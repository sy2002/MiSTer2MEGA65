library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_overlay is
   generic  (
      G_SHIFT          : integer := 0;    -- Deprecated. Will be removed in future release
      G_VGA_DX         : natural;
      G_VGA_DY         : natural;
      G_FONT_FILE      : string;
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
      vga_vram_data_i  : in  std_logic_vector(15 downto 0);

      -- VGA output
      vga_ce_o         : out std_logic;
      vga_red_o        : out std_logic_vector(7 downto 0);
      vga_green_o      : out std_logic_vector(7 downto 0);
      vga_blue_o       : out std_logic_vector(7 downto 0);
      vga_hs_o         : out std_logic;
      vga_vs_o         : out std_logic;
      vga_de_o         : out std_logic
   );
end entity video_overlay;

architecture synthesis of video_overlay is

   -- Delayed VGA signals
   signal vga_ce_d       : std_logic;
   signal vga_pix_x_d    : std_logic_vector(10 downto 0);
   signal vga_pix_y_d    : std_logic_vector(10 downto 0);
   signal vga_red_d      : std_logic_vector(7 downto 0);
   signal vga_green_d    : std_logic_vector(7 downto 0);
   signal vga_blue_d     : std_logic_vector(7 downto 0);
   signal vga_hs_d       : std_logic;
   signal vga_vs_d       : std_logic;
   signal vga_de_d       : std_logic;

   signal vga_osm_on_dd  : std_logic;
   signal vga_osm_rgb_dd : std_logic_vector(23 downto 0);   -- 23..0 = RGB, 8 bits each
   signal vga_red_dd     : std_logic_vector(7 downto 0);
   signal vga_green_dd   : std_logic_vector(7 downto 0);
   signal vga_blue_dd    : std_logic_vector(7 downto 0);
   signal vga_hs_dd      : std_logic;
   signal vga_vs_dd      : std_logic;
   signal vga_de_dd      : std_logic;
   signal vga_ce_dd      : std_logic;

begin

   -----------------------------------------------
   -- Recover pixel counters
   -----------------------------------------------

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
         vga_ce_o    => vga_ce_d,
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
         G_VGA_DX             => G_VGA_DX,
         G_VGA_DY             => G_VGA_DY,
         G_FONT_FILE          => G_FONT_FILE,
         G_FONT_DX            => G_FONT_DX,
         G_FONT_DY            => G_FONT_DY
      )
      port map (
         clk_i                => vga_clk_i,
         vga_col_i            => to_integer(unsigned(vga_pix_x_d)) - G_SHIFT,
         vga_row_i            => to_integer(unsigned(vga_pix_y_d)),
         vga_osm_cfg_xy_i     => vga_cfg_xy_i,
         vga_osm_cfg_dxdy_i   => vga_cfg_dxdy_i,
         vga_osm_cfg_enable_i => vga_cfg_enable_i,
         vga_osm_vram_addr_o  => vga_vram_addr_o,
         vga_osm_vram_data_i  => vga_vram_data_i( 7 downto 0),
         vga_osm_vram_attr_i  => vga_vram_data_i(15 downto 8),
         vga_osm_on_o         => vga_osm_on_dd,
         vga_osm_rgb_o        => vga_osm_rgb_dd
      ); -- i_vga_osm


   -- Clear video output outside visible screen.
   -- This also delays the video stream to bring it in sync with the OSM overlay.
   p_clear_invisible : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_red_dd   <= (others => '0');
         vga_blue_dd  <= (others => '0');
         vga_green_dd <= (others => '0');

         if vga_de_d then
            vga_red_dd   <= vga_red_d;
            vga_green_dd <= vga_green_d;
            vga_blue_dd  <= vga_blue_d;
         end if;

         vga_hs_dd <= vga_hs_d;
         vga_vs_dd <= vga_vs_d;
         vga_de_dd <= vga_de_d;
         vga_ce_dd <= vga_ce_d;
      end if;
   end process; -- p_clear_invisible

   p_output_registers : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Output from Core
         vga_red_o   <= vga_red_dd;
         vga_green_o <= vga_green_dd;
         vga_blue_o  <= vga_blue_dd;

         -- On-Screen Menu overlay
         if vga_osm_on_dd = '1' then
            vga_red_o   <= vga_osm_rgb_dd(23 downto 16);
            vga_green_o <= vga_osm_rgb_dd(15 downto  8);
            vga_blue_o  <= vga_osm_rgb_dd( 7 downto  0);
         end if;

         vga_hs_o    <= vga_hs_dd;
         vga_vs_o    <= vga_vs_dd;
         vga_de_o    <= vga_de_dd;
         vga_ce_o    <= vga_ce_dd;
      end if;
   end process; -- p_output_registers

end architecture synthesis;

