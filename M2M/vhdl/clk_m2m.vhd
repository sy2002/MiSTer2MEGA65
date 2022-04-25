-------------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Clock Generator using the Xilinx specific MMCME2_ADV:
--
--   QNICE expects 50 MHz
--   HyperRAM expects 100 MHz
--   Audio processing expects 30 MHz
--   HDMI 720p 60 Hz expects 74.25 MHz (HDMI) and 371.25 MHz (TMDS)
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
      sys_clk_i       : in  std_logic;   -- expects 100 MHz
      sys_rstn_i      : in  std_logic;   -- Asynchronous, asserted low

      qnice_clk_o     : out std_logic;   -- QNICE's 50 MHz main clock
      qnice_rst_o     : out std_logic;   -- QNICE's reset, synchronized

      hr_clk_x1_o     : out std_logic;   -- MEGA65 HyperRAM @ 100 MHz
      hr_clk_x2_o     : out std_logic;   -- MEGA65 HyperRAM @ 200 MHz
      hr_clk_x2_del_o : out std_logic;   -- MEGA65 HyperRAM @ 200 MHz phase delayed
      hr_rst_o        : out std_logic;   -- MEGA65 HyperRAM reset, synchronized

      tmds_clk_o      : out std_logic;   -- HDMI's 371.25 MHz pixelclock (74.25 MHz x 5) for TMDS
      hdmi_clk_o      : out std_logic;   -- HDMI's 74.25 MHz pixelclock for 720p @ 50 Hz
      hdmi_rst_o      : out std_logic;   -- HDMI's reset, synchronized

      audio_clk_o     : out std_logic;   -- Audio's 30 MHz clock
      audio_rst_o     : out std_logic    -- Audio's reset, synchronized
   );
end entity clk_m2m;

architecture rtl of clk_m2m is

signal clkfb1             : std_logic;
signal clkfb1_mmcm        : std_logic;
signal clkfb2             : std_logic;
signal clkfb2_mmcm        : std_logic;
signal clkfb3             : std_logic;
signal clkfb3_mmcm        : std_logic;
signal qnice_clk_mmcm     : std_logic;
signal hr_clk_x1_mmcm     : std_logic;
signal hr_clk_x2_mmcm     : std_logic;
signal hr_clk_x2_del_mmcm : std_logic;
signal audio_clk_mmcm     : std_logic;
signal tmds_clk_mmcm      : std_logic;
signal hdmi_clk_mmcm      : std_logic;

signal qnice_locked       : std_logic;
signal hdmi_locked        : std_logic;

begin

   -------------------------------------------------------------------------------------
   -- Generate QNICE and HyperRAM clock
   -------------------------------------------------------------------------------------

   -- VCO frequency range for Artix 7 speed grade -1 : 600 MHz - 1200 MHz
   -- f_VCO = f_CLKIN * CLKFBOUT_MULT_F / DIVCLK_DIVIDE
   
   i_clk_qnice : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => 12.0,       -- 1200 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 24.000,     -- QNICE @ 50 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 12,          -- HyperRAM @ 100 MHz
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE,
         CLKOUT2_DIVIDE       => 6,          -- HyperRAM @ 200 MHz
         CLKOUT2_PHASE        => 0.000,
         CLKOUT2_DUTY_CYCLE   => 0.500,
         CLKOUT2_USE_FINE_PS  => FALSE,
         CLKOUT3_DIVIDE       => 6,          -- HyperRAM @ 200 MHz phase delayed
         CLKOUT3_PHASE        => 180.000,
         CLKOUT3_DUTY_CYCLE   => 0.500,
         CLKOUT3_USE_FINE_PS  => FALSE,
         CLKOUT4_DIVIDE       => 40,         -- Audio @ 30 MHz
         CLKOUT4_PHASE        => 0.000,
         CLKOUT4_DUTY_CYCLE   => 0.500,
         CLKOUT4_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => clkfb1_mmcm,
         CLKOUT0             => qnice_clk_mmcm,
         CLKOUT1             => hr_clk_x1_mmcm,
         CLKOUT2             => hr_clk_x2_mmcm,
         CLKOUT3             => hr_clk_x2_del_mmcm,
         CLKOUT4             => audio_clk_mmcm,
         -- Input clock control
         CLKFBIN             => clkfb1,
         CLKIN1              => sys_clk_i,
         CLKIN2              => '0',
         -- Tied to always select the primary input clock
         CLKINSEL            => '1',
         -- Ports for dynamic reconfiguration
         DADDR               => (others => '0'),
         DCLK                => '0',
         DEN                 => '0',
         DI                  => (others => '0'),
         DO                  => open,
         DRDY                => open,
         DWE                 => '0',
         -- Ports for dynamic phase shift
         PSCLK               => '0',
         PSEN                => '0',
         PSINCDEC            => '0',
         PSDONE              => open,
         -- Other control and status signals
         LOCKED              => qnice_locked,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_qnice

   -------------------------------------------------------------------------------------
   -- Generate 74.25 MHz for 720p @ 50 Hz and 5x74.25 MHz = 371.25 MHz for TMDS
   -------------------------------------------------------------------------------------

   i_clk_hdmi : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 5,
         CLKFBOUT_MULT_F      => 37.125,     -- f_VCO = (100 MHz / 5) x 37.125 = 742.5 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 2.000,      -- 371.25 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 10,         -- 74.25 MHz
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => clkfb2_mmcm,
         CLKOUT0             => tmds_clk_mmcm,
         CLKOUT1             => hdmi_clk_mmcm,
         -- Input clock control
         CLKFBIN             => clkfb2,
         CLKIN1              => sys_clk_i,
         CLKIN2              => '0',
         -- Tied to always select the primary input clock
         CLKINSEL            => '1',
         -- Ports for dynamic reconfiguration
         DADDR               => (others => '0'),
         DCLK                => '0',
         DEN                 => '0',
         DI                  => (others => '0'),
         DO                  => open,
         DRDY                => open,
         DWE                 => '0',
         -- Ports for dynamic phase shift
         PSCLK               => '0',
         PSEN                => '0',
         PSINCDEC            => '0',
         PSDONE              => open,
         -- Other control and status signals
         LOCKED              => hdmi_locked,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_hdmi

   -------------------------------------------------------------------------------------
   -- Output buffering
   -------------------------------------------------------------------------------------

   clkfb1_bufg : BUFG
      port map (
         I => clkfb1_mmcm,
         O => clkfb1
      );

   clkfb2_bufg : BUFG
      port map (
         I => clkfb2_mmcm,
         O => clkfb2
      );

   clkfb3_bufg : BUFG
      port map (
         I => clkfb3_mmcm,
         O => clkfb3
      );

   qnice_clk_bufg : BUFG
      port map (
         I => qnice_clk_mmcm,
         O => qnice_clk_o
      );

   hr_clk_x1_bufg : BUFG
      port map (
         I => hr_clk_x1_mmcm,
         O => hr_clk_x1_o
      );

   hr_clk_x2_bufg : BUFG
      port map (
         I => hr_clk_x2_mmcm,
         O => hr_clk_x2_o
      );

   hr_clk_x2_del_bufg : BUFG
      port map (
         I => hr_clk_x2_del_mmcm,
         O => hr_clk_x2_del_o
      );

   audio_clk_bufg : BUFG
      port map (
         I => audio_clk_mmcm,
         O => audio_clk_o
      );

   tmds_clk_bufg : BUFG
      port map (
         I => tmds_clk_mmcm,
         O => tmds_clk_o
      );

   hdmi_clk_bufg : BUFG
      port map (
         I => hdmi_clk_mmcm,
         O => hdmi_clk_o
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
         DEST_SYNC_FF    => 10
      )
      port map (
         -- 1-bit input: Source reset signal
         -- Important: The HyperRAM needs to be reset when ascal is being reset! The Avalon memory interface
         --  assumes that both ends maintain state information and agree on this state information. Therefore,
         -- one side can not be reset in the middle of e.g. a burst transaction, without the other end becoming confused.         
         src_arst  => not (qnice_locked and sys_rstn_i) or hdmi_rst_o,
         dest_clk  => hr_clk_x1_o,      -- 1-bit input: Destination clock.
         dest_arst => hr_rst_o          -- 1-bit output: src_rst synchronized to the destination clock domain.
                                        -- This output is registered.
      );

   i_xpm_cdc_async_rst_audio : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 10
      )
      port map (
         src_arst  => not (qnice_locked and sys_rstn_i),   -- 1-bit input: Source reset signal.
         dest_clk  => audio_clk_o,      -- 1-bit input: Destination clock.
         dest_arst => audio_rst_o       -- 1-bit output: src_rst synchronized to the destination clock domain.
                                        -- This output is registered.
      );

   i_xpm_cdc_async_rst_hdmi : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 10
      )
      port map (
         src_arst  => not (hdmi_locked and sys_rstn_i),   -- 1-bit input: Source reset signal.
         dest_clk  => hdmi_clk_o,       -- 1-bit input: Destination clock.
         dest_arst => hdmi_rst_o        -- 1-bit output: src_rst synchronized to the destination clock domain.
                                       -- This output is registered.
      );

end architecture rtl;

