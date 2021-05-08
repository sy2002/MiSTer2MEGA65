----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Main file that contains the whole machine.

-- It can be configured to fit the different MEGA65 models using generics:
-- The different FPGA RAM sizes of R2 and R3 lead to different maximum sizes for
-- the cartridge ROM and RAM. Have a look at m65_const.vhd to learn more. 
--
-- Screen resolution:
-- VGA out runs at SVGA mode 800 x 600 @ 60 Hz. This is a compromise between
-- the optimal usage of screen real estate and compatibility to older CRTs 
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.qnice_tools.all;

entity MEGA65_Core is
generic (
   CART_ROM_MAX   : integer;                       -- maximum size of cartridge ROM in bytes 
   CART_RAM_MAX   : integer;                       -- ditto cartridge RAM
   SYS_ROM_MAX    : integer;                       -- maximum cartridge ROM mode, see m65_const.vhd for details
   SYS_RAM_MAX    : integer                        -- ditto cartridge RAM
);
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button
   
   -- serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                  -- receive data
   UART_TXD       : out std_logic;                 -- send data   
        
   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;
   
   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;
   
   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard   
   
   -- SD Card
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic;
   
   -- 3.5mm analog audio jack
   pwm_l          : out std_logic;
   pwm_r          : out std_logic;
      
   -- Joysticks
   joy_1_up_n     : in std_logic;
   joy_1_down_n   : in std_logic;
   joy_1_left_n   : in std_logic;
   joy_1_right_n  : in std_logic;
   joy_1_fire_n   : in std_logic;
      
   joy_2_up_n     : in std_logic;
   joy_2_down_n   : in std_logic;
   joy_2_left_n   : in std_logic;
   joy_2_right_n  : in std_logic;
   joy_2_fire_n   : in std_logic            
); 
end MEGA65_Core;

architecture beh of MEGA65_Core is

constant CART_ROM_WIDTH    : integer := f_log2(CART_ROM_MAX);
constant CART_RAM_WIDTH    : integer := f_log2(CART_RAM_MAX);

-- ROM options
constant GBC_ORG_ROM       : string := "../../rom/cgb_bios.rom";        -- Copyrighted original GBC ROM, not checked-in into official repo
constant GBC_OSS_ROM       : string := "../../BootROMs/cgb_boot.rom";   -- Alternative Open Source GBC ROM
constant DMG_ORG_ROM       : string := "../../rom/dmg_boot.rom";        -- Copyrighted original DMG ROM, not checked-in into official repo
constant DMG_OSS_ROM       : string := "../../BootROMs/dmg_boot.rom";   -- Alternative Open Source DMG ROM

constant GBC_ROM           : string := GBC_OSS_ROM;   -- use Open Source ROMs by default
constant DMG_ROM           : string := GBC_OSS_ROM;

-- clock speeds
constant GB_CLK_SPEED      : integer := 33_554_432;
constant QNICE_CLK_SPEED   : integer := 50_000_000;

-- rendering constants
constant GB_DX             : integer := 160;          -- Game Boy's X pixel resolution
constant GB_DY             : integer := 144;          -- ditto Y
constant VGA_DX            : integer := 800;          -- SVGA mode 800 x 600 @ 60 Hz
constant VGA_DY            : integer := 600;          -- ditto
constant GB_TO_VGA_SCALE   : integer := 4;            -- 160 x 144 => 4x => 640 x 576

-- clocks
signal main_clk            : std_logic;               -- Game Boy core main clock @ 33.554432 MHz
signal vga_pixelclk        : std_logic;               -- SVGA mode 800 x 600 @ 60 Hz: 40.00 MHz
signal qnice_clk           : std_logic;               -- QNICE main clock @ 50 MHz

-- VGA signals
signal vga_disp_en         : std_logic;
signal vga_col_raw         : integer range 0 to VGA_DX - 1;
signal vga_row_raw         : integer range 0 to VGA_DY - 1;
signal vga_col             : integer range 0 to VGA_DX - 1;
signal vga_row             : integer range 0 to VGA_DY - 1;
signal vga_col_next        : integer range 0 to VGA_DX - 1;
signal vga_row_next        : integer range 0 to VGA_DY - 1;
signal vga_hs_int          : std_logic;
signal vga_vs_int          : std_logic;

-- Audio signals
signal pcm_audio_left      : std_logic_vector(15 downto 0);
signal pcm_audio_right     : std_logic_vector(15 downto 0);

-- debounced signals for the reset button and the joysticks
signal dbnce_reset_n       : std_logic;
signal dbnce_joy1_up_n     : std_logic;
signal dbnce_joy1_down_n   : std_logic;
signal dbnce_joy1_left_n   : std_logic;
signal dbnce_joy1_right_n  : std_logic;
signal dbnce_joy1_fire_n   : std_logic;
signal dbnce_joy2_up_n     : std_logic;
signal dbnce_joy2_down_n   : std_logic;
signal dbnce_joy2_left_n   : std_logic;
signal dbnce_joy2_right_n  : std_logic;
signal dbnce_joy2_fire_n   : std_logic;

-- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
signal m65_joystick        : std_logic_vector(4 downto 0);

-- Game Boy
signal gbc_bios_addr       : std_logic_vector(11 downto 0);
signal gbc_bios_data       : std_logic_vector(7 downto 0);

-- LCD interface
signal lcd_clkena          : std_logic;
signal lcd_data            : std_logic_vector(14 downto 0);
signal lcd_mode            : std_logic_vector(1 downto 0);
signal lcd_on              : std_logic;
signal lcd_vsync           : std_logic;
signal lcd_r_blank_de      : std_logic := '0';
signal lcd_r_blank_output  : std_logic := '0';
signal lcd_r_blank_data    : std_logic_vector(14 downto 0) := (others => '0');
signal lcd_r_off           : std_logic := '0';
signal lcd_r_old_off       : std_logic := '0';
signal lcd_r_old_on        : std_logic := '0';
signal lcd_r_old_vs        : std_logic := '0';
signal lcd_r_blank_hcnt    : integer range 0 to GB_DX - 1 := 0;
signal lcd_r_blank_vcnt    : integer range 0 to GB_DY - 1 := 0;
signal pixel_out_we        : std_logic;
signal pixel_out_ptr       : integer range 0 to (GB_DX * GB_DY) - 1 := 0;
signal pixel_out_data      : std_logic_vector(23 downto 0) := (others => '0');
signal frame_buffer_data   : std_logic_vector(23 downto 0);
 
 -- speed control
signal sc_ce               : std_logic;
signal sc_ce_2x            : std_logic;
signal HDMA_on             : std_logic;
   
-- cartridge signals
signal cart_addr           : std_logic_vector(15 downto 0);
signal cart_rd             : std_logic;
signal cart_wr             : std_logic;
signal cart_do             : std_logic_vector(7 downto 0);
signal cart_di             : std_logic_vector(7 downto 0);

-- cartridge flags
signal cart_cgb_flag       : std_logic_vector(7 downto 0);
signal cart_sgb_flag       : std_logic_vector(7 downto 0);
signal cart_mbc_type       : std_logic_vector(7 downto 0);
signal cart_rom_size       : std_logic_vector(7 downto 0);
signal cart_ram_size       : std_logic_vector(7 downto 0);
signal cart_old_licensee   : std_logic_vector(7 downto 0);

signal isGBC_Game          : boolean;     -- current cartridge is dedicated GBC game
signal isSGB_Game          : boolean;     -- current cartridge is dedicated SBC game

-- MBC signals
signal cartrom_addr        : std_logic_vector(22 downto 0); 
signal cartrom_rd          : std_logic;
signal cartrom_data        : std_logic_vector(7 downto 0);
signal cartram_addr        : std_logic_vector(16 downto 0);
signal cartram_rd          : std_logic;
signal cartram_wr          : std_logic;
signal cartram_data_in     : std_logic_vector(7 downto 0);
signal cartram_data_out    : std_logic_vector(7 downto 0);

-- joypad: p54 selects matrix entry and data contains either
-- the direction keys or the other buttons
signal joypad_p54          : std_logic_vector(1 downto 0);
signal joypad_data         : std_logic_vector(3 downto 0);
signal joypad_data_i       : std_logic_vector(3 downto 0);

-- QNICE control signals (see also gbc.asm for more details)
signal qngbc_reset         : std_logic;
signal qngbc_pause         : std_logic;
signal qngbc_keyboard      : std_logic;
signal qngbc_joystick      : std_logic;
signal qngbc_color         : std_logic;
signal qngbc_joy_map       : std_logic_vector(1 downto 0);
signal qngbc_color_mode    : std_logic;

signal qngbc_bios_addr     : std_logic_vector(11 downto 0);
signal qngbc_bios_we       : std_logic;
signal qngbc_bios_data_in  : std_logic_vector(7 downto 0);
signal qngbc_bios_data_out : std_logic_vector(7 downto 0);
signal qngbc_cart_addr     : std_logic_vector(22 downto 0);
signal qngbc_cart_we       : std_logic;
signal qngbc_cart_data_in  : std_logic_vector(7 downto 0);
signal qngbc_cart_data_out : std_logic_vector(7 downto 0);
signal qngbc_osm_on        : std_logic;
signal qngbc_osm_rgb       : std_logic_vector(23 downto 0);
signal qngbc_keyb_matrix   : std_logic_vector(15 downto 0);

-- signals neccessary due to Verilog in VHDL embedding
-- otherwise, when wiring constants directly to the entity, then Vivado throws an error
signal i_fast_boot         : std_logic;
signal i_joystick          : std_logic_vector(7 downto 0);
signal i_reset             : std_logic;
signal i_dummy_0           : std_logic;
signal i_dummy_2bit_0      : std_logic_vector(1 downto 0);
signal i_dummy_8bit_0      : std_logic_vector(7 downto 0);
signal i_dummy_64bit_0     : std_logic_vector(63 downto 0);
signal i_dummy_129bit_0    : std_logic_vector(128 downto 0);
 
begin

   -- MMCME2_ADV clock generators:
   --    Core clock:          33.554432 MHz
   --    Pixelclock:          34.96 MHz
   --    QNICE co-processor:  50 MHz   
   clk_gen : entity work.clk_m
      port map
      (
         sys_clk_i         => CLK,
         gbmain_o          => main_clk,         -- Game Boy's 33.554432 MHz main clock
         qnice_o           => qnice_clk         -- QNICE's 50 MHz main clock
      );
   clk_pixel : entity work.clk_p
      port map
      (
         sys_clk_i         => CLK,
         pixelclk_o        => vga_pixelclk      -- 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
      );
         
   -- signals neccessary due to Verilog in VHDL embedding
   i_fast_boot       <= '0';
   i_joystick        <= x"FF";
   i_dummy_0         <= '0';
   i_dummy_2bit_0    <= (others => '0');
   i_dummy_8bit_0    <= (others => '0');
   i_dummy_64bit_0   <= (others => '0');
   i_dummy_129bit_0  <= (others => '0');
   
   -- TODO: Achieve timing closure also when using the debouncer   
   --i_reset           <= not dbnce_reset_n;   
   i_reset           <= not RESET_N; -- TODO/WARNING: might glitch

   -- Cartridge header flags
   -- Infos taken from: https://gbdev.io/pandocs/#the-cartridge-header and from MiSTer's mbc.sv
   isGBC_Game <= true when cart_cgb_flag = x"80" or cart_cgb_flag = x"C0" else false;
   isSGB_Game <= true when cart_sgb_flag = x"03" and cart_old_licensee = x"33" else false;
   
   -- Switch keyboard and joystick on/off according to the QNICE control and status register (see gbc.asm)
   -- joypad_data is active low
   joypad_data <= joypad_data_i when qngbc_keyboard = '1' else (others => '1');
         
   -- The actual machine (GB/GBC core)
   gameboy : entity work.gb
      port map
      (
         reset                   => qngbc_reset,
                     
         clk_sys                 => main_clk,
         ce                      => sc_ce,
         ce_2x                   => sc_ce_2x,
                  
         fast_boot               => i_fast_boot,
         joystick                => i_joystick,
         isGBC                   => qngbc_color,
         isGBC_game              => isGBC_Game,
      
         -- Cartridge interface: Connects with the Memory Bank Controller (MBC) 
         cart_addr               => cart_addr,
         cart_rd                 => cart_rd,
         cart_wr                 => cart_wr, 
         cart_di                 => cart_di,  
         cart_do                 => cart_do,  
         
         -- Game Boy BIOS interface
         gbc_bios_addr           => gbc_bios_addr,
         gbc_bios_do             => gbc_bios_data,
               
         -- audio    
         audio_l                 => pcm_audio_left,
         audio_r                 => pcm_audio_right,
               
         -- lcd interface     
         lcd_clkena              => lcd_clkena,
         lcd_data                => lcd_data,  
         lcd_mode                => lcd_mode,  
         lcd_on                  => lcd_on,    
         lcd_vsync               => lcd_vsync, 
            
         joy_p54                 => joypad_p54,
         joy_din                 => joypad_data,
                  
         speed                   => open,   --GBC
         HDMA_on                 => HDMA_on,
                  
         -- cheating/game code engine: not supported on MEGA65 
         gg_reset                => i_reset,
         gg_en                   => i_dummy_0,
         gg_code                 => i_dummy_129bit_0,
         gg_available            => open,
            
         -- serial port: not supported on MEGA65
         sc_int_clock2           => open,
         serial_clk_in           => i_dummy_0,
         serial_clk_out          => open,
         serial_data_in          => i_dummy_0,
         serial_data_out         => open,
               
         -- MiSTer's save states & rewind feature: not supported on MEGA65
         cart_ram_size           => i_dummy_8bit_0,
         save_state              => i_dummy_0,
         load_state              => i_dummy_0,
         sleep_savestate         => open,
         savestate_number        => i_dummy_2bit_0,               
         SaveStateExt_Din        => open, 
         SaveStateExt_Adr        => open, 
         SaveStateExt_wren       => open,
         SaveStateExt_rst        => open, 
         SaveStateExt_Dout       => i_dummy_64bit_0,
         SaveStateExt_load       => open,         
         Savestate_CRAMAddr      => open,     
         Savestate_CRAMRWrEn     => open,    
         Savestate_CRAMWriteData => open,
         Savestate_CRAMReadData  => i_dummy_8bit_0,                   
         SAVE_out_Din            => open,   
         SAVE_out_Dout           => i_dummy_64bit_0,
         SAVE_out_Adr            => open,   
         SAVE_out_rnw            => open,   
         SAVE_out_ena            => open,   
         SAVE_out_done           => i_dummy_0,               
         rewind_on               => i_dummy_0,
         rewind_active           => i_dummy_0
      );

   -- Speed control is mainly a clock divider and it also manages pause/resume/fast-forward/etc.
   gb_clk_ctrl : entity work.speedcontrol
      port map
      (
         clk_sys                 => main_clk,
         pause                   => qngbc_pause,
         speedup                 => '0',
         cart_act                => cart_rd or cart_wr,
         HDMA_on                 => HDMA_on,
         ce                      => sc_ce,
         ce_2x                   => sc_ce_2x,
         refresh                 => open,
         ff_on                   => open         
      );
      
   -- Memory Bank Controller (MBC)
   gb_mbc : entity work.mbc
      port map
      (
         -- Game Boy's clock and reset
         clk_sys                 => main_clk,
         ce_cpu2x                => sc_ce_2x,
         reset                   => qngbc_reset,
               
         -- Game Boy's cartridge interface
         cart_addr               => cart_addr,
         cart_rd                 => cart_rd,
         cart_wr                 => cart_wr,
         cart_do                 => cart_do,
         cart_di                 => cart_di,
         
         -- Cartridge ROM interface
         rom_addr                => cartrom_addr,
         rom_rd                  => cartrom_rd,
         rom_data                => cartrom_data,
         
         -- Cartridge RAM interface
         ram_addr                => cartram_addr, 
         ram_rd                  => cartram_rd, 
         ram_wr                  => cartram_wr, 
         ram_do                  => cartram_data_out,
         ram_di                  => cartram_data_in,
                     
         -- Cartridge flags
         cart_mbc_type           => cart_mbc_type,
         cart_rom_size           => cart_rom_size,
         cart_ram_size           => cart_ram_size                  
      );
      
   -- Convert the Game Boy's PCM output to pulse density modulation
   -- TODO: Is this component configured correctly when it comes to clock speed, constants used within
   -- the component, subtracting 32768 while converting to signed, etc.
   pcm2pdm : entity work.pcm_to_pdm
      port map
      (
         cpuclock       => qnice_clk,
         pcm_left       => signed(signed(pcm_audio_left) - 32768),
         pcm_right      => signed(signed(pcm_audio_right) - 32768),
         pdm_left       => pwm_l,
         pdm_right      => pwm_r,
         audio_mode     => '0'
      ); 
                
   -- BIOS ROM / BOOT ROM
   bios_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH     => 12,
         DATA_WIDTH     => 8,
         ROM_PRELOAD    => true,       -- load default ROM in case no other ROM is on the SD card 
         ROM_FILE       => GBC_ROM,
         FALLING_B      => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC ROM interface
         clock_a        => main_clk,
         address_a      => gbc_bios_addr,
         q_a            => gbc_bios_data, 
         
         -- QNICE RAM interface 
         clock_b        => qnice_clk,
         address_b      => qngbc_bios_addr,
         data_b         => qngbc_bios_data_in,
         wren_b         => qngbc_bios_we,
         q_b            => qngbc_bios_data_out         
      );
     
   -- Cartridge ROM: modelled as a dual port dual clock RAM so that QNICE can fill it and Game Boy can read it
   game_cart_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH        => CART_ROM_WIDTH,
         DATA_WIDTH        => 8,
         LATCH_ADDR_A      => true,       -- the gbc core expects that the RAM latches the address on cart_rd
         FALLING_B         => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC Game Cartridge ROM Interface
         clock_a           => main_clk,
         address_a         => cartrom_addr(CART_ROM_WIDTH - 1 downto 0),
         do_latch_addr_a   => cartrom_rd,
         q_a               => cartrom_data,
         
         -- QNICE RAM interface
         clock_b           => qnice_clk,
         address_b         => qngbc_cart_addr(CART_ROM_WIDTH - 1 downto 0),
         data_b            => qngbc_cart_data_in,
         wren_b            => qngbc_cart_we,
         q_b               => qngbc_cart_data_out  
      );
      
   -- Cartridge RAM
   game_cart_ram : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH        => CART_RAM_WIDTH,
         DATA_WIDTH        => 8
      )
      port map
      (
         clock_a           => main_clk,
         address_a         => cartram_addr(CART_RAM_WIDTH - 1 downto 0),
         data_a            => cartram_data_in,
         wren_a            => cartram_wr,
         q_a               => cartram_data_out
      );

   -- Dual clock & dual port RAM that acts as framebuffer: the LCD display of the gameboy is
   -- written here by the GB core (using its local clock) and the VGA/HDMI display is being fed
   -- using the pixel clock
   frame_buffer : entity work.dualport_2clk_ram
      generic map
      ( 
         ADDR_WIDTH   => 15,
         MAXIMUM_SIZE => GB_DX * GB_DY, -- we do not need 2^15 x 24bit, but just (GB_DX * GB_DY) x 24bit
         DATA_WIDTH   => 24
      )
      port map
      (
         clock_a      => main_clk,
         address_a    => std_logic_vector(to_unsigned(pixel_out_ptr, 15)),
         data_a       => pixel_out_data,
         wren_a       => pixel_out_we,
         q_a          => open,
         
         clock_b      => vga_pixelclk,
         address_b    => std_logic_vector(to_unsigned(vga_row_next * GB_DX + vga_col_next, 15)),
         data_b       => (others => '0'),
         wren_b       => '0',
         q_b          => frame_buffer_data
      );

   -- Scaler: 160 x 144 => 4x => 640 x 576
   -- Scaling by 4 is a convenient special case: We just need to use a SHR operation.
   -- We are doing this by taking the bits "9 downto 2" from the current column and row.
   -- This is a hardcoded and very fast operation.
   scaler : process(vga_col, vga_row)
      variable src_x: std_logic_vector(9 downto 0);
      variable src_y: std_logic_vector(9 downto 0);
      variable dst_x: std_logic_vector(7 downto 0);
      variable dst_y: std_logic_vector(7 downto 0);
      variable dst_x_i: integer range 0 to GB_DX - 1;
      variable dst_y_i: integer range 0 to GB_DY - 1;
      variable nextrow: integer range 0 to GB_DY - 1;
   begin    
      src_x    := std_logic_vector(to_unsigned(vga_col, 10));
      src_y    := std_logic_vector(to_unsigned(vga_row, 10));      
      dst_x    := src_x(9 downto 2);
      dst_y    := src_y(9 downto 2);
      dst_x_i  := to_integer(unsigned(dst_x));
      dst_y_i  := to_integer(unsigned(dst_y));
      nextrow  := dst_y_i + 1; 
            
      -- The dual port & dual clock RAM needs one clock cycle to provide the data. Therefore we need
      -- to always address one pixel ahead of were we currently stand      
      if dst_x_i < GB_DX - 1 then
         vga_col_next <= dst_x_i + 1;
         vga_row_next <= dst_y_i;
      else
         vga_col_next <= 0;
         if nextrow < GB_DY then
            vga_row_next <= nextrow;
         else
            vga_row_next <= 0;
         end if;
      end if;      
   end process;  
      
   -- Generate the signals necessary to store the LCD output into the frame buffer
   -- This process is heavily inspired and in part a 1-to-1 translation of portions of MiSTer's lcd.v
   lcd_to_pixels : process(main_clk, sc_ce, lcd_clkena, lcd_r_blank_de)
      variable r5, g5, b5                : unsigned(4 downto 0);
      variable r8, g8, b8                : std_logic_vector(7 downto 0);
      variable r10, g10, b10             : unsigned(9 downto 0);
      variable r10_min, g10_min, b10_min : unsigned(9 downto 0);
      variable gray                      : unsigned(7 downto 0);
      variable data                      : std_logic_vector(14 downto 0);
      variable pixel_we                  : std_logic;
   begin
      pixel_we := sc_ce and (lcd_clkena or lcd_r_blank_de);  
      if rising_edge(main_clk) then
         pixel_out_we <= pixel_we;

         if lcd_on = '0' or lcd_mode = "01" then
            lcd_r_off <= '1';
         else
            lcd_r_off <= '0';
         end if;
         
         if lcd_on = '0' and lcd_r_blank_output = '1' and lcd_r_blank_hcnt < GB_DX and lcd_r_blank_vcnt < GB_DY then
            lcd_r_blank_de <= '1';
         else
            lcd_r_blank_de <= '0';
         end if;
         
         if pixel_we = '1' then
            pixel_out_ptr <= pixel_out_ptr + 1;
         end if;

         lcd_r_old_off <= lcd_r_off;
         if (lcd_r_old_off xor lcd_r_off) = '1' then
            pixel_out_ptr <= 0;
         end if;
         
         lcd_r_old_on <= lcd_on;
         if lcd_r_old_on = '1' and lcd_on = '0' and lcd_r_blank_output = '0' then
            lcd_r_blank_output <= '1';
            lcd_r_blank_hcnt <= 0;
            lcd_r_blank_vcnt <= 0;
         end if;

         -- regenerate LCD timings for filling with blank color when LCD is off
         if sc_ce = '1' and lcd_on = '0' and lcd_r_blank_output = '1' then
            lcd_r_blank_data <= lcd_data;
            lcd_r_blank_hcnt <= lcd_r_blank_hcnt + 1;
            if lcd_r_blank_hcnt = 455 then
               lcd_r_blank_hcnt <= 0;
               lcd_r_blank_vcnt <= lcd_r_blank_vcnt + 1;
               if lcd_r_blank_vcnt = 153 then
                  lcd_r_blank_vcnt <= 0;
                  pixel_out_ptr <= 0;
               end if;
            end if;
         end if;

         -- output 1 blank frame until VSync after LCD is enabled
         lcd_r_old_vs <= lcd_vsync;
         if lcd_r_old_vs = '0' and lcd_vsync = '1' and lcd_r_blank_output = '1' then
            lcd_r_blank_output <= '0';
         end if;
                  
         if lcd_on = '1' and lcd_r_blank_output = '1' then
            data := lcd_r_blank_data;
         else
            data := lcd_data;
         end if;
                                                                        
         -- grayscale values taken from MiSTer's lcd.v
         if (qngbc_color = '0') then
            case (data(1 downto 0)) is            
               when "00"   => gray := to_unsigned(252, 8);
               when "01"   => gray := to_unsigned(168, 8);
               when "10"   => gray := to_unsigned(96, 8);
               when "11"   => gray := x"00";
               when others => gray := x"00";
            end case;
            pixel_out_data <= std_logic_vector(gray) & std_logic_vector(gray) & std_logic_vector(gray);
         else
            -- Game Boy's color output is only 5-bit
            r5 := unsigned(data(4 downto 0));
            g5 := unsigned(data(9 downto 5));
            b5 := unsigned(data(14 downto 10));

            -- color grading / lcd emulation, taken from:
            -- https://web.archive.org/web/20210223205311/https://byuu.net/video/color-emulation/
            --
            -- R = (r * 26 + g *  4 + b *  2);
            -- G = (         g * 24 + b *  8);
            -- B = (r *  6 + g *  4 + b * 22);
            -- R = min(960, R) >> 2;
            -- G = min(960, G) >> 2;
            -- B = min(960, B) >> 2;               

            r10 := (r5 * 26) + (g5 *  4) + (b5 *  2);
            g10 :=             (g5 * 24) + (b5 *  8);
            b10 := (r5 *  6) + (g5 *  4) + (b5 * 22);
            
            r10_min := MINIMUM(960, r10); -- just for being on the safe side, we are using separate vars. for the MINIMUM
            g10_min := MINIMUM(960, g10);
            b10_min := MINIMUM(960, b10);
                        
            -- fully saturated color mode (raw rgb): repeat bit pattern to convert 5-bit color to 8-bit color according to byuu.net
            if qngbc_color_mode = '0' then
               r8 := std_logic_vector(r5 & r5(4 downto 2));
               g8 := std_logic_vector(g5 & g5(4 downto 2));
               b8 := std_logic_vector(b5 & b5(4 downto 2)); 
               
            -- LCD Emulation mode according to byuu.net                      
            else
               r8 := std_logic_vector(r10_min(9 downto 2)); -- taking 9 downto 2 equals >> 2
               g8 := std_logic_vector(g10_min(9 downto 2));
               b8 := std_logic_vector(b10_min(9 downto 2));
            end if;

            pixel_out_data <= r8 & g8 & b8;
         end if;         
      end if;
   end process; 
                          
   -- MEGA65 keyboard and joystick controller
   kbd : entity work.keyboard
      generic map
      (
         CLOCK_SPEED       => GB_CLK_SPEED
      )
      port map
      (
         clk               => main_clk,
         kio8              => kb_io0,
         kio9              => kb_io1,
         kio10             => kb_io2,
         joystick          => m65_joystick,
         joy_map           => qngbc_joy_map,
         
         p54               => joypad_p54,
         joypad            => joypad_data_i,
         full_matrix       => qngbc_keyb_matrix
      );
   
   -- debouncer for the RESET button as well as for the joysticks:
   -- 40ms for the RESET button
   -- 5ms for any joystick direction
   -- 1ms for the fire button
   do_dbnce_reset_n : entity work.debounce
      generic map(clk_freq => GB_CLK_SPEED, stable_time => 40)
      port map (clk => main_clk, reset_n => '1', button => RESET_N, result => dbnce_reset_n);
   do_dbnce_joysticks : entity work.debouncer
      generic map
      (
         CLK_FREQ             => GB_CLK_SPEED
      )
      port map
      (
         clk                  => main_clk,
         reset_n              => RESET_N,

         joy_1_up_n           => joy_1_up_n,
         joy_1_down_n         => joy_1_down_n, 
         joy_1_left_n         => joy_1_left_n, 
         joy_1_right_n        => joy_1_right_n, 
         joy_1_fire_n         => joy_1_fire_n, 
           
         dbnce_joy1_up_n      => dbnce_joy1_up_n,
         dbnce_joy1_down_n    => dbnce_joy1_down_n,
         dbnce_joy1_left_n    => dbnce_joy1_left_n,
         dbnce_joy1_right_n   => dbnce_joy1_right_n,
         dbnce_joy1_fire_n    => dbnce_joy1_fire_n,
         
         joy_2_up_n           => joy_2_up_n,
         joy_2_down_n         => joy_2_down_n, 
         joy_2_left_n         => joy_2_left_n, 
         joy_2_right_n        => joy_2_right_n, 
         joy_2_fire_n         => joy_2_fire_n, 
           
         dbnce_joy2_up_n      => dbnce_joy2_up_n,
         dbnce_joy2_down_n    => dbnce_joy2_down_n,
         dbnce_joy2_left_n    => dbnce_joy2_left_n,
         dbnce_joy2_right_n   => dbnce_joy2_right_n,
         dbnce_joy2_fire_n    => dbnce_joy2_fire_n         
      );
      
   -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   m65_joystick <= (dbnce_joy1_fire_n  and dbnce_joy2_fire_n) & 
                   (dbnce_joy1_up_n    and dbnce_joy2_up_n)   &
                   (dbnce_joy1_down_n  and dbnce_joy2_down_n) &
                   (dbnce_joy1_left_n  and dbnce_joy2_left_n) &
                   (dbnce_joy1_right_n and dbnce_joy2_right_n);

   -- SVGA mode 800 x 600 @ 60 Hz  
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)      
   -- Timings taken from http://tinyvga.com/vga-timing/800x600@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         h_pixels    => VGA_DX,           -- horiztonal display width in pixels
         v_pixels    => VGA_DY,           -- vertical display width in rows
         
         h_pulse     => 128,              -- horiztonal sync pulse width in pixels
         h_bp        => 88,               -- horiztonal back porch width in pixels
         h_fp        => 40,               -- horiztonal front porch width in pixels
         h_pol       => '1',              -- horizontal sync pulse polarity (1 = positive, 0 = negative)
         
         v_pulse     => 4,                -- vertical sync pulse width in rows
         v_bp        => 23,               -- vertical back porch width in rows
         v_fp        => 1,                -- vertical front porch width in rows
         v_pol       => '1'               -- vertical sync pulse polarity (1 = positive, 0 = negative)         
      )
      port map
      (
         pixel_clk   =>	vga_pixelclk,     -- pixel clock at frequency of VGA mode being used
         reset_n     => dbnce_reset_n,    -- active low asycnchronous reset
         h_sync      => vga_hs_int,       -- horiztonal sync pulse
         v_sync      => vga_vs_int,       -- vertical sync pulse
         disp_ena    => vga_disp_en,      -- display enable ('1' = display time, '0' = blanking time)
         column      => vga_col_raw,      -- horizontal pixel coordinate
         row         => vga_row_raw,      -- vertical pixel coordinate
         n_blank     => open,             -- direct blacking output to DAC
         n_sync      => open              -- sync-on-green output to DAC      
      );
      
   -- due to the latching of the VGA signals, we are one pixel off: compensate for that
   adjust_pixel_skew : process(vga_col_raw, vga_row_raw)
      variable nextrow  : integer range 0 to VGA_DY - 1;
   begin
      nextrow := vga_row_raw + 1;
      if vga_col_raw < VGA_DX - 1 then
         vga_col <= vga_col_raw + 1;
         vga_row <= vga_row_raw;
      else
         vga_col <= 0;
         if nextrow < VGA_DY then
            vga_row <= nextrow;
         else
            vga_row <= 0;
         end if;          
      end if;
   end process;      
   
   video_signal_latches : process(vga_pixelclk)
   begin
      if rising_edge(vga_pixelclk) then
         VGA_RED   <= (others => '0');
         VGA_BLUE  <= (others => '0');
         VGA_GREEN <= (others => '0');
   
         if vga_disp_en then
            -- Game Boy output
            -- TODO: Investigate, why the top/left pixel is always white and solve it;
            -- workaround in the meantime: the top/left pixel is set to be always black which seems to be less intrusive
            if (vga_col_raw > 0 or vga_row_raw > 0) and
               (vga_col_raw < GB_DX * GB_TO_VGA_SCALE and vga_row_raw < GB_DY * GB_TO_VGA_SCALE) then
               VGA_RED   <= frame_buffer_data(23 downto 16);
               VGA_GREEN <= frame_buffer_data(15 downto 8);
               VGA_BLUE  <= frame_buffer_data(7 downto 0);
            end if;       
         
            -- On-Screen-Menu (OSM) output
            if qngbc_osm_on then
               VGA_RED   <= qngbc_osm_rgb(23 downto 16);
               VGA_GREEN <= qngbc_osm_rgb(15 downto 8);
               VGA_BLUE  <= qngbc_osm_rgb(7 downto 0);                  
            end if;
         end if;
                        
         -- VGA horizontal and vertical sync         
         VGA_HS      <= vga_hs_int;
         VGA_VS      <= vga_vs_int;         
      end if;
   end process;
        
   -- make the VDAC output the image
   -- for some reason, the VDAC does not like non-zero values outside the visible window
   -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
   -- TODO: check that       
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';   
   vdac_clk <= not vga_pixelclk; -- inverting the clock leads to a sharper signal for some reason
   
   -- QNICE Co-Processor (System-on-a-Chip) for ROM loading and On-Screen-Menu
   QNICE_SOC : entity work.QNICE
      generic map
      (
         VGA_DX            => VGA_DX,
         VGA_DY            => VGA_DY,
         MAX_ROM           => SYS_ROM_MAX,
         MAX_RAM           => SYS_RAM_MAX
      )
      port map
      (
         CLK50             => qnice_clk,        -- 50 MHz clock                                    
         RESET_N           => RESET_N,
         
         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         UART_RXD          => UART_RXD,         -- receive data
         UART_TXD          => UART_TXD,         -- send data   
                 
         -- SD Card
         SD_RESET          => SD_RESET,
         SD_CLK            => SD_CLK,
         SD_MOSI           => SD_MOSI,
         SD_MISO           => SD_MISO,
         
         -- keyboard interface
         full_matrix       => qngbc_keyb_matrix,
         
         -- VGA interface
         pixelclock        => vga_pixelclk,
         vga_x             => vga_col,
         vga_y             => vga_row,
         vga_on            => qngbc_osm_on,
         vga_rgb           => qngbc_osm_rgb,
                  
         -- Game Boy control
         gbc_reset         => qngbc_reset,
         gbc_pause         => qngbc_pause,
         gbc_keyboard      => qngbc_keyboard,
         gbc_joystick      => qngbc_joystick,
         gbc_color         => qngbc_color,
         gbc_joy_map       => qngbc_joy_map,
         gbc_color_mode    => qngbc_color_mode, 
       
         -- Interfaces to Game Boy's RAMs (MMIO):
         gbc_bios_addr     => qngbc_bios_addr,
         gbc_bios_we       => qngbc_bios_we,
         gbc_bios_data_in  => qngbc_bios_data_in,
         gbc_bios_data_out => qngbc_bios_data_out,
         gbc_cart_addr     => qngbc_cart_addr,
         gbc_cart_we       => qngbc_cart_we,
         gbc_cart_data_in  => qngbc_cart_data_in,
         gbc_cart_data_out => qngbc_cart_data_out,
         
         -- Cartridge flags
         cart_cgb_flag     => cart_cgb_flag,
         cart_sgb_flag     => cart_sgb_flag,
         cart_mbc_type     => cart_mbc_type,
         cart_rom_size     => cart_rom_size,
         cart_ram_size     => cart_ram_size,
         cart_old_licensee => cart_old_licensee                   
      );   
end beh;
