---------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Custom keyboard controller for your core
--
-- Runs in the clock domain of the core.
--
-- Basic philosophy of keyboard handling in MiSTer2MEGA: 
--
-- Each core is treating the keyboard in a different way: Some need low-active "matrices", some
-- might need small high-active keyboard memories, etc. This is why the MiSTer2MEGA65 framework
-- lets you define literally everything and only provides a minimal abstraction layer to the keyboard.
-- You need to adjust this module to your needs.
--
-- MiSTer2MEGA65 provides a very simple and generic interface to the MEGA65 keyboard:
-- kb_key_num_i is running through the key numbers 0 to 79 with a frequency of 1 kHz, i.e. the whole
-- keyboard is scanned 1000 times per second. kb_key_pressed_n_i is already debounced and signals
-- low active, if a certain key is being pressed right now.
-- 
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
   port (
      clk_main_i           : in std_logic;                     -- core clock
         
      -- interface to the MEGA65 keyboard
      key_num_i            : in integer range 0 to 79;    -- cycles through all MEGA65 keys
      key_pressed_n_i      : in std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?
      
      -- @TODO: Create the kind of keyboard output that your core needs
      -- "example_n_o" is a low active register and used by the demo core:
      --    bit 0: Space
      --    bit 1: Return
      --    bit 2: Run/Stop
      example_n_o          : out std_logic_vector(2 downto 0)
   );
end keyboard;

architecture beh of keyboard is

-- @TODO remove this demo signal
signal   keys_n: std_logic_vector(2 downto 0) := "111"; -- low active: no key pressed

begin

   example_n_o <= keys_n;

-- MEGA65 key codes that kb_key_num_i is using while
-- kb_key_pressed_n_i is signalling (low active) which key is pressed
--
--    0   INS/DEL
--    1   RETURN
--    2   HORZ/CRSR
--    3   F8/F7
--    4   F2/F1
--    5   F4/F3
--    6   F6/F5
--    7   VERT/CRSR
--    8   #/3
--    9   W/w
--    10  A/a
--    11  $/4
--    12  Z/z
--    13  S/s
--    14  E/e
--    15  LEFT SHIFT (SHIFT LOCK is locking LEFT SHIFT)
--    16  %/5
--    17  R/r
--    18  D/d
--    19  &/6
--    20  C/c
--    21  F/f
--    22  T/t
--    23  X/x
--    24  '/7
--    25  Y/y
--    26  G/g
--    27  (/8
--    28  B/b
--    29  H/h
--    30  U/u
--    31  V/v
--    32  )/9
--    33  I/i
--    34  J/j
--    35  0/0
--    36  M/m
--    37  K/k
--    38  O/o
--    39  N/n
--    40  +
--    41  P/p
--    42  L/l
--    43  -
--    44  >/.
--    45  [/:
--    46  @
--    47  </,
--    48  British pound
--    49  *
--    50  ]/;
--    51  CLR/HOME
--    52  RIGHT SHIFT
--    53  }/=
--    54  ARROW UP KEY
--    55  ?//
--    56  !/1
--    57  ARROW LEFT KEY
--    58  CTRL
--    59  "/2
--    60  SPACE/BAR
--    61  MEGA65 KEY
--    62  Q/q
--    63  RUN/STOP
--    64  NO SCRL
--    65  TAB
--    66  ALT
--    67  HELP
--    68  F10/F9
--    69  F12/F11
--    70  F14/F13
--    71  ESC/NO KEY
--    72  CAPSLOCK
--    73  CURSOR UP = SHIFT+VERT/CRSR
--    74  CURSOR LEFT = SHIFT+HORZ/CRSR
--    75  RESTORE
--    76  (again: INST/DEL                  unclear why, do not use)
--    77  (again: RETURN                    unclear why,do not use)
--    78  (again: CAPS LOCK, but hi active  unclear why,do not use)
--    79  ???

   -- @TODO: Replace this demo keyboard handler (which is used by the M2M demo core) by your actual keyboard logic
   demo_core_handle_keys : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then      
         case key_num_i is
            when 1         => keys_n(1) <= key_pressed_n_i;   -- Return
            when 60        => keys_n(0) <= key_pressed_n_i;   -- Space
            when 63        => keys_n(2) <= key_pressed_n_i;   -- Run/Stop
            when others    => null;
         end case;
      end if;
   end process;      
end beh;
