----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Block ROM (synchronous)
--
-- done by sy2002 in August 2015, refactored by MJoergen and sy2002 in 2020/21
-- taken from the QNICE-FPGA project and licensed according to the license
-- of QNICE-FPGA: https://github.com/sy2002/QNICE-FPGA/blob/master/LICENSE.md
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;

entity BROM is
generic (
   FILE_NAME    : string;
   ADDR_WIDTH   : integer := 16;
   DATA_WIDTH   : integer := 16;
   LATCH_ACTIVE : boolean := true
);
port (
   clk          : in std_logic;                        -- read and write on rising clock edge
   ce           : in std_logic;                        -- chip enable, when low then zero on output
   latch_addr   : in std_logic := '1';                 -- latch address (game rom logic needs that)

   address      : in std_logic_vector(ADDR_WIDTH - 1 downto 0);   -- address
   data         : out std_logic_vector(DATA_WIDTH - 1 downto 0)   -- read data
);
end BROM;

architecture beh of BROM is

signal addr_i : std_logic_vector(ADDR_WIDTH - 1 downto 0);
signal output : std_logic_vector(DATA_WIDTH - 1 downto 0);

impure function get_lines_in_romfile(rom_file_name : in string) return natural is
   file     rom_file  : text is in rom_file_name;
   variable line_v    : line;
   variable lines_v   : natural := 0;
begin
   while not endfile(rom_file) loop
      readline(rom_file, line_v);   -- Just ignore the line read from the file.
      lines_v := lines_v + 1;
   end loop;
   return lines_v;
end function;

constant C_LINES : natural := get_lines_in_romfile(FILE_NAME);

type brom_t is array (0 to C_LINES - 1) of bit_vector(DATA_WIDTH - 1 downto 0);

impure function read_romfile(rom_file_name : in string) return brom_t is
   file     rom_file  : text is in rom_file_name;
   variable line_v    : line;
   variable rom_v     : brom_t;
begin
   for i in brom_t'range loop
      if not endfile(rom_file) then
         readline(rom_file, line_v);
         read(line_v, rom_v(i));
      end if;
   end loop;
   return rom_v;
end function;

signal brom : brom_t := read_romfile(FILE_NAME);

begin

   latch_address : process(clk, address)
   begin
      if LATCH_ACTIVE then
         if rising_edge(clk) then
            if latch_addr = '1' then
               addr_i <= address;
            end if;
         end if;
      else
         addr_i <= address;
      end if;
   end process;
   
   rom_read : process (clk)
   begin
      if falling_edge(clk) then
         if ce = '1' then
            output <= to_stdlogicvector(brom(conv_integer(addr_i)));
         else
            output <= (others => 'U');
         end if;
      end if;
   end process;

   -- Doing it like this (i.e. one combinatorial process and the clocked process) is faster
   -- than moving "data" to the clocked process and then getting rid of "output" and the
   -- "manage_output" process.
   --
   -- Here are measurements taken with Vivado v2019.2
   --
   --    This version here (commit #f11f6bd):         Slack 0.168 / Delay 9.514
   --    The "optimized" version (commit #d409772):   Slack 0.055 / Delay 9.668
   
   -- zero while not ce
   manage_output : process (ce, output)
   begin
      if (ce = '0') then
         data <= (others => '0');
      else
         data <= output;
      end if;
   end process;
   
end beh;
