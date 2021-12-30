----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- QNICE Co-Processor for On-Screen-Menu, ROM loading, file I/O & core control
-- (refer to M2M/rom/sysdef.asm for a memory map and more details)
--
-- QNICE reads/writes registers and memory at the falling edge of the clock
--
-- QNICE Co-Processor is based on QNICE-FPGA done by The QNICE Development Team
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.env1_globals.all;
use work.qnice_tools.all;

entity QNICE is
generic (
   G_FIRMWARE        : string;                           -- .rom file that baked into the core as firmware
   G_VGA_DX          : natural;                          -- output screen width in pixel
   G_VGA_DY          : natural;                          -- ditto height
   G_FONT_DX         : natural;                          -- character width in pixel
   G_FONT_DY         : natural;                          -- ditto height         
   
   -- x|y start positions and dx|dy dimensions of the two standard windows of the Shell: main window and options menu
   G_SHELL_M_X       : integer;
   G_SHELL_M_Y       : integer;
   G_SHELL_M_DX      : integer;
   G_SHELL_M_DY      : integer;
   G_SHELL_O_X       : integer;
   G_SHELL_O_Y       : integer;
   G_SHELL_O_DX      : integer;
   G_SHELL_O_DY      : integer   
);
port (
   -- QNICE MEGA65 hardware interface
   clk50_i              : in std_logic;            -- 50 MHz clock
   reset_n_i            : in std_logic;            -- reset the whole QNICE SOC

   uart_rxd_i           : in std_logic;            -- receive data, 115.200 baud, 8-N-1, rxd, txd only; rts/cts are not available
   uart_txd_o           : out std_logic;           -- send data, ditto

   sd_reset_o           : out std_logic;           -- SD card interface via SPI
   sd_clk_o             : out std_logic;
   sd_mosi_o            : out std_logic;
   sd_miso_i            : in std_logic;

   -- QNICE public registers
   csr_reset_o          : out std_logic;           -- reset the MiSTer core
   csr_pause_o          : out std_logic;           -- pause the MiSTer core
   csr_osm_o            : out std_logic;           -- overlay the On-Screen-Menu over the MiSTer core's output
   csr_keyboard_o       : out std_logic;           -- couple the MEGA65 keyboard with the MiSTer core
   csr_joy1_o           : out std_logic;           -- ditto joystick port #1
   csr_joy2_o           : out std_logic;           -- ditto joystick port #2
   osm_xy_o             : out std_logic_vector(15 downto 0);   -- On-Screen-Menu x|y (in chars): x=hi-byte y=lo-byte 
   osm_dxdy_o           : out std_logic_vector(15 downto 0);   -- On-Screen-Menu dx|dy (in chars): dx=hi-byte dy=lo-byte
   
   -- Keyboard input for the firmware and Shell (see sysdef.asm)
   keys_n_i             : in std_logic_vector(15 downto 0);
   
   -- 256-bit General purpose control flags
   -- "d" = directly controled by the firmware
   -- "m" = indirectly controled by the menu system
   control_d_o          : out std_logic_vector(255 downto 0);
   control_m_o          : out std_logic_vector(255 downto 0);

   -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
   -- ramrom_dev_o: 0 = VRAM data, 1 = VRAM attributes, > 256 = free to be used for any "RAM like" device
   -- ramrom_addr_o is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
   ramrom_dev_o         : out std_logic_vector(15 downto 0);
   ramrom_addr_o        : out std_logic_vector(27 downto 0);
   ramrom_data_o        : out std_logic_vector(15 downto 0);
   ramrom_data_i        : in std_logic_vector(15 downto 0);
   ramrom_ce_o          : out std_logic;
   ramrom_we_o          : out std_logic
); 
end QNICE;

architecture beh of QNICE is

constant CHARS_DX                : natural := G_VGA_DX / G_FONT_DX;
constant CHARS_DY                : natural := G_VGA_DY / G_FONT_DY;

-- QNICE standard CPU control signals
signal cpu_addr                  : std_logic_vector(15 downto 0);
signal cpu_data_in               : std_logic_vector(15 downto 0);
signal cpu_data_out              : std_logic_vector(15 downto 0);
signal cpu_data_dir              : std_logic;
signal cpu_data_valid            : std_logic;
signal cpu_wait_for_data         : std_logic;
signal cpu_halt                  : std_logic;

-- QNICE standard reset control
signal reset_ctl                 : std_logic;
signal reset_pre_pore            : std_logic;
signal reset_post_pore           : std_logic;

-- QNICE standard MMIO signals
signal rom_en                    : std_logic;
signal rom_en_maybe              : std_logic; -- output of standard MMIO module without taking care of MiSTer2MEGA65 specific MMIO
signal rom_data_out              : std_logic_vector(15 downto 0);
signal ram_en                    : std_logic;
signal ram_busy                  : std_logic;
signal ram_data_out              : std_logic_vector(15 downto 0);
signal switch_data_out           : std_logic_vector(15 downto 0);
signal uart_en                   : std_logic;
signal uart_we                   : std_logic;
signal uart_reg                  : std_logic_vector(1 downto 0);
signal uart_cpu_ws               : std_logic;
signal uart_data_out             : std_logic_vector(15 downto 0);
signal eae_en                    : std_logic;
signal eae_we                    : std_logic;
signal eae_reg                   : std_logic_vector(2 downto 0);
signal eae_data_out              : std_logic_vector(15 downto 0);
signal sd_en                     : std_logic;
signal sd_we                     : std_logic;
signal sd_reg                    : std_logic_vector(2 downto 0);
signal sd_data_out               : std_logic_vector(15 downto 0);

-- M2M specific QNICE MMIO signals
signal ramrom_en                 : std_logic;                        -- $7000
signal ramrom_we                 : std_logic;
signal ramrom_data_out           : std_logic_vector(15 downto 0);
signal csr_en                    : std_logic;                        -- $FFE0
signal csr_we                    : std_logic;
signal csr_data_out              : std_logic_vector(15 downto 0);
signal osm_xy_en                 : std_logic;                        -- $FFE1
signal osm_xy_we                 : std_logic;
signal osm_xy_data_out           : std_logic_vector(15 downto 0);
signal osm_dxdy_en               : std_logic;                        -- $FFE2
signal osm_dxdy_we               : std_logic;
signal osm_dxdy_data_out         : std_logic_vector(15 downto 0);
signal shell_m_xy_en             : std_logic;                        -- $FFE3
signal shell_m_xy_data_out       : std_logic_vector(15 downto 0);
signal shell_m_dxdy_en           : std_logic;                        -- $FFE4
signal shell_m_dxdy_data_out     : std_logic_vector(15 downto 0);
signal shell_o_xy_en             : std_logic;                        -- $FFE5
signal shell_o_xy_data_out       : std_logic_vector(15 downto 0);
signal shell_o_dxdy_en           : std_logic;                        -- $FFE6
signal shell_o_dxdy_data_out     : std_logic_vector(15 downto 0);
signal sys_dxdy_en               : std_logic;                        -- $FFE7
signal sys_dxdy_data_out         : std_logic_vector(15 downto 0);
signal keys_en                   : std_logic;                        -- $FFE8
signal keys_data_out             : std_logic_vector(15 downto 0);
signal cfd_addr_en               : std_logic;                        -- $FFF0
signal cfd_addr_we               : std_logic;
signal cfd_addr_data_out         : std_logic_vector(15 downto 0);
signal cfd_data_en               : std_logic;                        -- $FFF1
signal cfd_data_we               : std_logic;
signal cfd_data_data_out         : std_logic_vector(15 downto 0);
signal cfm_addr_en               : std_logic;                        -- $FFF2
signal cfm_addr_we               : std_logic;
signal cfm_addr_data_out         : std_logic_vector(15 downto 0);
signal cfm_data_en               : std_logic;                        -- $FFF3
signal cfm_data_we               : std_logic;
signal cfm_data_data_out         : std_logic_vector(15 downto 0);
signal ramrom_dev_en             : std_logic;                        -- $FFF4
signal ramrom_dev_we             : std_logic;
signal ramrom_dev_data_out       : std_logic_vector(15 downto 0);
signal ramrom_4kwin_en           : std_logic;                        -- $FFF5
signal ramrom_4kwin_we           : std_logic;
signal ramrom_4kwin_data_out     : std_logic_vector(15 downto 0);

-- Internal registers
signal reg_csr                   : std_logic_vector(15 downto 0);
signal reg_cfd_addr              : natural range 0 to 15;
signal reg_cfm_addr              : natural range 0 to 15;
signal reg_ramrom_4kwin          : natural range 0 to 65535;

begin
   -- emulate the QNICE toggle switches as described in QNICE-FPGA's doc/README.md
   -- all zero: STDIN = STDOUT = UART
   switch_data_out <= (others => '0');

   -- Merge data outputs from all devices into a single data input to the CPU.
   -- This requires that all devices output 0's when not selected.
   cpu_data_in <= rom_data_out               or
                  ram_data_out               or
                  switch_data_out            or
                  uart_data_out              or
                  eae_data_out               or
                  sd_data_out                or
                  ramrom_data_out            or
                  csr_data_out               or
                  osm_xy_data_out            or
                  osm_dxdy_data_out          or                  
                  shell_m_xy_data_out        or
                  shell_m_dxdy_data_out      or
                  shell_o_xy_data_out        or
                  shell_o_dxdy_data_out      or
                  sys_dxdy_data_out          or
                  keys_data_out              or                 
                  cfd_addr_data_out          or
                  cfd_data_data_out          or
                  cfm_addr_data_out          or
                  cfm_data_data_out          or
                  ramrom_dev_data_out        or
                  ramrom_4kwin_data_out;
                                                                                          
   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1') else '0';                     
                  
   -- connect external registers with internal registers 
   csr_reset_o       <= reg_csr(0);
   csr_pause_o       <= reg_csr(1);
   csr_osm_o         <= reg_csr(2);
   csr_keyboard_o    <= reg_csr(3);
   csr_joy1_o        <= reg_csr(4);
   csr_joy2_o        <= reg_csr(5);
   ramrom_ce_o       <= ramrom_en;
   ramrom_we_o       <= ramrom_we;
   ramrom_addr_o     <= std_logic_vector(to_unsigned(reg_ramrom_4kwin * 4096 + to_integer(unsigned(cpu_addr(11 downto 0))), 28));
   ramrom_data_o     <= cpu_data_out;
                     
   -- QNICE CPU
   cpu : entity work.QNICE_CPU
      port map
      (
         CLK                  => clk50_i,
         RESET                => reset_ctl,
         WAIT_FOR_DATA        => cpu_wait_for_data,
         ADDR                 => cpu_addr,
         DATA_IN              => cpu_data_in,
         DATA_OUT             => cpu_data_out,
         DATA_DIR             => cpu_data_dir,
         DATA_VALID           => cpu_data_valid,
         HALT                 => cpu_halt,
         INS_CNT_STROBE       => open,
         INT_N                => '1',
         IGRANT_N             => open
      );
                  
   -- QNICE ROM
   rom : entity work.BROM
      generic map
      (
         FILE_NAME            => G_FIRMWARE
      )
      port map
      (
         CLK                  => clk50_i,
         ce                   => rom_en,
         address              => cpu_addr(14 downto 0),
         data                 => rom_data_out
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : entity work.BRAM
      port map
      (
         clk                  => clk50_i,
         ce                   => ram_en,
         address              => cpu_addr(14 downto 0),
         we                   => cpu_data_dir,         
         data_i               => cpu_data_out,
         data_o               => ram_data_out,
         busy                 => open         
      );

   -- special UART with FIFO that can be directly connected to the CPU bus
   uart : entity work.bus_uart
      generic map
      (
         DIVISOR              => UART_DIVISOR
      )
      port map
      (
         clk                  => clk50_i,
         reset                => reset_ctl,
         rx                   => uart_rxd_i,
         tx                   => uart_txd_o,
         rts                  => '0',
         cts                  => open,
         uart_en              => uart_en,
         uart_we              => uart_we,
         uart_reg             => uart_reg,
         uart_cpu_ws          => uart_cpu_ws,         
         cpu_data_in          => cpu_data_out,
         cpu_data_out         => uart_data_out
      );
      
   -- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
   eae_inst : entity work.eae
      port map
      (
         clk                  => clk50_i,
         reset                => reset_ctl,
         en                   => eae_en,
         we                   => eae_we,
         reg                  => eae_reg,
         data_in              => cpu_data_out,
         data_out             => eae_data_out
      );

   -- SD Card
   sd_card : entity work.sdcard
      port map
      (
         clk                  => clk50_i,
         reset                => reset_ctl,
         en                   => sd_en,
         we                   => sd_we,
         reg                  => sd_reg,
         data_in              => cpu_data_out,
         data_out             => sd_data_out,
         sd_reset             => sd_reset_o,
         sd_clk               => sd_clk_o,
         sd_mosi              => sd_mosi_o,
         sd_miso              => sd_miso_i
      );
    
   -- Standard QNICE-FPGA MMIO controller  
   mmio_std : entity work.mmio_mux
      generic map
      (
         GD_TIL               => false,
         GD_SWITCHES          => true,
         GD_HRAM              => false,
         GD_PORE              => false
      )
      port map (
         -- input from hardware
         HW_RESET             => not reset_n_i,
         CLK                  => clk50_i,
      
         -- input from CPU
         addr                 => cpu_addr,
         data_dir             => cpu_data_dir,
         data_valid           => cpu_data_valid,
         cpu_halt             => cpu_halt,
         cpu_igrant_n         => '1',
         
         -- let the CPU wait for data from the bus
         cpu_wait_for_data    => cpu_wait_for_data,
         
         -- ROM is enabled when the address is < $8000 and the CPU is reading
         -- But because we map the general purpose 4k MMIO window to $7000, this is only a "maybe"
         rom_enable           => rom_en_maybe,
         rom_busy             => '0',
         
         -- RAM is enabled when the address is in ($8000..$FEFF)
         ram_enable           => ram_en,
         ram_busy             => '0',
                          
         -- SWITCHES is $FF00
         switch_reg_enable    => open,    -- hardcoded to zero (STDIN=STDOUT=UART)
         
         -- UART register range $FF10..$FF13
         uart_en              => uart_en,
         uart_we              => uart_we,
         uart_reg             => uart_reg,
         uart_cpu_ws          => uart_cpu_ws,
         
         -- Extended Arithmetic Element register range $FF18..$FF1F
         eae_en               => eae_en,
         eae_we               => eae_we,
         eae_reg              => eae_reg,
      
         -- SD Card register range $FF20..FF27
         sd_en                => sd_en,
         sd_we                => sd_we,
         sd_reg               => sd_reg,
         
         -- global state and reset management
         reset_pre_pore       => reset_pre_pore,
         reset_post_pore      => reset_post_pore,
                                 
         -- QNICE hardware unsupported by gbc4MEGA65
         til_reg0_enable      => open,
         til_reg1_enable      => open,         
         kbd_en               => open,
         kbd_we               => open,
         kbd_reg              => open,
         cyc_en               => open,
         cyc_we               => open,
         cyc_reg              => open,
         ins_en               => open,
         ins_we               => open,
         ins_reg              => open,
         pore_rom_enable      => open,
         pore_rom_busy        => '0',      
         tin_en               => open,
         tin_we               => open,
         tin_reg              => open,
         vga_en               => open,
         vga_we               => open,
         vga_reg              => open,
         hram_en              => open,
         hram_we              => open,
         hram_reg             => open, 
         hram_cpu_ws          => '0'          
      );
               
   -- Additional MiSTer2MEGA65 specific MMIO (refer to M2M/rom/sysdef.asm for a memory map and more details)
   -- 0x7000: 4k MMIO window 
   -- 0xFFE0: Control and status register
   -- 0xFFE1: OSM x|y coordinates (in chars)
   -- 0xFFE2: OSM dx|dy width|height (in chars)
   -- 0xFFE3 .. 0xFFE6: read-only registers for OSM presets
   -- 0xFFE7: read-only register for hardware screen size in chars (width and height)
   -- 0xFFF0 .. 0xFFF3: access 256-bit general purpose control flags via address/data pairs
   -- 0xFFF4 -- 0xFFF5: 4k-segmented access to RAMs, ROMs and similarily behaving devices
   ramrom_en                  <= '1' when cpu_addr(15 downto 12) = x"7" else '0';
   ramrom_we                  <= ramrom_en and cpu_data_dir and cpu_data_valid;
   ramrom_data_out            <= ramrom_data_i when ramrom_en = '1' and ramrom_we = '0' else (others => '0');
   
   rom_en                     <= rom_en_maybe and not ramrom_en;
      
   csr_en                     <= '1' when cpu_addr = x"FFE0" else '0';
   csr_we                     <= csr_en and cpu_data_dir and cpu_data_valid;
   csr_data_out               <= reg_csr when csr_en = '1' and csr_we = '0' else (others => '0');
   
   osm_xy_en                  <= '1' when cpu_addr = x"FFE1" else '0';
   osm_xy_we                  <= osm_xy_en and cpu_data_dir and cpu_data_valid;
   osm_xy_data_out            <= osm_xy_o when osm_xy_en = '1' and osm_xy_we = '0' else (others => '0');
   
   osm_dxdy_en                <= '1' when cpu_addr = x"FFE2" else '0';
   osm_dxdy_we                <= osm_dxdy_en and cpu_data_dir and cpu_data_valid;
   osm_dxdy_data_out          <= osm_dxdy_o when osm_dxdy_en = '1' and osm_dxdy_we = '0' else (others => '0');
      
   shell_m_xy_en              <= '1' when cpu_addr = x"FFE3" else '0';
   shell_m_xy_data_out        <= std_logic_vector(to_unsigned(G_SHELL_M_X * 256 + G_SHELL_M_Y, 16)) when shell_m_xy_en = '1' and cpu_data_dir = '0' else (others => '0');  

   shell_m_dxdy_en            <= '1' when cpu_addr = x"FFE4" else '0';
   shell_m_dxdy_data_out      <= std_logic_vector(to_unsigned(G_SHELL_M_DX * 256 + G_SHELL_M_DY, 16)) when shell_m_dxdy_en = '1' and cpu_data_dir = '0' else (others => '0');

   shell_o_xy_en              <= '1' when cpu_addr = x"FFE5" else '0';
   shell_o_xy_data_out        <= std_logic_vector(to_unsigned(G_SHELL_O_X * 256 + G_SHELL_O_Y, 16)) when shell_o_xy_en = '1' and cpu_data_dir = '0' else (others => '0');

   shell_o_dxdy_en            <= '1' when cpu_addr = x"FFE6" else '0';
   shell_o_dxdy_data_out      <= std_logic_vector(to_unsigned(G_SHELL_O_DX * 256 + G_SHELL_O_DY, 16)) when shell_o_dxdy_en = '1' and cpu_data_dir = '0' else (others => '0');
   
   sys_dxdy_en                <= '1' when cpu_addr = x"FFE7" else '0';
   sys_dxdy_data_out          <= std_logic_vector(to_unsigned(CHARS_DX * 256 + CHARS_DY, 16)) when sys_dxdy_en = '1' and cpu_data_dir = '0' else (others => '0');
   
   keys_en                    <= '1' when cpu_addr = x"FFE8" else '0';
   keys_data_out              <= keys_n_i when keys_en = '1' and cpu_data_dir = '0' else (others => '0');
   
   cfd_addr_en                <= '1' when cpu_addr = x"FFF0" else '0';
   cfd_addr_we                <= cfd_addr_en and cpu_data_dir and cpu_data_valid;
   cfd_addr_data_out          <= std_logic_vector(to_unsigned(reg_cfd_addr, 16)) when cfd_addr_en = '1' and cfd_addr_we = '0' else (others => '0');
   
   cfd_data_en                <= '1' when cpu_addr = x"FFF1" else '0';
   cfd_data_we                <= cfd_data_en and cpu_data_dir and cpu_data_valid;
   cfd_data_data_out          <= control_d_o(((reg_cfd_addr + 1) * 16) - 1 downto (reg_cfd_addr * 16)) when cfd_data_en = '1' and cfd_data_we = '0' else (others => '0');  

   cfm_addr_en                <= '1' when cpu_addr = x"FFF2" else '0';
   cfm_addr_we                <= cfm_addr_en and cpu_data_dir and cpu_data_valid;
   cfm_addr_data_out          <= std_logic_vector(to_unsigned(reg_cfm_addr, 16)) when cfm_addr_en = '1' and cfm_addr_we = '0' else (others => '0');
   
   cfm_data_en                <= '1' when cpu_addr = x"FFF3" else '0';
   cfm_data_we                <= cfm_data_en and cpu_data_dir and cpu_data_valid;
   cfm_data_data_out          <= control_m_o(((reg_cfm_addr + 1) * 16) - 1 downto (reg_cfm_addr * 16)) when cfm_data_en = '1' and cfm_data_we = '0' else (others => '0');
   
   ramrom_dev_en              <= '1' when cpu_addr = x"FFF4" else '0';
   ramrom_dev_we              <= ramrom_dev_en and cpu_data_dir and cpu_data_valid;
   ramrom_dev_data_out        <= ramrom_dev_o when ramrom_dev_en = '1' and ramrom_dev_we = '0' else (others => '0');
   
   ramrom_4kwin_en            <= '1' when cpu_addr = x"FFF5" else '0';
   ramrom_4kwin_we            <= ramrom_4kwin_en and cpu_data_dir and cpu_data_valid;
   ramrom_4kwin_data_out      <= std_logic_vector(to_unsigned(reg_ramrom_4kwin, 16)) when ramrom_4kwin_en = '1' and ramrom_4kwin_we = '0' else (others => '0');    
                                       
   -- Registers (see also M2M/rom/sysdef.asm)
   handle_regs : process(clk50_i)
   begin
      if falling_edge(clk50_i) then
         -- Default values of all registers (reset)
         if reset_ctl = '1' then
            reg_csr     <= x"0001"; -- Hold the MiSTer core in reset state, de-couple all peripherals
            
             -- OSM is fullscreen by default
            osm_xy_o    <= x"0000";
            osm_dxdy_o  <= std_logic_vector(to_unsigned(CHARS_DX * 256 + CHARS_DY, 16));
            
            -- General purpose control flag management registers
            reg_cfd_addr <= 0;
            reg_cfm_addr <= 0;
            control_d_o <= (others => '0');
            control_m_o <= (others => '0');
            
            -- MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
            ramrom_dev_o <= x"0000";
            reg_ramrom_4kwin <= 0;
         else
            -- CSR register
            if csr_we then
               reg_csr <= cpu_data_out;
            end if;
                        
            -- OSM registers
            if osm_xy_we then
               osm_xy_o <= cpu_data_out;
            end if;
            if osm_dxdy_we then
               osm_dxdy_o <= cpu_data_out;
            end if;
            
            -- General purpose control flag management registers
            if cfd_addr_we then
               reg_cfd_addr <= to_integer(unsigned(cpu_data_out(3 downto 0)));
            end if;
            if cfd_data_we then
               control_d_o(((reg_cfd_addr + 1) * 16) - 1 downto (reg_cfd_addr * 16)) <= cpu_data_out;
            end if;
            if cfm_addr_we then
               reg_cfm_addr <= to_integer(unsigned(cpu_data_out(3 downto 0)));
            end if;
            if cfm_data_we then
               control_m_o(((reg_cfm_addr + 1) * 16) - 1 downto (reg_cfm_addr * 16)) <= cpu_data_out;            
            end if;
            
            -- MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
            if ramrom_dev_we then
               ramrom_dev_o <= cpu_data_out;   
            end if;
            if ramrom_4kwin_we then
               reg_ramrom_4kwin <= to_integer(unsigned(cpu_data_out));
            end if;
         end if;
      end if;
   end process;
         
end beh;

