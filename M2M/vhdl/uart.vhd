library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity uart is
   generic (
      G_BAUD_RATE : natural := 115_200
   );
   port (
      clk_speed_i : in    natural;    -- Clock speed in Hz
      clk_i       : in    std_logic;
      rst_i       : in    std_logic;
      tx_valid_i  : in    std_logic;
      tx_ready_o  : out   std_logic;
      tx_data_i   : in    std_logic_vector(7 downto 0);
      rx_valid_o  : out   std_logic;
      rx_ready_i  : in    std_logic;
      rx_data_o   : out   std_logic_vector(7 downto 0);
      uart_tx_o   : out   std_logic;
      uart_rx_i   : in    std_logic
   );
end entity uart;

architecture synthesis of uart is

   constant C_MAX_CLOCK_RATE : natural := 100_000_000;

   type     state_type is (
      IDLE_ST,
      CHECK_START_ST,
      BUSY_ST
   );

   signal   tx_data    : std_logic_vector(9 downto 0);
   signal   tx_state   : state_type := IDLE_ST;
   signal   tx_counter : natural range 0 to C_MAX_CLOCK_RATE;

   signal   rx_data    : std_logic_vector(9 downto 0);
   signal   rx_state   : state_type := IDLE_ST;
   signal   rx_counter : natural range 0 to C_MAX_CLOCK_RATE;

   signal   uart_rx_d : std_logic;
   signal   uart_tx   : std_logic;

begin

   tx_ready_o <= '1' when tx_state = IDLE_ST else
                 '0';

   uart_tx    <= tx_data(0);

   tx_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         uart_tx_o <= uart_tx;

         case tx_state is

            when IDLE_ST =>
               if tx_valid_i = '1' then
                  tx_data    <= "1" & tx_data_i & "0";
                  tx_counter <= 0;
                  tx_state   <= BUSY_ST;
               end if;

            when BUSY_ST =>
               if tx_counter < clk_speed_i then
                  tx_counter <= tx_counter + G_BAUD_RATE;
               else
                  if or (tx_data(9 downto 1)) = '1' then
                     tx_counter <= 0;
                     tx_data    <= "0" & tx_data(9 downto 1);
                  else
                     tx_data  <= (others => '1');
                     tx_state <= IDLE_ST;
                  end if;
               end if;

            when others =>
               null;

         end case;

         if rst_i = '1' then
            tx_data    <= (others => '1');
            tx_state   <= IDLE_ST;
            tx_counter <= 0;
            uart_tx_o  <= '1';
         end if;
      end if;
   end process tx_proc;

   rx_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Synchronize to clock
         uart_rx_d <= uart_rx_i;

         if rx_ready_i = '1' then
            rx_valid_o <= '0';
         end if;

         case rx_state is

            when IDLE_ST =>
               -- Start bit detected
               if uart_rx_d = '0' then
                  -- Make sure we sample in the "middle" of each bit
                  rx_counter <= clk_speed_i / 2 + G_BAUD_RATE;
                  rx_state   <= CHECK_START_ST;
               end if;

            when CHECK_START_ST =>
               if rx_counter < clk_speed_i then
                  rx_counter <= rx_counter + G_BAUD_RATE;
               else
                  rx_counter <= (rx_counter - clk_speed_i) + G_BAUD_RATE;
                  rx_data    <= uart_rx_d & rx_data(9 downto 1);
                  rx_state   <= BUSY_ST;
               end if;
               -- Verify start bit valid
               if uart_rx_d = '1' then
                  rx_state   <= IDLE_ST;
               end if;

            when BUSY_ST =>
               if rx_counter < clk_speed_i then
                  rx_counter <= rx_counter + G_BAUD_RATE;
               else
                  rx_counter <= (rx_counter - clk_speed_i) + G_BAUD_RATE;
                  rx_data    <= uart_rx_d & rx_data(9 downto 1);
               end if;

         end case;

         -- Ten bits received in total.
         if rx_data(0) = '0' then
            -- Final stop bit must be '1'.
            -- Discard if consumer is busy.
            if rx_data(9) = '1' and (rx_ready_i = '1' or rx_valid_o = '0') then
               rx_data_o  <= rx_data(8 downto 1);
               rx_valid_o <= '1';
            end if;
            rx_data    <= (others => '1');
            rx_state   <= IDLE_ST;
         end if;

         if rst_i = '1' then
            rx_valid_o <= '0';
            rx_data    <= (others => '1');
            rx_state   <= IDLE_ST;
         end if;
      end if;
   end process rx_proc;

end architecture synthesis;

