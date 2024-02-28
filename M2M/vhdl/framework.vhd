----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Hardware Abstraction Layer to simplify mega65.vhd
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
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
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   clk_i                   : in    std_logic;                  -- 100 MHz clock
   reset_n_i               : in    std_logic;

   -- Serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   uart_rxd_i              : in    std_logic;                  -- receive data
   uart_txd_o              : out   std_logic;                  -- send data

   -- VGA
   vga_red_o               : out   std_logic_vector(7 downto 0);
   vga_green_o             : out   std_logic_vector(7 downto 0);
   vga_blue_o              : out   std_logic_vector(7 downto 0);
   vga_hs_o                : out   std_logic;
   vga_vs_o                : out   std_logic;

   -- VDAC
   vdac_clk_o              : out   std_logic;
   vdac_sync_n_o           : out   std_logic;
   vdac_blank_n_o          : out   std_logic;

   -- Digital Video (HDMI)
   tmds_data_p_o           : out   std_logic_vector(2 downto 0);
   tmds_data_n_o           : out   std_logic_vector(2 downto 0);
   tmds_clk_p_o            : out   std_logic;
   tmds_clk_n_o            : out   std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0_o                : out   std_logic;                 -- clock to keyboard
   kb_io1_o                : out   std_logic;                 -- data output to keyboard
   kb_io2_i                : in    std_logic;                 -- data input from keyboard

   -- Micro SD Connector (external slot at back of the cover)
   sd_reset_o              : out   std_logic;
   sd_clk_o                : out   std_logic;
   sd_mosi_o               : out   std_logic;
   sd_miso_i               : in    std_logic;
   sd_cd_i                 : in    std_logic;

   -- SD Connector (this is the slot at the bottom side of the case under the cover)
   sd2_reset_o             : out   std_logic;
   sd2_clk_o               : out   std_logic;
   sd2_mosi_o              : out   std_logic;
   sd2_miso_i              : in    std_logic;
   sd2_cd_i                : in    std_logic;

   -- Joysticks and Paddles
   joy_1_up_n_i            : in    std_logic;
   joy_1_down_n_i          : in    std_logic;
   joy_1_left_n_i          : in    std_logic;
   joy_1_right_n_i         : in    std_logic;
   joy_1_fire_n_i          : in    std_logic;
   joy_1_up_n_o            : out   std_logic;
   joy_1_down_n_o          : out   std_logic;
   joy_1_left_n_o          : out   std_logic;
   joy_1_right_n_o         : out   std_logic;
   joy_1_fire_n_o          : out   std_logic;

   joy_2_up_n_i            : in    std_logic;
   joy_2_down_n_i          : in    std_logic;
   joy_2_left_n_i          : in    std_logic;
   joy_2_right_n_i         : in    std_logic;
   joy_2_fire_n_i          : in    std_logic;
   joy_2_up_n_o            : out   std_logic;
   joy_2_down_n_o          : out   std_logic;
   joy_2_left_n_o          : out   std_logic;
   joy_2_right_n_o         : out   std_logic;
   joy_2_fire_n_o          : out   std_logic;

   paddle_i                : in    std_logic_vector(3 downto 0);
   paddle_drain_o          : out   std_logic;

   -- Built-in HyperRAM
   hr_d_io                 : inout std_logic_vector(7 downto 0);    -- Data/Address
   hr_rwds_io              : inout std_logic;               -- RW Data strobe
   hr_reset_o              : out   std_logic;                 -- Active low RESET line to HyperRAM
   hr_clk_p_o              : out   std_logic;
   hr_cs0_o                : out   std_logic;

   -- Connect to CORE
   qnice_clk_o             : out   std_logic;
   qnice_rst_o             : out   std_logic;
   main_clk_i              : in    std_logic;
   main_rst_i              : in    std_logic;
   main_qnice_reset_o      : out   std_logic;
   main_qnice_pause_o      : out   std_logic;
   main_reset_m2m_o        : out   std_logic;
   main_reset_core_o       : out   std_logic;
   main_key_num_o          : out   integer range 0 to 79;
   main_key_pressed_n_o    : out   std_logic;
   main_power_led_i        : in    std_logic;
   main_power_led_col_i    : in    std_logic_vector(23 downto 0);
   main_drive_led_i        : in    std_logic;
   main_drive_led_col_i    : in    std_logic_vector(23 downto 0);
   main_osm_control_m_o    : out   std_logic_vector(255 downto 0);
   main_qnice_gp_reg_o     : out   std_logic_vector(255 downto 0);
   main_audio_l_i          : in    signed(15 downto 0);
   main_audio_r_i          : in    signed(15 downto 0);
   video_clk_i             : in    std_logic;
   video_rst_i             : in    std_logic;
   video_ce_i              : in    std_logic;
   video_ce_ovl_i          : in    std_logic;
   video_red_i             : in    std_logic_vector(7 downto 0);
   video_green_i           : in    std_logic_vector(7 downto 0);
   video_blue_i            : in    std_logic_vector(7 downto 0);
   video_vs_i              : in    std_logic;
   video_hs_i              : in    std_logic;
   video_hblank_i          : in    std_logic;
   video_vblank_i          : in    std_logic;
   main_joy1_up_n_o        : out   std_logic;
   main_joy1_down_n_o      : out   std_logic;
   main_joy1_left_n_o      : out   std_logic;
   main_joy1_right_n_o     : out   std_logic;
   main_joy1_fire_n_o      : out   std_logic;
   main_joy1_up_n_i        : in    std_logic;
   main_joy1_down_n_i      : in    std_logic;
   main_joy1_left_n_i      : in    std_logic;
   main_joy1_right_n_i     : in    std_logic;
   main_joy1_fire_n_i      : in    std_logic;
   main_joy2_up_n_o        : out   std_logic;
   main_joy2_down_n_o      : out   std_logic;
   main_joy2_left_n_o      : out   std_logic;
   main_joy2_right_n_o     : out   std_logic;
   main_joy2_fire_n_o      : out   std_logic;
   main_joy2_up_n_i        : in    std_logic;
   main_joy2_down_n_i      : in    std_logic;
   main_joy2_left_n_i      : in    std_logic;
   main_joy2_right_n_i     : in    std_logic;
   main_joy2_fire_n_i      : in    std_logic;
   main_pot1_x_o           : out   std_logic_vector(7 downto 0);
   main_pot1_y_o           : out   std_logic_vector(7 downto 0);
   main_pot2_x_o           : out   std_logic_vector(7 downto 0);
   main_pot2_y_o           : out   std_logic_vector(7 downto 0);
   main_rtc_o              : out   std_logic_vector(64 downto 0);


   -- Audio
   audio_clk_o             : out   std_logic;
   audio_reset_o           : out   std_logic;
   audio_left_o            : out   signed(15 downto 0);
   audio_right_o           : out   signed(15 downto 0);

   -- Provide HyperRAM to core (in HyperRAM clock domain)
   hr_clk_o                : out   std_logic;
   hr_rst_o                : out   std_logic;
   hr_core_write_i         : in    std_logic;
   hr_core_read_i          : in    std_logic;
   hr_core_address_i       : in    std_logic_vector(31 downto 0);
   hr_core_writedata_i     : in    std_logic_vector(15 downto 0);
   hr_core_byteenable_i    : in    std_logic_vector(1 downto 0);
   hr_core_burstcount_i    : in    std_logic_vector(7 downto 0);
   hr_core_readdata_o      : out   std_logic_vector(15 downto 0);
   hr_core_readdatavalid_o : out   std_logic;
   hr_core_waitrequest_o   : out   std_logic;
   hr_high_o               : out   std_logic; -- Core is too fast
   hr_low_o                : out   std_logic; -- Core is too slow

   -- QNICE control signals
   qnice_dvi_i             : in    std_logic;
   qnice_video_mode_i      : in    video_mode_type;
   qnice_osm_cfg_scaling_i : in    std_logic_vector(8 downto 0);
   qnice_retro15kHz_i      : in    std_logic;
   qnice_scandoubler_i     : in    std_logic;
   qnice_csync_i           : in    std_logic;
   qnice_audio_mute_i      : in    std_logic;
   qnice_audio_filter_i    : in    std_logic;
   qnice_zoom_crop_i       : in    std_logic;
   qnice_ascal_mode_i      : in    std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_i : in    std_logic;
   qnice_ascal_triplebuf_i : in    std_logic;
   qnice_flip_joyports_i   : in    std_logic;
   qnice_osm_control_m_o   : out   std_logic_vector(255 downto 0);
   qnice_gp_reg_o          : out   std_logic_vector(255 downto 0);

   -- QNICE device management
   qnice_ramrom_dev_o      : out   std_logic_vector(15 downto 0);
   qnice_ramrom_addr_o     : out   std_logic_vector(27 downto 0);
   qnice_ramrom_data_out_o : out   std_logic_vector(15 downto 0);
   qnice_ramrom_data_in_i  : in    std_logic_vector(15 downto 0);
   qnice_ramrom_ce_o       : out   std_logic;
   qnice_ramrom_we_o       : out   std_logic;
   qnice_ramrom_wait_i     : in    std_logic;

   hdmi_scl_io             : inout std_logic;
   hdmi_sda_io             : inout std_logic;

   vga_scl_io              : inout std_logic;
   vga_sda_io              : inout std_logic;

   audio_scl_io            : inout std_logic;
   audio_sda_io            : inout std_logic;

   -- I2C bus
   -- U32 = PCA9655EMTTXG. Address 0x40. I/O expander.
   -- U12 = MP8869SGL-Z.   Address 0x61. DC/DC Converter.
   -- U14 = MP8869SGL-Z.   Address 0x67. DC/DC Converter.
   i2c_scl_io              : inout std_logic;
   i2c_sda_io              : inout std_logic;

   -- PMOD I2C device
   -- Connected to J18
   grove_sda_io            : inout std_logic;
   grove_scl_io            : inout std_logic;

   -- I2C bus for on-board peripherals
   -- U36. 24AA025E48T. Address 0x50. 2K Serial EEPROM.
   -- U38. RV-3032-C7.  Address 0x51. Real-Time Clock Module.
   -- U39. 24LC128.     Address 0x56. 128K CMOS Serial EEPROM.
   fpga_sda_io             : inout std_logic;
   fpga_scl_io             : inout std_logic
);
end entity framework;

architecture synthesis of framework is

---------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------

constant VIDEO_MODE_VECTOR    : video_modes_vector(0 to 6) := (
   C_HDMI_720p_50,        -- HDMI 1280x720   @ 50 Hz
   C_HDMI_720p_60,        -- 1280x720        @ 60 Hz
   C_HDMI_576p_50,        -- PAL 576p in 4:3 @ 50 Hz
   C_HDMI_576p_50,        -- PAL 576p in 5:4 @ 50 Hz
   C_HDMI_640x480p_60,    -- HDMI 640x480    @ 60 Hz
   C_HDMI_720x480p_5994,  -- HDMI 720x480    @ 59.94 Hz
   C_SVGA_800_600_60);    -- SVGA 800x600    @ 60 Hz

signal video_mode : video_modes_t;

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal qnice_clk              : std_logic;               -- QNICE main clock @ 50 MHz
signal hr_clk                 : std_logic;               -- HyperRAM @ 100 MHz
signal hr_clk_del             : std_logic;               -- HyperRAM @ 100 MHz phase delayed
signal hr_delay_refclk        : std_logic;               -- HyperRAM @ 200 MHz
signal audio_clk              : std_logic;               -- Audio clock @ 60 MHz
signal tmds_clk               : std_logic;               -- HDMI pixel clock at 5x speed for TMDS @ 371.25 MHz
signal hdmi_clk               : std_logic;               -- HDMI pixel clock at normal speed @ 74.25 MHz
signal sys_pps                : std_logic;               -- One pulse per second

signal qnice_rst              : std_logic;
signal hr_rst                 : std_logic;
signal audio_rst              : std_logic;
signal hdmi_rst               : std_logic;

---------------------------------------------------------------------------------------------
-- Reset Control
---------------------------------------------------------------------------------------------

signal reset_core_n           : std_logic;
signal reset_m2m_n            : std_logic;

--------------------------------------------------------------------------------------------
-- main_clk_i (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- QNICE control and status register
signal main_csr_keyboard_on   : std_logic;
signal main_csr_joy1_on       : std_logic;
signal main_csr_joy2_on       : std_logic;

-- keyboard handling
signal main_qnice_keys_n      : std_logic_vector(15 downto 0);

--- control signals from QNICE in main's clock domain
signal main_flip_joyports     : std_logic;

---------------------------------------------------------------------------------------------
-- audio_clk
---------------------------------------------------------------------------------------------

signal audio_left             : std_logic_vector(15 downto 0);
signal audio_right            : std_logic_vector(15 downto 0);

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
signal qnice_ascal_mode       : std_logic_vector(4 downto 0);  -- name qnice_ascal_mode is already taken
signal qnice_poly_wr          : std_logic;

-- VRAM
signal qnice_vram_data        : std_logic_vector(15 downto 0);
signal qnice_vram_we          : std_logic;   -- Writing to bits 7-0
signal qnice_vram_attr_we     : std_logic;   -- Writing to bits 15-8

-- On-Screen-Menu (OSM)
signal qnice_osm_cfg_enable   : std_logic;
signal qnice_osm_cfg_xy       : std_logic_vector(15 downto 0);
signal qnice_osm_cfg_dxdy     : std_logic_vector(15 downto 0);
signal qnice_hdmax            : std_logic_vector(11 downto 0);
signal qnice_vdmax            : std_logic_vector(11 downto 0);
signal qnice_clk_sel          : std_logic_vector( 2 downto 0);

signal qnice_h_pixels         : std_logic_vector(11 downto 0); -- horizontal visible display width in pixels
signal qnice_v_pixels         : std_logic_vector(11 downto 0); -- horizontal visible display width in pixels
signal qnice_h_pulse          : std_logic_vector(11 downto 0); -- horizontal sync pulse width in pixels
signal qnice_h_bp             : std_logic_vector(11 downto 0); -- horizontal back porch width in pixels
signal qnice_h_fp             : std_logic_vector(11 downto 0); -- horizontal front porch width in pixels
signal qnice_v_pulse          : std_logic_vector(11 downto 0); -- horizontal sync pulse width in pixels
signal qnice_v_bp             : std_logic_vector(11 downto 0); -- horizontal back porch width in pixels
signal qnice_v_fp             : std_logic_vector(11 downto 0); -- horizontal front porch width in pixels
signal qnice_h_freq           : std_logic_vector(15 downto 0); -- horizontal sync frequency

-- m2m_keyb output for the firmware and the Shell; see also sysdef.asm
signal qnice_qnice_keys_n     : std_logic_vector(15 downto 0);

-- Paddles in 50 MHz clock domain which happens to be QNICE's
signal qnice_pot1_x_n         : unsigned(7 downto 0);
signal qnice_pot1_y_n         : unsigned(7 downto 0);
signal qnice_pot2_x_n         : unsigned(7 downto 0);
signal qnice_pot2_y_n         : unsigned(7 downto 0);

signal qnice_avm_write         : std_logic;
signal qnice_avm_read          : std_logic;
signal qnice_avm_address       : std_logic_vector(31 downto 0);
signal qnice_avm_writedata     : std_logic_vector(15 downto 0);
signal qnice_avm_byteenable    : std_logic_vector( 1 downto 0);
signal qnice_avm_burstcount    : std_logic_vector( 7 downto 0);
signal qnice_avm_readdata      : std_logic_vector(15 downto 0);
signal qnice_avm_readdatavalid : std_logic;
signal qnice_avm_waitrequest   : std_logic;

signal qnice_pps               : std_logic;
signal qnice_hdmi_clk_freq     : std_logic_vector(27 downto 0);

signal qnice_i2c_wait          : std_logic;
signal qnice_i2c_ce            : std_logic;
signal qnice_i2c_we            : std_logic;
signal qnice_i2c_rd_data       : std_logic_vector(15 downto 0);

signal qnice_rtc_wait          : std_logic;
signal qnice_rtc_ce            : std_logic;
signal qnice_rtc_we            : std_logic;
signal qnice_rtc_rd_data       : std_logic_vector(15 downto 0);

signal qnice_rtc               : std_logic_vector(64 downto 0);

-- Statistics
signal qnice_hr_count_long     : std_logic_vector(31 downto 0);
signal qnice_hr_count_short    : std_logic_vector(31 downto 0);
signal qnice_hr_count_long_d   : std_logic_vector(31 downto 0);
signal qnice_hr_count_short_d  : std_logic_vector(31 downto 0);
signal qnice_hr_count_long_dd  : std_logic_vector(31 downto 0);
signal qnice_hr_count_short_dd : std_logic_vector(31 downto 0);

---------------------------------------------------------------------------------------------
-- HyperRAM
---------------------------------------------------------------------------------------------

-- Digital pipeline's signals to the HyperRAM arbiter
signal hr_dig_write           : std_logic;
signal hr_dig_read            : std_logic;
signal hr_dig_address         : std_logic_vector(31 downto 0) := (others => '0');
signal hr_dig_writedata       : std_logic_vector(15 downto 0);
signal hr_dig_byteenable      : std_logic_vector( 1 downto 0);
signal hr_dig_burstcount      : std_logic_vector( 7 downto 0);
signal hr_dig_readdata        : std_logic_vector(15 downto 0);
signal hr_dig_readdatavalid   : std_logic;
signal hr_dig_waitrequest     : std_logic;

signal hr_qnice_write         : std_logic;
signal hr_qnice_read          : std_logic;
signal hr_qnice_address       : std_logic_vector(31 downto 0) := (others => '0');
signal hr_qnice_writedata     : std_logic_vector(15 downto 0);
signal hr_qnice_byteenable    : std_logic_vector( 1 downto 0);
signal hr_qnice_burstcount    : std_logic_vector( 7 downto 0);
signal hr_qnice_readdata      : std_logic_vector(15 downto 0);
signal hr_qnice_readdatavalid : std_logic;
signal hr_qnice_waitrequest   : std_logic;

-- HyperRAM controller
signal hr_write               : std_logic;
signal hr_read                : std_logic;
signal hr_address             : std_logic_vector(31 downto 0) := (others => '0');
signal hr_writedata           : std_logic_vector(15 downto 0);
signal hr_byteenable          : std_logic_vector( 1 downto 0);
signal hr_burstcount          : std_logic_vector( 7 downto 0);
signal hr_readdata            : std_logic_vector(15 downto 0);
signal hr_readdatavalid       : std_logic;
signal hr_waitrequest         : std_logic;

-- Statistics
signal hr_count_long          : unsigned(31 downto 0);
signal hr_count_short         : unsigned(31 downto 0);

-- Physical layer
signal hr_rwds_in             : std_logic;
signal hr_rwds_out            : std_logic;
signal hr_rwds_oe_n           : std_logic;   -- Output enable for RWDS
signal hr_dq_in               : std_logic_vector(7 downto 0);
signal hr_dq_out              : std_logic_vector(7 downto 0);
signal hr_dq_oe_n             : std_logic_vector(7 downto 0);   -- Output enable for DQ

signal scl_out                : std_logic_vector(7 downto 0);
signal sda_out                : std_logic_vector(7 downto 0);

begin

   ---------------------------------------------------------------------------------------------------------------
   -- Generate clocks and reset signals
   ---------------------------------------------------------------------------------------------------------------

   i_clk_m2m : entity work.clk_m2m
      port map (
         sys_clk_i         => clk_i,
         sys_rstn_i        => reset_m2m_n,        -- reset everything
         core_rstn_i       => reset_core_n,       -- reset only the core (means the HyperRAM needs to be reset, too)
         qnice_clk_o       => qnice_clk,
         qnice_rst_o       => qnice_rst,
         hr_clk_o          => hr_clk,
         hr_clk_del_o      => hr_clk_del,
         hr_delay_refclk_o => hr_delay_refclk,
         hr_rst_o          => hr_rst,
         audio_clk_o       => audio_clk,
         audio_rst_o       => audio_rst,
         sys_pps_o         => sys_pps
      ); -- i_clk_m2m

   video_mode <= C_SVGA_800_600_60    when qnice_video_mode_i = C_VIDEO_SVGA_800_60   else
                 C_HDMI_720x480p_5994 when qnice_video_mode_i = C_VIDEO_HDMI_720_5994 else
                 C_HDMI_640x480p_60   when qnice_video_mode_i = C_VIDEO_HDMI_640_60   else
                 C_HDMI_576p_50       when qnice_video_mode_i = C_VIDEO_HDMI_5_4_50   else
                 C_HDMI_576p_50       when qnice_video_mode_i = C_VIDEO_HDMI_4_3_50   else
                 C_HDMI_720p_60       when qnice_video_mode_i = C_VIDEO_HDMI_16_9_60  else
                 C_HDMI_720p_50;                             -- C_VIDEO_HDMI_16_9_50

   qnice_clk_sel <= video_mode.CLK_SEL;

   -- reconfigurable MMCM: 25.2MHz, 27MHz, 74.25MHz or 148.5MHz
   i_video_out_clock : entity work.video_out_clock
      generic map (
         fref    => 100.0 -- Clock speed in MHz of the input clk_i
      )
      port map (
         rsti    => not reset_m2m_n,
         clki    => clk_i,
         sel     => qnice_clk_sel,
         rsto    => hdmi_rst,
         clko    => hdmi_clk,
         clko_x5 => tmds_clk
      ); -- i_video_out_clock

   hr_clk_o    <= hr_clk;
   hr_rst_o    <= hr_rst;

   qnice_clk_o <= qnice_clk;
   qnice_rst_o <= qnice_rst;

   ---------------------------------------------------------------------------------------------------------------
   -- Board Clock Domain: clk_i
   ---------------------------------------------------------------------------------------------------------------

   i_reset_manager : entity work.reset_manager
      generic map (
         BOARD_CLK_SPEED => BOARD_CLK_SPEED
      )
      port map (
         CLK            => clk_i,
         RESET_N        => reset_n_i,
         reset_m2m_n_o  => reset_m2m_n,
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

         joy_1_up_n           => joy_1_up_n_i,
         joy_1_down_n         => joy_1_down_n_i,
         joy_1_left_n         => joy_1_left_n_i,
         joy_1_right_n        => joy_1_right_n_i,
         joy_1_fire_n         => joy_1_fire_n_i,

         dbnce_joy1_up_n      => main_joy1_up_n_o,
         dbnce_joy1_down_n    => main_joy1_down_n_o,
         dbnce_joy1_left_n    => main_joy1_left_n_o,
         dbnce_joy1_right_n   => main_joy1_right_n_o,
         dbnce_joy1_fire_n    => main_joy1_fire_n_o,

         joy_2_up_n           => joy_2_up_n_i,
         joy_2_down_n         => joy_2_down_n_i,
         joy_2_left_n         => joy_2_left_n_i,
         joy_2_right_n        => joy_2_right_n_i,
         joy_2_fire_n         => joy_2_fire_n_i,

         dbnce_joy2_up_n      => main_joy2_up_n_o,
         dbnce_joy2_down_n    => main_joy2_down_n_o,
         dbnce_joy2_left_n    => main_joy2_left_n_o,
         dbnce_joy2_right_n   => main_joy2_right_n_o,
         dbnce_joy2_fire_n    => main_joy2_fire_n_o
      ); -- i_joy_debouncer

   -- Joystick outputs from the core are connected directly
   joy_1_up_n_o    <= main_joy1_up_n_i;
   joy_1_down_n_o  <= main_joy1_down_n_i;
   joy_1_left_n_o  <= main_joy1_left_n_i;
   joy_1_right_n_o <= main_joy1_right_n_i;
   joy_1_fire_n_o  <= main_joy1_fire_n_i;
   joy_2_up_n_o    <= main_joy2_up_n_i;
   joy_2_down_n_o  <= main_joy2_down_n_i;
   joy_2_left_n_o  <= main_joy2_left_n_i;
   joy_2_right_n_o <= main_joy2_right_n_i;
   joy_2_fire_n_o  <= main_joy2_fire_n_i;


   -- M2M keyboard driver that outputs two distinct keyboard states: key_* for being used by the core and qnice_* for the firmware/Shell
   i_m2m_keyb : entity work.m2m_keyb
      port map (
         clk_main_i           => main_clk_i,
         clk_main_speed_i     => CORE_CLK_SPEED,

         -- interface to the MEGA65 keyboard controller
         kio8_o               => kb_io0_o,
         kio9_o               => kb_io1_o,
         kio10_i              => kb_io2_i,

         -- interface to the core
         enable_core_i        => main_csr_keyboard_on,
         key_num_o            => main_key_num_o,
         key_pressed_n_o      => main_key_pressed_n_o,

         -- control the drive led on the MEGA65 keyboard
         power_led_i          => main_power_led_i,
         power_led_col_i      => main_power_led_col_i,
         drive_led_i          => main_drive_led_i,
         drive_led_col_i      => main_drive_led_col_i,

         -- interface to QNICE: used by the firmware and the Shell
         qnice_keys_n_o       => main_qnice_keys_n
      ); -- i_m2m_keyb

   ---------------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain: qnice_clk
   ---------------------------------------------------------------------------------------------------------------

   i_qnice_wrapper : entity work.qnice_wrapper
   generic map (
      G_BOARD => G_BOARD
   )
   port map (
      clk_i                     => qnice_clk,
      rst_i                     => qnice_rst,
      uart_rxd_i                => uart_rxd_i,
      uart_txd_o                => uart_txd_o,
      sd_reset_o                => sd_reset_o,
      sd_clk_o                  => sd_clk_o,
      sd_mosi_o                 => sd_mosi_o,
      sd_miso_i                 => sd_miso_i,
      sd_cd_i                   => sd_cd_i,
      sd2_reset_o               => sd2_reset_o,
      sd2_clk_o                 => sd2_clk_o,
      sd2_mosi_o                => sd2_mosi_o,
      sd2_miso_i                => sd2_miso_i,
      sd2_cd_i                  => sd2_cd_i,
      paddle_i                  => paddle_i,
      paddle_drain_o            => paddle_drain_o,
      qnice_osm_cfg_enable_o    => qnice_osm_cfg_enable,
      qnice_osm_cfg_xy_o        => qnice_osm_cfg_xy,
      qnice_osm_cfg_dxdy_o      => qnice_osm_cfg_dxdy,
      qnice_hdmax_i             => qnice_hdmax,
      qnice_vdmax_i             => qnice_vdmax,
      qnice_h_pixels_i          => qnice_h_pixels,
      qnice_v_pixels_i          => qnice_v_pixels,
      qnice_h_pulse_i           => qnice_h_pulse,
      qnice_h_bp_i              => qnice_h_bp,
      qnice_h_fp_i              => qnice_h_fp,
      qnice_v_pulse_i           => qnice_v_pulse,
      qnice_v_bp_i              => qnice_v_bp,
      qnice_v_fp_i              => qnice_v_fp,
      qnice_h_freq_i            => qnice_h_freq,
      qnice_ascal_mode_i        => qnice_ascal_mode_i,
      qnice_ascal_polyphase_i   => qnice_ascal_polyphase_i,
      qnice_ascal_triplebuf_i   => qnice_ascal_triplebuf_i,
      qnice_flip_joyports_i     => qnice_flip_joyports_i,
      qnice_osm_control_m_o     => qnice_osm_control_m_o,
      qnice_gp_reg_o            => qnice_gp_reg_o,
      qnice_csr_reset_o         => qnice_csr_reset,
      qnice_csr_pause_o         => qnice_csr_pause,
      qnice_csr_keyboard_on_o   => qnice_csr_keyboard_on,
      qnice_csr_joy1_on_o       => qnice_csr_joy1_on,
      qnice_csr_joy2_on_o       => qnice_csr_joy2_on,
      qnice_ascal_mode_o        => qnice_ascal_mode,
      qnice_poly_wr_o           => qnice_poly_wr,
      qnice_vram_data_i         => qnice_vram_data,
      qnice_vram_we_o           => qnice_vram_we,
      qnice_vram_attr_we_o      => qnice_vram_attr_we,
      qnice_qnice_keys_n_i      => qnice_qnice_keys_n,
      qnice_pot1_x_n_o          => qnice_pot1_x_n,
      qnice_pot1_y_n_o          => qnice_pot1_y_n,
      qnice_pot2_x_n_o          => qnice_pot2_x_n,
      qnice_pot2_y_n_o          => qnice_pot2_y_n,
      qnice_avm_write_o         => qnice_avm_write,
      qnice_avm_read_o          => qnice_avm_read,
      qnice_avm_address_o       => qnice_avm_address,
      qnice_avm_writedata_o     => qnice_avm_writedata,
      qnice_avm_byteenable_o    => qnice_avm_byteenable,
      qnice_avm_burstcount_o    => qnice_avm_burstcount,
      qnice_avm_readdata_i      => qnice_avm_readdata,
      qnice_avm_readdatavalid_i => qnice_avm_readdatavalid,
      qnice_avm_waitrequest_i   => qnice_avm_waitrequest,
      qnice_pps_i               => qnice_pps,
      qnice_hdmi_clk_freq_i     => qnice_hdmi_clk_freq,
      qnice_hr_count_long_i     => qnice_hr_count_long,
      qnice_hr_count_short_i    => qnice_hr_count_short,
      qnice_i2c_wait_i          => qnice_i2c_wait,
      qnice_i2c_ce_o            => qnice_i2c_ce,
      qnice_i2c_we_o            => qnice_i2c_we,
      qnice_i2c_rd_data_i       => qnice_i2c_rd_data,
      qnice_rtc_wait_i          => qnice_rtc_wait,
      qnice_rtc_ce_o            => qnice_rtc_ce,
      qnice_rtc_we_o            => qnice_rtc_we,
      qnice_rtc_rd_data_i       => qnice_rtc_rd_data,
      qnice_ramrom_dev_o        => qnice_ramrom_dev_o,
      qnice_ramrom_addr_o       => qnice_ramrom_addr_o,
      qnice_ramrom_data_out_o   => qnice_ramrom_data_out_o,
      qnice_ramrom_data_in_i    => qnice_ramrom_data_in_i,
      qnice_ramrom_ce_o         => qnice_ramrom_ce_o,
      qnice_ramrom_we_o         => qnice_ramrom_we_o,
      qnice_ramrom_wait_i       => qnice_ramrom_wait_i
   ); -- i_qnice_wrapper

   -- Determine HDMI clock frequency
   i_clock_counter : entity work.clock_counter
   port map (
      clk_i     => qnice_clk,
      pps_i     => qnice_pps,
      cnt_o     => qnice_hdmi_clk_freq,
      mon_clk_i => hdmi_clk
   );

   --------------------------------------------------------
   -- HyperRAM clock domain: hr_clk
   --------------------------------------------------------

   i_avm_arbit_general : entity work.avm_arbit_general
      generic map (
         G_NUM_SLAVES   => 3,
         G_FREQ_HZ      => BOARD_CLK_SPEED,
         G_ADDRESS_SIZE => 32,
         G_DATA_SIZE    => 16
      )
      port map (
         clk_i                 => hr_clk,
         rst_i                 => hr_rst,
         s_avm_write_i         => hr_dig_write         & hr_core_write_i         & hr_qnice_write,
         s_avm_read_i          => hr_dig_read          & hr_core_read_i          & hr_qnice_read,
         s_avm_address_i       => hr_dig_address       & hr_core_address_i       & hr_qnice_address,
         s_avm_writedata_i     => hr_dig_writedata     & hr_core_writedata_i     & hr_qnice_writedata,
         s_avm_byteenable_i    => hr_dig_byteenable    & hr_core_byteenable_i    & hr_qnice_byteenable,
         s_avm_burstcount_i    => hr_dig_burstcount    & hr_core_burstcount_i    & hr_qnice_burstcount,
         s_avm_readdata_o(3*16-1 downto 2*16) => hr_dig_readdata,
         s_avm_readdata_o(2*16-1 downto 1*16) => hr_core_readdata_o,
         s_avm_readdata_o(1*16-1 downto 0*16) => hr_qnice_readdata,
         s_avm_readdatavalid_o(2) => hr_dig_readdatavalid,
         s_avm_readdatavalid_o(1) => hr_core_readdatavalid_o,
         s_avm_readdatavalid_o(0) => hr_qnice_readdatavalid,
         s_avm_waitrequest_o(2)   => hr_dig_waitrequest,
         s_avm_waitrequest_o(1)   => hr_core_waitrequest_o,
         s_avm_waitrequest_o(0)   => hr_qnice_waitrequest,
         m_avm_write_o         => hr_write,
         m_avm_read_o          => hr_read,
         m_avm_address_o       => hr_address,
         m_avm_writedata_o     => hr_writedata,
         m_avm_byteenable_o    => hr_byteenable,
         m_avm_burstcount_o    => hr_burstcount,
         m_avm_readdata_i      => hr_readdata,
         m_avm_readdatavalid_i => hr_readdatavalid,
         m_avm_waitrequest_i   => hr_waitrequest
      ); -- i_avm_arbit_general


   ---------------------------------------------------------------------------------------------------------------
   -- Clock Domain Crossing
   ---------------------------------------------------------------------------------------------------------------

   -- Clock domain crossing: SYS to CORE
   i_sys2main: xpm_cdc_array_single
      generic map (
         WIDTH => 2
      )
      port map (
         src_clk     => clk_i,
         src_in(0)   => not reset_m2m_n,
         src_in(1)   => not reset_core_n,
         dest_clk    => main_clk_i,
         dest_out(0) => main_reset_m2m_o,
         dest_out(1) => main_reset_core_o
      ); -- i_sys2main

   -- Clock domain crossing: SYS to QNICE
   i_sys2qnice : entity work.cdc_pulse
     port map (
       src_clk_i   => clk_i,
       src_pulse_i => sys_pps,
       dst_clk_i   => qnice_clk,
       dst_pulse_o => qnice_pps
     ); -- i_sys2qnice

   -- Clock domain crossing: CORE to QNICE
   i_main2qnice: xpm_cdc_array_single
      generic map (
         WIDTH => 16
      )
      port map (
         src_clk                => main_clk_i,
         src_in(15 downto  0)   => main_qnice_keys_n,
         dest_clk               => qnice_clk,
         dest_out(15 downto  0) => qnice_qnice_keys_n
      ); -- i_main2qnice

   -- Clock domain crossing: CORE to AUDIO
   i_main2audio: entity work.cdc_stable
      generic map (
         G_REGISTER_SRC => true,
         G_DATA_SIZE    => 32
      )
      port map (
         src_clk_i                => main_clk_i,
         src_data_i(15 downto  0) => std_logic_vector(main_audio_l_i),
         src_data_i(31 downto 16) => std_logic_vector(main_audio_r_i),
         dst_clk_i                => audio_clk,
         dst_data_o(15 downto  0) => audio_left,
         dst_data_o(31 downto 16) => audio_right
      ); -- i_main2audio

   -- Clock domain crossing: QNICE to CORE
   i_qnice2main: xpm_cdc_array_single
      generic map (
         WIDTH => 615
      )
      port map (
         src_clk                    => qnice_clk,
         src_in(0)                  => qnice_csr_reset,
         src_in(1)                  => qnice_csr_pause,
         src_in(2)                  => qnice_csr_keyboard_on,
         src_in(3)                  => qnice_csr_joy1_on,
         src_in(4)                  => qnice_csr_joy2_on,
         src_in(5)                  => qnice_flip_joyports_i,
         src_in(261 downto 6)       => qnice_osm_control_m_o,
         src_in(517 downto 262)     => qnice_gp_reg_o,
         src_in(525 downto 518)     => std_logic_vector(qnice_pot1_x_n),
         src_in(533 downto 526)     => std_logic_vector(qnice_pot1_y_n),
         src_in(541 downto 534)     => std_logic_vector(qnice_pot2_x_n),
         src_in(549 downto 542)     => std_logic_vector(qnice_pot2_y_n),
         src_in(614 downto 550)     => qnice_rtc,
         dest_clk                   => main_clk_i,
         dest_out(0)                => main_qnice_reset_o,
         dest_out(1)                => main_qnice_pause_o,
         dest_out(2)                => main_csr_keyboard_on,
         dest_out(3)                => main_csr_joy1_on,
         dest_out(4)                => main_csr_joy2_on,
         dest_out(5)                => main_flip_joyports,
         dest_out(261 downto 6)     => main_osm_control_m_o,
         dest_out(517 downto 262)   => main_qnice_gp_reg_o,
         dest_out(525 downto 518)   => main_pot1_x_o,
         dest_out(533 downto 526)   => main_pot1_y_o,
         dest_out(541 downto 534)   => main_pot2_x_o,
         dest_out(549 downto 542)   => main_pot2_y_o,
         dest_out(614 downto 550)   => main_rtc_o
      ); -- i_qnice2main

   -- Clock domain crossing: QNICE to HR
   i_avm_fifo_qnice : entity work.avm_fifo
      generic map (
         G_WR_DEPTH     => 16,
         G_RD_DEPTH     => 16,
         G_FILL_SIZE    => 1,
         G_ADDRESS_SIZE => 32,
         G_DATA_SIZE    => 16
      )
      port map (
         s_clk_i               => qnice_clk,
         s_rst_i               => qnice_rst,
         s_avm_waitrequest_o   => qnice_avm_waitrequest,
         s_avm_write_i         => qnice_avm_write,
         s_avm_read_i          => qnice_avm_read,
         s_avm_address_i       => qnice_avm_address,
         s_avm_writedata_i     => qnice_avm_writedata,
         s_avm_byteenable_i    => qnice_avm_byteenable,
         s_avm_burstcount_i    => qnice_avm_burstcount,
         s_avm_readdata_o      => qnice_avm_readdata,
         s_avm_readdatavalid_o => qnice_avm_readdatavalid,
         m_clk_i               => hr_clk,
         m_rst_i               => hr_rst,
         m_avm_waitrequest_i   => hr_qnice_waitrequest,
         m_avm_write_o         => hr_qnice_write,
         m_avm_read_o          => hr_qnice_read,
         m_avm_address_o       => hr_qnice_address,
         m_avm_writedata_o     => hr_qnice_writedata,
         m_avm_byteenable_o    => hr_qnice_byteenable,
         m_avm_burstcount_o    => hr_qnice_burstcount,
         m_avm_readdata_i      => hr_qnice_readdata,
         m_avm_readdatavalid_i => hr_qnice_readdatavalid
      ); -- i_avm_fifo_qnice

   -- Clock domain crossing: HR to QNICE
   i_hr2qnice: entity work.cdc_stable
      generic map (
         G_DATA_SIZE => 64
      )
      port map (
         src_clk_i                => hr_clk,
         src_data_i(31 downto  0) => std_logic_vector(hr_count_long),
         src_data_i(63 downto 32) => std_logic_vector(hr_count_short),
         dst_clk_i                => qnice_clk,
         dst_data_o(31 downto  0) => qnice_hr_count_long,
         dst_data_o(63 downto 32) => qnice_hr_count_short
      ); -- i_hr2qnice


   ---------------------------------------------------------------------------------------------------------------
   -- Audio and video processing pipeline: Multiple clock domains
   ---------------------------------------------------------------------------------------------------------------

   i_av_pipeline : entity work.av_pipeline
      generic map (
         G_VIDEO_MODE_VECTOR     => VIDEO_MODE_VECTOR,
         G_AUDIO_CLOCK_RATE      => 12_288_000,
         G_VGA_DX                => VGA_DX,
         G_VGA_DY                => VGA_DY,
         G_FONT_FILE             => FONT_FILE,
         G_FONT_DX               => FONT_DX,
         G_FONT_DY               => FONT_DY
      )
      port map (
         -- Input from Core
         video_clk_i             => video_clk_i,
         video_rst_i             => video_rst_i,
         video_ce_i              => video_ce_i,
         video_ce_ovl_i          => video_ce_ovl_i,
         video_red_i             => video_red_i,
         video_green_i           => video_green_i,
         video_blue_i            => video_blue_i,
         video_vs_i              => video_vs_i,
         video_hs_i              => video_hs_i,
         video_hblank_i          => video_hblank_i,
         video_vblank_i          => video_vblank_i,
         audio_clk_i             => audio_clk,
         audio_rst_i             => audio_rst,
         audio_left_i            => audio_left,
         audio_right_i           => audio_right,
         qnice_clk_i             => qnice_clk,
         qnice_rst_i             => qnice_rst,
         qnice_osm_cfg_scaling_i => qnice_osm_cfg_scaling_i,
         qnice_osm_cfg_xy_i      => qnice_osm_cfg_xy,
         qnice_osm_cfg_dxdy_i    => qnice_osm_cfg_dxdy,
         qnice_osm_cfg_enable_i  => qnice_osm_cfg_enable,
         qnice_retro15kHz_i      => qnice_retro15kHz_i,
         qnice_scandoubler_i     => qnice_scandoubler_i,
         qnice_csync_i           => qnice_csync_i,
         qnice_zoom_crop_i       => qnice_zoom_crop_i,
         qnice_audio_filter_i    => qnice_audio_filter_i,
         qnice_audio_mute_i      => qnice_audio_mute_i,
         qnice_video_mode_i      => video_mode_to_slv(qnice_video_mode_i),
         qnice_dvi_i             => qnice_dvi_i,
         qnice_poly_clk_i        => qnice_clk,
         qnice_poly_dw_i         => qnice_ramrom_data_out_o(9 downto 0),
         qnice_poly_a_i          => qnice_ramrom_addr_o(6+3 downto 0),
         qnice_poly_wr_i         => qnice_poly_wr,
         qnice_ascal_mode_i      => qnice_ascal_mode,
         qnice_hdmax_o           => qnice_hdmax,
         qnice_vdmax_o           => qnice_vdmax,
         qnice_h_pixels_o        => qnice_h_pixels,
         qnice_v_pixels_o        => qnice_v_pixels,
         qnice_h_pulse_o         => qnice_h_pulse,
         qnice_h_bp_o            => qnice_h_bp,
         qnice_h_fp_o            => qnice_h_fp,
         qnice_v_pulse_o         => qnice_v_pulse,
         qnice_v_bp_o            => qnice_v_bp,
         qnice_v_fp_o            => qnice_v_fp,
         qnice_h_freq_o          => qnice_h_freq,
         qnice_address_i         => qnice_ramrom_addr_o(VRAM_ADDR_WIDTH-1 downto 0),
         qnice_data_i            => qnice_ramrom_data_out_o(7 downto 0) & qnice_ramrom_data_out_o(7 downto 0),   -- 2 copies of the same data
         qnice_wren_i            => qnice_vram_attr_we or qnice_vram_we,
         qnice_byteenable_i      => qnice_vram_attr_we & qnice_vram_we,
         qnice_q_o               => qnice_vram_data,
         sys_clk_i               => clk_i,
         sys_pps_i               => sys_pps,
         hr_clk_i                => hr_clk,
         hr_rst_i                => hr_rst,
         hr_write_o              => hr_dig_write,
         hr_read_o               => hr_dig_read,
         hr_address_o            => hr_dig_address,
         hr_writedata_o          => hr_dig_writedata,
         hr_byteenable_o         => hr_dig_byteenable,
         hr_burstcount_o         => hr_dig_burstcount,
         hr_readdata_i           => hr_dig_readdata,
         hr_readdatavalid_i      => hr_dig_readdatavalid,
         hr_waitrequest_i        => hr_dig_waitrequest,
         hr_high_o               => hr_high_o,
         hr_low_o                => hr_low_o,
         -- Output to MEGA65 board
         VGA_RED                 => vga_red_o,
         VGA_GREEN               => vga_green_o,
         VGA_BLUE                => vga_blue_o,
         VGA_HS                  => vga_hs_o,
         VGA_VS                  => vga_vs_o,
         vdac_clk                => vdac_clk_o,
         vdac_sync_n             => vdac_sync_n_o,
         vdac_blank_n            => vdac_blank_n_o,
         audio_clk_o             => audio_clk_o,
         audio_reset_o           => audio_reset_o,
         audio_left_o            => audio_left_o,
         audio_right_o           => audio_right_o,
         hdmi_clk_i              => hdmi_clk,
         hdmi_rst_i              => hdmi_rst,
         tmds_clk_i              => tmds_clk,
         tmds_data_p_o           => tmds_data_p_o,
         tmds_data_n_o           => tmds_data_n_o,
         tmds_clk_p_o            => tmds_clk_p_o,
         tmds_clk_n_o            => tmds_clk_n_o
      ); -- i_av_pipeline


   ---------------------------------------------------------------------------------------------------------------
   -- HyperRAM controller
   ---------------------------------------------------------------------------------------------------------------

   i_hyperram : entity work.hyperram
      generic map (
         G_ERRATA_ISSI_D_FIX => true
      )
      port map (
         clk_i               => hr_clk,
         clk_del_i           => hr_clk_del,
         delay_refclk_i      => hr_delay_refclk,
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
         count_long_o        => hr_count_long,
         count_short_o       => hr_count_short,
         hr_resetn_o         => hr_reset_o,
         hr_csn_o            => hr_cs0_o,
         hr_ck_o             => hr_clk_p_o,
         hr_rwds_in_i        => hr_rwds_in,
         hr_rwds_out_o       => hr_rwds_out,
         hr_rwds_oe_n_o      => hr_rwds_oe_n,
         hr_dq_in_i          => hr_dq_in,
         hr_dq_out_o         => hr_dq_out,
         hr_dq_oe_n_o        => hr_dq_oe_n
      ); -- i_hyperram

   -- Tri-state buffers for HyperRAM
   hr_rwds_io <= hr_rwds_out when hr_rwds_oe_n = '0' else 'Z';
   hr_d_gen : for i in 0 to 7 generate
      hr_d_io(i) <= hr_dq_out(i) when hr_dq_oe_n(i) = '0' else 'Z';
   end generate hr_d_gen;
   hr_rwds_in <= hr_rwds_io;
   hr_dq_in   <= hr_d_io;


   ---------------------------------------------------------------------------------------------------------------
   -- I2C controller
   ---------------------------------------------------------------------------------------------------------------

   i_rtc_wrapper : entity work.rtc_wrapper
   generic map (
      G_BOARD       => G_BOARD,
      G_I2C_CLK_DIV => 250   -- SCL=100kHz @50MHz
   )
   port map (
      clk_i         => qnice_clk,
      rst_i         => qnice_rst,
      rtc_o         => qnice_rtc,
      rtc_wait_o    => qnice_rtc_wait,
      rtc_ce_i      => qnice_rtc_ce,
      rtc_we_i      => qnice_rtc_we,
      rtc_addr_i    => qnice_ramrom_addr_o(7 downto 0),
      rtc_wr_data_i => qnice_ramrom_data_out_o,
      rtc_rd_data_o => qnice_rtc_rd_data,
      i2c_wait_o    => qnice_i2c_wait,
      i2c_ce_i      => qnice_i2c_ce,
      i2c_we_i      => qnice_i2c_we,
      i2c_addr_i    => qnice_ramrom_addr_o,
      i2c_wr_data_i => qnice_ramrom_data_out_o,
      i2c_rd_data_o => qnice_i2c_rd_data,
      scl_in_i      => "11" & audio_scl_io & vga_scl_io & hdmi_scl_io & i2c_scl_io & grove_scl_io & fpga_scl_io,
      sda_in_i      => "11" & audio_sda_io & vga_sda_io & hdmi_sda_io & i2c_sda_io & grove_sda_io & fpga_sda_io,
      scl_out_o     => scl_out,
      sda_out_o     => sda_out
   ); -- i_rtc_wrapper

   -- Open collector, i.e. either drive pin low, or let it float (tri-state)
   fpga_sda_io  <= '0' when sda_out(0) = '0' else 'Z';
   fpga_scl_io  <= '0' when scl_out(0) = '0' else 'Z';
   grove_sda_io <= '0' when sda_out(1) = '0' else 'Z';
   grove_scl_io <= '0' when scl_out(1) = '0' else 'Z';
   i2c_sda_io   <= '0' when sda_out(2) = '0' else 'Z';
   i2c_scl_io   <= '0' when scl_out(2) = '0' else 'Z';
   hdmi_sda_io  <= '0' when sda_out(3) = '0' else 'Z';
   hdmi_scl_io  <= '0' when scl_out(3) = '0' else 'Z';
   vga_sda_io   <= '0' when sda_out(4) = '0' else 'Z';
   vga_scl_io   <= '0' when scl_out(4) = '0' else 'Z';
   audio_sda_io <= '0' when sda_out(5) = '0' else 'Z';
   audio_scl_io <= '0' when scl_out(5) = '0' else 'Z';

end architecture synthesis;

