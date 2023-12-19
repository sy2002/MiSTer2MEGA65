library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity qnice_arbit is
  port (
    clk_i        : in  std_logic;
    rst_i        : in  std_logic;

    s0_wait_o    : out std_logic;
    s0_ce_i      : in  std_logic;
    s0_we_i      : in  std_logic;
    s0_addr_i    : in  std_logic_vector(27 downto 0);
    s0_wr_data_i : in  std_logic_vector(15 downto 0);
    s0_rd_data_o : out std_logic_vector(15 downto 0);

    s1_wait_o    : out std_logic;
    s1_ce_i      : in  std_logic;
    s1_we_i      : in  std_logic;
    s1_addr_i    : in  std_logic_vector(27 downto 0);
    s1_wr_data_i : in  std_logic_vector(15 downto 0);
    s1_rd_data_o : out std_logic_vector(15 downto 0);

    m_wait_i     : in  std_logic;
    m_ce_o       : out std_logic;
    m_we_o       : out std_logic;
    m_addr_o     : out std_logic_vector(27 downto 0);
    m_wr_data_o  : out std_logic_vector(15 downto 0);
    m_rd_data_i  : in  std_logic_vector(15 downto 0)
  );
end entity qnice_arbit;

architecture synthesis of qnice_arbit is

-- This does the same as the ternary operator "cond ? t : f" in the C language
pure function cond_select(cond : std_logic; t : std_logic_vector; f : std_logic_vector) return std_logic_vector is
begin
   if cond = '1' then
      return t;
   else
      return f;
   end if;
end function cond_select;

-- This does the same as the ternary operator "cond ? t : f" in the C language
pure function cond_select(cond : std_logic; t : std_logic; f : std_logic) return std_logic is
begin
   if cond = '1' then
      return t;
   else
      return f;
   end if;
end function cond_select;

begin

   m_ce_o      <= cond_select(s1_ce_i, s1_ce_i,      s0_ce_i);
   m_we_o      <= cond_select(s1_ce_i, s1_we_i,      s0_we_i);
   m_addr_o    <= cond_select(s1_ce_i, s1_addr_i,    s0_addr_i);
   m_wr_data_o <= cond_select(s1_ce_i, s1_wr_data_i, s0_wr_data_i);

   s0_wait_o    <= m_wait_i;
   s1_wait_o    <= m_wait_i;
   s0_rd_data_o <= m_rd_data_i;
   s1_rd_data_o <= m_rd_data_i;

end architecture synthesis;

