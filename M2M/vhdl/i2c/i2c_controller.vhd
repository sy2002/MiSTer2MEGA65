----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- QNICE interface to I2C devices
-- Copied from https://github.com/MJoergen/i2c
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This is an I2C master controller with a convenient CPU interface.
-- Address 0x00 - 0x7F : Data buffer (bits 15-8 are transmitted first)
-- Address 0xF0        : Config
-- Address 0xF1        : Status
-- Config.0            : 0 = write, 1 = read
-- Config.7-1          : Slave address
-- Config.11-8         : Number of bytes to transfer
-- Config.12           : Unused
-- Config.15-13        : I2C bus
-- Status.0            : Idle
-- Status.1            : Busy
-- Status.2            : Nack (clear on read)
-- Status.3            : Bus Hold
--
-- Example for reading from RTC device ISL12020MIRZ
-- Write 0x0000 to 0x0000 : Prepare to send 0x00 to I2C device
-- Write 0x01DE to 0x00F0 : write 1 byte (0x00) to slave address 0x6F
-- Read from 0x00F1 : Repeat until value returned 0x0001
-- Write 0x07DF to 0x00F0 : read 7 bytes from slave address 0x6F
-- Read from 0x00F1 : Repeat until value returned 0x0001
-- Read 7 bytes from 0x0000 to 0x0003.

entity i2c_controller is
  generic (
    G_I2C_CLK_DIV : integer := 500  -- SCL=100kHz @100MHz
  );
  port (
    clk_i         : in  std_logic;
    rst_i         : in  std_logic;
    -- CPU
    cpu_wait_o    : out std_logic;
    cpu_ce_i      : in  std_logic;
    cpu_we_i      : in  std_logic;
    cpu_addr_i    : in  std_logic_vector(27 downto 0);
    cpu_wr_data_i : in  std_logic_vector(15 downto 0);
    cpu_rd_data_o : out std_logic_vector(15 downto 0);
    -- I2C signals
    scl_in_i      : in  std_logic_vector(7 downto 0);
    sda_in_i      : in  std_logic_vector(7 downto 0);
    scl_out_o     : out std_logic_vector(7 downto 0);
    sda_out_o     : out std_logic_vector(7 downto 0)
  );
end entity i2c_controller;

architecture synthesis of i2c_controller is

  signal enable    : std_logic;
  signal start     : std_logic;
  signal i2c_bus   : natural range 0 to 7;
  signal i2c_addr  : std_logic_vector( 7 downto 0);    -- Slave address, R/nWR
  signal num_bytes : unsigned( 3 downto 0);            -- Number of bytes to send
  signal tx_data   : std_logic_vector(15 downto 0);
  signal tx_rdy    : std_logic;
  signal rx_vld    : std_logic;
  signal rx_data   : std_logic_vector(15 downto 0);
  signal response  : std_logic_vector( 3 downto 0);    -- d3: Slave hold, d2: NACK,  d1: busy, d0: idle

  signal scl_in    : std_logic;
  signal sda_in    : std_logic;
  signal scl_out   : std_logic;
  signal sda_out   : std_logic;

begin

  cpu_to_i2c_master_inst : entity work.cpu_to_i2c_master
    port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      cpu_wait_o     => cpu_wait_o,
      cpu_ce_i       => cpu_ce_i,
      cpu_we_i       => cpu_we_i,
      cpu_addr_i     => cpu_addr_i,
      cpu_wr_data_i  => cpu_wr_data_i,
      cpu_rd_data_o  => cpu_rd_data_o,
      enable_o       => enable,
      start_o        => start,
      i2c_bus_o      => i2c_bus,
      i2c_addr_o     => i2c_addr,
      num_bytes_o    => num_bytes,
      tx_data_o      => tx_data,
      tx_rdy_i       => tx_rdy,
      rx_vld_i       => rx_vld,
      rx_data_i      => rx_data,
      response_i     => response
    ); -- cpu_to_i2c_master_inst

  i2c_master_inst: entity work.i2c_master
    generic map (
      G_I2C_CLK_DIV  => G_I2C_CLK_DIV
    )
    port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      enable_i       => enable,
      start_i        => start,
      i2c_addr_i     => i2c_addr,
      num_bytes_i    => num_bytes,
      tx_data_i      => tx_data,
      tx_rdy_o       => tx_rdy,
      rx_vld_o       => rx_vld,
      rx_data_o      => rx_data,
      response_o     => response,
      scl_in_i       => scl_in,
      sda_in_i       => sda_in,
      scl_out_o      => scl_out,
      sda_out_o      => sda_out
    ); -- i2c_master_inst

  i2c_proc : process (all)
  begin
    scl_in <= scl_in_i(i2c_bus);
    sda_in <= sda_in_i(i2c_bus);
    scl_out_o <= (others => 'H');
    scl_out_o(i2c_bus) <= scl_out;
    sda_out_o <= (others => 'H');
    sda_out_o(i2c_bus) <= sda_out;
  end process i2c_proc;

end architecture synthesis;

