library  ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

library std;
   use std.textio.all;

entity ram_init is
   generic (
      G_ADDR_WIDTH   : positive;
      G_DATA_WIDTH   : positive;
      G_ROM_PRELOAD  : boolean := false;
      G_ROM_FILE     : string  := "";
      G_ROM_FILE_HEX : boolean := false
   );
   port (
      clock_i   : in  std_logic;
      clen_i    : in  std_logic;
      address_i : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
      data_i    : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
      wren_i    : in  std_logic;
      q_o       : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
   );
end entity ram_init;

architecture synthesis of ram_init is

   subtype t_word is std_logic_vector(G_DATA_WIDTH - 1 downto 0);
   type    t_ram  is array(0 to 2**G_ADDR_WIDTH - 1) of t_word;

   impure function InitRAMFromFile(ramfilename: string) return t_ram is
      file     ramfile     : text;
      variable ramfileline : line;
      variable ram_data    : t_ram := (others => (others => '0'));
      variable bitvec      : bit_vector(G_DATA_WIDTH - 1 downto 0);
      variable i           : natural := 0;
   begin
      if G_ROM_PRELOAD then
         file_open(ramfile, ramfilename);
         while not endfile(ramfile) loop
            readline(ramfile, ramfileline);
            if G_ROM_FILE_HEX then
               hread(ramfileline, bitvec);
            else
               read(ramfileline, bitvec);
            end if;
            ram_data(i) := to_stdlogicvector(bitvec);
            i := i + 1;
         end loop;
         file_close(ramfile);
      end if;
      return ram_data;
   end function;

   signal ram : t_ram := InitRAMFromFile(G_ROM_FILE);

begin

   ram_proc : process (clock_i)
   begin
      if rising_edge(clock_i) then
         if clen_i = '1' then
            if wren_i = '1' then
               ram(to_integer(unsigned(address_i))) <= data_i;
            end if;

            q_o <= ram(to_integer(unsigned(address_i)));
         end if;
      end if;
   end process ram_proc;

end architecture synthesis;

