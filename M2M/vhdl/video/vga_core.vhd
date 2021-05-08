----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- VGA core interface.
--
-- This block provides a bridge between the VGA control block and the MEGA65 core.
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_core is
   generic  (
      G_VGA_DX          : integer;  -- 800
      G_VGA_DY          : integer;  -- 600
      G_GB_DX           : integer;  -- 160
      G_GB_DY           : integer;  -- 144
      G_GB_TO_VGA_SCALE : integer   -- 4 : 160x144 => 640x576
   );
   port (
      clk_i                : in  std_logic;
      rst_i                : in  std_logic;

      vga_col_i            : in  integer range 0 to G_VGA_DX - 1;
      vga_row_i            : in  integer range 0 to G_VGA_DY - 1;
      vga_core_vram_addr_o : out std_logic_vector(14 downto 0);
      vga_core_vram_data_i : in  std_logic_vector(23 downto 0);
      vga_core_on_o        : out std_logic;
      vga_core_rgb_o       : out std_logic_vector(23 downto 0)    -- 23..0 = RGB, 8 bits each
   );
end vga_core;

architecture synthesis of vga_core is

   signal vga_col_next : integer range 0 to G_VGA_DX - 1;
   signal vga_row_next : integer range 0 to G_VGA_DY - 1;

begin

   -- Scaler: 160 x 144 => 4x => 640 x 576
   -- Scaling by 4 is a convenient special case: We just need to use a SHR operation.
   -- We are doing this by taking the bits "9 downto 2" from the current column and row.
   -- This is a hardcoded and very fast operation.
   p_scaler : process (all)
      variable src_x: std_logic_vector(9 downto 0);
      variable src_y: std_logic_vector(9 downto 0);
      variable dst_x: std_logic_vector(7 downto 0);
      variable dst_y: std_logic_vector(7 downto 0);
      variable dst_x_i: integer range 0 to G_GB_DX - 1;
      variable dst_y_i: integer range 0 to G_GB_DY - 1;
      variable nextrow: integer range 0 to G_GB_DY - 1;
   begin
      src_x   := std_logic_vector(to_unsigned(vga_col_i, 10));
      src_y   := std_logic_vector(to_unsigned(vga_row_i, 10));
      dst_x   := src_x(9 downto 2);
      dst_y   := src_y(9 downto 2);
      dst_x_i := to_integer(unsigned(dst_x));
      dst_y_i := to_integer(unsigned(dst_y));
      nextrow := dst_y_i + 1;

      -- The dual port & dual clock RAM needs one clock cycle to provide the data. Therefore we need
      -- to always address one pixel ahead of where we currently stand
      if dst_x_i < G_GB_DX - 1 then
         vga_col_next <= dst_x_i + 1;
         vga_row_next <= dst_y_i;
      else
         vga_col_next <= 0;
         if nextrow < G_GB_DY then
            vga_row_next <= nextrow;
         else
            vga_row_next <= 0;
         end if;
      end if;
   end process p_scaler;

   vga_core_vram_addr_o <= std_logic_vector(to_unsigned(vga_row_next * G_GB_DX + vga_col_next, 15));

   vga_core_on_o <= '1' when
            vga_col_i >= 0 and vga_col_i < G_GB_DX * G_GB_TO_VGA_SCALE and
            vga_row_i >= 0 and vga_row_i < G_GB_DY * G_GB_TO_VGA_SCALE
         else '0';
   vga_core_rgb_o <= vga_core_vram_data_i;

end synthesis;

