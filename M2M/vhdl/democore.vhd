------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Demo core that produces a test image including test sound, so that MiSTer2MEGA65
-- can be synthesized and tested stand alone even before the MiSTer core is being
-- applied. The MEGA65 "Help" menu can be used to change the behavior of the core.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity democore is
   generic (
      -- The democore is configured to generate a PAL signal at 720x576 @ 50 Hz resolution.
      CLK_KHZ   : integer := 27000;
      H_PIXELS  : integer :=   720;      -- horizontal display width in pixels
      V_PIXELS  : integer :=   576;      -- vertical display width in rows
      H_FP      : integer :=    17;      -- horizontal front porch width in pixels
      H_PULSE   : integer :=    64;      -- horizontal sync pulse width in pixels
      H_BP      : integer :=    63;      -- horizontal back porch width in pixels
      V_FP      : integer :=     5;      -- vertical front porch width in rows
      V_PULSE   : integer :=     5;      -- vertical sync pulse width in rows
      V_BP      : integer :=    39;      -- vertical back porch width in rows
      H_MAX     : integer :=   864;
      V_MAX     : integer :=   625;
      H_POL     : std_logic := '1';     -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL     : std_logic := '1'      -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );
   port (
      clk_main_i           : in  std_logic;
      reset_i              : in  std_logic;
      pause_i              : in  std_logic;
      keyboard_n_i         : in  std_logic_vector(2 downto 0);

      -- Video output
      vga_ce_o             : out std_logic;
      vga_red_o            : out std_logic_vector(7 downto 0);
      vga_green_o          : out std_logic_vector(7 downto 0);
      vga_blue_o           : out std_logic_vector(7 downto 0);
      vga_vs_o             : out std_logic;
      vga_hs_o             : out std_logic;
      vga_de_o             : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o         : out signed(15 downto 0);
      audio_right_o        : out signed(15 downto 0)
   );
end entity democore;

architecture synthesis of democore is

   signal video_pixel_x : integer := 0;
   signal video_pixel_y : integer := 0;

   alias video_clk_i : std_logic is clk_main_i;

   signal video_red   : std_logic_vector(7 downto 0);
   signal video_green : std_logic_vector(7 downto 0);
   signal video_blue  : std_logic_vector(7 downto 0);
   signal video_vs    : std_logic;
   signal video_hs    : std_logic;
   signal video_de    : std_logic;

begin

   i_vga_controller : entity work.vga_controller
      port map (
         h_pulse   => H_PULSE,
         h_bp      => H_BP,
         h_pixels  => H_PIXELS,
         h_fp      => H_FP,
         h_pol     => H_POL,
         v_pulse   => V_PULSE,
         v_bp      => V_BP,
         v_pixels  => V_PIXELS,
         v_fp      => V_FP,
         v_pol     => V_POL,
         pixel_clk => video_clk_i,
         reset_n   => '1',
         h_sync    => video_hs,
         v_sync    => video_vs,
         disp_ena  => video_de,
         column    => video_pixel_x,
         row       => video_pixel_y,
         n_blank   => open,
         n_sync    => open
      ); -- i_vga_controller

   audio_left_o  <= (others => '0');
   audio_right_o <= (others => '0');

   i_democore_pixel : entity work.democore_pixel
      generic  map (
         G_VGA_DX => H_PIXELS,
         G_VGA_DY => V_PIXELS
      )
      port map (
         vga_clk_i => video_clk_i,
         vga_col_i => video_pixel_x,
         vga_row_i => video_pixel_y,
         vga_core_rgb_o(23 downto 16) => video_red,
         vga_core_rgb_o(15 downto  8) => video_green,
         vga_core_rgb_o( 7 downto  0) => video_blue
      );

   p_rgb : process (video_clk_i)
   begin
      if rising_edge(video_clk_i) then
         if video_de then
            vga_red_o   <= video_red;
            vga_green_o <= video_green;
            vga_blue_o  <= video_blue;
         else
            vga_red_o   <= X"00";
            vga_green_o <= X"00";
            vga_blue_o  <= X"00";
         end if;
         vga_hs_o    <= video_hs;
         vga_vs_o    <= video_vs;
         vga_de_o    <= video_de;
      end if;
   end process p_rgb;

   vga_ce_o <= '1';

end architecture synthesis;

