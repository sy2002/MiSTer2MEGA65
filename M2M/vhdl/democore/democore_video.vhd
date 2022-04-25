library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity democore_video is
   generic (
      G_VIDEO_MODE : video_modes_t
   );
   port (
      clk_main_i     : in  std_logic;
      reset_i        : in  std_logic;

      -- Game input
      ball_pos_x_i   : in  std_logic_vector(15 downto 0);
      ball_pos_y_i   : in  std_logic_vector(15 downto 0);
      paddle_pos_x_i : in  std_logic_vector(15 downto 0);
      paddle_pos_y_i : in  std_logic_vector(15 downto 0);

      update_o       : out std_logic;

      -- Video output
      vga_ce_o       : out std_logic;
      vga_red_o      : out std_logic_vector(7 downto 0);
      vga_green_o    : out std_logic_vector(7 downto 0);
      vga_blue_o     : out std_logic_vector(7 downto 0);
      vga_vs_o       : out std_logic;
      vga_hs_o       : out std_logic;
      vga_hblank_o   : out std_logic;
      vga_vblank_o   : out std_logic
   );
end entity democore_video;

architecture synthesis of democore_video is

   constant C_BORDER      : integer :=   4; -- Number of pixels
   constant C_SIZE_BALL   : integer :=  20; -- Number of pixels
   constant C_SIZE_PADDLE : integer := 100; -- Number of pixels

   signal video_ce      : std_logic;
   signal video_hs      : std_logic;
   signal video_vs      : std_logic;
   signal video_hblank  : std_logic;
   signal video_vblank  : std_logic;
   signal video_pixel_x : integer range 0 to G_VIDEO_MODE.H_PIXELS - 1;
   signal video_pixel_y : integer range 0 to G_VIDEO_MODE.V_PIXELS - 1;
   signal video_red     : std_logic_vector(7 downto 0);
   signal video_green   : std_logic_vector(7 downto 0);
   signal video_blue    : std_logic_vector(7 downto 0);

begin

   i_vga_controller : entity work.vga_controller
      port map (
         h_pulse   => G_VIDEO_MODE.H_PULSE,
         h_bp      => G_VIDEO_MODE.H_BP,
         h_pixels  => G_VIDEO_MODE.H_PIXELS,
         h_fp      => G_VIDEO_MODE.H_FP,
         h_pol     => '1',
         v_pulse   => G_VIDEO_MODE.V_PULSE,
         v_bp      => G_VIDEO_MODE.V_BP,
         v_pixels  => G_VIDEO_MODE.V_PIXELS,
         v_fp      => G_VIDEO_MODE.V_FP,
         v_pol     => '1',
         clk_i     => clk_main_i,
         ce_i      => video_ce,
         reset_n   => '1',
         h_sync    => video_hs,
         v_sync    => video_vs,
         h_blank   => video_hblank,
         v_blank   => video_vblank,
         column    => video_pixel_x,
         row       => video_pixel_y,
         n_blank   => open,
         n_sync    => open
      ); -- i_vga_controller

   p_rgb : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         -- Render background
         vga_red_o   <= X"88";
         vga_green_o <= X"CC";
         vga_blue_o  <= X"AA";

         -- Render white border
         if video_pixel_x < C_BORDER or video_pixel_x + C_BORDER >= G_VIDEO_MODE.H_PIXELS or
            video_pixel_y < C_BORDER or video_pixel_y + C_BORDER >= G_VIDEO_MODE.V_PIXELS then
            vga_red_o   <= X"FF";
            vga_green_o <= X"FF";
            vga_blue_o  <= X"FF";
         end if;

         -- Render red-ish square
         if video_pixel_x >= to_integer(unsigned(ball_pos_x_i)) and video_pixel_x < to_integer(unsigned(ball_pos_x_i)) + C_SIZE_BALL and
            video_pixel_y >= to_integer(unsigned(ball_pos_y_i)) and video_pixel_y < to_integer(unsigned(ball_pos_y_i)) + C_SIZE_BALL then
            vga_red_o   <= X"EE";
            vga_green_o <= X"20";
            vga_blue_o  <= X"40";
         end if;

         -- Render green-ish paddle
         if video_pixel_x >= to_integer(unsigned(paddle_pos_x_i)) and video_pixel_x < to_integer(unsigned(paddle_pos_x_i)) + C_SIZE_PADDLE and
            video_pixel_y >= to_integer(unsigned(paddle_pos_y_i)) and video_pixel_y < to_integer(unsigned(paddle_pos_y_i)) + C_SIZE_BALL then
            vga_red_o   <= X"20";
            vga_green_o <= X"EE";
            vga_blue_o  <= X"40";
         end if;

         -- Screen blanking outside visible area
         if video_hblank = '1' or video_vblank = '1' then
            vga_red_o   <= X"00";
            vga_green_o <= X"00";
            vga_blue_o  <= X"00";
         end if;

         video_ce <= not video_ce;

         vga_hs_o <= video_hs;
         vga_vs_o <= video_vs;
         vga_hblank_o <= video_hblank;
         vga_vblank_o <= video_vblank;
      end if;
   end process p_rgb;

   vga_ce_o <= video_ce;

   update_o <= '1' when video_pixel_x = 0 and video_pixel_y = 0 else '0';

end architecture synthesis;

