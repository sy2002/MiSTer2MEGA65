-------------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Clock Generator using the Xilinx specific MMCME2_ADV:
--
--   QNICE expects 50 MHz
--   HyperRAM expects 100 MHz
--   Audio processing expects 30 MHz
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
-------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk_m2m is
   port (
      sys_clk_i         : in  std_logic;   -- expects 100 MHz
      sys_rstn_i        : in  std_logic;   -- Asynchronous, asserted low
      core_rstn_i       : in  std_logic;   -- Reset only the core, asserted low

      qnice_clk_o       : out std_logic;   -- QNICE's 50 MHz main clock
      qnice_rst_o       : out std_logic;   -- QNICE's reset, synchronized

      hr_clk_o          : out std_logic;   -- MEGA65 HyperRAM @ 100 MHz
      hr_clk_del_o      : out std_logic;   -- MEGA65 HyperRAM @ 100 MHz phase delayed
      hr_delay_refclk_o : out std_logic;   -- MEGA65 HyperRAM @ 200 MHz
      hr_rst_o          : out std_logic;   -- MEGA65 HyperRAM reset, synchronized

      audio_clk_o       : out std_logic;   -- Audio's 12.288 MHz clock
      audio_rst_o       : out std_logic;   -- Audio's reset, synchronized

      sys_pps_o         : out std_logic    -- One pulse per second (in sys_clk domain)
   );
end entity clk_m2m;

architecture rtl of clk_m2m is

signal audio_fb_mmcm        : std_logic;
signal qnice_fb_mmcm        : std_logic;
signal qnice_clk_mmcm       : std_logic;
signal hr_clk_mmcm          : std_logic;
signal hr_clk_del_mmcm      : std_logic;
signal hr_delay_refclk_mmcm : std_logic;
signal audio_clk_mmcm       : std_logic;

signal sys_clk_9975_bg      : std_logic;

signal qnice_locked         : std_logic;
signal audio_locked         : std_logic;

signal sys_counter          : natural range 0 to 99_999_999;

begin

   -------------------------------------------------------------------------------------
   -- Generate QNICE and HyperRAM clock
   -------------------------------------------------------------------------------------

   -- VCO frequency range for Artix 7 speed grade -1 : 600 MHz - 1200 MHz
   -- f_VCO = f_CLKIN * CLKFBOUT_MULT_F / DIVCLK_DIVIDE

   i_clk_qnice : PLLE2_BASE
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKFBOUT_MULT        => 12,         -- 1200 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         CLKOUT0_DIVIDE       => 24,         -- QNICE @ 50 MHz
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_PHASE        => 0.000,
         CLKOUT1_DIVIDE       => 12,         -- HyperRAM @ 100 MHz
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_PHASE        => 0.000,
         CLKOUT2_DIVIDE       => 6,          -- HyperRAM @ 200 MHz
         CLKOUT2_DUTY_CYCLE   => 0.500,
         CLKOUT2_PHASE        => 0.000,
         CLKOUT3_DIVIDE       => 12,         -- HyperRAM @ 100 MHz phase delayed
         CLKOUT3_DUTY_CYCLE   => 0.500,
         CLKOUT3_PHASE        => 90.000,
         DIVCLK_DIVIDE        => 1,
         REF_JITTER1          => 0.010,
         STARTUP_WAIT         => "FALSE"
      )
      port map (
         CLKFBIN             => qnice_fb_mmcm,
         CLKFBOUT            => qnice_fb_mmcm,
         CLKIN1              => sys_clk_i,
         CLKOUT0             => qnice_clk_mmcm,
         CLKOUT1             => hr_clk_mmcm,
         CLKOUT2             => hr_delay_refclk_mmcm,
         CLKOUT3             => hr_clk_del_mmcm,
         LOCKED              => qnice_locked,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_qnice

   i_clk_audio : MMCME2_BASE
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKFBOUT_MULT_F      => 48.000,     -- 960 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         CLKOUT0_DIVIDE_F     => 78.125,     -- AUDIO @ 12.288 MHz
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_PHASE        => 0.000,
         DIVCLK_DIVIDE        => 5,
         REF_JITTER1          => 0.010,
         STARTUP_WAIT         => FALSE
      )
      port map (
         CLKFBIN             => audio_fb_mmcm,
         CLKFBOUT            => audio_fb_mmcm,
         CLKIN1              => sys_clk_i,
         CLKOUT0             => audio_clk_mmcm,
         LOCKED              => audio_locked,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_audio

   ---------------------------------------------------------------------------------------
   -- Output buffering
   ---------------------------------------------------------------------------------------

   qnice_clk_bufg : BUFG
      port map (
         I => qnice_clk_mmcm,
         O => qnice_clk_o
      );

   hr_clk_bufg : BUFG
      port map (
         I => hr_clk_mmcm,
         O => hr_clk_o
      );

   hr_clk_del_bufg : BUFG
      port map (
         I => hr_clk_del_mmcm,
         O => hr_clk_del_o
      );

   hr_delay_refclk_bufg : BUFG
      port map (
         I => hr_delay_refclk_mmcm,
         O => hr_delay_refclk_o
      );

   audio_clk_bufg : BUFG
      port map (
         I => audio_clk_mmcm,
         O => audio_clk_o
      );

   -------------------------------------
   -- Reset generation
   -------------------------------------

   i_xpm_cdc_async_rst_qnice : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1
      )
      port map (
         src_arst  => not (qnice_locked and sys_rstn_i),   -- 1-bit input: Source reset signal.
         dest_clk  => qnice_clk_o,      -- 1-bit input: Destination clock.
         dest_arst => qnice_rst_o       -- 1-bit output: src_rst synchronized to the destination clock domain.
                                        -- This output is registered.
      );

   i_xpm_cdc_async_rst_hr : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         -- 1-bit input: Source reset signal
         -- Important: The HyperRAM needs to be reset when ascal is being reset! The Avalon memory interface
         -- assumes that both ends maintain state information and agree on this state information. Therefore,
         -- one side can not be reset in the middle of e.g. a burst transaction, without the other end becoming confused.
         src_arst  => not (qnice_locked and sys_rstn_i and core_rstn_i),
         dest_clk  => hr_clk_o,         -- 1-bit input: Destination clock.
         dest_arst => hr_rst_o          -- 1-bit output: src_rst synchronized to the destination clock domain.
                                        -- This output is registered.
      );

   i_xpm_cdc_async_rst_audio : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         src_arst  => not (audio_locked and sys_rstn_i),   -- 1-bit input: Source reset signal.
         dest_clk  => audio_clk_o,      -- 1-bit input: Destination clock.
         dest_arst => audio_rst_o       -- 1-bit output: src_rst synchronized to the destination clock domain.
                                        -- This output is registered.
      );

   p_sys_pps : process (sys_clk_i)
   begin
      if rising_edge(sys_clk_i) then
         if sys_counter < 99_999_999 then
            sys_counter <= sys_counter + 1;
            sys_pps_o   <= '0';
         else
            sys_counter <= 0;
            sys_pps_o   <= '1';
         end if;
      end if;
   end process p_sys_pps;

end architecture rtl;

