----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- QNICE interface to date/time. Includes both internal timer and external RTC.
-- Copied from https://github.com/MJoergen/i2c
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This entity contains a free-running internal timer, running independently of the
-- external RTC. The internal timer can be stopped and started, and can be set (when
-- stopped). Furthermore, when internal timer is stopped, the date/time can be copied
-- between the internal timer and the external RTC.
--
-- Address | Data
-- 0x00    | Hundredths of a second (BCD format, 0x00-0x99)
-- 0x01    | Seconds                (BCD format, 0x00-0x60)
-- 0x02    | Minutes                (BCD format, 0x00-0x59)
-- 0x03    | Hours                  (BCD format, 0x00-0x23)
-- 0x04    | DayOfMonth             (BCD format, 0x01-0x31)
-- 0x05    | Month                  (BCD format, 0x01-0x12)
-- 0x06    | Year since 2000        (BCD format, 0x00-0x99)
-- 0x07    | DayOfWeek              (0x00 = Monday)
-- 0x08    | Command                (bit 0 : RO : I2C Busy)
--                                  (bit 1 : RW : Copy from RTC to internal)
--                                  (bit 2 : RW : Copy from internal to RTC)
--                                  (bit 3 : RW : Internal Timer Running)
--
-- Addresses 0x00 to 0x07 provide R/W access to the internal timer.
--
-- The Command byte (address 0x08) is used to start or stop the internal timer, and to
-- synchronize with the external RTC.  Any changes to the internal timer are only allowed
-- when the internal timer is stopped. So addresses 0x00 to 0x07 are read-only, when the
-- internal timer is running.
-- The protocol for synchronizing with the RTC is as follows:
-- 1. Stop the internal timer by writing 0x00 to Command.
-- 2. Read from Command and make sure value read is zero (otherwise wait).
-- 3. Write either 0x02 or 0x04 to the command byte.
-- 4. Read from Command and wait until value read is zero. (Note: The I2C transaction
--    takes approximately 1 millisecond to complete).
-- 5. Start the internal timer by writing 0x08 to Command.
-- Optionally, you may use auto-start in step 3 above by writing 0x0A or 0x0C. This
-- will automatically re-start the internal timer right after the I2C transaction is
-- complete, so that step 5 can be skipped.
-- Note: The Command byte automatically clears, when the command is completed. Reading
-- from the Command byte gives the status of the current command.
--
--
-- RTC output format to CORE:
-- Bits  7 -  0 : Seconds    (BCD format, 0x00-0x60)
-- Bits 15 -  8 : Minutes    (BCD format, 0x00-0x59)
-- Bits 23 - 16 : Hours      (BCD format, 0x00-0x23)
-- Bits 31 - 24 : DayOfMonth (BCD format, 0x01-0x31)
-- Bits 39 - 32 : Month      (BCD format, 0x01-0x12)
-- Bits 47 - 40 : Year       (BCD format, 0x00-0x99)
-- Bits 55 - 48 : DayOfWeek  (0x00-0x06)
-- Bits 63 - 56 : 0x40
-- Bit       64 : Toggle flag. Flips anytime there is a change in the other bits

entity rtc_controller is
  generic (
    G_CLK_SPEED_HZ : natural := 50_000_000;
    G_BOARD        : string                     -- Which platform are we running on.
  );
  port (
    clk_i           : in  std_logic;
    rst_i           : in  std_logic;

    -- Passed on directly to the CORE
    rtc_o           : out std_logic_vector(64 downto 0);

    -- CPU slave: Connect to QNICE CPU
    cpu_s_wait_o    : out std_logic;
    cpu_s_ce_i      : in  std_logic;
    cpu_s_we_i      : in  std_logic;
    cpu_s_addr_i    : in  std_logic_vector( 7 downto 0);
    cpu_s_wr_data_i : in  std_logic_vector(15 downto 0);
    cpu_s_rd_data_o : out std_logic_vector(15 downto 0);

    -- CPU master: Connect to I2C controller
    cpu_m_wait_i    : in  std_logic;
    cpu_m_ce_o      : out std_logic;
    cpu_m_we_o      : out std_logic;
    cpu_m_addr_o    : out std_logic_vector( 7 downto 0);
    cpu_m_wr_data_o : out std_logic_vector(15 downto 0);
    cpu_m_rd_data_i : in  std_logic_vector(15 downto 0)
  );
end entity rtc_controller;

architecture synthesis of rtc_controller is

   signal rtc_read     : std_logic;
   signal rtc_write    : std_logic;
   signal rtc_busy     : std_logic;
   signal rtc_internal : std_logic_vector(64 downto 0);
   signal rtc_external : std_logic_vector(63 downto 0);
   signal rtc_busy_d   : std_logic;
   signal rtc_reading  : std_logic;

   signal running      : std_logic;

   signal tick         : std_logic;
   signal tick_counter : natural range 0 to G_CLK_SPEED_HZ/100-1;
   constant C_MAX      : std_logic_vector(55 downto 0) := X"99_12_31_23_59_59_99";

begin

   cpu_s_wait_o <= '0';

   rtc_o <= rtc_internal(64) & X"40" & rtc_internal(63 downto 8);

   -- Instantiate the RTC master
   rtc_master_inst : entity work.rtc_master
      generic map (
         G_BOARD => G_BOARD
      )
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         rtc_busy_o      => rtc_busy,     -- Command bit 0
         rtc_read_i      => rtc_read,     -- Command bit 1
         rtc_write_i     => rtc_write,    -- Command bit 2
         rtc_wr_data_i   => rtc_internal(63 downto 0), -- Copy to external RTC
         rtc_rd_data_o   => rtc_external,              -- Read from external RTC
         cpu_m_wait_i    => cpu_m_wait_i,
         cpu_m_ce_o      => cpu_m_ce_o,
         cpu_m_we_o      => cpu_m_we_o,
         cpu_m_addr_o    => cpu_m_addr_o,
         cpu_m_wr_data_o => cpu_m_wr_data_o,
         cpu_m_rd_data_i => cpu_m_rd_data_i
      ); -- rtc_master_inst

   tick_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if tick_counter = G_CLK_SPEED_HZ/100 - 1 then
            tick <= '1';
            tick_counter <= 0;
         else
            tick <= '0';
            tick_counter <= tick_counter + 1;
         end if;
      end if;
   end process tick_proc;

   -- Update local time
   rtc_proc : process (clk_i)

      pure function increment_bcd(arg : std_logic_vector) return std_logic_vector is
         variable res : std_logic_vector(arg'length-1 downto 0);
      begin
         res := arg;
         for i in 0 to arg'length/4-1 loop
            if res(4*i+3 downto 4*i) < X"9" then
               res(4*i+3 downto 4*i) := res(4*i+3 downto 4*i) + 1;
               exit;
            end if;
            res(4*i+3 downto 4*i) := X"0";
         end loop;
         return res;
      end function increment_bcd;

      variable idx : natural range 0 to 7;

   begin
      if rising_edge(clk_i) then
         rtc_write <= '0';
         rtc_read  <= '0';
         if tick = '1' and running = '1' then
            for i in 0 to C_MAX'length/8-1 loop
               -- If incrementing DayOfMonth, then increment DayOfWeek
               if i = 4 then
                  rtc_internal(63 downto 56) <= (rtc_internal(63 downto 56) + 1) mod 7;
               end if;

               if rtc_internal(8*i+7 downto 8*i) < C_MAX(8*i+7 downto 8*i) then
                  rtc_internal(8*i+7 downto 8*i) <= increment_bcd(rtc_internal(8*i+7 downto 8*i));
                  exit;
               end if;
               rtc_internal(8*i+7 downto 8*i) <= X"00";
            end loop;
         end if;

         if cpu_s_ce_i = '1' and cpu_s_we_i = '1' then
            -- Local timer only writeable when timer is stopped
            if cpu_s_addr_i < X"08" and running = '0' then
               idx := to_integer(cpu_s_addr_i(2 downto 0));
               rtc_internal(8*idx+7 downto 8*idx) <= cpu_s_wr_data_i(7 downto 0);
            end if;

            -- Command byte only writeable when I2C is idle
            if cpu_s_addr_i = X"08" and rtc_busy = '0' then
               -- When timer is running, no RTC commands are allowed
               if running = '1' and cpu_s_wr_data_i(2 downto 1) = "00" then
                  running <= cpu_s_wr_data_i(3);
               end if;

               -- When timer is stopped bits 1-3 are writeable
               if running = '0' then
                  running     <= cpu_s_wr_data_i(3);
                  rtc_reading <= cpu_s_wr_data_i(1);
                  rtc_read    <= cpu_s_wr_data_i(1);
                  rtc_write   <= cpu_s_wr_data_i(2);
               end if;
            end if;
         end if;

         -- Copy external to internal
         rtc_busy_d <= rtc_busy;
         if rtc_busy_d = '1' and rtc_busy = '0' then
            if rtc_reading = '1' then
               rtc_reading  <= '0';
               rtc_internal(63 downto 0) <= rtc_external;
               rtc_internal(64) <= not rtc_internal(64);
            end if;
         end if;

         if rst_i = '1' then
            rtc_reading  <= '1';
            rtc_read     <= '0';
            rtc_write    <= '0';
            running      <= '1';
            rtc_internal <= "0" & X"00_00_01_01_00_00_00_00";
         end if;
      end if;
   end process rtc_proc;

   -- Combinatorial read
   comb_proc : process (all)
   begin
      cpu_s_rd_data_o <= X"0000"; -- default
      case cpu_s_addr_i is
         when X"00" => cpu_s_rd_data_o <= X"00" & rtc_internal( 7 downto  0);
         when X"01" => cpu_s_rd_data_o <= X"00" & rtc_internal(15 downto  8);
         when X"02" => cpu_s_rd_data_o <= X"00" & rtc_internal(23 downto 16);
         when X"03" => cpu_s_rd_data_o <= X"00" & rtc_internal(31 downto 24);
         when X"04" => cpu_s_rd_data_o <= X"00" & rtc_internal(39 downto 32);
         when X"05" => cpu_s_rd_data_o <= X"00" & rtc_internal(47 downto 40);
         when X"06" => cpu_s_rd_data_o <= X"00" & rtc_internal(55 downto 48);
         when X"07" => cpu_s_rd_data_o <= X"00" & rtc_internal(63 downto 56);
         when X"08" => cpu_s_rd_data_o <= X"00" & "0000" & running & rtc_write & rtc_read & rtc_busy;
         when others => cpu_s_rd_data_o <= X"0000";
      end case;
   end process comb_proc;

end architecture synthesis;

