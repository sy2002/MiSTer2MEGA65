----------------------------------------------------------------------------------
-- Commodore 64 for MEGA65
--
-- Complete pipeline processing of audio and video output (analog and digital)
--
-- based on C64_MiSTer by the MiSTer development team
-- port done by MJoergen and sy2002 in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity audio_video_pipeline is
   generic (
      G_SHIFT_HDMI           : integer;              -- Deprecated. Will be removed in future release
      G_VIDEO_MODE_VECTOR    : video_modes_vector;   -- Desired video format of HDMI output.
      G_VGA_DX               : natural;              -- Actual format of video from Core (in pixels).
      G_VGA_DY               : natural
   );
   port (
      -- Input from Core (video and audio)
      video_clk_i              : in  std_logic;
      video_rst_i              : in  std_logic;
      video_ce_i               : in  std_logic;
      video_red_i              : in  std_logic_vector(7 downto 0);
      video_green_i            : in  std_logic_vector(7 downto 0);
      video_blue_i             : in  std_logic_vector(7 downto 0);
      video_hs_i               : in  std_logic;
      video_vs_i               : in  std_logic;
      video_de_i               : in  std_logic;
      audio_clk_i              : in  std_logic;
      audio_rst_i              : in  std_logic;
      audio_left_i             : in  signed(15 downto 0); -- Signed PCM format
      audio_right_i            : in  signed(15 downto 0); -- Signed PCM format

      -- Analog output (VGA and audio jack)
      vga_red_o                : out std_logic_vector(7 downto 0);
      vga_green_o              : out std_logic_vector(7 downto 0);
      vga_blue_o               : out std_logic_vector(7 downto 0);
      vga_hs_o                 : out std_logic;
      vga_vs_o                 : out std_logic;
      vdac_clk_o               : out std_logic;
      vdac_syncn_o             : out std_logic;
      vdac_blankn_o            : out std_logic;
      pwm_l_o                  : out std_logic;
      pwm_r_o                  : out std_logic;

      -- Digital output (HDMI)
      hdmi_clk_i               : in  std_logic;
      hdmi_rst_i               : in  std_logic;
      tmds_clk_i               : in  std_logic;
      tmds_data_p_o            : out std_logic_vector(2 downto 0);
      tmds_data_n_o            : out std_logic_vector(2 downto 0);
      tmds_clk_p_o             : out std_logic;
      tmds_clk_n_o             : out std_logic;

      -- Connect to QNICE and Video RAM
      video_osm_cfg_enable_i   : in  std_logic;
      video_osm_cfg_xy_i       : in  std_logic_vector(15 downto 0);
      video_osm_cfg_dxdy_i     : in  std_logic_vector(15 downto 0);
      video_osm_vram_addr_o    : out std_logic_vector(15 downto 0);
      video_osm_vram_data_i    : in  std_logic_vector(15 downto 0);
      hdmi_triple_buffering_i  : in  std_logic;
      hdmi_video_mode_i        : in  natural;
      hdmi_osm_cfg_enable_i    : in  std_logic;
      hdmi_osm_cfg_xy_i        : in  std_logic_vector(15 downto 0);
      hdmi_osm_cfg_dxdy_i      : in  std_logic_vector(15 downto 0);
      hdmi_osm_vram_addr_o     : out std_logic_vector(15 downto 0);
      hdmi_osm_vram_data_i     : in  std_logic_vector(15 downto 0);

      -- Connect to HyperRAM controller
      hr_clk_i                 : in  std_logic;
      hr_rst_i                 : in  std_logic;
      hr_write_o               : out std_logic;
      hr_read_o                : out std_logic;
      hr_address_o             : out std_logic_vector(31 downto 0);
      hr_writedata_o           : out std_logic_vector(15 downto 0);
      hr_byteenable_o          : out std_logic_vector(1 downto 0);
      hr_burstcount_o          : out std_logic_vector(7 downto 0);
      hr_readdata_i            : in  std_logic_vector(15 downto 0);
      hr_readdatavalid_i       : in  std_logic;
      hr_waitrequest_i         : in  std_logic
   );
end entity audio_video_pipeline;

architecture synthesis of audio_video_pipeline is

   constant C_FONT_DX            : natural := 16;
   constant C_FONT_DY            : natural := 16;

   ---------------------------------------------------------------------------------------------
   -- pcm_clk
   ---------------------------------------------------------------------------------------------

   -- HDMI PCM sampling rate
   constant HDMI_PCM_SAMPLING      : natural := 48_000;
   constant GB_CLK_SPEED           : natural := 31_527_778;   -- C64 main clock in PAL mode @ 31,527,778 MHz
   constant PIXEL_CLK_SPEED        : natural := 74_250_000; -- TBD

   constant pcm_acr_cnt_range      : integer := (HDMI_PCM_SAMPLING * 256) / 1000;
   constant pcm_audio_cnt_interval : integer := (4 * GB_CLK_SPEED) / HDMI_PCM_SAMPLING;

   signal count : integer range 0 to 255;
   signal pcm_rst                  : std_logic;
   signal pcm_clk                  : std_logic;                     -- 256 * 48 kHz = 12.288 MHz
   signal pcm_clken                : std_logic;                     -- 48 kHz (via clock divider)

   signal pcm_acr                  : std_logic;                     -- HDMI ACR packet strobe (frequency = 128fs/N e.g. 1kHz)
   signal pcm_n                    : std_logic_vector(19 downto 0); -- HDMI ACR N value
   signal pcm_cts                  : std_logic_vector(19 downto 0); -- HDMI ACR CTS value

   signal pcm_audio_left_d         : signed(15 downto 0); -- Signed PCM format
   signal pcm_audio_right_d        : signed(15 downto 0); -- Signed PCM format
   signal pcm_audio_left_dd        : signed(15 downto 0); -- Signed PCM format
   signal pcm_audio_right_dd       : signed(15 downto 0); -- Signed PCM format
   signal pcm_audio_left           : signed(15 downto 0); -- Signed PCM format
   signal pcm_audio_right          : signed(15 downto 0); -- Signed PCM format

   signal pcm_audio_counter        : integer := 0;
   signal pcm_acr_counter          : integer range 0 to pcm_acr_cnt_range := 0;

   signal reset_na               : std_logic;            -- Asynchronous reset, active low

   signal hdmi_tmds              : slv_9_0_t(0 to 2);    -- parallel TMDS symbol stream x 3 channels
   signal hdmi_video_mode        : video_modes_t;

   constant C_AVM_ADDRESS_SIZE   : integer := 19;
   constant C_AVM_DATA_SIZE      : integer := 128;
   signal hdmi_htotal            : integer;
   signal hdmi_hsstart           : integer;
   signal hdmi_hsend             : integer;
   signal hdmi_hdisp             : integer;
   signal hdmi_vtotal            : integer;
   signal hdmi_vsstart           : integer;
   signal hdmi_vsend             : integer;
   signal hdmi_vdisp             : integer;

   -- Auto-calculate display dimensions based on an 4:3 aspect ratio
   signal hdmi_hmin              : integer;
   signal hdmi_hmax              : integer;
   signal hdmi_vmin              : integer;
   signal hdmi_vmax              : integer;

   -- After video_rescaler
   signal hdmi_red               : unsigned(7 downto 0);
   signal hdmi_green             : unsigned(7 downto 0);
   signal hdmi_blue              : unsigned(7 downto 0);
   signal hdmi_hs                : std_logic;
   signal hdmi_vs                : std_logic;
   signal hdmi_de                : std_logic;

   -- After OSM
   signal hdmi_osm_red           : std_logic_vector(7 downto 0);
   signal hdmi_osm_green         : std_logic_vector(7 downto 0);
   signal hdmi_osm_blue          : std_logic_vector(7 downto 0);
   signal hdmi_osm_hs            : std_logic;
   signal hdmi_osm_vs            : std_logic;
   signal hdmi_osm_de            : std_logic;

   signal hr_wide_write          : std_logic;
   signal hr_wide_read           : std_logic;
   signal hr_wide_address        : std_logic_vector(C_AVM_ADDRESS_SIZE-1 downto 0);
   signal hr_wide_writedata      : std_logic_vector(C_AVM_DATA_SIZE-1 downto 0);
   signal hr_wide_byteenable     : std_logic_vector(C_AVM_DATA_SIZE/8-1 downto 0);
   signal hr_wide_burstcount     : std_logic_vector(7 downto 0);
   signal hr_wide_readdata       : std_logic_vector(C_AVM_DATA_SIZE-1 downto 0);
   signal hr_wide_readdatavalid  : std_logic;
   signal hr_wide_waitrequest    : std_logic;

   signal video_ce_overlay       : std_logic_vector(1 downto 0) := "10"; -- Clock divider 1/2
   signal video_ce_hdmi          : std_logic_vector(3 downto 0) := "1000"; -- Clock divider 1/4

begin

   hdmi_video_mode <= G_VIDEO_MODE_VECTOR(hdmi_video_mode_i);
   hdmi_htotal     <= hdmi_video_mode.H_PIXELS + hdmi_video_mode.H_FP + hdmi_video_mode.H_PULSE + hdmi_video_mode.H_BP;
   hdmi_hsstart    <= hdmi_video_mode.H_PIXELS + hdmi_video_mode.H_FP;
   hdmi_hsend      <= hdmi_video_mode.H_PIXELS + hdmi_video_mode.H_FP + hdmi_video_mode.H_PULSE;
   hdmi_hdisp      <= hdmi_video_mode.H_PIXELS;
   hdmi_vtotal     <= hdmi_video_mode.V_PIXELS + hdmi_video_mode.V_FP + hdmi_video_mode.V_PULSE + hdmi_video_mode.V_BP;
   hdmi_vsstart    <= hdmi_video_mode.V_PIXELS + hdmi_video_mode.V_FP;
   hdmi_vsend      <= hdmi_video_mode.V_PIXELS + hdmi_video_mode.V_FP + hdmi_video_mode.V_PULSE;
   hdmi_vdisp      <= hdmi_video_mode.V_PIXELS;
   hdmi_hmin       <= (hdmi_video_mode.H_PIXELS-hdmi_video_mode.V_PIXELS*4/3)/2;
   hdmi_hmax       <= (hdmi_video_mode.H_PIXELS+hdmi_video_mode.V_PIXELS*4/3)/2-1;
   hdmi_vmin       <= 0;
   hdmi_vmax       <= hdmi_video_mode.V_PIXELS-1;

   ---------------------------------------------------------------------------------------------
   -- Analog output (VGA and audio jack)
   ---------------------------------------------------------------------------------------------

   -- Convert the C64's PCM output to pulse density modulation
   i_pcm2pdm : entity work.pcm_to_pdm
      port map
      (
         cpuclock         => audio_clk_i,
         pcm_left         => audio_left_i,
         pcm_right        => audio_right_i,
         -- Pulse Density Modulation (PDM is supposed to sound better than PWM on MEGA65)
         pdm_left         => pwm_l_o,
         pdm_right        => pwm_r_o,
         audio_mode       => '0'         -- 0=PDM, 1=PWM
      ); -- i_pcm2pdm


   i_video_overlay_video : entity work.video_overlay
      generic  map (
         G_VGA_DX         => G_VGA_DX,
         G_VGA_DY         => G_VGA_DY,
         G_FONT_DX        => C_FONT_DX,
         G_FONT_DY        => C_FONT_DY
      )
      port map (
         vga_clk_i        => video_clk_i,
         vga_ce_i         => video_ce_overlay(0),
         vga_red_i        => video_red_i,
         vga_green_i      => video_green_i,
         vga_blue_i       => video_blue_i,
         vga_hs_i         => video_hs_i,
         vga_vs_i         => video_vs_i,
         vga_de_i         => video_de_i,
         vga_cfg_enable_i => video_osm_cfg_enable_i,
         vga_cfg_xy_i     => video_osm_cfg_xy_i,
         vga_cfg_dxdy_i   => video_osm_cfg_dxdy_i,
         vga_vram_addr_o  => video_osm_vram_addr_o,
         vga_vram_data_i  => video_osm_vram_data_i,
         vga_ce_o         => open,
         vga_red_o        => vga_red_o,
         vga_green_o      => vga_green_o,
         vga_blue_o       => vga_blue_o,
         vga_hs_o         => vga_hs_o,
         vga_vs_o         => vga_vs_o,
         vga_de_o         => open
      ); -- i_video_overlay_video

   -- Make the VDAC output the image
   vdac_syncn_o  <= '0';
   vdac_blankn_o <= '1';
   vdac_clk_o    <= not video_clk_i;


   ---------------------------------------------------------------------------------------------
   -- Digital output (HDMI) - Audio part
   ---------------------------------------------------------------------------------------------

   i_clk_synthetic : entity work.clk_synthetic
      generic map (
         G_SRC_FREQ_HZ  => 60_000_000,
         G_DEST_FREQ_HZ => HDMI_PCM_SAMPLING*256
      )
      port map (
         src_clk_i  => audio_clk_i,
         src_rst_i  => audio_rst_i,
         dest_clk_o => pcm_clk,
         dest_rst_o => pcm_rst
      ); -- i_clk_synthetic

   p_clken : process (pcm_clk)
   begin
      if rising_edge(pcm_clk) then
         if count = 255 then
            count     <= 0;
            pcm_clken <= '1';
         else
            count     <= count + 1;
            pcm_clken <= '0';
         end if;

         if pcm_rst = '1' then
            count     <= 0;
            pcm_clken <= '0';
         end if;
      end if;
   end process p_clken;


   -- N and CTS values for HDMI Audio Clock Regeneration.
   -- depends on pixel clock and audio sample rate
   pcm_n   <= std_logic_vector(to_unsigned((HDMI_PCM_SAMPLING * 128) / 1000, pcm_n'length)); -- 6144 is correct according to HDMI spec.
   pcm_cts <= std_logic_vector(to_unsigned(PIXEL_CLK_SPEED / 1000, pcm_cts'length));

   -- ACR packet rate should be 128fs/N = 1kHz
   -- pcm_clk is at 12.288 MHz
   p_pcm_acr : process (pcm_clk)
   begin
      if rising_edge(pcm_clk) then
         -- Generate 1KHz ACR pulse train from 12.288MHz
         if pcm_acr_counter /= (pcm_acr_cnt_range - 1) then
            pcm_acr_counter <= pcm_acr_counter + 1;
            pcm_acr <= '0';
         else
            pcm_acr <= '1';
            pcm_acr_counter <= 0;
         end if;
      end if;
   end process p_pcm_acr;

   -- Clock Domain Crossing.
   -- Only propagate the sample when there is no metastability.
   p_sample : process (pcm_clk)
   begin
      if rising_edge(pcm_clk) then
         pcm_audio_left_d   <= audio_left_i;
         pcm_audio_right_d  <= audio_right_i;
         pcm_audio_left_dd  <= pcm_audio_left_d;
         pcm_audio_right_dd <= pcm_audio_right_d;

         if pcm_audio_left_d = pcm_audio_left_dd and pcm_audio_right_d = pcm_audio_right_dd then
            pcm_audio_left  <= pcm_audio_left_dd;
            pcm_audio_right <= pcm_audio_right_dd;
         end if;
      end if;
   end process p_sample;


   ---------------------------------------------------------------------------------------------
   -- Digital output (HDMI) - Video part
   ---------------------------------------------------------------------------------------------

   reset_na <= not (video_rst_i or hdmi_rst_i or hr_rst_i);

   -- Clock enable for Overlay and HDMI video streams
   p_video_ce : process (video_clk_i)
   begin
      if rising_edge(video_clk_i) then
         video_ce_overlay <= video_ce_overlay(0) & video_ce_overlay(video_ce_overlay'left downto 1);
         video_ce_hdmi <= video_ce_hdmi(0) & video_ce_hdmi(video_ce_hdmi'left downto 1);
      end if;
   end process p_video_ce;

   i_ascal : entity work.ascal
      generic map (
         MASK      => x"ff",
         RAMBASE   => (others => '0'),
         RAMSIZE   => x"0020_0000", -- = 2MB
         INTER     => true,
         HEADER    => true,
         DOWNSCALE => true,
         BYTESWAP  => true,
         PALETTE   => true,
         PALETTE2  => true,
         FRAC      => 4,
         OHRES     => 2048,
         IHRES     => 2048,
         N_DW      => C_AVM_DATA_SIZE,
         N_AW      => C_AVM_ADDRESS_SIZE,
         N_BURST   => 256  -- 256 bytes per burst
      )
      port map (
         i_r               => unsigned(video_red_i),        -- input
         i_g               => unsigned(video_green_i),      -- input
         i_b               => unsigned(video_blue_i),       -- input
         i_hs              => video_hs_i,                   -- input
         i_vs              => video_vs_i,                   -- input
         i_fl              => '0',                          -- input
         i_de              => video_de_i,                   -- input
         i_ce              => video_ce_hdmi(0),             -- input
         i_clk             => video_clk_i,                  -- input
         o_r               => hdmi_red,                     -- output
         o_g               => hdmi_green,                   -- output
         o_b               => hdmi_blue,                    -- output
         o_hs              => hdmi_hs,                      -- output
         o_vs              => hdmi_vs,                      -- output
         o_de              => hdmi_de,                      -- output
         o_vbl             => open,                         -- output
         o_ce              => '1',                          -- input
         o_clk             => hdmi_clk_i,                   -- input
         o_border          => X"000000",                    -- input
         o_fb_ena          => '0',                          -- input
         o_fb_hsize        => 0,                            -- input
         o_fb_vsize        => 0,                            -- input
         o_fb_format       => "000100",                     -- input
         o_fb_base         => x"0000_0000",                 -- input
         o_fb_stride       => (others => '0'),              -- input
         pal1_clk          => '0',                          -- input
         pal1_dw           => x"000000000000",              -- input
         pal1_dr           => open,                         -- output
         pal1_a            => "0000000",                    -- input
         pal1_wr           => '0',                          -- input
         pal_n             => '0',                          -- input
         pal2_clk          => '0',                          -- input
         pal2_dw           => x"000000",                    -- input
         pal2_dr           => open,                         -- output
         pal2_a            => "00000000",                   -- input
         pal2_wr           => '0',                          -- input
         o_lltune          => open,                         -- output
         iauto             => '1',                          -- input
         himin             => 0,                            -- input
         himax             => 0,                            -- input
         vimin             => 0,                            -- input
         vimax             => 0,                            -- input
         i_hdmax           => open,                         -- output
         i_vdmax           => open,                         -- output
         run               => '1',                          -- input
         freeze            => '0',                          -- input
         mode              => "0" & hdmi_triple_buffering_i & "000", -- input
         htotal            => hdmi_htotal,                  -- input
         hsstart           => hdmi_hsstart,                 -- input
         hsend             => hdmi_hsend,                   -- input
         hdisp             => hdmi_hdisp,                   -- input
         vtotal            => hdmi_vtotal,                  -- input
         vsstart           => hdmi_vsstart,                 -- input
         vsend             => hdmi_vsend,                   -- input
         vdisp             => hdmi_vdisp,                   -- input
         hmin              => hdmi_hmin,                    -- input
         hmax              => hdmi_hmax,                    -- input
         vmin              => hdmi_vmin,                    -- input
         vmax              => hdmi_vmax,                    -- input
         format            => "01",                         -- input
         poly_clk          => '0',                          -- input
         poly_dw           => (others => '0'),              -- input
         poly_a            => (others => '0'),              -- input
         poly_wr           => '0',                          -- input
         avl_clk           => hr_clk_i,                     -- input
         avl_waitrequest   => hr_wide_waitrequest,          -- input
         avl_readdata      => hr_wide_readdata,             -- input
         avl_readdatavalid => hr_wide_readdatavalid,        -- input
         avl_burstcount    => hr_wide_burstcount,           -- output
         avl_writedata     => hr_wide_writedata,            -- output
         avl_address       => hr_wide_address,              -- output
         avl_write         => hr_wide_write,                -- output
         avl_read          => hr_wide_read,                 -- output
         avl_byteenable    => hr_wide_byteenable,           -- output
         reset_na          => reset_na                      -- input
      ); -- i_ascal

   i_avm_decrease : entity work.avm_decrease
      generic map (
         G_SLAVE_ADDRESS_SIZE  => C_AVM_ADDRESS_SIZE,
         G_SLAVE_DATA_SIZE     => C_AVM_DATA_SIZE,
         G_MASTER_ADDRESS_SIZE => 22,  -- HyperRAM size is 4 MWords = 8 MBytes.
         G_MASTER_DATA_SIZE    => 16
      )
      port map (
         clk_i                 => hr_clk_i,
         rst_i                 => hr_rst_i,
         s_avm_write_i         => hr_wide_write,
         s_avm_read_i          => hr_wide_read,
         s_avm_address_i       => hr_wide_address,
         s_avm_writedata_i     => hr_wide_writedata,
         s_avm_byteenable_i    => hr_wide_byteenable,
         s_avm_burstcount_i    => hr_wide_burstcount,
         s_avm_readdata_o      => hr_wide_readdata,
         s_avm_readdatavalid_o => hr_wide_readdatavalid,
         s_avm_waitrequest_o   => hr_wide_waitrequest,
         m_avm_write_o         => hr_write_o,
         m_avm_read_o          => hr_read_o,
         m_avm_address_o       => hr_address_o(21 downto 0), -- MSB defaults to zero
         m_avm_writedata_o     => hr_writedata_o,
         m_avm_byteenable_o    => hr_byteenable_o,
         m_avm_burstcount_o    => hr_burstcount_o,
         m_avm_readdata_i      => hr_readdata_i,
         m_avm_readdatavalid_i => hr_readdatavalid_i,
         m_avm_waitrequest_i   => hr_waitrequest_i
      ); -- i_avm_decrease


   i_video_overlay_hdmi : entity work.video_overlay
      generic  map (
         G_SHIFT          => G_SHIFT_HDMI,   -- Deprecated. Will be removed in future release
         G_VGA_DX         => G_VGA_DX,  -- TBD
         G_VGA_DY         => G_VGA_DY,  -- TBD
         G_FONT_DX        => C_FONT_DX,
         G_FONT_DY        => C_FONT_DY
      )
      port map (
         vga_clk_i        => hdmi_clk_i,
         vga_ce_i         => '1',
         vga_red_i        => std_logic_vector(hdmi_red),
         vga_green_i      => std_logic_vector(hdmi_green),
         vga_blue_i       => std_logic_vector(hdmi_blue),
         vga_hs_i         => hdmi_hs,
         vga_vs_i         => hdmi_vs,
         vga_de_i         => hdmi_de,
         vga_cfg_enable_i => hdmi_osm_cfg_enable_i,
         vga_cfg_xy_i     => hdmi_osm_cfg_xy_i,
         vga_cfg_dxdy_i   => hdmi_osm_cfg_dxdy_i,
         vga_vram_addr_o  => hdmi_osm_vram_addr_o,
         vga_vram_data_i  => hdmi_osm_vram_data_i,
         vga_ce_o         => open,
         vga_red_o        => hdmi_osm_red,
         vga_green_o      => hdmi_osm_green,
         vga_blue_o       => hdmi_osm_blue,
         vga_hs_o         => hdmi_osm_hs,
         vga_vs_o         => hdmi_osm_vs,
         vga_de_o         => hdmi_osm_de
      ); -- i_video_overlay_hdmi

   i_vga_to_hdmi : entity work.vga_to_hdmi
      port map (
         select_44100 => '0',
         dvi          => '0',
         vic          => std_logic_vector(to_unsigned(hdmi_video_mode.CEA_CTA_VIC, 8)),
         aspect       => hdmi_video_mode.ASPECT,
         pix_rep      => hdmi_video_mode.PIXEL_REP,
         vs_pol       => hdmi_video_mode.V_POL,
         hs_pol       => hdmi_video_mode.H_POL,

         vga_rst      => hdmi_rst_i,
         vga_clk      => hdmi_clk_i,
         vga_vs       => hdmi_osm_vs,
         vga_hs       => hdmi_osm_hs,
         vga_de       => hdmi_osm_de,
         vga_r        => hdmi_osm_red,
         vga_g        => hdmi_osm_green,
         vga_b        => hdmi_osm_blue,

         -- PCM audio
         pcm_clk      => pcm_clk,                             -- 256 * 48 kHz = 12.288 MHz
         pcm_rst      => pcm_rst,
         pcm_clken    => pcm_clken,                           -- 1/256 = 48 kHz
         pcm_l        => std_logic_vector(pcm_audio_left),
         pcm_r        => std_logic_vector(pcm_audio_right),
         pcm_acr      => pcm_acr,
         pcm_n        => pcm_n,
         pcm_cts      => pcm_cts,

         -- TMDS output (parallel)
         tmds         => hdmi_tmds
      ); -- i_vga_to_hdmi


   ---------------------------------------------------------------------------------------------
   -- tmds_clk (HDMI)
   ---------------------------------------------------------------------------------------------

   -- serialiser: in this design we use TMDS SelectIO outputs
   GEN_HDMI_DATA: for i in 0 to 2 generate
   begin
      I_HDMI_DATA: entity work.serialiser_10to1_selectio
      port map (
         rst     => hdmi_rst_i,
         clk     => hdmi_clk_i,
         clk_x5  => tmds_clk_i,
         d       => hdmi_tmds(i),
         out_p   => tmds_data_p_o(i),
         out_n   => tmds_data_n_o(i)
      ); -- I_HDMI_DATA: entity work.serialiser_10to1_selectio
   end generate GEN_HDMI_DATA;

   GEN_HDMI_CLK: entity work.serialiser_10to1_selectio
   port map (
         rst     => hdmi_rst_i,
         clk     => hdmi_clk_i,
         clk_x5  => tmds_clk_i,
         d       => "0000011111",
         out_p   => tmds_clk_p_o,
         out_n   => tmds_clk_n_o
      ); -- GEN_HDMI_CLK

end architecture synthesis;

