----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- VGA On-Screen-Memory interface.
--
-- This block provides a bridge between the VGA control block and the QNICE core.
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 and MJoergen in 2021 and licensed under GPL v3
--
-- The signals vga_osm_on_o and vga_osm_rgb_o are delayed one clock cycle after
-- vga_col_i and vga_row_i.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

entity vga_osm is
   generic  (
      G_VGA_DX : integer;
      G_VGA_DY : integer
   );
   port (
      clk_i                : in  std_logic;
      rst_i                : in  std_logic;

      vga_col_i            : in  integer range 0 to G_VGA_DX - 1;
      vga_row_i            : in  integer range 0 to G_VGA_DY - 1;

      vga_osm_cfg_enable_i : in  std_logic;
      vga_osm_cfg_xy_i     : in  std_logic_vector(15 downto 0);
      vga_osm_cfg_dxdy_i   : in  std_logic_vector(15 downto 0);
      vga_osm_vram_addr_o  : out std_logic_vector(15 downto 0);
      vga_osm_vram_data_i  : in  std_logic_vector(7 downto 0);
      vga_osm_vram_attr_i  : in  std_logic_vector(7 downto 0);

      vga_osm_on_o         : out std_logic;
      vga_osm_rgb_o        : out std_logic_vector(23 downto 0)
   );
end vga_osm;

architecture synthesis of vga_osm is

   -- Constants for VGA output
   constant FONT_DX           : integer := 16;
   constant FONT_DY           : integer := 16;
   constant CHARS_DX          : integer := G_VGA_DX / FONT_DX;
   constant CHARS_DY          : integer := G_VGA_DY / FONT_DY;

   -- VGA signals
   signal vga_osm_x1          : integer range 0 to CHARS_DX - 1;
   signal vga_osm_x2          : integer range 0 to CHARS_DX - 1;
   signal vga_osm_y1          : integer range 0 to CHARS_DY - 1;
   signal vga_osm_y2          : integer range 0 to CHARS_DY - 1;

   signal vga_x_div_16        : integer range 0 to CHARS_DX - 1;
   signal vga_y_div_16        : integer range 0 to CHARS_DY - 1;
   signal vga_x_mod_16        : integer range 0 to 15;
   signal vga_y_mod_16        : integer range 0 to 15;

   signal vga_x_div_16_d      : integer range 0 to CHARS_DX - 1;
   signal vga_y_div_16_d      : integer range 0 to CHARS_DY - 1;
   signal vga_x_mod_16_d      : integer range 0 to 15;
   signal vga_y_mod_16_d      : integer range 0 to 15;

   signal vga_osm_font_addr_d : std_logic_vector(11 downto 0);
   signal vga_osm_font_data_d : std_logic_vector(15 downto 0);

begin

   calc_boundaries : process (all)
      variable vga_osm_x : integer range 0 to CHARS_DX - 1;
      variable vga_osm_y : integer range 0 to CHARS_DY - 1;
   begin
      vga_osm_x  := to_integer(unsigned(vga_osm_cfg_xy_i(15 downto 8)));
      vga_osm_y  := to_integer(unsigned(vga_osm_cfg_xy_i(7 downto 0)));
      vga_osm_x1 <= vga_osm_x;
      vga_osm_y1 <= vga_osm_y;
      vga_osm_x2 <= vga_osm_x + to_integer(unsigned(vga_osm_cfg_dxdy_i(15 downto 8)));
      vga_osm_y2 <= vga_osm_y + to_integer(unsigned(vga_osm_cfg_dxdy_i(7 downto 0)));
   end process calc_boundaries;

   vga_x_div_16 <= to_integer(to_unsigned(vga_col_i, 16)(9 downto 4));
   vga_y_div_16 <= to_integer(to_unsigned(vga_row_i, 16)(9 downto 4));
   vga_x_mod_16 <= to_integer(to_unsigned(vga_col_i, 16)(3 downto 0));
   vga_y_mod_16 <= to_integer(to_unsigned(vga_row_i, 16)(3 downto 0));

   -- Read character and attribute from VRAM. Available in the next clock cycle.
   vga_osm_vram_addr_o <= std_logic_vector(to_unsigned(vga_y_div_16 * CHARS_DX + vga_x_div_16, 16));

   -- Read font data. (Almost) combinatorial read.
   vga_osm_font_addr_d <= std_logic_vector(to_unsigned(to_integer(unsigned(vga_osm_vram_data_i)) * FONT_DY + vga_y_mod_16, 12));

   -- 16x16 pixel font ROM
   -- This reads on the falling clock edge, and is therefore equivalent to a combinatorial read.
   font : entity work.BROM
      generic map
      (
         FILE_NAME    => "../font/Anikki-16x16.rom",
         ADDR_WIDTH   => 12,
         DATA_WIDTH   => 16,
         LATCH_ACTIVE => false
      )
      port map
      (
         clk          => clk_i,
         ce           => '1',
         address      => vga_osm_font_addr_d,
         data         => vga_osm_font_data_d
      ); -- font : entity work.BROM

   p_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_x_div_16_d <= vga_x_div_16;
         vga_y_div_16_d <= vga_y_div_16;
         vga_x_mod_16_d <= vga_x_mod_16;
         vga_y_mod_16_d <= vga_y_mod_16;
      end if;
   end process p_delay;

   -- render OSM: calculate the pixel that needs to be shown at the given position
   render_osm : process (all)

      function attr2rgb(attr: in std_logic_vector(3 downto 0)) return std_logic_vector is
         variable r, g, b    : std_logic_vector(7 downto 0);
         variable brightness : std_logic_vector(7 downto 0);
      begin
         brightness := x"FF" when attr(3) = '0' else x"7F";
         r := brightness when attr(2) = '1' else x"00";
         g := brightness when attr(1) = '1' else x"00";
         b := brightness when attr(0) = '1' else x"00";
         return r & g & b;
      end attr2rgb;

   begin
      -- if pixel is set in font (and take care of inverse on/off)
      if vga_osm_font_data_d(15 - vga_x_mod_16_d) = not vga_osm_vram_attr_i(7) then
         -- foreground color
         vga_osm_rgb_o <= attr2rgb(vga_osm_vram_attr_i(6) & vga_osm_vram_attr_i(2 downto 0));
      else
         -- background color
         vga_osm_rgb_o <= attr2rgb(vga_osm_vram_attr_i(6 downto 3));
      end if;

   end process render_osm;

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_osm_on_o <= '0';
         if vga_x_div_16 >= vga_osm_x1 and vga_x_div_16 < vga_osm_x2 and
            vga_y_div_16 >= vga_osm_y1 and vga_y_div_16 < vga_osm_y2
         then
            vga_osm_on_o <= vga_osm_cfg_enable_i;
         end if;
      end if;
   end process;

end synthesis;

