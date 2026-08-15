----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Behavioral XPM CDC stub used by the vdrives regression test
--
-- This framework is based on the MiSTer project
-- Powered by MiSTer2MEGA65
-- MiSTer2MEGA65 done by sy2002 and MJoergen since 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package vcomponents is
   component xpm_cdc_array_single is
      generic (
         WIDTH : integer := 2
      );
      port (
         src_clk  : in  std_logic;
         src_in   : in  std_logic_vector(WIDTH - 1 downto 0);
         dest_clk : in  std_logic;
         dest_out : out std_logic_vector(WIDTH - 1 downto 0)
      );
   end component xpm_cdc_array_single;
end package vcomponents;

package body vcomponents is
end package body vcomponents;

library ieee;
use ieee.std_logic_1164.all;

entity xpm_cdc_array_single is
   generic (
      WIDTH : integer := 2
   );
   port (
      src_clk  : in  std_logic;
      src_in   : in  std_logic_vector(WIDTH - 1 downto 0);
      dest_clk : in  std_logic;
      dest_out : out std_logic_vector(WIDTH - 1 downto 0)
   );
end entity xpm_cdc_array_single;

architecture test of xpm_cdc_array_single is
   signal sync_ff1 : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
   signal sync_ff2 : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
begin
   cdc_proc : process(dest_clk)
   begin
      if rising_edge(dest_clk) then
         sync_ff1 <= src_in;
         sync_ff2 <= sync_ff1;
      end if;
   end process cdc_proc;

   dest_out <= sync_ff2;
end architecture test;
