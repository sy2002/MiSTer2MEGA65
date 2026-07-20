----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Optional sync-pulse reshaper for the analog VGA Standard mode
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2026 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.video_modes_pkg.all;

entity vga_sync_reshaper is
   generic (
      G_CONFIG : vga_sync_reshaper_cfg_t := C_VGA_SYNC_RESHAPER_OFF
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      enable_i : in  std_logic;
      hs_i     : in  std_logic;
      vs_i     : in  std_logic;
      hs_o     : out std_logic;
      vs_o     : out std_logic
   );
end entity vga_sync_reshaper;

architecture synthesis of vga_sync_reshaper is

   constant C_BYPASS : boolean := not G_CONFIG.ENABLED;

begin

   assert C_BYPASS or (G_CONFIG.HSYNC_WIDTH_CLKS > 0 and G_CONFIG.VSYNC_WIDTH_LINES > 0)
      report "vga_sync_reshaper: enabled sync widths must be nonzero"
      severity failure;

   g_bypass : if C_BYPASS generate
      hs_o <= hs_i;
      vs_o <= vs_i;
   end generate g_bypass;

   g_reshape : if not C_BYPASS generate
      signal hs_d             : std_logic := '0';
      signal vs_d             : std_logic := '0';
      signal hsync_active     : std_logic := '0';
      signal vsync_active     : std_logic := '0';
      signal hsync_count      : natural range 0 to G_CONFIG.HSYNC_WIDTH_CLKS := 0;
      signal vsync_line_count : natural range 0 to G_CONFIG.VSYNC_WIDTH_LINES := 0;
   begin
      -- Only a definite enable selects the reshaped signal. During mode changes,
      -- all other values fall back to the original syncs immediately.
      hs_o <= G_CONFIG.HSYNC_POLARITY when enable_i = '1' and hsync_active = '1' else
              not G_CONFIG.HSYNC_POLARITY when enable_i = '1' else
              hs_i;
      vs_o <= G_CONFIG.VSYNC_POLARITY when enable_i = '1' and vsync_active = '1' else
              not G_CONFIG.VSYNC_POLARITY when enable_i = '1' else
              vs_i;

      p_reshape : process(clk_i)
      begin
         if rising_edge(clk_i) then
            hs_d <= hs_i;
            vs_d <= vs_i;

            if rst_i = '1' or enable_i /= '1' then
               hsync_active     <= '0';
               vsync_active     <= '0';
               hsync_count      <= 0;
               vsync_line_count <= 0;
            else
               -- Preserve the source leading edge, but replace the HS duration.
               if hs_d = '0' and hs_i = '1' then
                  hsync_active <= '1';
                  hsync_count  <= G_CONFIG.HSYNC_WIDTH_CLKS - 1;
               elsif hsync_count > 0 then
                  hsync_active <= '1';
                  hsync_count  <= hsync_count - 1;
               else
                  hsync_active <= '0';
               end if;

               -- MiSTer scandoubler VS transitions are aligned with the falling
               -- edge of active-high HS. Start on the source VS leading edge and
               -- end after the configured number of complete output lines.
               if vs_d = '0' and vs_i = '1' then
                  vsync_active     <= '1';
                  vsync_line_count <= 0;
               elsif vsync_active = '1' and hs_d = '1' and hs_i = '0' then
                  if vsync_line_count = G_CONFIG.VSYNC_WIDTH_LINES - 1 then
                     vsync_active <= '0';
                  else
                     vsync_line_count <= vsync_line_count + 1;
                  end if;
               end if;
            end if;
         end if;
      end process p_reshape;
   end generate g_reshape;

end architecture synthesis;
