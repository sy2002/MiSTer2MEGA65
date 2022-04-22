----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- MEGA65 main file that contains the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

library work;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   
   -- M2M's reset manager provides 2 signals:
   --    RESET_M2M_N:   Reset the whole machine: Core and Framework
   --    RESET_CORE_N:  Only reset the core
   RESET_M2M_N    : in std_logic;
   RESET_CORE_N   : in std_logic;

   -- Serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                  -- receive data
   UART_TXD       : out std_logic;                 -- send data

   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;

   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;

   -- Digital Video (HDMI)
   tmds_data_p    : out std_logic_vector(2 downto 0);
   tmds_data_n    : out std_logic_vector(2 downto 0);
   tmds_clk_p     : out std_logic;
   tmds_clk_n     : out std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard

   -- SD Card (internal on bottom)
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic;
   SD_CD          : in std_logic;

   -- SD Card (external on back)
   SD2_RESET      : out std_logic;
   SD2_CLK        : out std_logic;
   SD2_MOSI       : out std_logic;
   SD2_MISO       : in std_logic;
   SD2_CD         : in std_logic;

   -- 3.5mm analog audio jack
   pwm_l          : out std_logic;
   pwm_r          : out std_logic;

   -- Joysticks
   joy_1_up_n     : in std_logic;
   joy_1_down_n   : in std_logic;
   joy_1_left_n   : in std_logic;
   joy_1_right_n  : in std_logic;
   joy_1_fire_n   : in std_logic;

   joy_2_up_n     : in std_logic;
   joy_2_down_n   : in std_logic;
   joy_2_left_n   : in std_logic;
   joy_2_right_n  : in std_logic;
   joy_2_fire_n   : in std_logic;

   -- Built-in HyperRAM
   hr_d           : inout std_logic_vector(7 downto 0);    -- Data/Address
   hr_rwds        : inout std_logic;               -- RW Data strobe
   hr_reset       : out std_logic;                 -- Active low RESET line to HyperRAM
   hr_clk_p       : out std_logic;
   hr_cs0         : out std_logic
);
end entity MEGA65_Core;

architecture beh of MEGA65_Core is

-- QNICE Firmware: Use the regular QNICE "operating system" called "Monitor" while developing
-- and debugging and use the MiSTer2MEGA65 firmware in the release version
--constant QNICE_FIRMWARE       : string  := "../../QNICE/monitor/monitor.rom";  -- debug/development
constant QNICE_FIRMWARE       : string  := "../../MEGA65/m2m-rom/m2m-rom.rom";   -- release

-- HDMI 1280x720 @ 60 Hz resolution = mode 0, 1280x720 @ 50 Hz resolution = mode 1
constant VIDEO_MODE_VECTOR    : video_modes_vector(0 to 1) := (C_HDMI_720p_60, C_HDMI_720p_50);

-- CORE clock speed
constant CORE_CLK_SPEED       : natural := 54_000_000;   -- @TODO YOURCORE expects 54 MHz
constant HDMI_CLK_SPEED       : natural := 74_250_000;

-- Rendering constants (in pixels)
--    VGA_*   size of the final output on the screen
--    FONT_*  size of one OSM character
constant VGA_DX               : natural := 720;
constant VGA_DY               : natural := 576;
constant FONT_FILE            : string  := "../font/Anikki-16x16.rom";
constant FONT_DX              : natural := 16;
constant FONT_DY              : natural := 16;

-- Constants for the OSM screen memory
constant CHARS_DX             : natural := VGA_DX / FONT_DX;
constant CHARS_DY             : natural := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE        : natural := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH      : natural := f_log2(CHAR_MEM_SIZE);

---------------------------------------------------------------------------------------------
-- Democore & example stuff: Delete before starting to port your own core
---------------------------------------------------------------------------------------------

-- the example menu allows you to switch the HDMI output frequency between 50Hz and 60Hz
constant C_MENU_60_HZ         : natural := 10;

-- example virtual drive handler, which is connected to nothing and only here to demo
-- the file- and directory browsing capabilities of the firmware
constant C_DEV_DEMO_VD        : std_logic_vector(15 downto 0) := x"0101";
constant C_DEV_DEMO_NOBUFFER  : std_logic_vector(15 downto 0) := x"AAAA";

-- QNICE clock domain
signal qnice_demo_vd_data_o   : std_logic_vector(15 downto 0);
signal qnice_demo_vd_ce       : std_logic;
signal qnice_demo_vd_we       : std_logic;

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal qnice_clk              : std_logic;               -- QNICE main clock @ 50 MHz
signal hr_clk_x1              : std_logic;               -- HyperRAM @ 100 MHz
signal hr_clk_x2              : std_logic;               -- HyperRAM @ 200 MHz
signal hr_clk_x2_del          : std_logic;               -- HyperRAM @ 200 MHz phase delayed
signal audio_clk              : std_logic;               -- Audio clock @ 60 MHz
signal tmds_clk               : std_logic;               -- HDMI pixel clock at 5x speed for TMDS @ 371.25 MHz
signal hdmi_clk               : std_logic;               -- HDMI pixel clock at normal speed @ 74.25 MHz
signal main_clk               : std_logic;               -- Core main clock
signal video_clk              : std_logic;               -- Core pixel clock

signal qnice_rst              : std_logic;
signal hr_rst                 : std_logic;
signal audio_rst              : std_logic;
signal hdmi_rst               : std_logic;
signal main_rst               : std_logic;
signal video_rst              : std_logic;

signal core_only_rst          : std_logic;               -- reset only the core, not the framework

---------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- QNICE control and status register
signal main_qnice_reset       : std_logic;
signal main_qnice_pause       : std_logic;
signal main_csr_keyboard_on   : std_logic;
signal main_csr_joy1_on       : std_logic;
signal main_csr_joy2_on       : std_logic;

-- keyboard handling
signal main_key_num           : integer range 0 to 79;
signal main_key_pressed_n     : std_logic;
signal main_qnice_keys_n      : std_logic_vector(15 downto 0);
signal main_drive_led         : std_logic;

-- QNICE On Screen Menu selections
signal main_osm_control_m     : std_logic_vector(255 downto 0);

-- signed audio from the core
-- if the core outputs unsigned audio, make sure you convert properly to prevent a loss in audio quality
signal main_audio_l           : signed(15 downto 0);
signal main_audio_r           : signed(15 downto 0);
signal filt_audio_l           : std_logic_vector(15 downto 0);
signal filt_audio_r           : std_logic_vector(15 downto 0);
signal audio_l                : std_logic_vector(15 downto 0);
signal audio_r                : std_logic_vector(15 downto 0);

-- Video output from Core
signal main_video_ce          : std_logic;
signal main_video_red         : std_logic_vector(7 downto 0);
signal main_video_green       : std_logic_vector(7 downto 0);
signal main_video_blue        : std_logic_vector(7 downto 0);
signal main_video_vs          : std_logic;
signal main_video_hs          : std_logic;
signal main_video_hblank      : std_logic;
signal main_video_vblank      : std_logic;

signal main_crop_ce           : std_logic;
signal main_crop_red          : std_logic_vector(7 downto 0);
signal main_crop_green        : std_logic_vector(7 downto 0);
signal main_crop_blue         : std_logic_vector(7 downto 0);
signal main_crop_hs           : std_logic;
signal main_crop_vs           : std_logic;
signal main_crop_hblank       : std_logic;
signal main_crop_vblank       : std_logic;

-- Joysticks
signal j1_up_n                : std_logic;
signal j1_down_n              : std_logic;
signal j1_left_n              : std_logic;
signal j1_right_n             : std_logic;
signal j1_fire_n              : std_logic;
signal j2_up_n                : std_logic;
signal j2_down_n              : std_logic;
signal j2_left_n              : std_logic;
signal j2_right_n             : std_logic;
signal j2_fire_n              : std_logic;

-- On-Screen-Menu (OSM) for VGA
signal main_osm_cfg_enable   : std_logic;
signal main_osm_cfg_xy       : std_logic_vector(15 downto 0);
signal main_osm_cfg_dxdy     : std_logic_vector(15 downto 0);
signal main_osm_vram_addr    : std_logic_vector(15 downto 0);
signal main_osm_vram_data    : std_logic_vector(15 downto 0);

-- On-Screen-Menu (OSM) for HDMI
signal hdmi_osm_cfg_enable    : std_logic;
signal hdmi_osm_cfg_xy        : std_logic_vector(15 downto 0);
signal hdmi_osm_cfg_dxdy      : std_logic_vector(15 downto 0);
signal hdmi_osm_vram_addr     : std_logic_vector(15 downto 0);
signal hdmi_osm_vram_data     : std_logic_vector(15 downto 0);

-- QNICE On Screen Menu selections
signal hdmi_osm_control_m     : std_logic_vector(255 downto 0);

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

-- Control and status register that QNICE uses to control the Core
signal qnice_csr_reset        : std_logic;
signal qnice_csr_pause        : std_logic;
signal qnice_csr_keyboard_on  : std_logic;
signal qnice_csr_joy1_on      : std_logic;
signal qnice_csr_joy2_on      : std_logic;

-- On-Screen-Menu (OSM)
signal qnice_osm_cfg_enable   : std_logic;
signal qnice_osm_cfg_xy       : std_logic_vector(15 downto 0);
signal qnice_osm_cfg_dxdy     : std_logic_vector(15 downto 0);

-- ascal.vhd mode register and polyphase filter handling
signal qnice_ascal_mode       : std_logic_vector(4 downto 0);
signal qnice_poly_wr          : std_logic;

-- m2m_keyb output for the firmware and the Shell; see also sysdef.asm
signal qnice_qnice_keys_n     : std_logic_vector(15 downto 0);

-- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
-- ramrom_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
signal qnice_ramrom_dev       : std_logic_vector(15 downto 0);
signal qnice_ramrom_addr      : std_logic_vector(27 downto 0);
signal qnice_ramrom_data_o    : std_logic_vector(15 downto 0);
signal qnice_ramrom_data_i    : std_logic_vector(15 downto 0);
signal qnice_ramrom_ce        : std_logic;
signal qnice_ramrom_we        : std_logic;

-- Devices: MiSTer2MEGA framework
constant C_DEV_VRAM_DATA      : std_logic_vector(15 downto 0) := x"0000";
constant C_DEV_VRAM_ATTR      : std_logic_vector(15 downto 0) := x"0001";
constant C_DEV_OSM_CONFIG     : std_logic_vector(15 downto 0) := x"0002";
constant C_DEV_ASCAL_PPHASE   : std_logic_vector(15 downto 0) := x"0003";
constant C_DEV_SYS_INFO       : std_logic_vector(15 downto 0) := x"00FF";
constant C_SYS_VGA            : std_logic_vector(15 downto 0) := x"0010";
constant C_SYS_HDMI           : std_logic_vector(15 downto 0) := x"0011";

-- Virtual drive management system (handled by vdrives.vhd and the firmware)
-- If you are not using virtual drives, make sure that:
--    C_VDNUM        is 0
--    C_VD_DEVICE    is x"EEEE"
--    C_VD_BUFFER    is (x"EEEE", x"EEEE")
-- Otherwise make sure that you wire C_VD_DEVICE in the qnice_ramrom_devices process and that you
-- have as many appropriately sized RAM buffers for disk images as you have drives
type vd_buf_array is array(natural range <>) of std_logic_vector;
constant C_VDNUM              : natural := 3;                                          -- amount of virtual drives; if more than 5: also adjust VDRIVES_MAX in M2M/rom/shell_vars.asm, maximum is 15
constant C_VD_DEVICE          : std_logic_vector(15 downto 0) := C_DEV_DEMO_VD;        -- device number of vdrives.vhd device
constant C_VD_BUFFER          : vd_buf_array := (  C_DEV_DEMO_NOBUFFER,
                                                   C_DEV_DEMO_NOBUFFER,
                                                   C_DEV_DEMO_NOBUFFER,
                                                   x"EEEE");                           -- Always finish the array using x"EEEE"

-- Sysinfo device for the two graphics adaptors that the firmware uses for the on-screen-display 
signal sys_info_vga           : std_logic_vector(47 downto 0);
signal sys_info_hdmi          : std_logic_vector(47 downto 0);

-- VRAM
signal qnice_vram_data        : std_logic_vector(15 downto 0);
signal qnice_vram_we          : std_logic;   -- Writing to bits 7-0
signal qnice_vram_attr_we     : std_logic;   -- Writing to bits 15-8

-- Shell configuration (config.vhd)
signal qnice_config_data      : std_logic_vector(15 downto 0);

-- QNICE On Screen Menu selections
signal qnice_osm_control_m    : std_logic_vector(255 downto 0);

constant C_MENU_HDMI_60HZ     : natural := 10;
constant C_MENU_CRT_EMULATION : natural := 20;
constant C_MENU_HDMI_ZOOM     : natural := 21;
constant C_MENU_IMPROVE_AUDIO : natural := 22;

-- HyperRAM
signal hr_write         : std_logic;
signal hr_read          : std_logic;
signal hr_address       : std_logic_vector(31 downto 0) := (others => '0');
signal hr_writedata     : std_logic_vector(15 downto 0);
signal hr_byteenable    : std_logic_vector(1 downto 0);
signal hr_burstcount    : std_logic_vector(7 downto 0);
signal hr_readdata      : std_logic_vector(15 downto 0);
signal hr_readdatavalid : std_logic;
signal hr_waitrequest   : std_logic;

signal hr_rwds_in       : std_logic;
signal hr_rwds_out      : std_logic;
signal hr_rwds_oe       : std_logic;   -- Output enable for RWDS
signal hr_dq_in         : std_logic_vector(7 downto 0);
signal hr_dq_out        : std_logic_vector(7 downto 0);
signal hr_dq_oe         : std_logic;   -- Output enable for DQ

-- These values are copied from C64_MiSTerMEGA65/sys/sys_top.v
constant audio_flt_rate : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(7056000, 32));
constant audio_cx       : std_logic_vector(39 downto 0) := std_logic_vector(to_signed(4258969, 40));
constant audio_cx0      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(3, 8));
constant audio_cx1      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(2, 8));
constant audio_cx2      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(1, 8));
constant audio_cy0      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-6216759, 24));
constant audio_cy1      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed( 6143386, 24));
constant audio_cy2      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-2023767, 24));
constant audio_att      : std_logic_vector( 4 downto 0) := "00000";
constant audio_mix      : std_logic_vector( 1 downto 0) := "00"; -- 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

component audio_out
   generic (
      CLK_RATE : natural := 24576000
   );
   port (
      reset       : in  std_logic;
      clk         : in  std_logic;

      -- 0 - 48KHz, 1 - 96KHz
      sample_rate : in  std_logic;

      flt_rate    : in  std_logic_vector(31 downto 0);
      cx          : in  std_logic_vector(39 downto 0);
      cx0         : in  std_logic_vector( 7 downto 0);
      cx1         : in  std_logic_vector( 7 downto 0);
      cx2         : in  std_logic_vector( 7 downto 0);
      cy0         : in  std_logic_vector(23 downto 0);
      cy1         : in  std_logic_vector(23 downto 0);
      cy2         : in  std_logic_vector(23 downto 0);

      att         : in  std_logic_vector( 4 downto 0);
      mix         : in  std_logic_vector( 1 downto 0);

      is_signed   : in  std_logic;
      core_l      : in  std_logic_vector(15 downto 0);
      core_r      : in  std_logic_vector(15 downto 0);

      alsa_l      : in  std_logic_vector(15 downto 0);
      alsa_r      : in  std_logic_vector(15 downto 0);

      -- Signed output
      al          : out std_logic_vector(15 downto 0);
      ar          : out std_logic_vector(15 downto 0)
   );
end component audio_out;

begin

   -- MMCME2_ADV clock generators:
   --   QNICE:                50 MHz
   --   HyperRAM:             100 MHz and 200 MHz
   --   HDMI 720p 50 Hz:      74.25 MHz (HDMI) and 371.25 MHz (TMDS)
   --   @TODO YOURCORE:       54 MHz
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => CLK,             -- expects 100 MHz
         sys_rstn_i        => RESET_M2M_N,     -- Asynchronous, asserted low

         qnice_clk_o       => qnice_clk,       -- QNICE's 50 MHz main clock
         qnice_rst_o       => qnice_rst,       -- QNICE's reset, synchronized

         hr_clk_x1_o       => hr_clk_x1,       -- HyperRAM's 100 MHz
         hr_clk_x2_o       => hr_clk_x2,       -- HyperRAM's 200 MHz
         hr_clk_x2_del_o   => hr_clk_x2_del,   -- HyperRAM's 200 MHz phase delayed
         hr_rst_o          => hr_rst,          -- HyperRAM's reset, synchronized

         audio_clk_o       => audio_clk,       -- Audio's 30 MHz
         audio_rst_o       => audio_rst,       -- Audio's reset, synchronized

         tmds_clk_o        => tmds_clk,        -- HDMI's 371.25 MHz pixelclock (74.25 MHz x 5) for TMDS
         hdmi_clk_o        => hdmi_clk,        -- HDMI's 74.25 MHz pixelclock for 720p @ 50 Hz
         hdmi_rst_o        => hdmi_rst,        -- HDMI's reset, synchronized

         main_clk_o        => main_clk,        -- CORE's 54 MHz clock
         main_rst_o        => main_rst         -- CORE's reset, synchronized
      ); -- clk_gen


   ---------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
      )
      port map (
         clk_main_i           => main_clk,
         reset_soft_i         => core_only_rst,
         reset_hard_i         => main_rst or main_qnice_reset,
         pause_i              => main_qnice_pause,
         flip_joys_i          => '0',

         clk_main_speed_i     => CORE_CLK_SPEED,

         -- M2M Keyboard interface
         kb_key_num_i         => main_key_num,
         kb_key_pressed_n_i   => main_key_pressed_n,

         -- MEGA65 joysticks
         joy_1_up_n_i         => j1_up_n,
         joy_1_down_n_i       => j1_down_n,
         joy_1_left_n_i       => j1_left_n,
         joy_1_right_n_i      => j1_right_n,
         joy_1_fire_n_i       => j1_fire_n,

         joy_2_up_n_i         => j2_up_n,
         joy_2_down_n_i       => j2_down_n,
         joy_2_left_n_i       => j2_left_n,
         joy_2_right_n_i      => j2_right_n,
         joy_2_fire_n_i       => j2_fire_n,

         -- Video output
         -- This is PAL 720x576 @ 50 Hz (pixel clock 27 MHz), but synchronized to main_clk (54 MHz).
         video_ce_o           => main_video_ce,
         video_red_o          => main_video_red,
         video_green_o        => main_video_green,
         video_blue_o         => main_video_blue,
         video_vs_o           => main_video_vs,  -- positive polarity
         video_hs_o           => main_video_hs,  -- positive polarity
         video_hblank_o       => main_video_hblank,
         video_vblank_o       => main_video_vblank,

         -- Audio output (PCM format, signed values)
         audio_left_o         => main_audio_l,
         audio_right_o        => main_audio_r,

         -- Drive led
         drive_led_o          => main_drive_led
      ); -- i_main

   -- M2M keyboard driver that outputs two distinct keyboard states: key_* for being used by the core and qnice_* for the firmware/Shell
   i_m2m_keyb : entity work.m2m_keyb
      port map (
         clk_main_i           => main_clk,
         clk_main_speed_i     => CORE_CLK_SPEED,

         -- interface to the MEGA65 keyboard controller
         kio8_o               => kb_io0,
         kio9_o               => kb_io1,
         kio10_i              => kb_io2,

         -- interface to the core
         enable_core_i        => main_csr_keyboard_on,
         key_num_o            => main_key_num,
         key_pressed_n_o      => main_key_pressed_n,

         -- control the drive led on the MEGA65 keyboard
         drive_led_i          => main_drive_led,

         -- interface to QNICE: used by the firmware and the Shell
         qnice_keys_n_o       => main_qnice_keys_n
      ); -- i_m2m_keyb

   ---------------------------------------------------------------------------------------------
   -- qnice_clk
   ---------------------------------------------------------------------------------------------

   -- QNICE Co-Processor (System-on-a-Chip) for ROM loading and On-Screen-Menu
   QNICE_SOC : entity work.QNICE
      generic map (
         G_FIRMWARE              => QNICE_FIRMWARE,
         G_VGA_DX                => VGA_DX,
         G_VGA_DY                => VGA_DY,
         G_FONT_DX               => FONT_DX,
         G_FONT_DY               => FONT_DY
      )
      port map (
         clk50_i                 => qnice_clk,
         reset_n_i               => not qnice_rst,

         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         uart_rxd_i              => UART_RXD,
         uart_txd_o              => UART_TXD,

         -- SD Card (internal on bottom)
         sd_reset_o              => SD_RESET,
         sd_clk_o                => SD_CLK,
         sd_mosi_o               => SD_MOSI,
         sd_miso_i               => SD_MISO,
         sd_cd_i                 => SD_CD,

         -- SD Card (external on back)
         sd2_reset_o             => SD2_RESET,
         sd2_clk_o               => SD2_CLK,
         sd2_mosi_o              => SD2_MOSI,
         sd2_miso_i              => SD2_MISO,
         sd2_cd_i                => SD2_CD,

         -- QNICE public registers
         csr_reset_o             => qnice_csr_reset,
         csr_pause_o             => qnice_csr_pause,
         csr_osm_o               => qnice_osm_cfg_enable,
         csr_keyboard_o          => qnice_csr_keyboard_on,
         csr_joy1_o              => qnice_csr_joy1_on,
         csr_joy2_o              => qnice_csr_joy2_on,
         osm_xy_o                => qnice_osm_cfg_xy,
         osm_dxdy_o              => qnice_osm_cfg_dxdy,
         
         ascal_mode_i            => "00" & qnice_osm_control_m(C_MENU_CRT_EMULATION) & "00",
         ascal_mode_o            => qnice_ascal_mode,

         -- Keyboard input for the firmware and Shell (see sysdef.asm)
         keys_n_i                => qnice_qnice_keys_n,

         -- 256-bit General purpose control flags
         -- "d" = directly controled by the firmware
         -- "m" = indirectly controled by the menu system
         control_d_o             => open,
         control_m_o             => qnice_osm_control_m,
         
         -- 16-bit special-purpose and 16-bit general-purpose input flags 
         -- Special-purpose flags are having a given semantic when the "Shell" firmware is running,
         -- but right now they are reserved and not used, yet.
         special_i               => (others => '0'),
         general_i               => (others => '0'),            

         -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
         -- ramrom_dev_o: 0 = VRAM data, 1 = VRAM attributes, > 256 = free to be used for any "RAM like" device
         -- ramrom_addr_o is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         ramrom_dev_o            => qnice_ramrom_dev,
         ramrom_addr_o           => qnice_ramrom_addr,
         ramrom_data_o           => qnice_ramrom_data_o,
         ramrom_data_i           => qnice_ramrom_data_i,
         ramrom_ce_o             => qnice_ramrom_ce,
         ramrom_we_o             => qnice_ramrom_we
      ); -- QNICE_SOC

   shell_cfg : entity work.config
      port map (
         -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
         -- bits 11 downto 0: address the up to 4k the configuration data
         address_i               => qnice_ramrom_addr,

         -- config data
         data_o                  => qnice_config_data
      ); -- shell_cfg

   -- The device selector qnice_ramrom_dev decides, which RAM/ROM-like device QNICE is writing to.
   -- Device numbers < 256 are reserved for QNICE; everything else can be used by your MiSTer core.
   qnice_ramrom_devices : process(all)
   begin
      -- MiSTer2MEGA65 reserved
      qnice_vram_we        <= '0';
      qnice_vram_attr_we   <= '0';
      qnice_ramrom_data_i  <= x"EEEE";
      qnice_poly_wr        <= '0';

      -- Demo core specific: Delete before starting to port your core
      qnice_demo_vd_ce     <= '0';
      qnice_demo_vd_we     <= '0';       

      case qnice_ramrom_dev is
         ----------------------------------------------------------------------------
         -- MiSTer2MEGA65 reserved devices with device numbers < 0x0100
         -- (refer to M2M/rom/sysdef.asm for a memory map and more details)
         ----------------------------------------------------------------------------
         
         -- On-Screen-Menu (OSM) video ram data and attributes 
         when C_DEV_VRAM_DATA =>
            qnice_vram_we              <= qnice_ramrom_we;
            qnice_ramrom_data_i        <= x"00" & qnice_vram_data(7 downto 0);
         when C_DEV_VRAM_ATTR =>
            qnice_vram_attr_we         <= qnice_ramrom_we;
            qnice_ramrom_data_i        <= x"00" & qnice_vram_data(15 downto 8);

         -- Shell configuration data (config.vhd)
         when C_DEV_OSM_CONFIG =>
            qnice_ramrom_data_i        <= qnice_config_data;
        
         -- ascal.vhd's polyphase handling
         when C_DEV_ASCAL_PPHASE =>
            qnice_ramrom_data_i        <= x"EEEE"; -- write-only
            qnice_poly_wr              <= qnice_ramrom_we;

         -- Read-only System Info (constants are defined in sysdef.asm)
         when C_DEV_SYS_INFO =>
            case qnice_ramrom_addr(27 downto 12) is
               -- Virtual drives
               when x"0000" =>
                  case qnice_ramrom_addr(11 downto 0) is
                     when x"000" => qnice_ramrom_data_i <= std_logic_vector(to_unsigned(C_VDNUM, 16));
                     when x"001" => qnice_ramrom_data_i <= C_VD_DEVICE;

                     when others =>
                        if qnice_ramrom_addr(11 downto 4) = x"10" then
                           qnice_ramrom_data_i <= C_VD_BUFFER(to_integer(unsigned(qnice_ramrom_addr(3 downto 0))));
                        end if;

                  end case;

               -- Graphics card VGA
               when X"0010" =>
                  case qnice_ramrom_addr(11 downto 0) is
                     when X"000" => qnice_ramrom_data_i <= sys_info_vga(15 downto  0);
                     when X"001" => qnice_ramrom_data_i <= sys_info_vga(31 downto 16);
                     when X"002" => qnice_ramrom_data_i <= sys_info_vga(47 downto 32);
                     when others => null;
                  end case;

               -- Graphics card HDMI
               when X"0011" =>
                  case qnice_ramrom_addr(11 downto 0) is
                     when X"000" => qnice_ramrom_data_i <= sys_info_hdmi(15 downto  0);
                     when X"001" => qnice_ramrom_data_i <= sys_info_hdmi(31 downto 16);
                     when X"002" => qnice_ramrom_data_i <= sys_info_hdmi(47 downto 32);
                     when others => null;
                  end case;

               when others => null;
            end case;

         ----------------------------------------------------------------------------
         -- Core specific devices
         ----------------------------------------------------------------------------
         
         -- Demo core specific stuff: delete before porting your own core
         when C_DEV_DEMO_VD =>
            qnice_demo_vd_ce     <= qnice_ramrom_ce;
            qnice_demo_vd_we     <= qnice_ramrom_we;
            qnice_ramrom_data_i  <= qnice_demo_vd_data_o; 
         
         -- @TODO YOUR RAMs or ROMs (e.g. for cartridges)
         -- Device numbers need to be >= 0x0100

         when others => null;
      end case;
   end process qnice_ramrom_devices;

   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   -- Clock domain crossing: 100 MHz system main clock to core
   i_system2main: xpm_cdc_array_single
      generic map (
         WIDTH => 11
      )
      port map (
         src_clk                => CLK,
         src_in(0)              => not RESET_CORE_N,
         src_in(1)              => joy_1_up_n,
         src_in(2)              => joy_1_down_n,
         src_in(3)              => joy_1_left_n,
         src_in(4)              => joy_1_right_n,
         src_in(5)              => joy_1_fire_n,
         src_in(6)              => joy_2_up_n,
         src_in(7)              => joy_2_down_n,
         src_in(8)              => joy_2_left_n,
         src_in(9)              => joy_2_right_n,
         src_in(10)             => joy_2_fire_n,         
         dest_clk               => main_clk,
         dest_out(0)            => core_only_rst,
         dest_out(1)            => j1_up_n,
         dest_out(2)            => j1_down_n,
         dest_out(3)            => j1_left_n,
         dest_out(4)            => j1_right_n,
         dest_out(5)            => j1_fire_n,
         dest_out(6)            => j2_up_n,
         dest_out(7)            => j2_down_n,
         dest_out(8)            => j2_left_n,
         dest_out(9)            => j2_right_n,
         dest_out(10)           => j2_fire_n
      );

   -- IMPORTANT THING TO PONDER AROUND DUAL-CLOCK / DUAL-PORT DEVICES SUCH AS BRAMs:
   --
   -- We might want to make sure, that all dual port dual clock RAMs here that are interacting
   -- with QNICE are rising-edge only, so that we have 20ns time versus the 10ns that are
   -- available due to the "mixed mode" of QNICE needing falling-edge and other parts of
   -- M2M need rising-edge.
   --
   -- Example: gbc4mega65 Cartridge RAM, where we ran into timing closure problems due to this.
   -- Back then, this was solved by adjusting the FPGA speed grade to the right value (-2) and
   -- "luck" due to Vivado picking the right routing optimization strategy.
   --
   -- Possible solution that does not need QNICE changes: In the MMIO-MUX part, introduce
   -- a delay for QNICE when accessing anything via the "0x7000 device system" using the
   -- WAIT_FOR_DATA mechanism. Something like this untested/unproven sketech of code:
   --     process delay_cart_rom : process (clk50)
   --     begin
   --        if rising_edge(clk50) then
   --          if WAIT = '1' then
   --              WAIT <= '0';
   --         elsif gbc_cart_en = '1' then
   --              WAIT <= '1';
   --         end if;
   --     end process;
   -- When doing this, one needs to check QNICE's internal address bus timing to see, if
   -- gbc_cart_en is asserted long enough to still work after this delay. And if not,
   -- some mechanism to compensate for this needs to be found. And of course it might be
   -- that the above-mentioned code is "too slow" (setting WAIT one cycle too late). The
   -- whole thing needs some serious brain-power-investment to be solved.
   --
   -- Advantage: Will make the whole design more robust and less prone to timing closure problems.
   --
   -- Disadvantage: Slower QNICE access to "0x7000 devices"; but as it can be seen at the time
   -- of writing this, this should not be a problem because most of the tasks QNICE does outside
   -- SD card access for mounted floppies and other devices is not realtime and therefore not
   -- timing critical. If this changed, we might introduce "high-speed" devices that are using
   -- the falling-edge and that work without WAIT_FOR_DATA.

   -- Clock domain crossing: QNICE to core
   i_qnice2main: xpm_cdc_array_single
      generic map (
         WIDTH => 261
      )
      port map (
         src_clk                => qnice_clk,
         src_in(0)              => qnice_csr_reset,
         src_in(1)              => qnice_csr_pause,
         src_in(2)              => qnice_csr_keyboard_on,
         src_in(3)              => qnice_csr_joy1_on,
         src_in(4)              => qnice_csr_joy2_on,
         src_in(260 downto 5)   => qnice_osm_control_m,
         dest_clk               => main_clk,
         dest_out(0)            => main_qnice_reset,
         dest_out(1)            => main_qnice_pause,
         dest_out(2)            => main_csr_keyboard_on,
         dest_out(3)            => main_csr_joy1_on,
         dest_out(4)            => main_csr_joy2_on,
         dest_out(260 downto 5) => main_osm_control_m
      ); -- i_qnice2main

   -- Clock domain crossing: core to QNICE
   i_main2qnice: xpm_cdc_array_single
      generic map (
         WIDTH => 16
      )
      port map (
         src_clk                => main_clk,
         src_in(15 downto 0)    => main_qnice_keys_n,
         dest_clk               => qnice_clk,
         dest_out(15 downto 0)  => qnice_qnice_keys_n
      ); -- i_main2qnice

   -- Clock domain crossing: QNICE to VGA QNICE-On-Screen-Display
   i_qnice2video: xpm_cdc_array_single
      generic map (
         WIDTH => 33
      )
      port map (
         src_clk                => qnice_clk,
         src_in(15 downto 0)    => qnice_osm_cfg_xy,
         src_in(31 downto 16)   => qnice_osm_cfg_dxdy,
         src_in(32)             => qnice_osm_cfg_enable,
         dest_clk               => main_clk,
         dest_out(15 downto 0)  => main_osm_cfg_xy,
         dest_out(31 downto 16) => main_osm_cfg_dxdy,
         dest_out(32)           => main_osm_cfg_enable
      ); -- i_qnice2video

   -- Clock domain crossing: QNICE to HDMI QNICE-On-Screen-Display
   i_qnice2hdmi: xpm_cdc_array_single
      generic map (
         WIDTH => 289
      )
      port map (
         src_clk                 => qnice_clk,
         src_in(15 downto 0)     => qnice_osm_cfg_xy,
         src_in(31 downto 16)    => qnice_osm_cfg_dxdy,
         src_in(32)              => qnice_osm_cfg_enable,
         src_in(288 downto 33)   => qnice_osm_control_m,
         dest_clk                => hdmi_clk,
         dest_out(15 downto 0)   => hdmi_osm_cfg_xy,
         dest_out(31 downto 16)  => hdmi_osm_cfg_dxdy,
         dest_out(32)            => hdmi_osm_cfg_enable,
         dest_out(288 downto 33) => hdmi_osm_control_m
      ); -- i_qnice2hdmi

   i_osm_vram_vga : entity work.dualport_2clk_ram_byteenable
      generic map (
         G_ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         G_DATA_WIDTH   => 16,
         G_FALLING_A    => true  -- QNICE expects read/write to happen at the falling clock edge
      )
      port map
      (
         a_clk_i        => qnice_clk,
         a_address_i    => qnice_ramrom_addr(VRAM_ADDR_WIDTH-1 downto 0),
         a_data_i       => qnice_ramrom_data_o(7 downto 0) & qnice_ramrom_data_o(7 downto 0),   -- 2 copies of the same data
         a_wren_i       => qnice_vram_we or qnice_vram_attr_we,
         a_byteenable_i => qnice_vram_attr_we & qnice_vram_we,
         a_q_o          => qnice_vram_data,

         b_clk_i        => main_clk,
         b_address_i    => main_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         b_q_o          => main_osm_vram_data
      ); -- i_osm_vram_vga

   -- QNICE-On-Screen-Display Video RAM for HDMI output
   i_osm_vram_hdmi : entity work.dualport_2clk_ram_byteenable
      generic map (
         G_ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         G_DATA_WIDTH   => 16,
         G_FALLING_A    => true  -- QNICE expects read/write to happen at the falling clock edge
      )
      port map
      (
         a_clk_i        => qnice_clk,
         a_address_i    => qnice_ramrom_addr(VRAM_ADDR_WIDTH-1 downto 0),
         a_data_i       => qnice_ramrom_data_o(7 downto 0) & qnice_ramrom_data_o(7 downto 0),   -- 2 copies of the same data
         a_wren_i       => qnice_vram_we or qnice_vram_attr_we,
         a_byteenable_i => qnice_vram_attr_we & qnice_vram_we,
         a_q_o          => open, -- TBD

         b_clk_i        => hdmi_clk,
         b_address_i    => hdmi_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         b_q_o          => hdmi_osm_vram_data
      ); -- i_osm_vram_hdmi

   --------------------------------------------------------
   -- Audio and Video processing pipeline
   --------------------------------------------------------

   i_audio_out : audio_out
      generic map (
         CLK_RATE => 30_000_000
      )
      port map (
         reset       => audio_rst,
         clk         => audio_clk,

         sample_rate => '0', -- 0 - 48KHz, 1 - 96KHz

         flt_rate    => audio_flt_rate,
         cx          => audio_cx,
         cx0         => audio_cx0,
         cx1         => audio_cx1,
         cx2         => audio_cx2,
         cy0         => audio_cy0,
         cy1         => audio_cy1,
         cy2         => audio_cy2,
         att         => audio_att,
         mix         => audio_mix,

         is_signed   => '1',
         core_l      => std_logic_vector(main_audio_l),
         core_r      => std_logic_vector(main_audio_r),

         alsa_l      => (others => '0'),
         alsa_r      => (others => '0'),

         -- Signed output
         al          => filt_audio_l,
         ar          => filt_audio_r
      ); -- i_audio_out

   audio_l <= filt_audio_l when qnice_osm_control_m(C_MENU_IMPROVE_AUDIO) = '1' else std_logic_vector(main_audio_l);
   audio_r <= filt_audio_r when qnice_osm_control_m(C_MENU_IMPROVE_AUDIO) = '1' else std_logic_vector(main_audio_r);

   i_analog_pipeline : entity work.analog_pipeline
      generic map (
         G_VGA_DX            => VGA_DX,
         G_VGA_DY            => VGA_DY,
         G_FONT_FILE         => FONT_FILE,
         G_FONT_DX           => FONT_DX,
         G_FONT_DY           => FONT_DY
      )
      port map (
         -- Input from Core (video and audio)
         video_clk_i              => main_clk,
         video_rst_i              => main_rst,
         video_ce_i               => main_video_ce,
         video_red_i              => main_video_red,
         video_green_i            => main_video_green,
         video_blue_i             => main_video_blue,
         video_hs_i               => main_video_hs,
         video_vs_i               => main_video_vs,
         video_hblank_i           => main_video_hblank,
         video_vblank_i           => main_video_vblank,
         audio_clk_i              => audio_clk, -- 30 MHz
         audio_rst_i              => audio_rst,
         audio_left_i             => main_audio_l,
         audio_right_i            => main_audio_r,

         -- Analog output (VGA and audio jack)
         vga_red_o                => vga_red,
         vga_green_o              => vga_green,
         vga_blue_o               => vga_blue,
         vga_hs_o                 => vga_hs,
         vga_vs_o                 => vga_vs,
         vdac_clk_o               => vdac_clk,
         vdac_syncn_o             => vdac_sync_n,
         vdac_blankn_o            => vdac_blank_n,
         pwm_l_o                  => pwm_l,
         pwm_r_o                  => pwm_r,

         -- Connect to QNICE and Video RAM
         video_osm_cfg_enable_i   => main_osm_cfg_enable,
         video_osm_cfg_xy_i       => main_osm_cfg_xy,
         video_osm_cfg_dxdy_i     => main_osm_cfg_dxdy,
         video_osm_vram_addr_o    => main_osm_vram_addr,
         video_osm_vram_data_i    => main_osm_vram_data,
         scandoubler_i            => '0',

         -- System info device
         sys_info_vga_o           => sys_info_vga
      ); -- i_analog_pipeline

   i_crop : entity work.crop
      port map (
         video_crop_mode_i => main_osm_control_m(C_MENU_HDMI_ZOOM),
         video_clk_i       => main_clk,
         video_rst_i       => main_rst,
         video_ce_i        => main_video_ce,
         video_red_i       => main_video_red,
         video_green_i     => main_video_green,
         video_blue_i      => main_video_blue,
         video_hs_i        => main_video_hs,
         video_vs_i        => main_video_vs,
         video_hblank_i    => main_video_hblank,
         video_vblank_i    => main_video_vblank,
         video_ce_o        => main_crop_ce,
         video_red_o       => main_crop_red,
         video_green_o     => main_crop_green,
         video_blue_o      => main_crop_blue,
         video_hs_o        => main_crop_hs,
         video_vs_o        => main_crop_vs,
         video_hblank_o    => main_crop_hblank,
         video_vblank_o    => main_crop_vblank
      ); -- i_crop

   i_digital_pipeline : entity work.digital_pipeline
      generic map (
         G_HDMI_CLK_SPEED    => HDMI_CLK_SPEED,
         G_SHIFT_HDMI        => VIDEO_MODE_VECTOR(0).H_PIXELS - VGA_DX,    -- Deprecated. Will be removed in future release
                                                                           -- The purpose is to right-shift the position of the OSM
                                                                           -- on the HDMI output. This will be removed when the
                                                                           -- M2M framework supports two different OSM VRAMs.
         G_VIDEO_MODE_VECTOR => VIDEO_MODE_VECTOR,
         G_VGA_DX            => VGA_DX,
         G_VGA_DY            => VGA_DY,
         G_FONT_FILE         => FONT_FILE,
         G_FONT_DX           => FONT_DX,
         G_FONT_DY           => FONT_DY
      )
      port map (
         -- Input from Core (video and audio)
         video_clk_i              => main_clk,
         video_rst_i              => main_rst,
         video_ce_i               => main_crop_ce,
         video_red_i              => main_crop_red,
         video_green_i            => main_crop_green,
         video_blue_i             => main_crop_blue,
         video_hs_i               => main_crop_hs,
         video_vs_i               => main_crop_vs,
         video_hblank_i           => main_crop_hblank,
         video_vblank_i           => main_crop_vblank,
         audio_clk_i              => audio_clk, -- 30 MHz
         audio_rst_i              => audio_rst,
         audio_left_i             => main_audio_l,
         audio_right_i            => main_audio_r,

         -- Digital output (HDMI)
         hdmi_clk_i               => hdmi_clk,
         hdmi_rst_i               => hdmi_rst,
         tmds_clk_i               => tmds_clk,
         tmds_data_p_o            => tmds_data_p,
         tmds_data_n_o            => tmds_data_n,
         tmds_clk_p_o             => tmds_clk_p,
         tmds_clk_n_o             => tmds_clk_n,

         -- Connect to QNICE and Video RAM
         hdmi_video_mode_i        => hdmi_osm_control_m(C_MENU_HDMI_60HZ),
         hdmi_crop_mode_i         => main_osm_control_m(C_MENU_HDMI_ZOOM),
         hdmi_osm_cfg_enable_i    => hdmi_osm_cfg_enable,
         hdmi_osm_cfg_xy_i        => hdmi_osm_cfg_xy,
         hdmi_osm_cfg_dxdy_i      => hdmi_osm_cfg_dxdy,
         hdmi_osm_vram_addr_o     => hdmi_osm_vram_addr,
         hdmi_osm_vram_data_i     => hdmi_osm_vram_data,

         -- System info device
         sys_info_hdmi_o          => sys_info_hdmi,

         -- QNICE connection to ascal's mode register
         qnice_ascal_mode_i       => unsigned(qnice_ascal_mode),

         -- QNICE device for interacting with the Polyphase filter coefficients
         qnice_poly_clk_i         => qnice_clk,
         qnice_poly_dw_i          => unsigned(qnice_ramrom_data_o(9 downto 0)),
         qnice_poly_a_i           => unsigned(qnice_ramrom_addr(6+3 downto 0)),
         qnice_poly_wr_i          => qnice_poly_wr,

         -- Connect to HyperRAM controller
         hr_clk_i                 => hr_clk_x1,
         hr_rst_i                 => hr_rst,
         hr_write_o               => hr_write,
         hr_read_o                => hr_read,
         hr_address_o             => hr_address,
         hr_writedata_o           => hr_writedata,
         hr_byteenable_o          => hr_byteenable,
         hr_burstcount_o          => hr_burstcount,
         hr_readdata_i            => hr_readdata,
         hr_readdatavalid_i       => hr_readdatavalid,
         hr_waitrequest_i         => hr_waitrequest
      ); -- i_digital_pipeline

   --------------------------------------------------------
   -- Instantiate HyperRAM controller
   --------------------------------------------------------

   i_hyperram : entity work.hyperram
      port map (
         clk_x1_i            => hr_clk_x1,
         clk_x2_i            => hr_clk_x2,
         clk_x2_del_i        => hr_clk_x2_del,
         rst_i               => hr_rst,
         avm_write_i         => hr_write,
         avm_read_i          => hr_read,
         avm_address_i       => hr_address,
         avm_writedata_i     => hr_writedata,
         avm_byteenable_i    => hr_byteenable,
         avm_burstcount_i    => hr_burstcount,
         avm_readdata_o      => hr_readdata,
         avm_readdatavalid_o => hr_readdatavalid,
         avm_waitrequest_o   => hr_waitrequest,
         hr_resetn_o         => hr_reset,
         hr_csn_o            => hr_cs0,
         hr_ck_o             => hr_clk_p,
         hr_rwds_in_i        => hr_rwds_in,
         hr_rwds_out_o       => hr_rwds_out,
         hr_rwds_oe_o        => hr_rwds_oe,
         hr_dq_in_i          => hr_dq_in,
         hr_dq_out_o         => hr_dq_out,
         hr_dq_oe_o          => hr_dq_oe
      ); -- i_hyperram

   -- Tri-state buffers for HyperRAM
   hr_rwds    <= hr_rwds_out when hr_rwds_oe = '1' else 'Z';
   hr_d       <= hr_dq_out   when hr_dq_oe   = '1' else (others => 'Z');
   hr_rwds_in <= hr_rwds;
   hr_dq_in   <= hr_d;

   ---------------------------------------------------------------------------------------
   -- Virtual drive handler
   --
   -- Only added for demo-purposes at this place, so that we can demonstrate the
   -- firmware's ability to browse files and folders. It is very likely, that the
   -- virtual drive handler needs to be placed somewhere else, for example inside
   -- main.vhd. We advise to delete this before starting to port a core and re-adding
   -- it later (and at the right place), if and when needed.
   ---------------------------------------------------------------------------------------

   i_vdrives : entity work.vdrives
      generic map (
         VDNUM       => C_VDNUM
      )
      port map
      (
         clk_qnice_i       => qnice_clk,
         clk_core_i        => main_clk,
         reset_core_i      => main_rst or main_qnice_reset,
      
         -- Core clock domain
         img_mounted_o     => open,
         img_readonly_o    => open,
         img_size_o        => open,
         img_type_o        => open,
         drive_mounted_o   => open,
         
         -- QNICE clock domain
               
         sd_lba_i          => (others => (others => '0')),
         sd_blk_cnt_i      => (others => (others => '0')),
         sd_rd_i           => (others => '0'),
         sd_wr_i           => (others => '0'),
         sd_ack_o          => open, 
      
         sd_buff_addr_o    => open,
         sd_buff_dout_o    => open,
         sd_buff_din_i     => (others => (others => '0')),
         sd_buff_wr_o      => open,
         
         -- QNICE interface (MMIO, 4k-segmented)
         -- qnice_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         qnice_addr_i      => qnice_ramrom_addr,
         qnice_data_i      => qnice_ramrom_data_o,
         qnice_data_o      => qnice_demo_vd_data_o,
         qnice_ce_i        => qnice_demo_vd_ce,
         qnice_we_i        => qnice_demo_vd_we  
      );

end architecture beh;
