----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- MEGA65 keyboard controller
--
-- Runs in the clock domain of the core.
--
-- There are three purposes of this controller:
--
-- 1) Serve key_num and key_status to the core's keyboard.vhd, so that there the
--    core specific keyboard mapping can take place.
--
-- 2) Serve qnice_keys to QNICE and the firmware, so that the Shell can rely
--    on certain mappings (and behaviors) to be always available, independent
--    of the core specific way to handle the keyboard.
--
-- 3) Control the drive led
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity m2m_keyb is
   generic (
      G_USE_UART       : boolean := false;
      G_SCAN_FREQUENCY : integer := 1000 -- keyboard scan frequency in Hz, default: 1 kHz
   );
   port (
      clk_main_i       : in    std_logic;                     -- core clock
      rst_main_i       : in    std_logic;
      clk_main_speed_i : in    natural;                       -- speed of core clock in Hz

      -- interface to the MEGA65 keyboard controller
      kio8_o           : out   std_logic;                     -- clock to keyboard
      kio9_o           : out   std_logic;                     -- data output to keyboard
      kio10_i          : in    std_logic;                     -- data input from keyboard

      -- interface to serial debug port (via JTAG)
      uart_rx_i        : in    std_logic;

      -- interface to the core
      enable_core_i    : in    std_logic;                     -- 0 = core is decoupled from the keyboard, 1 = standard operation
      key_num_o        : out   integer range 0 to 79;         -- cycles through all keys with G_SCAN_FREQUENCY
      key_pressed_n_o  : out   std_logic;                     -- low active: debounced feedback: is kb_key_num_o pressed right now?

      -- control the drive led on the MEGA65 keyboard
      power_led_i      : in    std_logic;
      power_led_col_i  : in    std_logic_vector(23 downto 0); -- RGB color of power led
      drive_led_i      : in    std_logic;
      drive_led_col_i  : in    std_logic_vector(23 downto 0); -- RGB color of drive led

      -- interface to QNICE: used by the firmware and the Shell (see sysdef.asm for details)
      qnice_keys_n_o   : out   std_logic_vector(15 downto 0);
      keys_read_i      : in    std_logic
   );
end entity m2m_keyb;

architecture synthesis of m2m_keyb is

   signal matrix_col     : std_logic_vector(7 downto 0);
   signal matrix_col_idx : integer range 0 to 9          := 0;
   signal key_num        : integer range 0 to 79;
   signal key_status_n   : std_logic;
   signal keys_n         : std_logic_vector(15 downto 0) := x"FFFF"; -- low active, "no key pressed"

   signal uart_rx_ready : std_logic;
   signal uart_rx_valid : std_logic;
   signal uart_rx_data  : std_logic_vector(7 downto 0);

   signal fifo_ready : std_logic;
   signal fifo_valid : std_logic;
   signal fifo_data  : std_logic_vector(7 downto 0);

   signal key_ready     : std_logic;
   signal key_valid     : std_logic;
   signal key_data      : natural range 0 to 79;
   signal key_data_r    : natural range 0 to 79;
   signal key_timer     : natural range 0 to 100_000_000; -- Counts clock cycles
   signal key_pressed_n : std_logic;

   type key_state_type is (IDLE_ST, KEY_PRESS_ST, KEY_RELEASE_ST);
   signal key_state : key_state_type := IDLE_ST;

begin

   use_uart_gen : if G_USE_UART generate

      -- Read characters from UART (ASCII format)
      uart_inst : entity work.uart
         port map (
            clk_speed_i => clk_main_speed_i,
            clk_i       => clk_main_i,
            rst_i       => rst_main_i,
            tx_valid_i  => '0',
            tx_ready_o  => open,
            tx_data_i   => X"00",
            rx_valid_o  => uart_rx_valid,
            rx_ready_i  => uart_rx_ready,
            rx_data_o   => uart_rx_data,
            uart_tx_o   => open,
            uart_rx_i   => uart_rx_i
         ); -- uart_inst

      axi_fifo_small_inst : entity work.axi_fifo_small
         generic map (
            G_RAM_WIDTH => 8,
            G_RAM_DEPTH => 256
         )
         port map (
            clk_i     => clk_main_i,
            rst_i     => rst_main_i,
            s_ready_o => uart_rx_ready,
            s_valid_i => uart_rx_valid,
            s_data_i  => uart_rx_data,
            m_ready_i => fifo_ready,
            m_valid_o => fifo_valid,
            m_data_o  => fifo_data
         ); -- axi_fifo_small_inst

      -- Convert ASCII codes to MEGA65 keyboard codes
      ascii_to_mega65_inst : entity work.ascii_to_mega65
         port map (
            clk_i           => clk_main_i,
            rst_i           => rst_main_i,
            uart_rx_valid_i => fifo_valid,
            uart_rx_ready_o => fifo_ready,
            uart_rx_data_i  => fifo_data,
            key_valid_o     => key_valid,
            key_ready_i     => key_ready,
            key_data_o      => key_data
         ); -- ascii_to_mega65_inst

   end generate use_uart_gen;

   key_pressed_n_o <= key_pressed_n or not enable_core_i;

   key_ready <= '1' when key_state = IDLE_ST else '0';

   uart_fsm_proc : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         key_num_o     <= key_num;
         key_pressed_n <= key_status_n;

         if G_USE_UART then
            case key_state is
               when IDLE_ST =>
                  if key_valid = '1' then
                     -- Store key
                     key_data_r <= key_data;
                     -- Simulate key pressed for a short while
                     key_timer  <= clk_main_speed_i / 32; -- 32 ms
                     key_state  <= KEY_PRESS_ST;
                  end if;

               when KEY_PRESS_ST =>
                  if key_num = key_data_r then
                     -- Override with key from UART
                     key_pressed_n <= '0';
                  end if;
                  if key_timer > 0 then
                     key_timer <= key_timer - 1;
                  elsif keys_read_i = '1' then -- Wait for QNICE to process key
                     -- Simulate key released for a short while
                     key_timer <= clk_main_speed_i / 32; -- 32 ms
                     key_state <= KEY_RELEASE_ST;
                  end if;

               when KEY_RELEASE_ST =>
                  if key_timer > 0 then
                     key_timer <= key_timer - 1;
                  elsif keys_read_i = '1' then -- Wait for QNICE to process key
                     key_state <= IDLE_ST;
                  end if;

            end case;

            if rst_main_i = '1' then
               key_state <= IDLE_ST;
            end if;
         end if;
      end if;
   end process uart_fsm_proc;

   -- output the keyboard interface for QNICE
   qnice_keys_n_o  <= keys_n;

   mega65kbd_to_matrix_inst : entity work.mega65kbd_to_matrix
      port map (
         ioclock           => clk_main_i,
         clock_frequency   => clk_main_speed_i,

         -- _steady means that the led stays on steadily
         -- _blinking means that the led is blinking
         -- The colors are specified as BGR (reverse RGB)
         powerled_steady   => power_led_i,
         powerled_col      => power_led_col_i(7 downto 0) & power_led_col_i(15 downto 8) & power_led_col_i(23 downto 16), -- RGB to BGR
         driveled_steady   => drive_led_i,
         driveled_blinking => '0',
         driveled_col      => drive_led_col_i(7 downto 0) & drive_led_col_i(15 downto 8) & drive_led_col_i(23 downto 16), -- RGB to BGR

         kio8              => kio8_o,
         kio9              => kio9_o,
         kio10             => kio10_i,

         matrix_col        => matrix_col,
         matrix_col_idx    => matrix_col_idx,

         capslock_out      => open
      ); -- mega65kbd_to_matrix_inst

   matrix_to_keynum_inst : entity work.matrix_to_keynum
      generic map (
         SCAN_FREQUENCY => G_SCAN_FREQUENCY
      )
      port map (
         clk                    => clk_main_i,
         clock_frequency        => clk_main_speed_i,
         reset_in               => rst_main_i,

         matrix_col             => matrix_col,
         matrix_col_idx         => matrix_col_idx,

         m65_key_num            => key_num,
         m65_key_status_n       => key_status_n,

         suppress_key_glitches  => '1',
         suppress_key_retrigger => '0',

         bucky_key              => open
      ); -- matrix_to_keynum_ins

   matrix_col_idx_proc : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if matrix_col_idx < 9 then
            matrix_col_idx <= matrix_col_idx + 1;
         else
            matrix_col_idx <= 0;
         end if;
      end if;
   end process matrix_col_idx_proc;

   -- make qnice_keys_o a register and fill it
   -- see sysdef.asm for the key-to-bit mapping
   keys_n_proc : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         case key_num_o is
            when 73 => keys_n(0) <= key_pressed_n;     -- Cursor up
            when  7 => keys_n(1) <= key_pressed_n;     -- Cursor down
            when 74 => keys_n(2) <= key_pressed_n;     -- Cursor left
            when  2 => keys_n(3) <= key_pressed_n;     -- Cursor right
            when  1 => keys_n(4) <= key_pressed_n;     -- Return
            when 60 => keys_n(5) <= key_pressed_n;     -- Space
            when 63 => keys_n(6) <= key_pressed_n;     -- Run/Stop
            when 67 => keys_n(7) <= key_pressed_n;     -- Help
            when  4 => keys_n(8) <= key_pressed_n;     -- F1
            when  5 => keys_n(9) <= key_pressed_n;     -- F3
            when others => null;
         end case;
      end if;
   end process keys_n_proc;

end architecture synthesis;

