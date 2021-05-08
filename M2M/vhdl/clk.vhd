----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Main clock & QNICE-clock generator using the Xilinx specific MMCME2_ADV
--
-- The MiSTer core expects 8x the clock speed of the original Game Boy:
--   8 x 4.194304 MHz = 33.554432 MHz
-- The QNICE core expects 50 MHz
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clk is
   port (
      sys_clk_i  : in  std_logic;   -- expects 100 MHz
      gbmain_o   : out std_logic;   -- Game Boy's 33.554432 MHz main clock
      qnice_o    : out std_logic;   -- QNICE's 50 MHz main clock
      pixelclk_o : out std_logic    -- outputs 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
   );
end clk;

architecture rtl of clk is

signal clkfb         : std_logic;
signal clkfb_mmcm    : std_logic;
signal gbmain_mmcm   : std_logic;
signal qnice_mmcm    : std_logic;
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
         CLKFBOUT_MULT_F      => 8.0,        -- 800 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 23.875,     -- GameBoyColor @ 33.51 MHz, close enough to 33.554432 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 16,         -- QNICE main @ 50 MHz
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE,
         CLKOUT2_DIVIDE       => 20,         -- Pixelclock @ 40.00 MHz
         CLKOUT2_PHASE        => 0.000,
         CLKOUT2_DUTY_CYCLE   => 0.500,
         CLKOUT2_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => clkfb_mmcm,
         CLKOUT0             => gbmain_mmcm,
         CLKOUT1             => qnice_mmcm,
         CLKOUT2             => pixelclk_mmcm,
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
      
   gbmain_bufg : BUFG
      port map (
         I => gbmain_mmcm,
         O => gbmain_o
      );

   qnice_bufg : BUFG
      port map (
         I => qnice_mmcm,
         O => qnice_o
      );

   pixelclk_bufg : BUFG
      port map (
         I => pixelclk_mmcm,
         O => pixelclk_o
      );
      
end architecture rtl;

