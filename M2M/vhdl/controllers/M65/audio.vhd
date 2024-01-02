----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Controller for the audio DAC, AK4432VT
-- The DAC requires a 12.288 MHz clock.
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
   audio_clk_i    : in    std_logic;   -- 12.288 MHz
   audio_reset_i  : in    std_logic;
   audio_left_i   : in    signed(15 downto 0);
   audio_right_i  : in    signed(15 downto 0);

   -- Audio DAC. U37 = AK4432VT
   audio_mclk_o   : out   std_logic;   -- Master Clock Input Pin,       12.288 MHz = 256*48 kHz
   audio_bick_o   : out   std_logic;   -- Audio Serial Data Clock Pin,   3.072 MHz
   audio_sdti_o   : out   std_logic;   -- Audio Serial Data Input Pin,  16-bit LSB justified
   audio_lrclk_o  : out   std_logic;   -- Input Channel Clock Pin,      48.0 kHz
   audio_pdn_n_o  : out   std_logic    -- Power-Down & Reset Pin
);
end entity audio;

architecture synthesis of audio is

   signal fs_counter : integer range 0 to 255;
   signal i2s_data   : std_logic_vector(63 downto 0);

begin

   -------------------------------------------------------------
   -- Convert the audio data to I2S format for the DAC.
   -------------------------------------------------------------

   i2s_data_proc : process (audio_clk_i)
   begin
      if rising_edge(audio_clk_i) then
         if fs_counter /= 255 then
           fs_counter <= fs_counter + 1;
           if (fs_counter mod 4) = 3 then
             i2s_data(63 downto 1) <= i2s_data(62 downto 0);
           end if;
         else
           fs_counter <= 0;
           i2s_data <= (others => '0');
           i2s_data(63 downto 48) <= std_logic_vector(audio_left_i);
           i2s_data(31 downto 16) <= std_logic_vector(audio_right_i);
         end if;
      end if;
   end process i2s_data_proc;

   -- Generate LRCLK, BICK and SDTI for I2S sinks
   audio_proc : process (audio_clk_i)
   begin
      if rising_edge(audio_clk_i) then
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

   audio_mclk_o   <= audio_clk_i;
   audio_pdn_n_o  <= not audio_reset_i;

end architecture synthesis;

