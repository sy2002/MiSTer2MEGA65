library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity democore_pixel is
   generic  (
      G_VGA_DX            : natural;
      G_VGA_DY            : natural
   );
   port (
      vga_clk_i            : in  std_logic;
      vga_col_i            : in  integer range 0 to G_VGA_DX - 1;
      vga_row_i            : in  integer range 0 to G_VGA_DY - 1;
      vga_core_rgb_o       : out std_logic_vector(23 downto 0)    -- 23..0 = RGB, 8 bits each
   );
end entity democore_pixel;

architecture synthesis of democore_pixel is

   constant C_BORDER  : integer := 4;  -- Number of pixels
   constant C_SQ_SIZE : integer := 50; -- Number of pixels

   signal pos_x : integer range 0 to G_VGA_DX-1 := G_VGA_DX/2;
   signal pos_y : integer range 0 to G_VGA_DY-1 := G_VGA_DY/2;
   signal vel_x : integer range -7 to 7         := 1;
   signal vel_y : integer range -7 to 7         := 1;

begin

   p_rgb : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Render background
         vga_core_rgb_o <= X"88CCAA";

         -- Render white border
         if vga_col_i < C_BORDER or vga_col_i + C_BORDER >= G_VGA_DX or
            vga_row_i < C_BORDER or vga_row_i + C_BORDER >= G_VGA_DY then
            vga_core_rgb_o <= X"FFFFFF";
         end if;

         -- Render red-ish square
         if vga_col_i >= pos_x and vga_col_i < pos_x + C_SQ_SIZE and
            vga_row_i >= pos_y and vga_row_i < pos_y + C_SQ_SIZE then
            vga_core_rgb_o <= X"EE2040";
         end if;
      end if;
   end process p_rgb;


   -- Move the square
   p_move : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Update once each frame
         if vga_col_i = 0 and vga_row_i = 0 then
            pos_x <= pos_x + vel_x;
            pos_y <= pos_y + vel_y;

            if pos_x + vel_x >= G_VGA_DX - C_SQ_SIZE - C_BORDER and vel_x > 0 then
               vel_x <= -vel_x;
            end if;

            if pos_x + vel_x < C_BORDER and vel_x < 0 then
               vel_x <= -vel_x;
            end if;

            if pos_y + vel_y >= G_VGA_DY - C_SQ_SIZE - C_BORDER and vel_y > 0 then
               vel_y <= -vel_y;
            end if;

            if pos_y + vel_y < C_BORDER and vel_y < 0 then
               vel_y <= -vel_y;
            end if;
         end if;
      end if;
   end process p_move;

end architecture synthesis;

