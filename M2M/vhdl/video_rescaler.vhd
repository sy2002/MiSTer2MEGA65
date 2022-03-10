library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity video_rescaler is
   generic (
      G_VIDEO_MODE      : video_modes_t      -- Desired output video mode
   );
   port (
      -- Core connections
      reset_na_i        : in    std_logic;   -- Asynchronous, asserted low reset

      core_clk_i        : in    std_logic;
      core_ce_i         : in    std_logic;   -- clock enable
      core_r_i          : in    std_logic_vector(7 downto 0);
      core_g_i          : in    std_logic_vector(7 downto 0);
      core_b_i          : in    std_logic_vector(7 downto 0);
      core_hs_i         : in    std_logic;   -- h sync
      core_vs_i         : in    std_logic;   -- v sync
      core_de_i         : in    std_logic;   -- display enable

      vga_clk_i         : in    std_logic;
      vga_ce_i          : in    std_logic;
      vga_r_o           : out   std_logic_vector(7 downto 0);
      vga_g_o           : out   std_logic_vector(7 downto 0);
      vga_b_o           : out   std_logic_vector(7 downto 0);
      vga_hs_o          : out   std_logic;   -- h sync
      vga_vs_o          : out   std_logic;   -- v sync
      vga_de_o          : out   std_logic;   -- display enable

      -- HyperRAM I/O connections
      hr_clk_x1_i       : in    std_logic;
      hr_clk_x2_i       : in    std_logic;
      hr_clk_x2_del_i   : in    std_logic;
      hr_rst_i          : in    std_logic;

      hr_resetn         : out   std_logic;
      hr_csn            : out   std_logic;
      hr_ck             : out   std_logic;
      hr_rwds           : inout std_logic;
      hr_dq             : inout std_logic_vector(7 downto 0)
   );
end entity video_rescaler;

architecture synthesis of video_rescaler is

   -- Auto-calculate display dimensions based on an 4:3 aspect ratio
   constant C_HTOTAL  : integer := G_VIDEO_MODE.H_PIXELS + G_VIDEO_MODE.H_FP + G_VIDEO_MODE.H_PULSE + G_VIDEO_MODE.H_BP;
   constant C_HSSTART : integer := G_VIDEO_MODE.H_PIXELS + G_VIDEO_MODE.H_FP;
   constant C_HSEND   : integer := G_VIDEO_MODE.H_PIXELS + G_VIDEO_MODE.H_FP + G_VIDEO_MODE.H_PULSE;
   constant C_HDISP   : integer := G_VIDEO_MODE.H_PIXELS;
   constant C_VTOTAL  : integer := G_VIDEO_MODE.V_PIXELS + G_VIDEO_MODE.V_FP + G_VIDEO_MODE.V_PULSE + G_VIDEO_MODE.V_BP;
   constant C_VSSTART : integer := G_VIDEO_MODE.V_PIXELS + G_VIDEO_MODE.V_FP;
   constant C_VSEND   : integer := G_VIDEO_MODE.V_PIXELS + G_VIDEO_MODE.V_FP + G_VIDEO_MODE.V_PULSE;
   constant C_VDISP   : integer := G_VIDEO_MODE.V_PIXELS;
   constant C_HMIN    : integer := (G_VIDEO_MODE.H_PIXELS-G_VIDEO_MODE.V_PIXELS*4/3)/2;
   constant C_HMAX    : integer := (G_VIDEO_MODE.H_PIXELS+G_VIDEO_MODE.V_PIXELS*4/3)/2-1;
   constant C_VMIN    : integer := 0;
   constant C_VMAX    : integer := G_VIDEO_MODE.V_PIXELS-1;

   -- Clocks
   alias  avl_clk    : std_logic is hr_clk_x1_i;

   -- Resets
   alias avl_rst     : std_logic is hr_rst_i;

   constant C_AVM_ADDRESS_SIZE : integer := 19;
   constant C_AVM_DATA_SIZE    : integer := 128;

   -- Video rescaler interface to HyperRAM
   signal avl_write           : std_logic;
   signal avl_read            : std_logic;
   signal avl_waitrequest     : std_logic;
   signal avl_address         : std_logic_vector(C_AVM_ADDRESS_SIZE-1 DOWNTO 0);
   signal avl_burstcount      : std_logic_vector(7 DOWNTO 0);
   signal avl_byteenable      : std_logic_vector(C_AVM_DATA_SIZE/8-1 DOWNTO 0);
   signal avl_writedata       : std_logic_vector(C_AVM_DATA_SIZE-1 DOWNTO 0);
   signal avl_readdata        : std_logic_vector(C_AVM_DATA_SIZE-1 DOWNTO 0);
   signal avl_readdatavalid   : std_logic;

   signal vga_r               : unsigned(7 downto 0);
   signal vga_g               : unsigned(7 downto 0);
   signal vga_b               : unsigned(7 downto 0);

begin

   vga_r_o <= std_logic_vector(vga_r);
   vga_g_o <= std_logic_vector(vga_g);
   vga_b_o <= std_logic_vector(vga_b);

   --------------------------------------------------------
   -- Instantiate video rescaler
   --------------------------------------------------------

   i_ascal : entity work.ascal
      generic map (
         MASK      => x"ff",
         RAMBASE   => (others => '0'),
         RAMSIZE   => x"0020_0000", -- = 2MB
         INTER     => true,
         HEADER    => true,
         DOWNSCALE => true,
         BYTESWAP  => true,
         PALETTE   => true,
         PALETTE2  => true,
         FRAC      => 4,
         OHRES     => 2048,
         IHRES     => 2048,
         N_DW      => C_AVM_DATA_SIZE,
         N_AW      => C_AVM_ADDRESS_SIZE,
         N_BURST   => 256  -- 256 bytes per burst
      )
      port map (
         i_r               => unsigned(core_r_i),           -- input
         i_g               => unsigned(core_g_i),           -- input
         i_b               => unsigned(core_b_i),           -- input
         i_hs              => core_hs_i,                    -- input
         i_vs              => core_vs_i,                    -- input
         i_fl              => '0',                          -- input
         i_de              => core_de_i,                    -- input
         i_ce              => core_ce_i,                    -- input
         i_clk             => core_clk_i,                   -- input
         o_r               => vga_r,                        -- output
         o_g               => vga_g,                        -- output
         o_b               => vga_b,                        -- output
         o_hs              => vga_hs_o,                     -- output
         o_vs              => vga_vs_o,                     -- output
         o_de              => vga_de_o,                     -- output
         o_vbl             => open,                         -- output
         o_ce              => vga_ce_i,                     -- input
         o_clk             => vga_clk_i,                    -- input
         o_border          => X"886644",                    -- input
         o_fb_ena          => '0',                          -- input
         o_fb_hsize        => 0,                            -- input
         o_fb_vsize        => 0,                            -- input
         o_fb_format       => "000100",                     -- input
         o_fb_base         => x"0000_0000",                 -- input
         o_fb_stride       => (others => '0'),              -- input
         pal1_clk          => '0',                          -- input
         pal1_dw           => x"000000000000",              -- input
         pal1_dr           => open,                         -- output
         pal1_a            => "0000000",                    -- input
         pal1_wr           => '0',                          -- input
         pal_n             => '0',                          -- input
         pal2_clk          => '0',                          -- input
         pal2_dw           => x"000000",                    -- input
         pal2_dr           => open,                         -- output
         pal2_a            => "00000000",                   -- input
         pal2_wr           => '0',                          -- input
         o_lltune          => open,                         -- output
         iauto             => '1',                          -- input
         himin             => 0,                            -- input
         himax             => 0,                            -- input
         vimin             => 0,                            -- input
         vimax             => 0,                            -- input
         i_hdmax           => open,                         -- output
         i_vdmax           => open,                         -- output
         run               => '1',                          -- input
         freeze            => '0',                          -- input
         mode              => "00000",                      -- input
         htotal            => C_HTOTAL,                     -- input
         hsstart           => C_HSSTART,                    -- input
         hsend             => C_HSEND,                      -- input
         hdisp             => C_HDISP,                      -- input
         vtotal            => C_VTOTAL,                     -- input
         vsstart           => C_VSSTART,                    -- input
         vsend             => C_VSEND,                      -- input
         vdisp             => C_VDISP,                      -- input
         hmin              => C_HMIN,                       -- input
         hmax              => C_HMAX,                       -- input
         vmin              => C_VMIN,                       -- input
         vmax              => C_VMAX,                       -- input
         format            => "01",                         -- input
         poly_clk          => '0',                          -- input
         poly_dw           => (others => '0'),              -- input
         poly_a            => (others => '0'),              -- input
         poly_wr           => '0',                          -- input
         avl_clk           => avl_clk,                      -- input
         avl_waitrequest   => avl_waitrequest,              -- input
         avl_readdata      => avl_readdata,                 -- input
         avl_readdatavalid => avl_readdatavalid,            -- input
         avl_burstcount    => avl_burstcount,               -- output
         avl_writedata     => avl_writedata,                -- output
         avl_address       => avl_address,                  -- output
         avl_write         => avl_write,                    -- output
         avl_read          => avl_read,                     -- output
         avl_byteenable    => avl_byteenable,               -- output
         reset_na          => reset_na_i                    -- input
      ); -- i_ascal


   --------------------------------------------------------
   -- HyperRAM wrapper
   --------------------------------------------------------

   i_hyperram_wrapper : entity work.hyperram_wrapper
      generic map (
         N_DW => C_AVM_DATA_SIZE,
         N_AW => C_AVM_ADDRESS_SIZE
      )
      port map (
         avl_clk_i           => avl_clk,
         avl_rst_i           => avl_rst,
         avl_burstcount_i    => avl_burstcount,
         avl_writedata_i     => avl_writedata,
         avl_address_i       => avl_address,
         avl_write_i         => avl_write,
         avl_read_i          => avl_read,
         avl_byteenable_i    => avl_byteenable,
         avl_waitrequest_o   => avl_waitrequest,
         avl_readdata_o      => avl_readdata,
         avl_readdatavalid_o => avl_readdatavalid,
         clk_x2_i            => hr_clk_x2_i,
         clk_x2_del_i        => hr_clk_x2_del_i,
         hr_resetn_o         => hr_resetn,
         hr_csn_o            => hr_csn,
         hr_ck_o             => hr_ck,
         hr_rwds_io          => hr_rwds,
         hr_dq_io            => hr_dq
      ); -- i_hyperram_wrapper

end architecture synthesis;

