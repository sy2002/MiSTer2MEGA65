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

entity democore is
   generic (
      G_CORE_CLK_SPEED     : natural;
      G_OUTPUT_DX          : natural;
      G_OUTPUT_DY          : natural
   );
   port (
      clk_main_i           : in  std_logic;
      reset_i              : in  std_logic;
      keyboard_n_i         : in  std_logic_vector(2 downto 0);

      -- Audio output (Signed PCM)
      audio_left_o         : out signed(15 downto 0);
      audio_right_o        : out signed(15 downto 0)

   );
end entity democore;

architecture synthesis of democore is

begin

   audio_left_o  <= (others => '0');
   audio_right_o <= (others => '0');

end architecture synthesis;

