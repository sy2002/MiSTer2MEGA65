library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity democore_game is
   generic  (
      G_VGA_DX       : natural;
      G_VGA_DY       : natural
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      update_i       : in  std_logic;
      keyboard_n_i   : in  std_logic_vector(79 downto 0);
      ball_pos_x_o   : out std_logic_vector(15 downto 0);
      ball_pos_y_o   : out std_logic_vector(15 downto 0);
      paddle_pos_x_o : out std_logic_vector(15 downto 0);
      paddle_pos_y_o : out std_logic_vector(15 downto 0)
   );
end entity democore_game;

architecture synthesis of democore_game is

   constant C_BORDER      : integer :=   4;  -- Number of pixels
   constant C_SIZE_BALL   : integer :=  20; -- Number of pixels
   constant C_SIZE_PADDLE : integer := 100; -- Number of pixels

   constant m65_horz_crsr : integer := 2;   -- means cursor right in C64 terminology
   constant m65_left_crsr : integer := 74;  -- cursor left

   signal ball_pos_x   : integer range 0 to G_VGA_DX-1;
   signal ball_pos_y   : integer range 0 to G_VGA_DY-1;
   signal ball_vel_x   : integer range -7 to 7;
   signal ball_vel_y   : integer range -7 to 7;
   signal paddle_pos_x : integer range 0 to G_VGA_DX-1;
   signal paddle_pos_y : integer range 0 to G_VGA_DY-1;

begin

   -- Move the ball
   p_move_ball : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if update_i = '1' then
            ball_pos_x <= ball_pos_x + ball_vel_x;
            ball_pos_y <= ball_pos_y + ball_vel_y;

            if ball_pos_x + ball_vel_x >= G_VGA_DX - C_SIZE_BALL - C_BORDER and ball_vel_x > 0 then
               ball_vel_x <= -ball_vel_x;
            end if;

            if ball_pos_x + ball_vel_x < C_BORDER and ball_vel_x < 0 then
               ball_vel_x <= -ball_vel_x;
            end if;

            if ball_pos_y + ball_vel_y >= G_VGA_DY - C_SIZE_BALL - C_BORDER and ball_vel_y > 0 then
               ball_vel_y <= -ball_vel_y;
            end if;

            if ball_pos_y + ball_vel_y < C_BORDER and ball_vel_y < 0 then
               ball_vel_y <= -ball_vel_y;
            end if;
         end if;

         if rst_i = '1' then
            ball_pos_x <= G_VGA_DX/2;
            ball_pos_y <= G_VGA_DY/2;
            ball_vel_x <= 1;
            ball_vel_y <= 1;
         end if;
      end if;
   end process p_move_ball;


   -- Move the paddle
   p_move_paddle : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if update_i = '1' then

            if paddle_pos_x + 1 < G_VGA_DX - C_SIZE_PADDLE - C_BORDER and keyboard_n_i(m65_horz_crsr) = '0' then
               paddle_pos_x <= paddle_pos_x + 1;
            end if;

            if paddle_pos_x - 1 >= C_BORDER and keyboard_n_i(m65_left_crsr) = '0' then
               paddle_pos_x <= paddle_pos_x - 1;
            end if;
         end if;

         if rst_i = '1' then
            paddle_pos_x <= G_VGA_DX/2;
            paddle_pos_y <= G_VGA_DY-C_SIZE_BALL-C_BORDER;
         end if;
      end if;
   end process p_move_paddle;


   paddle_pos_x_o <= std_logic_vector(to_unsigned(paddle_pos_x, 16));
   paddle_pos_y_o <= std_logic_vector(to_unsigned(paddle_pos_y, 16));

   ball_pos_x_o <= std_logic_vector(to_unsigned(ball_pos_x, 16));
   ball_pos_y_o <= std_logic_vector(to_unsigned(ball_pos_y, 16));

end architecture synthesis;

