library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.video_modes_pkg.all;

entity vga_wrapper is
   generic  (
      G_VIDEO_MODE     : video_modes_t;
      G_VGA_DX         : natural;
      G_VGA_DY         : natural;
      G_FONT_DX        : natural;
      G_FONT_DY        : natural
   );
   port (
      vga_clk_i        : in  std_logic;

      -- VGA input
      vga_ce_i         : in  std_logic;
      vga_red_i        : in  std_logic_vector(7 downto 0);
      vga_green_i      : in  std_logic_vector(7 downto 0);
      vga_blue_i       : in  std_logic_vector(7 downto 0);
      vga_hs_i         : in  std_logic;
      vga_vs_i         : in  std_logic;
      vga_de_i         : in  std_logic;

      -- QNICE
      vga_cfg_enable_i : in  std_logic;
      vga_cfg_xy_i     : in  std_logic_vector(15 downto 0);
      vga_cfg_dxdy_i   : in  std_logic_vector(15 downto 0);
      vga_vram_addr_o  : out std_logic_vector(15 downto 0);
      vga_vram_data_i  : in  std_logic_vector(7 downto 0);
      vga_vram_attr_i  : in  std_logic_vector(7 downto 0);

      -- VGA output
      vga_ce_o         : out std_logic;
      vga_red_o        : out std_logic_vector(7 downto 0);
      vga_green_o      : out std_logic_vector(7 downto 0);
      vga_blue_o       : out std_logic_vector(7 downto 0);
      vga_hs_o         : out std_logic;
      vga_vs_o         : out std_logic;
      vga_de_o         : out std_logic
   );
end entity vga_wrapper;

architecture synthesis of vga_wrapper is

   -- Delayed VGA signals
   signal vga_pix_x_d : std_logic_vector(10 downto 0);
   signal vga_pix_y_d : std_logic_vector(10 downto 0);
   signal vga_red_d   : std_logic_vector(7 downto 0);
   signal vga_green_d : std_logic_vector(7 downto 0);
   signal vga_blue_d  : std_logic_vector(7 downto 0);
   signal vga_hs_d    : std_logic;
   signal vga_vs_d    : std_logic;
   signal vga_de_d    : std_logic;

   signal vga_osm_on_d  : std_logic;
   signal vga_osm_rgb_d : std_logic_vector(23 downto 0);   -- 23..0 = RGB, 8 bits each

begin

   -----------------------------------------------
   -- Recover pixel counters
   -----------------------------------------------

   i_vga_recover_counters : entity work.vga_recover_counters
      port map (
         vga_clk_i   => vga_clk_i,
         vga_ce_i    => '1',
         vga_red_i   => vga_red_i,
         vga_green_i => vga_green_i,
         vga_blue_i  => vga_blue_i,
         vga_hs_i    => vga_hs_i,
         vga_vs_i    => vga_vs_i,
         vga_de_i    => vga_de_i,
         vga_ce_o    => open,
         vga_pix_x_o => vga_pix_x_d,
         vga_pix_y_o => vga_pix_y_d,
         vga_red_o   => vga_red_d,
         vga_green_o => vga_green_d,
         vga_blue_o  => vga_blue_d,
         vga_hs_o    => vga_hs_d,
         vga_vs_o    => vga_vs_d,
         vga_de_o    => vga_de_d
      ); -- i_vga_recover_counters


   -----------------------------------------------
   -- Instantiate On-Screen-Menu generator
   -----------------------------------------------

   i_vga_osm : entity work.vga_osm
      generic map (
         G_VGA_DX             => G_VIDEO_MODE.H_PIXELS,
         G_VGA_DY             => G_VIDEO_MODE.V_PIXELS,
         G_FONT_DX            => G_FONT_DX,
         G_FONT_DY            => G_FONT_DY
      )
      port map (
         clk_i                => vga_clk_i,
         vga_col_i            => to_integer(unsigned(vga_pix_x_d)),
         vga_row_i            => to_integer(unsigned(vga_pix_y_d)),
         vga_osm_cfg_xy_i     => vga_cfg_xy_i,
         vga_osm_cfg_dxdy_i   => vga_cfg_dxdy_i,
         vga_osm_cfg_enable_i => vga_cfg_enable_i,
         vga_osm_vram_addr_o  => vga_vram_addr_o,
         vga_osm_vram_data_i  => vga_vram_data_i,
         vga_osm_vram_attr_i  => vga_vram_attr_i,
         vga_osm_on_o         => vga_osm_on_d,
         vga_osm_rgb_o        => vga_osm_rgb_d
      ); -- i_vga_osm : entity work.vga_osm



   p_video_signal_latches : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Default border color
         vga_red_o   <= (others => '0');
         vga_blue_o  <= (others => '0');
         vga_green_o <= (others => '0');

         if vga_de_d then
            -- MiSTer core output
            vga_red_o   <= vga_red_d;
            vga_green_o <= vga_green_d;
            vga_blue_o  <= vga_blue_d;

            -- On-Screen-Menu (OSM) output
            if vga_osm_on_d then
               vga_red_o   <= vga_osm_rgb_d(23 downto 16);
               vga_green_o <= vga_osm_rgb_d(15 downto 8);
               vga_blue_o  <= vga_osm_rgb_d(7 downto 0);
            end if;
         end if;

         -- VGA horizontal and vertical sync
         vga_hs_o <= vga_hs_d;
         vga_vs_o <= vga_vs_d;
         vga_de_o <= vga_de_d;
      end if;
   end process; -- p_video_signal_latches : process(vga_pixelclk)

end architecture synthesis;

