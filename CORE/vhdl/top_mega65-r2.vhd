----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- R2-Version: Top Module for synthesizing the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mega65_r2 is
port (
   CLK            : in  std_logic;                  -- 100 MHz clock
   RESET_N        : in  std_logic;                  -- CPU reset button

   -- serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in  std_logic;                  -- receive data
   UART_TXD       : out std_logic;                  -- send data

   -- VGA and VDAC
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;

   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;

   -- HDMI via ADV7511
--   hdmi_vsync     : out std_logic;
--   hdmi_hsync     : out std_logic;
--   hdmired        : out std_logic_vector(7 downto 0);
--   hdmigreen      : out std_logic_vector(7 downto 0);
--   hdmiblue       : out std_logic_vector(7 downto 0);

--   hdmi_clk       : out std_logic;
--   hdmi_de        : out std_logic;                 -- high when valid pixels being output

--   hdmi_int       : in std_logic;                  -- interrupts by ADV7511
--   hdmi_spdif     : out std_logic := '0';          -- unused: GND
--   hdmi_scl       : inout std_logic;               -- I2C to/from ADV7511: serial clock
--   hdmi_sda       : inout std_logic;               -- I2C to/from ADV7511: serial data

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in  std_logic;                 -- data input from keyboard

   -- SD Card
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in  std_logic;

   -- 3.5mm analog audio jack
   pwm_l          : out std_logic;
   pwm_r          : out std_logic;

   -- Joysticks
   joy_1_up_n     : in  std_logic;
   joy_1_down_n   : in  std_logic;
   joy_1_left_n   : in  std_logic;
   joy_1_right_n  : in  std_logic;
   joy_1_fire_n   : in  std_logic;

   joy_2_up_n     : in  std_logic;
   joy_2_down_n   : in  std_logic;
   joy_2_left_n   : in  std_logic;
   joy_2_right_n  : in  std_logic;
   joy_2_fire_n   : in  std_logic;

   -- Built-in HyperRAM
   hr_d           : inout std_logic_vector(7 downto 0);    -- Data/Address
   hr_rwds        : inout std_logic;               -- RW Data strobe
   hr_reset       : out std_logic;                 -- Active low RESET line to HyperRAM
   hr_clk_p       : out std_logic;
   hr_cs0         : out std_logic

   -- Optional additional HyperRAM in trap-door slot
--   hr2_d          : inout unsigned(7 downto 0);    -- Data/Address
--   hr2_rwds       : inout std_logic;               -- RW Data strobe
--   hr2_reset      : out std_logic;                 -- Active low RESET line to HyperRAM
--   hr2_clk_p      : out std_logic;
--   hr_cs1         : out std_logic
);
end entity mega65_r2;

architecture synthesis of mega65_r2 is
begin

   MEGA65 : entity work.MEGA65_Core
      generic map
      (
         -- @TODO: Add your MEGA65 revision machine dependent generics (MEGA65 R2, R3, ...) here
         -- or delete them if your core does not have machine dependencies
         YOUR_GENERIC1  => 1,
         YOUR_GENERIC2  => "MiSTer2MEGA65",
         YOUR_GENERICN  => 1234
      )
      port map
      (
         CLK            => CLK,
         RESET_N        => RESET_N,

         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         UART_RXD       => UART_RXD,
         UART_TXD       => UART_TXD,

         -- VGA and VDAC
         VGA_RED        => VGA_RED,
         VGA_GREEN      => VGA_GREEN,
         VGA_BLUE       => VGA_BLUE,
         VGA_HS         => VGA_HS,
         VGA_VS         => VGA_VS,

         vdac_clk       => vdac_clk,
         vdac_sync_n    => vdac_sync_n,
         vdac_blank_n   => vdac_blank_n,

         -- MEGA65 smart keyboard controller
         kb_io0         => kb_io0,
         kb_io1         => kb_io1,
         kb_io2         => kb_io2,

         -- SD Card
         SD_RESET       => SD_RESET,
         SD_CLK         => SD_CLK,
         SD_MOSI        => SD_MOSI,
         SD_MISO        => SD_MISO,

         -- 3.5mm analog audio jack
         pwm_l          => pwm_l,
         pwm_r          => pwm_r,

         -- Joysticks
         joy_1_up_n     => joy_1_up_n,
         joy_1_down_n   => joy_1_down_n,
         joy_1_left_n   => joy_1_left_n,
         joy_1_right_n  => joy_1_right_n,
         joy_1_fire_n   => joy_1_fire_n,

         joy_2_up_n     => joy_2_up_n,
         joy_2_down_n   => joy_2_down_n,
         joy_2_left_n   => joy_2_left_n,
         joy_2_right_n  => joy_2_right_n,
         joy_2_fire_n   => joy_2_fire_n,

         hr_d           => hr_d,
         hr_rwds        => hr_rwds,
         hr_reset       => hr_reset,
         hr_clk_p       => hr_clk_p,
         hr_cs0         => hr_cs0
      ); -- MEGA65

end architecture synthesis;

