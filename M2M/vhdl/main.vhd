library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
   generic (
      G_GB_CLK_SPEED         : integer;
      G_GB_DX                : integer;
      G_GB_DY                : integer
   );
   port (
      main_clk               : in  std_logic;
      reset_n                : in  std_logic;

      -- MEGA65 smart keyboard controller
      kb_io0                 : out std_logic;
      kb_io1                 : out std_logic;
      kb_io2                 : in  std_logic;

      -- Audio
      pwm_l                  : out std_logic;
      pwm_r                  : out std_logic;

      -- Game Boy BIOS
      main_gbc_bios_addr     : out std_logic_vector(11 downto 0);
      main_gbc_bios_data     : in  std_logic_vector(7 downto 0);

      -- LCD screen
      main_pixel_out_we      : out std_logic;
      main_pixel_out_ptr     : out integer range 0 to (G_GB_DX * G_GB_DY) - 1 := 0;
      main_pixel_out_data    : out std_logic_vector(23 downto 0) := (others => '0');

      -- cartridge flags
      main_cart_cgb_flag     : in  std_logic_vector(7 downto 0);
      main_cart_sgb_flag     : in  std_logic_vector(7 downto 0);
      main_cart_mbc_type     : in  std_logic_vector(7 downto 0);
      main_cart_rom_size     : in  std_logic_vector(7 downto 0);
      main_cart_ram_size     : in  std_logic_vector(7 downto 0);
      main_cart_old_licensee : in  std_logic_vector(7 downto 0);

      -- MBC signals
      main_cartrom_addr      : out std_logic_vector(22 downto 0);
      main_cartrom_rd        : out std_logic;
      main_cartrom_data      : in  std_logic_vector(7 downto 0);
      main_cartram_addr      : out std_logic_vector(16 downto 0);
      main_cartram_rd        : out std_logic;
      main_cartram_wr        : out std_logic;
      main_cartram_data_in   : out std_logic_vector(7 downto 0);
      main_cartram_data_out  : in  std_logic_vector(7 downto 0);

      -- QNICE control signals (see also gbc.asm for more details)
      main_qngbc_reset       : in  std_logic;
      main_qngbc_pause       : in  std_logic;
      main_qngbc_keyboard    : in  std_logic;
      main_qngbc_color       : in  std_logic;
      main_qngbc_joy_map     : in  std_logic_vector(1 downto 0);
      main_qngbc_color_mode  : in  std_logic;
      main_qngbc_keyb_matrix : out std_logic_vector(15 downto 0);

      -- Joysticks
      joy_1_up_n             : in std_logic;
      joy_1_down_n           : in std_logic;
      joy_1_left_n           : in std_logic;
      joy_1_right_n          : in std_logic;
      joy_1_fire_n           : in std_logic;

      joy_2_up_n             : in std_logic;
      joy_2_down_n           : in std_logic;
      joy_2_left_n           : in std_logic;
      joy_2_right_n          : in std_logic;
      joy_2_fire_n           : in std_logic
   );
end main;

architecture synthesis of main is

   -- ROM options
   constant GBC_OSS_ROM       : string := "../../BootROMs/cgb_boot.rom";   -- Alternative Open Source GBC ROM

   constant GBC_ROM           : string := GBC_OSS_ROM;   -- use Open Source ROMs by default

   -- Audio
   signal main_pcm_audio_left      : std_logic_vector(15 downto 0);
   signal main_pcm_audio_right     : std_logic_vector(15 downto 0);

   -- debounced signals for the reset button and the joysticks
   signal main_dbnce_reset_n       : std_logic;
   signal main_dbnce_joy1_up_n     : std_logic;
   signal main_dbnce_joy1_down_n   : std_logic;
   signal main_dbnce_joy1_left_n   : std_logic;
   signal main_dbnce_joy1_right_n  : std_logic;
   signal main_dbnce_joy1_fire_n   : std_logic;
   signal main_dbnce_joy2_up_n     : std_logic;
   signal main_dbnce_joy2_down_n   : std_logic;
   signal main_dbnce_joy2_left_n   : std_logic;
   signal main_dbnce_joy2_right_n  : std_logic;
   signal main_dbnce_joy2_fire_n   : std_logic;

   -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   signal main_m65_joystick        : std_logic_vector(4 downto 0);

   -- LCD interface
   signal main_lcd_clkena          : std_logic;
   signal main_lcd_data            : std_logic_vector(14 downto 0);
   signal main_lcd_mode            : std_logic_vector(1 downto 0);
   signal main_lcd_on              : std_logic;
   signal main_lcd_vsync           : std_logic;

   -- speed control
   signal main_sc_ce               : std_logic;
   signal main_sc_ce_2x            : std_logic;
   signal main_HDMA_on             : std_logic;

   -- cartridge signals
   signal main_cart_addr           : std_logic_vector(15 downto 0);
   signal main_cart_rd             : std_logic;
   signal main_cart_wr             : std_logic;
   signal main_cart_do             : std_logic_vector(7 downto 0);
   signal main_cart_di             : std_logic_vector(7 downto 0);

   signal main_isGBC_Game          : boolean;     -- current cartridge is dedicated GBC game
   signal main_isSGB_Game          : boolean;     -- current cartridge is dedicated SBC game

   -- joypad: p54 selects matrix entry and data contains either
   -- the direction keys or the other buttons
   signal main_joypad_p54          : std_logic_vector(1 downto 0);
   signal main_joypad_data         : std_logic_vector(3 downto 0);
   signal main_joypad_data_i       : std_logic_vector(3 downto 0);

   -- constants necessary due to Verilog in VHDL embedding
   -- otherwise, when wiring constants directly to the entity, then Vivado throws an error
   constant c_fast_boot       : std_logic := '0';
   constant c_joystick        : std_logic_vector(7 downto 0) := X"FF";
   constant c_dummy_0         : std_logic := '0';
   constant c_dummy_2bit_0    : std_logic_vector(1 downto 0) := (others => '0');
   constant c_dummy_8bit_0    : std_logic_vector(7 downto 0) := (others => '0');
   constant c_dummy_64bit_0   : std_logic_vector(63 downto 0) := (others => '0');
   constant c_dummy_129bit_0  : std_logic_vector(128 downto 0) := (others => '0');

   signal i_reset             : std_logic;

begin

   -- The actual machine (GB/GBC core)
   gameboy : entity work.gb
      port map
      (
         reset                   => main_qngbc_reset,      -- input

         clk_sys                 => main_clk,              -- input
         ce                      => main_sc_ce,            -- input
         ce_2x                   => main_sc_ce_2x,         -- input

         fast_boot               => c_fast_boot,           -- input
         joystick                => c_joystick,            -- input
         isGBC                   => main_qngbc_color,      -- input
         isGBC_game              => main_isGBC_Game,       -- input

         -- Cartridge interface: Connects with the Memory Bank Controller (MBC)
         cart_addr               => main_cart_addr,        -- output
         cart_rd                 => main_cart_rd,          -- output
         cart_wr                 => main_cart_wr,          -- output
         cart_di                 => main_cart_di,          -- input
         cart_do                 => main_cart_do,          -- output

         -- Game Boy BIOS interface
         gbc_bios_addr           => main_gbc_bios_addr,    -- output
         gbc_bios_do             => main_gbc_bios_data,    -- input

         -- audio
         audio_l                 => main_pcm_audio_left,   -- output
         audio_r                 => main_pcm_audio_right,  -- output

         -- lcd interface
         lcd_clkena              => main_lcd_clkena,       -- output
         lcd_data                => main_lcd_data,         -- output
         lcd_mode                => main_lcd_mode,         -- output
         lcd_on                  => main_lcd_on,           -- output
         lcd_vsync               => main_lcd_vsync,        -- output

         joy_p54                 => main_joypad_p54,       -- output
         joy_din                 => main_joypad_data,      -- input

         speed                   => open,   --GBC          -- output
         HDMA_on                 => main_HDMA_on,          -- output

         -- cheating/game code engine: not supported on MEGA65
         gg_reset                => i_reset,               -- input
         gg_en                   => c_dummy_0,             -- input
         gg_code                 => c_dummy_129bit_0,      -- input
         gg_available            => open,                  -- output

         -- serial port: not supported on MEGA65
         sc_int_clock2           => open,                  -- output
         serial_clk_in           => c_dummy_0,             -- input
         serial_clk_out          => open,                  -- output
         serial_data_in          => c_dummy_0,             -- input
         serial_data_out         => open,                  -- output

         -- MiSTer's save states & rewind feature: not supported on MEGA65
         cart_ram_size           => c_dummy_8bit_0,        -- input
         save_state              => c_dummy_0,             -- input
         load_state              => c_dummy_0,             -- input
         savestate_number        => c_dummy_2bit_0,        -- input
         sleep_savestate         => open,                  -- output
         state_loaded            => open,                  -- output
         SaveStateExt_Din        => open,                  -- output
         SaveStateExt_Adr        => open,                  -- output
         SaveStateExt_wren       => open,                  -- output
         SaveStateExt_rst        => open,                  -- output
         SaveStateExt_Dout       => c_dummy_64bit_0,       -- input
         SaveStateExt_load       => open,                  -- output
         Savestate_CRAMAddr      => open,                  -- output
         Savestate_CRAMRWrEn     => open,                  -- output
         Savestate_CRAMWriteData => open,                  -- output
         Savestate_CRAMReadData  => c_dummy_8bit_0,        -- input
         SAVE_out_Din            => open,                  -- output
         SAVE_out_Dout           => c_dummy_64bit_0,       -- input
         SAVE_out_Adr            => open,                  -- output
         SAVE_out_rnw            => open,                  -- output
         SAVE_out_ena            => open,                  -- output
         SAVE_out_done           => c_dummy_0,             -- input
         rewind_on               => c_dummy_0,             -- input
         rewind_active           => c_dummy_0              -- input
      ); -- gameboy : entity work.gb

   -- Speed control is mainly a clock divider and it also manages pause/resume/fast-forward/etc.
   gb_clk_ctrl : entity work.speedcontrol
      port map
      (
         clk_sys                 => main_clk,
         pause                   => main_qngbc_pause,
         speedup                 => '0',
         cart_act                => main_cart_rd or main_cart_wr,
         HDMA_on                 => main_HDMA_on,
         ce                      => main_sc_ce,
         ce_2x                   => main_sc_ce_2x,
         refresh                 => open,
         ff_on                   => open
      );

   -- Memory Bank Controller (MBC)
   gb_mbc : entity work.mbc
      port map
      (
         -- Game Boy's clock and reset
         clk_sys                 => main_clk,                  -- input
         ce_cpu2x                => main_sc_ce_2x,             -- input
         reset                   => main_qngbc_reset,          -- input

         -- Game Boy's cartridge interface
         cart_addr               => main_cart_addr,            -- input
         cart_rd                 => main_cart_rd,              -- input
         cart_wr                 => main_cart_wr,              -- input
         cart_do                 => main_cart_do,              -- input
         cart_di                 => main_cart_di,              -- output

         -- Cartridge ROM interface
         rom_addr                => main_cartrom_addr,         -- output
         rom_rd                  => main_cartrom_rd,           -- output
         rom_data                => main_cartrom_data,         -- input

         -- Cartridge RAM interface
         ram_addr                => main_cartram_addr,         -- output
         ram_rd                  => main_cartram_rd,           -- output
         ram_wr                  => main_cartram_wr,           -- output
         ram_do                  => main_cartram_data_out,     -- input
         ram_di                  => main_cartram_data_in,      -- output

         -- Cartridge flags
         cart_mbc_type           => main_cart_mbc_type,        -- input
         cart_rom_size           => main_cart_rom_size,        -- input
         cart_ram_size           => main_cart_ram_size         -- input
      ); -- gb_mbc : entity work.mbc


   -- Generate the signals necessary to store the LCD output into the frame buffer
   -- This process is heavily inspired and in part a 1-to-1 translation of portions of MiSTer's lcd.v

   i_lcd_to_pixels : entity work.lcd_to_pixels
      port map (
         clk_i                      => main_clk,
         sc_ce_i                    => main_sc_ce,
         qngbc_color_i              => main_qngbc_color,
         qngbc_color_mode_i         => main_qngbc_color_mode,
         lcd_clkena_i               => main_lcd_clkena,
         lcd_data_i                 => main_lcd_data,
         lcd_mode_i                 => main_lcd_mode,
         lcd_on_i                   => main_lcd_on,
         lcd_vsync_i                => main_lcd_vsync,
         pixel_out_we_o             => main_pixel_out_we,
         pixel_out_ptr_o            => main_pixel_out_ptr,
         pixel_out_data_o           => main_pixel_out_data
      ); -- i_lcd_to_pixels : entity work.lcd_to_pixels


   -- MEGA65 keyboard and joystick controller
   kbd : entity work.keyboard
      generic map
      (
         CLOCK_SPEED             => G_GB_CLK_SPEED
      )
      port map
      (
         clk                     => main_clk,
         kio8                    => kb_io0,
         kio9                    => kb_io1,
         kio10                   => kb_io2,
         joystick                => main_m65_joystick,
         joy_map                 => main_qngbc_joy_map,

         p54                     => main_joypad_p54,
         joypad                  => main_joypad_data_i,
         full_matrix             => main_qngbc_keyb_matrix
      ); -- kbd : entity work.keyboard


   -- debouncer for the RESET button as well as for the joysticks:
   -- 40ms for the RESET button
   -- 5ms for any joystick direction
   -- 1ms for the fire button
   do_dbnce_reset_n : entity work.debounce
      generic map(clk_freq => G_GB_CLK_SPEED, stable_time => 40)
      port map (clk => main_clk, reset_n => '1', button => RESET_N, result => main_dbnce_reset_n);
   do_dbnce_joysticks : entity work.debouncer
      generic map
      (
         CLK_FREQ                => G_GB_CLK_SPEED
      )
      port map
      (
         clk                     => main_clk,
         reset_n                 => RESET_N,

         joy_1_up_n              => joy_1_up_n,
         joy_1_down_n            => joy_1_down_n,
         joy_1_left_n            => joy_1_left_n,
         joy_1_right_n           => joy_1_right_n,
         joy_1_fire_n            => joy_1_fire_n,

         dbnce_joy1_up_n         => main_dbnce_joy1_up_n,
         dbnce_joy1_down_n       => main_dbnce_joy1_down_n,
         dbnce_joy1_left_n       => main_dbnce_joy1_left_n,
         dbnce_joy1_right_n      => main_dbnce_joy1_right_n,
         dbnce_joy1_fire_n       => main_dbnce_joy1_fire_n,

         joy_2_up_n              => joy_2_up_n,
         joy_2_down_n            => joy_2_down_n,
         joy_2_left_n            => joy_2_left_n,
         joy_2_right_n           => joy_2_right_n,
         joy_2_fire_n            => joy_2_fire_n,

         dbnce_joy2_up_n         => main_dbnce_joy2_up_n,
         dbnce_joy2_down_n       => main_dbnce_joy2_down_n,
         dbnce_joy2_left_n       => main_dbnce_joy2_left_n,
         dbnce_joy2_right_n      => main_dbnce_joy2_right_n,
         dbnce_joy2_fire_n       => main_dbnce_joy2_fire_n
      ); -- do_dbnce_joysticks : entity work.debouncer

   -- Convert the Game Boy's PCM output to pulse density modulation
   -- TODO: Is this component configured correctly when it comes to clock speed, constants used within
   -- the component, subtracting 32768 while converting to signed, etc.
   pcm2pdm : entity work.pcm_to_pdm
      port map
      (
         cpuclock                => main_clk,
         pcm_left                => signed(signed(main_pcm_audio_left) - 32768),
         pcm_right               => signed(signed(main_pcm_audio_right) - 32768),
         pdm_left                => pwm_l,
         pdm_right               => pwm_r,
         audio_mode              => '0'
      );

   -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   main_m65_joystick <= (main_dbnce_joy1_fire_n  and main_dbnce_joy2_fire_n) &
                        (main_dbnce_joy1_up_n    and main_dbnce_joy2_up_n)   &
                        (main_dbnce_joy1_down_n  and main_dbnce_joy2_down_n) &
                        (main_dbnce_joy1_left_n  and main_dbnce_joy2_left_n) &
                        (main_dbnce_joy1_right_n and main_dbnce_joy2_right_n);

   -- Switch keyboard and joystick on/off according to the QNICE control and status register (see gbc.asm)
   -- joypad_data is active low
   main_joypad_data <= main_joypad_data_i when main_qngbc_keyboard = '1' else (others => '1');

   -- Cartridge header flags
   -- Infos taken from: https://gbdev.io/pandocs/#the-cartridge-header and from MiSTer's mbc.sv
   main_isGBC_Game <= true when main_cart_cgb_flag = x"80" or main_cart_cgb_flag = x"C0" else false;
   main_isSGB_Game <= true when main_cart_sgb_flag = x"03" and main_cart_old_licensee = x"33" else false;

end synthesis;

