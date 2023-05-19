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

entity av_pipeline is
port (
   CLK                     : in  std_logic;                  -- 100 MHz clock

   -- VGA
   VGA_RED                 : out std_logic_vector(7 downto 0);
   VGA_GREEN               : out std_logic_vector(7 downto 0);
   VGA_BLUE                : out std_logic_vector(7 downto 0);
   VGA_HS                  : out std_logic;
   VGA_VS                  : out std_logic;

   -- VDAC
   vdac_clk                : out std_logic;
   vdac_sync_n             : out std_logic;
   vdac_blank_n            : out std_logic;

   -- Digital Video (HDMI)
   tmds_data_p             : out std_logic_vector(2 downto 0);
   tmds_data_n             : out std_logic_vector(2 downto 0);
   tmds_clk_p              : out std_logic;
   tmds_clk_n              : out std_logic;

   -- 3.5mm analog audio jack
   pwm_l                   : out std_logic;
   pwm_r                   : out std_logic;

   main_clk_i              : in  std_logic;
   main_rst_i              : in  std_logic;
   main_audio_l_i          : in  signed(15 downto 0);
   main_audio_r_i          : in  signed(15 downto 0);
   video_clk_i             : in  std_logic;
   video_rst_i             : in  std_logic;
   video_ce_i              : in  std_logic;
   video_ce_ovl_i          : in  std_logic;
   video_retro15kHz_i      : in  std_logic;
   video_red_i             : in  std_logic_vector(7 downto 0);
   video_green_i           : in  std_logic_vector(7 downto 0);
   video_blue_i            : in  std_logic_vector(7 downto 0);
   video_vs_i              : in  std_logic;
   video_hs_i              : in  std_logic;
   video_hblank_i          : in  std_logic;
   video_vblank_i          : in  std_logic;

   -- Provide HyperRAM to core (in HyperRAM clock domain)
   hr_clk_o                : out std_logic;
   hr_rst_o                : out std_logic;
   hr_write_o              : out std_logic;
   hr_read_o               : out std_logic;
   hr_address_o            : out std_logic_vector(31 downto 0);
   hr_writedata_o          : out std_logic_vector(15 downto 0);
   hr_byteenable_o         : out std_logic_vector(1 downto 0);
   hr_burstcount_o         : out std_logic_vector(7 downto 0);
   hr_readdata_i           : in  std_logic_vector(15 downto 0);
   hr_readdatavalid_i      : in  std_logic;
   hr_waitrequest_i        : in  std_logic;
   hr_high_o               : out std_logic; -- Core is too fast
   hr_low_o                : out std_logic  -- Core is too slow
);
end entity av_pipeline;

architecture synthesis of av_pipeline is

---------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------

-- HDMI 1280x720 @ 50 Hz resolution = mode 0, 1280x720 @ 60 Hz resolution = mode 1, PAL 576p in 4:3 and 5:4 are modes 2 and 3
constant VIDEO_MODE_VECTOR    : video_modes_vector(0 to 3) := (C_HDMI_720p_50, C_HDMI_720p_60, C_HDMI_576p_50, C_HDMI_576p_50);

--------------------------------------------------------------------------------------------
-- main_clk_i (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- Device management
signal qnice_ramrom_data_in          : std_logic_vector(15 downto 0);
signal qnice_ramrom_data_in_hyperram : std_logic_vector(15 downto 0);
signal qnice_ramrom_wait             : std_logic;
signal qnice_ramrom_wait_hyperram    : std_logic;
signal qnice_ramrom_ce_hyperram      : std_logic;
signal qnice_ramrom_address          : std_logic_vector(31 downto 0);

-- QNICE control and status register
signal main_csr_keyboard_on   : std_logic;
signal main_csr_joy1_on       : std_logic;
signal main_csr_joy2_on       : std_logic;

signal video_zoom_crop        : std_logic;
signal video_scandoubler      : std_logic;
signal video_csync            : std_logic;

-- keyboard handling
signal main_qnice_keys_n      : std_logic_vector(15 downto 0);

-- signed audio from the core
-- if the core outputs unsigned audio, make sure you convert properly to prevent a loss in audio quality
signal filt_audio_l           : std_logic_vector(15 downto 0);
signal filt_audio_r           : std_logic_vector(15 downto 0);
signal audio_l                : signed(15 downto 0);
signal audio_r                : signed(15 downto 0);

--- control signals from QNICE in main's clock domain
signal main_audio_filter      : std_logic;
signal main_audio_mute        : std_logic;
signal main_flip_joyports     : std_logic;

---------------------------------------------------------------------------------------------
-- video_clk
---------------------------------------------------------------------------------------------

signal video_crop_ce          : std_logic;
signal video_crop_red         : std_logic_vector(7 downto 0);
signal video_crop_green       : std_logic_vector(7 downto 0);
signal video_crop_blue        : std_logic_vector(7 downto 0);
signal video_crop_hs          : std_logic;
signal video_crop_vs          : std_logic;
signal video_crop_hblank      : std_logic;
signal video_crop_vblank      : std_logic;

-- On-Screen-Menu (OSM) for VGA
signal video_osm_cfg_enable   : std_logic;
signal video_osm_cfg_xy       : std_logic_vector(15 downto 0);
signal video_osm_cfg_dxdy     : std_logic_vector(15 downto 0);
signal video_osm_vram_addr    : std_logic_vector(15 downto 0);
signal video_osm_vram_data    : std_logic_vector(15 downto 0);
signal video_hdmax            : natural range 0 to 4095;
signal video_vdmax            : natural range 0 to 4095;

signal video_pps              : std_logic;
signal video_x_vis            : std_logic_vector(15 downto 0);
signal video_x_tot            : std_logic_vector(15 downto 0);
signal video_y_vis            : std_logic_vector(15 downto 0);
signal video_y_tot            : std_logic_vector(15 downto 0);
signal video_h_freq           : std_logic_vector(15 downto 0);

---------------------------------------------------------------------------------------------
-- hdmi_clk
---------------------------------------------------------------------------------------------

-- On-Screen-Menu (OSM) for HDMI
signal hdmi_osm_cfg_enable    : std_logic;
signal hdmi_osm_cfg_xy        : std_logic_vector(15 downto 0);
signal hdmi_osm_cfg_dxdy      : std_logic_vector(15 downto 0);
signal hdmi_osm_vram_addr     : std_logic_vector(15 downto 0);
signal hdmi_osm_vram_data     : std_logic_vector(15 downto 0);

signal hdmi_video_mode        : std_logic_vector(1 downto 0);
signal hdmi_zoom_crop         : std_logic;

-- QNICE On Screen Menu selections
signal hdmi_osm_control_m     : std_logic_vector(255 downto 0);

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
   end process select_or_mute_audio;

   i_video_counters : entity work.video_counters
      port map (
         video_clk_i    => video_clk_i,
         video_rst_i    => video_rst_i,
         video_ce_i     => video_ce_i,
         video_vs_i     => video_vs_i,
         video_hs_i     => video_hs_i,
         video_hblank_i => video_hblank_i,
         video_vblank_i => video_vblank_i,
         video_pps_i    => video_pps,
         video_x_vis_o  => video_x_vis,
         video_x_tot_o  => video_x_tot,
         video_y_vis_o  => video_y_vis,
         video_y_tot_o  => video_y_tot,
         video_h_freq_o => video_h_freq
      ); -- i_video_counters

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
         video_clk_i              => video_clk_i,
         video_rst_i              => video_rst_i,
         video_ce_i               => video_ce_i,
         video_ce_ovl_i           => video_ce_ovl_i,
         video_retro15kHz_i       => video_retro15kHz_i,
         video_red_i              => video_red_i,
         video_green_i            => video_green_i,
         video_blue_i             => video_blue_i,
         video_hs_i               => video_hs_i,
         video_vs_i               => video_vs_i,
         video_hblank_i           => video_hblank_i,
         video_vblank_i           => video_vblank_i,
         audio_clk_i              => audio_clk, -- 30 MHz
         audio_rst_i              => audio_rst,
         audio_left_i             => audio_l,
         audio_right_i            => audio_r,

         -- Configure the scandoubler: 0=off/1=on
         -- Make sure the signal is in the video_clk clock domain
         video_scandoubler_i      => video_scandoubler,

         -- Configure composite sync: 0=off/1=on
         video_csync_i            => video_csync,

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
         video_osm_cfg_enable_i   => video_osm_cfg_enable,
         video_osm_cfg_xy_i       => video_osm_cfg_xy,
         video_osm_cfg_dxdy_i     => video_osm_cfg_dxdy,
         video_osm_vram_addr_o    => video_osm_vram_addr,
         video_osm_vram_data_i    => video_osm_vram_data
      ); -- i_analog_pipeline

   i_crop : entity work.crop
      port map (
         video_crop_mode_i => video_zoom_crop,
         video_clk_i       => video_clk_i,
         video_rst_i       => video_rst_i,
         video_ce_i        => video_ce_i,
         video_red_i       => video_red_i,
         video_green_i     => video_green_i,
         video_blue_i      => video_blue_i,
         video_hs_i        => video_hs_i,
         video_vs_i        => video_vs_i,
         video_hblank_i    => video_hblank_i,
         video_vblank_i    => video_vblank_i,
         video_ce_o        => video_crop_ce,
         video_red_o       => video_crop_red,
         video_green_o     => video_crop_green,
         video_blue_o      => video_crop_blue,
         video_hs_o        => video_crop_hs,
         video_vs_o        => video_crop_vs,
         video_hblank_o    => video_crop_hblank,
         video_vblank_o    => video_crop_vblank
      ); -- i_crop

   i_digital_pipeline : entity work.digital_pipeline
      generic map (
         G_VIDEO_MODE_VECTOR => VIDEO_MODE_VECTOR,
         G_VGA_DX            => VGA_DX,
         G_VGA_DY            => VGA_DY,
         G_FONT_FILE         => FONT_FILE,
         G_FONT_DX           => FONT_DX,
         G_FONT_DY           => FONT_DY
      )
      port map (
         -- Input from Core (video and audio)
         video_clk_i              => video_clk_i,
         video_rst_i              => video_rst_i,
         video_ce_i               => video_crop_ce,
         video_red_i              => video_crop_red,
         video_green_i            => video_crop_green,
         video_blue_i             => video_crop_blue,
         video_hs_i               => video_crop_hs,
         video_vs_i               => video_crop_vs,
         video_hblank_i           => video_crop_hblank,
         video_vblank_i           => video_crop_vblank,
         video_hdmax_o            => video_hdmax,
         video_vdmax_o            => video_vdmax,
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
         hdmi_video_mode_i        => to_integer(unsigned(hdmi_video_mode)),
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
         hr_write_o               => hr_write_o,
         hr_read_o                => hr_read_o,
         hr_address_o             => hr_address_o,
         hr_writedata_o           => hr_writedata_o,
         hr_byteenable_o          => hr_byteenable_o,
         hr_burstcount_o          => hr_burstcount_o,
         hr_readdata_i            => hr_readdata_i,
         hr_readdatavalid_i       => hr_readdatavalid_i,
         hr_waitrequest_i         => hr_waitrequest_i
      ); -- i_digital_pipeline

   -- Monitor the read and write accesses to the HyperRAM by the ascaler.
   i_hdmi_flicker_free : entity work.hdmi_flicker_free
      generic map (
         G_THRESHOLD_LOW  => X"0000_1000",  -- @TODO: Optimize these threshold values
         G_THRESHOLD_HIGH => X"0000_2000"
      )
      port map (
         hr_clk_i       => hr_clk_x1,
         hr_write_i     => hr_dig_write_o,
         hr_read_i      => hr_dig_read_o,
         hr_address_i   => hr_dig_address_o,
         high_o         => hr_high_o,       -- Core is too fast
         low_o          => hr_low_o         -- Core is too slow
      ); -- i_hdmi_flicker_free

end architecture synthesis;

