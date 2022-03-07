library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_wrapper is
   generic  (
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

   signal vga_ce_1      : std_logic;
   signal vga_pix_x_1   : std_logic_vector(10 downto 0);
   signal vga_pix_y_1   : std_logic_vector(10 downto 0);
   signal vga_red_1     : std_logic_vector(7 downto 0);
   signal vga_green_1   : std_logic_vector(7 downto 0);
   signal vga_blue_1    : std_logic_vector(7 downto 0);
   signal vga_hs_1      : std_logic;
   signal vga_vs_1      : std_logic;
   signal vga_de_1      : std_logic;

   signal vga_ce_2      : std_logic;
   signal vga_red_2     : std_logic_vector(7 downto 0);
   signal vga_green_2   : std_logic_vector(7 downto 0);
   signal vga_blue_2    : std_logic_vector(7 downto 0);
   signal vga_hs_2      : std_logic;
   signal vga_vs_2      : std_logic;
   signal vga_de_2      : std_logic;
   signal vga_osm_on_2  : std_logic;
   signal vga_osm_rgb_2 : std_logic_vector(23 downto 0);

begin

   i_vga_recover_counters : entity work.vga_recover_counters
      port map (
         vga_clk_i   => vga_clk_i,
         vga_ce_i    => vga_ce_i,
         vga_red_i   => vga_red_i,
         vga_green_i => vga_green_i,
         vga_blue_i  => vga_blue_i,
         vga_hs_i    => vga_hs_i,
         vga_vs_i    => vga_vs_i,
         vga_de_i    => vga_de_i,
         vga_ce_o    => vga_ce_1,
         vga_pix_x_o => vga_pix_x_1,
         vga_pix_y_o => vga_pix_y_1,
         vga_red_o   => vga_red_1,
         vga_green_o => vga_green_1,
         vga_blue_o  => vga_blue_1,
         vga_hs_o    => vga_hs_1,
         vga_vs_o    => vga_vs_1,
         vga_de_o    => vga_de_1
      ); -- i_vga_recover_counters

   p_pipeline : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_ce_2    <= vga_ce_1;
         vga_red_2   <= vga_red_1;
         vga_green_2 <= vga_green_1;
         vga_blue_2  <= vga_blue_1;
         vga_hs_2    <= vga_hs_1;
         vga_vs_2    <= vga_vs_1;
         vga_de_2    <= vga_de_1;
      end if;
   end process p_pipeline;

   i_vga_osm : entity work.vga_osm
      generic  map (
         G_VGA_DX  => G_VGA_DX,
         G_VGA_DY  => G_VGA_DY,
         G_FONT_DX => G_FONT_DX,
         G_FONT_DY => G_FONT_DY
      )
      port map (
         clk_i                => vga_clk_i,
         vga_col_i            => to_integer(unsigned(vga_pix_x_1)),
         vga_row_i            => to_integer(unsigned(vga_pix_y_1)),
         vga_osm_cfg_enable_i => vga_cfg_enable_i,
         vga_osm_cfg_xy_i     => vga_cfg_xy_i,
         vga_osm_cfg_dxdy_i   => vga_cfg_dxdy_i,
         vga_osm_vram_addr_o  => vga_vram_addr_o,
         vga_osm_vram_data_i  => vga_vram_data_i,
         vga_osm_vram_attr_i  => vga_vram_attr_i,
         vga_osm_on_o         => vga_osm_on_2,
         vga_osm_rgb_o        => vga_osm_rgb_2
      ); -- i_vga_osm

   vga_ce_o    <= vga_ce_2;
   vga_red_o   <= vga_osm_rgb_2(23 downto 16) when vga_osm_on_2 = '1' else vga_red_2;
   vga_green_o <= vga_osm_rgb_2(15 downto  8) when vga_osm_on_2 = '1' else vga_green_2;
   vga_blue_o  <= vga_osm_rgb_2( 7 downto  0) when vga_osm_on_2 = '1' else vga_blue_2;
   vga_hs_o    <= vga_hs_2;
   vga_vs_o    <= vga_vs_2;
   vga_de_o    <= vga_de_2;

end architecture synthesis;

