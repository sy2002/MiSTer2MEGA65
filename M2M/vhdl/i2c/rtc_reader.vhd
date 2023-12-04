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

entity rtc_reader is
  port (
    clk_i         : in  std_logic;
    rst_i         : in  std_logic;

    start_i       : in  std_logic;
    busy_o        : out std_logic;
    rtc_o         : out std_logic_vector(64 downto 0);

    -- CPU master
    cpu_wait_i    : in  std_logic;
    cpu_ce_o      : out std_logic;
    cpu_we_o      : out std_logic;
    cpu_addr_o    : out std_logic_vector( 7 downto 0);
    cpu_wr_data_o : out std_logic_vector(15 downto 0);
    cpu_rd_data_i : in  std_logic_vector(15 downto 0)
  );
end entity rtc_reader;

architecture synthesis of rtc_reader is

  type cmd_t is (NOP_CMD, WRITE_CMD, WAIT_CMD, SHIFT_CMD);
  type action_t is record
    cmd  : cmd_t;
    addr : std_logic_vector( 7 downto 0);
    data : std_logic_vector(15 downto 0);
  end record action_t;

  type action_list_t is array (natural range <>) of action_t;
  -- For the R5 board we are controlling several devices:
  -- DC/DC converter:
  -- I2C bus      = 2 (I2C)
  -- I2C address  = 0x61 and 0x67
  -- I2C register = 0x01
  -- RTC (RV-3032-C7):
  -- I2C bus      = 0 (FPGA)
  -- I2C address  = 0x51
  -- I2C register = 0x00
  constant C_ACTION_LIST_R5 : action_list_t := (
    -- This initializes the two DC/DC converters
    0 => (WAIT_CMD,  X"F1", X"0001"),   -- Wait until I2C is idle
    1 => (WRITE_CMD, X"00", X"01A7"),   -- Prepare to write to device
    2 => (WRITE_CMD, X"F0", X"42C2"),   -- Send two bytes to device
    3 => (WAIT_CMD,  X"F1", X"0000"),   -- Wait until I2C command is accepted
    4 => (WAIT_CMD,  X"F1", X"0001"),   -- Wait until I2C is idle
    5 => (WRITE_CMD, X"00", X"01A7"),   -- Prepare to write to device
    6 => (WRITE_CMD, X"F0", X"42CE"),   -- Send two bytes to device
    7 => (WAIT_CMD,  X"F1", X"0000"),   -- Wait until I2C command is accepted
    8 => (WAIT_CMD,  X"F1", X"0001"),   -- Wait until I2C is idle

    -- This reads from the RTC
    9 => (WAIT_CMD,  X"F1", X"0001"),   -- Wait until I2C is idle
   10 => (WRITE_CMD, X"00", X"0100"),   -- Prepare to write to RTC
   11 => (WRITE_CMD, X"F0", X"01A2"),   -- Send one byte, 0x01, to RTC
   12 => (WAIT_CMD,  X"F1", X"0000"),   -- Wait until I2C command is accepted
   13 => (WAIT_CMD,  X"F1", X"0001"),   -- Wait until I2C is idle
   14 => (WRITE_CMD, X"F0", X"07A3"),   -- Receive seven bytes from RTC
   15 => (WAIT_CMD,  X"F1", X"0000"),   -- Wait until I2C command is accepted
   16 => (WAIT_CMD,  X"F1", X"0001"),   -- Wait until I2C is idle
   17 => (SHIFT_CMD, X"00", X"0004")    -- Read seven bytes from buffer
   );
  constant C_ACTION_LIST : action_list_t := C_ACTION_LIST_R5; -- TBD
  constant C_ACTION_NUM : natural := C_ACTION_LIST'length;

  type state_t is (RESET_ST, IDLE_ST, BUSY_ST);
  signal state : state_t := IDLE_ST;

  signal action_idx  : natural range 0 to C_ACTION_NUM-1;
  signal action      : action_t;
  signal next_action : std_logic;
  signal rtc         : std_logic_vector(64 downto 0);

begin

  busy_o <= '0' when state = IDLE_ST else '1';

  --        Toggle & 0x40       Weekday             Year-Month-Date Hours-Minutes-Seconds
  rtc_o  <= rtc(64 downto 56) & rtc(31 downto 24) & rtc(55 downto 32) & rtc(23 downto 0);

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if cpu_wait_i = '0' then
        cpu_ce_o      <= '0';
      end if;

      next_action <= '0';

      case state is
        when RESET_ST =>
          if rst_i = '0' then
            action_idx  <= 0;
            action      <= C_ACTION_LIST(0);
            next_action <= '0';
            state       <= BUSY_ST;
          end if;

        when IDLE_ST =>
          if start_i = '1' then
            action_idx  <= 0;
            action      <= C_ACTION_LIST(0);
            next_action <= '0';
            state       <= BUSY_ST;
          end if;

        when BUSY_ST =>
          if next_action = '0' then
            case action.cmd is
              when NOP_CMD =>
                null;

              when WRITE_CMD =>
                cpu_ce_o      <= '1';
                cpu_we_o      <= '1';
                cpu_addr_o    <= action.addr;
                cpu_wr_data_o <= action.data;
                if cpu_wait_i = '0' then
                  next_action <= '1';
                end if;

              when WAIT_CMD =>
                cpu_ce_o      <= '1';
                cpu_we_o      <= '0';
                cpu_addr_o    <= action.addr;
                cpu_wr_data_o <= (others => '0');
                if cpu_ce_o = '1' and cpu_wait_i = '0' and cpu_rd_data_i = action.data then
                  next_action <= '1';
                end if;

              when SHIFT_CMD =>
                cpu_ce_o      <= '1';
                cpu_we_o      <= '0';
                cpu_addr_o    <= action.addr;
                cpu_wr_data_o <= (others => '0');
                if cpu_ce_o = '1' and cpu_wait_i = '0' then
                  rtc(63 downto 0) <= cpu_rd_data_i(7 downto 0) & cpu_rd_data_i(15 downto 8) & rtc(63 downto 16);
                  action.data <= action.data - 1;
                  action.addr <= action.addr + 1;
                  cpu_addr_o  <= cpu_addr_o + 1;
                  if action.data = 1 then
                    next_action <= '1';
                    cpu_ce_o    <= '0';
                  end if;
                end if;

            end case; -- action.cmd
          end if;
      end case; -- state

      if next_action = '1' then
        if action_idx + 1 < C_ACTION_NUM then
          action <= C_ACTION_LIST(action_idx + 1);
          action_idx <= action_idx + 1;
        else
          rtc(63 downto 56) <= X"40";
          rtc(64) <= not rtc(64); -- Toggle to indicate new RTC value is valid
          state   <= IDLE_ST;
        end if;
      end if;

      if rst_i = '1' then
        cpu_ce_o      <= '0';
        cpu_we_o      <= '0';
        cpu_addr_o    <= (others => '0');
        cpu_wr_data_o <= (others => '0');
        action_idx    <= 0;
        next_action   <= '0';
        rtc           <= "0" & X"4000000101000000";
        state         <= RESET_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

