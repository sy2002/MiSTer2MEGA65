----------------------------------------------------------------------------------
-- MiSTer2MEGA65
--
-- This module handles the protocol for file loading with the OSM.
-- This is a helper module for the core that needs to parse files
-- after they have been read.
--
-- done by MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package qnice_csr_pkg is

   constant C_ERROR_STRING_LENGTH : integer := 21;
   type string_vector is array (natural range <>) of string(1 to C_ERROR_STRING_LENGTH);

   -- Request status from the QNICE
   constant C_CSR_REQ_IDLE     : std_logic_vector(3 downto 0) := "0000";
   constant C_CSR_REQ_LDNG     : std_logic_vector(3 downto 0) := "0001";
   constant C_CSR_REQ_ERR      : std_logic_vector(3 downto 0) := "0010";
   constant C_CSR_REQ_OK       : std_logic_vector(3 downto 0) := "0011"; -- File is ready

   -- Response back to the QNICE
   constant C_CSR_RESP_IDLE    : std_logic_vector(3 downto 0) := "0000";
   constant C_CSR_RESP_PARSING : std_logic_vector(3 downto 0) := "0001";
   constant C_CSR_RESP_READY   : std_logic_vector(3 downto 0) := "0010"; -- Successfully parsed file
   constant C_CSR_RESP_ERROR   : std_logic_vector(3 downto 0) := "0011"; -- Error parsing file

end package qnice_csr_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.qnice_csr_pkg.all;

entity qnice_csr is
generic (
   G_ERROR_STRINGS : string_vector(0 to 15)
);
port (
   -- Interface to QNICE
   qnice_clk_i          : in  std_logic;
   qnice_rst_i          : in  std_logic;
   qnice_addr_i         : in  std_logic_vector(27 downto 0);
   qnice_data_i         : in  std_logic_vector(15 downto 0);
   qnice_ce_i           : in  std_logic;
   qnice_we_i           : in  std_logic;
   qnice_data_o         : out std_logic_vector(15 downto 0);
   qnice_wait_o         : out std_logic;

   -- Interface to core wrapper
   qnice_csr_o          : out std_logic;
   qnice_req_status_o   : out std_logic_vector( 3 downto 0); -- See C_CSR_REQ_* above
   qnice_req_length_o   : out std_logic_vector(22 downto 0); -- Byte length of file
   qnice_resp_status_i  : in  std_logic_vector( 3 downto 0); -- See C_CSR_RESP_* above
   qnice_resp_error_i   : in  std_logic_vector( 3 downto 0); -- Index into G_ERROR_STRINGS
   qnice_resp_address_i : in  std_logic_vector(22 downto 0)  -- Byte offset in file of error (approximate)
);
end entity qnice_csr;

architecture synthesis of qnice_csr is

   constant C_CSR_CASREG    : unsigned(15 downto 0) := X"FFFF";

   constant C_CSR_STATUS    : unsigned(11 downto 0) := X"000";
   constant C_CSR_FS_LO     : unsigned(11 downto 0) := X"001";
   constant C_CSR_FS_HI     : unsigned(11 downto 0) := X"002";
   constant C_CSR_PARSEST   : unsigned(11 downto 0) := X"010";
   constant C_CSR_PARSEE1   : unsigned(11 downto 0) := X"011";
   constant C_CSR_ADDR_LO   : unsigned(11 downto 0) := X"012";
   constant C_CSR_ADDR_HI   : unsigned(11 downto 0) := X"013";
   constant C_CSR_ERR_START : unsigned(11 downto 0) := X"100";
   constant C_CSR_ERR_END   : unsigned(11 downto 0) := X"1FF";

   -- return ASCII value of given string at the position defined by index (zero-based)
   pure function str2data(str : string; index : integer) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := index + 1;
      if strpos <= str'length then
         return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
      else
         return X"0000"; -- zero terminated strings
      end if;
   end function str2data;

begin

   -- True, when this entity is handling the request/response
   qnice_csr_o <= '1' when qnice_ce_i = '1' and unsigned(qnice_addr_i(27 downto 12)) = C_CSR_CASREG
             else '0';

   ----------------------------------------
   -- Decode information from and to QNICE
   ----------------------------------------

   p_write : process (qnice_clk_i)
   begin
      if falling_edge(qnice_clk_i) then
         if qnice_csr_o = '1' and qnice_we_i = '1' then
            case unsigned(qnice_addr_i(11 downto 0)) is
               when C_CSR_STATUS => qnice_req_status_o               <= qnice_data_i(3 downto 0);
               when C_CSR_FS_LO  => qnice_req_length_o(15 downto  0) <= qnice_data_i;
               when C_CSR_FS_HI  => qnice_req_length_o(22 downto 16) <= qnice_data_i(6 downto 0);
               when others => null;
            end case;
         end if;

         if qnice_rst_i = '1' then
            qnice_req_status_o <= (others => '0');
            qnice_req_length_o <= (others => '0');
         end if;
      end if;
   end process p_write;


   -----------------------------------------
   -- Generate response to QNICE
   -----------------------------------------

   p_read : process (all)
      variable error_index_v : natural range 0 to 7;
      variable char_index_v  : natural range 1 to 32;
   begin
      error_index_v := to_integer(unsigned(qnice_resp_error_i(2 downto 0)));
      char_index_v  := to_integer(unsigned(qnice_addr_i(4 downto 0)));

      qnice_data_o <= x"0000"; -- By default read back zeros.
      qnice_wait_o <= '0';

      if qnice_csr_o = '1' and qnice_we_i = '0' then
         case to_integer(unsigned(qnice_addr_i(11 downto 0))) is
            when to_integer(C_CSR_STATUS)  => qnice_data_o <= X"000" & qnice_req_status_o;
            when to_integer(C_CSR_FS_LO)   => qnice_data_o <= qnice_req_length_o(15 downto  0);
            when to_integer(C_CSR_FS_HI)   => qnice_data_o(6 downto 0) <= qnice_req_length_o(22 downto 16);
            when to_integer(C_CSR_PARSEST) => qnice_data_o <= X"000" & qnice_resp_status_i;
            when to_integer(C_CSR_PARSEE1) => qnice_data_o <= X"000" & qnice_resp_error_i;
            when to_integer(C_CSR_ADDR_LO) => qnice_data_o <= qnice_resp_address_i(15 downto 0);
            when to_integer(C_CSR_ADDR_HI) => qnice_data_o <= "000000000" & qnice_resp_address_i(22 downto 16);
            when to_integer(C_CSR_ERR_START)
              to to_integer(C_CSR_ERR_END) => qnice_data_o <= str2data(G_ERROR_STRINGS(error_index_v), char_index_v);
            when others => null;
         end case;
      end if;
   end process p_read;

end architecture synthesis;

