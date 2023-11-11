library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_to_i2c_master is
  port (
    clk_i         : in  std_logic;
    rst_i         : in  std_logic;
    -- CPU
    cpu_wait_o    : out std_logic;
    cpu_ce_i      : in  std_logic;
    cpu_we_i      : in  std_logic;
    cpu_addr_i    : in  std_logic_vector(7 downto 0);
    cpu_wr_data_i : in  std_logic_vector(15 downto 0);
    cpu_rd_data_o : out std_logic_vector(15 downto 0);
    -- I2C master signals
    enable_o      : out std_logic;
    start_o       : out std_logic;
    i2c_bus_o     : out natural range 0 to 7;
    i2c_addr_o    : out std_logic_vector(7 downto 0);
    num_bytes_o   : out unsigned(3 downto 0);
    tx_data_o     : out std_logic_vector(15 downto 0);
    tx_rdy_i      : in  std_logic;
    rx_vld_i      : in  std_logic;
    rx_data_i     : in  std_logic_vector(15 downto 0);
    response_i    : in  std_logic_vector(3 downto 0)
  );
end entity cpu_to_i2c_master;

architecture synthesis of cpu_to_i2c_master is

  constant REG_I2C_DATA   : std_logic_vector(7 downto 0) := X"00";
  constant REG_I2C_CONFIG : std_logic_vector(7 downto 0) := X"F0";
  constant REG_I2C_STATUS : std_logic_vector(7 downto 0) := X"F1";
  constant RAM_AW         : integer := 4;

  signal cpu_rd_en        : std_logic;
  signal cpu_wr_en        : std_logic;

  type i2c_ram_t is array (natural range <>) of std_logic_vector(15 downto 0);

  signal start            : std_logic_vector(3 downto 0);
  signal num_bytes        : std_logic_vector(3 downto 0);  -- Number of bytes to send
  signal i2c_ram          : i2c_ram_t(0 to 2**RAM_AW-1);
  signal ram_addr         : unsigned(RAM_AW-1 downto 0) := (others => '0'); -- LSB not use for ram address
  signal ram_wr           : std_logic;
  signal ram_rd           : std_logic_vector(1 downto 0);
  signal ram_wr_data      : std_logic_vector(15 downto 0);
  signal ram_rd_data      : std_logic_vector(15 downto 0);
  signal nack             : std_logic;

begin

  enable_o <= '1';
  start_o  <= start(3);

  cpu_rd_en <= cpu_ce_i and not cpu_we_i;
  cpu_wr_en <= cpu_ce_i and cpu_we_i;

  cpu_proc : process (clk_i)
  begin
    if falling_edge(clk_i) then
      if response_i(2) = '1' then
        nack <= '1';
      end if;
      cpu_rd_data_o <= (others => '0');
      ram_wr        <= '0';
      ram_rd        <= ram_rd(0) & '0';
      ram_rd_data   <= i2c_ram(to_integer(ram_addr));
      if ram_wr = '1' then
        i2c_ram(to_integer(ram_addr)) <= ram_wr_data;
      end if;
      start          <= start(2 downto 0) & start(0);

      if cpu_wr_en = '1' and cpu_addr_i = REG_I2C_CONFIG then
        i2c_addr_o <= cpu_wr_data_i( 7 downto  0);
        num_bytes  <= cpu_wr_data_i(11 downto  8);
        i2c_bus_o  <= to_integer(unsigned(cpu_wr_data_i(15 downto 13)));
        start(0)   <= '1';
      end if;
      if cpu_rd_en = '1' then
        if cpu_addr_i = REG_I2C_CONFIG then
          cpu_rd_data_o( 7 downto  0) <= i2c_addr_o;
          cpu_rd_data_o(11 downto  8) <= num_bytes;
          cpu_rd_data_o(15 downto 13) <= std_logic_vector(to_unsigned(i2c_bus_o, 3));
        elsif cpu_addr_i = REG_I2C_STATUS then
          cpu_rd_data_o(3 downto 0) <= response_i(3) & nack & response_i(1 downto 0);
          nack <= '0';
        end if;
      end if;

      if cpu_wr_en = '1' and cpu_addr_i(7 downto RAM_AW) = REG_I2C_DATA(7 downto RAM_AW) then
        ram_addr    <= unsigned(cpu_addr_i(RAM_AW-1 downto 0));
        ram_wr_data <= cpu_wr_data_i;
        ram_wr      <= '1';
      end if;

      if cpu_rd_en = '1' and cpu_addr_i(7 downto RAM_AW) = REG_I2C_DATA(7 downto RAM_AW) then
        ram_addr   <= unsigned(cpu_addr_i(RAM_AW-1 downto 0));
        ram_rd(0)  <= '1';
        cpu_wait_o <= '1';
      end if;
      if ram_rd(1) = '1' then
        cpu_wait_o <= '0';
        cpu_rd_data_o <= ram_rd_data;
        ram_rd <= "00";
      end if;


      if response_i(1) = '1' then               -- command accepted
        start(0)      <= '0';
        num_bytes_o <= (others => '0');
      end if;

      if start(1 downto 0) = "01" then
        ram_addr <= (others => '0');          -- Clear address
        num_bytes_o <= unsigned(num_bytes);
      end if;
      if i2c_addr_o(0) = '0' then               -- I2C write
        if start(3 downto 2) = "01" then
          tx_data_o  <= ram_rd_data;            -- Load first data
          ram_addr <= ram_addr + 1;
        elsif tx_rdy_i = '1' then
          tx_data_o  <= ram_rd_data;
          ram_addr <= ram_addr + 1;
        end if;
      else
        if rx_vld_i = '1' then
          ram_wr_data <= rx_data_i;
          ram_wr <= '1';
        end if;
        if ram_wr = '1' then
          ram_addr <= ram_addr + 1;
        end if;
      end if;

      if rst_i = '1' then
        cpu_wait_o <= '0';
        start <= (others => '0');
        nack  <= '0';
      end if;
    end if;
  end process cpu_proc;

end architecture synthesis;

