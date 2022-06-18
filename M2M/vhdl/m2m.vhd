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

entity m2m is
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
   hr_cs0         : out std_logic
);
end entity m2m;

architecture synthesis of m2m is

signal main_clk    : std_logic;
signal main_rst    : std_logic;
signal reset_m2m_n : std_logic;
signal qnice_clk   : std_logic;

--------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- QNICE control and status register
signal main_qnice_reset       : std_logic;
signal main_qnice_pause       : std_logic;

signal main_reset_m2m         : std_logic;
signal main_reset_core        : std_logic;

-- keyboard handling
signal main_key_num           : integer range 0 to 79;
signal main_key_pressed_n     : std_logic;

-- QNICE On Screen Menu selections
signal main_osm_control_m     : std_logic_vector(255 downto 0);

-- signed audio from the core
-- if the core outputs unsigned audio, make sure you convert properly to prevent a loss in audio quality
signal main_audio_l           : signed(15 downto 0);
signal main_audio_r           : signed(15 downto 0);

-- Video output from Core
signal main_video_ce          : std_logic;
signal main_video_red         : std_logic_vector(7 downto 0);
signal main_video_green       : std_logic_vector(7 downto 0);
signal main_video_blue        : std_logic_vector(7 downto 0);
signal main_video_vs          : std_logic;
signal main_video_hs          : std_logic;
signal main_video_hblank      : std_logic;
signal main_video_vblank      : std_logic;

-- Joysticks
signal main_joy1_up_n         : std_logic;
signal main_joy1_down_n       : std_logic;
signal main_joy1_left_n       : std_logic;
signal main_joy1_right_n      : std_logic;
signal main_joy1_fire_n       : std_logic;

signal main_joy2_up_n         : std_logic;
signal main_joy2_down_n       : std_logic;
signal main_joy2_left_n       : std_logic;
signal main_joy2_right_n      : std_logic;
signal main_joy2_fire_n       : std_logic;

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

-- Video and audio mode control
signal qnice_dvi              : std_logic;
signal qnice_video_mode       : std_logic;
signal qnice_audio_mute       : std_logic;
signal qnice_audio_filter     : std_logic;
signal qnice_zoom_crop        : std_logic;
signal qnice_ascal_mode       : std_logic_vector(1 downto 0);
signal qnice_ascal_polyphase  : std_logic;
signal qnice_ascal_triplebuf  : std_logic;

-- flip joystick ports
signal qnice_flip_joyports    : std_logic;

-- QNICE On Screen Menu selections
signal qnice_osm_control_m    : std_logic_vector(255 downto 0);

-- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
-- ramrom_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
signal qnice_ramrom_dev       : std_logic_vector(15 downto 0);
signal qnice_ramrom_addr      : std_logic_vector(27 downto 0);
signal qnice_ramrom_data_o    : std_logic_vector(15 downto 0);
signal qnice_ramrom_data_i    : std_logic_vector(15 downto 0);
signal qnice_ramrom_ce        : std_logic;
signal qnice_ramrom_we        : std_logic;

begin

   i_framework : entity work.framework
   port map (
      -- Connect to I/O ports
      CLK                     => CLK,
      max10_tx                => max10_tx,
      max10_rx                => max10_rx,
      max10_clkandsync        => max10_clkandsync,
      UART_RXD                => UART_RXD,
      UART_TXD                => UART_TXD,
      VGA_RED                 => VGA_RED,
      VGA_GREEN               => VGA_GREEN,
      VGA_BLUE                => VGA_BLUE,
      VGA_HS                  => VGA_HS,
      VGA_VS                  => VGA_VS,
      vdac_clk                => vdac_clk,
      vdac_sync_n             => vdac_sync_n,
      vdac_blank_n            => vdac_blank_n,
      tmds_data_p             => tmds_data_p,
      tmds_data_n             => tmds_data_n,
      tmds_clk_p              => tmds_clk_p,
      tmds_clk_n              => tmds_clk_n,
      kb_io0                  => kb_io0,
      kb_io1                  => kb_io1,
      kb_io2                  => kb_io2,
      SD_RESET                => SD_RESET,
      SD_CLK                  => SD_CLK,
      SD_MOSI                 => SD_MOSI,
      SD_MISO                 => SD_MISO,
      SD_CD                   => SD_CD,
      SD2_RESET               => SD2_RESET,
      SD2_CLK                 => SD2_CLK,
      SD2_MOSI                => SD2_MOSI,
      SD2_MISO                => SD2_MISO,
      SD2_CD                  => SD2_CD,
      pwm_l                   => pwm_l,
      pwm_r                   => pwm_r,
      joy_1_up_n              => joy_1_up_n,
      joy_1_down_n            => joy_1_down_n,
      joy_1_left_n            => joy_1_left_n,
      joy_1_right_n           => joy_1_right_n,
      joy_1_fire_n            => joy_1_fire_n,
      joy_2_up_n              => joy_2_up_n,
      joy_2_down_n            => joy_2_down_n,
      joy_2_left_n            => joy_2_left_n,
      joy_2_right_n           => joy_2_right_n,
      joy_2_fire_n            => joy_2_fire_n,
      hr_d                    => hr_d,
      hr_rwds                 => hr_rwds,
      hr_reset                => hr_reset,
      hr_clk_p                => hr_clk_p,
      hr_cs0                  => hr_cs0,

      -- Connect to CORE
      qnice_clk_o             => qnice_clk,
      reset_m2m_n_o           => reset_m2m_n,
      main_clk_i              => main_clk,
      main_rst_i              => main_rst,
      main_qnice_reset_o      => main_qnice_reset,
      main_qnice_pause_o      => main_qnice_pause,
      main_reset_m2m_o        => main_reset_m2m,
      main_reset_core_o       => main_reset_core,
      main_key_num_o          => main_key_num,
      main_key_pressed_n_o    => main_key_pressed_n,
      main_osm_control_m_o    => main_osm_control_m,
      main_audio_l_i          => main_audio_l,
      main_audio_r_i          => main_audio_r,
      main_video_ce_i         => main_video_ce,
      main_video_red_i        => main_video_red,
      main_video_green_i      => main_video_green,
      main_video_blue_i       => main_video_blue,
      main_video_vs_i         => main_video_vs,
      main_video_hs_i         => main_video_hs,
      main_video_hblank_i     => main_video_hblank,
      main_video_vblank_i     => main_video_vblank,
      main_joy1_up_n_o        => main_joy1_up_n,
      main_joy1_down_n_o      => main_joy1_down_n,
      main_joy1_left_n_o      => main_joy1_left_n,
      main_joy1_right_n_o     => main_joy1_right_n,
      main_joy1_fire_n_o      => main_joy1_fire_n,
      main_joy2_up_n_o        => main_joy2_up_n,
      main_joy2_down_n_o      => main_joy2_down_n,
      main_joy2_left_n_o      => main_joy2_left_n,
      main_joy2_right_n_o     => main_joy2_right_n,
      main_joy2_fire_n_o      => main_joy2_fire_n,
      
      -- Connect to QNICE
      qnice_dvi_i             => qnice_dvi,
      qnice_video_mode_i      => qnice_video_mode,
      qnice_audio_mute_i      => qnice_audio_mute,
      qnice_audio_filter_i    => qnice_audio_filter,
      qnice_zoom_crop_i       => qnice_zoom_crop,
      qnice_ascal_mode_i      => qnice_ascal_mode,
      qnice_ascal_polyphase_i => qnice_ascal_polyphase,
      qnice_ascal_triplebuf_i => qnice_ascal_triplebuf,
      qnice_flip_joyports_i   => qnice_flip_joyports,
      qnice_osm_control_m_o   => qnice_osm_control_m,
      qnice_ramrom_dev_o      => qnice_ramrom_dev,
      qnice_ramrom_addr_o     => qnice_ramrom_addr,
      qnice_ramrom_data_out_o => qnice_ramrom_data_o,
      qnice_ramrom_data_in_i  => qnice_ramrom_data_i,
      qnice_ramrom_ce_o       => qnice_ramrom_ce,
      qnice_ramrom_we_o       => qnice_ramrom_we
   ); -- i_framework


   ---------------------------------------------------------------------------------------------------------------
   -- MEGA65 Core including the MiSTer core: Multiple clock domains
   ---------------------------------------------------------------------------------------------------------------

   CORE : entity work.MEGA65_Core
      port map (
         CLK                     => CLK,
         RESET_M2M_N             => reset_m2m_n,

         -- Share clock and reset with the framework
         main_clk_o              => main_clk,            -- CORE's 54 MHz clock
         main_rst_o              => main_rst,            -- CORE's reset, synchronized

         --------------------------------------------------------------------------------------------------------
         -- QNICE Clock Domain
         --------------------------------------------------------------------------------------------------------


         -- Provide QNICE clock to the core: for the vdrives as well as for RAMs and ROMs
         qnice_clk_i             => qnice_clk,

         -- Video and audio mode control
         qnice_dvi_o             => qnice_dvi,
         qnice_video_mode_o      => qnice_video_mode,    -- 720p always; 0 = 50Hz, 1 = 60 Hz
         qnice_audio_mute_o      => qnice_audio_mute,
         qnice_audio_filter_o    => qnice_audio_filter,
         qnice_zoom_crop_o       => qnice_zoom_crop,
         qnice_ascal_mode_o      => qnice_ascal_mode,
         qnice_ascal_polyphase_o => qnice_ascal_polyphase,
         qnice_ascal_triplebuf_o => qnice_ascal_triplebuf,

         -- Flip joystick ports
         qnice_flip_joyports_o   => qnice_flip_joyports,

         -- On-Screen-Menu selections (in QNICE clock domain)
         qnice_osm_control_i     => qnice_osm_control_m,

         -- Core-specific devices
         qnice_dev_id_i          => qnice_ramrom_dev,
         qnice_dev_addr_i        => qnice_ramrom_addr,
         qnice_dev_data_i        => qnice_ramrom_data_o,
         qnice_dev_data_o        => qnice_ramrom_data_i,
         qnice_dev_ce_i          => qnice_ramrom_ce,
         qnice_dev_we_i          => qnice_ramrom_we,

         --------------------------------------------------------------------------------------------------------
         -- Core Clock Domain
         --------------------------------------------------------------------------------------------------------

         -- M2M's reset manager provides 2 signals:
         --    m2m:   Reset the whole machine: Core and Framework
         --    core:  Only reset the core
         main_reset_m2m_i        => main_reset_m2m  or main_qnice_reset or main_rst,
         main_reset_core_i       => main_reset_core or main_qnice_reset,
         main_pause_core_i       => main_qnice_pause,

         -- On-Screen-Menu selections (in main clock domain)
         main_osm_control_i      => main_osm_control_m,

         -- Video output
         main_video_ce_o         => main_video_ce,
         main_video_red_o        => main_video_red,
         main_video_green_o      => main_video_green,
         main_video_blue_o       => main_video_blue,
         main_video_vs_o         => main_video_vs,
         main_video_hs_o         => main_video_hs,
         main_video_hblank_o     => main_video_hblank,
         main_video_vblank_o     => main_video_vblank,

         -- Audio output (Signed PCM)
         main_audio_left_o       => main_audio_l,
         main_audio_right_o      => main_audio_r,

         -- M2M Keyboard interface
         main_kb_key_num_i       => main_key_num,
         main_kb_key_pressed_n_i => main_key_pressed_n,

         -- Joysticks input
         main_joy_1_up_n_i       => main_joy1_up_n,
         main_joy_1_down_n_i     => main_joy1_down_n,
         main_joy_1_left_n_i     => main_joy1_left_n,
         main_joy_1_right_n_i    => main_joy1_right_n,
         main_joy_1_fire_n_i     => main_joy1_fire_n,

         main_joy_2_up_n_i       => main_joy2_up_n,
         main_joy_2_down_n_i     => main_joy2_down_n,
         main_joy_2_left_n_i     => main_joy2_left_n,
         main_joy_2_right_n_i    => main_joy2_right_n,
         main_joy_2_fire_n_i     => main_joy2_right_n
      ); -- CORE

end architecture synthesis;

