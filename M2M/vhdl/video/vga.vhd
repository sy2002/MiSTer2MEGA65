-------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- VGA control block
--
-- This block overlays the On Screen Menu (OSM) on top of the MiSTer Core output.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
-------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;
use work.video_modes_pkg.all;

entity vga is
   generic  (
      G_VIDEO_MODE         : video_modes_t;
      G_CORE_DX            : natural;
      G_CORE_DY            : natural;
      G_CORE_TO_VGA_SCALE  : natural;
      G_FONT_DX            : natural;
      G_FONT_DY            : natural
   );
   port (
      clk_i                : in  std_logic;
      rstn_i               : in  std_logic;

      -- OSM configuration from QNICE
      vga_osm_cfg_enable_i : in  std_logic;
      vga_osm_cfg_xy_i     : in  std_logic_vector(15 downto 0);
      vga_osm_cfg_dxdy_i   : in  std_logic_vector(15 downto 0);

      -- OSM interface to VRAM (character RAM and attribute RAM)
      vga_osm_vram_addr_o  : out std_logic_vector(15 downto 0);
      vga_osm_vram_data_i  : in  std_logic_vector(7 downto 0);
      vga_osm_vram_attr_i  : in  std_logic_vector(7 downto 0);

      -- Core interface to VRAM (24-bit RGB colors in the core's native resolution)
      vga_core_vram_addr_o : out std_logic_vector(14 downto 0);
      vga_core_vram_data_i : in  std_logic_vector(23 downto 0);

      -- VGA / VDAC output
      vga_red_o            : out std_logic_vector(7 downto 0);
      vga_green_o          : out std_logic_vector(7 downto 0);
      vga_blue_o           : out std_logic_vector(7 downto 0);
      vga_hs_o             : out std_logic;
      vga_vs_o             : out std_logic;
      vga_de_o             : out std_logic;
      vdac_clk_o           : out std_logic;
      vdac_sync_n_o        : out std_logic;
      vdac_blank_n_o       : out std_logic
   );
end vga;

architecture synthesis of vga is

   -- VGA signals
   signal vga_hs         : std_logic;
   signal vga_vs         : std_logic;
   signal vga_disp_en    : std_logic;

--
--   -- Core and OSM pixel data
   signal vga_core_on_d  : std_logic;
   signal vga_core_rgb_d : std_logic_vector(23 downto 0);   -- 23..0 = RGB, 8 bits each
--   signal vga_osm_on_d   : std_logic;
--   signal vga_osm_rgb_d  : std_logic_vector(23 downto 0);   -- 23..0 = RGB, 8 bits each

begin

   i_democore : entity work.democore
      generic map (
         G_CORE_CLK_SPEED     => 0,
         G_VIDEO_MODE         => G_VIDEO_MODE,
         G_OUTPUT_DX          => 0,
         G_OUTPUT_DY          => 0
      )
      port map (
         clk_main_i           => clk_i,
         reset_i              => '0',
         pause_i              => '0',
         keyboard_n_i         => "000",
         vga_ce_o             => open,
         vga_red_o            => vga_core_rgb_d(23 downto 16),
         vga_green_o          => vga_core_rgb_d(15 downto  8),
         vga_blue_o           => vga_core_rgb_d( 7 downto  0),
         vga_vs_o             => vga_vs,
         vga_hs_o             => vga_hs,
         vga_de_o             => vga_disp_en,
         audio_left_o         => open,
         audio_right_o        => open
      ); -- i_democore
   vga_core_on_d <= '1';

   i_vga_wrapper : entity work.vga_wrapper
      generic  map (
         G_VIDEO_MODE     => G_VIDEO_MODE,
         G_VGA_DX         => G_VIDEO_MODE.H_PIXELS,
         G_VGA_DY         => G_VIDEO_MODE.V_PIXELS,
         G_FONT_DX        => G_FONT_DX,
         G_FONT_DY        => G_FONT_DY
      )
      port map (
         vga_clk_i        => clk_i,
         vga_ce_i         => '1',
         vga_red_i        => vga_core_rgb_d(23 downto 16),
         vga_green_i      => vga_core_rgb_d(15 downto  8),
         vga_blue_i       => vga_core_rgb_d( 7 downto  0),
         vga_vs_i         => vga_vs,
         vga_hs_i         => vga_hs,
         vga_de_i         => vga_disp_en,
         vga_cfg_enable_i => vga_osm_cfg_enable_i,
         vga_cfg_xy_i     => vga_osm_cfg_xy_i,
         vga_cfg_dxdy_i   => vga_osm_cfg_dxdy_i,
         vga_vram_addr_o  => vga_osm_vram_addr_o,
         vga_vram_data_i  => vga_osm_vram_data_i,
         vga_vram_attr_i  => vga_osm_vram_attr_i,
         vga_ce_o         => open,
         vga_red_o        => vga_red_o,
         vga_green_o      => vga_green_o,
         vga_blue_o       => vga_blue_o,
         vga_hs_o         => vga_hs_o,
         vga_vs_o         => vga_vs_o,
         vga_de_o         => vga_de_o
      ); -- i_vga_wrapper


   -- make the VDAC output the image
   -- for some reason, the VDAC does not like non-zero values outside the visible window
   -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
   -- TODO: check that
   vdac_sync_n_o  <= '0';
   vdac_blank_n_o <= '1';
   vdac_clk_o     <= not clk_i; -- inverting the clock leads to a sharper signal for some reason

end synthesis;

