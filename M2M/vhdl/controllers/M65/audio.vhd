----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Controller for the audio DAC, AK4432VT
-- The DAC is hardwired for I2C interface mode.
-- Sample rate is fsn=48 kHz.
-- Default mode is "32-bit MSB justified", aka mode 6, see pages 21 and 39 in
-- ak4432vt-en-datasheet.pdf
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity audio is
port (
   audio_clk_i    : in    std_logic;   -- 30.000 MHz
   audio_reset_i  : in    std_logic;
   audio_left_i   : in    signed(15 downto 0);
   audio_right_i  : in    signed(15 downto 0);

   -- Audio DAC. U37 = AK4432VT
   audio_mclk_o   : out   std_logic;   -- Master Clock Input Pin,       12.288 MHz = 256*48 kHz
   audio_bick_o   : out   std_logic;   -- Audio Serial Data Clock Pin,   3.072 MHz
   audio_sdti_o   : out   std_logic;   -- Audio Serial Data Input Pin,  16-bit LSB justified
   audio_lrclk_o  : out   std_logic;   -- Input Channel Clock Pin,      48.0 kHz
   audio_pdn_n_o  : out   std_logic;   -- Power-Down & Reset Pin
   audio_i2cfil_o : out   std_logic;   -- I2C Interface Mode Select Pin
   audio_scl_o    : out   std_logic;   -- Control Data Clock Input Pin
   audio_sda_io   : inout std_logic    -- Control Data Input/Output Pin
);
end entity audio;

architecture synthesis of audio is

   signal audio_12_fb_mmcm    : std_logic;
   signal audio_12_clk_mmcm   : std_logic;
   signal audio_12_clk        : std_logic;   -- 12.288 MHz
   signal audio_12_left       : std_logic_vector(15 downto 0); -- Signed
   signal audio_12_right      : std_logic_vector(15 downto 0); -- Signed

   signal fs_counter : integer range 0 to 255;
   signal i2s_data   : std_logic_vector(63 downto 0);

begin

   -------------------------------------------------------------
   -- The DAC requires a 12.288 MHz clock, but the audio_clock
   -- input to this entity is 30.000 MHz. So we instantiate
   -- yet another MMCM and CDC to handle this conversion.
   -------------------------------------------------------------

   i_clk_audio_12 : MMCME2_BASE
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKFBOUT_MULT_F      => 32.000,     -- f_VCO = (30 MHz / 1) x 32.000 = 960 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKIN1_PERIOD        => 33.333,     -- INPUT @ 30 MHz
         CLKOUT0_DIVIDE_F     => 78.125,     -- AUDIO_12 @ 12.288 MHz
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_PHASE        => 0.000,
         DIVCLK_DIVIDE        => 1,
         REF_JITTER1          => 0.010,
         STARTUP_WAIT         => FALSE
      )
      port map (
         CLKFBIN             => audio_12_fb_mmcm,
         CLKFBOUT            => audio_12_fb_mmcm,
         CLKIN1              => audio_clk_i,
         CLKOUT0             => audio_12_clk_mmcm,
         LOCKED              => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_audio_12

   audio_12_clk_bufg : BUFG
      port map (
         I => audio_12_clk_mmcm,
         O => audio_12_clk
      );

   -- Clock domain crossing: AUDIO to AUDIO_12
   i_audio2audio12: entity work.cdc_stable
      generic map (
         G_DATA_SIZE => 32
      )
      port map (
         src_clk_i                => audio_clk_i,
         src_data_i(15 downto  0) => std_logic_vector(audio_left_i),
         src_data_i(31 downto 16) => std_logic_vector(audio_right_i),
         dst_clk_i                => audio_12_clk,
         dst_data_o(15 downto  0) => audio_12_left,
         dst_data_o(31 downto 16) => audio_12_right
      ); -- i_audio2audio12


   -------------------------------------------------------------
   -- Convert the audio data to I2S format for the DAC.
   -------------------------------------------------------------

   i2s_data_proc : process (audio_12_clk)
   begin
      if rising_edge(audio_12_clk) then
         if fs_counter /= 255 then
           fs_counter <= fs_counter + 1;
           if (fs_counter mod 4) = 3 then
             i2s_data(63 downto 1) <= i2s_data(62 downto 0);
           end if;
         else
           fs_counter <= 0;
           i2s_data <= (others => '0');
           i2s_data(63 downto 48) <= audio_12_left;
           i2s_data(31 downto 16) <= audio_12_right;
         end if;
      end if;
   end process i2s_data_proc;

   -- Generate LRCLK, BICK and SDTI for I2S sinks
   audio_proc : process (audio_12_clk)
   begin
      if rising_edge(audio_12_clk) then
         audio_sdti_o <= i2s_data(63);
         if fs_counter < 128 then
            audio_lrclk_o <= '1';
         else
            audio_lrclk_o <= '0';
         end if;

         if (fs_counter mod 4) < 2 then
            audio_bick_o <= '0';
         else
            audio_bick_o <= '1';
         end if;
      end if;
   end process audio_proc;

   audio_mclk_o   <= audio_12_clk;
   audio_pdn_n_o  <= not audio_reset_i;
   audio_i2cfil_o <= '0';  -- I2C speed 400 kHz
   audio_scl_o    <= '1';
   audio_sda_io   <= 'Z';

end architecture synthesis;

