----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- RTC controller. Connects to QNICE interface of the I2C master.
-- This provides the QNICE CPU with a generic RTC interface.
-- In other words, it abstracts away the specifics of the various hardware revisions.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- RTC data format:
-- Bits  7 -  0 : 1/100 Seconds (BCD format, 0x00-0x99)
-- Bits 15 -  8 : Seconds       (BCD format, 0x00-0x60)
-- Bits 23 - 16 : Minutes       (BCD format, 0x00-0x59)
-- Bits 31 - 24 : Hours         (BCD format, 0x00-0x23)
-- Bits 39 - 32 : DayOfMonth    (BCD format, 0x01-0x31)
-- Bits 47 - 40 : Month         (BCD format, 0x01-0x12)
-- Bits 55 - 48 : Year          (BCD format, 0x00-0x99)
-- Bits 63 - 56 : DayOfWeek     (0x00-0x06)

entity rtc_master is
  generic (
    G_BOARD : string  -- Which platform are we running on.
  );
  port (
    clk_i           : in  std_logic;
    rst_i           : in  std_logic;

    rtc_busy_o      : out std_logic;
    rtc_read_i      : in  std_logic; -- Pulse to initiate a read from RTC
    rtc_write_i     : in  std_logic; -- Pulse to initiate a write to RTC
    rtc_wr_data_i   : in  std_logic_vector(63 downto 0);
    rtc_rd_data_o   : out std_logic_vector(63 downto 0);

    -- CPU master. Connect to I2C controller
    cpu_m_wait_i    : in  std_logic;
    cpu_m_ce_o      : out std_logic;
    cpu_m_we_o      : out std_logic;
    cpu_m_addr_o    : out std_logic_vector( 7 downto 0);
    cpu_m_wr_data_o : out std_logic_vector(15 downto 0);
    cpu_m_rd_data_i : in  std_logic_vector(15 downto 0)
  );
end entity rtc_master;

architecture synthesis of rtc_master is

  type cmd_t is (NOP_CMD, WRITE_CMD, WAIT_CMD, SHIFT_IN_CMD, SHIFT_OUT_CMD, END_CMD);
  type action_t is record
    cmd  : cmd_t;
    addr : std_logic_vector( 7 downto 0);
    data : std_logic_vector(15 downto 0);
  end record action_t;

  type action_list_t is array (natural range <>) of action_t;

  -- For the R3 board:
  -- RTC device   : ISL12020MIRZ
  -- I2C bus      : 0 (FPGA)
  -- I2C address  : 0x6F
  -- I2C register : 0x00
  -- I2C byte_cnt : 0x07
  -- Values read back are:
  -- 0: Seconds
  -- 1: Minutes
  -- 2: Hours
  -- 3: DayOfMonth
  -- 4: Month
  -- 5: Year
  -- 6: DayOfWeek
  constant C_ACTION_LIST_READ_R3 : action_list_t := (
    -- This reads from the RTC
    0 => (WAIT_CMD,     X"F1", X"0001"),   -- Wait until I2C is idle
    1 => (WRITE_CMD,    X"00", X"0000"),   -- Prepare to write to RTC
    2 => (WRITE_CMD,    X"F0", X"01DE"),   -- Send one byte, 0x01, to RTC
    3 => (WAIT_CMD,     X"F1", X"0000"),   -- Wait until I2C command is accepted
    4 => (WAIT_CMD,     X"F1", X"0001"),   -- Wait until I2C is idle
    5 => (WRITE_CMD,    X"F0", X"07DF"),   -- Receive seven bytes from RTC
    6 => (WAIT_CMD,     X"F1", X"0000"),   -- Wait until I2C command is accepted
    7 => (WAIT_CMD,     X"F1", X"0001"),   -- Wait until I2C is idle
    8 => (SHIFT_IN_CMD, X"00", X"0004"),   -- Read seven bytes from buffer
    9 => (END_CMD,      X"00", X"0000")
   );

  constant C_ACTION_LIST_WRITE_R3 : action_list_t := (
    -- This writes to the RTC
    0 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    1 => (SHIFT_OUT_CMD, X"00", X"0005"),   -- Prepare to write to RTC
    2 => (WRITE_CMD,     X"F0", X"08DE"),   -- Send eight bytes from RTC
    3 => (WAIT_CMD,      X"F1", X"0000"),   -- Wait until I2C command is accepted
    4 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    5 => (END_CMD,       X"00", X"0000")
   );

  -- For the R5 board:
  -- RTC device   : RV-3032-C7
  -- I2C bus      : 0 (FPGA)
  -- I2C address  : 0x51
  -- I2C register : 0x00
  -- I2C byte_cnt : 0x08
  -- Values read back are:
  -- 0: Hundredths
  -- 1: Seconds
  -- 2: Minutes
  -- 3: Hours
  -- 4: DayOfWeek
  -- 5: DayOfMonth
  -- 6: Month
  -- 7: Year
  constant C_ACTION_LIST_READ_R5 : action_list_t := (
    -- This reads from the RTC
    0 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    1 => (WRITE_CMD,     X"00", X"0000"),   -- Prepare to write to RTC
    2 => (WRITE_CMD,     X"F0", X"01A2"),   -- Send one byte, 0x01, to RTC
    3 => (WAIT_CMD,      X"F1", X"0000"),   -- Wait until I2C command is accepted
    4 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    5 => (WRITE_CMD,     X"F0", X"08A3"),   -- Receive eight bytes from RTC
    6 => (WAIT_CMD,      X"F1", X"0000"),   -- Wait until I2C command is accepted
    7 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    8 => (SHIFT_IN_CMD,  X"00", X"0004"),   -- Read seven bytes from buffer
    9 => (END_CMD,       X"00", X"0000")
   );

  constant C_ACTION_LIST_WRITE_R5 : action_list_t := (
    -- This writes to the RTC
    0 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    1 => (SHIFT_OUT_CMD, X"00", X"0005"),   -- Prepare to write to RTC
    2 => (WRITE_CMD,     X"F0", X"09A2"),   -- Send nine bytes from RTC
    3 => (WAIT_CMD,      X"F1", X"0000"),   -- Wait until I2C command is accepted
    4 => (WAIT_CMD,      X"F1", X"0001"),   -- Wait until I2C is idle
    5 => (END_CMD,       X"00", X"0000")
   );

  pure function get_action_list_read(board : string) return action_list_t is
  begin
    if board = "MEGA65_R3" then
      return C_ACTION_LIST_READ_R3;
    else
      return C_ACTION_LIST_READ_R5; -- Valid for R4 and R5
    end if;
  end function get_action_list_read;

  pure function get_action_list_write(board : string) return action_list_t is
  begin
    if board = "MEGA65_R3" then
      return C_ACTION_LIST_WRITE_R3;
    else
      return C_ACTION_LIST_WRITE_R5; -- Valid for R4 and R5
    end if;
  end function get_action_list_write;

  -- Call this after reading from RTC
  pure function post_read(board : string; arg : std_logic_vector) return std_logic_vector is
  begin
    if board = "MEGA65_R3" then
      return arg(55 downto 0) & X"00";
    else
      -- Valid for R4 and R5
      return arg(39 downto 32) & arg(63 downto 40) & arg(31 downto 0);
    end if;
  end function post_read;

  -- Call this before writing to RTC
  pure function pre_write(board : string; arg : std_logic_vector) return std_logic_vector is
  begin
    if board = "MEGA65_R3" then
      return X"00" & arg(63 downto 8) & X"00";
    else
      -- Valid for R4 and R5
      return arg(55 downto 32) & arg(63 downto 56) & arg(31 downto 0) & X"00";
    end if;
  end function pre_write;


  constant C_ACTION_LIST_READ  : action_list_t := get_action_list_read(G_BOARD);
  constant C_ACTION_LIST_WRITE : action_list_t := get_action_list_write(G_BOARD);

  type state_t is (RESET_ST, IDLE_ST, BUSY_ST);
  signal state : state_t := IDLE_ST;

  signal action_idx  : natural range 0 to 15;
  signal action      : action_t;
  signal next_action : std_logic;
  signal rtc         : std_logic_vector(63 downto 0);
  signal rtc_write   : std_logic_vector(71 downto 0);
  signal write       : std_logic;

begin

  rtc_busy_o <= '0' when state = IDLE_ST else '1';

  rtc_rd_data_o <= rtc;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if cpu_m_wait_i = '0' then
        cpu_m_ce_o      <= '0';
      end if;

      next_action <= '0';

      case state is
        when RESET_ST =>
          if rst_i = '0' then
            action_idx  <= 0;
            action      <= C_ACTION_LIST_READ(0);
            next_action <= '0';
            state       <= BUSY_ST;
          end if;

        when IDLE_ST =>
          if rtc_read_i = '1' then
            action_idx  <= 0;
            action      <= C_ACTION_LIST_READ(0);
            next_action <= '0';
            state       <= BUSY_ST;
            write       <= '0';
          end if;
          if rtc_write_i = '1' then
            rtc_write   <= pre_write(G_BOARD, rtc_wr_data_i);
            action_idx  <= 0;
            action      <= C_ACTION_LIST_WRITE(0);
            next_action <= '0';
            state       <= BUSY_ST;
            write       <= '1';
          end if;

        when BUSY_ST =>
          if next_action = '0' then
            case action.cmd is
              when NOP_CMD =>
                null;

              when WRITE_CMD =>
                cpu_m_ce_o      <= '1';
                cpu_m_we_o      <= '1';
                cpu_m_addr_o    <= action.addr;
                cpu_m_wr_data_o <= action.data;
                if cpu_m_wait_i = '0' then
                  next_action <= '1';
                end if;

              when WAIT_CMD =>
                cpu_m_ce_o      <= '1';
                cpu_m_we_o      <= '0';
                cpu_m_addr_o    <= action.addr;
                cpu_m_wr_data_o <= (others => '0');
                if cpu_m_ce_o = '1' and cpu_m_wait_i = '0' and cpu_m_rd_data_i = action.data then
                  next_action <= '1';
                end if;

              when SHIFT_IN_CMD =>
                cpu_m_ce_o      <= '1';
                cpu_m_we_o      <= '0';
                cpu_m_addr_o    <= action.addr;
                cpu_m_wr_data_o <= (others => '0');
                if cpu_m_ce_o = '1' and cpu_m_wait_i = '0' then
                  rtc(63 downto 0) <= cpu_m_rd_data_i(7 downto 0) & cpu_m_rd_data_i(15 downto 8) & rtc(63 downto 16);
                  action.data <= action.data - 1;
                  action.addr <= action.addr + 1;
                  cpu_m_addr_o  <= cpu_m_addr_o + 1;
                  if action.data = 1 then
                    next_action <= '1';
                    cpu_m_ce_o    <= '0';
                  end if;
                end if;

              when SHIFT_OUT_CMD =>
                if cpu_m_ce_o = '0' then
                  cpu_m_ce_o      <= '1';
                  cpu_m_we_o      <= '1';
                  cpu_m_addr_o    <= action.addr;
                  cpu_m_wr_data_o <= rtc_write(7 downto 0) & rtc_write(15 downto 8);
                end if;
                if cpu_m_ce_o = '1' and cpu_m_wait_i = '0' then
                  rtc_write(71 downto 0) <= X"0000" & rtc_write(71 downto 16);
                  action.data <= action.data - 1;
                  action.addr <= action.addr + 1;
                  cpu_m_addr_o  <= cpu_m_addr_o + 1;
                  if action.data = 1 then
                    next_action <= '1';
                    cpu_m_ce_o  <= '0';
                    cpu_m_we_o  <= '0';
                  end if;
                end if;

              when END_CMD =>
                rtc   <= post_read(G_BOARD, rtc);
                state <= IDLE_ST;

            end case; -- action.cmd
          end if;
      end case; -- state

      if next_action = '1' then
        if write = '1' then
          action <= C_ACTION_LIST_WRITE(action_idx + 1);
        else
          action <= C_ACTION_LIST_READ(action_idx + 1);
        end if;
        action_idx <= action_idx + 1;
      end if;

      if rst_i = '1' then
        cpu_m_ce_o      <= '0';
        cpu_m_we_o      <= '0';
        cpu_m_addr_o    <= (others => '0');
        cpu_m_wr_data_o <= (others => '0');
        action_idx      <= 0;
        next_action     <= '0';
        rtc             <= X"00_00_01_01_00_00_00_00";
        state           <= RESET_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

