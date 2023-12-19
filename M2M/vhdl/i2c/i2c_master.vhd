----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- I2C master for controlling I2C devices.
-- Copied from https://github.com/MJoergen/i2c
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  generic (
    G_I2C_CLK_DIV     : integer
  );
  port (
    clk_i             : in  std_logic;
    rst_i             : in  std_logic;

    -- Interface to client
    enable_i          : in  std_logic;
    start_i           : in  std_logic;
    i2c_addr_i        : in  std_logic_vector(7 downto 0);         -- Slave address, R/nWR
    num_bytes_i       : in  unsigned(3 downto 0);                 -- Number of bytes to send
    tx_data_i         : in  std_logic_vector(15 downto 0);
    tx_rdy_o          : out std_logic;
    rx_vld_o          : out std_logic;
    rx_data_o         : out std_logic_vector(15 downto 0);
    response_o        : out std_logic_vector(3 downto 0);         -- d3: Slave hold, d2: NACK,  d1: busy, d0: idle

    -- Interface to device
    scl_in_i          : in  std_logic;
    sda_in_i          : in  std_logic;
    scl_out_o         : out std_logic;
    sda_out_o         : out std_logic
  );
end entity i2c_master;

architecture synthesis of i2c_master is

  type state_t is (I2C_IDLE, I2C_REP_START, I2C_START, I2C_WR_NEG_EDGE, I2C_WR_POS_EDGE,
                   I2C_RD_NEG_EDGE, I2C_RD_POS_EDGE, I2C_STOP_1, I2C_STOP_2);
  signal sda_out      : std_logic;
  signal scl_out      : std_logic;
  signal sda_tri      : std_logic;
  signal scl_tri      : std_logic;

  signal sda_in_s     : std_logic;
  signal scl_in_s     : std_logic;

  signal prescale_cnt : unsigned(8 downto 0);
  signal clk_en       : std_logic;

  signal state        : state_t;
  signal rd_cmd       : std_logic;
  signal sda_out_s    : std_logic;
  signal tx_reg       : std_logic_vector(7 downto 0);
  signal rx_reg       : std_logic_vector(7 downto 0);
  signal byte_cnt     : unsigned(3 downto 0);
  signal bit_cnt      : unsigned(3 downto 0);
  signal nack         : std_logic;
  signal odd_byte     : std_logic;
  signal clr_tri      : std_logic;

begin

  sda_out_o <= sda_out or sda_tri;
  scl_out_o <= scl_out or scl_tri;

  scl_tri <= response_o(0) or not enable_i;

  input_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if sda_in_i = '0' then
        sda_in_s <= '0';
      else
        sda_in_s <= '1';
      end if;

      if scl_in_i = '0' then
        scl_in_s <= '0';
      else
        scl_in_s <= '1';
      end if;
    end if;
  end process input_proc;


  clk_en_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if enable_i = '0' then
        prescale_cnt <= (others => '0');
        clk_en       <= '0';
      elsif prescale_cnt < G_I2C_CLK_DIV-1 then
        prescale_cnt <= prescale_cnt + 1;
        clk_en  <= '0';
      else
        prescale_cnt <= (others => '0');
        clk_en  <= '1';
      end if;
    end if;
  end process clk_en_proc;


  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if enable_i = '0' then
        sda_out_s  <= '1';
        scl_out    <= '1';
        sda_tri    <= '1';
        response_o <= "0001";
        state      <= I2C_IDLE;
      end if;

      if clr_tri = '1' then
        sda_tri <= '0';
      end if;
      clr_tri <= '0';
      sda_out <= sda_out_s;   -- Increase SDA hold time by 10 ns

      tx_rdy_o      <= '0';
      rx_vld_o      <= '0';
      response_o(2) <= '0';     -- Clear NACK;

      if clk_en = '1' then
        if scl_out = '1' and scl_in_s = '0' then   -- Slave wait
          response_o(3) <= '1';
        else
          response_o(3) <= '0';
          response_o(0) <= '0';                -- clear idle flag
          case state is
            when I2C_IDLE =>
              sda_tri   <= '1';
              scl_out   <= '1';
              sda_out_s <= '1';
              if start_i = '1' then
                state   <= I2C_START;
              end if;
              response_o(1) <= '0';            -- Clear busy flag set
              response_o(0) <= '1';            -- set idle flag

            when I2C_REP_START =>
              scl_out <= '1';
              state     <= I2C_START;

            when I2C_START =>
              clr_tri   <= '1';
              scl_out   <= '1';
              sda_out_s <= '0';                    -- Start condition
              response_o(1) <= '1';                -- Set busy flag set
              nack      <= '0';
              bit_cnt   <= to_unsigned(9, bit_cnt'length);
              state     <= I2C_WR_NEG_EDGE;
              tx_reg    <= i2c_addr_i;
              rd_cmd    <= i2c_addr_i(0);
              byte_cnt  <= num_bytes_i;
              odd_byte  <= '0';
              rx_data_o <= (others => '0');

            when I2C_WR_NEG_EDGE =>                  -- Send Byte
              scl_out   <= '0';
              sda_out_s <= tx_reg(7);
              tx_reg    <= tx_reg(6 downto 0) & '1';
              state     <= I2C_WR_POS_EDGE;
              if (bit_cnt = 1) then
                sda_tri <= '1';                    -- ACK bit
              else
                clr_tri <= '1';
              end if;
              if (bit_cnt > 0) then
                bit_cnt <= bit_cnt - 1;
              else
                if nack = '1' then                   -- NACK from device
                  sda_out_s <= '0';
                  state     <= I2C_STOP_1;
                elsif byte_cnt > 0 then
                  if rd_cmd = '1' then               -- Goto Read section
                    odd_byte  <= '0';
                    sda_out_s <= '1';
                    sda_tri   <= '1';
                    clr_tri   <= '0';
                    state     <= I2C_RD_POS_EDGE;
                  else
                    if byte_cnt = 1 then
                      response_o(1) <= '0';         -- ready for next command
                    end if;
                    byte_cnt <= byte_cnt - 1;
                  end if;
                else                                 -- Nothing more to send
                  clr_tri <= '1';
                  if num_bytes_i > 0 then            -- New command ready
                    sda_out_s <= '1';
                    state     <= I2C_REP_START;
                  else                               --  Nothing more to do
                    sda_out_s <= '0';
                    state     <= I2C_STOP_1;
                  end if;
                end if;
                bit_cnt <= to_unsigned(8, bit_cnt'length);
              end if;

            when I2C_WR_POS_EDGE =>
              scl_out <= '1';
              state   <= I2C_WR_NEG_EDGE;
              if bit_cnt = 0 then                    -- Prepare next byte
                nack   <= sda_in_s;                  -- ACK/NACK
                if odd_byte = '1' then
                  tx_reg   <= tx_data_i(7 downto 0);
                  tx_rdy_o <= '1';
                else
                  tx_reg <= tx_data_i(15 downto 8);
                end if;
                odd_byte <= not odd_byte;
                if byte_cnt = 0 and start_i = '0' then
                  response_o(1) <= '0';              -- ready for next command
                end if;
              end if;

            when I2C_RD_NEG_EDGE =>
              scl_out   <= '0';
              sda_out_s <= '1';
              sda_tri   <= '1';
              state     <= I2C_RD_POS_EDGE;          -- Default state
              if bit_cnt = 1 then                    -- ACK/NACK
                clr_tri <= '1';
                if odd_byte = '0' then
                  rx_data_o(15 downto 8) <= rx_reg;
                else
                  rx_data_o(7 downto 0) <= rx_reg;
                  rx_vld_o <= '1';
                end if;
                if byte_cnt > 1 then
                  sda_out_s <= '0';                  -- ACK read byte
                else
                  rx_vld_o      <= '1';              -- NACK last byte
                  response_o(1) <= '0';              -- ready for next command
                end if;
                odd_byte  <= not odd_byte;
              end if;
              if bit_cnt > 0 then
                bit_cnt <= bit_cnt - 1;
              else
                if sda_out_s = '1' then              -- Last byte NACK'ed
                  if num_bytes_i > 0 then
                    sda_out_s <= '1';
                    state     <= I2C_REP_START;
                  else
                    sda_out_s <= '0';
                    state     <= I2C_STOP_1;
                  end if;
                end if;
                bit_cnt  <= to_unsigned(8, bit_cnt'length);
                byte_cnt <= byte_cnt - 1;
              end if;

            when I2C_RD_POS_EDGE =>                  -- Read
              rx_reg  <= rx_reg(6 downto 0) & sda_in_s;
              scl_out <= '1';
              state   <= I2C_RD_NEG_EDGE;

            when I2C_STOP_1 =>                       -- Stop
              scl_out <= '1';
              state   <= I2C_STOP_2;

            when I2C_STOP_2 =>
              sda_out_s  <= '1';
              response_o <= '0' & nack & '0' & '0';
              nack       <= '0';
              state      <= I2C_IDLE;

            when others =>
              state      <= I2C_IDLE;

          end case;
        end if;
      end if;

      if rst_i = '1' then
        sda_out_s  <= '1';
        scl_out    <= '1';
        state      <= I2C_IDLE;
        nack       <= '0';
        response_o <= (others => '0');
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

