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
   constant CHARS_DX               : integer := G_VGA_DX / G_FONT_DX;
   constant CHARS_DY               : integer := G_VGA_DY / G_FONT_DY;

   type stage_t is record
      vga_col             : integer range 0 to 2047;
      vga_row             : integer range 0 to 2047;
      vga_osm_cfg_scaling : integer range 0 to 8;
      vga_osm_x1          : integer range 0 to 127;
      vga_osm_x2          : integer range 0 to 127;
      vga_osm_y1          : integer range 0 to 127;
      vga_osm_y2          : integer range 0 to 127;
      vga_col_delta       : integer range -2048 to 2047;
      vga_row_delta       : integer range -2048 to 2047;
      vga_x_div_16        : integer range 0 to 127;
      vga_y_div_16        : integer range 0 to 127;
      vga_x_mod_16        : integer range 0 to 15;
      vga_y_mod_16        : integer range 0 to 15;
      vga_osm_vram_addr   : std_logic_vector(15 downto 0);
      vga_osm_vram_attr   : std_logic_vector( 7 downto 0);
      vga_osm_on          : std_logic;
      vga_osm_rgb         : std_logic_vector(23 downto 0);
   end record stage_t;

   constant STATE_INIT : stage_t := (0,0,0,0,0,0,0,0,0,0,0,0,0,X"0000",X"00",'0',X"000000");

   signal stage1 : stage_t := STATE_INIT;
   signal stage2 : stage_t := STATE_INIT;
   signal stage3 : stage_t := STATE_INIT;
   signal stage4 : stage_t := STATE_INIT;
   signal stage5 : stage_t := STATE_INIT;
   signal stage6 : stage_t := STATE_INIT;
   signal stage7 : stage_t := STATE_INIT;
   signal stage5_vga_osm_font_addr : std_logic_vector(11 downto 0);
   signal stage5_vga_osm_vram_attr : std_logic_vector( 7 downto 0);
   signal stage6_vga_osm_font_data : std_logic_vector(15 downto 0);

begin

   -----------
   -- Stage 1
   -----------

   p_stage1 : process (clk_i)
      variable vga_osm_x : integer range 0 to 127;
      variable vga_osm_y : integer range 0 to 127;
   begin
      if rising_edge(clk_i) then
         vga_osm_x  := to_integer(vga_osm_cfg_xy_i(15 downto 8));
         vga_osm_y  := to_integer(vga_osm_cfg_xy_i(7 downto 0));
         stage1.vga_osm_x1          <= vga_osm_x;
         stage1.vga_osm_y1          <= vga_osm_y;
         stage1.vga_osm_x2          <= vga_osm_x + to_integer(vga_osm_cfg_dxdy_i(15 downto 8));
         stage1.vga_osm_y2          <= vga_osm_y + to_integer(vga_osm_cfg_dxdy_i( 7 downto 0));
         stage1.vga_col             <= vga_col_i;
         stage1.vga_row             <= vga_row_i;
         stage1.vga_col_delta       <= vga_col_i - to_integer(vga_osm_cfg_dxdy_i(15 downto 8)) * G_FONT_DX / 2;
         stage1.vga_row_delta       <= vga_row_i - to_integer(vga_osm_cfg_dxdy_i( 7 downto 0)) * G_FONT_DY / 2;
         stage1.vga_osm_cfg_scaling <= vga_osm_cfg_scaling_i;
      end if;
   end process p_stage1;


   -----------
   -- Stage 2
   -----------

   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2 <= stage1;
         -- This part implements the fractional scaling
         -- It also makes sure there is no overflow.
         -- Default is no scaling.
         if stage1.vga_col < G_VGA_DX then
            stage2.vga_col <= stage1.vga_col + (stage1.vga_osm_cfg_scaling * stage1.vga_col_delta) / 8;
         end if;
         if stage1.vga_row < G_VGA_DY then
            stage2.vga_row <= stage1.vga_row + (stage1.vga_osm_cfg_scaling * stage1.vga_row_delta) / 8;
         end if;
      end if;
   end process p_stage2;


   -----------
   -- Stage 3
   -----------

   p_stage3 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage3 <= stage2;
         stage3.vga_x_div_16 <= stage2.vga_col / G_FONT_DX;
         stage3.vga_y_div_16 <= stage2.vga_row / G_FONT_DY;
         stage3.vga_x_mod_16 <= stage2.vga_col mod G_FONT_DX;
         stage3.vga_y_mod_16 <= stage2.vga_row mod G_FONT_DY;
      end if;
   end process p_stage3;


   -----------
   -- Stage 4
   -----------

   p_stage4 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage4 <= stage3;
         stage4.vga_osm_vram_addr <= to_stdlogicvector(stage3.vga_y_div_16 * CHARS_DX + stage3.vga_x_div_16, 16);
      end if;
   end process p_stage4;


   -----------
   -- Stage 5
   -----------

   -- Read character and attribute from VRAM. Available in stage 5
   vga_osm_vram_addr_o <= stage4.vga_osm_vram_addr;

   p_stage5 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage5 <= stage4;
      end if;
   end process p_stage5;


   -----------
   -- Stage 6
   -----------

   -- Read font data. Available in stage 6
   stage5_vga_osm_font_addr <= to_stdlogicvector(to_integer(vga_osm_vram_data_i) * G_FONT_DY + stage5.vga_y_mod_16, 12);
   stage5_vga_osm_vram_attr <= vga_osm_vram_attr_i;

   -- 16x16 pixel font ROM
   inst_font : entity work.ram_init
      generic map (
         G_ADDR_WIDTH   => 12,
         G_DATA_WIDTH   => 16,
         G_ROM_PRELOAD  => true,
         G_ROM_FILE     => G_FONT_FILE,
         G_ROM_FILE_HEX => false
      )
      port map (
         clock_i   => clk_i,
         clen_i    => '1',
         address_i => stage5_vga_osm_font_addr,
         data_i    => (others => '0'),
         wren_i    => '0',
         q_o       => stage6_vga_osm_font_data
      ); -- inst_font

   p_stage6 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage6 <= stage5;
         stage6.vga_osm_vram_attr <= stage5_vga_osm_vram_attr;
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
         if stage6_vga_osm_font_data(15 - stage6.vga_x_mod_16) = not stage6.vga_osm_vram_attr(7) then
            -- foreground color
            stage7.vga_osm_rgb <= attr2rgb(stage6.vga_osm_vram_attr(6) & stage6.vga_osm_vram_attr(2 downto 0));
         else
            -- background color
            stage7.vga_osm_rgb <= attr2rgb(stage6.vga_osm_vram_attr(6 downto 3));
         end if;

         stage7.vga_osm_on <= '0';
         if stage6.vga_x_div_16 >= stage6.vga_osm_x1 and stage6.vga_x_div_16 < stage6.vga_osm_x2 and
            stage6.vga_y_div_16 >= stage6.vga_osm_y1 and stage6.vga_y_div_16 < stage6.vga_osm_y2
         then
            stage7.vga_osm_on <= vga_osm_cfg_enable_i;
         end if;
      end if;
   end process p_stage7;


   vga_osm_rgb_o <= stage7.vga_osm_rgb;
   vga_osm_on_o  <= stage7.vga_osm_on;

end architecture synthesis;

