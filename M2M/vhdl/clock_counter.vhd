----------------------------------------------------------------------------------
-- CLOCK COUNTER
-- It monitors an unknown clock and returns its frequency in Hz
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

library xpm;
use xpm.vcomponents.all;

entity clock_counter is
port (
   clk_i     : in    std_logic; -- Main clock
   pps_i     : in    std_logic; -- One pulse per second
   cnt_o     : out   std_logic_vector(27 downto 0); -- Frequency of mon_clk_i
   mon_clk_i : in    std_logic  -- Clock to monitor
);
end entity clock_counter;

architecture synthesis of clock_counter is

signal mon_pps               : std_logic;
signal mon_clk_cnt           : std_logic_vector(27 downto 0);
signal mon_clk_cnt_latch     : std_logic_vector(27 downto 0);

begin

   i_clk2mon : entity work.cdc_pulse
     port map (
       src_clk_i   => clk_i,
       src_pulse_i => pps_i,
       dst_clk_i   => mon_clk_i,
       dst_pulse_o => mon_pps
     );

   p_mon_clk_cnt : process (mon_clk_i)
   begin
      if rising_edge(mon_clk_i) then
         -- Count number of mon clock cycles
         mon_clk_cnt <= std_logic_vector(unsigned(mon_clk_cnt) + 1);

         -- Reset counter once every second
         if mon_pps = '1' then
            mon_clk_cnt_latch <= mon_clk_cnt;
            mon_clk_cnt <= (others => '0');
         end if;

      end if;
   end process p_mon_clk_cnt;

   i_mon2clk : entity work.cdc_stable
   generic map (
      G_DATA_SIZE    => 28
   )
   port map (
      src_data_i => mon_clk_cnt_latch,
      dst_clk_i  => clk_i,
      dst_data_o => cnt_o
   );

end architecture synthesis;

