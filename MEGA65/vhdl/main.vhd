----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
   generic (
      G_CORE_CLK_SPEED       : natural;

      -- @TODO adjust this to your needs
      G_OUTPUT_DX            : natural;
      G_OUTPUT_DY            : natural;
      G_YOUR_GENERIC1        : boolean;
      G_ANOTHER_THING        : natural
   );
   port (
      clk_main_i             : in  std_logic;
      reset_i                : in  std_logic;
      pause_i                : in  std_logic;

      -- M2M Keyboard interface
      kb_key_num_i           : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i     : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- Audio output (Signed PCM)
      audio_left_o           : out signed(15 downto 0);
      audio_right_o          : out signed(15 downto 0);

      -- MEGA65 joysticks
      joy_1_up_n_i           : in  std_logic;
      joy_1_down_n_i         : in  std_logic;
      joy_1_left_n_i         : in  std_logic;
      joy_1_right_n_i        : in  std_logic;
      joy_1_fire_n_i         : in  std_logic;

      joy_2_up_n_i           : in  std_logic;
      joy_2_down_n_i         : in  std_logic;
      joy_2_left_n_i         : in  std_logic;
      joy_2_right_n_i        : in  std_logic;
      joy_2_fire_n_i         : in  std_logic
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
signal keyboard_n          : std_logic_vector(2 downto 0);

begin

   -- @TODO: Add the actual MiSTer core here
   -- The demo core's purpose is to show a test image and to make sure, that the MiSTer2MEGA65 framework
   -- can be synthesized and run stand-alone without an actual MiSTer core being there, yet
   i_democore : entity work.democore
      generic map (
         G_CORE_CLK_SPEED     => G_CORE_CLK_SPEED,
         G_OUTPUT_DX          => G_OUTPUT_DX,
         G_OUTPUT_DY          => G_OUTPUT_DY
      )
      port map (
         clk_main_i           => clk_main_i,
         reset_i              => reset_i,

         keyboard_n_i         => keyboard_n,

         audio_left_o         => audio_left_o,
         audio_right_o        => audio_right_o
      ); -- i_democore

   -- @TODO: Keyboard mapping and keyboard behavior
   -- Each core is treating the keyboard in a different way: Some need low-active "matrices", some
   -- might need small high-active keyboard memories, etc. This is why the MiSTer2MEGA65 framework
   -- lets you define literally everything and only provides a minimal abstraction layer to the keyboard.
   -- You need to adjust keyboard.vhd to your needs
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      ); -- i_keyboard

end architecture synthesis;

