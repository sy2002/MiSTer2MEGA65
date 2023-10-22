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

entity hal_mega65_r4 is
port (
   clk_i                   : in    std_logic;                  -- 100 MHz clock
   reset_button_i          : in    std_logic;

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

   -- Audio DAC. U37 = AK4432VT
   audio_mclk_o            : out   std_logic;   -- Master Clock Input Pin,       12.288 MHz
   audio_bick_o            : out   std_logic;   -- Audio Serial Data Clock Pin,   3.072 MHz
   audio_sdti_o            : out   std_logic;   -- Audio Serial Data Input Pin,  16-bit LSB justified
   audio_lrclk_o           : out   std_logic;   -- Input Channel Clock Pin,      48.0 kHz
   audio_pdn_n_o           : out   std_logic;   -- Power-Down & Reset Pin
   audio_i2cfil_o          : out   std_logic;   -- I2C Interface Mode Select Pin
   audio_scl_o             : out   std_logic;   -- Control Data Clock Input Pin
   audio_sda_io            : inout std_logic;   -- Control Data Input/Output Pin

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
   reset_m2m_n_o           : out   std_logic;
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
   qnice_video_mode_i      : in    natural range 0 to 3;
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
   qnice_ramrom_wait_i     : in    std_logic
);
end entity hal_mega65_r4;

architecture synthesis of hal_mega65_r4 is

   signal audio_clk     : std_logic;
   signal audio_reset   : std_logic;
   signal audio_left    : signed(15 downto 0);
   signal audio_right   : signed(15 downto 0);

begin

   -- Driver for the audio DAC (AK4432VT).
   i_audio : entity work.audio
      port map (
         audio_clk_i    => audio_clk,
         audio_reset_i  => audio_reset,
         audio_left_i   => audio_left,
         audio_right_i  => audio_right,
         audio_mclk_o   => audio_mclk_o,
         audio_bick_o   => audio_bick_o,
         audio_sdti_o   => audio_sdti_o,
         audio_lrclk_o  => audio_lrclk_o,
         audio_pdn_n_o  => audio_pdn_n_o,
         audio_i2cfil_o => audio_i2cfil_o,
         audio_scl_o    => audio_scl_o,
         audio_sda_io   => audio_sda_io
      ); -- i_audio

   i_framework : entity work.framework
   port map (
      -- Connect to I/O ports
      clk_i                   => clk_i,
      reset_n_i               => not reset_button_i,
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
      joy_1_up_n_i            => joy_1_up_n_i,
      joy_1_down_n_i          => joy_1_down_n_i,
      joy_1_left_n_i          => joy_1_left_n_i,
      joy_1_right_n_i         => joy_1_right_n_i,
      joy_1_fire_n_i          => joy_1_fire_n_i,
      joy_1_up_n_o            => joy_1_up_n_o,
      joy_1_down_n_o          => joy_1_down_n_o,
      joy_1_left_n_o          => joy_1_left_n_o,
      joy_1_right_n_o         => joy_1_right_n_o,
      joy_1_fire_n_o          => joy_1_fire_n_o,
      joy_2_up_n_i            => joy_2_up_n_i,
      joy_2_down_n_i          => joy_2_down_n_i,
      joy_2_left_n_i          => joy_2_left_n_i,
      joy_2_right_n_i         => joy_2_right_n_i,
      joy_2_fire_n_i          => joy_2_fire_n_i,
      joy_2_up_n_o            => joy_2_up_n_o,
      joy_2_down_n_o          => joy_2_down_n_o,
      joy_2_left_n_o          => joy_2_left_n_o,
      joy_2_right_n_o         => joy_2_right_n_o,
      joy_2_fire_n_o          => joy_2_fire_n_o,
      paddle_i                => paddle_i,
      paddle_drain_o          => paddle_drain_o,
      hr_d_io                 => hr_d_io,
      hr_rwds_io              => hr_rwds_io,
      hr_reset_o              => hr_reset_o,
      hr_clk_p_o              => hr_clk_p_o,
      hr_cs0_o                => hr_cs0_o,

      -- Connect to CORE
      qnice_clk_o             => qnice_clk_o,
      qnice_rst_o             => qnice_rst_o,
      reset_m2m_n_o           => reset_m2m_n_o,
      main_clk_i              => main_clk_i,
      main_rst_i              => main_rst_i,
      main_qnice_reset_o      => main_qnice_reset_o,
      main_qnice_pause_o      => main_qnice_pause_o,
      main_reset_m2m_o        => main_reset_m2m_o,
      main_reset_core_o       => main_reset_core_o,
      main_key_num_o          => main_key_num_o,
      main_key_pressed_n_o    => main_key_pressed_n_o,
      main_power_led_i        => main_power_led_i,
      main_power_led_col_i    => main_power_led_col_i,
      main_drive_led_i        => main_drive_led_i,
      main_drive_led_col_i    => main_drive_led_col_i,
      main_osm_control_m_o    => main_osm_control_m_o,
      main_qnice_gp_reg_o     => main_qnice_gp_reg_o,
      main_audio_l_i          => main_audio_l_i,
      main_audio_r_i          => main_audio_r_i,
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
      main_joy1_up_n_o        => main_joy1_up_n_o,
      main_joy1_down_n_o      => main_joy1_down_n_o,
      main_joy1_left_n_o      => main_joy1_left_n_o,
      main_joy1_right_n_o     => main_joy1_right_n_o,
      main_joy1_fire_n_o      => main_joy1_fire_n_o,
      main_joy1_up_n_i        => main_joy1_up_n_i,
      main_joy1_down_n_i      => main_joy1_down_n_i,
      main_joy1_left_n_i      => main_joy1_left_n_i,
      main_joy1_right_n_i     => main_joy1_right_n_i,
      main_joy1_fire_n_i      => main_joy1_fire_n_i,
      main_joy2_up_n_o        => main_joy2_up_n_o,
      main_joy2_down_n_o      => main_joy2_down_n_o,
      main_joy2_left_n_o      => main_joy2_left_n_o,
      main_joy2_right_n_o     => main_joy2_right_n_o,
      main_joy2_fire_n_o      => main_joy2_fire_n_o,
      main_joy2_up_n_i        => main_joy2_up_n_i,
      main_joy2_down_n_i      => main_joy2_down_n_i,
      main_joy2_left_n_i      => main_joy2_left_n_i,
      main_joy2_right_n_i     => main_joy2_right_n_i,
      main_joy2_fire_n_i      => main_joy2_fire_n_i,
      main_pot1_x_o           => main_pot1_x_o,
      main_pot1_y_o           => main_pot1_y_o,
      main_pot2_x_o           => main_pot2_x_o,
      main_pot2_y_o           => main_pot2_y_o,

      -- Provide HyperRAM to core (in HyperRAM clock domain)
      hr_clk_o                => hr_clk_o,
      hr_rst_o                => hr_rst_o,
      hr_core_write_i         => hr_core_write_i,
      hr_core_read_i          => hr_core_read_i,
      hr_core_address_i       => hr_core_address_i,
      hr_core_writedata_i     => hr_core_writedata_i,
      hr_core_byteenable_i    => hr_core_byteenable_i,
      hr_core_burstcount_i    => hr_core_burstcount_i,
      hr_core_readdata_o      => hr_core_readdata_o,
      hr_core_readdatavalid_o => hr_core_readdatavalid_o,
      hr_core_waitrequest_o   => hr_core_waitrequest_o,
      hr_high_o               => hr_high_o,
      hr_low_o                => hr_low_o,

      -- Audio
      audio_clk_o             => audio_clk,
      audio_reset_o           => audio_reset,
      audio_left_o            => audio_left,
      audio_right_o           => audio_right,

      -- Connect to QNICE
      qnice_dvi_i             => qnice_dvi_i,
      qnice_video_mode_i      => qnice_video_mode_i,
      qnice_scandoubler_i     => qnice_scandoubler_i,
      qnice_csync_i           => qnice_csync_i,
      qnice_audio_mute_i      => qnice_audio_mute_i,
      qnice_audio_filter_i    => qnice_audio_filter_i,
      qnice_zoom_crop_i       => qnice_zoom_crop_i,
      qnice_osm_cfg_scaling_i => qnice_osm_cfg_scaling_i,
      qnice_retro15kHz_i      => qnice_retro15kHz_i,
      qnice_ascal_mode_i      => qnice_ascal_mode_i,
      qnice_ascal_polyphase_i => qnice_ascal_polyphase_i,
      qnice_ascal_triplebuf_i => qnice_ascal_triplebuf_i,
      qnice_flip_joyports_i   => qnice_flip_joyports_i,
      qnice_osm_control_m_o   => qnice_osm_control_m_o,
      qnice_gp_reg_o          => qnice_gp_reg_o,
      qnice_ramrom_dev_o      => qnice_ramrom_dev_o,
      qnice_ramrom_addr_o     => qnice_ramrom_addr_o,
      qnice_ramrom_data_out_o => qnice_ramrom_data_out_o,
      qnice_ramrom_data_in_i  => qnice_ramrom_data_in_i,
      qnice_ramrom_ce_o       => qnice_ramrom_ce_o,
      qnice_ramrom_we_o       => qnice_ramrom_we_o,
      qnice_ramrom_wait_i     => qnice_ramrom_wait_i
   ); -- i_framework

end architecture synthesis;

