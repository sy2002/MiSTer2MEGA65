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
      G_CORE_CLK_SPEED     : natural;
      G_VIDEO_MODE         : video_modes_t;
      G_OUTPUT_DX          : natural;
      G_OUTPUT_DY          : natural
   );
   port (
      clk_main_i           : in  std_logic;
      reset_i              : in  std_logic;
      pause_i              : in  std_logic;
      keyboard_n_i         : in  std_logic_vector(2 downto 0);

      -- VGA output
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

   signal vga_pixel_x : integer := 0;
   signal vga_pixel_y : integer := 0;

   alias vga_clk_i : std_logic is clk_main_i;

   signal vga_red   : std_logic_vector(7 downto 0);
   signal vga_green : std_logic_vector(7 downto 0);
   signal vga_blue  : std_logic_vector(7 downto 0);
   signal vga_vs    : std_logic;
   signal vga_hs    : std_logic;
   signal vga_de    : std_logic;

begin

   i_vga_controller : entity work.vga_controller
      port map (
         h_pulse   => G_VIDEO_MODE.H_PULSE,
         h_bp      => G_VIDEO_MODE.H_BP,
         h_pixels  => G_VIDEO_MODE.H_PIXELS,
         h_fp      => G_VIDEO_MODE.H_FP,
         h_pol     => G_VIDEO_MODE.H_POL,
         v_pulse   => G_VIDEO_MODE.V_PULSE,
         v_bp      => G_VIDEO_MODE.V_BP,
         v_pixels  => G_VIDEO_MODE.V_PIXELS,
         v_fp      => G_VIDEO_MODE.V_FP,
         v_pol     => G_VIDEO_MODE.V_POL,
         pixel_clk => vga_clk_i,
         reset_n   => '1',
         h_sync    => vga_hs,
         v_sync    => vga_vs,
         disp_ena  => vga_de,
         column    => vga_pixel_x,
         row       => vga_pixel_y,
         n_blank   => open,
         n_sync    => open
      ); -- i_vga_controller

   audio_left_o  <= (others => '0');
   audio_right_o <= (others => '0');

   i_democore_pixel : entity work.democore_pixel
      generic  map (
         G_VGA_DX => G_VIDEO_MODE.H_PIXELS,
         G_VGA_DY => G_VIDEO_MODE.V_PIXELS
      )
      port map (
         vga_clk_i => vga_clk_i,
         vga_col_i => vga_pixel_x,
         vga_row_i => vga_pixel_y,
         vga_core_rgb_o(23 downto 16) => vga_red,
         vga_core_rgb_o(15 downto  8) => vga_green,
         vga_core_rgb_o( 7 downto  0) => vga_blue
      );

   p_rgb : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if vga_de then
            vga_red_o   <= vga_red;
            vga_green_o <= vga_green;
            vga_blue_o  <= vga_blue;
         else
            vga_red_o   <= X"00";
            vga_green_o <= X"00";
            vga_blue_o  <= X"00";
         end if;
         vga_hs_o    <= vga_hs;
         vga_vs_o    <= vga_vs;
         vga_de_o    <= vga_de;
      end if;
   end process p_rgb;

   vga_ce_o <= '1';

end architecture synthesis;

