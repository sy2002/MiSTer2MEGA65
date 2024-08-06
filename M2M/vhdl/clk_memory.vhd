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

entity clk_memory is
   port (
      sys_clk_i         : in    std_logic; -- expects 100 MHz
      sys_rstn_i        : in    std_logic; -- Asynchronous, asserted low

      hr_clk_o          : out   std_logic; -- MEGA65 HyperRAM @ 100 MHz
      hr_clk_del_o      : out   std_logic; -- MEGA65 HyperRAM @ 100 MHz phase delayed
      hr_delay_refclk_o : out   std_logic; -- MEGA65 HyperRAM @ 200 MHz
      hr_rst_o          : out   std_logic  -- MEGA65 HyperRAM reset, synchronized
   );
end entity clk_memory;

architecture synthesis of clk_memory is

   signal fb_clk          : std_logic;
   signal hr_clk          : std_logic;
   signal hr_clk_del      : std_logic;
   signal hr_delay_refclk : std_logic;
   signal pll_locked      : std_logic;

begin

   -------------------------------------------------------------------------------------
   -- Generate HyperRAM clock
   -------------------------------------------------------------------------------------

   -- VCO frequency range for Artix 7 speed grade -1 : 600 MHz - 1200 MHz
   -- f_VCO = f_CLKIN * CLKFBOUT_MULT_F / DIVCLK_DIVIDE

   clk_mem_inst : component plle2_base
      generic map (
         BANDWIDTH          => "OPTIMIZED",
         CLKFBOUT_MULT      => 12,   -- 1200 MHz
         CLKFBOUT_PHASE     => 0.000,
         CLKIN1_PERIOD      => 10.0, -- INPUT @ 100 MHz
         CLKOUT0_DIVIDE     => 12,   -- HyperRAM @ 100 MHz
         CLKOUT0_DUTY_CYCLE => 0.500,
         CLKOUT0_PHASE      => 0.000,
         CLKOUT1_DIVIDE     => 6,    -- HyperRAM @ 200 MHz
         CLKOUT1_DUTY_CYCLE => 0.500,
         CLKOUT1_PHASE      => 0.000,
         CLKOUT2_DIVIDE     => 12,   -- HyperRAM @ 100 MHz phase delayed
         CLKOUT2_DUTY_CYCLE => 0.500,
         CLKOUT2_PHASE      => 90.000,
         DIVCLK_DIVIDE      => 1,
         REF_JITTER1        => 0.010,
         STARTUP_WAIT       => "FALSE"
      )
      port map (
         clkfbin  => fb_clk,
         clkfbout => fb_clk,
         clkin1   => sys_clk_i,
         clkout0  => hr_clk,
         clkout1  => hr_delay_refclk,
         clkout2  => hr_clk_del,
         locked   => pll_locked,
         pwrdwn   => '0',
         rst      => '0'
      ); -- clk_mem_inst


   ---------------------------------------------------------------------------------------
   -- Output buffering
   ---------------------------------------------------------------------------------------

   bufg_hr_clk_inst : component bufg
      port map (
         i => hr_clk,
         o => hr_clk_o
      ); -- bufg_hr_clk_inst

   bufg_hr_clk_del_inst : component bufg
      port map (
         i => hr_clk_del,
         o => hr_clk_del_o
      ); -- bufg_hr_clk_del_inst

   bufg_hr_delay_refclk_inst : component bufg
      port map (
         i => hr_delay_refclk,
         o => hr_delay_refclk_o
      ); -- bufg_hr_delay_refclk_inst


   -------------------------------------
   -- Reset generation
   -------------------------------------

   xpm_cdc_async_rst_hr_inst : component xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         -- 1-bit input: Source reset signal
         -- Important: The HyperRAM needs to be reset when ascal is being reset! The Avalon memory interface
         -- assumes that both ends maintain state information and agree on this state information. Therefore,
         -- one side can not be reset in the middle of e.g. a burst transaction, without the other end becoming confused.
         src_arst  => not (pll_locked and sys_rstn_i),
         dest_clk  => hr_clk_o, -- 1-bit input: Destination clock.
         dest_arst => hr_rst_o  -- 1-bit output: src_rst synchronized to the destination clock domain.
      -- This output is registered.
      );

end architecture synthesis;

