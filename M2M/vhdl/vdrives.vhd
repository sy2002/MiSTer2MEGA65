---------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Virtual Drives
--
-- This module covers the virtual drives part of the MiSTer framework's "hps_io.sv" module. It is
-- an interface to the QNICE firmware which makes sure that we stay compatible to the MiSTer protocol,
-- so this module can be directly wired to the "SD" interface of MiSTer's drives.
--
-- Constraint: Right now, we only support 8-bit data width and 14-bit address width, for the
-- "SD byte level access". That means the "WIDE" mode of "hps_io.sv" is not supported, yet.
--
-- QNICE memory map:
--
-- Window 0x0000:
--    0x0000   img_mounted_o (drive 0 = lowest bit of std_logic_vector)
--    0x0001   img_readonly_o
--    0x0002   img_size_o: low word
--    0x0003   img_size_o: high word
--    0x0004   sd_buff_addr_o
--    0x0005   sd_buff_dout_o
--    0x0006   sd_buff_wr_o
--    0x0007   Number of virtual drives
--    0x0008   Block size for LBA adressing
--
-- Window 0x0001 and onwards: window 1 = drive 0, window 2 = drive 1, ...
--    0x0000   sd_lba_i: low word
--    0x0001   sd_lba_i: high word
--    0x0002   sd_blk_cnt_i + 1 (because the input is too low by 1)
--    0x0003   sd_lba_i in bytes: low word
--    0x0004   sd_lba_i in bytes: high word
--    0x0005   (sd_blk_cnt_i + 1) in bytes 
--    0x0006   sd_rd_i
--    0x0007   sd_wr_i
--    0x0008   sd_ack_o
--    0x0009   sd_buff_din_i
--
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package vdrives_pkg is
   type vd_vec_array is array(natural range <>) of std_logic_vector;
   type vd_std_array is array(natural range <>) of std_logic;
   
   constant AW: natural := 13;   -- 14-bit
   constant DW: natural := 7;    -- 8-bit
end package;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.vdrives_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity vdrives is
generic (
   VDNUM             : natural := 1;      -- amount of virtual drives, MiSTer supports a maximum of 10
   BLKSZ             : natural := 2       -- block size for LBA adressing: 0..7: 0 = 128, 1 = 256, 2 = 512(default), .. 7 = 16384
);
port (
   clk_qnice_i       : in std_logic;
   clk_core_i        : in std_logic;
   reset_core_i      : in std_logic;
   
   -- MiSTer's "SD config" interface, which runs in the core's clock domain
   img_mounted_o     : out std_logic_vector(VDNUM - 1 downto 0);  -- signaling that new image has been mounted
   img_readonly_o    : out std_logic;                             -- mounted as read only; valid only for active bit in img_mounted
   img_size_o        : out std_logic_vector(31 downto 0);         -- size of image in bytes; valid only for active bit in img_mounted 
   
   -- MiSTer's "SD block level access" interface, which runs in QNICE's clock domain
   -- using dedicated signal on Mister's side such as "clk_sys"
   sd_lba_i          : in vd_vec_array(VDNUM - 1 downto 0)(31 downto 0);
   sd_blk_cnt_i      : in vd_vec_array(VDNUM - 1 downto 0)(5 downto 0);  -- number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!
   sd_rd_i           : in vd_std_array(VDNUM - 1 downto 0);
   sd_wr_i           : in vd_std_array(VDNUM - 1 downto 0);
   sd_ack_o          : out vd_std_array(VDNUM - 1 downto 0); 

   -- MiSTer's "SD byte level access": the MiSTer components use a combination of the drive-specific sd_ack and the sd_buff_wr
   -- to determine, which RAM buffer actually needs to be written to (using the clk_qnice_i clock domain)
   sd_buff_addr_o    : out std_logic_vector(AW downto 0);
   sd_buff_dout_o    : out std_logic_vector(DW downto 0);
   sd_buff_din_i     : in vd_vec_array(VDNUM - 1 downto 0)(DW downto 0);
   sd_buff_wr_o      : out std_logic;
   
   -- QNICE interface (MMIO, 4k-segmented)
   -- qnice_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
   qnice_addr_i      : in std_logic_vector(27 downto 0);
   qnice_data_i      : in std_logic_vector(15 downto 0);
   qnice_data_o      : out std_logic_vector(15 downto 0);
   qnice_ce_i        : in std_logic;
   qnice_we_i        : in std_logic   
);
end vdrives;

architecture beh of vdrives is

signal reset_qnice      : std_logic;

-- QNICE registers
signal img_mounted      : std_logic_vector(VDNUM - 1 downto 0);
signal img_readonly     : std_logic;
signal img_size         : std_logic_vector(31 downto 0);

signal sd_rd            : vd_std_array(VDNUM - 1 downto 0);
signal sd_rd_trig_del   : vd_std_array(VDNUM - 1 downto 0);
signal sd_lba           : vd_vec_array(VDNUM - 1 downto 0)(31 downto 0);
signal sd_blk_cnt       : vd_vec_array(VDNUM - 1 downto 0)(5 downto 0);
signal sd_lba_bytes     : vd_vec_array(VDNUM - 1 downto 0)(63 downto 0);
signal sd_blk_cnt_bytes : vd_vec_array(VDNUM - 1 downto 0)(31 downto 0);

signal sd_buff_addr     : std_logic_vector(AW downto 0);
signal sd_buff_dout     : std_logic_vector(DW downto 0);
signal sd_buff_din      : vd_vec_array(VDNUM - 1 downto 0)(DW downto 0);
signal sd_buff_wr       : std_logic; 

-- core clock domain
signal img_mounted_out  : std_logic_vector(VDNUM - 1 downto 0);
signal img_readonly_out : std_logic;
signal img_size_out     : std_logic_vector(31 downto 0);

attribute MARK_DEBUG : string;
attribute MARK_DEBUG of sd_rd : signal is "TRUE";

begin

   -- core clock domain
   img_mounted_o     <= img_mounted_out;
   img_readonly_o    <= img_readonly_out;
   img_size_o        <= img_size_out;
   
   -- QNICE clock domain
   sd_buff_addr_o    <= sd_buff_addr;
   sd_buff_dout_o    <= sd_buff_dout;
   sd_buff_wr_o      <= sd_buff_wr;
   
   -- calculate lba and block count in bytes by shifting to the left
   g_bytecalc : for i in 0 to VDNUM - 1 generate
      sd_lba_bytes(i)((31 + 7 + BLKSZ) downto (7 + BLKSZ))     <= sd_lba(0);
      sd_lba_bytes(i)((7 + BLKSZ - 1) downto 0)                <= (others => '0');
      sd_blk_cnt_bytes(i)((5 + 7 + BLKSZ) downto (7 + BLKSZ))  <= sd_blk_cnt(0);
      sd_blk_cnt_bytes(i)((7 + BLKSZ - 1) downto 0)            <= (others => '0');
   end generate g_bytecalc;

   i_cdc_main2qnice: xpm_cdc_array_single
      generic map (
         WIDTH => 1
      )
      port map (
         src_clk                       => clk_core_i,
         src_in(0)                     => reset_core_i,
         dest_clk                      => clk_qnice_i,
         dest_out(0)                   => reset_qnice
      );
      
   i_cdc_q2m_img_mounted: xpm_cdc_array_single
      generic map (
         WIDTH => VDNUM
      )
      port map (
         src_clk                       => clk_qnice_i,
         src_in(VDNUM - 1 downto 0)    => img_mounted(VDNUM - 1 downto 0),
         dest_clk                      => clk_core_i,
         dest_out(VDNUM - 1 downto 0)  => img_mounted_out(VDNUM - 1 downto 0) 
      );
      
   i_cdc_qnice2main: xpm_cdc_array_single
      generic map (
         WIDTH => 33
      )
      port map (
         src_clk                       => clk_qnice_i,
         src_in(0)                     => img_readonly,
         src_in(32 downto 1)           => img_size,
         dest_clk                      => clk_core_i,
         dest_out(0)                   => img_readonly_out,
         dest_out(32 downto 1)         => img_size_out
      );
      
   write_qnice_registers : process(clk_qnice_i)
   begin
      if falling_edge(clk_qnice_i) then
         if reset_qnice = '1' then
            img_mounted <= (others => '0');
            img_readonly <= '0';
            img_size <= (others => '0');
            sd_buff_addr <= (others => '0');
            sd_buff_dout <= (others => '0');
            sd_buff_wr <= '0';
            sd_rd <= (others => '0');
            sd_rd_trig_del <= (others => '0');
            sd_lba <= (others => (others => '0'));
            sd_blk_cnt <= (others => (others => '0'));
            
         -- reading sd_rd is triggering a reset of the sd_rd flag
         elsif qnice_ce_i = '1' and qnice_we_i = '0' and qnice_addr_i(27 downto 12) > x"0000" and qnice_addr_i(11 downto 0) = x"006" then
            for i in 0 to VDNUM - 1 loop
               if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                  sd_rd_trig_del(i) <= '1';
               end if;
            end loop;         
         else
            -- reset sd_rd after read
            for i in 0 to VDNUM - 1 loop
               if sd_rd_trig_del(i) = '1' then
                  sd_rd_trig_del(i) <= '0';
                  sd_rd(i) <= '0';
               end if;
            end loop;
         
            -- Address window 0x0000: QNICE registers written by QNICE         
            if qnice_we_i = '1' then            
               if qnice_addr_i(27 downto 4) = x"000000" then
                  case qnice_addr_i(3 downto 0) is
                     -- img_mounted_o (drive 0 = lowest bit of std_logic_vector)
                     when x"0" =>
                        img_mounted(VDNUM - 1 downto 0) <= qnice_data_i(VDNUM - 1 downto 0);
                        
                     -- img_readonly_o
                     when x"1" =>
                        img_readonly <= qnice_data_i(0);
                        
                     -- img_size_o: low word
                     when x"2" =>
                        img_size(15 downto 0) <= qnice_data_i;

                     -- img_size_o: high word
                     when x"3" =>
                        img_size(31 downto 16) <= qnice_data_i;
                        
                     -- sd_buff_addr_o
                     when x"4" =>
                        sd_buff_addr(AW downto 0) <= qnice_data_i(AW downto 0);
                                     
                     -- sd_buff_dout_o
                     when x"5" =>
                        sd_buff_dout(DW downto 0) <= qnice_data_i(DW downto 0);
                        
                     -- sd_buff_wr_o
                     when x"6" =>                        
                        sd_buff_wr <= qnice_data_i(0);
                        
                     -- 7 and 8 are read-only: Number of virtual drives and Block size for LBA adressing
                     when x"7" =>
                     when x"8" =>
                        null;
                                               
                     when others =>
                        null;
                  end case;                  
               end if;
            end if;
            
            -- QNICE registers written by IEC
            
            -- sd_rd: latch sd_rd until read by QNICE and use sd_rd as a trigger to also latch sd_lba sd_blk_cnt
            for i in 0 to VDNUM - 1 loop
               if sd_rd_i(i) = '1' then
                  sd_rd(i)       <= '1';
                  sd_lba(i)      <= sd_lba_i(i);
                  -- sd_blk_cnt oddity: MiSTer delivers value that is too small by 1, so add 1
                  sd_blk_cnt(i)  <= std_logic_vector(to_unsigned(to_integer(unsigned(sd_blk_cnt_i(i))) + 1, 6)); 
               end if;
            end loop;            
          
         end if;
      end if;
   end process;
   
   read_qnice_registers : process(clk_qnice_i)
   begin
      qnice_data_o <= x"0000";
      -- Address window 0x0000 and address < 0xF            
      if qnice_addr_i(27 downto 4) = x"000000" then
         case qnice_addr_i(3 downto 0) is
            -- img_mounted_o (drive 0 = lowest bit of std_logic_vector)         
            when x"0" =>
               qnice_data_o(VDNUM - 1 downto 0) <= img_mounted(VDNUM - 1 downto 0);

            -- img_readonly_o
            when x"1" =>
               qnice_data_o(0) <= img_readonly;
               
            -- img_size_o: low word
            when x"2" =>
               qnice_data_o <= img_size(15 downto 0);

            -- img_size_o: high word
            when x"3" =>
               qnice_data_o <= img_size(31 downto 16);

            -- sd_buff_addr_o
            when x"4" =>
               qnice_data_o(AW downto 0) <= sd_buff_addr(AW downto 0);
                            
            -- sd_buff_dout_o
            when x"5" =>
               qnice_data_o(DW downto 0) <= sd_buff_dout(DW downto 0);
               
            -- sd_buff_wr_o
            when x"6" =>                        
               qnice_data_o(0) <= sd_buff_wr;
               
            -- Number of virtual drives
            when x"7" =>
               qnice_data_o <= std_logic_vector(to_unsigned(VDNUM, 16));

            -- Block size for LBA adressing
            when x"8" =>
               qnice_data_o(7 + BLKSZ) <= '1';           
            when others =>
               null;
         end case;
         
      -- Window 0x0001 and onwards: window 1 = drive 0, window 2 = drive 1, ...         
      elsif qnice_addr_i(27 downto 12) > x"0000" and qnice_addr_i(11 downto 4) = x"00" then
         case qnice_addr_i(3 downto 0) is
            -- sd_lba_i: low word
            when x"0" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_lba(i)(15 downto 0);
                  end if;                  
               end loop;

            -- sd_lba_i: high word
            when x"1" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_lba(i)(31 downto 16);
                  end if;                  
               end loop;
               
            -- sd_blk_cnt_i + 1 (because the input is too low by 1 we increase it during latching)
            when x"2" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(5 downto 0) <= sd_blk_cnt(i);
                  end if;                  
               end loop;

            -- sd_lba_i in bytes: low word            
            when x"3" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_lba_bytes(i)(15 downto 0);
                  end if;                  
               end loop;               

            -- sd_lba_i in bytes: high word            
            when x"4" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_lba_bytes(i)(31 downto 16);
                  end if;                  
               end loop;
                              
            -- (sd_blk_cnt_i + 1) in bytes
            when x"5" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_blk_cnt_bytes(i)(15 downto 0);
                  end if;                  
               end loop;
         
            -- sd_rd_i            
            when x"6" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(0) <= sd_rd(i);
                  end if;
               end loop;
               
            when others =>
               null;
         end case;
      end if;   
   end process;

end beh;
