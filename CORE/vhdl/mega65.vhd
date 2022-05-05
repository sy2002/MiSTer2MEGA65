----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- MEGA65 main file that contains the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;


library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
port (
   CLK                     : in std_logic;         -- 100 MHz clock
   RESET_M2M_N             : in std_logic;         -- Debounced system reset in system clock domain

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;        -- CORE's 54 MHz clock
   main_rst_o              : out std_logic;        -- CORE's reset, synchronized

   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in std_logic;

   -- Video and audio mode control
   qnice_video_mode_o      : out std_logic;        -- 720p always; 0 = 50Hz, 1 = 60 Hz
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in std_logic;
   qnice_dev_we_i          : in std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in std_logic;
   main_reset_core_i       : in std_logic;

   main_pause_core_i       : in std_logic;

   -- Video output
   main_video_ce_o         : out std_logic;
   main_video_red_o        : out std_logic_vector(7 downto 0);
   main_video_green_o      : out std_logic_vector(7 downto 0);
   main_video_blue_o       : out std_logic_vector(7 downto 0);
   main_video_vs_o         : out std_logic;
   main_video_hs_o         : out std_logic;
   main_video_hblank_o     : out std_logic;
   main_video_vblank_o     : out std_logic;

   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface
   main_kb_key_num_i       : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

   -- Joysticks input
   main_joy_1_up_n_i       : in std_logic;
   main_joy_1_down_n_i     : in std_logic;
   main_joy_1_left_n_i     : in std_logic;
   main_joy_1_right_n_i    : in std_logic;
   main_joy_1_fire_n_i     : in std_logic;

   main_joy_2_up_n_i       : in std_logic;
   main_joy_2_down_n_i     : in std_logic;
   main_joy_2_left_n_i     : in std_logic;
   main_joy_2_right_n_i    : in std_logic;
   main_joy_2_fire_n_i     : in std_logic;

   -- On-Screen-Menu selections
   main_osm_control_i     : in std_logic_vector(255 downto 0)
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal main_clk               : std_logic;               -- Core main clock
signal main_rst               : std_logic;

---------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
-- Democore & example stuff: Delete before starting to port your own core
---------------------------------------------------------------------------------------------

-- Democore menu items
constant C_MENU_HDMI_60HZ     : natural := 10;
constant C_MENU_CRT_EMULATION : natural := 20;
constant C_MENU_HDMI_ZOOM     : natural := 21;
constant C_MENU_IMPROVE_AUDIO : natural := 22;

-- QNICE clock domain
signal qnice_demo_vd_data_o   : std_logic_vector(15 downto 0);
signal qnice_demo_vd_ce       : std_logic;
signal qnice_demo_vd_we       : std_logic;

begin

   -- MMCME2_ADV clock generators:
   --   @TODO YOURCORE:       54 MHz
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => CLK,             -- expects 100 MHz
         sys_rstn_i        => RESET_M2M_N,     -- Asynchronous, asserted low
         main_clk_o        => main_clk,        -- CORE's 54 MHz clock
         main_rst_o        => main_rst         -- CORE's reset, synchronized
      ); -- clk_gen

   main_clk_o <= main_clk;
   main_rst_o <= main_rst;

   ---------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
      )
      port map (
         clk_main_i           => main_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
         pause_i              => main_pause_core_i,

         clk_main_speed_i     => CORE_CLK_SPEED,

         -- Video output
         -- This is PAL 720x576 @ 50 Hz (pixel clock 27 MHz), but synchronized to main_clk (54 MHz).
         video_ce_o           => main_video_ce_o,
         video_red_o          => main_video_red_o,
         video_green_o        => main_video_green_o,
         video_blue_o         => main_video_blue_o,
         video_vs_o           => main_video_vs_o,
         video_hs_o           => main_video_hs_o,
         video_hblank_o       => main_video_hblank_o,
         video_vblank_o       => main_video_vblank_o,

         -- Audio output (PCM format, signed values)
         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         -- M2M Keyboard interface
         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         -- MEGA65 joysticks
         joy_1_up_n_i         => main_joy_1_up_n_i ,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,

         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i
      ); -- i_main

   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   -- Use On-Screen-Menu selections to configure several audio and video settings
   -- Video and audio mode control
   qnice_video_mode_o         <= qnice_osm_control_i(C_MENU_HDMI_60HZ);       -- 720p always; 0 = 50Hz, 1 = 60 Hz
   qnice_audio_mute_o         <= '0';                                         -- audio is not muted
   qnice_audio_filter_o       <= qnice_osm_control_i(C_MENU_IMPROVE_AUDIO);   -- 0 = raw audio, 1 = use filters from globals.vhd
   qnice_zoom_crop_o          <= qnice_osm_control_i(C_MENU_HDMI_ZOOM);       -- 0 = no zoom/crop

   -- ascal filters that are applied while zooming the input to 720p
   -- 00 : Nearest Neighbour
   -- 01 : Bilinear
   -- 10 : Sharp Bilinear
   -- 11 : Bicubic
   qnice_ascal_mode_o         <= "00";

   -- If polyphase is '1' then the ascal filter mode is ignored and polyphase filters are used instead
   -- @TODO: Right now, the filters are hardcoded in the M2M framework, we need to make them changeable inside m2m-rom.asm
   qnice_ascal_polyphase_o    <= qnice_osm_control_i(C_MENU_CRT_EMULATION);

   -- ascal triple-buffering
   -- @TODO: Right now, the M2M framework only supports OFF, so do not touch until the framework is upgraded
   qnice_ascal_triplebuf_o    <= '0';

   -- Flip joystick ports (i.e. the joystick in port 2 is used as joystick 1 and vice versa)
   qnice_flip_joyports_o      <= '0';

   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   core_specific_devices : process(all)
   begin
      -- make sure that this is x"EEEE" by default and avoid a register here by having this default value
      qnice_dev_data_o     <= x"EEEE";

      -- Demo core specific: Delete before starting to port your core
      qnice_demo_vd_ce     <= '0';
      qnice_demo_vd_we     <= '0';

      case qnice_dev_id_i is

         -- Demo core specific stuff: delete before porting your own core
         when C_DEV_DEMO_VD =>
            qnice_demo_vd_ce     <= qnice_dev_ce_i;
            qnice_demo_vd_we     <= qnice_dev_we_i;
            qnice_dev_data_o     <= qnice_demo_vd_data_o;

         -- @TODO YOUR RAMs or ROMs (e.g. for cartridges) or other devices here
         -- Device numbers need to be >= 0x0100

         when others => null;
      end case;
   end process core_specific_devices;

   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   -- Put your dual-clock devices such as RAMs and ROMs here
   --
   -- Use the M2M framework's official RAM/ROM: dualport_2clk_ram
   -- and make sure that the you configure the port that works with QNICE as a falling edge
   -- by setting G_FALLING_A or G_FALLING_B (depending on which port you use) to true.

   ---------------------------------------------------------------------------------------
   -- Virtual drive handler
   --
   -- Only added for demo-purposes at this place, so that we can demonstrate the
   -- firmware's ability to browse files and folders. It is very likely, that the
   -- virtual drive handler needs to be placed somewhere else, for example inside
   -- main.vhd. We advise to delete this before starting to port a core and re-adding
   -- it later (and at the right place), if and when needed.
   ---------------------------------------------------------------------------------------

   i_vdrives : entity work.vdrives
      generic map (
         VDNUM       => C_VDNUM
      )
      port map
      (
         clk_qnice_i       => qnice_clk_i,
         clk_core_i        => main_clk,
         reset_core_i      => main_reset_core_i,

         -- Core clock domain
         img_mounted_o     => open,
         img_readonly_o    => open,
         img_size_o        => open,
         img_type_o        => open,
         drive_mounted_o   => open,

         -- QNICE clock domain

         sd_lba_i          => (others => (others => '0')),
         sd_blk_cnt_i      => (others => (others => '0')),
         sd_rd_i           => (others => '0'),
         sd_wr_i           => (others => '0'),
         sd_ack_o          => open,

         sd_buff_addr_o    => open,
         sd_buff_dout_o    => open,
         sd_buff_din_i     => (others => (others => '0')),
         sd_buff_wr_o      => open,

         -- QNICE interface (MMIO, 4k-segmented)
         -- qnice_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         qnice_addr_i      => qnice_dev_addr_i,
         qnice_data_i      => qnice_dev_data_i,
         qnice_data_o      => qnice_demo_vd_data_o,
         qnice_ce_i        => qnice_demo_vd_ce,
         qnice_we_i        => qnice_demo_vd_we
      );

end architecture synthesis;
