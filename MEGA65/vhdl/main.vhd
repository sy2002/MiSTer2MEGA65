----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
   generic (
      G_CORE_CLK_SPEED        : natural;
      
      -- @TODO adjust this to your needs
      G_OUTPUT_DX             : natural;
      G_OUTPUT_DY             : natural;     
      G_YOUR_GENERIC1         : boolean;
      G_ANOTHER_THING         : natural
   );
   port (
      main_clk               : in  std_logic;
      reset_n                : in  std_logic;

      -- MEGA65 smart keyboard controller
      kb_io0                 : out std_logic;
      kb_io1                 : out std_logic;
      kb_io2                 : in  std_logic

      -- MEGA65 audio
--      pwm_l                  : out std_logic;
--      pwm_r                  : out std_logic;

      -- MEGA65 joysticks
--      joy_1_up_n             : in std_logic;
--      joy_1_down_n           : in std_logic;
--      joy_1_left_n           : in std_logic;
--      joy_1_right_n          : in std_logic;
--      joy_1_fire_n           : in std_logic;

--      joy_2_up_n             : in std_logic;
--      joy_2_down_n           : in std_logic;
--      joy_2_left_n           : in std_logic;
--      joy_2_right_n          : in std_logic;
--      joy_2_fire_n           : in std_logic
   );
end main;

architecture synthesis of main is

begin

   -- @TODO: Add the actual MiSTer core here
   -- The demo core's purpose is to show a test image and to make sure, that the MiSTer2MEGA65 framework
   -- can be synthesized and run stand-alone without an actual MiSTer core being there, yet
   i_democore : entity work.democore   
      generic map
      (
         G_CORE_CLK_SPEED  => G_CORE_CLK_SPEED,
         G_OUTPUT_DX       => G_OUTPUT_DX,
         G_OUTPUT_DY       => G_OUTPUT_DY
      )
      port map
      (
         main_clk          => main_clk,
         reset_n           => reset_n
      );

--   -- MEGA65 keyboard and joystick controller
--   kbd : entity work.keyboard
--      generic map
--      (
--         CLOCK_SPEED             => G_CORE_CLK_SPEED
--      )
--      port map
--      (
--         clk                     => main_clk,
--         kio8                    => kb_io0,
--         kio9                    => kb_io1,
--         kio10                   => kb_io2,
--         joystick                => main_m65_joystick,
--         joy_map                 => main_qngbc_joy_map,

--         p54                     => main_joypad_p54,
--         joypad                  => main_joypad_data_i,
--         full_matrix             => main_qngbc_keyb_matrix
--      ); -- kbd : entity work.keyboard


--   -- debouncer for the RESET button as well as for the joysticks:
--   -- 40ms for the RESET button
--   -- 5ms for any joystick direction
--   -- 1ms for the fire button
--   do_dbnce_reset_n : entity work.debounce
--      generic map(clk_freq => G_CORE_CLK_SPEED, stable_time => 40)
--      port map (clk => main_clk, reset_n => '1', button => RESET_N, result => main_dbnce_reset_n);
--   do_dbnce_joysticks : entity work.debouncer
--      generic map
--      (
--         CLK_FREQ                => G_CORE_CLK_SPEED
--      )
--      port map
--      (
--         clk                     => main_clk,
--         reset_n                 => RESET_N,

--         joy_1_up_n              => joy_1_up_n,
--         joy_1_down_n            => joy_1_down_n,
--         joy_1_left_n            => joy_1_left_n,
--         joy_1_right_n           => joy_1_right_n,
--         joy_1_fire_n            => joy_1_fire_n,

--         dbnce_joy1_up_n         => main_dbnce_joy1_up_n,
--         dbnce_joy1_down_n       => main_dbnce_joy1_down_n,
--         dbnce_joy1_left_n       => main_dbnce_joy1_left_n,
--         dbnce_joy1_right_n      => main_dbnce_joy1_right_n,
--         dbnce_joy1_fire_n       => main_dbnce_joy1_fire_n,

--         joy_2_up_n              => joy_2_up_n,
--         joy_2_down_n            => joy_2_down_n,
--         joy_2_left_n            => joy_2_left_n,
--         joy_2_right_n           => joy_2_right_n,
--         joy_2_fire_n            => joy_2_fire_n,

--         dbnce_joy2_up_n         => main_dbnce_joy2_up_n,
--         dbnce_joy2_down_n       => main_dbnce_joy2_down_n,
--         dbnce_joy2_left_n       => main_dbnce_joy2_left_n,
--         dbnce_joy2_right_n      => main_dbnce_joy2_right_n,
--         dbnce_joy2_fire_n       => main_dbnce_joy2_fire_n
--      ); -- do_dbnce_joysticks : entity work.debouncer


end synthesis;

