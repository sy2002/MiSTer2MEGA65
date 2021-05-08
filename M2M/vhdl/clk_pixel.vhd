----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Pixelclock generator using the Xilinx specific MMCME2_ADV:
-- SVGA mode 800 x 600 @ 60 Hz
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clk_p is
   port (
      sys_clk_i  : in  std_logic;   -- expects 100 MHz
      pixelclk_o : out std_logic    -- outputs 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
   );
end clk_p;

architecture rtl of clk_p is

signal clkfb         : std_logic;
signal clkfb_mmcm    : std_logic;
signal pixelclk_mmcm : std_logic;

begin

   i_mmcme2_adv : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => 8.0,        -- 800.0 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 20.0,       -- Pixelclock @ 40.00 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE
--         CLKOUT1_DIVIDE       => 25,
--         CLKOUT1_PHASE        => 0.000,
--         CLKOUT1_DUTY_CYCLE   => 0.500,
--         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => clkfb_mmcm,
         CLKOUT0             => pixelclk_mmcm,
--         CLKOUT1             => open,
         -- Input clock control
         CLKFBIN             => clkfb,
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
         LOCKED              => open,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      );


   -------------------------------------
   -- Output buffering
   -------------------------------------

   clkfb_bufg : BUFG
      port map (
         I => clkfb_mmcm,
         O => clkfb
      );

   pixelclk_bufg : BUFG
      port map (
         I => pixelclk_mmcm,
         O => pixelclk_o
      );
      
end architecture rtl;

