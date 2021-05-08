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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

Library xpm;
use xpm.vcomponents.all;

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

-- Constants for VGA output
constant FONT_DX           : integer := 16;
constant FONT_DY           : integer := 16;
constant CHARS_DX          : integer := VGA_DX / FONT_DX;
constant CHARS_DY          : integer := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE     : integer := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH   : integer := f_log2(CHAR_MEM_SIZE);

-- clocks
signal main_clk            : std_logic;               -- Game Boy core main clock @ 33.554432 MHz
signal vga_pixelclk        : std_logic;               -- SVGA mode 800 x 600 @ 60 Hz: 40.00 MHz
signal qnice_clk           : std_logic;               -- QNICE main clock @ 50 MHz


---------------------------------------------------------------------------------------------
-- main_clk
---------------------------------------------------------------------------------------------

-- debounced signals for the reset button and the joysticks
signal main_dbnce_reset_n       : std_logic;

-- Game Boy
signal main_gbc_bios_addr       : std_logic_vector(11 downto 0);
signal main_gbc_bios_data       : std_logic_vector(7 downto 0);

-- LCD interface
signal main_pixel_out_we        : std_logic;
signal main_pixel_out_ptr       : integer range 0 to (GB_DX * GB_DY) - 1 := 0;
signal main_pixel_out_data      : std_logic_vector(23 downto 0) := (others => '0');

-- cartridge flags
signal main_cart_cgb_flag       : std_logic_vector(7 downto 0);
signal main_cart_sgb_flag       : std_logic_vector(7 downto 0);
signal main_cart_mbc_type       : std_logic_vector(7 downto 0);
signal main_cart_rom_size       : std_logic_vector(7 downto 0);
signal main_cart_ram_size       : std_logic_vector(7 downto 0);
signal main_cart_old_licensee   : std_logic_vector(7 downto 0);

-- MBC signals
signal main_cartrom_addr        : std_logic_vector(22 downto 0);
signal main_cartrom_rd          : std_logic;
signal main_cartrom_data        : std_logic_vector(7 downto 0);
signal main_cartram_addr        : std_logic_vector(16 downto 0);
signal main_cartram_rd          : std_logic;
signal main_cartram_wr          : std_logic;
signal main_cartram_data_in     : std_logic_vector(7 downto 0);
signal main_cartram_data_out    : std_logic_vector(7 downto 0);

-- QNICE control signals (see also gbc.asm for more details)
signal main_qngbc_reset         : std_logic;
signal main_qngbc_pause         : std_logic;
signal main_qngbc_keyboard      : std_logic;
signal main_qngbc_joystick      : std_logic;
signal main_qngbc_color         : std_logic;
signal main_qngbc_joy_map       : std_logic_vector(1 downto 0);
signal main_qngbc_color_mode    : std_logic;
signal main_qngbc_keyb_matrix   : std_logic_vector(15 downto 0);


---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

-- QNICE control signals (see also gbc.asm for more details)
signal qnice_qngbc_reset          : std_logic;
signal qnice_qngbc_pause          : std_logic;
signal qnice_qngbc_keyboard       : std_logic;
signal qnice_qngbc_joystick       : std_logic;
signal qnice_qngbc_color          : std_logic;
signal qnice_qngbc_joy_map        : std_logic_vector(1 downto 0);
signal qnice_qngbc_color_mode     : std_logic;
signal qnice_qngbc_keyb_matrix    : std_logic_vector(15 downto 0);

-- cartridge flags
signal qnice_cart_cgb_flag        : std_logic_vector(7 downto 0);
signal qnice_cart_sgb_flag        : std_logic_vector(7 downto 0);
signal qnice_cart_mbc_type        : std_logic_vector(7 downto 0);
signal qnice_cart_rom_size        : std_logic_vector(7 downto 0);
signal qnice_cart_ram_size        : std_logic_vector(7 downto 0);
signal qnice_cart_old_licensee    : std_logic_vector(7 downto 0);

-- QNICE control signals (see also gbc.asm for more details)
signal qnice_qngbc_bios_addr      : std_logic_vector(11 downto 0);
signal qnice_qngbc_bios_we        : std_logic;
signal qnice_qngbc_bios_data_in   : std_logic_vector(7 downto 0);
signal qnice_qngbc_bios_data_out  : std_logic_vector(7 downto 0);
signal qnice_qngbc_cart_addr      : std_logic_vector(22 downto 0);
signal qnice_qngbc_cart_we        : std_logic;
signal qnice_qngbc_cart_data_in   : std_logic_vector(7 downto 0);
signal qnice_qngbc_cart_data_out  : std_logic_vector(7 downto 0);

-- On-Screen-Menu (OSM)
signal qnice_osm_vram_addr        : std_logic_vector(VRAM_ADDR_WIDTH - 1 downto 0);
signal qnice_osm_vram_data        : std_logic_vector(7 downto 0);
signal qnice_osm_vram_attr_data   : std_logic_vector(7 downto 0);
signal qnice_osm_font_addr        : std_logic_vector(11 downto 0);
signal qnice_osm_font_data        : std_logic_vector(15 downto 0);
signal qnice_osm_cfg_enable       : std_logic;
signal qnice_osm_cfg_xy           : std_logic_vector(15 downto 0);
signal qnice_osm_cfg_dxdy         : std_logic_vector(15 downto 0);
signal qnice_osm_x1, qnice_osm_x2 : integer range 0 to CHARS_DX - 1;
signal qnice_osm_y1, qnice_osm_y2 : integer range 0 to CHARS_DY - 1;

signal qnice_vram_addr            : std_logic_vector(15 downto 0);
signal qnice_vram_data_out        : std_logic_vector(15 downto 0);
signal qnice_vram_attr_we         : std_logic;
signal qnice_vram_attr_data_out_i : std_logic_vector(7 downto 0);
signal qnice_vram_we              : std_logic;
signal qnice_vram_data_out_i      : std_logic_vector(7 downto 0);


---------------------------------------------------------------------------------------------
-- vga_pixelclk
---------------------------------------------------------------------------------------------

-- Core frame buffer
signal vga_core_vram_addr  : std_logic_vector(14 downto 0);
signal vga_core_vram_data  : std_logic_vector(23 downto 0);

-- On-Screen-Menu (OSM)
signal vga_osm_cfg_enable : std_logic;
signal vga_osm_cfg_xy     : std_logic_vector(15 downto 0);
signal vga_osm_cfg_dxdy   : std_logic_vector(15 downto 0);
signal vga_osm_vram_addr  : std_logic_vector(15 downto 0);
signal vga_osm_vram_data  : std_logic_vector(7 downto 0);
signal vga_osm_vram_attr  : std_logic_vector(7 downto 0);

-- constants necessary due to Verilog in VHDL embedding
-- otherwise, when wiring constants directly to the entity, then Vivado throws an error
constant c_fast_boot      : std_logic := '0';
constant c_joystick       : std_logic_vector(7 downto 0) := X"FF";
constant c_dummy_0        : std_logic := '0';
constant c_dummy_2bit_0   : std_logic_vector(1 downto 0) := (others => '0');
constant c_dummy_8bit_0   : std_logic_vector(7 downto 0) := (others => '0');
constant c_dummy_64bit_0  : std_logic_vector(63 downto 0) := (others => '0');
constant c_dummy_129bit_0 : std_logic_vector(128 downto 0) := (others => '0');

signal i_reset            : std_logic;


begin

   -- MMCME2_ADV clock generators:
   --    Core clock:          33.554432 MHz
   --    Pixelclock:          40 MHz
   --    QNICE co-processor:  50 MHz
   clk_gen : entity work.clk
      port map
      (
         sys_clk_i  => CLK,
         gbmain_o   => main_clk,         -- Game Boy's 33.554432 MHz main clock
         qnice_o    => qnice_clk,        -- QNICE's 50 MHz main clock
         pixelclk_o => vga_pixelclk      -- 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
      );

   -- TODO: Achieve timing closure also when using the debouncer
   --i_reset           <= not dbnce_reset_n;
   i_reset <= not RESET_N; -- TODO/WARNING: might glitch


   ---------------------------------------------------------------------------------------------
   -- main_clk
   ---------------------------------------------------------------------------------------------

   i_main : entity work.main
      generic map (
         G_GB_CLK_SPEED         => GB_CLK_SPEED,
         G_GB_DX                => GB_DX,
         G_GB_DY                => GB_DY
      )
      port map (
         main_clk               => main_clk,
         reset_n                => reset_n,
         kb_io0                 => kb_io0,
         kb_io1                 => kb_io1,
         kb_io2                 => kb_io2,
         pwm_l                  => pwm_l,
         pwm_r                  => pwm_r,
         main_gbc_bios_addr     => main_gbc_bios_addr,
         main_gbc_bios_data     => main_gbc_bios_data,
         main_pixel_out_we      => main_pixel_out_we,
         main_pixel_out_ptr     => main_pixel_out_ptr,
         main_pixel_out_data    => main_pixel_out_data,
         main_cart_cgb_flag     => main_cart_cgb_flag,
         main_cart_sgb_flag     => main_cart_sgb_flag,
         main_cart_mbc_type     => main_cart_mbc_type,
         main_cart_rom_size     => main_cart_rom_size,
         main_cart_ram_size     => main_cart_ram_size,
         main_cart_old_licensee => main_cart_old_licensee,
         main_cartrom_addr      => main_cartrom_addr,
         main_cartrom_rd        => main_cartrom_rd,
         main_cartrom_data      => main_cartrom_data,
         main_cartram_addr      => main_cartram_addr,
         main_cartram_rd        => main_cartram_rd,
         main_cartram_wr        => main_cartram_wr,
         main_cartram_data_in   => main_cartram_data_in,
         main_cartram_data_out  => main_cartram_data_out,
         main_qngbc_reset       => main_qngbc_reset,
         main_qngbc_pause       => main_qngbc_pause,
         main_qngbc_keyboard    => main_qngbc_keyboard,
         main_qngbc_color       => main_qngbc_color,
         main_qngbc_joy_map     => main_qngbc_joy_map,
         main_qngbc_color_mode  => main_qngbc_color_mode,
         main_qngbc_keyb_matrix => main_qngbc_keyb_matrix,
         joy_1_up_n             => joy_1_up_n,
         joy_1_down_n           => joy_1_down_n,
         joy_1_left_n           => joy_1_left_n,
         joy_1_right_n          => joy_1_right_n,
         joy_1_fire_n           => joy_1_fire_n,
         joy_2_up_n             => joy_2_up_n,
         joy_2_down_n           => joy_2_down_n,
         joy_2_left_n           => joy_2_left_n,
         joy_2_right_n          => joy_2_right_n,
         joy_2_fire_n           => joy_2_fire_n
      ); -- i_main : entity work.main is


   ---------------------------------------------------------------------------------------------
   -- qnice_clk
   ---------------------------------------------------------------------------------------------

   -- QNICE Co-Processor (System-on-a-Chip) for ROM loading and On-Screen-Menu
   QNICE_SOC : entity work.QNICE
      generic map
      (
         CHARS_DX                => CHARS_DX,
         CHARS_DY                => CHARS_DY,
         MAX_ROM                 => SYS_ROM_MAX,
         MAX_RAM                 => SYS_RAM_MAX
      )
      port map
      (
         CLK50                   => qnice_clk,        -- 50 MHz clock      -- input
         RESET_N                 => RESET_N,                               -- input

         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         UART_RXD                => UART_RXD,         -- receive data      -- input
         UART_TXD                => UART_TXD,         -- send data         -- output

         -- SD Card
         SD_RESET                => SD_RESET,                              -- output
         SD_CLK                  => SD_CLK,                                -- output
         SD_MOSI                 => SD_MOSI,                               -- output
         SD_MISO                 => SD_MISO,                               -- input

         gbc_osm                 => qnice_osm_cfg_enable,                  -- output
         osm_xy                  => qnice_osm_cfg_xy,                      -- output
         osm_dxdy                => qnice_osm_cfg_dxdy,                    -- output
         vram_addr               => qnice_vram_addr,                       -- output
         vram_data_out           => qnice_vram_data_out,                   -- output
         vram_attr_we            => qnice_vram_attr_we,                    -- output
         vram_attr_data_out_i    => qnice_vram_attr_data_out_i,            -- input
         vram_we                 => qnice_vram_we,                         -- output
         vram_data_out_i         => qnice_vram_data_out_i,                 -- input

         -- keyboard interface
         full_matrix             => qnice_qngbc_keyb_matrix,               -- input

         -- Game Boy control
         gbc_reset               => qnice_qngbc_reset,                     -- output
         gbc_pause               => qnice_qngbc_pause,                     -- output
         gbc_keyboard            => qnice_qngbc_keyboard,                  -- output
         gbc_joystick            => qnice_qngbc_joystick,                  -- output
         gbc_color               => qnice_qngbc_color,                     -- output
         gbc_joy_map             => qnice_qngbc_joy_map,                   -- output
         gbc_color_mode          => qnice_qngbc_color_mode,                -- output

         -- Interfaces to Game Boy's RAMs (MMIO):
         gbc_bios_addr           => qnice_qngbc_bios_addr,                 -- output
         gbc_bios_we             => qnice_qngbc_bios_we,                   -- output
         gbc_bios_data_in        => qnice_qngbc_bios_data_in,              -- output
         gbc_bios_data_out       => qnice_qngbc_bios_data_out,             -- input
         gbc_cart_addr           => qnice_qngbc_cart_addr,                 -- output
         gbc_cart_we             => qnice_qngbc_cart_we,                   -- output
         gbc_cart_data_in        => qnice_qngbc_cart_data_in,              -- output
         gbc_cart_data_out       => qnice_qngbc_cart_data_out,             -- input

         -- Cartridge flags
         cart_cgb_flag           => qnice_cart_cgb_flag,                   -- output
         cart_sgb_flag           => qnice_cart_sgb_flag,                   -- output
         cart_mbc_type           => qnice_cart_mbc_type,                   -- output
         cart_rom_size           => qnice_cart_rom_size,                   -- output
         cart_ram_size           => qnice_cart_ram_size,                   -- output
         cart_old_licensee       => qnice_cart_old_licensee                -- output
      ); -- QNICE_SOC : entity work.QNICE


   ---------------------------------------------------------------------------------------------
   -- vga_pixelclk
   ---------------------------------------------------------------------------------------------

   i_vga : entity work.vga
      generic map (
         G_VGA_DX          => VGA_DX,
         G_VGA_DY          => VGA_DY,
         G_GB_DX           => GB_DX,
         G_GB_DY           => GB_DY,
         G_GB_TO_VGA_SCALE => GB_TO_VGA_SCALE
      )
      port map (
         clk_i                => vga_pixelclk,     -- pixel clock at frequency of VGA mode being used
         rst_i                => reset_n,          -- active low asycnchronous reset
         vga_osm_cfg_enable_i => vga_osm_cfg_enable,
         vga_osm_cfg_xy_i     => vga_osm_cfg_xy,
         vga_osm_cfg_dxdy_i   => vga_osm_cfg_dxdy,
         vga_osm_vram_addr_o  => vga_osm_vram_addr,
         vga_osm_vram_data_i  => vga_osm_vram_data,
         vga_osm_vram_attr_i  => vga_osm_vram_attr,
         vga_core_vram_addr_o => vga_core_vram_addr,
         vga_core_vram_data_i => vga_core_vram_data,
         vga_red_o            => vga_red,
         vga_green_o          => vga_green,
         vga_blue_o           => vga_blue,
         vga_hs_o             => vga_hs,
         vga_vs_o             => vga_vs,
         vdac_clk_o           => vdac_clk,
         vdac_sync_n_o        => vdac_sync_n,
         vdac_blank_n_o       => vdac_blank_n
      ); -- i_vga : entity work.vga


   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   i_qnice2main: xpm_cdc_array_single
      generic map (
         WIDTH => 56
      )
      port map (
         src_clk                => qnice_clk,
         src_in(0)              => qnice_qngbc_reset,
         src_in(1)              => qnice_qngbc_pause,
         src_in(2)              => qnice_qngbc_keyboard,
         src_in(3)              => qnice_qngbc_joystick,
         src_in(4)              => qnice_qngbc_color,
         src_in(6 downto 5)     => qnice_qngbc_joy_map,
         src_in(7)              => qnice_qngbc_color_mode,
         src_in(15 downto 8)    => qnice_cart_cgb_flag,
         src_in(23 downto 16)   => qnice_cart_sgb_flag,
         src_in(31 downto 24)   => qnice_cart_mbc_type,
         src_in(39 downto 32)   => qnice_cart_rom_size,
         src_in(47 downto 40)   => qnice_cart_ram_size,
         src_in(55 downto 48)   => qnice_cart_old_licensee,
         dest_clk               => main_clk,
         dest_out(0)            => main_qngbc_reset,
         dest_out(1)            => main_qngbc_pause,
         dest_out(2)            => main_qngbc_keyboard,
         dest_out(3)            => main_qngbc_joystick,
         dest_out(4)            => main_qngbc_color,
         dest_out(6 downto 5)   => main_qngbc_joy_map,
         dest_out(7)            => main_qngbc_color_mode,
         dest_out(15 downto 8)  => main_cart_cgb_flag,
         dest_out(23 downto 16) => main_cart_sgb_flag,
         dest_out(31 downto 24) => main_cart_mbc_type,
         dest_out(39 downto 32) => main_cart_rom_size,
         dest_out(47 downto 40) => main_cart_ram_size,
         dest_out(55 downto 48) => main_cart_old_licensee
      ); -- i_qnice2main: xpm_cdc_array_single

   i_main2qnice: xpm_cdc_array_single
      generic map (
         WIDTH => 16
      )
      port map (
         src_clk                => main_clk,
         src_in(15 downto 0)    => main_qngbc_keyb_matrix,
         dest_clk               => qnice_clk,
         dest_out(15 downto 0)  => qnice_qngbc_keyb_matrix
      ); -- i_main2qnice: xpm_cdc_array_single

   i_qnice2vga: xpm_cdc_array_single
      generic map (
         WIDTH => 33
      )
      port map (
         src_clk                => qnice_clk,
         src_in(15 downto 0)    => qnice_osm_cfg_xy,
         src_in(31 downto 16)   => qnice_osm_cfg_dxdy,
         src_in(32)             => qnice_osm_cfg_enable,
         dest_clk               => vga_pixelclk,
         dest_out(15 downto 0)  => vga_osm_cfg_xy,
         dest_out(31 downto 16) => vga_osm_cfg_dxdy,
         dest_out(32)           => vga_osm_cfg_enable
      ); -- i_qnice2vga: xpm_cdc_single
      

   -- BIOS ROM / BOOT ROM
   bios_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH  => 12,
         DATA_WIDTH  => 8,
         ROM_PRELOAD => true,       -- load default ROM in case no other ROM is on the SD card
         ROM_FILE    => GBC_ROM,
         FALLING_B   => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC ROM interface
         clock_a     => main_clk,
         address_a   => main_gbc_bios_addr,
         q_a         => main_gbc_bios_data,

         -- QNICE RAM interface
         clock_b     => qnice_clk,
         address_b   => qnice_qngbc_bios_addr,
         data_b      => qnice_qngbc_bios_data_in,
         wren_b      => qnice_qngbc_bios_we,
         q_b         => qnice_qngbc_bios_data_out
      ); -- bios_rom : entity work.dualport_2clk_ram


   -- Cartridge ROM: modelled as a dual port dual clock RAM so that QNICE can fill it and Game Boy can read it
   game_cart_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH      => CART_ROM_WIDTH,
         DATA_WIDTH      => 8,
         LATCH_ADDR_A    => true,       -- the gbc core expects that the RAM latches the address on cart_rd
         FALLING_B       => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC Game Cartridge ROM Interface
         clock_a         => main_clk,
         address_a       => main_cartrom_addr(CART_ROM_WIDTH - 1 downto 0),
         do_latch_addr_a => main_cartrom_rd,
         q_a             => main_cartrom_data,

         -- QNICE RAM interface
         clock_b         => qnice_clk,
         address_b       => qnice_qngbc_cart_addr(CART_ROM_WIDTH - 1 downto 0),
         data_b          => qnice_qngbc_cart_data_in,
         wren_b          => qnice_qngbc_cart_we,
         q_b             => qnice_qngbc_cart_data_out
      ); -- game_cart_rom : entity work.dualport_2clk_ram


   -- Cartridge RAM
   game_cart_ram : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH   => CART_RAM_WIDTH,
         DATA_WIDTH   => 8
      )
      port map
      (
         clock_a      => main_clk,
         address_a    => main_cartram_addr(CART_RAM_WIDTH - 1 downto 0),
         data_a       => main_cartram_data_in,
         wren_a       => main_cartram_wr,
         q_a          => main_cartram_data_out
      ); -- game_cart_ram : entity work.dualport_2clk_ram


   -- Dual clock & dual port RAM that acts as framebuffer: the LCD display of the gameboy is
   -- written here by the GB core (using its local clock) and the VGA/HDMI display is being fed
   -- using the pixel clock
   core_frame_buffer : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH   => 15,
         MAXIMUM_SIZE => GB_DX * GB_DY, -- we do not need 2^15 x 24bit, but just (GB_DX * GB_DY) x 24bit
         DATA_WIDTH   => 24
      )
      port map
      (
         clock_a      => main_clk,
         address_a    => std_logic_vector(to_unsigned(main_pixel_out_ptr, 15)),
         data_a       => main_pixel_out_data,
         wren_a       => main_pixel_out_we,
         q_a          => open,

         clock_b      => vga_pixelclk,
         address_b    => vga_core_vram_addr,
         data_b       => (others => '0'),
         wren_b       => '0',
         q_b          => vga_core_vram_data
      ); -- core_frame_buffer : entity work.dualport_2clk_ram

   -- Dual port & dual clock screen RAM / video RAM: contains the "ASCII" codes of the characters
   osm_vram : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         DATA_WIDTH   => 8,
         FALLING_A    => true              -- QNICE expects read/write to happen at the falling clock edge
      )
      port map
      (
         clock_a      => qnice_clk,
         address_a    => qnice_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         data_a       => qnice_vram_data_out(7 downto 0),
         wren_a       => qnice_vram_we,
         q_a          => qnice_vram_data_out_i,

         clock_b      => vga_pixelclk,
         address_b    => vga_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         q_b          => vga_osm_vram_data
      ); -- osm_vram : entity work.dualport_2clk_ram

   -- Dual port & dual clock attribute RAM: contains inverse attribute, light/dark attrib. and colors of the chars
   -- bit 7: 1=inverse
   -- bit 6: 1=dark, 0=bright
   -- bit 5: background red
   -- bit 4: background green
   -- bit 3: background blue
   -- bit 2: foreground red
   -- bit 1: foreground green
   -- bit 0: foreground blue
   osm_vram_attr : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH   => VRAM_ADDR_WIDTH,
         DATA_WIDTH   => 8,
         FALLING_A    => true
      )
      port map
      (
         clock_a      => qnice_clk,
         address_a    => qnice_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),
         data_a       => qnice_vram_data_out(7 downto 0),
         wren_a       => qnice_vram_attr_we,
         q_a          => qnice_vram_attr_data_out_i,

         clock_b      => vga_pixelclk,
         address_b    => vga_osm_vram_addr(VRAM_ADDR_WIDTH-1 downto 0),       -- same address as VRAM
         q_b          => vga_osm_vram_attr
      ); -- osm_vram_attr : entity work.dualport_2clk_ram

end beh;

