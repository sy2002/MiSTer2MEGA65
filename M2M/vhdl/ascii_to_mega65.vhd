library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- Translates key codes from ASCII to MEGA65.
--
-- I'm using the same key mapping as the XEMU:
-- https://github.com/MEGA65/mega65-user-guide/blob/master/images/xemu-extended-keyboard.png
--
-- In particular:
-- CLR/HOME <-> Home
-- RUN/STOP <-> End
-- HELP     <-> Page Up
-- RESTORE  <-> Page Down

entity ascii_to_mega65 is
   port (
      clk_i           : in    std_logic;
      rst_i           : in    std_logic;
      uart_rx_ready_o : out   std_logic;
      uart_rx_valid_i : in    std_logic;
      uart_rx_data_i  : in    std_logic_vector(7 downto 0);
      key_ready_i     : in    std_logic;
      key_valid_o     : out   std_logic;
      key_data_o      : out   natural range 0 to 79
   );
end entity ascii_to_mega65;

architecture synthesis of ascii_to_mega65 is

   constant C_UART_BUF_SIZE : natural                              := 5;

   -- Several keys have multiple different ASCII encodings
   constant C_F1_5          : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_31_31_7e";
   constant C_F3_5          : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_31_33_7e";
   constant C_F5_5          : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_31_35_7e";
   constant C_F7_5          : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_31_38_7e";
   constant C_F9_5          : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_32_30_7e";
   constant C_F11_5         : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_32_33_7e";
   constant C_F12_5         : std_logic_vector(5 * 8 - 1 downto 0) := X"1b_5b_32_34_7e";
   constant C_HOME_4        : std_logic_vector(4 * 8 - 1 downto 0) := X"1b_5b_31_7e";
   constant C_INSERT_4      : std_logic_vector(4 * 8 - 1 downto 0) := X"1b_5b_32_7e";
   constant C_DELETE_4      : std_logic_vector(4 * 8 - 1 downto 0) := X"1b_5b_33_7e";
   constant C_END_4         : std_logic_vector(4 * 8 - 1 downto 0) := X"1b_5b_34_7e";
   constant C_PAGE_UP_4     : std_logic_vector(4 * 8 - 1 downto 0) := X"1b_5b_35_7e";
   constant C_PAGE_DOWN_4   : std_logic_vector(4 * 8 - 1 downto 0) := X"1b_5b_36_7e";
   constant C_F1_3          : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_4f_50";
   constant C_F3_3          : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_4f_52";
   constant C_F5_3          : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_4f_54";
   constant C_F7_3          : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_4f_56";
   constant C_UP_3          : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_5b_41";
   constant C_DOWN_3        : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_5b_42";
   constant C_RIGHT_3       : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_5b_43";
   constant C_LEFT_3        : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_5b_44";
   constant C_END_3         : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_5b_46";
   constant C_HOME_3        : std_logic_vector(3 * 8 - 1 downto 0) := X"1b_5b_48";

   -- MEGA65 key codes
   constant C_M65_INS_DEL     : integer          := 0;
   constant C_M65_RETURN      : integer          := 1;
   constant C_M65_HORZ_CRSR   : integer          := 2;  -- means cursor right in C64 terminology
   constant C_M65_F7          : integer          := 3;
   constant C_M65_F1          : integer          := 4;
   constant C_M65_F3          : integer          := 5;
   constant C_M65_F5          : integer          := 6;
   constant C_M65_VERT_CRSR   : integer          := 7;  -- means cursor down in C64 terminology
   constant C_M65_3           : integer          := 8;
   constant C_M65_W           : integer          := 9;
   constant C_M65_A           : integer          := 10;
   constant C_M65_4           : integer          := 11;
   constant C_M65_Z           : integer          := 12;
   constant C_M65_S           : integer          := 13;
   constant C_M65_E           : integer          := 14;
   constant C_M65_LEFT_SHIFT  : integer          := 15;
   constant C_M65_5           : integer          := 16;
   constant C_M65_R           : integer          := 17;
   constant C_M65_D           : integer          := 18;
   constant C_M65_6           : integer          := 19;
   constant C_M65_C           : integer          := 20;
   constant C_M65_F           : integer          := 21;
   constant C_M65_T           : integer          := 22;
   constant C_M65_X           : integer          := 23;
   constant C_M65_7           : integer          := 24;
   constant C_M65_Y           : integer          := 25;
   constant C_M65_G           : integer          := 26;
   constant C_M65_8           : integer          := 27;
   constant C_M65_B           : integer          := 28;
   constant C_M65_H           : integer          := 29;
   constant C_M65_U           : integer          := 30;
   constant C_M65_V           : integer          := 31;
   constant C_M65_9           : integer          := 32;
   constant C_M65_I           : integer          := 33;
   constant C_M65_J           : integer          := 34;
   constant C_M65_0           : integer          := 35;
   constant C_M65_M           : integer          := 36;
   constant C_M65_K           : integer          := 37;
   constant C_M65_O           : integer          := 38;
   constant C_M65_N           : integer          := 39;
   constant C_M65_PLUS        : integer          := 40;
   constant C_M65_P           : integer          := 41;
   constant C_M65_L           : integer          := 42;
   constant C_M65_MINUS       : integer          := 43;
   constant C_M65_DOT         : integer          := 44;
   constant C_M65_COLON       : integer          := 45;
   constant C_M65_AT          : integer          := 46;
   constant C_M65_COMMA       : integer          := 47;
   constant C_M65_GBP         : integer          := 48;
   constant C_M65_ASTERISK    : integer          := 49;
   constant C_M65_SEMICOLON   : integer          := 50;
   constant C_M65_CLR_HOME    : integer          := 51;
   constant C_M65_RIGHT_SHIFT : integer          := 52;
   constant C_M65_EQUAL       : integer          := 53;
   constant C_M65_ARROW_UP    : integer          := 54; -- symbol, not cursor
   constant C_M65_SLASH       : integer          := 55;
   constant C_M65_1           : integer          := 56;
   constant C_M65_ARROW_LEFT  : integer          := 57; -- symbol, not cursor
   constant C_M65_CTRL        : integer          := 58;
   constant C_M65_2           : integer          := 59;
   constant C_M65_SPACE       : integer          := 60;
   constant C_M65_MEGA        : integer          := 61;
   constant C_M65_Q           : integer          := 62;
   constant C_M65_RUN_STOP    : integer          := 63;
   constant C_M65_NO_SCRL     : integer          := 64;
   constant C_M65_TAB         : integer          := 65;
   constant C_M65_ALT         : integer          := 66;
   constant C_M65_HELP        : integer          := 67;
   constant C_M65_F9          : integer          := 68;
   constant C_M65_F11         : integer          := 69;
   constant C_M65_F13         : integer          := 70;
   constant C_M65_ESC         : integer          := 71;
   constant C_M65_CAPSLOCK    : integer          := 72;
   constant C_M65_UP_CRSR     : integer          := 73; -- cursor up
   constant C_M65_LEFT_CRSR   : integer          := 74; -- cursor left
   constant C_M65_RESTORE     : integer          := 75;
   constant C_M65_NONE        : integer          := 79;

   signal   uart_buf     : std_logic_vector(C_UART_BUF_SIZE * 8 - 1 downto 0);
   signal   uart_buf_len : natural range 0 to C_UART_BUF_SIZE;
   signal   uart_buf_en  : std_logic;

begin

   uart_rx_ready_o <= (key_ready_i or not key_valid_o) and uart_buf_en;

   uart_buf_proc : process (clk_i)
      variable uart_buf_hex_v : std_logic_vector(C_UART_BUF_SIZE * 16 - 1 downto 0);
   begin
      if rising_edge(clk_i) then
         -- Only check input every other clock cycle
         uart_buf_en <= not uart_buf_en;

         if key_ready_i = '1' then
            key_valid_o <= '0';
         end if;

         if uart_rx_valid_i = '1' and uart_rx_ready_o = '1' then
            -- A byte is received, just shift it in.
            uart_buf <= uart_buf(uart_buf'left-8 downto 0) & uart_rx_data_i;
            if uart_buf_len < C_UART_BUF_SIZE then
               uart_buf_len <= uart_buf_len + 1;
            end if;
         elsif uart_buf_len >= 5 then
            -- As soon as 5 bytes are received, consume them all no matter what.
            uart_buf_len <= 0;
            key_valid_o  <= '1';
            case uart_buf(5*8-1 downto 0) is
               when C_F1_5  => key_data_o <= C_M65_F1;
               when C_F3_5  => key_data_o <= C_M65_F3;
               when C_F5_5  => key_data_o <= C_M65_F5;
               when C_F7_5  => key_data_o <= C_M65_F7;
               when C_F9_5  => key_data_o <= C_M65_F9;
               when C_F11_5 => key_data_o <= C_M65_F11;
               when others =>
                  key_valid_o <= key_valid_o; -- Leave unchanged
            end case;
         elsif uart_buf_len >= 4 then
            uart_buf_len <= 0;
            key_valid_o  <= '1';
            case uart_buf(4*8-1 downto 0) is
               when C_PAGE_UP_4   => key_data_o <= C_M65_HELP;
               when C_PAGE_DOWN_4 => key_data_o <= C_M65_RESTORE;
               when C_HOME_4      => key_data_o <= C_M65_CLR_HOME;
               when C_END_4       => key_data_o <= C_M65_RUN_STOP;

               when others =>
                  key_valid_o <= key_valid_o; -- Leave unchanged
                  if uart_buf(uart_buf_len*8-1 downto uart_buf_len*8-8) = X"1b" and uart_buf(7 downto 0) /= X"7e" then
                     -- Don't consume if this is an unterminated escape sequence
                     uart_buf_len <= uart_buf_len;
                  end if;
            end case;
         elsif uart_buf_len >= 3 then
            uart_buf_len <= 0;
            key_valid_o  <= '1';
            case uart_buf(3*8-1 downto 0) is
               when C_F1_3    => key_data_o <= C_M65_F1;
               when C_F3_3    => key_data_o <= C_M65_F3;
               when C_F5_3    => key_data_o <= C_M65_F5;
               when C_F7_3    => key_data_o <= C_M65_F7;
               when C_UP_3    => key_data_o <= C_M65_UP_CRSR;
               when C_DOWN_3  => key_data_o <= C_M65_VERT_CRSR;
               when C_LEFT_3  => key_data_o <= C_M65_LEFT_CRSR;
               when C_RIGHT_3 => key_data_o <= C_M65_HORZ_CRSR;
               when C_HOME_3  => key_data_o <= C_M65_CLR_HOME;
               when C_END_3   => key_data_o <= C_M65_RUN_STOP;
               when others =>
                  key_valid_o <= key_valid_o; -- Leave unchanged
                  if uart_buf(uart_buf_len*8-1 downto uart_buf_len*8-8) = X"1b" and uart_buf(7 downto 0) /= X"7e" then
                     -- Don't consume if this is an unterminated escape sequence
                     uart_buf_len <= uart_buf_len;
                  end if;
            end case;
         elsif uart_buf_len >= 1 then
            uart_buf_len <= 0;
            key_valid_o  <= '1';
            case character'val(to_integer(uart_buf(7 downto 0))) is
               when character'val( 9) => key_data_o <= C_M65_TAB;
               when character'val(13) => key_data_o <= C_M65_RETURN;
               when ' '       => key_data_o <= C_M65_SPACE;
               when '*'       => key_data_o <= C_M65_ASTERISK;
               when '+'       => key_data_o <= C_M65_PLUS;
               when ','       => key_data_o <= C_M65_COMMA;
               when '-'       => key_data_o <= C_M65_MINUS;
               when '.'       => key_data_o <= C_M65_DOT;
               when '/'       => key_data_o <= C_M65_SLASH;
               when '0'       => key_data_o <= C_M65_0;
               when '1'       => key_data_o <= C_M65_1;
               when '2'       => key_data_o <= C_M65_2;
               when '3'       => key_data_o <= C_M65_3;
               when '4'       => key_data_o <= C_M65_4;
               when '5'       => key_data_o <= C_M65_5;
               when '6'       => key_data_o <= C_M65_6;
               when '7'       => key_data_o <= C_M65_7;
               when '8'       => key_data_o <= C_M65_8;
               when '9'       => key_data_o <= C_M65_9;
               when ':'       => key_data_o <= C_M65_COLON;
               when ';'       => key_data_o <= C_M65_SEMICOLON;
               when '='       => key_data_o <= C_M65_EQUAL;
               when '@'       => key_data_o <= C_M65_AT;
               when 'a' | 'A' => key_data_o <= C_M65_A;
               when 'b' | 'B' => key_data_o <= C_M65_B;
               when 'c' | 'C' => key_data_o <= C_M65_C;
               when 'd' | 'D' => key_data_o <= C_M65_D;
               when 'e' | 'E' => key_data_o <= C_M65_E;
               when 'f' | 'F' => key_data_o <= C_M65_F;
               when 'g' | 'G' => key_data_o <= C_M65_G;
               when 'h' | 'H' => key_data_o <= C_M65_H;
               when 'i' | 'I' => key_data_o <= C_M65_I;
               when 'j' | 'J' => key_data_o <= C_M65_J;
               when 'k' | 'K' => key_data_o <= C_M65_K;
               when 'l' | 'L' => key_data_o <= C_M65_L;
               when 'm' | 'M' => key_data_o <= C_M65_M;
               when 'n' | 'N' => key_data_o <= C_M65_N;
               when 'o' | 'O' => key_data_o <= C_M65_O;
               when 'p' | 'P' => key_data_o <= C_M65_P;
               when 'q' | 'Q' => key_data_o <= C_M65_Q;
               when 'r' | 'R' => key_data_o <= C_M65_R;
               when 's' | 'S' => key_data_o <= C_M65_S;
               when 't' | 'T' => key_data_o <= C_M65_T;
               when 'u' | 'U' => key_data_o <= C_M65_U;
               when 'v' | 'V' => key_data_o <= C_M65_V;
               when 'w' | 'W' => key_data_o <= C_M65_W;
               when 'x' | 'X' => key_data_o <= C_M65_X;
               when 'y' | 'Y' => key_data_o <= C_M65_Y;
               when 'z' | 'Z' => key_data_o <= C_M65_Z;
               when others =>
                  key_valid_o  <= key_valid_o; -- Leave unchanged

                  if uart_buf(uart_buf_len*8-1 downto uart_buf_len*8-8) = X"1b" and uart_buf(7 downto 0) /= X"7e" then
                     -- Don't consume if this is an unterminated escape sequence
                     uart_buf_len <= uart_buf_len;
                  end if;
            end case;
         end if;

         if rst_i = '1' then
            uart_buf_len      <= 0;
         end if;
      end if;
   end process uart_buf_proc;

end architecture synthesis;

