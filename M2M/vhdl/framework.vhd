----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Abstraction layer to simplify mega65.vhd
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity framework is
port (
   CLK            : in  std_logic;                  -- 100 MHz clock
   -- MAX10 FPGA (delivers reset)
   max10_tx          : in std_logic;
   max10_rx          : out std_logic;
   max10_clkandsync  : inout std_logic;

   -- Serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in  std_logic;                  -- receive data
   UART_TXD       : out std_logic;                  -- send data

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
   kb_io2         : in  std_logic;                 -- data input from keyboard

   -- SD Card (internal on bottom)
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in  std_logic;
   SD_CD          : in  std_logic;

   -- SD Card (external on back)
   SD2_RESET      : out std_logic;
   SD2_CLK        : out std_logic;
   SD2_MOSI       : out std_logic;
   SD2_MISO       : in  std_logic;
   SD2_CD         : in  std_logic;

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
   hr_cs0         : out std_logic;

   -- Connect to CORE
   qnice_clk_o             : out std_logic;
   reset_m2m_n_o           : out std_logic;
   main_clk_i              : in  std_logic;
   main_rst_i              : in  std_logic;
   main_qnice_reset_o      : out std_logic;
   main_qnice_pause_o      : out std_logic;
   main_reset_m2m_o        : out std_logic;
   main_reset_core_o       : out std_logic;
   main_key_num_o          : out integer range 0 to 79;
   main_key_pressed_n_o    : out std_logic;
   main_drive_led_i        : in  std_logic;
   main_osm_control_m_o    : out std_logic_vector(255 downto 0);
   main_audio_l_i          : in  signed(15 downto 0);
   main_audio_r_i          : in  signed(15 downto 0);
   main_video_ce_i         : in  std_logic;
   main_video_red_i        : in  std_logic_vector(7 downto 0);
   main_video_green_i      : in  std_logic_vector(7 downto 0);
   main_video_blue_i       : in  std_logic_vector(7 downto 0);
   main_video_vs_i         : in  std_logic;
   main_video_hs_i         : in  std_logic;
   main_video_hblank_i     : in  std_logic;
   main_video_vblank_i     : in  std_logic;
   main_joy1_up_n_o        : out std_logic;
   main_joy1_down_n_o      : out std_logic;
   main_joy1_left_n_o      : out std_logic;
   main_joy1_right_n_o     : out std_logic;
   main_joy1_fire_n_o      : out std_logic;
   main_joy2_up_n_o        : out std_logic;
   main_joy2_down_n_o      : out std_logic;
   main_joy2_left_n_o      : out std_logic;
   main_joy2_right_n_o     : out std_logic;
   main_joy2_fire_n_o      : out std_logic;
   
   -- QNICE control signals
   qnice_dvi_i             : in  std_logic;
   qnice_video_mode_i      : in  std_logic;
   qnice_audio_mute_i      : in  std_logic;
   qnice_audio_filter_i    : in  std_logic;
   qnice_zoom_crop_i       : in  std_logic;
   qnice_ascal_mode_i      : in  std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_i : in  std_logic;
   qnice_ascal_triplebuf_i : in  std_logic;
   qnice_flip_joyports_i   : in  std_logic;
   qnice_osm_control_m_o   : out std_logic_vector(255 downto 0);
   
   -- QNICE device management
   qnice_ramrom_dev_o      : out std_logic_vector(15 downto 0);
   qnice_ramrom_addr_o     : out std_logic_vector(27 downto 0);
   qnice_ramrom_data_out_o : out std_logic_vector(15 downto 0);
   qnice_ramrom_data_in_i  : in  std_logic_vector(15 downto 0);
   qnice_ramrom_ce_o       : out std_logic;
   qnice_ramrom_we_o       : out std_logic
);
end entity framework;

architecture synthesis of framework is

---------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------

constant BOARD_CLK_SPEED      : natural := 100_000_000;

-- M2M's strategy on video modes:
-- VGA port: Retro experience, very often a 4:3 aspect ratio and retro-ish resolutions
-- HDMI port: Either 50Hz or 60Hz but always 720p
constant VIDEO_MODE_VECTOR    : video_modes_vector(0 to 1) := (C_HDMI_720p_50, C_HDMI_720p_60);

-- Devices: MiSTer2MEGA framework
constant C_DEV_VRAM_DATA      : std_logic_vector(15 downto 0) := x"0000";
constant C_DEV_VRAM_ATTR      : std_logic_vector(15 downto 0) := x"0001";
constant C_DEV_OSM_CONFIG     : std_logic_vector(15 downto 0) := x"0002";
constant C_DEV_ASCAL_PPHASE   : std_logic_vector(15 downto 0) := x"0003";
constant C_DEV_SYS_INFO       : std_logic_vector(15 downto 0) := x"00FF";

-- SysInfo record numbers
constant C_SYS_DRIVES         : std_logic_vector(15 downto 0) := x"0000";
constant C_SYS_VGA            : std_logic_vector(15 downto 0) := x"0010";
constant C_SYS_HDMI           : std_logic_vector(15 downto 0) := x"0011";

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

signal qnice_rst              : std_logic;
signal hr_rst                 : std_logic;
signal audio_rst              : std_logic;
signal hdmi_rst               : std_logic;

---------------------------------------------------------------------------------------------
-- Reset Control
---------------------------------------------------------------------------------------------

signal reset_n                : std_logic;
signal reset_n_dbnce          : std_logic;
signal reset_core_n           : std_logic;

--------------------------------------------------------------------------------------------
-- CLK (Input clock)
---------------------------------------------------------------------------------------------

-- keyboard handling
signal sys_qnice_keys_n       : std_logic_vector(15 downto 0);
signal sys_csr_keyboard_on    : std_logic;
signal sys_key_num            : integer range 0 to 79;
signal sys_key_pressed_n      : std_logic;
signal sys_drive_led          : std_logic;

--------------------------------------------------------------------------------------------
-- main_clk_i (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- Device management
signal qnice_ramrom_data_in   : std_logic_vector(15 downto 0);

-- QNICE control and status register
signal main_csr_joy1_on       : std_logic;
signal main_csr_joy2_on       : std_logic;
signal main_key_num           : std_logic_vector(7 downto 0);

signal main_zoom_crop         : std_logic;

-- signed audio from the core
-- if the core outputs unsigned audio, make sure you convert properly to prevent a loss in audio quality
signal filt_audio_l           : std_logic_vector(15 downto 0);
signal filt_audio_r           : std_logic_vector(15 downto 0);
signal audio_l                : signed(15 downto 0);
signal audio_r                : signed(15 downto 0);

signal main_crop_ce           : std_logic;
signal main_crop_red          : std_logic_vector(7 downto 0);
signal main_crop_green        : std_logic_vector(7 downto 0);
signal main_crop_blue         : std_logic_vector(7 downto 0);
signal main_crop_hs           : std_logic;
signal main_crop_vs           : std_logic;
signal main_crop_hblank       : std_logic;
signal main_crop_vblank       : std_logic;

-- On-Screen-Menu (OSM) for VGA
signal main_osm_cfg_enable    : std_logic;
signal main_osm_cfg_xy        : std_logic_vector(15 downto 0);
signal main_osm_cfg_dxdy      : std_logic_vector(15 downto 0);
signal main_osm_vram_addr     : std_logic_vector(15 downto 0);
signal main_osm_vram_data     : std_logic_vector(15 downto 0);

--- control signals from QNICE in main's clock domain
signal main_audio_filter      : std_logic;      
signal main_audio_mute        : std_logic;
signal main_flip_joyports     : std_logic;

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

-- Control and status register that QNICE uses to control the Core
signal qnice_csr_reset        : std_logic;
signal qnice_csr_pause        : std_logic;
signal qnice_csr_keyboard_on  : std_logic;
signal qnice_csr_joy1_on      : std_logic;
signal qnice_csr_joy2_on      : std_logic;

-- ascal.vhd mode register and polyphase filter handling
signal qn_ascal_mode          : std_logic_vector(4 downto 0);  -- name qnice_ascal_mode is already taken
signal qnice_poly_wr          : std_logic;

-- VRAM
signal qnice_vram_data        : std_logic_vector(15 downto 0);
signal qnice_vram_we          : std_logic;   -- Writing to bits 7-0
signal qnice_vram_attr_we     : std_logic;   -- Writing to bits 15-8

-- On-Screen-Menu (OSM)
signal qnice_osm_cfg_enable   : std_logic;
signal qnice_osm_cfg_xy       : std_logic_vector(15 downto 0);
signal qnice_osm_cfg_dxdy     : std_logic_vector(15 downto 0);

-- m2m_keyb output for the firmware and the Shell; see also sysdef.asm
signal qnice_qnice_keys_n     : std_logic_vector(15 downto 0);

-- Shell configuration (config.vhd)
signal qnice_config_data      : std_logic_vector(15 downto 0);

---------------------------------------------------------------------------------------------
-- hdmi_clk
---------------------------------------------------------------------------------------------

-- On-Screen-Menu (OSM) for HDMI
signal hdmi_osm_cfg_enable    : std_logic;
signal hdmi_osm_cfg_xy        : std_logic_vector(15 downto 0);
signal hdmi_osm_cfg_dxdy      : std_logic_vector(15 downto 0);
signal hdmi_osm_vram_addr     : std_logic_vector(15 downto 0);
signal hdmi_osm_vram_data     : std_logic_vector(15 downto 0);

signal hdmi_video_mode        : std_logic;
signal hdmi_zoom_crop         : std_logic;

-- QNICE On Screen Menu selections
signal hdmi_osm_control_m     : std_logic_vector(255 downto 0);

---------------------------------------------------------------------------------------------
-- HyperRAM
---------------------------------------------------------------------------------------------

signal hr_write               : std_logic;
signal hr_read                : std_logic;
signal hr_address             : std_logic_vector(31 downto 0) := (others => '0');
signal hr_writedata           : std_logic_vector(15 downto 0);
signal hr_byteenable          : std_logic_vector(1 downto 0);
signal hr_burstcount          : std_logic_vector(7 downto 0);
signal hr_readdata            : std_logic_vector(15 downto 0);
signal hr_readdatavalid       : std_logic;
signal hr_waitrequest         : std_logic;

signal hr_rwds_in             : std_logic;
signal hr_rwds_out            : std_logic;
signal hr_rwds_oe             : std_logic;   -- Output enable for RWDS
signal hr_dq_in               : std_logic_vector(7 downto 0);
signal hr_dq_out              : std_logic_vector(7 downto 0);
signal hr_dq_oe               : std_logic;   -- Output enable for DQ

---------------------------------------------------------------------------------------------
-- MiSTer audio filter
---------------------------------------------------------------------------------------------

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

   qnice_clk_o <= qnice_clk;

   -----------------------------------------------------------------------------------------
   -- MAX10 FPGA handling: extract reset signal
   -----------------------------------------------------------------------------------------

   MAX10 : entity work.max10
      port map (
         pixelclock        => CLK,
         cpuclock          => CLK,
         led               => open,

         max10_rx          => max10_rx,
         max10_tx          => max10_tx,
         max10_clkandsync  => max10_clkandsync,

         max10_fpga_commit => open,
         max10_fpga_date   => open,
         reset_button      => reset_n,
         dipsw             => open,
         j21in             => open,
         j21ddr            => (others => '0'),
         j21out            => (others => '0')
      );
      
   -- 20 ms stable time for the reset button
   i_reset_debouncer : entity work.debounce
      generic map(initial => '1', clk_freq => BOARD_CLK_SPEED, stable_time => 20)
      port map (clk => CLK, reset_n => '1', button => reset_n, result => reset_n_dbnce);

   ---------------------------------------------------------------------------------------------------------------
   -- Generate clocks and reset signals
   ---------------------------------------------------------------------------------------------------------------

   i_clk_m2m : entity work.clk_m2m
      port map (
         sys_clk_i       => CLK,
         sys_rstn_i      => reset_n_dbnce,
         qnice_clk_o     => qnice_clk,
         qnice_rst_o     => qnice_rst,
         hr_clk_x1_o     => hr_clk_x1,
         hr_clk_x2_o     => hr_clk_x2,
         hr_clk_x2_del_o => hr_clk_x2_del,
         hr_rst_o        => hr_rst,
         tmds_clk_o      => tmds_clk,
         hdmi_clk_o      => hdmi_clk,
         hdmi_rst_o      => hdmi_rst,
         audio_clk_o     => audio_clk,
         audio_rst_o     => audio_rst
      ); -- i_clk_m2m

   ---------------------------------------------------------------------------------------------------------------
   -- Board Clock Domain: CLK
   ---------------------------------------------------------------------------------------------------------------

   i_reset_manager : entity work.reset_manager
      generic map (
         BOARD_CLK_SPEED => BOARD_CLK_SPEED
      )
      port map (
         CLK            => CLK,
         RESET_N        => reset_n_dbnce,
         reset_m2m_n_o  => reset_m2m_n_o,
         reset_core_n_o => reset_core_n
      ); -- i_reset_manager

   ---------------------------------------------------------------------------------------------------------------
   -- Core Clock Domain: main_clk_i
   ---------------------------------------------------------------------------------------------------------------

   i_joy_debouncer : entity work.debouncer
      generic map (
         CLK_FREQ             => CORE_CLK_SPEED
      )
      port map (
         clk                  => main_clk_i,
         reset_n              => not main_rst_i,

         flip_joys_i          => main_flip_joyports,
         joy_1_on             => main_csr_joy1_on,
         joy_2_on             => main_csr_joy2_on,

         joy_1_up_n           => joy_1_up_n,
         joy_1_down_n         => joy_1_down_n,
         joy_1_left_n         => joy_1_left_n,
         joy_1_right_n        => joy_1_right_n,
         joy_1_fire_n         => joy_1_fire_n,

         dbnce_joy1_up_n      => main_joy1_up_n_o,
         dbnce_joy1_down_n    => main_joy1_down_n_o,
         dbnce_joy1_left_n    => main_joy1_left_n_o,
         dbnce_joy1_right_n   => main_joy1_right_n_o,
         dbnce_joy1_fire_n    => main_joy1_fire_n_o,

         joy_2_up_n           => joy_2_up_n,
         joy_2_down_n         => joy_2_down_n,
         joy_2_left_n         => joy_2_left_n,
         joy_2_right_n        => joy_2_right_n,
         joy_2_fire_n         => joy_2_fire_n,

         dbnce_joy2_up_n      => main_joy2_up_n_o,
         dbnce_joy2_down_n    => main_joy2_down_n_o,
         dbnce_joy2_left_n    => main_joy2_left_n_o,
         dbnce_joy2_right_n   => main_joy2_right_n_o,
         dbnce_joy2_fire_n    => main_joy2_fire_n_o
      );

   -- M2M keyboard driver that outputs two distinct keyboard states: key_* for being used by the core and qnice_* for the firmware/Shell
   i_m2m_keyb : entity work.m2m_keyb
      port map (
         clk_main_i           => CLK,
         clk_main_speed_i     => 100_000_000,

         -- interface to the MEGA65 keyboard controller
         kio8_o               => kb_io0,
         kio9_o               => kb_io1,
         kio10_i              => kb_io2,

         -- interface to the core
         enable_core_i        => sys_csr_keyboard_on,
         key_num_o            => sys_key_num,
         key_pressed_n_o      => sys_key_pressed_n,

         -- control the drive led on the MEGA65 keyboard
         drive_led_i          => sys_drive_led,

         -- interface to QNICE: used by the firmware and the Shell
         qnice_keys_n_o       => sys_qnice_keys_n
      ); -- i_m2m_keyb

   ---------------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain: qnice_clk
   ---------------------------------------------------------------------------------------------------------------

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

         ascal_mode_i            => "0" & qnice_ascal_triplebuf_i & qnice_ascal_polyphase_i & qnice_ascal_mode_i,
         ascal_mode_o            => qn_ascal_mode,

         -- Keyboard input for the firmware and Shell (see sysdef.asm)
         keys_n_i                => qnice_qnice_keys_n,

         -- 256-bit General purpose control flags
         -- "d" = directly controled by the firmware
         -- "m" = indirectly controled by the menu system
         control_d_o             => open,
         control_m_o             => qnice_osm_control_m_o,

         -- 16-bit special-purpose and 16-bit general-purpose input flags
         -- Special-purpose flags are having a given semantic when the "Shell" firmware is running,
         -- but right now they are reserved and not used, yet.
         special_i               => (others => '0'),
         general_i               => (others => '0'),

         -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
         -- ramrom_dev_o: 0 = VRAM data, 1 = VRAM attributes, > 256 = free to be used for any "RAM like" device
         -- ramrom_addr_o is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         ramrom_dev_o            => qnice_ramrom_dev_o,
         ramrom_addr_o           => qnice_ramrom_addr_o,
         ramrom_data_o           => qnice_ramrom_data_out_o,
         ramrom_data_i           => qnice_ramrom_data_in,
         ramrom_ce_o             => qnice_ramrom_ce_o,
         ramrom_we_o             => qnice_ramrom_we_o
      ); -- QNICE_SOC

   -- Shell configuration file config.vhd
   shell_cfg : entity work.config
      port map (
         -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
         -- bits 11 downto 0: address the up to 4k the configuration data
         address_i               => qnice_ramrom_addr_o,

         -- config data
         data_o                  => qnice_config_data
      ); -- shell_cfg

   -- QNICE devices selected via qnice_ramrom_dev
   --    Devices with IDs < x"0100" are framework devices
   --    All others are user specific / core specific devices
   -- (refer to M2M/rom/sysdef.asm for a memory map and more details)
   qnice_ramrom_devices : process(all)
   begin
      qnice_ramrom_data_in    <= x"EEEE";
      qnice_vram_we           <= '0';
      qnice_vram_attr_we      <= '0';
      qnice_poly_wr           <= '0';

      -----------------------------------
      -- Framework devices
      -----------------------------------
      if qnice_ramrom_dev_o < x"0100" then
         case qnice_ramrom_dev_o is

            -- On-Screen-Menu (OSM) video ram data and attributes
            when C_DEV_VRAM_DATA =>
               qnice_vram_we              <= qnice_ramrom_we_o;
               qnice_ramrom_data_in       <= x"00" & qnice_vram_data(7 downto 0);
            when C_DEV_VRAM_ATTR =>
               qnice_vram_attr_we         <= qnice_ramrom_we_o;
               qnice_ramrom_data_in       <= x"00" & qnice_vram_data(15 downto 8);

            -- Shell configuration data (config.vhd)
            when C_DEV_OSM_CONFIG =>
               qnice_ramrom_data_in       <= qnice_config_data;

            -- ascal.vhd's polyphase handling
            when C_DEV_ASCAL_PPHASE =>
               qnice_ramrom_data_in       <= x"EEEE"; -- write-only
               qnice_poly_wr              <= qnice_ramrom_we_o;

            -- Read-only System Info (constants are defined in sysdef.asm)
            when C_DEV_SYS_INFO =>
               case qnice_ramrom_addr_o(27 downto 12) is

                  -- Virtual drives
                  when C_SYS_DRIVES =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        when x"000" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned(C_VDNUM, 16));
                        when x"001" => qnice_ramrom_data_in <= C_VD_DEVICE;

                        when others =>
                           if qnice_ramrom_addr_o(11 downto 4) = x"10" then
                              qnice_ramrom_data_in <= C_VD_BUFFER(to_integer(unsigned(qnice_ramrom_addr_o(3 downto 0))));
                           end if;
                     end case;

                  -- Graphics card VGA
                  when C_SYS_VGA =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        -- SYS_DXDY
                        when X"000" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        -- SHELL_M_XY: Always start at the top/left corner
                        when X"001" => qnice_ramrom_data_in <= x"0000";

                        -- SHELL_M_DXDY: Use full screen
                        when X"002" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        when others => null;
                     end case;

                  -- Graphics card HDMI
                  when C_SYS_HDMI =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        -- SYS_DXDY
                        when X"000" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        -- SHELL_M_XY: Always start at the top/left corner
                        when X"001" => qnice_ramrom_data_in <= x"0000";

                        -- SHELL_M_DXDY: Use full screen
                        when X"002" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        when others => null;
                     end case;

                  when others => null;
               end case;
            when others => null;
         end case;

      -----------------------------------
      -- User/core specific devices
      -----------------------------------
      else
         qnice_ramrom_data_in <= qnice_ramrom_data_in_i;
      end if;
   end process qnice_ramrom_devices;

   ---------------------------------------------------------------------------------------------------------------
   -- Clock Domain Crossing
   ---------------------------------------------------------------------------------------------------------------

   -- Clock domain crossing: QNICE to core
   i_qnice2main: xpm_cdc_array_single
      generic map (
         WIDTH => 265
      )
      port map (
         src_clk                => qnice_clk,
         src_in(0)              => qnice_csr_reset,
         src_in(1)              => qnice_csr_pause,
         src_in(2)              => '0',
         src_in(3)              => qnice_csr_joy1_on,
         src_in(4)              => qnice_csr_joy2_on,
         src_in(5)              => qnice_flip_joyports_i,
         src_in(6)              => qnice_zoom_crop_i,
         src_in(7)              => qnice_audio_mute_i,
         src_in(8)              => qnice_audio_filter_i,
         src_in(264 downto 9)   => qnice_osm_control_m_o,
         dest_clk               => main_clk_i,
         dest_out(0)            => main_qnice_reset_o,
         dest_out(1)            => main_qnice_pause_o,
         dest_out(2)            => open,
         dest_out(3)            => main_csr_joy1_on,
         dest_out(4)            => main_csr_joy2_on,
         dest_out(5)            => main_flip_joyports,
         dest_out(6)            => main_zoom_crop,
         dest_out(7)            => main_audio_mute,
         dest_out(8)            => main_audio_filter,
         dest_out(264 downto 9) => main_osm_control_m_o
      ); -- i_qnice2main

   -- Clock domain crossing: QNICE to SYS
   i_qnice2sys: xpm_cdc_array_single
      generic map (
         WIDTH => 1
      )
      port map (
         src_clk                => qnice_clk,
         src_in(0)              => qnice_csr_keyboard_on,
         dest_clk               => CLK,
         dest_out(0)            => sys_csr_keyboard_on
      ); -- i_qnice2sys

   -- Clock domain crossing: main to SYS
   i_main2sys: xpm_cdc_array_single
      generic map (
         WIDTH => 1
      )
      port map (
         src_clk                => main_clk_i,
         src_in(0)              => main_drive_led_i,
         dest_clk               => CLK,
         dest_out(0)            => sys_drive_led
      ); -- i_main2sys

   -- Clock domain crossing: SYS to QNICE
   i_sys2qnice: xpm_cdc_array_single
      generic map (
         WIDTH => 16
      )
      port map (
         src_clk                => CLK,
         src_in(15 downto 0)    => sys_qnice_keys_n,
         dest_clk               => qnice_clk,
         dest_out(15 downto 0)  => qnice_qnice_keys_n
      ); -- i_sys2qnice

   -- Clock domain crossing: SYS to QNICE
   i_sys2main: xpm_cdc_array_single
      generic map (
         WIDTH => 9
      )
      port map (
         src_clk              => CLK,
         src_in(7 downto 0)   => std_logic_vector(to_unsigned(sys_key_num, 8)),
         src_in(8)            => sys_key_pressed_n,
         dest_clk             => main_clk_i,
         dest_out(7 downto 0) => main_key_num,
         dest_out(8)          => main_key_pressed_n_o
      ); -- i_sys2main
   main_key_num_o <= to_integer(unsigned(main_key_num));

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
         dest_clk               => main_clk_i,
         dest_out(15 downto 0)  => main_osm_cfg_xy,
         dest_out(31 downto 16) => main_osm_cfg_dxdy,
         dest_out(32)           => main_osm_cfg_enable
      ); -- i_qnice2video

   -- Clock domain crossing: QNICE to HDMI QNICE-On-Screen-Display
   i_qnice2hdmi: xpm_cdc_array_single
      generic map (
         WIDTH => 291
      )
      port map (
         src_clk                 => qnice_clk,
         src_in(15 downto 0)     => qnice_osm_cfg_xy,
         src_in(31 downto 16)    => qnice_osm_cfg_dxdy,
         src_in(32)              => qnice_osm_cfg_enable,
         src_in(33)              => qnice_video_mode_i,
         src_in(34)              => qnice_zoom_crop_i,
         src_in(290 downto 35)   => qnice_osm_control_m_o,
         dest_clk                => hdmi_clk,
         dest_out(15 downto 0)   => hdmi_osm_cfg_xy,
         dest_out(31 downto 16)  => hdmi_osm_cfg_dxdy,
         dest_out(32)            => hdmi_osm_cfg_enable,
         dest_out(33)            => hdmi_video_mode,
         dest_out(34)            => hdmi_zoom_crop,
         dest_out(290 downto 35) => hdmi_osm_control_m
      ); -- i_qnice2hdmi

   -- Clock domain crossing: Board clock domain (CLK) to core (main_clk_i)
   i_board2main: xpm_cdc_array_single
      generic map (
         WIDTH => 2
      )
      port map (
         src_clk                 => CLK,
         src_in(0)               => not reset_m2m_n_o,
         src_in(1)               => not reset_core_n,
         dest_clk                => main_clk_i,
         dest_out(0)             => main_reset_m2m_o,
         dest_out(1)             => main_reset_core_o
      );

   ---------------------------------------------------------------------------------------------------------------
   -- On-Screen-Menu video and attribute RAM: Dual-clock qnice_clk and main_clk_i
   ---------------------------------------------------------------------------------------------------------------

   i_osm_vram_vga : entity work.dualport_2clk_ram_byteenable
      generic map (
         G_ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         G_DATA_WIDTH   => 16,
         G_FALLING_A    => true  -- QNICE expects read/write to happen at the falling clock edge
      )
      port map
      (
         a_clk_i        => qnice_clk,
         a_address_i    => qnice_ramrom_addr_o(VRAM_ADDR_WIDTH-1 downto 0),
         a_data_i       => qnice_ramrom_data_out_o(7 downto 0) & qnice_ramrom_data_out_o(7 downto 0),   -- 2 copies of the same data
         a_wren_i       => qnice_vram_we or qnice_vram_attr_we,
         a_byteenable_i => qnice_vram_attr_we & qnice_vram_we,
         a_q_o          => qnice_vram_data,

         b_clk_i        => main_clk_i,
         b_address_i    => main_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         b_q_o          => main_osm_vram_data
      ); -- i_osm_vram_vga

   i_osm_vram_hdmi : entity work.dualport_2clk_ram_byteenable
      generic map (
         G_ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         G_DATA_WIDTH   => 16,
         G_FALLING_A    => true  -- QNICE expects read/write to happen at the falling clock edge
      )
      port map
      (
         a_clk_i        => qnice_clk,
         a_address_i    => qnice_ramrom_addr_o(VRAM_ADDR_WIDTH-1 downto 0),
         a_data_i       => qnice_ramrom_data_out_o(7 downto 0) & qnice_ramrom_data_out_o(7 downto 0),   -- 2 copies of the same data
         a_wren_i       => qnice_vram_we or qnice_vram_attr_we,
         a_byteenable_i => qnice_vram_attr_we & qnice_vram_we,
         a_q_o          => open, -- TBD

         b_clk_i        => hdmi_clk,
         b_address_i    => hdmi_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         b_q_o          => hdmi_osm_vram_data
      ); -- i_osm_vram_hdmi

   ---------------------------------------------------------------------------------------------------------------
   -- Audio and video processing pipeline: Multiple clock domains
   ---------------------------------------------------------------------------------------------------------------

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
         core_l      => std_logic_vector(main_audio_l_i),
         core_r      => std_logic_vector(main_audio_r_i),

         alsa_l      => (others => '0'),
         alsa_r      => (others => '0'),

         -- Signed output
         al          => filt_audio_l,
         ar          => filt_audio_r
      ); -- i_audio_out

   select_or_mute_audio : process(all)
   begin
      if main_audio_mute = '1' then
         audio_l <= (others => '0');
         audio_r <= (others => '0');
      else
         if main_audio_filter = '0' then
            audio_l <= main_audio_l_i;
            audio_r <= main_audio_r_i;
         else
            audio_l <= signed(filt_audio_l);
            audio_r <= signed(filt_audio_r);
         end if;
      end if;
   end process;

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
         video_clk_i              => main_clk_i,
         video_rst_i              => main_rst_i,
         video_ce_i               => main_video_ce_i,
         video_red_i              => main_video_red_i,
         video_green_i            => main_video_green_i,
         video_blue_i             => main_video_blue_i,
         video_hs_i               => main_video_hs_i,
         video_vs_i               => main_video_vs_i,
         video_hblank_i           => main_video_hblank_i,
         video_vblank_i           => main_video_vblank_i,
         audio_clk_i              => audio_clk, -- 30 MHz
         audio_rst_i              => audio_rst,
         audio_left_i             => audio_l,
         audio_right_i            => audio_r,

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
         scandoubler_i            => '0'
      ); -- i_analog_pipeline

   i_crop : entity work.crop
      port map (
         video_crop_mode_i => main_zoom_crop,
         video_clk_i       => main_clk_i,
         video_rst_i       => main_rst_i,
         video_ce_i        => main_video_ce_i,
         video_red_i       => main_video_red_i,
         video_green_i     => main_video_green_i,
         video_blue_i      => main_video_blue_i,
         video_hs_i        => main_video_hs_i,
         video_vs_i        => main_video_vs_i,
         video_hblank_i    => main_video_hblank_i,
         video_vblank_i    => main_video_vblank_i,
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
         video_clk_i              => main_clk_i,
         video_rst_i              => main_rst_i,
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
         audio_left_i             => audio_l,
         audio_right_i            => audio_r,

         -- Digital output (HDMI)
         hdmi_clk_i               => hdmi_clk,
         hdmi_rst_i               => hdmi_rst,
         tmds_clk_i               => tmds_clk,
         tmds_data_p_o            => tmds_data_p,
         tmds_data_n_o            => tmds_data_n,
         tmds_clk_p_o             => tmds_clk_p,
         tmds_clk_n_o             => tmds_clk_n,

         -- Connect to QNICE and Video RAM
         hdmi_dvi_i               => qnice_dvi_i, -- proper clock domain crossing for this very signal happens inside vga_to_hdmi.vhd
         hdmi_video_mode_i        => hdmi_video_mode,
         hdmi_crop_mode_i         => hdmi_zoom_crop,
         hdmi_osm_cfg_enable_i    => hdmi_osm_cfg_enable,
         hdmi_osm_cfg_xy_i        => hdmi_osm_cfg_xy,
         hdmi_osm_cfg_dxdy_i      => hdmi_osm_cfg_dxdy,
         hdmi_osm_vram_addr_o     => hdmi_osm_vram_addr,
         hdmi_osm_vram_data_i     => hdmi_osm_vram_data,

         -- QNICE connection to ascal's mode register
         qnice_ascal_mode_i       => unsigned(qn_ascal_mode),

         -- QNICE device for interacting with the Polyphase filter coefficients
         qnice_poly_clk_i         => qnice_clk,
         qnice_poly_dw_i          => unsigned(qnice_ramrom_data_out_o(9 downto 0)),
         qnice_poly_a_i           => unsigned(qnice_ramrom_addr_o(6+3 downto 0)),
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

   ---------------------------------------------------------------------------------------------------------------
   -- HyperRAM controller
   ---------------------------------------------------------------------------------------------------------------

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

end architecture synthesis;

