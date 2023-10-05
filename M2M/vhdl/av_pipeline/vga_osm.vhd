-------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- VGA On-Screen-Menu (OSM)
--
-- The OSM is rendered using the font and is based on the the VRAM and
-- VRAM attribute memory.
--
-- The signals vga_osm_on_o and vga_osm_rgb_o are delayed four clock cycles after
-- vga_col_i and vga_row_i.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
-------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity vga_osm is
   generic  (
      G_VGA_DX              : natural;
      G_VGA_DY              : natural;
      G_FONT_FILE           : string;
      G_FONT_DX             : natural;
      G_FONT_DY             : natural
   );
   port (
      clk_i                 : in  std_logic;

      vga_col_i             : in  integer range 0 to 2047;
      vga_row_i             : in  integer range 0 to 2047;

      vga_osm_cfg_scaling_i : in  integer range 0 to 8;
      vga_osm_cfg_enable_i  : in  std_logic;
      vga_osm_cfg_xy_i      : in  std_logic_vector(15 downto 0);
      vga_osm_cfg_dxdy_i    : in  std_logic_vector(15 downto 0);
      vga_osm_vram_addr_o   : out std_logic_vector(15 downto 0);
      vga_osm_vram_data_i   : in  std_logic_vector(7 downto 0);
      vga_osm_vram_attr_i   : in  std_logic_vector(7 downto 0);

      vga_osm_on_o          : out std_logic;
      vga_osm_rgb_o         : out std_logic_vector(23 downto 0)
   );
end vga_osm;

architecture synthesis of vga_osm is

   -- Constants for VGA output
   constant CHARS_DX                 : integer := G_VGA_DX / G_FONT_DX;
   constant CHARS_DY                 : integer := G_VGA_DY / G_FONT_DY;

   signal stage1_vga_col             : integer range 0 to 2047;
   signal stage1_vga_row             : integer range 0 to 2047;
   signal stage1_vga_osm_cfg_scaling : integer range 0 to 8;
   signal stage1_vga_osm_x1          : integer range 0 to 127;
   signal stage1_vga_osm_x2          : integer range 0 to 127;
   signal stage1_vga_osm_y1          : integer range 0 to 127;
   signal stage1_vga_osm_y2          : integer range 0 to 127;
   signal stage1_vga_col_delta       : integer range 0 to 2047;
   signal stage1_vga_row_delta       : integer range 0 to 2047;
   signal stage1_vga_osm_on          : std_logic;

   signal stage2_vga_col             : integer range 0 to 2047;
   signal stage2_vga_row             : integer range 0 to 2047;
   signal stage2_vga_osm_x1          : integer range 0 to 127;
   signal stage2_vga_osm_y1          : integer range 0 to 127;
   signal stage2_vga_osm_x2          : integer range 0 to 127;
   signal stage2_vga_osm_y2          : integer range 0 to 127;
   signal stage2_vga_osm_on          : std_logic;

   signal stage3_vga_osm_x1          : integer range 0 to 127;
   signal stage3_vga_osm_y1          : integer range 0 to 127;
   signal stage3_vga_osm_x2          : integer range 0 to 127;
   signal stage3_vga_osm_y2          : integer range 0 to 127;
   signal stage3_vga_x_div_16        : integer range 0 to 127;
   signal stage3_vga_y_div_16        : integer range 0 to 127;
   signal stage3_vga_x_mod_16        : integer range 0 to 15;
   signal stage3_vga_y_mod_16        : integer range 0 to 15;
   signal stage3_vga_osm_on          : std_logic;

   signal stage4_vga_osm_x1          : integer range 0 to 127;
   signal stage4_vga_osm_y1          : integer range 0 to 127;
   signal stage4_vga_osm_x2          : integer range 0 to 127;
   signal stage4_vga_osm_y2          : integer range 0 to 127;
   signal stage4_vga_osm_vram_addr   : std_logic_vector(15 downto 0);
   signal stage4_vga_x_div_16        : integer range 0 to 127;
   signal stage4_vga_y_div_16        : integer range 0 to 127;
   signal stage4_vga_x_mod_16        : integer range 0 to 15;
   signal stage4_vga_y_mod_16        : integer range 0 to 15;
   signal stage4_vga_osm_on          : std_logic;

   signal stage5_vga_osm_x1          : integer range 0 to 127;
   signal stage5_vga_osm_y1          : integer range 0 to 127;
   signal stage5_vga_osm_x2          : integer range 0 to 127;
   signal stage5_vga_osm_y2          : integer range 0 to 127;
   signal stage5_vga_x_div_16        : integer range 0 to 127;
   signal stage5_vga_y_div_16        : integer range 0 to 127;
   signal stage5_vga_x_mod_16        : integer range 0 to 15;
   signal stage5_vga_y_mod_16        : integer range 0 to 15;
   signal stage5_vga_osm_vram_attr   : std_logic_vector( 7 downto 0);
   signal stage5_vga_osm_vram_data   : std_logic_vector( 7 downto 0);
   signal stage5_vga_osm_font_addr   : std_logic_vector(11 downto 0);
   signal stage5_vga_osm_on          : std_logic;

   signal stage6_vga_osm_x1          : integer range 0 to 127;
   signal stage6_vga_osm_y1          : integer range 0 to 127;
   signal stage6_vga_osm_x2          : integer range 0 to 127;
   signal stage6_vga_osm_y2          : integer range 0 to 127;
   signal stage6_vga_x_div_16        : integer range 0 to 127;
   signal stage6_vga_y_div_16        : integer range 0 to 127;
   signal stage6_vga_x_mod_16        : integer range 0 to 15;
   signal stage6_vga_osm_vram_attr   : std_logic_vector( 7 downto 0);
   signal stage6_vga_osm_font_data   : std_logic_vector(15 downto 0);
   signal stage6_vga_osm_on          : std_logic;

   signal stage7_vga_osm_on          : std_logic;
   signal stage7_vga_osm_rgb         : std_logic_vector(23 downto 0);

begin

   -----------
   -- Stage 1
   -----------

   p_stage1 : process (all)
      variable vga_osm_x : integer range 0 to 127;
      variable vga_osm_y : integer range 0 to 127;
   begin
      if rising_edge(clk_i) then
         vga_osm_x  := to_integer(vga_osm_cfg_xy_i(15 downto 8));
         vga_osm_y  := to_integer(vga_osm_cfg_xy_i(7 downto 0));
         stage1_vga_osm_x1          <= vga_osm_x;
         stage1_vga_osm_y1          <= vga_osm_y;
         stage1_vga_osm_x2          <= vga_osm_x + to_integer(vga_osm_cfg_dxdy_i(15 downto 8));
         stage1_vga_osm_y2          <= vga_osm_y + to_integer(vga_osm_cfg_dxdy_i( 7 downto 0));
         stage1_vga_col             <= vga_col_i;
         stage1_vga_row             <= vga_row_i;
         stage1_vga_col_delta       <= vga_col_i - to_integer(vga_osm_cfg_dxdy_i(15 downto 8)) * G_FONT_DX / 2;
         stage1_vga_row_delta       <= vga_row_i - to_integer(vga_osm_cfg_dxdy_i( 7 downto 0)) * G_FONT_DY / 2;
         stage1_vga_osm_cfg_scaling <= vga_osm_cfg_scaling_i;
         stage1_vga_osm_on          <= vga_osm_cfg_enable_i;
      end if;
   end process p_stage1;


   -----------
   -- Stage 2
   -----------

   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2_vga_osm_x1 <= stage1_vga_osm_x1;
         stage2_vga_osm_y1 <= stage1_vga_osm_y1;
         stage2_vga_osm_x2 <= stage1_vga_osm_x2;
         stage2_vga_osm_y2 <= stage1_vga_osm_y2;
         stage2_vga_col    <= stage1_vga_col;
         stage2_vga_row    <= stage1_vga_row;
         stage2_vga_osm_on <= stage1_vga_osm_on;
         -- This part implements the fractional scaling
         -- It also makes sure there is no overflow.
         -- Default is no scaling.
         if stage1_vga_col < G_VGA_DX then
            stage2_vga_col <= stage1_vga_col + (stage1_vga_osm_cfg_scaling * stage1_vga_col_delta) / 8;
         end if;
         if stage1_vga_row < G_VGA_DY then
            stage2_vga_row <= stage1_vga_row + (stage1_vga_osm_cfg_scaling * stage1_vga_row_delta) / 8;
         end if;
      end if;
   end process p_stage2;


   -----------
   -- Stage 3
   -----------

   p_stage3 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage3_vga_osm_x1   <= stage2_vga_osm_x1;
         stage3_vga_osm_y1   <= stage2_vga_osm_y1;
         stage3_vga_osm_x2   <= stage2_vga_osm_x2;
         stage3_vga_osm_y2   <= stage2_vga_osm_y2;
         stage3_vga_x_div_16 <= stage2_vga_col / G_FONT_DX;
         stage3_vga_y_div_16 <= stage2_vga_row / G_FONT_DY;
         stage3_vga_x_mod_16 <= stage2_vga_col mod G_FONT_DX;
         stage3_vga_y_mod_16 <= stage2_vga_row mod G_FONT_DY;
         stage3_vga_osm_on   <= stage2_vga_osm_on;
      end if;
   end process p_stage3;


   -----------
   -- Stage 4
   -----------

   p_stage4 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage4_vga_osm_x1   <= stage3_vga_osm_x1;
         stage4_vga_osm_y1   <= stage3_vga_osm_y1;
         stage4_vga_osm_x2   <= stage3_vga_osm_x2;
         stage4_vga_osm_y2   <= stage3_vga_osm_y2;
         stage4_vga_x_div_16 <= stage3_vga_x_div_16;
         stage4_vga_y_div_16 <= stage3_vga_y_div_16;
         stage4_vga_x_mod_16 <= stage3_vga_x_mod_16;
         stage4_vga_y_mod_16 <= stage3_vga_y_mod_16;
         stage4_vga_osm_vram_addr <= to_stdlogicvector(stage3_vga_y_div_16 * CHARS_DX + stage3_vga_x_div_16, 16);
         stage4_vga_osm_on   <= stage3_vga_osm_on;
      end if;
   end process p_stage4;


   -----------
   -- Stage 5
   -----------

   -- Read character and attribute from VRAM. Available in stage 5
   vga_osm_vram_addr_o <= stage4_vga_osm_vram_addr;

   p_stage5 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage5_vga_osm_x1   <= stage4_vga_osm_x1;
         stage5_vga_osm_y1   <= stage4_vga_osm_y1;
         stage5_vga_osm_x2   <= stage4_vga_osm_x2;
         stage5_vga_osm_y2   <= stage4_vga_osm_y2;
         stage5_vga_x_div_16 <= stage4_vga_x_div_16;
         stage5_vga_y_div_16 <= stage4_vga_y_div_16;
         stage5_vga_x_mod_16 <= stage4_vga_x_mod_16;
         stage5_vga_y_mod_16 <= stage4_vga_y_mod_16;
         stage5_vga_osm_on   <= stage4_vga_osm_on;
      end if;
   end process p_stage5;

   stage5_vga_osm_vram_attr <= vga_osm_vram_attr_i;
   stage5_vga_osm_vram_data <= vga_osm_vram_data_i;


   -----------
   -- Stage 6
   -----------

   -- Read font data. Available in stage 6
   stage5_vga_osm_font_addr <= to_stdlogicvector(to_integer(stage5_vga_osm_vram_data) * G_FONT_DY + stage5_vga_y_mod_16, 12);

   -- 16x16 pixel font ROM
   font : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH   => 12,
         DATA_WIDTH   => 16,
         ROM_PRELOAD  => true,
         ROM_FILE     => G_FONT_FILE
      )
      port map
      (
         clock_a      => clk_i,
         address_a    => stage5_vga_osm_font_addr,
         q_a          => stage6_vga_osm_font_data
      ); -- font

   p_stage6 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage6_vga_osm_x1        <= stage5_vga_osm_x1;
         stage6_vga_osm_y1        <= stage5_vga_osm_y1;
         stage6_vga_osm_x2        <= stage5_vga_osm_x2;
         stage6_vga_osm_y2        <= stage5_vga_osm_y2;
         stage6_vga_x_div_16      <= stage5_vga_x_div_16;
         stage6_vga_y_div_16      <= stage5_vga_y_div_16;
         stage6_vga_x_mod_16      <= stage5_vga_x_mod_16;
         stage6_vga_osm_vram_attr <= stage5_vga_osm_vram_attr;
         stage6_vga_osm_on        <= stage5_vga_osm_on;
      end if;
   end process p_stage6;


   -----------
   -- Stage 7
   -----------

   -- render OSM: calculate the pixel that needs to be shown at the given position
   p_stage7 : process (clk_i)

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
      if rising_edge(clk_i) then
         -- if pixel is set in font (and take care of inverse on/off)
         if stage6_vga_osm_font_data(15 - stage6_vga_x_mod_16) = not stage6_vga_osm_vram_attr(7) then
            -- foreground color
            stage7_vga_osm_rgb <= attr2rgb(stage6_vga_osm_vram_attr(6) & stage6_vga_osm_vram_attr(2 downto 0));
         else
            -- background color
            stage7_vga_osm_rgb <= attr2rgb(stage6_vga_osm_vram_attr(6 downto 3));
         end if;

         stage7_vga_osm_on <= '0';
         if stage6_vga_x_div_16 >= stage6_vga_osm_x1 and stage6_vga_x_div_16 < stage6_vga_osm_x2 and
            stage6_vga_y_div_16 >= stage6_vga_osm_y1 and stage6_vga_y_div_16 < stage6_vga_osm_y2
         then
            stage7_vga_osm_on <= stage6_vga_osm_on;
         end if;
      end if;
   end process p_stage7;


   vga_osm_rgb_o <= stage7_vga_osm_rgb;
   vga_osm_on_o  <= stage7_vga_osm_on;

end architecture synthesis;

