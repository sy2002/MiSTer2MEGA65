library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- RTC output format:
-- Bits  7 -  0 : Seconds    (BCD format, 0x00-0x60)
-- Bits 15 -  8 : Minutes    (BCD format, 0x00-0x59)
-- Bits 23 - 16 : Hours      (BCD format, 0x00-0x23)
-- Bits 31 - 24 : DayOfMonth (BCD format, 0x01-0x31)
-- Bits 39 - 32 : Month      (BCD format, 0x01-0x12)
-- Bits 47 - 40 : Year       (BCD format, 0x00-0x99)
-- Bits 55 - 48 : DayOfWeek  (0x00-0x06)
-- Bits 63 - 56 : 0x40
-- Bit       64 : Toggle flag. Flips anytime there is a change in the other bits

entity rtc is
  port (
    clk_i         : in  std_logic;
    rst_i         : in  std_logic;

    rtc_o         : out std_logic_vector(64 downto 0);

    -- CPU slave: Connect to QNICE CPU
    cpu_wait_o    : out std_logic;
    cpu_ce_i      : in  std_logic;
    cpu_we_i      : in  std_logic;
    cpu_addr_i    : in  std_logic_vector( 7 downto 0);
    cpu_wr_data_i : in  std_logic_vector(15 downto 0);
    cpu_rd_data_o : out std_logic_vector(15 downto 0);

    -- CPU master: Connect to I2C controller
    cpu_wait_i    : in  std_logic;
    cpu_ce_o      : out std_logic;
    cpu_we_o      : out std_logic;
    cpu_addr_o    : out std_logic_vector( 7 downto 0);
    cpu_wr_data_o : out std_logic_vector(15 downto 0);
    cpu_rd_data_i : in  std_logic_vector(15 downto 0)
  );
end entity rtc;

architecture synthesis of rtc is

   signal start : std_logic;
   signal busy  : std_logic;

begin

   rtc_reader_inst : entity work.rtc_reader
     port map (
       clk_i         => clk_i,
       rst_i         => rst_i,
       start_i       => start,
       busy_o        => busy,
       rtc_o         => rtc_o,
       cpu_wait_i    => cpu_wait_i,
       cpu_ce_o      => cpu_ce_o,
       cpu_we_o      => cpu_we_o,
       cpu_addr_o    => cpu_addr_o,
       cpu_wr_data_o => cpu_wr_data_o,
       cpu_rd_data_i => cpu_rd_data_i
     ); -- rtc_reader_inst

   cpu_wait_o <= '0';

   write_proc : process (clk_i)
   begin
      if falling_edge(clk_i) then
         start <= '0';
         if cpu_ce_i = '1' and cpu_we_i = '1' then
            start <= '1';
         end if;
      end if;
   end process write_proc;

   -- Combinatorial read
   comb_proc : process (all)
   begin
      cpu_rd_data_o <= X"0000"; -- default
      case cpu_addr_i is
         when X"00" => cpu_rd_data_o <= X"00" & rtc_o( 7 downto  0);
         when X"01" => cpu_rd_data_o <= X"00" & rtc_o(15 downto  8);
         when X"02" => cpu_rd_data_o <= X"00" & rtc_o(23 downto 16);
         when X"03" => cpu_rd_data_o <= X"00" & rtc_o(31 downto 24);
         when X"04" => cpu_rd_data_o <= X"00" & rtc_o(39 downto 32);
         when X"05" => cpu_rd_data_o <= X"00" & rtc_o(47 downto 40);
         when X"06" => cpu_rd_data_o <= X"00" & rtc_o(55 downto 48);
         when X"07" => cpu_rd_data_o <= X"00" & rtc_o(63 downto 56);
         when X"08" => cpu_rd_data_o <= X"00" & "0000000" & rtc_o(64);
         when X"09" => cpu_rd_data_o <= X"00" & "0000000" & busy;
         when others => cpu_rd_data_o <= X"0000";
      end case;
   end process comb_proc;

end architecture synthesis;

