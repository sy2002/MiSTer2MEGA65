----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Demo core that produces a test image so that MiSTer2MEGA65 can ebe synthesized
-- and run run stand alone even before the MiSTer core is being applied
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity democore is
   generic (
      G_CORE_CLK_SPEED     : natural;
      G_OUTPUT_DX          : natural;
      G_OUTPUT_DY          : natural    
   );
   port (
      main_clk             : in  std_logic;
      reset_n              : in  std_logic
   );
end democore;

architecture beh of democore is

begin


end beh;
