----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Configuration data for the Shell
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity config is
port (
   -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
   -- bits 11 downto 0: address the up to 4k the configuration data
   address_i   : in std_logic_vector(27 downto 0);
   
   -- config data
   data_o      : out std_logic_vector(15 downto 0)
);
end config;

architecture beh of config is

constant CHR_NUL : character := character'val(0);

--------------------------------------------------------------------------------------------------------------------
-- Welcome Screen (Selector 0) 
--------------------------------------------------------------------------------------------------------------------

constant SEL_WELCOME : std_logic_vector(27 downto 12) := x"0000";
constant SCR_WELCOME : string :=

   "Demo Core and Demo Welcome Screen. Edit config.vhd to modify it. Version 1.0\n" &
   "MiSTer port done by Demo Author and Another One in 2021\n" &
   
   -- We are not insisting. But it would be nice if you gave us credit for MiSTer2MEGA65 by leaving this line in
   "Powered by MiSTer2MEGA65 Version 0.1 [WIP], done by sy2002 and MJoergen in 2021" & CHR_NUL;

--------------------------------------------------------------------------------------------------------------------
-- Address Decoding 
--------------------------------------------------------------------------------------------------------------------

begin

addr_decode : process(all)
   
   -- return ASCII value of given string at the position defined by address_i(11 downto 0)
   function str2data(str : string) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := to_integer(unsigned(address_i(11 downto 0))) + 1;
      return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
   end;
   
begin
   data_o <= x"EEEE";
   
   case address_i(27 downto 12) is   
      when SEL_WELCOME  => data_o <= str2data(SCR_WELCOME);
   
      when others => null;
   end case;
end process;

end beh;
