------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Demo core that produces a test image including test sound, so that MiSTer2MEGA65
-- can be synthesized and tested stand alone even before the MiSTer core is being
-- applied. The MEGA65 "Help" menu can be used to change the behavior of the core.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity democore is
   generic (
      G_CORE_CLK_SPEED     : natural;
      G_OUTPUT_DX          : natural;
      G_OUTPUT_DY          : natural    
   );
   port (
      clk_main_i           : in  std_logic;
      reset_i              : in  std_logic;
      keyboard_n_i         : in  std_logic_vector(2 downto 0)
   );
end democore;

architecture beh of democore is

begin


end beh;
