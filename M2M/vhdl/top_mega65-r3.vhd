----------------------------------------------------------------------------------
-- Commodore 64 for MEGA65 (C64MEGA65)
--
-- MEGA65 R3 main file that contains the whole machine
--
-- based on C64_MiSTer by the MiSTer development team
-- port done by MJoergen and sy2002 in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mega65_r3 is
port (
   -- Onboard crystal oscillator = 100 MHz
   clk_i              : in    std_logic;

   -- MAX10 FPGA (delivers reset)
   max10_tx_i         : in    std_logic;
   max10_rx_o         : out   std_logic;
   max10_clkandsync_o : out   std_logic;

   -- USB-RS232 Interface
   uart_rxd_i         : in    std_logic;
   uart_txd_o         : out   std_logic;

   -- VGA via VDAC. U3 = ADV7125BCPZ170
   vga_red_o          : out   std_logic_vector(7 downto 0);
   vga_green_o        : out   std_logic_vector(7 downto 0);
   vga_blue_o         : out   std_logic_vector(7 downto 0);
   vga_hs_o           : out   std_logic;
   vga_vs_o           : out   std_logic;
   vga_scl_io         : inout std_logic;
   vga_sda_io         : inout std_logic;
   vdac_clk_o         : out   std_logic;
   vdac_sync_n_o      : out   std_logic;
   vdac_blank_n_o     : out   std_logic;

   -- Digital Video (HDMI)
   tmds_data_p_o      : out   std_logic_vector(2 downto 0);
   tmds_data_n_o      : out   std_logic_vector(2 downto 0);
   tmds_clk_p_o       : out   std_logic;
   tmds_clk_n_o       : out   std_logic;
   hdmi_ct_hpd_o      : out   std_logic := '1';          -- Needed for HDMI compliancy: Assert +5V according to section 4.2.7 of the specification version 1.4b
   hdmi_hpd_i         : in    std_logic;
   hdmi_scl_io        : inout std_logic;
   hdmi_sda_io        : inout std_logic;
   hdmi_ls_oe_o       : out   std_logic;
   hdmi_cec_io        : inout std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0_o           : out   std_logic;                 -- clock to keyboard
   kb_io1_o           : out   std_logic;                 -- data output to keyboard
   kb_io2_i           : in    std_logic;                 -- data input from keyboard
   kb_jtagen_i        : in    std_logic;
   kb_tck_i           : in    std_logic;
   kb_tdi_i           : in    std_logic;
   kb_tdo_i           : in    std_logic;
   kb_tms_i           : in    std_logic;

   -- Micro SD Connector (external slot at back of the cover)
   sd_reset_o         : out   std_logic;
   sd_clk_o           : out   std_logic;
   sd_mosi_o          : out   std_logic;
   sd_miso_i          : in    std_logic;
   sd_cd_i            : in    std_logic;
   sd_d1_i            : in    std_logic;
   sd_d2_i            : in    std_logic;

   -- SD Connector (this is the slot at the bottom side of the case under the cover)
   sd2_reset_o        : out   std_logic;
   sd2_clk_o          : out   std_logic;
   sd2_mosi_o         : out   std_logic;
   sd2_miso_i         : in    std_logic;
   sd2_cd_i           : in    std_logic;
   sd2_wp_i           : in    std_logic;
   sd2_d1_i           : in    std_logic;
   sd2_d2_i           : in    std_logic;

   -- 3.5mm analog audio jack
   pwm_l_o            : out   std_logic;
   pwm_r_o            : out   std_logic;

   -- Audio DAC. U37 = SSM2518CPZ-R7
   audio_mclk_o       : out   std_logic;
   audio_bick_o       : out   std_logic;
   audio_sdti_o       : out   std_logic;
   audio_lrclk_o      : out   std_logic;
   audio_pdn_n_o      : out   std_logic;

   -- Joysticks and Paddles
   fa_up_n_i          : in    std_logic;
   fa_down_n_i        : in    std_logic;
   fa_left_n_i        : in    std_logic;
   fa_right_n_i       : in    std_logic;
   fa_fire_n_i        : in    std_logic;

   fb_up_n_i          : in    std_logic;
   fb_down_n_i        : in    std_logic;
   fb_left_n_i        : in    std_logic;
   fb_right_n_i       : in    std_logic;
   fb_fire_n_i        : in    std_logic;

   paddle_i           : in    std_logic_vector(3 downto 0);
   paddle_drain_o     : out   std_logic;

   -- HyperRAM. U29 = IS66WVH8M8BLL-100B1L
   hr_d_io            : inout std_logic_vector(7 downto 0);
   hr_rwds_io         : inout std_logic;
   hr_reset_o         : out   std_logic;
   hr_clk_p_o         : out   std_logic;
   hr_cs0_o           : out   std_logic;

   -- SMSC Ethernet PHY. U4 = KSZ8081RNDCA
   eth_clock_o        : out   std_logic;
   eth_led2_o         : out   std_logic;
   eth_mdc_o          : out   std_logic;
   eth_mdio_io        : inout std_logic;
   eth_reset_o        : out   std_logic;
   eth_rxd_i          : in    std_logic_vector(1 downto 0);
   eth_rxdv_i         : in    std_logic;
   eth_rxer_i         : in    std_logic;
   eth_txd_o          : out   std_logic_vector(1 downto 0);
   eth_txen_o         : out   std_logic;

   -- FDC interface
   f_density_o        : out   std_logic;
   f_diskchanged_i    : in    std_logic;
   f_index_i          : in    std_logic;
   f_motora_o         : out   std_logic;
   f_motorb_o         : out   std_logic;
   f_rdata_i          : in    std_logic;
   f_selecta_o        : out   std_logic;
   f_selectb_o        : out   std_logic;
   f_side1_o          : out   std_logic;
   f_stepdir_o        : out   std_logic;
   f_step_o           : out   std_logic;
   f_track0_i         : in    std_logic;
   f_wdata_o          : out   std_logic;
   f_wgate_o          : out   std_logic;
   f_writeprotect_i   : in    std_logic;

   -- I2C bus for on-board peripherals
   fpga_sda_io        : inout std_logic;
   fpga_scl_io        : inout std_logic;
   grove_sda_io       : inout std_logic;
   grove_scl_io       : inout std_logic;

   -- On board LEDs
   led_o              : out   std_logic;

   -- Pmod Header
   p1lo_io            : inout std_logic_vector(3 downto 0);
   p1hi_io            : inout std_logic_vector(3 downto 0);
   p2lo_io            : inout std_logic_vector(3 downto 0);
   p2hi_io            : inout std_logic_vector(3 downto 0);

   -- Quad SPI Flash. U5 = S25FL512SAGBHIS10
   qspidb_io          : inout std_logic_vector(3 downto 0);
   qspicsn_o          : out   std_logic;


   --------------------------------------------------------------------
   -- C64 specific ports that are not supported by the M2M framework
   --------------------------------------------------------------------

   -- CBM-488/IEC serial port
   iec_reset_n_o      : out   std_logic;
   iec_atn_n_o        : out   std_logic;
   iec_clk_en_o       : out   std_logic;
   iec_clk_n_i        : in    std_logic;
   iec_clk_n_o        : out   std_logic;
   iec_data_en_o      : out   std_logic;
   iec_data_n_i       : in    std_logic;
   iec_data_n_o       : out   std_logic;
   iec_srq_en_o       : out   std_logic;
   iec_srq_n_i        : in    std_logic;
   iec_srq_n_o        : out   std_logic;

   -- C64 Expansion Port (aka Cartridge Port) control lines
   -- *_dir=1 means FPGA->Port, =0 means Port->FPGA
   cart_ctrl_en_o     : out   std_logic;
   cart_ctrl_dir_o    : out   std_logic;
   cart_addr_en_o     : out   std_logic;
   cart_haddr_dir_o   : out   std_logic;
   cart_laddr_dir_o   : out   std_logic;
   cart_data_en_o     : out   std_logic;
   cart_data_dir_o    : out   std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_reset_o       : out   std_logic;                  -- R3 board bug. Should be inout.
   cart_phi2_o        : out   std_logic;
   cart_dotclock_o    : out   std_logic;

   cart_nmi_i         : in    std_logic;                  -- R3 board bug. Should be inout.
   cart_irq_i         : in    std_logic;                  -- R3 board bug. Should be inout.
   cart_dma_i         : in    std_logic;
   cart_exrom_i       : in    std_logic;
   cart_game_i        : in    std_logic;

   cart_ba_io         : inout std_logic;
   cart_rw_io         : inout std_logic;
   cart_roml_io       : inout std_logic;
   cart_romh_io       : inout std_logic;
   cart_io1_io        : inout std_logic;
   cart_io2_io        : inout std_logic;

   cart_d_io          : inout unsigned(7 downto 0);
   cart_a_io          : inout unsigned(15 downto 0)
);
end entity mega65_r3;

architecture synthesis of mega65_r3 is

   signal main_clk    : std_logic;
   signal main_rst    : std_logic;
   signal reset_m2m_n : std_logic;
   signal qnice_clk   : std_logic;
   signal qnice_rst   : std_logic;

   --------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- QNICE control and status register
   signal main_qnice_reset       : std_logic;
   signal main_qnice_pause       : std_logic;

   signal main_reset_m2m         : std_logic;
   signal main_reset_core        : std_logic;

   -- keyboard handling (incl. drive led)
   signal main_key_num           : integer range 0 to 79;
   signal main_key_pressed_n     : std_logic;
   signal main_power_led         : std_logic;
   signal main_power_led_col     : std_logic_vector(23 downto 0);
   signal main_drive_led         : std_logic;
   signal main_drive_led_col     : std_logic_vector(23 downto 0);

   -- QNICE On Screen Menu selections
   signal main_osm_control_m     : std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   signal main_qnice_gp_reg      : std_logic_vector(255 downto 0);

   -- signed audio from the core
   -- if the core outputs unsigned audio, make sure you convert properly to prevent a loss in audio quality
   signal main_audio_l           : signed(15 downto 0);
   signal main_audio_r           : signed(15 downto 0);

   -- Video output from Core
   signal video_clk              : std_logic;
   signal video_rst              : std_logic;
   signal video_ce               : std_logic;
   signal video_ce_ovl           : std_logic;
   signal video_red              : std_logic_vector(7 downto 0);
   signal video_green            : std_logic_vector(7 downto 0);
   signal video_blue             : std_logic_vector(7 downto 0);
   signal video_vs               : std_logic;
   signal video_hs               : std_logic;
   signal video_hblank           : std_logic;
   signal video_vblank           : std_logic;

   -- Joysticks and Paddles
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

   signal main_pot1_x            : std_logic_vector(7 downto 0);
   signal main_pot1_y            : std_logic_vector(7 downto 0);
   signal main_pot2_x            : std_logic_vector(7 downto 0);
   signal main_pot2_y            : std_logic_vector(7 downto 0);

   ---------------------------------------------------------------------------------------------
   -- HyperRAM clock domain
   ---------------------------------------------------------------------------------------------

   signal hr_clk                 : std_logic;
   signal hr_rst                 : std_logic;
   signal hr_core_write          : std_logic;
   signal hr_core_read           : std_logic;
   signal hr_core_address        : std_logic_vector(31 downto 0);
   signal hr_core_writedata      : std_logic_vector(15 downto 0);
   signal hr_core_byteenable     : std_logic_vector(1 downto 0);
   signal hr_core_burstcount     : std_logic_vector(7 downto 0);
   signal hr_core_readdata       : std_logic_vector(15 downto 0);
   signal hr_core_readdatavalid  : std_logic;
   signal hr_core_waitrequest    : std_logic;
   signal hr_low                 : std_logic;
   signal hr_high                : std_logic;

   ---------------------------------------------------------------------------------------------
   -- qnice_clk
   ---------------------------------------------------------------------------------------------

   -- Video and audio mode control
   signal qnice_dvi              : std_logic;
   signal qnice_video_mode       : natural range 0 to 3;
   signal qnice_scandoubler      : std_logic;
   signal qnice_csync            : std_logic;
   signal qnice_audio_mute       : std_logic;
   signal qnice_audio_filter     : std_logic;
   signal qnice_zoom_crop        : std_logic;
   signal qnice_ascal_mode       : std_logic_vector(1 downto 0);
   signal qnice_ascal_polyphase  : std_logic;
   signal qnice_ascal_triplebuf  : std_logic;
   signal qnice_retro15kHz       : std_logic;
   signal qnice_osm_cfg_scaling  : std_logic_vector(8 downto 0);

   -- flip joystick ports
   signal qnice_flip_joyports    : std_logic;

   -- QNICE On Screen Menu selections
   signal qnice_osm_control_m    : std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   signal qnice_gp_reg           : std_logic_vector(255 downto 0);

   -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
   -- ramrom_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
   signal qnice_ramrom_dev       : std_logic_vector(15 downto 0);
   signal qnice_ramrom_addr      : std_logic_vector(27 downto 0);
   signal qnice_ramrom_data_o    : std_logic_vector(15 downto 0);
   signal qnice_ramrom_data_i    : std_logic_vector(15 downto 0);
   signal qnice_ramrom_ce        : std_logic;
   signal qnice_ramrom_we        : std_logic;
   signal qnice_ramrom_wait      : std_logic;

begin

   ---------------------------------------------------------------------------------------------------------------
   -- MiSTer2MEGA Hardware Abstraction Layer for the MEGA65 board revision R3
   ---------------------------------------------------------------------------------------------------------------

   i_hal_mega65_r3 : entity work.hal_mega65_r3
   port map (
      -- Connect to I/O ports
      clk_i                   => clk_i,
      max10_tx_i              => max10_tx_i,
      max10_rx_o              => max10_rx_o,
      max10_clkandsync_o      => max10_clkandsync_o,
      uart_rxd_i              => uart_rxd_i,
      uart_txd_o              => uart_txd_o,
      vga_red_o               => vga_red_o,
      vga_green_o             => vga_green_o,
      vga_blue_o              => vga_blue_o,
      vga_hs_o                => vga_hs_o,
      vga_vs_o                => vga_vs_o,
      vdac_clk_o              => vdac_clk_o,
      vdac_sync_n_o           => vdac_sync_n_o,
      vdac_blank_n_o          => vdac_blank_n_o,
      tmds_data_p_o           => tmds_data_p_o,
      tmds_data_n_o           => tmds_data_n_o,
      tmds_clk_p_o            => tmds_clk_p_o,
      tmds_clk_n_o            => tmds_clk_n_o,
      kb_io0_o                => kb_io0_o,
      kb_io1_o                => kb_io1_o,
      kb_io2_i                => kb_io2_i,
      sd_reset_o              => sd_reset_o,
      sd_clk_o                => sd_clk_o,
      sd_mosi_o               => sd_mosi_o,
      sd_miso_i               => sd_miso_i,
      sd_cd_i                 => sd_cd_i,
      sd2_reset_o             => sd2_reset_o,
      sd2_clk_o               => sd2_clk_o,
      sd2_mosi_o              => sd2_mosi_o,
      sd2_miso_i              => sd2_miso_i,
      sd2_cd_i                => sd2_cd_i,
      pwm_l_o                 => pwm_l_o,
      pwm_r_o                 => pwm_r_o,
      joy_1_up_n_i            => fa_up_n_i,
      joy_1_down_n_i          => fa_down_n_i,
      joy_1_left_n_i          => fa_left_n_i,
      joy_1_right_n_i         => fa_right_n_i,
      joy_1_fire_n_i          => fa_fire_n_i,
      joy_2_up_n_i            => fb_up_n_i,
      joy_2_down_n_i          => fb_down_n_i,
      joy_2_left_n_i          => fb_left_n_i,
      joy_2_right_n_i         => fb_right_n_i,
      joy_2_fire_n_i          => fb_fire_n_i,
      paddle_i                => paddle_i,
      paddle_drain_o          => paddle_drain_o,
      hr_d_io                 => hr_d_io,
      hr_rwds_io              => hr_rwds_io,
      hr_reset_o              => hr_reset_o,
      hr_clk_p_o              => hr_clk_p_o,
      hr_cs0_o                => hr_cs0_o,

      -- Connect to CORE
      qnice_clk_o             => qnice_clk,
      qnice_rst_o             => qnice_rst,
      reset_m2m_n_o           => reset_m2m_n,
      main_clk_i              => main_clk,
      main_rst_i              => main_rst,
      main_qnice_reset_o      => main_qnice_reset,
      main_qnice_pause_o      => main_qnice_pause,
      main_reset_m2m_o        => main_reset_m2m,
      main_reset_core_o       => main_reset_core,
      main_key_num_o          => main_key_num,
      main_key_pressed_n_o    => main_key_pressed_n,
      main_power_led_i        => main_power_led,
      main_power_led_col_i    => main_power_led_col,
      main_drive_led_i        => main_drive_led,
      main_drive_led_col_i    => main_drive_led_col,
      main_osm_control_m_o    => main_osm_control_m,
      main_qnice_gp_reg_o     => main_qnice_gp_reg,
      main_audio_l_i          => main_audio_l,
      main_audio_r_i          => main_audio_r,
      video_clk_i             => video_clk,
      video_rst_i             => video_rst,
      video_ce_i              => video_ce,
      video_ce_ovl_i          => video_ce_ovl,
      video_red_i             => video_red,
      video_green_i           => video_green,
      video_blue_i            => video_blue,
      video_vs_i              => video_vs,
      video_hs_i              => video_hs,
      video_hblank_i          => video_hblank,
      video_vblank_i          => video_vblank,
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
      main_pot1_x_o           => main_pot1_x,
      main_pot1_y_o           => main_pot1_y,
      main_pot2_x_o           => main_pot2_x,
      main_pot2_y_o           => main_pot2_y,

      -- Provide HyperRAM to core (in HyperRAM clock domain)
      hr_clk_o                => hr_clk,
      hr_rst_o                => hr_rst,
      hr_core_write_i         => hr_core_write,
      hr_core_read_i          => hr_core_read,
      hr_core_address_i       => hr_core_address,
      hr_core_writedata_i     => hr_core_writedata,
      hr_core_byteenable_i    => hr_core_byteenable,
      hr_core_burstcount_i    => hr_core_burstcount,
      hr_core_readdata_o      => hr_core_readdata,
      hr_core_readdatavalid_o => hr_core_readdatavalid,
      hr_core_waitrequest_o   => hr_core_waitrequest,
      hr_high_o               => hr_high,
      hr_low_o                => hr_low,

      -- Connect to QNICE
      qnice_dvi_i             => qnice_dvi,
      qnice_video_mode_i      => qnice_video_mode,
      qnice_scandoubler_i     => qnice_scandoubler,
      qnice_csync_i           => qnice_csync,
      qnice_audio_mute_i      => qnice_audio_mute,
      qnice_audio_filter_i    => qnice_audio_filter,
      qnice_zoom_crop_i       => qnice_zoom_crop,
      qnice_osm_cfg_scaling_i => qnice_osm_cfg_scaling,
      qnice_retro15kHz_i      => qnice_retro15kHz,
      qnice_ascal_mode_i      => qnice_ascal_mode,
      qnice_ascal_polyphase_i => qnice_ascal_polyphase,
      qnice_ascal_triplebuf_i => qnice_ascal_triplebuf,
      qnice_flip_joyports_i   => qnice_flip_joyports,
      qnice_osm_control_m_o   => qnice_osm_control_m,
      qnice_gp_reg_o          => qnice_gp_reg,
      qnice_ramrom_dev_o      => qnice_ramrom_dev,
      qnice_ramrom_addr_o     => qnice_ramrom_addr,
      qnice_ramrom_data_out_o => qnice_ramrom_data_o,
      qnice_ramrom_data_in_i  => qnice_ramrom_data_i,
      qnice_ramrom_ce_o       => qnice_ramrom_ce,
      qnice_ramrom_we_o       => qnice_ramrom_we,
      qnice_ramrom_wait_i     => qnice_ramrom_wait
   ); -- i_hal_mega65_r3


   ---------------------------------------------------------------------------------------------------------------
   -- MEGA65 Core including the MiSTer core: Multiple clock domains
   ---------------------------------------------------------------------------------------------------------------

   CORE : entity work.MEGA65_Core
      port map (
         CLK                     => clk_i,
         RESET_M2M_N             => reset_m2m_n,

         -- Share clock and reset with the framework
         main_clk_o              => main_clk,            -- CORE's 54 MHz clock
         main_rst_o              => main_rst,            -- CORE's reset, synchronized

         --------------------------------------------------------------------------------------------------------
         -- QNICE Clock Domain
         --------------------------------------------------------------------------------------------------------

         -- Provide QNICE clock to the core: for the vdrives as well as for RAMs and ROMs
         qnice_clk_i             => qnice_clk,
         qnice_rst_i             => qnice_rst,

         -- Video and audio mode control
         qnice_dvi_o             => qnice_dvi,
         qnice_video_mode_o      => qnice_video_mode,
         qnice_scandoubler_o     => qnice_scandoubler,
         qnice_csync_o           => qnice_csync,
         qnice_audio_mute_o      => qnice_audio_mute,
         qnice_audio_filter_o    => qnice_audio_filter,
         qnice_zoom_crop_o       => qnice_zoom_crop,
         qnice_ascal_mode_o      => qnice_ascal_mode,
         qnice_ascal_polyphase_o => qnice_ascal_polyphase,
         qnice_ascal_triplebuf_o => qnice_ascal_triplebuf,
         qnice_retro15kHz_o      => qnice_retro15kHz,
         qnice_osm_cfg_scaling_o => qnice_osm_cfg_scaling,

         -- Flip joystick ports
         qnice_flip_joyports_o   => qnice_flip_joyports,

         -- On-Screen-Menu selections (in QNICE clock domain)
         qnice_osm_control_i     => qnice_osm_control_m,

         -- QNICE general purpose register
         qnice_gp_reg_i          => qnice_gp_reg,

         -- Core-specific devices
         qnice_dev_id_i          => qnice_ramrom_dev,
         qnice_dev_addr_i        => qnice_ramrom_addr,
         qnice_dev_data_i        => qnice_ramrom_data_o,
         qnice_dev_data_o        => qnice_ramrom_data_i,
         qnice_dev_ce_i          => qnice_ramrom_ce,
         qnice_dev_we_i          => qnice_ramrom_we,
         qnice_dev_wait_o        => qnice_ramrom_wait,

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

         -- QNICE general purpose register (in main clock domain)
         main_qnice_gp_reg_i     => main_qnice_gp_reg,

         -- Video output
         video_clk_o             => video_clk,
         video_rst_o             => video_rst,
         video_ce_o              => video_ce,
         video_ce_ovl_o          => video_ce_ovl,
         video_red_o             => video_red,
         video_green_o           => video_green,
         video_blue_o            => video_blue,
         video_vs_o              => video_vs,
         video_hs_o              => video_hs,
         video_hblank_o          => video_hblank,
         video_vblank_o          => video_vblank,

         -- Audio output (Signed PCM)
         main_audio_left_o       => main_audio_l,
         main_audio_right_o      => main_audio_r,

         -- M2M Keyboard interface
         main_kb_key_num_i       => main_key_num,
         main_kb_key_pressed_n_i => main_key_pressed_n,
         main_power_led_o        => main_power_led,
         main_power_led_col_o    => main_power_led_col,
         main_drive_led_o        => main_drive_led,
         main_drive_led_col_o    => main_drive_led_col,

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
         main_joy_2_fire_n_i     => main_joy2_fire_n,

         main_pot1_x_i           => main_pot1_x,
         main_pot1_y_i           => main_pot1_y,
         main_pot2_x_i           => main_pot2_x,
         main_pot2_y_i           => main_pot2_y,

         --------------------------------------------------------------------------------------------------------
         -- Provide support for external memory (Avalon Memory Map)
         --------------------------------------------------------------------------------------------------------

         hr_clk_i                => hr_clk,
         hr_rst_i                => hr_rst,
         hr_core_write_o         => hr_core_write,
         hr_core_read_o          => hr_core_read,
         hr_core_address_o       => hr_core_address,
         hr_core_writedata_o     => hr_core_writedata,
         hr_core_byteenable_o    => hr_core_byteenable,
         hr_core_burstcount_o    => hr_core_burstcount,
         hr_core_readdata_i      => hr_core_readdata,
         hr_core_readdatavalid_i => hr_core_readdatavalid,
         hr_core_waitrequest_i   => hr_core_waitrequest,
         hr_high_i               => hr_high,
         hr_low_i                => hr_low,

         --------------------------------------------------------------------
         -- C64 specific ports that are not supported by the M2M framework
         --------------------------------------------------------------------

         -- CBM-488/IEC serial port
         iec_reset_n_o     => iec_reset_n_o,
         iec_atn_n_o       => iec_atn_n_o,
         iec_clk_en_o      => iec_clk_en_o,
         iec_clk_n_i       => iec_clk_n_i,
         iec_clk_n_o       => iec_clk_n_o,
         iec_data_en_o     => iec_data_en_o,
         iec_data_n_i      => iec_data_n_i,
         iec_data_n_o      => iec_data_n_o,
         iec_srq_en_o      => iec_srq_en_o,
         iec_srq_n_i       => iec_srq_n_i,
         iec_srq_n_o       => iec_srq_n_o,

         -- C64 Expansion Port (aka Cartridge Port) control lines
         -- *_dir=1 means FPGA->Port, =0 means Port->FPGA
         cart_ctrl_en_o    => cart_ctrl_en_o,
         cart_ctrl_dir_o   => cart_ctrl_dir_o,
         cart_addr_en_o    => cart_addr_en_o,
         cart_haddr_dir_o  => cart_haddr_dir_o,
         cart_laddr_dir_o  => cart_laddr_dir_o,
         cart_data_en_o    => cart_data_en_o,
         cart_data_dir_o   => cart_data_dir_o,

         -- C64 Expansion Port (aka Cartridge Port)
         cart_reset_o      => cart_reset_o,
         cart_phi2_o       => cart_phi2_o,
         cart_dotclock_o   => cart_dotclock_o,
         cart_nmi_i        => cart_nmi_i,
         cart_irq_i        => cart_irq_i,
         cart_dma_i        => cart_dma_i,
         cart_exrom_i      => cart_exrom_i,
         cart_game_i       => cart_game_i,
         cart_ba_io        => cart_ba_io,
         cart_rw_io        => cart_rw_io,
         cart_roml_io      => cart_roml_io,
         cart_romh_io      => cart_romh_io,
         cart_io1_io       => cart_io1_io,
         cart_io2_io       => cart_io2_io,
         cart_d_io         => cart_d_io,
         cart_a_io         => cart_a_io
      ); -- CORE

   -- Safe default values
   vga_scl_io    <= 'Z';
   vga_sda_io    <= 'Z';
   hdmi_scl_io   <= 'Z';
   hdmi_sda_io   <= 'Z';
   hdmi_ls_oe_o  <= '1';
   hdmi_cec_io   <= 'Z';
   audio_mclk_o  <= '0';
   audio_bick_o  <= '0';
   audio_sdti_o  <= '0';
   audio_lrclk_o <= '0';
   audio_pdn_n_o <= '0';
   eth_clock_o   <= '0';
   eth_led2_o    <= '0';
   eth_mdc_o     <= '0';
   eth_mdio_io   <= 'Z';
   eth_reset_o   <= '1';
   eth_txd_o     <= (others => '0');
   eth_txen_o    <= '0';
   f_density_o   <= '0';
   f_motora_o    <= '0';
   f_motorb_o    <= '0';
   f_selecta_o   <= '0';
   f_selectb_o   <= '0';
   f_side1_o     <= '0';
   f_stepdir_o   <= '0';
   f_step_o      <= '0';
   f_wdata_o     <= '0';
   f_wgate_o     <= '0';
   fpga_sda_io   <= 'Z';
   fpga_scl_io   <= 'Z';
   grove_sda_io  <= 'Z';
   grove_scl_io  <= 'Z';
   led_o         <= '0'; -- Off
   p1lo_io       <= (others => 'Z');
   p1hi_io       <= (others => 'Z');
   p2lo_io       <= (others => 'Z');
   p2hi_io       <= (others => 'Z');
   qspidb_io     <= (others => 'Z');
   qspicsn_o     <= '1';

end architecture synthesis;

