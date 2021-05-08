----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- QNICE Co-Processor for ROM loading and On-Screen-Menu
--
-- gbc4mega65 machine is based on Gameboy_MiSTer
-- QNICE Co-Processor is based on QNICE-FPGA done by The QNICE Development Team
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.env1_globals.all;
use work.qnice_tools.all;

entity QNICE is
generic (
   VGA_DX            : integer;
   VGA_DY            : integer;
   MAX_ROM           : integer;                       -- highest supported ROM size code from https://gbdev.io/pandocs/#_0148-rom-size
                                                      -- but ignoring the $5x values
   MAX_RAM           : integer                        -- highest supported RAM size code from https://gbdev.io/pandocs/#_0149-ram-size
);
port (
   -- QNICE MEGA65 hardware interface
   CLK50             : in std_logic;                  -- 50 MHz clock                                    
   RESET_N           : in std_logic;                  -- CPU reset button
      
   UART_RXD          : in std_logic;                  -- receive data, 115.200 baud, 8-N-1, rxd, txd only; rts/cts are not available
   UART_TXD          : out std_logic;                 -- send data, ditto
   
   SD_RESET          : out std_logic;
   SD_CLK            : out std_logic;
   SD_MOSI           : out std_logic;
   SD_MISO           : in std_logic;
   
   -- keyboard matrix
   full_matrix       : in std_logic_vector(15 downto 0);

   -- Host VGA interface:
   -- The host requests one pixel in advance and QNICE responds with vga_on if this pixel is
   -- an OSD pixel and if yes, vga_rgb contains the color
   pixelclock        : in std_logic;
   vga_x             : in integer range 0 to VGA_DX - 1;
   vga_y             : in integer range 0 to VGA_DY - 1;
   vga_on            : out std_logic;
   vga_rgb           : out std_logic_vector(23 downto 0);   -- 23..0 = RGB, 8 bits each 

   -- Control and status register
   gbc_reset         : buffer std_logic;     -- reset Game Boy
   gbc_pause         : buffer std_logic;     -- pause Game Boy
   gbc_osm           : buffer std_logic;     -- show QNICE's On-Screen-Menu (OSM) over the Game Boy's Screen
   gbc_keyboard      : buffer std_logic;     -- connect the M65 keyboard with the Game Boy
   gbc_joystick      : buffer std_logic;     -- connect the M65 joystick ports with the Game Boy
   gbc_color         : buffer std_logic;     -- 1=Game Boy Color; 0=Game Boy Classic
   gbc_joy_map       : buffer std_logic_vector(1 downto 0); -- see gbc.asm for the mapping
   gbc_color_mode    : buffer std_logic;     -- 0=Fully Saturated; 1=LCD Emulation 

   -- Interfaces to Game Boy's RAMs (MMIO):
   gbc_bios_addr     : out std_logic_vector(11 downto 0);
   gbc_bios_we       : out std_logic;
   gbc_bios_data_in  : out std_logic_vector(7 downto 0);
   gbc_bios_data_out : in std_logic_vector(7 downto 0);
   gbc_cart_addr     : out std_logic_vector(22 downto 0);
   gbc_cart_we       : out std_logic;
   gbc_cart_data_in  : out std_logic_vector(7 downto 0);
   gbc_cart_data_out : in std_logic_vector(7 downto 0);
         
   -- Information about the current game cartridge
   cart_cgb_flag     : buffer std_logic_vector(7 downto 0);
   cart_sgb_flag     : buffer std_logic_vector(7 downto 0);
   cart_mbc_type     : buffer std_logic_vector(7 downto 0);
   cart_rom_size     : buffer std_logic_vector(7 downto 0);
   cart_ram_size     : buffer std_logic_vector(7 downto 0);
   cart_old_licensee : buffer std_logic_vector(7 downto 0)
); 
end QNICE;

architecture beh of QNICE is

-- Constants for VGA output
constant FONT_DX                  : integer := 16;
constant FONT_DY                  : integer := 16;
constant CHARS_DX                 : integer := VGA_DX / FONT_DX;
constant CHARS_DY                 : integer := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE            : integer := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH          : integer := f_log2(CHAR_MEM_SIZE);

-- CPU control signals
signal cpu_addr                   : std_logic_vector(15 downto 0);
signal cpu_data_in                : std_logic_vector(15 downto 0);
signal cpu_data_out               : std_logic_vector(15 downto 0);
signal cpu_data_dir               : std_logic;
signal cpu_data_valid             : std_logic;
signal cpu_wait_for_data          : std_logic;
signal cpu_halt                   : std_logic;

-- reset control
signal reset_ctl                  : std_logic;
signal reset_pre_pore             : std_logic;
signal reset_post_pore            : std_logic;

-- QNICE standard MMIO signals
signal rom_en                     : std_logic;
signal rom_data_out               : std_logic_vector(15 downto 0);
signal ram_en                     : std_logic;
signal ram_en_maybe               : std_logic;                        -- output of standard MMIO module without taking care of gbc specific MMIO 
signal ram_busy                   : std_logic;
signal ram_data_out               : std_logic_vector(15 downto 0);
signal switch_data_out            : std_logic_vector(15 downto 0);
signal uart_en                    : std_logic;
signal uart_we                    : std_logic;
signal uart_reg                   : std_logic_vector(1 downto 0);
signal uart_cpu_ws                : std_logic;
signal uart_data_out              : std_logic_vector(15 downto 0);
signal eae_en                     : std_logic;
signal eae_we                     : std_logic;
signal eae_reg                    : std_logic_vector(2 downto 0);
signal eae_data_out               : std_logic_vector(15 downto 0);
signal sd_en                      : std_logic;
signal sd_we                      : std_logic;
signal sd_reg                     : std_logic_vector(2 downto 0);
signal sd_data_out                : std_logic_vector(15 downto 0);

-- GBC specific MMIO signals
signal csr_en                     : std_logic;                        -- $FFE0
signal csr_we                     : std_logic;
signal csr_data_out               : std_logic_vector(15 downto 0);
signal gbc_cart_sel_en            : std_logic;                        -- $FFE1
signal gbc_cart_sel_we            : std_logic;
signal osm_xy_en                  : std_logic;                        -- $FFE2
signal osm_xy_we                  : std_logic;
signal osm_xy_data_out            : std_logic_vector(15 downto 0);
signal osm_dxdy_en                : std_logic;                        -- $FFE3
signal osm_dxdy_we                : std_logic;
signal osm_dxdy_data_out          : std_logic_vector(15 downto 0);
signal keyb_en                    : std_logic;                        -- $FFE4
signal keyb_data_out              : std_logic_vector(15 downto 0);
signal gbc_cart_sel_data_out      : std_logic_vector(15 downto 0);
signal vram_en                    : std_logic;                        -- $D000
signal vram_we                    : std_logic;
signal vram_data_out_i            : std_logic_vector(7 downto 0);
signal vram_data_out_16bit        : std_logic_vector(15 downto 0);
signal vram_attr_en               : std_logic;
signal vram_attr_we               : std_logic;
signal vram_attr_data_out_i       : std_logic_vector(7 downto 0);
signal vram_attr_data_out_16bit   : std_logic_vector(15 downto 0);
signal gbc_bios_en                : std_logic;                        -- $C000
signal gbc_bios_data_out_16bit    : std_logic_vector(15 downto 0);
signal gbc_cart_en                : std_logic;                        -- $B000
signal gbc_cart_data_out_16bit    : std_logic_vector(15 downto 0);   
signal cf_cgb_en                  : std_logic;                        -- $FFE5             
signal cf_cgb_we                  : std_logic;
signal cf_cgb_data_out_16bit      : std_logic_vector(15 downto 0);
signal cf_sgb_en                  : std_logic;                        -- $FFE6
signal cf_sgb_we                  : std_logic;
signal cf_sgb_data_out_16bit      : std_logic_vector(15 downto 0);
signal cf_mbc_en                  : std_logic;                        -- $FFE7
signal cf_mbc_we                  : std_logic;
signal cf_mbc_data_out_16bit      : std_logic_vector(15 downto 0);
signal cf_rom_size_en             : std_logic;                        -- $FFE8
signal cf_rom_size_we             : std_logic;
signal cf_rom_size_data_out_16bit : std_logic_vector(15 downto 0);
signal cf_ram_size_en             : std_logic;                        -- $FFE9
signal cf_ram_size_we             : std_logic;
signal cf_ram_size_data_out_16bit : std_logic_vector(15 downto 0);
signal cf_oldlic_en               : std_logic;                        -- $FFEA
signal cf_oldlic_we               : std_logic;
signal cf_oldlic_data_out_16bit   : std_logic_vector(15 downto 0);
signal reg_maxramrom_en           : std_logic;                        -- $FFEB
signal reg_maxramrom_data_out     : std_logic_vector(15 downto 0);

-- The cartridge address is up to 8 MB large and is calculated like this: (gbc_cart_sel x 4096) + gbc_cart_win
signal gbc_cart_sel               : integer range 0 to 2047;

-- On-Screen-Menu (OSM)
signal vga_x_old                  : integer range 0 to VGA_DX - 1;
signal vga_y_old                  : integer range 0 to VGA_DY - 1;
signal osm_vram_addr              : std_logic_vector(VRAM_ADDR_WIDTH - 1 downto 0);
signal osm_vram_data              : std_logic_vector(7 downto 0);
signal osm_vram_attr_data         : std_logic_vector(7 downto 0);
signal osm_font_addr              : std_logic_vector(11 downto 0);
signal osm_font_data              : std_logic_vector(15 downto 0);
signal osm_xy                     : std_logic_vector(15 downto 0);
signal osm_dxdy                   : std_logic_vector(15 downto 0);
signal osm_x1, osm_x2             : integer range 0 to CHARS_DX - 1;
signal osm_y1, osm_y2             : integer range 0 to CHARS_DY - 1;

begin

   -- Merge data outputs from all devices into a single data input to the CPU.
   -- This requires that all devices output 0's when not selected.
   cpu_data_in <= rom_data_out               or
                  ram_data_out               or
                  switch_data_out            or
                  uart_data_out              or
                  eae_data_out               or
                  sd_data_out                or
                  csr_data_out               or
                  keyb_data_out              or
                  vram_data_out_16bit        or
                  vram_attr_data_out_16bit   or
                  gbc_bios_data_out_16bit    or
                  gbc_cart_data_out_16bit    or
                  gbc_cart_sel_data_out      or
                  osm_xy_data_out            or
                  osm_dxdy_data_out          or                  
                  cf_cgb_data_out_16bit      or
                  cf_sgb_data_out_16bit      or
                  cf_mbc_data_out_16bit      or
                  cf_rom_size_data_out_16bit or
                  cf_ram_size_data_out_16bit or
                  cf_oldlic_data_out_16bit   or
                  reg_maxramrom_data_out;                    
                                    
   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1') else '0';                     
                  
   -- QNICE CPU
   cpu : entity work.QNICE_CPU
      port map
      (
         CLK                  => CLK50,
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
         FILE_NAME            => ROM_FILE,
         ADDR_WIDTH           => 15,
         DATA_WIDTH           => 16,
         LATCH_ACTIVE         => false
      )
      port map
      (
         CLK                  => CLK50,
         ce                   => rom_en,
         address              => cpu_addr(14 downto 0),
         data                 => rom_data_out
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : entity work.BRAM
      port map
      (
         clk                  => CLK50,
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
         clk                  => CLK50,
         reset                => reset_ctl,
         rx                   => UART_RXD,
         tx                   => UART_TXD,
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
         clk                  => CLK50,
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
         clk                  => CLK50,
         reset                => reset_ctl,
         en                   => sd_en,
         we                   => sd_we,
         reg                  => sd_reg,
         data_in              => cpu_data_out,
         data_out             => sd_data_out,
         sd_reset             => SD_RESET,
         sd_clk               => SD_CLK,
         sd_mosi              => SD_MOSI,
         sd_miso              => SD_MISO
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
         HW_RESET             => not RESET_N,
         CLK                  => CLK50,
      
         -- input from CPU
         addr                 => cpu_addr,
         data_dir             => cpu_data_dir,
         data_valid           => cpu_data_valid,
         cpu_halt             => cpu_halt,
         cpu_igrant_n         => '1',
         
         -- let the CPU wait for data from the bus
         cpu_wait_for_data    => cpu_wait_for_data,
         
         -- ROM is enabled when the address is < $8000 and the CPU is reading
         rom_enable           => rom_en,
         rom_busy             => '0',
         
         -- RAM is enabled when the address is in ($8000..$FEFF)
         -- QNICE's standard MMIO module is not aware of gbc specific MMIO, this is why this signal is just a "maybe"
         ram_enable           => ram_en_maybe,
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
               
   -- Additional gbc4mega65 specific MMIO:
   -- 0xB000..0xBFFF: Game Cartridge RAM: 4kb gliding window defined by 0xFFE1 multiplied by 4096
   -- 0xC000..0xCFFF: BIOS/BOOT "ROM RAM": 4kb
   -- 0xD000..0xD7FF: Screen RAM, "ASCII" codes
   -- 0xD800..0xDFFF: Attribute RAM for Screen RAM
   -- 0xFFE0        : Game Boy control and status register
   -- 0xFFE1        : Selector for the gliding Cartridge RAM window (multiplied by 4096)
   -- 0xFFE2        : X and Y coordinate (in chars, hi/lo) where the OSM window will start
   -- 0xFFE3        : DX and DY size (in chars, hi/lo) of the OSM window
   -- 0xFFE4        : keyboard
   -- 0xFFE5        : Cartridge flag: CGB
   -- 0xFFE6        : Cartridge flag: SGB
   -- 0xFFE7        : Cartridge flag: MBC
   -- 0xFFE8        : Cartridge flag: ROM size
   -- 0xFFE9        : Cartridge flag: RAM size
   -- 0xFFEA        : Cartridge flag: Old Licensee
   -- 0xFFEB        : Codes of the highest supported RAM and ROM amounts
   ram_en                     <= ram_en_maybe and not vram_en and not vram_attr_en and not gbc_bios_en and not gbc_cart_en;  -- exclude gbc specific MMIO areas
   csr_en                     <= '1' when cpu_addr(15 downto 0) = x"FFE0" else '0';
   csr_we                     <= csr_en and cpu_data_dir and cpu_data_valid;
   csr_data_out               <= x"0" & "000" & gbc_color_mode & gbc_joy_map & gbc_color & gbc_joystick & gbc_keyboard & gbc_osm & gbc_pause & gbc_reset when csr_en = '1' and csr_we = '0' else (others => '0');
   vram_en                    <= '1' when cpu_addr(15 downto 11) = x"D" & "0" else '0'; -- $D000 .. $D7FF
   vram_we                    <= vram_en and cpu_data_dir and cpu_data_valid;
   vram_data_out_16bit        <= x"00" & vram_data_out_i when vram_en = '1' and vram_we = '0' else (others => '0');
   vram_attr_en               <= '1' when cpu_addr(15 downto 11) = x"D" & "1" else '0'; -- $D800 .. $DFFF
   vram_attr_we               <= vram_attr_en and cpu_data_dir and cpu_data_valid;
   vram_attr_data_out_16bit   <= x"00" & vram_attr_data_out_i when vram_attr_en = '1' and vram_attr_we = '0' else (others => '0');
   gbc_bios_addr              <= cpu_addr(11 downto 0);
   gbc_bios_en                <= '1' when cpu_addr(15 downto 12) = x"C" else '0';
   gbc_bios_we                <= gbc_bios_en and cpu_data_dir and cpu_data_valid;
   gbc_bios_data_in           <= cpu_data_out(7 downto 0);
   gbc_bios_data_out_16bit    <= x"00" & gbc_bios_data_out when gbc_bios_en = '1' and gbc_bios_we = '0' else (others => '0');
   gbc_cart_addr              <= std_logic_vector(to_unsigned(gbc_cart_sel, 11)) & cpu_addr(11 downto 0); -- up to 8 MB ROM size: 4096 x gbc_cart_sel + address in window
   gbc_cart_en                <= '1' when cpu_addr(15 downto 12) = x"B" else '0';
   gbc_cart_we                <= gbc_cart_en and cpu_data_dir and cpu_data_valid;
   gbc_cart_data_in           <= cpu_data_out(7 downto 0);
   gbc_cart_data_out_16bit    <= x"00" & gbc_cart_data_out when gbc_cart_en = '1' and gbc_cart_we = '0' else (others => '0');
   gbc_cart_sel_en            <= '1' when cpu_addr = x"FFE1" else '0';
   gbc_cart_sel_we            <= gbc_cart_sel_en and cpu_data_dir and cpu_data_valid;
   gbc_cart_sel_data_out      <= "00000" & std_logic_vector(to_unsigned(gbc_cart_sel, 11)) when gbc_cart_sel_en = '1' and gbc_cart_sel_we = '0' else (others => '0');
   osm_xy_en                  <= '1' when cpu_addr = x"FFE2" else '0';
   osm_xy_we                  <= osm_xy_en and cpu_data_dir and cpu_data_valid;
   osm_xy_data_out            <= osm_xy when osm_xy_en = '1' and osm_xy_we = '0' else (others => '0');
   osm_dxdy_en                <= '1' when cpu_addr = x"FFE3" else '0';
   osm_dxdy_we                <= osm_dxdy_en and cpu_data_dir and cpu_data_valid;
   osm_dxdy_data_out          <= osm_dxdy when osm_dxdy_en = '1' and osm_dxdy_we = '0' else (others => '0');
   keyb_en                    <= '1' when cpu_addr = x"FFE4" else '0';
   keyb_data_out              <= full_matrix when keyb_en = '1' and cpu_data_dir = '0' else (others => '0');
   cf_cgb_en                  <= '1' when cpu_addr = x"FFE5" else '0';
   cf_cgb_we                  <= cf_cgb_en and cpu_data_dir and cpu_data_valid;
   cf_cgb_data_out_16bit      <= x"00" & cart_cgb_flag when cf_cgb_en = '1' and cf_cgb_we = '0' else (others => '0');
   cf_sgb_en                  <= '1' when cpu_addr = x"FFE6" else '0';
   cf_sgb_we                  <= cf_sgb_en and cpu_data_dir and cpu_data_valid;
   cf_sgb_data_out_16bit      <= x"00" & cart_sgb_flag when cf_sgb_en = '1' and cf_sgb_we = '0' else (others => '0');   
   cf_mbc_en                  <= '1' when cpu_addr = x"FFE7" else '0';
   cf_mbc_we                  <= cf_mbc_en and cpu_data_dir and cpu_data_valid;
   cf_mbc_data_out_16bit      <= x"00" & cart_mbc_type when cf_mbc_en = '1' and cf_mbc_we = '0' else (others => '0');   
   cf_rom_size_en             <= '1' when cpu_addr = x"FFE8" else '0';
   cf_rom_size_we             <= cf_rom_size_en and cpu_data_dir and cpu_data_valid;
   cf_rom_size_data_out_16bit <= x"00" & cart_rom_size when cf_rom_size_en = '1' and cf_rom_size_we = '0' else (others => '0');
   cf_ram_size_en             <= '1' when cpu_addr = x"FFE9" else '0';
   cf_ram_size_we             <= cf_ram_size_en and cpu_data_dir and cpu_data_valid;
   cf_ram_size_data_out_16bit <= x"00" & cart_ram_size when cf_ram_size_en = '1' and cf_ram_size_we = '0' else (others => '0');
   cf_oldlic_en               <= '1' when cpu_addr = x"FFEA" else '0';
   cf_oldlic_we               <= cf_oldlic_en and cpu_data_dir and cpu_data_valid;
   cf_oldlic_data_out_16bit   <= x"00" & cart_old_licensee when cf_oldlic_en = '1' and cf_oldlic_we = '0' else (others => '0');
   reg_maxramrom_en           <= '1' when cpu_addr = x"FFEB" else '0';
   reg_maxramrom_data_out     <= std_logic_vector(to_unsigned(MAX_RAM, 8)) & std_logic_vector(to_unsigned(MAX_ROM, 8)) when reg_maxramrom_en ='1' else (others => '0');  
                        
   -- Registers (see also gbc.asm)
   --   CSR: Control and status register (reset, pause, osm, keyboard, joystick, gbc/gb mode selection)
   --   cart_sel: Cartridge "ROM RAM" 4096-byte window selector
   --   osm_xy: X and Y coordinate (in chars, hi/lo) where the OSM window will start
   --   osm_dxdy: DX and DY size (in chars, hi/lo) of the OSM window
   --   cf*: Cartridge flag registers
   handle_regs : process(clk50)
   begin
      if falling_edge(clk50) then
         if reset_ctl = '1' then
            gbc_reset      <= '1';  -- Default: System is in reset state and therefore halted
            gbc_pause      <= '0';  -- Default: The clock is not paused
            gbc_osm        <= '1';  -- Default: The On-Screen-Menu is ON
            gbc_keyboard   <= '1';  -- Default: The keyboard of the Game Boy is ON
            gbc_joystick   <= '1';  -- Default: The joystick of the Game Boy is ON
            gbc_color      <= '1';  -- Default: Game Boy Color, even for Game Boy Classic games
            gbc_joy_map    <= "00"; -- Default: Standard Joystick, Fire Button=A
            gbc_color_mode <= '0';  -- Default: Fully saturated colors (raw RGB output)
            osm_xy    <= x"0000";
            osm_dxdy  <= std_logic_vector(to_unsigned(CHARS_DX * 256 + CHARS_DY, 16));
         else
            -- CSR register
            if csr_we = '1' then
               gbc_reset      <= cpu_data_out(0);
               gbc_pause      <= cpu_data_out(1);
               gbc_osm        <= cpu_data_out(2);
               gbc_keyboard   <= cpu_data_out(3);
               gbc_joystick   <= cpu_data_out(4);
               gbc_color      <= cpu_data_out(5);
               gbc_joy_map    <= cpu_data_out(7 downto 6);
               gbc_color_mode <= cpu_data_out(8);
            end if;
            
            -- cartridge window selector
            if gbc_cart_sel_we = '1' then
               gbc_cart_sel <= to_integer(unsigned(cpu_data_out(10 downto 0))); -- 0 .. 2047 
            end if;
            
            -- osm registers
            if osm_xy_we = '1' then
               osm_xy <= cpu_data_out;
            end if;
            if osm_dxdy_we = '1' then
               osm_dxdy <= cpu_data_out;
            end if;
            
            -- cf*: Cartridge flag registers
            if cf_cgb_we  = '1' then            
               cart_cgb_flag <= cpu_data_out(7 downto 0);
            end if;
            if cf_sgb_we = '1' then
               cart_sgb_flag <= cpu_data_out(7 downto 0);
            end if;   
            if cf_mbc_we = '1' then
               cart_mbc_type <= cpu_data_out(7 downto 0);
            end if;   
            if cf_rom_size_we = '1' then
               cart_rom_size <= cpu_data_out(7 downto 0);
            end if;
            if cf_ram_size_we = '1' then            
               cart_ram_size <= cpu_data_out(7 downto 0);
            end if;
            if cf_oldlic_we = '1' then
               cart_old_licensee <= cpu_data_out(7 downto 0);
            end if;                    
         end if;
      end if;
   end process;
   
   -- emulate the toggle switches as described in QNICE-FPGA's doc/README.md
   -- all zero: STDIN = STDOUT = UART
   switch_data_out <= (others => '0');
      
   -- Dual port & dual clock screen RAM / video RAM: contains the "ASCII" codes of the characters
   vram : entity work.dualport_2clk_ram
      generic map
      (
          ADDR_WIDTH          => VRAM_ADDR_WIDTH,
          DATA_WIDTH          => 8,
          FALLING_A           => true              -- QNICE expects read/write to happen at the falling clock edge
      )
      port map
      (
         clock_a              => CLK50,
         address_a            => cpu_addr(VRAM_ADDR_WIDTH - 1 downto 0),
         data_a               => cpu_data_out(7 downto 0),
         wren_a               => vram_we,
         q_a                  => vram_data_out_i,
   
         clock_b              => pixelclock,
         address_b            => osm_vram_addr,
         q_b                  => osm_vram_data
      );
      
   -- Dual port & dual clock attribute RAM: contains inverse attribute, light/dark attrib. and colors of the chars
   -- bit 7: 1=inverse
   -- bit 6: 1=dark, 0=bright
   -- bit 5: background red
   -- bit 4: background green
   -- bit 3: background blue
   -- bit 2: foreground red
   -- bit 1: foreground green
   -- bit 0: foreground blue
   vram_attr : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH           => VRAM_ADDR_WIDTH,
         DATA_WIDTH           => 8,
         FALLING_A            => true
      )
      port map
      (
         clock_a              => CLK50,
         address_a            => cpu_addr(VRAM_ADDR_WIDTH - 1 downto 0),
         data_a               => cpu_data_out(7 downto 0),
         wren_a               => vram_attr_we,
         q_a                  => vram_attr_data_out_i,
         
         clock_b              => pixelclock,
         address_b            => osm_vram_addr,       -- same address as VRAM
         q_b                  => osm_vram_attr_data
      );
         
   -- 16x16 pixel font ROM
   font : entity work.BROM
      generic map
      (
         FILE_NAME      => "../font/Anikki-16x16.rom",
         ADDR_WIDTH     => 12,
         DATA_WIDTH     => 16,
         LATCH_ACTIVE   => false
      )
      port map
      (
         clk            => pixelclock,
         ce             => '1',
         address        => osm_font_addr,
         data           => osm_font_data
      );
     
   -- it takes one pixelclock cycle until the vram returns the data 
   latch_vga_xy : process(pixelclock)
   begin
      if rising_edge(pixelclock) then
         vga_x_old <= vga_x;
         vga_y_old <= vga_y;
      end if;
   end process;
      
   -- render OSM: calculate the pixel that needs to be shown at the given position  
   -- TODO: either here or in the top file: we are +1 pixel too much to the right (what about the vertical axis?) 
   render_osm : process(vga_x, vga_y, vga_x_old, vga_y_old, osm_vram_data, osm_vram_attr_data, osm_font_data, osm_x1, osm_y1, osm_x2, osm_y2, gbc_osm)
      variable vga_x_div_16 : integer range 0 to CHARS_DX - 1;
      variable vga_y_div_16 : integer range 0 to CHARS_DY - 1;
      variable vga_x_mod_16 : integer range 0 to 15;
      variable vga_y_mod_16 : integer range 0 to 15;
      
      function attr2rgb(attr: in std_logic_vector(3 downto 0)) return std_logic_vector is
      variable r, g, b: std_logic_vector(7 downto 0);
      variable brightness : std_logic_vector(7 downto 0);
      begin
         -- see comment above at vram_attr to understand the Attribute VRAM bit patterns
         brightness := x"FF" when attr(3) = '0' else x"7F";
         r := brightness when attr(2) = '1' else x"00";
         g := brightness when attr(1) = '1' else x"00";
         b := brightness when attr(0) = '1' else x"00";
         return r & g & b;
      end attr2rgb;
      
   begin
      vga_x_div_16 := to_integer(to_unsigned(vga_x, 16)(9 downto 4));
      vga_y_div_16 := to_integer(to_unsigned(vga_y, 16)(9 downto 4));
      vga_x_mod_16 := to_integer(to_unsigned(vga_x_old, 16)(3 downto 0));
      vga_y_mod_16 := to_integer(to_unsigned(vga_y_old, 16)(3 downto 0));
      osm_vram_addr <= std_logic_vector(to_unsigned(vga_y_div_16 * CHARS_DX + vga_x_div_16, VRAM_ADDR_WIDTH));
      osm_font_addr <= std_logic_vector(to_unsigned(to_integer(unsigned(osm_vram_data)) * FONT_DY + vga_y_mod_16, 12));
      -- if pixel is set in font (and take care of inverse on/off)
      if osm_font_data(15 - vga_x_mod_16) = not osm_vram_attr_data(7) then
         -- foreground color
         vga_rgb <= attr2rgb(osm_vram_attr_data(6) & osm_vram_attr_data(2 downto 0));
      else
         -- background color
         vga_rgb <= attr2rgb(osm_vram_attr_data(6 downto 3));
      end if;
      
      if vga_x_div_16 >= osm_x1 and vga_x_div_16 < osm_x2 and vga_y_div_16 >= osm_y1 and vga_y_div_16 < osm_y2 then
         vga_on <= gbc_osm;
      else
         vga_on <= '0';
      end if;
   end process;   
   
   calc_boundaries : process(osm_xy, osm_dxdy)
      variable osm_x : integer range 0 to CHARS_DX - 1;
      variable osm_y : integer range 0 to CHARS_DY - 1;
   begin
      osm_x  := to_integer(unsigned(osm_xy(15 downto 8)));
      osm_y  := to_integer(unsigned(osm_xy(7 downto 0)));
      osm_x1 <= osm_x;
      osm_y1 <= osm_y;
      osm_x2 <= osm_x + to_integer(unsigned(osm_dxdy(15 downto 8)));
      osm_y2 <= osm_y + to_integer(unsigned(osm_dxdy(7 downto 0)));
   end process;
end beh;
