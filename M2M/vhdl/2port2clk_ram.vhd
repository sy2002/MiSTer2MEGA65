----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Dual Port Dual Clock RAM: Drop-in replacement for "dpram.vhd"
--
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity dualport_2clk_ram is
	generic (
		 ADDR_WIDTH     : integer := 8;            -- The size of the RAM will be 2**ADDR_WIDTH
		 DATA_WIDTH     : integer := 8;
		 MAXIMUM_SIZE   : integer := integer'high; -- Maximum size of RAM, independent from ADDR_WIDTH 
		 ROM_PRELOAD    : boolean := false;        -- Preload a ROM
		 ROM_FILE       : string  := "";
		 ROM_FILE_HEX   : boolean := false;        -- hexadecimal format (using hread) instead of binary format (using read)        
		 LATCH_ADDR_A   : boolean := false;        -- latch address a when "do_latch_addr_a" = '1'
		 LATCH_ADDR_B   : boolean := false;        -- ditto address b
		 FALLING_A      : boolean := false;        -- read/write on falling edge for clock a
		 FALLING_B      : boolean := false         -- ditto clock b		 		 
	); 
	port
	(
		clock_a         : IN STD_LOGIC := '0';
		address_a       : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (others => '0');
		do_latch_addr_a : IN STD_LOGIC := '0';
		data_a          : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0) := (others => '0');
		wren_a          : IN STD_LOGIC := '0';
		q_a             : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);

		clock_b         : IN STD_LOGIC := '0';
		address_b       : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (others => '0');
		do_latch_addr_b : IN STD_LOGIC := '0';
		data_b          : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0) := (others => '0');
		wren_b          : IN STD_LOGIC := '0';
		q_b             : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0)
	);
end dualport_2clk_ram;

architecture beh of dualport_2clk_ram is

constant    MEMORY_SIZE : integer := MINIMUM(2**ADDR_WIDTH, MAXIMUM_SIZE);
type        memory_t is array(0 to MEMORY_SIZE - 1) of std_logic_vector((DATA_WIDTH - 1) downto 0);

impure function InitRAMFromFile(ramfilename: string) return memory_t is
   file     ramfile	   : text is in ramfilename;
   variable ramfileline : line;
   variable ram_data	   : memory_t;
   variable bitvec      : bit_vector(DATA_WIDTH - 1 downto 0);
   variable i           : natural := 0;
begin
   while not endfile(ramfile) loop
      readline(ramfile, ramfileline);
      if ROM_FILE_HEX then
         hread(ramfileline, bitvec);
      else
         read(ramfileline, bitvec);
      end if;
      ram_data(i) := to_stdlogicvector(bitvec);
      i := i + 1;
   end loop;
   return ram_data;
end function;

-- Vivado 2019.2 crashes, if we are not using this indirection
impure function InitRAM(ramfile: string) return memory_t is
begin
   if ROM_PRELOAD then
      return InitRamFromFile(ramfile);
   else
      return (others => (others => '0'));
   end if;
end;

signal      ram               : memory_t := InitRAM(ROM_FILE);
attribute   ram_style         : string;
attribute   ram_style of ram  : signal is "block";

signal      address_a_int     : integer;
signal      address_b_int     : integer;

begin
   -- Optional latch management for A and B 
   latch_address_a : process(clock_a, address_a)
   begin
      if LATCH_ADDR_A then
         if not FALLING_A then
            if rising_edge(clock_a) then
               if do_latch_addr_a = '1' then
                  address_a_int <= to_integer(unsigned(address_a));
               end if;               
            end if;
         else
            if falling_edge(clock_a) then
               if do_latch_addr_a = '1' then
                  address_a_int <= to_integer(unsigned(address_a));
               end if;               
            end if;         
         end if;
      else
         address_a_int <= to_integer(unsigned(address_a));      
      end if;
   end process;   
   
   latch_address_b : process(clock_b, address_b)
   begin
      if LATCH_ADDR_B then
         if not FALLING_B then
            if rising_edge(clock_b) then
               if do_latch_addr_b = '1' then
                  address_b_int <= to_integer(unsigned(address_b));
               end if;               
            end if;
         else
            if falling_edge(clock_b) then
               if do_latch_addr_b = '1' then
                  address_b_int <= to_integer(unsigned(address_b));
               end if;               
            end if;         
         end if;
      else
         address_b_int <= to_integer(unsigned(address_b));      
      end if;
   end process;   
   
   -- Port A
   write_a : process(clock_a)
   begin
      if not FALLING_A then
         if rising_edge(clock_a) then
            if wren_a = '1' then
               ram(address_a_int) <= data_a;
            end if;
            q_a <= ram(address_a_int);         
         end if;
      else
         if falling_edge(clock_a) then
            if wren_a = '1' then
               ram(address_a_int) <= data_a;
            end if;
            q_a <= ram(address_a_int);         
         end if;      
      end if;
   end process;

   -- Port B
   write_b : process(clock_b)
   begin
      if not FALLING_B then
         if rising_edge(clock_b) then
            if wren_b = '1' then
               ram(address_b_int) <= data_b;
            end if;
            q_b <= ram(address_b_int);         
         end if;
      else
         if falling_edge(clock_b) then
            if wren_b = '1' then
               ram(address_b_int) <= data_b;
            end if;
            q_b <= ram(address_b_int);         
         end if;      
      end if;
   end process;
end beh;
