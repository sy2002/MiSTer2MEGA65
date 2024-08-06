----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Hardware Abstraction Layer for external memory.
-- This supports both HyperRAM and SDRAM.
-- On the R3/R4/R5 boards, HyperRAM is used. On newer boards, SDRAM is used.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2024 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity memory_wrapper is
   generic (
      G_BOARD : string -- Which platform are we running on.
   );
   port (
      sys_clk_i           : in    std_logic; -- expects 100 MHz
      sys_rstn_i          : in    std_logic; -- Asynchronous, asserted low

      -- The clock depends on the type of memory:
      -- For HyperRAM, it will be 100 MHz.
      -- For SDRAM, it will be 166 MHz.
      mem_clk_o           : out   std_logic;
      mem_rst_o           : out   std_logic;

      -- Connect to framework
      mem_waitrequest_o   : out   std_logic;
      mem_write_i         : in    std_logic;
      mem_read_i          : in    std_logic;
      mem_address_i       : in    std_logic_vector(31 downto 0);
      mem_writedata_i     : in    std_logic_vector(15 downto 0);
      mem_byteenable_i    : in    std_logic_vector(1 downto 0);
      mem_burstcount_i    : in    std_logic_vector(7 downto 0);
      mem_readdata_o      : out   std_logic_vector(15 downto 0);
      mem_readdatavalid_o : out   std_logic;

      -- Connect to physical device
      hr_d_io             : inout std_logic_vector(7 downto 0);
      hr_rwds_io          : inout std_logic;
      hr_reset_o          : out   std_logic;
      hr_clk_p_o          : out   std_logic;
      hr_cs0_o            : out   std_logic
   );
end entity memory_wrapper;

architecture synthesis of memory_wrapper is

   -- Additional clocks used by the HyperRAM controller
   signal hr_clk_del      : std_logic;
   signal hr_delay_refclk : std_logic;

   -- Physical layer
   signal hr_rwds_in   : std_logic;
   signal hr_rwds_out  : std_logic;
   signal hr_rwds_oe_n : std_logic;                    -- Output enable for RWDS
   signal hr_dq_in     : std_logic_vector(7 downto 0);
   signal hr_dq_out    : std_logic_vector(7 downto 0);
   signal hr_dq_oe_n   : std_logic_vector(7 downto 0); -- Output enable for DQ

begin

   ---------------------------------------------------------------------------------------------------------------
   -- Generate clocks for the memory controller
   ---------------------------------------------------------------------------------------------------------------

   clk_memory_inst : entity work.clk_memory
      port map (
         sys_clk_i         => sys_clk_i,
         sys_rstn_i        => sys_rstn_i,
         hr_clk_o          => mem_clk_o,
         hr_rst_o          => mem_rst_o,
         hr_clk_del_o      => hr_clk_del,
         hr_delay_refclk_o => hr_delay_refclk
      ); -- clk_memory_inst


   ---------------------------------------------------------------------------------------------------------------
   -- HyperRAM controller
   ---------------------------------------------------------------------------------------------------------------

   hyperram_inst : entity work.hyperram
      generic map (
         G_ERRATA_ISSI_D_FIX => true
      )
      port map (
         clk_i               => mem_clk_o,
         rst_i               => mem_rst_o,
         avm_waitrequest_o   => mem_waitrequest_o,
         avm_write_i         => mem_write_i,
         avm_read_i          => mem_read_i,
         avm_address_i       => mem_address_i,
         avm_writedata_i     => mem_writedata_i,
         avm_byteenable_i    => mem_byteenable_i,
         avm_burstcount_i    => mem_burstcount_i,
         avm_readdata_o      => mem_readdata_o,
         avm_readdatavalid_o => mem_readdatavalid_o,
         clk_del_i           => hr_clk_del,
         delay_refclk_i      => hr_delay_refclk,
         hr_resetn_o         => hr_reset_o,
         hr_csn_o            => hr_cs0_o,
         hr_ck_o             => hr_clk_p_o,
         hr_rwds_in_i        => hr_rwds_in,
         hr_rwds_out_o       => hr_rwds_out,
         hr_rwds_oe_n_o      => hr_rwds_oe_n,
         hr_dq_in_i          => hr_dq_in,
         hr_dq_out_o         => hr_dq_out,
         hr_dq_oe_n_o        => hr_dq_oe_n
      ); -- hyperram_inst

   -- Tri-state buffers for HyperRAM
   hr_rwds_io <= hr_rwds_out when hr_rwds_oe_n = '0' else
                 'Z';

   hr_d_gen : for i in 0 to 7 generate
      hr_d_io(i) <= hr_dq_out(i) when hr_dq_oe_n(i) = '0' else
                    'Z';
   end generate hr_d_gen;

   hr_rwds_in <= hr_rwds_io;
   hr_dq_in   <= hr_d_io;

end architecture synthesis;

