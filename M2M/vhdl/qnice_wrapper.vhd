----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the QNICE subsystem of M2M
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

library work;
use work.globals.all;
use work.types_pkg.all;

entity qnice_wrapper is
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   clk_i                     : in  std_logic;
   rst_i                     : in  std_logic;

   -- Serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   uart_rxd_i                : in  std_logic;                  -- receive data
   uart_txd_o                : out std_logic;                  -- send data

   -- Micro SD Connector (external slot at back of the cover)
   sd_reset_o                : out std_logic;
   sd_clk_o                  : out std_logic;
   sd_mosi_o                 : out std_logic;
   sd_miso_i                 : in  std_logic;
   sd_cd_i                   : in  std_logic;

   -- SD Connector (this is the slot at the bottom side of the case under the cover)
   sd2_reset_o               : out std_logic;
   sd2_clk_o                 : out std_logic;
   sd2_mosi_o                : out std_logic;
   sd2_miso_i                : in  std_logic;
   sd2_cd_i                  : in  std_logic;

   paddle_i                  : in  std_logic_vector(3 downto 0);
   paddle_drain_o            : out std_logic;

   -- On-Screen-Menu (OSM)
   qnice_osm_cfg_enable_o    : out std_logic;
   qnice_osm_cfg_xy_o        : out std_logic_vector(15 downto 0);
   qnice_osm_cfg_dxdy_o      : out std_logic_vector(15 downto 0);
   qnice_hdmax_i             : in  std_logic_vector(11 downto 0);
   qnice_vdmax_i             : in  std_logic_vector(11 downto 0);
   qnice_h_pixels_i          : in  std_logic_vector(11 downto 0); -- horizontal visible display width in pixels
   qnice_v_pixels_i          : in  std_logic_vector(11 downto 0); -- horizontal visible display width in pixels
   qnice_h_pulse_i           : in  std_logic_vector(11 downto 0); -- horizontal sync pulse width in pixels
   qnice_h_bp_i              : in  std_logic_vector(11 downto 0); -- horizontal back porch width in pixels
   qnice_h_fp_i              : in  std_logic_vector(11 downto 0); -- horizontal front porch width in pixels
   qnice_v_pulse_i           : in  std_logic_vector(11 downto 0); -- horizontal sync pulse width in pixels
   qnice_v_bp_i              : in  std_logic_vector(11 downto 0); -- horizontal back porch width in pixels
   qnice_v_fp_i              : in  std_logic_vector(11 downto 0); -- horizontal front porch width in pixels
   qnice_h_freq_i            : in  std_logic_vector(15 downto 0); -- horizontal sync frequency

   -- QNICE control signals
   qnice_ascal_mode_i        : in  std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_i   : in  std_logic;
   qnice_ascal_triplebuf_i   : in  std_logic;
   qnice_flip_joyports_i     : in  std_logic;
   qnice_osm_control_m_o     : out std_logic_vector(255 downto 0);
   qnice_gp_reg_o            : out std_logic_vector(255 downto 0);

   -- Control and status register that QNICE uses to control the Core
   qnice_csr_reset_o         : out std_logic;
   qnice_csr_pause_o         : out std_logic;
   qnice_csr_keyboard_on_o   : out std_logic;
   qnice_csr_joy1_on_o       : out std_logic;
   qnice_csr_joy2_on_o       : out std_logic;

   -- ascal.vhd mode register and polyphase filter handling
   qnice_ascal_mode_o        : out std_logic_vector(4 downto 0);  -- name qnice_ascal_mode is already taken
   qnice_poly_wr_o           : out std_logic;

   -- VRAM
   qnice_vram_data_i         : in  std_logic_vector(15 downto 0);
   qnice_vram_we_o           : out std_logic;   -- Writing to bits 7-0
   qnice_vram_attr_we_o      : out std_logic;   -- Writing to bits 15-8

   -- m2m_keyb output for the firmware and the Shell; see also sysdef.asm
   qnice_qnice_keys_n_i      : in  std_logic_vector(15 downto 0);

   qnice_pot1_x_n_o          : out unsigned(7 downto 0);
   qnice_pot1_y_n_o          : out unsigned(7 downto 0);
   qnice_pot2_x_n_o          : out unsigned(7 downto 0);
   qnice_pot2_y_n_o          : out unsigned(7 downto 0);

   qnice_avm_write_o         : out std_logic;
   qnice_avm_read_o          : out std_logic;
   qnice_avm_address_o       : out std_logic_vector(31 downto 0);
   qnice_avm_writedata_o     : out std_logic_vector(15 downto 0);
   qnice_avm_byteenable_o    : out std_logic_vector( 1 downto 0);
   qnice_avm_burstcount_o    : out std_logic_vector( 7 downto 0);
   qnice_avm_readdata_i      : in  std_logic_vector(15 downto 0);
   qnice_avm_readdatavalid_i : in  std_logic;
   qnice_avm_waitrequest_i   : in  std_logic;

   qnice_pps_i               : in  std_logic;
   qnice_hdmi_clk_freq_i     : in  std_logic_vector(27 downto 0);

   qnice_hr_count_long_i     : in  std_logic_vector(31 downto 0);
   qnice_hr_count_short_i    : in  std_logic_vector(31 downto 0);

   qnice_i2c_wait_i          : in  std_logic;
   qnice_i2c_ce_o            : out std_logic;
   qnice_i2c_we_o            : out std_logic;
   qnice_i2c_rd_data_i       : in  std_logic_vector(15 downto 0);

   qnice_rtc_wait_i          : in  std_logic;
   qnice_rtc_ce_o            : out std_logic;
   qnice_rtc_we_o            : out std_logic;
   qnice_rtc_rd_data_i       : in  std_logic_vector(15 downto 0);

   -- QNICE device management
   qnice_ramrom_dev_o        : out std_logic_vector(15 downto 0);
   qnice_ramrom_addr_o       : out std_logic_vector(27 downto 0);
   qnice_ramrom_data_out_o   : out std_logic_vector(15 downto 0);
   qnice_ramrom_data_in_i    : in  std_logic_vector(15 downto 0);
   qnice_ramrom_ce_o         : out std_logic;
   qnice_ramrom_we_o         : out std_logic;
   qnice_ramrom_wait_i       : in  std_logic
);
end entity qnice_wrapper;

architecture synthesis of qnice_wrapper is

---------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------

-- Devices: MiSTer2MEGA framework
constant C_DEV_VRAM_DATA      : std_logic_vector(15 downto 0) := x"0000";
constant C_DEV_VRAM_ATTR      : std_logic_vector(15 downto 0) := x"0001";
constant C_DEV_OSM_CONFIG     : std_logic_vector(15 downto 0) := x"0002";
constant C_DEV_ASCAL_PPHASE   : std_logic_vector(15 downto 0) := x"0003";
constant C_DEV_HYPERRAM       : std_logic_vector(15 downto 0) := x"0004";
constant C_DEV_I2C            : std_logic_vector(15 downto 0) := x"0005";
constant C_DEV_RTC            : std_logic_vector(15 downto 0) := x"0006";
constant C_DEV_SYS_INFO       : std_logic_vector(15 downto 0) := x"00FF";

-- SysInfo record numbers
constant C_SYS_DRIVES         : std_logic_vector(15 downto 0) := x"0000";
constant C_SYS_VGA            : std_logic_vector(15 downto 0) := x"0010";
constant C_SYS_HDMI           : std_logic_vector(15 downto 0) := x"0011";
constant C_SYS_CRTSANDROMS    : std_logic_vector(15 downto 0) := x"0020";
constant C_SYS_CORE           : std_logic_vector(15 downto 0) := x"0030";
constant C_SYS_BOARD          : std_logic_vector(15 downto 0) := x"0040";
constant C_SYS_HYPERRAM       : std_logic_vector(15 downto 0) := x"0041";

-- Device management
signal qnice_ramrom_data_in          : std_logic_vector(15 downto 0);
signal qnice_ramrom_data_in_hyperram : std_logic_vector(15 downto 0);
signal qnice_ramrom_wait             : std_logic;
signal qnice_ramrom_wait_hyperram    : std_logic;
signal qnice_ramrom_ce_hyperram      : std_logic;
signal qnice_ramrom_address          : std_logic_vector(31 downto 0);

-- Shell configuration (config.vhd)
signal qnice_config_data             : std_logic_vector(15 downto 0);

-- Paddles in 50 MHz clock domain which happens to be QNICE's
signal qnice_pot1_x                  : unsigned(7 downto 0);
signal qnice_pot1_y                  : unsigned(7 downto 0);
signal qnice_pot2_x                  : unsigned(7 downto 0);
signal qnice_pot2_y                  : unsigned(7 downto 0);

-- Statistics
signal qnice_hr_count_long_d         : std_logic_vector(31 downto 0);
signal qnice_hr_count_short_d        : std_logic_vector(31 downto 0);
signal qnice_hr_count_long_dd        : std_logic_vector(31 downto 0);
signal qnice_hr_count_short_dd       : std_logic_vector(31 downto 0);

-- return ASCII value of given string at the position defined by index (zero-based)
pure function str2data(str : string; index : integer) return std_logic_vector is
variable strpos : integer;
begin
   strpos := index + 1;
   if strpos <= str'length then
      return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
   else
      return X"0000"; -- zero terminated strings
   end if;
end function str2data;

begin

   -- QNICE Co-Processor (System-on-a-Chip) for On-Screen-Menu, Disk mounting/virtual drives, ROM loading, etc.
   QNICE_SOC : entity work.QNICE
      generic map (
         G_FIRMWARE              => QNICE_FIRMWARE,
         G_VGA_DX                => VGA_DX,
         G_VGA_DY                => VGA_DY,
         G_FONT_DX               => FONT_DX,
         G_FONT_DY               => FONT_DY
      )
      port map (
         clk50_i                 => clk_i,
         reset_n_i               => not rst_i,

         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         uart_rxd_i              => uart_rxd_i,
         uart_txd_o              => uart_txd_o,

         -- Micro SD Connector (external slot at back of the cover)
         sd_reset_o              => sd_reset_o,
         sd_clk_o                => sd_clk_o,
         sd_mosi_o               => sd_mosi_o,
         sd_miso_i               => sd_miso_i,
         sd_cd_i                 => sd_cd_i,

         -- SD Connector (this is the slot at the bottom side of the case under the cover)
         sd2_reset_o             => sd2_reset_o,
         sd2_clk_o               => sd2_clk_o,
         sd2_mosi_o              => sd2_mosi_o,
         sd2_miso_i              => sd2_miso_i,
         sd2_cd_i                => sd2_cd_i,

         -- QNICE public registers
         csr_reset_o             => qnice_csr_reset_o,
         csr_pause_o             => qnice_csr_pause_o,
         csr_osm_o               => qnice_osm_cfg_enable_o,
         csr_keyboard_o          => qnice_csr_keyboard_on_o,
         csr_joy1_o              => qnice_csr_joy1_on_o,
         csr_joy2_o              => qnice_csr_joy2_on_o,
         osm_xy_o                => qnice_osm_cfg_xy_o,
         osm_dxdy_o              => qnice_osm_cfg_dxdy_o,

         ascal_mode_i            => "0" & qnice_ascal_triplebuf_i & qnice_ascal_polyphase_i & qnice_ascal_mode_i,
         ascal_mode_o            => qnice_ascal_mode_o,

         -- Keyboard input for the firmware and Shell (see sysdef.asm)
         keys_n_i                => qnice_qnice_keys_n_i,

         -- 256-bit General purpose control flags
         -- "d" = directly controled by the firmware
         -- "m" = indirectly controled by the menu system
         control_d_o             => qnice_gp_reg_o,
         control_m_o             => qnice_osm_control_m_o,

         -- 16-bit special-purpose and 16-bit general-purpose input flags
         -- Special-purpose flags are having a given semantic when the "Shell" firmware is running,
         -- but right now they are reserved and not used, yet.
         special_i               => (others => '0'),
         general_i               => (others => '0'),

         -- QNICE MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
         -- ramrom_dev_o: 0 = VRAM data, 1 = VRAM attributes, > 256 = free to be used for any "RAM like" device
         -- ramrom_addr_o is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         ramrom_dev_o            => qnice_ramrom_dev_o,
         ramrom_addr_o           => qnice_ramrom_addr_o,
         ramrom_data_o           => qnice_ramrom_data_out_o,
         ramrom_data_i           => qnice_ramrom_data_in,
         ramrom_ce_o             => qnice_ramrom_ce_o,
         ramrom_wait_i           => qnice_ramrom_wait,
         ramrom_we_o             => qnice_ramrom_we_o
      ); -- QNICE_SOC

   -- Shell configuration file config.vhd
   shell_cfg : entity work.config
      port map (
         clk_i                   => clk_i,
         -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
         -- bits 11 downto 0: address the up to 4k the configuration data
         address_i               => qnice_ramrom_addr_o,

         -- config data
         data_o                  => qnice_config_data
      ); -- shell_cfg

   -- QNICE devices selected via qnice_ramrom_dev
   --    Devices with IDs < x"0100" are framework devices
   --    All others are user specific / core specific devices
   -- (refer to M2M/rom/sysdef.asm for a memory map and more details)
   qnice_ramrom_devices : process(all)
      variable strpos      : natural;
      variable current_chr : std_logic_vector(15 downto 0);
   begin
      qnice_ramrom_ce_hyperram <= '0';
      qnice_ramrom_data_in     <= x"EEEE";
      qnice_ramrom_wait        <= '0';
      qnice_vram_we_o          <= '0';
      qnice_vram_attr_we_o     <= '0';
      qnice_poly_wr_o          <= '0';
      qnice_i2c_ce_o           <= '0';
      qnice_i2c_we_o           <= '0';
      qnice_rtc_ce_o           <= '0';
      qnice_rtc_we_o           <= '0';

      -----------------------------------
      -- Framework devices
      -----------------------------------
      if qnice_ramrom_dev_o < x"0100" then
         case qnice_ramrom_dev_o is

            -- On-Screen-Menu (OSM) video ram data and attributes
            when C_DEV_VRAM_DATA =>
               qnice_vram_we_o            <= qnice_ramrom_we_o;
               qnice_ramrom_data_in       <= x"00" & qnice_vram_data_i(7 downto 0);
            when C_DEV_VRAM_ATTR =>
               qnice_vram_attr_we_o       <= qnice_ramrom_we_o;
               qnice_ramrom_data_in       <= x"00" & qnice_vram_data_i(15 downto 8);

            -- Shell configuration data (config.vhd)
            when C_DEV_OSM_CONFIG =>
               qnice_ramrom_data_in       <= qnice_config_data;

            -- ascal.vhd's polyphase handling
            when C_DEV_ASCAL_PPHASE =>
               qnice_ramrom_data_in       <= x"EEEE"; -- write-only
               qnice_poly_wr_o            <= qnice_ramrom_we_o;

            -- HyperRAM access
            when C_DEV_HYPERRAM =>
               qnice_ramrom_ce_hyperram   <= qnice_ramrom_ce_o;
               qnice_ramrom_data_in       <= qnice_ramrom_data_in_hyperram;
               qnice_ramrom_wait          <= qnice_ramrom_wait_hyperram;

            -- I2C devices access
            when C_DEV_I2C =>
               qnice_i2c_ce_o             <= qnice_ramrom_ce_o;
               qnice_i2c_we_o             <= qnice_ramrom_we_o;
               qnice_ramrom_data_in       <= qnice_i2c_rd_data_i;
               qnice_ramrom_wait          <= qnice_i2c_wait_i;

            -- RTC devices access
            when C_DEV_RTC =>
               qnice_rtc_ce_o             <= qnice_ramrom_ce_o;
               qnice_rtc_we_o             <= qnice_ramrom_we_o;
               qnice_ramrom_data_in       <= qnice_rtc_rd_data_i;
               qnice_ramrom_wait          <= qnice_rtc_wait_i;

            -- Read-only System Info (constants are defined in sysdef.asm)
            when C_DEV_SYS_INFO =>
               case qnice_ramrom_addr_o(27 downto 12) is

                  -- Virtual drives
                  when C_SYS_DRIVES =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        when x"000" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned(C_VDNUM, 16));
                        when x"001" => qnice_ramrom_data_in <= C_VD_DEVICE;

                        when others =>
                           if qnice_ramrom_addr_o(11 downto 4) = x"10" then
                              qnice_ramrom_data_in <= C_VD_BUFFER(to_integer(unsigned(qnice_ramrom_addr_o(3 downto 0))));
                           end if;
                     end case;

                  -- Simulated cartridges and ROMs
                  when C_SYS_CRTSANDROMS =>
                     if qnice_ramrom_addr_o(11 downto 0) = x"000" then
                        qnice_ramrom_data_in <= std_logic_vector(to_unsigned(C_CRTROMS_MAN_NUM, 16));
                     elsif qnice_ramrom_addr_o(11 downto 0) = x"001" then
                        qnice_ramrom_data_in <= std_logic_vector(to_unsigned(C_CRTROMS_AUTO_NUM, 16));
                     elsif qnice_ramrom_addr_o(11 downto 8) = x"1" then
                        qnice_ramrom_data_in <= C_CRTROMS_MAN(to_integer(unsigned(qnice_ramrom_addr_o(7 downto 0))));
                     elsif qnice_ramrom_addr_o(11 downto 8) = x"2" then
                        qnice_ramrom_data_in <= C_CRTROMS_AUTO(to_integer(unsigned(qnice_ramrom_addr_o(7 downto 0))));
                     elsif qnice_ramrom_addr_o(11 downto 8) >= x"3" then
                        strpos := to_integer(unsigned(qnice_ramrom_addr_o(15 downto 0))) - 16#7300# + 1;
                        qnice_ramrom_data_in <= std_logic_vector(to_unsigned(character'pos(C_CRTROMS_AUTO_NAMES(strpos)), 16));
                     end if;

                  -- Graphics card VGA
                  when C_SYS_VGA =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        -- SYS_DXDY
                        when X"000" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        -- SHELL_M_XY: Always start at the top/left corner
                        when X"001" => qnice_ramrom_data_in <= x"0000";

                        -- SHELL_M_DXDY: Use full screen
                        when X"002" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        when others => null;
                     end case;

                  -- Graphics card HDMI
                  when C_SYS_HDMI =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        -- SYS_DXDY
                        when X"000" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        -- SHELL_M_XY: Always start at the top/left corner
                        when X"001" => qnice_ramrom_data_in <= x"0000";

                        -- SHELL_M_DXDY: Use full screen
                        when X"002" => qnice_ramrom_data_in <= std_logic_vector(to_unsigned((VGA_DX/FONT_DX) * 256 + (VGA_DY/FONT_DY), 16));

                        when X"003" => qnice_ramrom_data_in <= qnice_hdmi_clk_freq_i(15 downto 0);
                        when X"004" => qnice_ramrom_data_in <= "0000" & qnice_hdmi_clk_freq_i(27 downto 16);
                        when others => null;
                     end case;

                  -- Info about the core
                  when C_SYS_CORE =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        -- CORE_X: Horizontal size of core display
                        when X"000" => qnice_ramrom_data_in <= "0000" & qnice_hdmax_i;

                        -- CORE_Y: Vertical size of core display
                        when X"001" => qnice_ramrom_data_in <= "0000" & qnice_vdmax_i;

                        -- CORE_H_PIXELS:
                        when X"002" => qnice_ramrom_data_in <= "0000" & qnice_h_pixels_i;

                        -- CORE_V_PIXELS:
                        when X"003" => qnice_ramrom_data_in <= "0000" & qnice_v_pixels_i;

                        -- CORE_H_PULSE:
                        when X"004" => qnice_ramrom_data_in <= "0000" & qnice_h_pulse_i;

                        -- CORE_H_BP:
                        when X"005" => qnice_ramrom_data_in <= "0000" & qnice_h_bp_i;

                        -- CORE_H_FP:
                        when X"006" => qnice_ramrom_data_in <= "0000" & qnice_h_fp_i;

                        -- CORE_V_PULSE:
                        when X"007" => qnice_ramrom_data_in <= "0000" & qnice_v_pulse_i;

                        -- CORE_V_BP:
                        when X"008" => qnice_ramrom_data_in <= "0000" & qnice_v_bp_i;

                        -- CORE_V_FP:
                        when X"009" => qnice_ramrom_data_in <= "0000" & qnice_v_fp_i;

                        -- CORE_H_FREQ:
                        when X"00A" => qnice_ramrom_data_in <= qnice_h_freq_i;

                        when others => null;
                     end case;

                  -- Info about the board
                  when C_SYS_BOARD =>
                     qnice_ramrom_data_in <= str2data(G_BOARD, to_integer(unsigned(qnice_ramrom_addr_o(11 downto 0))));

                  when C_SYS_HYPERRAM =>
                     case qnice_ramrom_addr_o(11 downto 0) is
                        when X"000" => qnice_ramrom_data_in <= qnice_hr_count_long_dd(15 downto 0);
                        when X"001" => qnice_ramrom_data_in <= qnice_hr_count_long_dd(31 downto 16);
                        when X"002" => qnice_ramrom_data_in <= qnice_hr_count_short_dd(15 downto 0);
                        when X"003" => qnice_ramrom_data_in <= qnice_hr_count_short_dd(31 downto 16);
                        when X"004" => qnice_ramrom_data_in <= qnice_hr_count_long_d(15 downto 0);
                        when X"005" => qnice_ramrom_data_in <= qnice_hr_count_long_d(31 downto 16);
                        when X"006" => qnice_ramrom_data_in <= qnice_hr_count_short_d(15 downto 0);
                        when X"007" => qnice_ramrom_data_in <= qnice_hr_count_short_d(31 downto 16);
                        when X"008" => qnice_ramrom_data_in <= qnice_hr_count_long_i(15 downto 0);
                        when X"009" => qnice_ramrom_data_in <= qnice_hr_count_long_i(31 downto 16);
                        when X"00A" => qnice_ramrom_data_in <= qnice_hr_count_short_i(15 downto 0);
                        when X"00B" => qnice_ramrom_data_in <= qnice_hr_count_short_i(31 downto 16);
                        when others => null;
                     end case;

                  when others => null;
               end case;
            when others => null;
         end case;

      -----------------------------------
      -- User/core specific devices
      -----------------------------------
      else
         qnice_ramrom_data_in <= qnice_ramrom_data_in_i;
         qnice_ramrom_wait    <= qnice_ramrom_wait_i;
      end if;
   end process qnice_ramrom_devices;

   qnice_ramrom_address <= "10000" & qnice_ramrom_addr_o(26 downto 0) when qnice_ramrom_addr_o(27) = '1'
                      else "000000000" & qnice_ramrom_addr_o(22 downto 0);

   i_qnice2hyperram : entity work.qnice2hyperram
      port map (
         clk_i                 => clk_i,
         rst_i                 => rst_i,
         s_qnice_wait_o        => qnice_ramrom_wait_hyperram,
         s_qnice_address_i     => qnice_ramrom_address,
         s_qnice_cs_i          => qnice_ramrom_ce_hyperram,
         s_qnice_write_i       => qnice_ramrom_we_o,
         s_qnice_writedata_i   => qnice_ramrom_data_out_o,
         s_qnice_byteenable_i  => "11",
         s_qnice_readdata_o    => qnice_ramrom_data_in_hyperram,
         m_avm_write_o         => qnice_avm_write_o,
         m_avm_read_o          => qnice_avm_read_o,
         m_avm_address_o       => qnice_avm_address_o,
         m_avm_writedata_o     => qnice_avm_writedata_o,
         m_avm_byteenable_o    => qnice_avm_byteenable_o,
         m_avm_burstcount_o    => qnice_avm_burstcount_o,
         m_avm_readdata_i      => qnice_avm_readdata_i,
         m_avm_readdatavalid_i => qnice_avm_readdatavalid_i,
         m_avm_waitrequest_i   => qnice_avm_waitrequest_i
      ); -- i_qnice2hyperram

   p_hr_stats : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if qnice_pps_i = '1' then
            qnice_hr_count_long_d  <= qnice_hr_count_long_i;
            qnice_hr_count_short_d <= qnice_hr_count_short_i;

            qnice_hr_count_long_dd  <= std_logic_vector(unsigned(qnice_hr_count_long_i) - unsigned(qnice_hr_count_long_d));
            qnice_hr_count_short_dd <= std_logic_vector(unsigned(qnice_hr_count_short_i) - unsigned(qnice_hr_count_short_d));
         end if;
      end if;
   end process p_hr_stats;

   -- Generate the paddle readings (mouse not supported, yet)
   -- Works with 50 MHz, which happens to be the QNICE clock domain
   i_mouse_paddles: entity work.mouse_input
      port map (
         clk                     => clk_i,

         mouse_debug             => open,
         amiga_mouse_enable_a    => '0',
         amiga_mouse_enable_b    => '0',
         amiga_mouse_assume_a    => '0',
         amiga_mouse_assume_b    => '0',

         -- These are the 1351 mouse / C64 paddle inputs and drain control
         fa_potx                 => paddle_i(0),
         fa_poty                 => paddle_i(1),
         fb_potx                 => paddle_i(2),
         fb_poty                 => paddle_i(3),
         pot_drain               => paddle_drain_o,

         -- To allow auto-detection of Amiga mouses, we need to know what the
         -- rest of the joystick pins are doing
         fa_fire                 => '1',
         fa_left                 => '1',
         fa_right                => '1',
         fa_up                   => '1',
         fa_down                 => '1',
         fb_fire                 => '1',
         fb_left                 => '1',
         fb_right                => '1',
         fb_up                   => '1',
         fb_down                 => '1',

         fa_up_out               => open,
         fa_down_out             => open,
         fa_left_out             => open,
         fa_right_out            => open,

         fb_up_out               => open,
         fb_down_out             => open,
         fb_left_out             => open,
         fb_right_out            => open,

         -- We output the four sampled pot values
         pota_x                  => qnice_pot1_x,
         pota_y                  => qnice_pot1_y,
         potb_x                  => qnice_pot2_x,
         potb_y                  => qnice_pot2_y
      ); -- i_mouse_paddles

    -- We need to invert the values that we get from i_mouse_paddles
   correct_and_flip_paddles : process(all)
   begin
      if qnice_flip_joyports_i = '0' then
         qnice_pot1_x_n_o <= x"FF" - qnice_pot1_x;
         qnice_pot1_y_n_o <= x"FF" - qnice_pot1_y;
         qnice_pot2_x_n_o <= x"FF" - qnice_pot2_x;
         qnice_pot2_y_n_o <= x"FF" - qnice_pot2_y;
      else
         qnice_pot2_x_n_o <= x"FF" - qnice_pot1_x;
         qnice_pot2_y_n_o <= x"FF" - qnice_pot1_y;
         qnice_pot1_x_n_o <= x"FF" - qnice_pot2_x;
         qnice_pot1_y_n_o <= x"FF" - qnice_pot2_y;
      end if;
   end process correct_and_flip_paddles;

end architecture synthesis;

