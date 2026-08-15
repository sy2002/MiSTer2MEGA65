----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Adversarial regression test for virtual-drive image event handling
--
-- This framework is based on the MiSTer project
-- Powered by MiSTer2MEGA65
-- MiSTer2MEGA65 done by sy2002 and MJoergen since 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

use work.vdrives_pkg.all;

entity vdrives_test is
end entity vdrives_test;

architecture test of vdrives_test is
   constant C_VDNUM : natural := 2;
   type natural_array is array(natural range <>) of natural;

   signal clk_qnice  : std_logic := '0';
   signal clk_core   : std_logic := '0';
   signal reset_core : std_logic := '1';

   signal img_mounted        : std_logic_vector(C_VDNUM - 1 downto 0);
   signal img_readonly       : std_logic;
   signal img_size           : std_logic_vector(31 downto 0);
   signal img_type           : std_logic_vector(1 downto 0);
   signal drive_mounted      : std_logic_vector(C_VDNUM - 1 downto 0);
   signal img_mounted_toggle : std_logic_vector(C_VDNUM - 1 downto 0);
   signal cache_dirty        : std_logic_vector(C_VDNUM - 1 downto 0);
   signal cache_flushing     : std_logic_vector(C_VDNUM - 1 downto 0);

   signal sd_lba      : vd_vec_array(C_VDNUM - 1 downto 0)(31 downto 0) := (others => (others => '0'));
   signal sd_blk_cnt  : vd_vec_array(C_VDNUM - 1 downto 0)(5 downto 0)  := (others => (others => '0'));
   signal sd_rd       : vd_std_array(C_VDNUM - 1 downto 0)              := (others => '0');
   signal sd_wr       : vd_std_array(C_VDNUM - 1 downto 0)              := (others => '0');
   signal sd_ack      : vd_std_array(C_VDNUM - 1 downto 0);
   signal sd_buff_addr : std_logic_vector(AW downto 0);
   signal sd_buff_dout : std_logic_vector(DW downto 0);
   signal sd_buff_din  : vd_vec_array(C_VDNUM - 1 downto 0)(DW downto 0) := (others => (others => '0'));
   signal sd_buff_wr   : std_logic;

   signal qnice_addr : std_logic_vector(27 downto 0) := (others => '0');
   signal qnice_din  : std_logic_vector(15 downto 0) := (others => '0');
   signal qnice_dout : std_logic_vector(15 downto 0);
   signal qnice_ce   : std_logic := '0';
   signal qnice_we   : std_logic := '0';

   signal img_mounted_toggle_d : std_logic_vector(C_VDNUM - 1 downto 0) := (others => '0');
   signal toggle_transitions   : natural_array(C_VDNUM - 1 downto 0) := (others => 0);
begin
   clk_qnice <= not clk_qnice after 10 ns;
   clk_core  <= not clk_core after 35 ns;

   i_dut : entity work.vdrives
      generic map (
         VDNUM => C_VDNUM,
         BLKSZ => 2
      )
      port map (
         clk_qnice_i       => clk_qnice,
         clk_core_i        => clk_core,
         reset_core_i      => reset_core,
         img_mounted_o     => img_mounted,
         img_readonly_o    => img_readonly,
         img_size_o        => img_size,
         img_type_o        => img_type,
         drive_mounted_o   => drive_mounted,
         cache_dirty_o     => cache_dirty,
         cache_flushing_o  => cache_flushing,
         sd_lba_i          => sd_lba,
         sd_blk_cnt_i      => sd_blk_cnt,
         sd_rd_i           => sd_rd,
         sd_wr_i           => sd_wr,
         sd_ack_o          => sd_ack,
         sd_buff_addr_o    => sd_buff_addr,
         sd_buff_dout_o    => sd_buff_dout,
         sd_buff_din_i     => sd_buff_din,
         sd_buff_wr_o      => sd_buff_wr,
         qnice_addr_i      => qnice_addr,
         qnice_data_i      => qnice_din,
         qnice_data_o      => qnice_dout,
         qnice_ce_i        => qnice_ce,
         qnice_we_i        => qnice_we,
         img_mounted_toggle_o => img_mounted_toggle
      );

   count_toggle_transitions : process(clk_core)
   begin
      if rising_edge(clk_core) then
         if reset_core = '1' then
            img_mounted_toggle_d <= (others => '0');
            toggle_transitions   <= (others => 0);
         else
            img_mounted_toggle_d <= img_mounted_toggle;
            for i in 0 to C_VDNUM - 1 loop
               if img_mounted_toggle(i) /= img_mounted_toggle_d(i) then
                  toggle_transitions(i) <= toggle_transitions(i) + 1;
               end if;
            end loop;
         end if;
      end if;
   end process count_toggle_transitions;

   stimulus : process
      procedure wait_core_cycles(constant cycles : in positive) is
      begin
         for cycle in 1 to cycles loop
            wait until rising_edge(clk_core);
         end loop;
         wait for 1 ns;
      end procedure wait_core_cycles;

      procedure qnice_write(
         constant address : in std_logic_vector(27 downto 0);
         constant data    : in std_logic_vector(15 downto 0)
      ) is
      begin
         qnice_addr <= address;
         qnice_din  <= data;
         qnice_ce   <= '1';
         qnice_we   <= '1';
         wait until falling_edge(clk_qnice);
         wait for 1 ns;
         qnice_ce <= '0';
         qnice_we <= '0';
      end procedure qnice_write;

      procedure set_image_size(constant size : in std_logic_vector(31 downto 0)) is
      begin
         qnice_write(x"0000002", size(15 downto 0));
         qnice_write(x"0000003", size(31 downto 16));
         wait_core_cycles(4);
      end procedure set_image_size;

      procedure image_event(
         constant drives           : in std_logic_vector(C_VDNUM - 1 downto 0);
         constant size             : in std_logic_vector(31 downto 0);
         constant high_core_cycles : in positive
      ) is
         variable mount_data : std_logic_vector(15 downto 0) := (others => '0');
      begin
         set_image_size(size);
         mount_data(C_VDNUM - 1 downto 0) := drives;
         qnice_write(x"0000000", mount_data);
         wait_core_cycles(high_core_cycles);
         qnice_write(x"0000000", x"0000");
         wait_core_cycles(5);
      end procedure image_event;

      procedure check_state(
         constant expected_mounted : in std_logic_vector(C_VDNUM - 1 downto 0);
         constant expected_toggle  : in std_logic_vector(C_VDNUM - 1 downto 0);
         constant expected_count_0 : in natural;
         constant expected_count_1 : in natural;
         constant test_name        : in string
      ) is
      begin
         assert drive_mounted = expected_mounted
            report test_name & ": mounted state is " & to_hstring(drive_mounted) &
                   ", expected " & to_hstring(expected_mounted)
            severity failure;
         assert img_mounted_toggle = expected_toggle
            report test_name & ": event toggle is " & to_hstring(img_mounted_toggle) &
                   ", expected " & to_hstring(expected_toggle)
            severity failure;
         assert toggle_transitions(0) = expected_count_0
            report test_name & ": drive 0 transition count is " &
                   integer'image(toggle_transitions(0)) & ", expected " &
                   integer'image(expected_count_0)
            severity failure;
         assert toggle_transitions(1) = expected_count_1
            report test_name & ": drive 1 transition count is " &
                   integer'image(toggle_transitions(1)) & ", expected " &
                   integer'image(expected_count_1)
            severity failure;
      end procedure check_state;

      variable mount_data : std_logic_vector(15 downto 0) := (others => '0');
   begin
      -- Allow both clock domains to observe reset.
      wait_core_cycles(6);
      check_state("00", "00", 0, 0, "reset");
      reset_core <= '0';
      wait_core_cycles(5);

      -- A one-cycle strobe must toggle exactly once.
      image_event("01", x"00002000", 1);
      check_state("01", "01", 1, 0, "single-cycle mount");

      -- An even-width strobe catches the naive implementation: toggling on every
      -- high cycle would cancel itself and leave the token unchanged.
      image_event("01", x"00004000", 8);
      check_state("01", "00", 2, 0, "eight-cycle replacement");

      -- Unmounts are image events too and must clear only the selected drive.
      image_event("01", x"00000000", 2);
      check_state("00", "01", 3, 0, "two-cycle unmount");

      -- Exercise both vector bits together with a deliberately long strobe.
      image_event("11", x"00006000", 17);
      check_state("11", "10", 4, 1, "simultaneous long mount");

      -- A single-drive unmount must leave the other drive untouched.
      image_event("10", x"00000000", 6);
      check_state("01", "00", 4, 2, "independent drive unmount");

      -- Reset must establish a known token and edge-detector baseline.
      reset_core <= '1';
      wait_core_cycles(5);
      check_state("00", "00", 0, 0, "second reset");
      reset_core <= '0';
      wait_core_cycles(5);

      -- Rewriting a high mount bit without a low interval is still one edge.
      set_image_size(x"00008000");
      mount_data(0) := '1';
      qnice_write(x"0000000", mount_data);
      wait_core_cycles(3);
      qnice_write(x"0000000", mount_data);
      wait_core_cycles(8);
      qnice_write(x"0000000", x"0000");
      wait_core_cycles(5);
      check_state("01", "01", 1, 0, "repeated high level");

      -- Long idle time must not create another event.
      wait_core_cycles(20);
      check_state("01", "01", 1, 0, "idle stability");

      report "vdrives_test: PASS" severity note;
      finish;
   end process stimulus;
end architecture test;

-- Prove that pre-existing named and positional port maps can omit the new trailing output.
library ieee;
use ieee.std_logic_1164.all;

use work.vdrives_pkg.all;

entity vdrives_legacy_port_test is
end entity vdrives_legacy_port_test;

architecture test of vdrives_legacy_port_test is
   signal sd_lba     : vd_vec_array(0 downto 0)(31 downto 0) := (others => (others => '0'));
   signal sd_blk_cnt : vd_vec_array(0 downto 0)(5 downto 0)  := (others => (others => '0'));
   signal sd_rd      : vd_std_array(0 downto 0)              := (others => '0');
   signal sd_wr      : vd_std_array(0 downto 0)              := (others => '0');
   signal sd_buff_din : vd_vec_array(0 downto 0)(DW downto 0) := (others => (others => '0'));
begin
   i_dut : entity work.vdrives
      generic map (
         VDNUM => 1
      )
      port map (
         clk_qnice_i      => '0',
         clk_core_i       => '0',
         reset_core_i     => '1',
         img_mounted_o    => open,
         img_readonly_o   => open,
         img_size_o       => open,
         img_type_o       => open,
         drive_mounted_o  => open,
         cache_dirty_o    => open,
         cache_flushing_o => open,
         sd_lba_i         => sd_lba,
         sd_blk_cnt_i     => sd_blk_cnt,
         sd_rd_i          => sd_rd,
         sd_wr_i          => sd_wr,
         sd_ack_o         => open,
         sd_buff_addr_o   => open,
         sd_buff_dout_o   => open,
         sd_buff_din_i    => sd_buff_din,
         sd_buff_wr_o     => open,
         qnice_addr_i     => (others => '0'),
         qnice_data_i     => (others => '0'),
         qnice_data_o     => open,
         qnice_ce_i       => '0',
         qnice_we_i       => '0'
      );

   i_dut_positional : entity work.vdrives
      generic map (
         1,
         2
      )
      port map (
         '0',
         '0',
         '1',
         open,
         open,
         open,
         open,
         open,
         open,
         open,
         sd_lba,
         sd_blk_cnt,
         sd_rd,
         sd_wr,
         open,
         open,
         open,
         sd_buff_din,
         open,
         (others => '0'),
         (others => '0'),
         open,
         '0',
         '0'
      );
end architecture test;
