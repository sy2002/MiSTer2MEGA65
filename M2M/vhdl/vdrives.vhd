-------------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Virtual Drives
--
-- This module covers the virtual drives part of the MiSTer framework's "hps_io.sv" module. It is
-- an interface to the QNICE firmware which makes sure that we stay compatible to the MiSTer protocol,
-- so this module can be directly wired to the "SD" interface of MiSTer's drives. It is also
-- multi-drive compatible: Just set the generic VDNUM to the number of drives.
--
-- Constraint: Right now, we only support 8-bit data width and 14-bit address width, for the
-- "SD byte level access". That means the "WIDE" mode of "hps_io.sv" is not supported, yet.
--
-- QNICE memory map:
--
-- Window 0x0000: Control and data registers
--    0x0000   img_mounted_o (drive 0 = lowest bit of std_logic_vector)
--    0x0001   img_readonly_o
--    0x0002   img_size_o: low word
--    0x0003   img_size_o: high word
--    0x0004   img_type_o: type of disk image (if the core supports multiple disk image types), 0 = default
--    0x0005   sd_buff_addr_o
--    0x0006   sd_buff_dout_o
--    0x0007   sd_buff_wr_o
--    0x0008   Number of virtual drives
--    0x0009   Block size for LBA adressing
--    0x000A   drive_mounted_o (in contrast to the strobed img_mounted_o, see below)
--
-- Window 0x0001 and onwards: window 1 = drive 0, window 2 = drive 1, ...
--    0x0000   sd_lba_i: low word
--    0x0001   sd_lba_i: high word
--    0x0002   sd_blk_cnt_i + 1 (because the input is too low by 1)
--    0x0003   sd_lba_i in bytes: low word
--    0x0004   sd_lba_i in bytes: high word
--    0x0005   (sd_blk_cnt_i + 1) in bytes 
--    0x0006   sd_lba_i in 4k window logic: number of 4k window
--    0x0007   sd_lba_i in 4k window logic: offset within the window
--    0x0008   sd_rd_i
--    0x0009   sd_wr_i
--    0x000A   sd_ack_o
--    0x000B   sd_buff_din_i
--
-- MiSTer's "SD" interface protocol (reverse-engineered, so accuracy may be only 95%):
--
-- This protocol is implemented in the MiSTerMEGA65 firmware. In standard use cases, you do not
-- need to worry about it. Nevertheless, we are documenting it here for our own purposes and
-- "just in case". Currently, we only support reading.
--
-- 1. Reset: There are several options in the original MiSTer how and when a drive should be made
--    available (i.e. not being reset). Implement your choice. Use drive_mounted_o as needed, because
--    in contrast to img_mounted_o (which is only strobed), drive_mounted_o is a latched signal.
--
-- 2. Mount a drive: MiSTer's logic reacts on the rising edge of the img_mounted_o bits. This is why it
--    is not offering one img_readonly_o, img_size_o and img_type_o per drive but only one for all drives.
--    Instead, values are processed on the rising edge of the mount bit. This means: Do not mount multiple
--    drives simultaneously, unless the img_readonly_o, img_size_o and img_type_o values are the same
--    for these drives. Make sure that you output these values before you actually trigger the rising
--    edge of the mount bit. Also make sure that you only strobe the signal and do not keep it up all the time.
--
-- 3. rd_i should be low while no drive is mounted.
--
-- 4. As soon the core's drive needs data, it pulls rd_i to high. The following routine should be executed
--    with as high performance as possible for example by buffering the mounted drive in RAM instead of
--    reading it in realtime from a data source (e.g. SD card).
--
-- 5. When rd_i=1, you stay in the same QNICE window 0x0001 + x (x=0 for drive 0, x=n for drive n)
--    as the one where you detected the rd_i=1. The data, that the core requested sits at the given LBA
--    and is BLK_CNT blocks long. The LBA size can be read in the Control and Data register. There are
--    performance optimizations available: You can access the address and requested data amount in bytes and
--    also in 4k windows plus offset which fits nicely in QNICE's MiSTer2MEGA architecture.
--
-- 6. Signal acknowledge using sd_ack_o and leave the signal high during the data transfer as
--    MiSTer uses the sd_ack_o (per drive) in conjunction with the sd_buff_wr_o as write enable.
--
-- 7. Use window 0x0000 (Control and data registers) to pump the data to the core's data buffer.
--    Set sd_buff_addr_o and sd_buff_dout_o and then strobe sd_buff_wr_o and then repeat.
--
-- 8. Lower sd_ack_o when done and go back to step 4 (i.e. wait until rd_i is high).
--
-- The difference between "mounting a drive" and "mounting an image": If a drive is mounted, it is
-- actually "switched on" and if it is unmounted, it is "switched off" (will be kept in reset state).
-- "Mounting an image" is more like inserting a disk into a drive. 
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
-------------------------------------------------------------------------------------------------------------

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

   ---------------------------------------------------------------------------------------
   -- Core clock domain
   ---------------------------------------------------------------------------------------

   -- MiSTer's "SD config" interface:
   -- While the appropriate bit in img_mounted_o is strobed, the other values are latched by MiSTer
   img_mounted_o     : out std_logic_vector(VDNUM - 1 downto 0);  -- signaling that new image has been mounted
   img_readonly_o    : out std_logic;                             -- mounted as read only; valid only for active bit in img_mounted
   img_size_o        : out std_logic_vector(31 downto 0);         -- size of image in bytes; valid only for active bit in img_mounted
   img_type_o        : out std_logic_vector(1 downto 0);

   -- While "img_mounted_o" needs to be strobed, "drive_mounted" latches the strobe,
   -- so that it can be used for resetting (and unresetting) the drive.
   drive_mounted_o   : out std_logic_vector(VDNUM - 1 downto 0);
   
   ---------------------------------------------------------------------------------------
   -- QNICE clock domain
   ---------------------------------------------------------------------------------------
         
   -- MiSTer's "SD block level access" interface, which runs in QNICE's clock domain using a dedicated signal
   -- on Mister's side such as "clk_sys" (<== oddly deep down in MiSTer code "clk_sys" is not the core, but the "sd write", i.e. QNICE)
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

-- QNICE registers for output signals
signal img_mounted      : std_logic_vector(VDNUM - 1 downto 0);
signal img_readonly     : std_logic;
signal img_size         : std_logic_vector(31 downto 0);
signal img_type         : std_logic_vector(1 downto 0);

signal sd_ack           : vd_std_array(VDNUM - 1 downto 0);

signal sd_buff_addr     : std_logic_vector(AW downto 0);
signal sd_buff_dout     : std_logic_vector(DW downto 0);
signal sd_buff_wr       : std_logic;

-- combinatoric (real-time) value: correction of sd_blk_cnt_i, which is too low by 1 by default
signal sd_blk_cnt_i_corrected : vd_vec_array(VDNUM - 1 downto 0)(5 downto 0);

-- Signals (not registers) to improve QNICE firmware performance because the calculations
-- are done in hardware instead of in software.
signal sd_lba_bytes     : vd_vec_array(VDNUM - 1 downto 0)(63 downto 0);
signal sd_blk_cnt_bytes : vd_vec_array(VDNUM - 1 downto 0)(31 downto 0);
signal sd_lba_4k_win    : vd_vec_array(VDNUM - 1 downto 0)(15 downto 0);
signal sd_lba_4k_offs   : vd_vec_array(VDNUM - 1 downto 0)(11 downto 0); 

-- CDC signals for QNICE to core clock domain
signal img_mounted_out  : std_logic_vector(VDNUM - 1 downto 0);
signal img_readonly_out : std_logic;
signal img_size_out     : std_logic_vector(31 downto 0);
signal img_type_out     : std_logic_vector(1 downto 0);

-- Drive mounted register in core's ane QNICE's clock domain
signal drive_mounted_reg         : std_logic_vector(VDNUM - 1 downto 0);
signal drive_mounted_reg_qnice   : std_logic_vector(VDNUM - 1 downto 0);

begin
   -- Core clock domain: Output registers
   img_mounted_o     <= img_mounted_out;
   img_readonly_o    <= img_readonly_out;
   img_size_o        <= img_size_out;
   img_type_o        <= img_type_out;
   drive_mounted_o   <= drive_mounted_reg;

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
         WIDTH => 35
      )
      port map (
         src_clk                       => clk_qnice_i,
         src_in(0)                     => img_readonly,
         src_in(2 downto 1)            => img_type,
         src_in(34 downto 3)           => img_size,
         dest_clk                      => clk_core_i,
         dest_out(0)                   => img_readonly_out,
         dest_out(2 downto 1)          => img_type_out,
         dest_out(34 downto 3)         => img_size_out
      );

   -- QNICE clock domain: Output registers
   sd_buff_addr_o    <= sd_buff_addr;
   sd_buff_dout_o    <= sd_buff_dout;
   sd_buff_wr_o      <= sd_buff_wr;
   sd_ack_o          <= sd_ack;

   i_cdc_main2qnice: xpm_cdc_array_single
      generic map (
         WIDTH => 1 + VDNUM
      )
      port map (
         src_clk                             => clk_core_i,
         src_in(0)                           => reset_core_i,
         src_in((1 + VDNUM - 1) downto 1)    => drive_mounted_reg,
         dest_clk                            => clk_qnice_i,
         dest_out(0)                         => reset_qnice,
         dest_out((1 + VDNUM - 1) downto 1)  => drive_mounted_reg_qnice
      );

   -- speed up the QNICE firmware by doing certain calculations in hardware instead of software
   g_bytecalc : for i in 0 to VDNUM - 1 generate
      -- MiSTer's value is too low by 1 by default, so we correct it; here is the original comment from "hps_io.sv"
      -- "number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!"
      sd_blk_cnt_i_corrected(i) <= std_logic_vector(to_unsigned((to_integer(unsigned(sd_blk_cnt_i(i))) + 1), 6));

      -- calculate lba and block count in bytes by shifting to the left
      sd_lba_bytes(i)((31 + 7 + BLKSZ) downto (7 + BLKSZ))     <= sd_lba_i(i);
      sd_lba_bytes(i)((7 + BLKSZ - 1) downto 0)                <= (others => '0');
      sd_blk_cnt_bytes(i)((5 + 7 + BLKSZ) downto (7 + BLKSZ))  <= sd_blk_cnt_i_corrected(i);
      sd_blk_cnt_bytes(i)((7 + BLKSZ - 1) downto 0)            <= (others => '0');
      
      -- calculate the QNICE RAMROM logic 4k window and the offset within the window by selecting the right bits
      sd_lba_4k_win(i)  <= sd_lba_bytes(i)(27 downto 12);      
      sd_lba_4k_offs(i) <= sd_lba_bytes(i)(11 downto 0);      
   end generate g_bytecalc;

   -- the protocol demands for a strobed img_mounted signal, but we need a constant signal
   -- to control the drive's reset line
   handle_drive_mounted : process(clk_core_i)
   begin
      if rising_edge(clk_core_i) then      
         for i in 0 to VDNUM - 1 loop
            if reset_core_i = '1' then
               drive_mounted_reg(i) <= '0';
            elsif img_mounted_out(i) = '1' then
               -- to unmount a drive: strobe img_mounted while having the image size set to zero
               if img_size_out = x"00000000" then
                  drive_mounted_reg(i) <= '0';
                  
               -- to mount a drive: strobe img_mounted while having a nonzero image size
               else
                  drive_mounted_reg(i) <= '1';
               end if; 
            end if;            
         end loop;
      end if;
   end process;
            
   write_qnice_registers : process(clk_qnice_i)
   begin
      if falling_edge(clk_qnice_i) then
         if reset_qnice = '1' then
            img_mounted    <= (others => '0');
            img_readonly   <= '0';
            img_size       <= (others => '0');
            img_type       <= (others => '0');
            sd_buff_addr   <= (others => '0');
            sd_buff_dout   <= (others => '0');
            sd_buff_wr     <= '0';
            sd_ack         <= (others => '0');            
         else         
            -- QNICE registers written by QNICE
            if qnice_we_i = '1' then
               -- Window 0x0000: Control and data registers              
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
                        
                     -- img_type_o
                     when x"4" =>
                        img_type <= qnice_data_i(1 downto 0);
                        
                     -- sd_buff_addr_o
                     when x"5" =>
                        sd_buff_addr(AW downto 0) <= qnice_data_i(AW downto 0);
                                     
                     -- sd_buff_dout_o
                     when x"6" =>
                        sd_buff_dout(DW downto 0) <= qnice_data_i(DW downto 0);
                        
                     -- sd_buff_wr_o
                     when x"7" =>                        
                        sd_buff_wr <= qnice_data_i(0);
                        
                     -- 7 and 8 are read-only: Number of virtual drives and Block size for LBA adressing
                     when x"8" =>
                     when x"9" =>
                        null;
                                               
                     when others =>
                        null;
                  end case;
                                    
               -- Window 0x0001 and onwards: window 1 = drive 0, window 2 = drive 1, ...         
               elsif qnice_addr_i(27 downto 12) > x"0000" and qnice_addr_i(11 downto 4) = x"00" then
                  -- sd_ack_o
                  if qnice_addr_i(3 downto 0) = x"A" then
                     for i in 0 to VDNUM - 1 loop
                        if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                           sd_ack(i) <= qnice_data_i(0);
                        end if;                  
                     end loop;                                 
                  end if;
               end if;
            end if;          
         end if;
      end if;
   end process;
   
   read_qnice_registers : process(all)
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
               
            -- img_type_o
            when x"4" =>
               qnice_data_o(1 downto 0) <= img_type;

            -- sd_buff_addr_o
            when x"5" =>
               qnice_data_o(AW downto 0) <= sd_buff_addr(AW downto 0);
                            
            -- sd_buff_dout_o
            when x"6" =>
               qnice_data_o(DW downto 0) <= sd_buff_dout(DW downto 0);
               
            -- sd_buff_wr_o
            when x"7" =>                        
               qnice_data_o(0) <= sd_buff_wr;
               
            -- Number of virtual drives
            when x"8" =>
               qnice_data_o <= std_logic_vector(to_unsigned(VDNUM, 16));

            -- Block size for LBA adressing
            when x"9" =>
               qnice_data_o(7 + BLKSZ) <= '1';    
               
            when x"A" =>
               qnice_data_o(VDNUM - 1 downto 0) <= drive_mounted_reg_qnice;
                      
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
                     qnice_data_o <= sd_lba_i(i)(15 downto 0);
                  end if;                  
               end loop;

            -- sd_lba_i: high word
            when x"1" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_lba_i(i)(31 downto 16);
                  end if;                  
               end loop;
               
            -- sd_blk_cnt_i + 1 (because the input is too low by 1 we increase it)
            when x"2" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(5 downto 0) <= sd_blk_cnt_i_corrected(i);
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
            
            -- sd_lba_i in 4k window logic: number of 4k window
            when x"6" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o <= sd_lba_4k_win(i);
                  end if;                  
               end loop;
               
            -- sd_lba_i in 4k window logic: offset within the window
            when x"7" =>   
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(11 downto 0) <= sd_lba_4k_offs(i);
                  end if;                  
               end loop;
               
            -- sd_rd_i            
            when x"8" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(0) <= sd_rd_i(i);
                  end if;
               end loop;
               
            -- sd_wr_i
            when x"9" =>
               null;
            
            -- sd_ack_o
            when x"A" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(0) <= sd_ack(i);
                  end if;                  
               end loop;                                 
               
            -- sd_buff_din_i
            when x"B" =>
               for i in 0 to VDNUM - 1 loop
                  if to_integer(unsigned(qnice_addr_i(19 downto 12))) = (i + 1) then
                     qnice_data_o(DW downto 0) <= sd_buff_din_i(i);
                  end if;                  
               end loop;                                        
                        
            when others =>
               null;
         end case;
      end if;   
   end process;

end beh;
