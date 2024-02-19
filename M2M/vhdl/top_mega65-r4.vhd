----------------------------------------------------------------------------------
-- Commodore 64 for MEGA65 (C64MEGA65)
--
-- MEGA65 R4 main file that contains the whole machine
--
-- based on C64_MiSTer by the MiSTer development team
-- port done by MJoergen and sy2002 in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity mega65_r4 is
port (
   -- Onboard crystal oscillator = 100 MHz
   clk_i                   : in    std_logic;

   -- Reset button on the side of the machine
   reset_button_i          : in    std_logic;      -- Active high

   -- USB-RS232 Interface
   uart_rxd_i              : in    std_logic;
   uart_txd_o              : out   std_logic;

   -- VGA via VDAC. U3 = ADV7125BCPZ170
   vga_red_o               : out   std_logic_vector(7 downto 0);
   vga_green_o             : out   std_logic_vector(7 downto 0);
   vga_blue_o              : out   std_logic_vector(7 downto 0);
   vga_hs_o                : out   std_logic;
   vga_vs_o                : out   std_logic;
   vga_scl_io              : inout std_logic;
   vga_sda_io              : inout std_logic;
   vdac_clk_o              : out   std_logic;
   vdac_sync_n_o           : out   std_logic;
   vdac_blank_n_o          : out   std_logic;
   vdac_psave_n_o          : out   std_logic;

   -- HDMI. U10 = PTN3363BSMP
   -- I2C address 0x40
   tmds_data_p_o           : out   std_logic_vector(2 downto 0);
   tmds_data_n_o           : out   std_logic_vector(2 downto 0);
   tmds_clk_p_o            : out   std_logic;
   tmds_clk_n_o            : out   std_logic;
   hdmi_hiz_en_o           : out   std_logic;   -- Connect to U10.HIZ_EN
   hdmi_ls_oe_n_o          : out   std_logic;   -- Connect to U10.OE#
   hdmi_hpd_i              : in    std_logic;   -- Connect to U10.HPD_SOURCE
   hdmi_scl_io             : inout std_logic;   -- Connect to U10.SCL_SOURCE
   hdmi_sda_io             : inout std_logic;   -- Connect to U10.SDA_SOURCE

   -- MEGA65 smart keyboard controller
   kb_io0_o                : out   std_logic;                 -- clock to keyboard
   kb_io1_o                : out   std_logic;                 -- data output to keyboard
   kb_io2_i                : in    std_logic;                 -- data input from keyboard
   kb_tck_o                : out   std_logic;
   kb_tdo_i                : in    std_logic;
   kb_tms_o                : out   std_logic;
   kb_tdi_o                : out   std_logic;
   kb_jtagen_o             : out   std_logic;

   -- Micro SD Connector (external slot at back of the cover)
   sd_reset_o              : out   std_logic;
   sd_clk_o                : out   std_logic;
   sd_mosi_o               : out   std_logic;
   sd_miso_i               : in    std_logic;
   sd_cd_i                 : in    std_logic;
   sd_d1_i                 : in    std_logic;
   sd_d2_i                 : in    std_logic;

   -- SD Connector (this is the slot at the bottom side of the case under the cover)
   sd2_reset_o             : out   std_logic;
   sd2_clk_o               : out   std_logic;
   sd2_mosi_o              : out   std_logic;
   sd2_miso_i              : in    std_logic;
   sd2_cd_i                : in    std_logic;
   sd2_wp_i                : in    std_logic;
   sd2_d1_i                : in    std_logic;
   sd2_d2_i                : in    std_logic;

   -- Audio DAC. U37 = AK4432VT
   -- I2C address 0x19
   audio_mclk_o            : out   std_logic;   -- Master Clock Input Pin,       12.288 MHz
   audio_bick_o            : out   std_logic;   -- Audio Serial Data Clock Pin,   3.072 MHz
   audio_sdti_o            : out   std_logic;   -- Audio Serial Data Input Pin,  16-bit LSB justified
   audio_lrclk_o           : out   std_logic;   -- Input Channel Clock Pin,      48.0 kHz
   audio_pdn_n_o           : out   std_logic;   -- Power-Down & Reset Pin
   audio_i2cfil_o          : out   std_logic;   -- I2C Interface Mode Select Pin
   audio_scl_io            : inout std_logic;   -- Control Data Clock Input Pin
   audio_sda_io            : inout std_logic;   -- Control Data Input/Output Pin

   -- Joysticks and Paddles
   fa_up_n_i               : in    std_logic;
   fa_down_n_i             : in    std_logic;
   fa_left_n_i             : in    std_logic;
   fa_right_n_i            : in    std_logic;
   fa_fire_n_i             : in    std_logic;
   fa_fire_n_o             : out   std_logic;   -- 0: Drive pin low (output). 1: Leave pin floating (input)
   fa_up_n_o               : out   std_logic;
   fa_left_n_o             : out   std_logic;
   fa_down_n_o             : out   std_logic;
   fa_right_n_o            : out   std_logic;
   fb_up_n_i               : in    std_logic;
   fb_down_n_i             : in    std_logic;
   fb_left_n_i             : in    std_logic;
   fb_right_n_i            : in    std_logic;
   fb_fire_n_i             : in    std_logic;
   fb_up_n_o               : out   std_logic;
   fb_down_n_o             : out   std_logic;
   fb_fire_n_o             : out   std_logic;
   fb_right_n_o            : out   std_logic;
   fb_left_n_o             : out   std_logic;

   -- Joystick power supply
   joystick_5v_disable_o   : out   std_logic;  -- 1: Disable 5V power supply to joysticks
   joystick_5v_powergood_i : in    std_logic;

   paddle_i                : in    std_logic_vector(3 downto 0);
   paddle_drain_o          : out   std_logic;

   -- HyperRAM. U29 = IS66WVH8M8DBLL-100B1LI
   hr_d_io                 : inout std_logic_vector(7 downto 0);
   hr_rwds_io              : inout std_logic;
   hr_reset_o              : out   std_logic;
   hr_clk_p_o              : out   std_logic;
   hr_cs0_o                : out   std_logic;

   -- CBM-488/IEC serial port
   iec_reset_n_o           : out   std_logic;
   iec_atn_n_o             : out   std_logic;
   iec_clk_en_n_o          : out   std_logic;
   iec_clk_n_i             : in    std_logic;
   iec_clk_n_o             : out   std_logic;
   iec_data_en_n_o         : out   std_logic;
   iec_data_n_i            : in    std_logic;
   iec_data_n_o            : out   std_logic;
   iec_srq_en_n_o          : out   std_logic;
   iec_srq_n_i             : in    std_logic;
   iec_srq_n_o             : out   std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_phi2_o             : out   std_logic;
   cart_dotclock_o         : out   std_logic;
   cart_dma_i              : in    std_logic;
   cart_reset_o            : out   std_logic;                  -- Output only on R4. Should be inout.
   cart_game_i             : in    std_logic;                  -- Input only on R4. Should be inout.
   cart_exrom_i            : in    std_logic;                  -- Input only on R4. Should be inout.
   cart_nmi_i              : in    std_logic;                  -- Input only on R4. Should be inout.
   cart_irq_i              : in    std_logic;                  -- Input only on R4. Should be inout.
   cart_ctrl_en_o          : out   std_logic;
   cart_ctrl_dir_o         : out   std_logic;                  -- =1 means FPGA->Port, =0 means Port->FPGA
   cart_ba_io              : inout std_logic;
   cart_rw_io              : inout std_logic;
   cart_io1_io             : inout std_logic;
   cart_io2_io             : inout std_logic;
   cart_romh_io            : inout std_logic;
   cart_roml_io            : inout std_logic;
   cart_addr_en_o          : out   std_logic;
   cart_haddr_dir_o        : out   std_logic;                  -- =1 means FPGA->Port, =0 means Port->FPGA
   cart_laddr_dir_o        : out   std_logic;                  -- =1 means FPGA->Port, =0 means Port->FPGA
   cart_a_io               : inout unsigned(15 downto 0);
   cart_data_en_o          : out   std_logic;
   cart_data_dir_o         : out   std_logic;                  -- =1 means FPGA->Port, =0 means Port->FPGA
   cart_d_io               : inout unsigned(7 downto 0);

   -- The remaining ports are not supported

   -- SMSC Ethernet PHY. U4 = KSZ8081RNDCA
   eth_clock_o             : out   std_logic;
   eth_led2_o              : out   std_logic;
   eth_mdc_o               : out   std_logic;
   eth_mdio_io             : inout std_logic;
   eth_reset_o             : out   std_logic;
   eth_rxd_i               : in    std_logic_vector(1 downto 0);
   eth_rxdv_i              : in    std_logic;
   eth_rxer_i              : in    std_logic;
   eth_txd_o               : out   std_logic_vector(1 downto 0);
   eth_txen_o              : out   std_logic;

   -- FDC interface
   f_density_o             : out   std_logic;
   f_diskchanged_i         : in    std_logic;
   f_index_i               : in    std_logic;
   f_motora_o              : out   std_logic;
   f_motorb_o              : out   std_logic;
   f_rdata_i               : in    std_logic;
   f_selecta_o             : out   std_logic;
   f_selectb_o             : out   std_logic;
   f_side1_o               : out   std_logic;
   f_stepdir_o             : out   std_logic;
   f_step_o                : out   std_logic;
   f_track0_i              : in    std_logic;
   f_wdata_o               : out   std_logic;
   f_wgate_o               : out   std_logic;
   f_writeprotect_i        : in    std_logic;

   -- I2C bus for on-board peripherals
   -- U36. 24AA025E48T. Address 0x50. 2K Serial EEPROM.
   -- U38. RV-3032-C7.  Address 0x51. Real-Time Clock Module.
   -- U39. 24LC128.     Address 0x56. 128K CMOS Serial EEPROM.
   fpga_sda_io             : inout std_logic;
   fpga_scl_io             : inout std_logic;

   -- Connected to J18
   grove_sda_io            : inout std_logic;
   grove_scl_io            : inout std_logic;

   -- On board LEDs
   led_g_n_o               : out   std_logic;
   led_r_n_o               : out   std_logic;
   led_o                   : out   std_logic;

   -- Pmod Header
   p1lo_io                 : inout std_logic_vector(3 downto 0);
   p1hi_io                 : inout std_logic_vector(3 downto 0);
   p2lo_io                 : inout std_logic_vector(3 downto 0);
   p2hi_io                 : inout std_logic_vector(3 downto 0);
   pmod1_en_o              : out   std_logic;
   pmod1_flag_i            : in    std_logic;
   pmod2_en_o              : out   std_logic;
   pmod2_flag_i            : in    std_logic;

   -- Quad SPI Flash. U5 = S25FL512SAGBHIS10
   qspidb_io               : inout std_logic_vector(3 downto 0);
   qspicsn_o               : out   std_logic;

   -- DIP Switches
   cpld_cfg_i              : in    std_logic_vector(3 downto 0);

   -- Debug.
   dbg_io_10               : inout std_logic;
   dbg_io_11               : inout std_logic;

   -- Board revision
   rev_bit_i               : in    std_logic_vector(3 downto 0);

   -- SDRAM - 32M x 16 bit, 3.3V VCC. U44 = IS42S16320F-6BL
   sdram_clk_o             : out   std_logic;
   sdram_cke_o             : out   std_logic;
   sdram_ras_n_o           : out   std_logic;
   sdram_cas_n_o           : out   std_logic;
   sdram_we_n_o            : out   std_logic;
   sdram_cs_n_o            : out   std_logic;
   sdram_ba_o              : out   std_logic_vector(1 downto 0);
   sdram_a_o               : out   std_logic_vector(12 downto 0);
   sdram_dqml_o            : out   std_logic;
   sdram_dqmh_o            : out   std_logic;
   sdram_dq_io             : inout std_logic_vector(15 downto 0)
);
end entity mega65_r4;

architecture synthesis of mega65_r4 is

   signal main_clk    : std_logic;
   signal main_rst    : std_logic;
   signal qnice_clk   : std_logic;
   signal qnice_rst   : std_logic;

   --------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- QNICE control and status register
   signal main_qnice_reset       : std_logic;
   signal main_qnice_pause       : std_logic;

   signal main_reset_m2m         : std_logic;
   signal main_reset_core        : std_logic;

   -- keyboard handling (incl. drive led)
   signal main_key_num           : integer range 0 to 79;
   signal main_key_pressed_n     : std_logic;
   signal main_power_led         : std_logic;
   signal main_power_led_col     : std_logic_vector(23 downto 0);
   signal main_drive_led         : std_logic;
   signal main_drive_led_col     : std_logic_vector(23 downto 0);

   -- QNICE On Screen Menu selections
   signal main_osm_control_m     : std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   signal main_qnice_gp_reg      : std_logic_vector(255 downto 0);

   -- signed audio from the core
   -- if the core outputs unsigned audio, make sure you convert properly to prevent a loss in audio quality
   signal main_audio_l           : signed(15 downto 0);
   signal main_audio_r           : signed(15 downto 0);

   -- Video output from Core
   signal video_clk              : std_logic;
   signal video_rst              : std_logic;
   signal video_ce               : std_logic;
   signal video_ce_ovl           : std_logic;
   signal video_red              : std_logic_vector(7 downto 0);
   signal video_green            : std_logic_vector(7 downto 0);
   signal video_blue             : std_logic_vector(7 downto 0);
   signal video_vs               : std_logic;
   signal video_hs               : std_logic;
   signal video_hblank           : std_logic;
   signal video_vblank           : std_logic;

   -- Joysticks and Paddles
   signal main_joy1_up_n_in      : std_logic;
   signal main_joy1_down_n_in    : std_logic;
   signal main_joy1_left_n_in    : std_logic;
   signal main_joy1_right_n_in   : std_logic;
   signal main_joy1_fire_n_in    : std_logic;

   signal main_joy1_up_n_out     : std_logic;
   signal main_joy1_down_n_out   : std_logic;
   signal main_joy1_left_n_out   : std_logic;
   signal main_joy1_right_n_out  : std_logic;
   signal main_joy1_fire_n_out   : std_logic;

   signal main_joy2_up_n_in      : std_logic;
   signal main_joy2_down_n_in    : std_logic;
   signal main_joy2_left_n_in    : std_logic;
   signal main_joy2_right_n_in   : std_logic;
   signal main_joy2_fire_n_in    : std_logic;

   signal main_joy2_up_n_out     : std_logic;
   signal main_joy2_down_n_out   : std_logic;
   signal main_joy2_left_n_out   : std_logic;
   signal main_joy2_right_n_out  : std_logic;
   signal main_joy2_fire_n_out   : std_logic;

   signal main_pot1_x            : std_logic_vector(7 downto 0);
   signal main_pot1_y            : std_logic_vector(7 downto 0);
   signal main_pot2_x            : std_logic_vector(7 downto 0);
   signal main_pot2_y            : std_logic_vector(7 downto 0);
   signal main_rtc               : std_logic_vector(64 downto 0);

   signal iec_clk_en             : std_logic;
   signal iec_data_en            : std_logic;
   signal iec_srq_en             : std_logic;

   signal cart_en                : std_logic;
   signal cart_roml_oe           : std_logic;
   signal cart_roml_in           : std_logic;
   signal cart_roml_out          : std_logic;
   signal cart_romh_oe           : std_logic;
   signal cart_romh_in           : std_logic;
   signal cart_romh_out          : std_logic;
   signal cart_ctrl_oe           : std_logic;
   signal cart_ba_in             : std_logic;
   signal cart_rw_in             : std_logic;
   signal cart_io1_in            : std_logic;
   signal cart_io2_in            : std_logic;
   signal cart_ba_out            : std_logic;
   signal cart_rw_out            : std_logic;
   signal cart_io1_out           : std_logic;
   signal cart_io2_out           : std_logic;
   signal cart_addr_oe           : std_logic;
   signal cart_a_in              : unsigned(15 downto 0);
   signal cart_a_out             : unsigned(15 downto 0);
   signal cart_data_oe           : std_logic;
   signal cart_d_in              : unsigned(7 downto 0);
   signal cart_d_out             : unsigned(7 downto 0);

   signal audio_clk              : std_logic;
   signal audio_reset            : std_logic;
   signal audio_left             : signed(15 downto 0);
   signal audio_right            : signed(15 downto 0);

   ---------------------------------------------------------------------------------------------
   -- HyperRAM clock domain
   ---------------------------------------------------------------------------------------------

   signal hr_clk                 : std_logic;
   signal hr_rst                 : std_logic;
   signal hr_core_write          : std_logic;
   signal hr_core_read           : std_logic;
   signal hr_core_address        : std_logic_vector(31 downto 0);
   signal hr_core_writedata      : std_logic_vector(15 downto 0);
   signal hr_core_byteenable     : std_logic_vector(1 downto 0);
   signal hr_core_burstcount     : std_logic_vector(7 downto 0);
   signal hr_core_readdata       : std_logic_vector(15 downto 0);
   signal hr_core_readdatavalid  : std_logic;
   signal hr_core_waitrequest    : std_logic;
   signal hr_low                 : std_logic;
   signal hr_high                : std_logic;

   ---------------------------------------------------------------------------------------------
   -- qnice_clk
   ---------------------------------------------------------------------------------------------

   -- Video and audio mode control
   signal qnice_dvi              : std_logic;
   signal qnice_video_mode       : video_mode_type;
   signal qnice_scandoubler      : std_logic;
   signal qnice_csync            : std_logic;
   signal qnice_audio_mute       : std_logic;
   signal qnice_audio_filter     : std_logic;
   signal qnice_zoom_crop        : std_logic;
   signal qnice_ascal_mode       : std_logic_vector(1 downto 0);
   signal qnice_ascal_polyphase  : std_logic;
   signal qnice_ascal_triplebuf  : std_logic;
   signal qnice_retro15kHz       : std_logic;
   signal qnice_osm_cfg_scaling  : std_logic_vector(8 downto 0);

   -- flip joystick ports
   signal qnice_flip_joyports    : std_logic;

   -- QNICE On Screen Menu selections
   signal qnice_osm_control_m    : std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   signal qnice_gp_reg           : std_logic_vector(255 downto 0);

   -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
   -- ramrom_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
   signal qnice_ramrom_dev       : std_logic_vector(15 downto 0);
   signal qnice_ramrom_addr      : std_logic_vector(27 downto 0);
   signal qnice_ramrom_data_out  : std_logic_vector(15 downto 0);
   signal qnice_ramrom_data_in   : std_logic_vector(15 downto 0);
   signal qnice_ramrom_ce        : std_logic;
   signal qnice_ramrom_we        : std_logic;
   signal qnice_ramrom_wait      : std_logic;

   signal i2c_sda                : std_logic := 'H';
   signal i2c_scl                : std_logic := 'H';

begin

   -- Driver for the audio DAC (AK4432VT).
   i_audio : entity work.audio
      port map (
         audio_clk_i    => audio_clk,
         audio_reset_i  => audio_reset,
         audio_left_i   => audio_left,
         audio_right_i  => audio_right,
         audio_mclk_o   => audio_mclk_o,
         audio_bick_o   => audio_bick_o,
         audio_sdti_o   => audio_sdti_o,
         audio_lrclk_o  => audio_lrclk_o,
         audio_pdn_n_o  => audio_pdn_n_o
      ); -- i_audio

   audio_i2cfil_o <= '0';  -- I2C speed 400 kHz

   ---------------------------------------------------------------------------------------------
   -- C64 Cartridge port
   ---------------------------------------------------------------------------------------------

   cart_roml_io     <= cart_roml_out when cart_ctrl_oe = '1' and cart_roml_oe = '1' else 'Z';
   cart_romh_io     <= cart_romh_out when cart_ctrl_oe = '1' and cart_romh_oe = '1' else 'Z';
   cart_roml_in     <= cart_roml_io;
   cart_romh_in     <= cart_romh_io;
   cart_ba_io       <= cart_ba_out   when cart_ctrl_oe = '1' else 'Z';
   cart_rw_io       <= cart_rw_out   when cart_ctrl_oe = '1' else 'Z';
   cart_io1_io      <= cart_io1_out  when cart_ctrl_oe = '1' else 'Z';
   cart_io2_io      <= cart_io2_out  when cart_ctrl_oe = '1' else 'Z';
   cart_ba_in       <= cart_ba_io;
   cart_rw_in       <= cart_rw_io;
   cart_io1_in      <= cart_io1_io;
   cart_io2_in      <= cart_io2_io;
   cart_ctrl_en_o   <= not cart_en;
   cart_ctrl_dir_o  <= cart_ctrl_oe;

   cart_d_io        <= cart_d_out    when cart_data_oe = '1' else (others => 'Z');
   cart_d_in        <= cart_d_io;
   cart_data_en_o   <= not cart_en;
   cart_data_dir_o  <= cart_data_oe;

   cart_a_io        <= cart_a_out    when cart_addr_oe = '1' else (others => 'Z');
   cart_a_in        <= cart_a_io;
   cart_addr_en_o   <= not cart_en;
   cart_haddr_dir_o <= cart_addr_oe;
   cart_laddr_dir_o <= cart_addr_oe;


   iec_clk_en_n_o   <= not iec_clk_en;
   iec_data_en_n_o  <= not iec_data_en;
   iec_srq_en_n_o   <= not iec_srq_en;


   ---------------------------------------------------------------------------------------------
   -- Safe default values for ports not supported by the M2M framework
   ---------------------------------------------------------------------------------------------

   vdac_psave_n_o        <= '1';
   hdmi_hiz_en_o         <= '0'; -- HDMI is 50 ohm terminated.
   hdmi_ls_oe_n_o        <= '0'; -- Enable HDMI output
   dbg_io_10             <= 'Z';
   dbg_io_11             <= 'Z';

   eth_clock_o           <= '0';
   eth_led2_o            <= '0';
   eth_mdc_o             <= '0';
   eth_mdio_io           <= 'Z';
   eth_reset_o           <= '1';
   eth_txd_o             <= (others => '0');
   eth_txen_o            <= '0';
   f_density_o           <= '1';
   f_motora_o            <= '1';
   f_motorb_o            <= '1';
   f_selecta_o           <= '1';
   f_selectb_o           <= '1';
   f_side1_o             <= '1';
   f_stepdir_o           <= '1';
   f_step_o              <= '1';
   f_wdata_o             <= '1';
   f_wgate_o             <= '1';
   joystick_5v_disable_o <= '0'; -- Enable 5V power supply to joysticks
   led_g_n_o             <= '1'; -- Off
   led_r_n_o             <= '1'; -- Off
   led_o                 <= '0'; -- Off
   p1lo_io               <= (others => 'Z');
   p1hi_io               <= (others => 'Z');
   p2lo_io               <= (others => 'Z');
   p2hi_io               <= (others => 'Z');
   pmod1_en_o            <= '0';
   pmod2_en_o            <= '0';
   qspidb_io             <= (others => 'Z');
   qspicsn_o             <= '1';
   sdram_clk_o           <= '0';
   sdram_cke_o           <= '0';
   sdram_ras_n_o         <= '1';
   sdram_cas_n_o         <= '1';
   sdram_we_n_o          <= '1';
   sdram_cs_n_o          <= '1';
   sdram_ba_o            <= (others => '0');
   sdram_a_o             <= (others => '0');
   sdram_dqml_o          <= '0';
   sdram_dqmh_o          <= '0';
   sdram_dq_io           <= (others => 'Z');


   -----------------------------------------------------------------------------------------
   -- MiSTer2MEGA framework
   -----------------------------------------------------------------------------------------

   i_framework : entity work.framework
   generic map (
      G_BOARD => "MEGA65_R4"
   )
   port map (
      -- Connect to I/O ports
      clk_i                   => clk_i,
      reset_n_i               => not reset_button_i,
      uart_rxd_i              => uart_rxd_i,
      uart_txd_o              => uart_txd_o,
      vga_red_o               => vga_red_o,
      vga_green_o             => vga_green_o,
      vga_blue_o              => vga_blue_o,
      vga_hs_o                => vga_hs_o,
      vga_vs_o                => vga_vs_o,
      vdac_clk_o              => vdac_clk_o,
      vdac_sync_n_o           => vdac_sync_n_o,
      vdac_blank_n_o          => vdac_blank_n_o,
      tmds_data_p_o           => tmds_data_p_o,
      tmds_data_n_o           => tmds_data_n_o,
      tmds_clk_p_o            => tmds_clk_p_o,
      tmds_clk_n_o            => tmds_clk_n_o,
      kb_io0_o                => kb_io0_o,
      kb_io1_o                => kb_io1_o,
      kb_io2_i                => kb_io2_i,
      sd_reset_o              => sd_reset_o,
      sd_clk_o                => sd_clk_o,
      sd_mosi_o               => sd_mosi_o,
      sd_miso_i               => sd_miso_i,
      sd_cd_i                 => sd_cd_i,
      sd2_reset_o             => sd2_reset_o,
      sd2_clk_o               => sd2_clk_o,
      sd2_mosi_o              => sd2_mosi_o,
      sd2_miso_i              => sd2_miso_i,
      sd2_cd_i                => sd2_cd_i,
      joy_1_up_n_i            => fa_up_n_i,
      joy_1_down_n_i          => fa_down_n_i,
      joy_1_left_n_i          => fa_left_n_i,
      joy_1_right_n_i         => fa_right_n_i,
      joy_1_fire_n_i          => fa_fire_n_i,
      joy_1_up_n_o            => fa_up_n_o,
      joy_1_down_n_o          => fa_down_n_o,
      joy_1_left_n_o          => fa_left_n_o,
      joy_1_right_n_o         => fa_right_n_o,
      joy_1_fire_n_o          => fa_fire_n_o,
      joy_2_up_n_i            => fb_up_n_i,
      joy_2_down_n_i          => fb_down_n_i,
      joy_2_left_n_i          => fb_left_n_i,
      joy_2_right_n_i         => fb_right_n_i,
      joy_2_fire_n_i          => fb_fire_n_i,
      joy_2_up_n_o            => fb_up_n_o,
      joy_2_down_n_o          => fb_down_n_o,
      joy_2_left_n_o          => fb_left_n_o,
      joy_2_right_n_o         => fb_right_n_o,
      joy_2_fire_n_o          => fb_fire_n_o,
      paddle_i                => paddle_i,
      paddle_drain_o          => paddle_drain_o,
      hr_d_io                 => hr_d_io,
      hr_rwds_io              => hr_rwds_io,
      hr_reset_o              => hr_reset_o,
      hr_clk_p_o              => hr_clk_p_o,
      hr_cs0_o                => hr_cs0_o,

      -- Connect to CORE
      qnice_clk_o             => qnice_clk,
      qnice_rst_o             => qnice_rst,
      main_clk_i              => main_clk,
      main_rst_i              => main_rst,
      main_qnice_reset_o      => main_qnice_reset,
      main_qnice_pause_o      => main_qnice_pause,
      main_reset_m2m_o        => main_reset_m2m,
      main_reset_core_o       => main_reset_core,
      main_key_num_o          => main_key_num,
      main_key_pressed_n_o    => main_key_pressed_n,
      main_power_led_i        => main_power_led,
      main_power_led_col_i    => main_power_led_col,
      main_drive_led_i        => main_drive_led,
      main_drive_led_col_i    => main_drive_led_col,
      main_osm_control_m_o    => main_osm_control_m,
      main_qnice_gp_reg_o     => main_qnice_gp_reg,
      main_audio_l_i          => main_audio_l,
      main_audio_r_i          => main_audio_r,
      video_clk_i             => video_clk,
      video_rst_i             => video_rst,
      video_ce_i              => video_ce,
      video_ce_ovl_i          => video_ce_ovl,
      video_red_i             => video_red,
      video_green_i           => video_green,
      video_blue_i            => video_blue,
      video_vs_i              => video_vs,
      video_hs_i              => video_hs,
      video_hblank_i          => video_hblank,
      video_vblank_i          => video_vblank,
      main_joy1_up_n_o        => main_joy1_up_n_in,
      main_joy1_down_n_o      => main_joy1_down_n_in,
      main_joy1_left_n_o      => main_joy1_left_n_in,
      main_joy1_right_n_o     => main_joy1_right_n_in,
      main_joy1_fire_n_o      => main_joy1_fire_n_in,
      main_joy1_up_n_i        => main_joy1_up_n_out,
      main_joy1_down_n_i      => main_joy1_down_n_out,
      main_joy1_left_n_i      => main_joy1_left_n_out,
      main_joy1_right_n_i     => main_joy1_right_n_out,
      main_joy1_fire_n_i      => main_joy1_fire_n_out,
      main_joy2_up_n_o        => main_joy2_up_n_in,
      main_joy2_down_n_o      => main_joy2_down_n_in,
      main_joy2_left_n_o      => main_joy2_left_n_in,
      main_joy2_right_n_o     => main_joy2_right_n_in,
      main_joy2_fire_n_o      => main_joy2_fire_n_in,
      main_joy2_up_n_i        => main_joy2_up_n_out,
      main_joy2_down_n_i      => main_joy2_down_n_out,
      main_joy2_left_n_i      => main_joy2_left_n_out,
      main_joy2_right_n_i     => main_joy2_right_n_out,
      main_joy2_fire_n_i      => main_joy2_fire_n_out,
      main_pot1_x_o           => main_pot1_x,
      main_pot1_y_o           => main_pot1_y,
      main_pot2_x_o           => main_pot2_x,
      main_pot2_y_o           => main_pot2_y,
      main_rtc_o              => main_rtc,

      -- Provide HyperRAM to core (in HyperRAM clock domain)
      hr_clk_o                => hr_clk,
      hr_rst_o                => hr_rst,
      hr_core_write_i         => hr_core_write,
      hr_core_read_i          => hr_core_read,
      hr_core_address_i       => hr_core_address,
      hr_core_writedata_i     => hr_core_writedata,
      hr_core_byteenable_i    => hr_core_byteenable,
      hr_core_burstcount_i    => hr_core_burstcount,
      hr_core_readdata_o      => hr_core_readdata,
      hr_core_readdatavalid_o => hr_core_readdatavalid,
      hr_core_waitrequest_o   => hr_core_waitrequest,
      hr_high_o               => hr_high,
      hr_low_o                => hr_low,

      -- Audio
      audio_clk_o             => audio_clk,
      audio_reset_o           => audio_reset,
      audio_left_o            => audio_left,
      audio_right_o           => audio_right,

      -- Connect to QNICE
      qnice_dvi_i             => qnice_dvi,
      qnice_video_mode_i      => qnice_video_mode,
      qnice_scandoubler_i     => qnice_scandoubler,
      qnice_csync_i           => qnice_csync,
      qnice_audio_mute_i      => qnice_audio_mute,
      qnice_audio_filter_i    => qnice_audio_filter,
      qnice_zoom_crop_i       => qnice_zoom_crop,
      qnice_osm_cfg_scaling_i => qnice_osm_cfg_scaling,
      qnice_retro15kHz_i      => qnice_retro15kHz,
      qnice_ascal_mode_i      => qnice_ascal_mode,
      qnice_ascal_polyphase_i => qnice_ascal_polyphase,
      qnice_ascal_triplebuf_i => qnice_ascal_triplebuf,
      qnice_flip_joyports_i   => qnice_flip_joyports,
      qnice_osm_control_m_o   => qnice_osm_control_m,
      qnice_gp_reg_o          => qnice_gp_reg,
      qnice_ramrom_dev_o      => qnice_ramrom_dev,
      qnice_ramrom_addr_o     => qnice_ramrom_addr,
      qnice_ramrom_data_out_o => qnice_ramrom_data_out,
      qnice_ramrom_data_in_i  => qnice_ramrom_data_in,
      qnice_ramrom_ce_o       => qnice_ramrom_ce,
      qnice_ramrom_we_o       => qnice_ramrom_we,
      qnice_ramrom_wait_i     => qnice_ramrom_wait,

      hdmi_scl_io             => hdmi_scl_io,
      hdmi_sda_io             => hdmi_sda_io,
      vga_scl_io              => vga_scl_io,
      vga_sda_io              => vga_sda_io,
      audio_scl_io            => audio_scl_io,
      audio_sda_io            => audio_sda_io,
      i2c_sda_io              => i2c_sda,
      i2c_scl_io              => i2c_scl,
      fpga_sda_io             => fpga_sda_io,
      fpga_scl_io             => fpga_scl_io,
      grove_sda_io            => grove_sda_io,
      grove_scl_io            => grove_scl_io
   ); -- i_framework


   ---------------------------------------------------------------------------------------------------------------
   -- MEGA65 Core including the MiSTer core: Multiple clock domains
   ---------------------------------------------------------------------------------------------------------------

   CORE : entity work.MEGA65_Core
      generic map (
         G_BOARD => "MEGA65_R4"
      )
      port map (
         clk_i                   => clk_i,

         -- Share clock and reset with the framework
         main_clk_o              => main_clk,            -- CORE's 54 MHz clock
         main_rst_o              => main_rst,            -- CORE's reset, synchronized

         --------------------------------------------------------------------------------------------------------
         -- QNICE Clock Domain
         --------------------------------------------------------------------------------------------------------

         -- Provide QNICE clock to the core: for the vdrives as well as for RAMs and ROMs
         qnice_clk_i             => qnice_clk,
         qnice_rst_i             => qnice_rst,

         -- Video and audio mode control
         qnice_dvi_o             => qnice_dvi,
         qnice_video_mode_o      => qnice_video_mode,
         qnice_scandoubler_o     => qnice_scandoubler,
         qnice_csync_o           => qnice_csync,
         qnice_audio_mute_o      => qnice_audio_mute,
         qnice_audio_filter_o    => qnice_audio_filter,
         qnice_zoom_crop_o       => qnice_zoom_crop,
         qnice_ascal_mode_o      => qnice_ascal_mode,
         qnice_ascal_polyphase_o => qnice_ascal_polyphase,
         qnice_ascal_triplebuf_o => qnice_ascal_triplebuf,
         qnice_retro15kHz_o      => qnice_retro15kHz,
         qnice_osm_cfg_scaling_o => qnice_osm_cfg_scaling,

         -- Flip joystick ports
         qnice_flip_joyports_o   => qnice_flip_joyports,

         -- On-Screen-Menu selections (in QNICE clock domain)
         qnice_osm_control_i     => qnice_osm_control_m,

         -- QNICE general purpose register
         qnice_gp_reg_i          => qnice_gp_reg,

         -- Core-specific devices
         qnice_dev_id_i          => qnice_ramrom_dev,
         qnice_dev_addr_i        => qnice_ramrom_addr,
         qnice_dev_data_i        => qnice_ramrom_data_out,
         qnice_dev_data_o        => qnice_ramrom_data_in,
         qnice_dev_ce_i          => qnice_ramrom_ce,
         qnice_dev_we_i          => qnice_ramrom_we,
         qnice_dev_wait_o        => qnice_ramrom_wait,

         --------------------------------------------------------------------------------------------------------
         -- Core Clock Domain
         --------------------------------------------------------------------------------------------------------

         -- M2M's reset manager provides 2 signals:
         --    m2m:   Reset the whole machine: Core and Framework
         --    core:  Only reset the core
         main_reset_m2m_i        => main_reset_m2m  or main_qnice_reset or main_rst,
         main_reset_core_i       => main_reset_core or main_qnice_reset,
         main_pause_core_i       => main_qnice_pause,

         -- On-Screen-Menu selections (in main clock domain)
         main_osm_control_i      => main_osm_control_m,

         -- QNICE general purpose register (in main clock domain)
         main_qnice_gp_reg_i     => main_qnice_gp_reg,

         -- Video output
         video_clk_o             => video_clk,
         video_rst_o             => video_rst,
         video_ce_o              => video_ce,
         video_ce_ovl_o          => video_ce_ovl,
         video_red_o             => video_red,
         video_green_o           => video_green,
         video_blue_o            => video_blue,
         video_vs_o              => video_vs,
         video_hs_o              => video_hs,
         video_hblank_o          => video_hblank,
         video_vblank_o          => video_vblank,

         -- Audio output (Signed PCM)
         main_audio_left_o       => main_audio_l,
         main_audio_right_o      => main_audio_r,

         -- M2M Keyboard interface
         main_kb_key_num_i       => main_key_num,
         main_kb_key_pressed_n_i => main_key_pressed_n,
         main_power_led_o        => main_power_led,
         main_power_led_col_o    => main_power_led_col,
         main_drive_led_o        => main_drive_led,
         main_drive_led_col_o    => main_drive_led_col,

         -- Joysticks input
         main_joy_1_up_n_i       => main_joy1_up_n_in,
         main_joy_1_down_n_i     => main_joy1_down_n_in,
         main_joy_1_left_n_i     => main_joy1_left_n_in,
         main_joy_1_right_n_i    => main_joy1_right_n_in,
         main_joy_1_fire_n_i     => main_joy1_fire_n_in,
         main_joy_1_up_n_o       => main_joy1_up_n_out,
         main_joy_1_down_n_o     => main_joy1_down_n_out,
         main_joy_1_left_n_o     => main_joy1_left_n_out,
         main_joy_1_right_n_o    => main_joy1_right_n_out,
         main_joy_1_fire_n_o     => main_joy1_fire_n_out,

         main_joy_2_up_n_i       => main_joy2_up_n_in,
         main_joy_2_down_n_i     => main_joy2_down_n_in,
         main_joy_2_left_n_i     => main_joy2_left_n_in,
         main_joy_2_right_n_i    => main_joy2_right_n_in,
         main_joy_2_fire_n_i     => main_joy2_fire_n_in,
         main_joy_2_up_n_o       => main_joy2_up_n_out,
         main_joy_2_down_n_o     => main_joy2_down_n_out,
         main_joy_2_left_n_o     => main_joy2_left_n_out,
         main_joy_2_right_n_o    => main_joy2_right_n_out,
         main_joy_2_fire_n_o     => main_joy2_fire_n_out,

         main_pot1_x_i           => main_pot1_x,
         main_pot1_y_i           => main_pot1_y,
         main_pot2_x_i           => main_pot2_x,
         main_pot2_y_i           => main_pot2_y,
         main_rtc_i              => main_rtc,

         --------------------------------------------------------------------------------------------------------
         -- Provide support for external memory (Avalon Memory Map)
         --------------------------------------------------------------------------------------------------------

         hr_clk_i                => hr_clk,
         hr_rst_i                => hr_rst,
         hr_core_write_o         => hr_core_write,
         hr_core_read_o          => hr_core_read,
         hr_core_address_o       => hr_core_address,
         hr_core_writedata_o     => hr_core_writedata,
         hr_core_byteenable_o    => hr_core_byteenable,
         hr_core_burstcount_o    => hr_core_burstcount,
         hr_core_readdata_i      => hr_core_readdata,
         hr_core_readdatavalid_i => hr_core_readdatavalid,
         hr_core_waitrequest_i   => hr_core_waitrequest,
         hr_high_i               => hr_high,
         hr_low_i                => hr_low,

         --------------------------------------------------------------------
         -- C64 specific ports that are not supported by the M2M framework
         --------------------------------------------------------------------

         -- CBM-488/IEC serial port
         iec_reset_n_o     => iec_reset_n_o,
         iec_atn_n_o       => iec_atn_n_o,
         iec_clk_en_o      => iec_clk_en,
         iec_clk_n_i       => iec_clk_n_i,
         iec_clk_n_o       => iec_clk_n_o,
         iec_data_en_o     => iec_data_en,
         iec_data_n_i      => iec_data_n_i,
         iec_data_n_o      => iec_data_n_o,
         iec_srq_en_o      => iec_srq_en,
         iec_srq_n_i       => iec_srq_n_i,
         iec_srq_n_o       => iec_srq_n_o,

         -- C64 Expansion Port (aka Cartridge Port)
         cart_en_o         => cart_en, -- Enable port, active high
         cart_phi2_o       => cart_phi2_o,
         cart_dotclock_o   => cart_dotclock_o,
         cart_dma_i        => cart_dma_i,
         --
         cart_reset_oe_o   => open,         -- Not connected on the R4 board
         cart_reset_i      => '1',          -- Not connected on the R4 board
         cart_reset_o      => cart_reset_o,
         --
         cart_game_oe_o    => open,         -- Not connected on the R4 board
         cart_game_i       => cart_game_i,
         cart_game_o       => open,         -- Not connected on the R4 board
         --
         cart_exrom_oe_o   => open,         -- Not connected on the R4 board
         cart_exrom_i      => cart_exrom_i,
         cart_exrom_o      => open,         -- Not connected on the R4 board
         --
         cart_nmi_oe_o     => open,         -- Not connected on the R4 board
         cart_nmi_i        => cart_nmi_i,
         cart_nmi_o        => open,         -- Not connected on the R4 board
         --
         cart_irq_oe_o     => open,         -- Not connected on the R4 board
         cart_irq_i        => cart_irq_i,
         cart_irq_o        => open,         -- Not connected on the R4 board
         --
         cart_roml_oe_o    => cart_roml_oe,
         cart_roml_i       => cart_roml_in,
         cart_roml_o       => cart_roml_out,
         --
         cart_romh_oe_o    => cart_romh_oe,
         cart_romh_i       => cart_romh_in,
         cart_romh_o       => cart_romh_out,
         --
         cart_ctrl_oe_o    => cart_ctrl_oe, -- 0 : tristate (i.e. input), 1 : output
         cart_ba_i         => cart_ba_in,
         cart_rw_i         => cart_rw_in,
         cart_io1_i        => cart_io1_in,
         cart_io2_i        => cart_io2_in,
         cart_ba_o         => cart_ba_out,
         cart_rw_o         => cart_rw_out,
         cart_io1_o        => cart_io1_out,
         cart_io2_o        => cart_io2_out,
         --
         cart_data_oe_o    => cart_data_oe, -- 0 : tristate (i.e. input), 1 : output
         cart_d_i          => cart_d_in,
         cart_d_o          => cart_d_out,
         --
         cart_addr_oe_o    => cart_addr_oe, -- 0 : tristate (i.e. input), 1 : output
         cart_a_i          => cart_a_in,
         cart_a_o          => cart_a_out
      ); -- CORE

end architecture synthesis;

