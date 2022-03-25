----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Configuration data for the Shell
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity config is
port (
   -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
   -- bits 11 downto 0: address the up to 4k the configuration data
   address_i   : in std_logic_vector(27 downto 0);
   
   -- config data
   data_o      : out std_logic_vector(15 downto 0)
);
end config;

architecture beh of config is

--------------------------------------------------------------------------------------------------------------------
-- String and character constants (specific for the Anikki-16x16 font)
--------------------------------------------------------------------------------------------------------------------

constant CHR_LINE_1  : character := character'val(196);
constant CHR_LINE_5  : string := CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1;
constant CHR_LINE_10 : string := CHR_LINE_5 & CHR_LINE_5;
constant CHR_LINE_50 : string := CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10;

--------------------------------------------------------------------------------------------------------------------
-- Welcome Screen (Selectors 0x0000 .. 0x00FF) 
--------------------------------------------------------------------------------------------------------------------

constant SEL_WELCOME : std_logic_vector(15 downto 0) := x"0000";
constant SCR_WELCOME : string :=

   "Name of the Demo Core Version 1.0\n" &
   "MiSTer port done by Demo Author in 2022\n\n" &

   -- We are not insisting. But it would be nice if you gave us credit for MiSTer2MEGA65 by leaving these lines in
   "Powered by MiSTer2MEGA65 Version [WIP],\n" &
   "done by sy2002 and MJoergen in 2022\n" &

   "\n\nEdit config.vhd to modify welcome screen.\n\n" &
   "You can for example show the keyboard map.\n" &
   "Look at this example from Game Boy Color:\n\n\n" &

   "    MEGA65               Game Boy\n" & 
   "    " & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_1 & CHR_LINE_1 & "\n" &
   "    Cursor keys          Joypad\n" &
   "    Space                Start\n" &
   "    Enter                Select\n" &
   "    Left Shift           A\n" &
   "    MEGA65 key           B\n" &
   "    Help                 Options menu\n\n\n" &

   "\n\n    Press Space to continue.\n\n\n";

-- @TODO: We want to support multiple help/screens more screens that can be browsed, maybe even linked
-- Logic to be thought-trough. We might think of a double-linked-list structure beginning from 0x0001 on:
-- forward/backward/data and arrow keys for navigation, SPACE to end the help mode and to continue

--------------------------------------------------------------------------------------------------------------------
-- Set start folder for file browser (Selector 0x0100) 
--------------------------------------------------------------------------------------------------------------------

constant SEL_DIR_START : std_logic_vector(15 downto 0) := x"0100";
constant DIR_START     : string := "/m2m";

--------------------------------------------------------------------------------------------------------------------
-- Load one or more mandatory or optional BIOS/ROMs  (Selectors 0x0200 .. 0x02FF) 
--------------------------------------------------------------------------------------------------------------------

-- Data structure: Word 0: Flags, Word 1+: full path to BIOS/ROM
-- Flags: bit 0: 1=mandatory
--        bit 1: 1=hide this file from the file browser
--        bit 2: 1=needs magic byte mapping
--        bit 3: 1=increasing the selector by 3 leads to one more BIOS/ROM

-- You need to create the desired amount SEL_ROM_x_FLAG, SEL_ROM_x_FILE and SEL_ROM_x_MAGIC constants
-- and add them to the addr_decode process
--
-- Make sure that each block consists of exactly 4 selectors, so that the firmware can trust, that
-- adding 4 to the selector in case of flag bit 3 = 1 always leads to the next valid selector block
--
-- About "magic": @TODO: This is a future feature: While reading the ROM/BIOS: Certain bytes within
-- the file can be extracted and mapped to general purpose control flags (M2M$CFD_ADDR and 2M$CFD_DATA)
--
-- About "device": This is the device ID that you want to load the BIOS/ROM to. Make sure that you are always using
-- symbolic names here and that you are adjusting the process "qnice_ramrom_devices" in mega95.vhd accordingly  

-- TODO REFACTOR: USE RECORDS AND A RETRIEVAL FUNCTION
constant SEL_ROM_1_FLAG   : std_logic_vector(15 downto 0) := x"0200";
constant SEL_ROM_1_FILE   : std_logic_vector(15 downto 0) := x"0201";
constant SEL_ROM_1_MAGIC  : std_logic_vector(15 downto 0) := x"0202";
constant SEL_ROM_1_DEVICE : std_logic_vector(15 downto 0) := x"0203";
constant ROM_1_FLAG       : std_logic_vector(15 downto 0) := x"000" & "1011"; -- mandatory, hide, no magic, there is more
constant ROM_1_FILE       : string := "/m2m/logo.rom";

constant SEL_ROM_2_FLAG   : std_logic_vector(15 downto 0) := x"0204"; 
constant SEL_ROM_2_FILE   : std_logic_vector(15 downto 0) := x"0205";
constant SEL_ROM_2_MAGIC  : std_logic_vector(15 downto 0) := x"0206";
constant SEL_ROM_2_DEVICE : std_logic_vector(15 downto 0) := x"0207";
constant ROM_2_FLAG       : std_logic_vector(15 downto 0) := x"000" & "0000"; -- optional, do not hide, no magic, no more roms
constant ROM_2_FILE       : string := "/m2m/test_opt.rom";

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu  (Selectors 0x0300 .. 0x0304) 
--------------------------------------------------------------------------------------------------------------------

constant SEL_OPTM_ITEMS    : std_logic_vector(15 downto 0) := x"0300";
constant SEL_OPTM_GROUPS   : std_logic_vector(15 downto 0) := x"0301";
constant SEL_OPTM_STDSEL   : std_logic_vector(15 downto 0) := x"0302";
constant SEL_OPTM_LINES    : std_logic_vector(15 downto 0) := x"0303";
constant SEL_OPTM_START    : std_logic_vector(15 downto 0) := x"0304";
constant SEL_OPTM_ICOUNT   : std_logic_vector(15 downto 0) := x"0305";

-- Configuration constants for OPTM_GROUPS (do not change their value, shell.asm and menu.asm expect them to be like this)
constant OPTM_G_TEXT       : integer := 0;                -- text that cannot be selected
constant OPTM_G_CLOSE      : integer := 16#00FF#;         -- menu items that closes menu
constant OPTM_G_STDSEL     : integer := 16#0100#;         -- item within a group that is selected by default
constant OPTM_G_LINE       : integer := 16#0200#;         -- draw a line at this position
constant OPTM_G_START      : integer := 16#0400#;         -- selector / cursor position after startup (only use once!)
constant OPTM_G_SINGLESEL  : integer := 16#8000#;         -- single select item

-- Size of menu and menu items
   
-- CAUTION: End each line (also the last one) with a \n and make sure empty lines / separator lines are only consisting of a "\n"
--          Do use a lower case \n. If you forget one of them or if you use upper case, you will run into undefined behavior.
constant OPTM_SIZE         : integer := 24;  -- amount of items including empty lines:
                                             -- needs to be equal to the number of lines in OPTM_ITEM and amount of items in OPTM_GROUPS
                                             -- Important: make sure that SHELL_O_DY in mega65.vhd is equal to OPTM_SIZE + 2,
                                             -- so that the On-Screen window has the correct length
                                             -- @TODO: There is for sure a more elegant way than this redundant definition
constant OPTM_ITEMS        : string :=

   " Demo Headline A\n" &
   "\n" & 
   " Item A.1\n" &
   " Item A.2\n" &
   "\n" &
   " Headline B\n" &
   "\n" &
   " Triple Buffering\n"   &
   "\n"                    &
   " On\n"                 &
   " Off\n"                &
   "\n"                    &
   " 60 Hz\n"              &
   "\n"                    &
   " On\n"                 &
   " Off\n"                &
   "\n"                    &
   " Another Headline\n" &
   "\n" &
   " Yes\n" &
   " No\n" &
   " Maybe\n" &
   "\n" &
   " Close Menu\n";
        
-- define your own constants here and choose meaningful names
-- make sure that your first group uses the value 1 (0 means "no menu item", such as text and line),
-- and be aware that you can only have a maximum of 254 groups (255 means "Close Menu");
-- also make sure that your group numbers are monotonic increasing (e.g. 1, 2, 3, 4, ...)
constant OPTM_G_A          : integer := 1;
constant OPTM_G_B          : integer := 2;
constant OPTM_G_AUDIO      : integer := 3;
constant OPTM_G_VIDEO      : integer := 4;
constant OPTM_G_ANOTHER    : integer := 5;

-- define your menu groups: which menu items are belonging together to form a group?
-- where are separator lines? which items should be selected by default?
-- make sure that you have exactly the same amount of entries here than in OPTM_ITEMS and defined by OPTM_SIZE
type OPTM_GTYPE is array (0 to OPTM_SIZE - 1) of integer range 0 to 65535;
constant OPTM_GROUPS       : OPTM_GTYPE := ( OPTM_G_TEXT,                              -- Demo Headline
                                             OPTM_G_LINE,                              -- Line
                                             OPTM_G_A + OPTM_G_START,                  -- Item A.1, cursor start position
                                             OPTM_G_A + OPTM_G_STDSEL,                 -- Item A.2, selected by default
                                             OPTM_G_LINE,                              -- Line
                                             OPTM_G_TEXT,                              -- Headine B
                                             OPTM_G_LINE,                              -- Line
                                             OPTM_G_TEXT,
                                             OPTM_G_LINE,
                                             OPTM_G_AUDIO   + OPTM_G_STDSEL,
                                             OPTM_G_AUDIO,
                                             OPTM_G_LINE,
                                             OPTM_G_TEXT,
                                             OPTM_G_LINE,
                                             OPTM_G_VIDEO   + OPTM_G_STDSEL,
                                             OPTM_G_VIDEO,
                                             OPTM_G_LINE,
                                             OPTM_G_TEXT,                              -- Another Headline
                                             OPTM_G_LINE,                              -- Line
                                             OPTM_G_ANOTHER + OPTM_G_STDSEL,           -- Item Yes, selected by default
                                             OPTM_G_ANOTHER,                           -- Item No
                                             OPTM_G_ANOTHER,                           -- Item Maybe
                                             OPTM_G_LINE,                              -- Line
                                             OPTM_G_CLOSE                              -- Close Menu
                                           ); 

--------------------------------------------------------------------------------------------------------------------
-- Address Decoding 
--------------------------------------------------------------------------------------------------------------------

begin

addr_decode : process(all)
   variable index : integer;
   
   -- return ASCII value of given string at the position defined by address_i(11 downto 0)
   function str2data(str : string) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := to_integer(unsigned(address_i(11 downto 0))) + 1;
      if strpos <= str'length then
         return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
      else
         return (others => '0'); -- zero terminated strings
      end if;
   end;
     
begin
   data_o <= x"EEEE";
   index := to_integer(unsigned(address_i(11 downto 0)));
   
   case address_i(27 downto 12) is   
      when SEL_WELCOME     => data_o <= str2data(SCR_WELCOME);
      when SEL_DIR_START   => data_o <= str2data(DIR_START);
      when SEL_OPTM_ITEMS  => data_o <= str2data(OPTM_ITEMS);
      when SEL_OPTM_GROUPS => data_o <= x"00" & std_logic_vector(to_unsigned(OPTM_GROUPS(index), 16)(7 downto 0));
      when SEL_OPTM_STDSEL => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), 16)(8));
      when SEL_OPTM_LINES  => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), 16)(9));
      when SEL_OPTM_START  => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), 16)(10));
      when SEL_OPTM_ICOUNT => data_o <= x"00" & std_logic_vector(to_unsigned(OPTM_SIZE, 8));
             
      -- BIOS / ROM section
      -- @TODO: Add the desired amount of SEL_ROM_x_FLAG and SEL_ROM_x_FILE constants here
      when SEL_ROM_1_FLAG  => data_o <= ROM_1_FLAG;
      when SEL_ROM_1_FILE  => data_o <= str2data(ROM_1_FILE);
      when SEL_ROM_2_FLAG  => data_o <= ROM_2_FLAG;
      when SEL_ROM_2_FILE  => data_o <= str2data(ROM_2_FILE);
   
      when others => null;
   end case;
end process;

end beh;
