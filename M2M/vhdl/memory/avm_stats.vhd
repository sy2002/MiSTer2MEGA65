library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity avm_stats is
   port (
      clk_i               : in  std_logic; -- Main clock
      pps_i               : in  std_logic; -- One pulse per second
      rst_i               : in  std_logic; -- Synchronous reset

      -- Avalon Memory Map
      avm_write_i         : in  std_logic;
      avm_read_i          : in  std_logic;
      avm_burstcount_i    : in  std_logic_vector(7 downto 0);
      avm_readdatavalid_i : in  std_logic;
      avm_waitrequest_i   : in  std_logic;

      -- Statistics outputs
      stats_idle_o        : out std_logic_vector(27 downto 0);
      stats_wait_o        : out std_logic_vector(27 downto 0);
      stats_write_o       : out std_logic_vector(27 downto 0);
      stats_read_o        : out std_logic_vector(27 downto 0)
   );
end entity avm_stats;

architecture synthesis of avm_stats is

   signal wr_burstcount : std_logic_vector(7 downto 0);
   signal rd_burstcount : std_logic_vector(7 downto 0);
   signal stats_idle    : std_logic_vector(27 downto 0);
   signal stats_wait    : std_logic_vector(27 downto 0);
   signal stats_write   : std_logic_vector(27 downto 0);
   signal stats_read    : std_logic_vector(27 downto 0);

   type t_state is (IDLE_ST, WRITING_ST, READING_ST, READING_AND_WRITING_ST);
   signal state : t_state := IDLE_ST;

begin

   p_stats : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               if avm_write_i = '1' and avm_waitrequest_i = '0' then
                  stats_write <= stats_write + 1;
                  if avm_burstcount_i > 1 then
                     wr_burstcount <= avm_burstcount_i - 1;
                     state <= WRITING_ST;
                  end if;
               elsif avm_read_i = '1' and avm_waitrequest_i = '0' then
                  rd_burstcount  <= avm_burstcount_i;
                  stats_read <= stats_read + 1;
                  state <= READING_ST;
               elsif (avm_write_i = '1' or avm_read_i = '1') and avm_waitrequest_i = '1' then
                  stats_wait <= stats_wait + 1;
               else
                  stats_idle <= stats_idle + 1;
               end if;

            when WRITING_ST =>
               stats_write <= stats_write + 1;
               if avm_write_i = '1' and avm_waitrequest_i = '0' then
                  wr_burstcount <= wr_burstcount - 1;
                  if wr_burstcount = 1 then
                     state <= IDLE_ST;
                  end if;
               end if;

            when READING_ST =>
               stats_read <= stats_read + 1;
               if avm_readdatavalid_i = '1' then
                  rd_burstcount <= rd_burstcount - 1;
                  if rd_burstcount = 1 then
                     state <= IDLE_ST;
                  end if;
               end if;
               if avm_write_i = '1' and avm_waitrequest_i = '0' then
                  stats_write <= stats_write + 1;
                  if avm_burstcount_i > 1 then
                     wr_burstcount <= avm_burstcount_i - 1;
                     state <= READING_AND_WRITING_ST;
                     if avm_readdatavalid_i = '1' and rd_burstcount = 1 then
                        state <= WRITING_ST;
                     end if;
                  end if;
               end if;

            when READING_AND_WRITING_ST =>
               stats_read <= stats_read + 1;
               if avm_readdatavalid_i = '1' then
                  rd_burstcount <= rd_burstcount - 1;
                  if rd_burstcount = 1 then
                     state <= WRITING_ST;
                  end if;
               end if;
               if avm_write_i = '1' and avm_waitrequest_i = '0' then
                  stats_write <= stats_write + 1;
                  wr_burstcount <= wr_burstcount - 1;
                  if wr_burstcount = 1 then
                     state <= READING_ST;
                  end if;
               end if;

            when others =>
               null;
         end case;

         if pps_i = '1' then
            stats_idle_o  <= stats_idle;
            stats_wait_o  <= stats_wait;
            stats_write_o <= stats_write;
            stats_read_o  <= stats_read;
         end if;

         if pps_i = '1' or rst_i = '1' then
            stats_idle    <= (others => '0');
            stats_wait    <= (others => '0');
            stats_write   <= (others => '0');
            stats_read    <= (others => '0');
         end if;

         if rst_i = '1' then
            state <= IDLE_ST;
            wr_burstcount <= X"00";
            rd_burstcount <= X"00";
         end if;
      end if;
   end process p_stats;

end architecture synthesis;

