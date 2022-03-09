library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hyperram_wrapper is
   generic (
      N_DW : natural range 64 to 128 := 128;
      N_AW : natural range 8 to 32 := 19
   );
   port (
      avl_clk_i           : in    std_logic;
      avl_rst_i           : in    std_logic;
      avl_burstcount_i    : in    std_logic_vector(7 downto 0);
      avl_writedata_i     : in    std_logic_vector(N_DW-1 downto 0);
      avl_address_i       : in    std_logic_vector(N_AW-1 downto 0);
      avl_write_i         : in    std_logic;
      avl_read_i          : in    std_logic;
      avl_byteenable_i    : in    std_logic_vector(N_DW/8-1 downto 0);
      avl_waitrequest_o   : out   std_logic;
      avl_readdata_o      : out   std_logic_vector(N_DW-1 downto 0);
      avl_readdatavalid_o : out   std_logic;

      clk_x2_i            : in    std_logic; -- Physical I/O only
      clk_x2_del_i        : in    std_logic; -- Double frequency, phase shifted

      -- HyperRAM device interface
      hr_resetn_o         : out   std_logic;
      hr_csn_o            : out   std_logic;
      hr_ck_o             : out   std_logic;
      hr_rwds_io          : inout std_logic;
      hr_dq_io            : inout std_logic_vector(7 downto 0)
   );
end entity hyperram_wrapper;

architecture synthesis of hyperram_wrapper is

   -- HyperRAM
   signal avm_write         : std_logic;
   signal avm_read          : std_logic;
   signal avm_address       : std_logic_vector(31 downto 0) := (others => '0');
   signal avm_writedata     : std_logic_vector(15 downto 0);
   signal avm_byteenable    : std_logic_vector(1 downto 0);
   signal avm_burstcount    : std_logic_vector(7 downto 0);
   signal avm_readdata      : std_logic_vector(15 downto 0);
   signal avm_readdatavalid : std_logic;
   signal avm_waitrequest   : std_logic;

   signal hr_rwds_in        : std_logic;
   signal hr_rwds_out       : std_logic;
   signal hr_rwds_oe        : std_logic;   -- Output enable for RWDS
   signal hr_dq_in          : std_logic_vector(7 downto 0);
   signal hr_dq_out         : std_logic_vector(7 downto 0);
   signal hr_dq_oe          : std_logic;    -- Output enable for DQ

begin

   --------------------------------------------------------
   -- Convert from ascaler data width to HyperRAM data width
   --------------------------------------------------------

   i_avm_decrease : entity work.avm_decrease
      generic map (
         G_SLAVE_ADDRESS_SIZE  => N_AW,
         G_SLAVE_DATA_SIZE     => N_DW,
         G_MASTER_ADDRESS_SIZE => 22,  -- HyperRAM size is 4 MWords = 8 MBbytes.
         G_MASTER_DATA_SIZE    => 16
      )
      port map (
         clk_i                 => avl_clk_i,
         rst_i                 => avl_rst_i,
         s_avm_write_i         => avl_write_i,
         s_avm_read_i          => avl_read_i,
         s_avm_address_i       => avl_address_i,
         s_avm_writedata_i     => avl_writedata_i,
         s_avm_byteenable_i    => avl_byteenable_i,
         s_avm_burstcount_i    => avl_burstcount_i,
         s_avm_readdata_o      => avl_readdata_o,
         s_avm_readdatavalid_o => avl_readdatavalid_o,
         s_avm_waitrequest_o   => avl_waitrequest_o,
         m_avm_write_o         => avm_write,
         m_avm_read_o          => avm_read,
         m_avm_address_o       => avm_address(21 downto 0), -- MSB defaults to zero
         m_avm_writedata_o     => avm_writedata,
         m_avm_byteenable_o    => avm_byteenable,
         m_avm_burstcount_o    => avm_burstcount,
         m_avm_readdata_i      => avm_readdata,
         m_avm_readdatavalid_i => avm_readdatavalid,
         m_avm_waitrequest_i   => avm_waitrequest
      ); -- i_avm_decrease


   --------------------------------------------------------
   -- Instantiate HyperRAM controller
   --------------------------------------------------------

   i_hyperram : entity work.hyperram
      port map (
         clk_x1_i            => avl_clk_i,
         clk_x2_i            => clk_x2_i,
         clk_x2_del_i        => clk_x2_del_i,
         rst_i               => avl_rst_i,
         avm_write_i         => avm_write,
         avm_read_i          => avm_read,
         avm_address_i       => avm_address,
         avm_writedata_i     => avm_writedata,
         avm_byteenable_i    => avm_byteenable,
         avm_burstcount_i    => avm_burstcount,
         avm_readdata_o      => avm_readdata,
         avm_readdatavalid_o => avm_readdatavalid,
         avm_waitrequest_o   => avm_waitrequest,
         hr_resetn_o         => hr_resetn_o,
         hr_csn_o            => hr_csn_o,
         hr_ck_o             => hr_ck_o,
         hr_rwds_in_i        => hr_rwds_in,
         hr_rwds_out_o       => hr_rwds_out,
         hr_rwds_oe_o        => hr_rwds_oe,
         hr_dq_in_i          => hr_dq_in,
         hr_dq_out_o         => hr_dq_out,
         hr_dq_oe_o          => hr_dq_oe
      ); -- i_hyperram


   ----------------------------------
   -- Tri-state buffers for HyperRAM
   ----------------------------------

   hr_rwds_io <= hr_rwds_out when hr_rwds_oe = '1' else 'Z';
   hr_dq_io   <= hr_dq_out   when hr_dq_oe   = '1' else (others => 'Z');
   hr_rwds_in <= hr_rwds_io;
   hr_dq_in   <= hr_dq_io;

end architecture synthesis;

