----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Debug module to provide information about video resolution
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity video_counters is
port (
   video_clk_i    : in  std_logic;
   video_rst_i    : in  std_logic;
   video_ce_i     : in  std_logic;  -- Must be active high
   video_vs_i     : in  std_logic;  -- Must be active high
   video_hs_i     : in  std_logic;  -- Must be active high
   video_hblank_i : in  std_logic;  -- Must be active high
   video_vblank_i : in  std_logic;  -- Must be active high
   video_pps_i    : in  std_logic;  -- Must be active high
   video_x_vis_o  : out std_logic_vector(15 downto 0);
   video_x_tot_o  : out std_logic_vector(15 downto 0);
   video_y_vis_o  : out std_logic_vector(15 downto 0);
   video_y_tot_o  : out std_logic_vector(15 downto 0);
   video_h_freq_o : out std_logic_vector(15 downto 0)
);
end entity video_counters;

architecture synthesis of video_counters is

   signal video_vs_d  : std_logic;
   signal video_hs_d  : std_logic;

   signal video_x_vis  : std_logic_vector(15 downto 0);
   signal video_x_tot  : std_logic_vector(15 downto 0);
   signal video_y_vis  : std_logic_vector(15 downto 0);
   signal video_y_tot  : std_logic_vector(15 downto 0);
   signal video_h_freq : std_logic_vector(15 downto 0);

begin

   process (video_clk_i)
   begin
      if rising_edge(video_clk_i) then
         if video_ce_i = '1' then
            video_vs_d <= video_vs_i;
            video_hs_d <= video_hs_i;

            video_x_tot <= video_x_tot + 1;
            if video_hblank_i = '0' then
               video_x_vis <= video_x_vis + 1;
            end if;

            if video_hs_d = '0' and video_hs_i = '1' then
               video_x_vis_o <= video_x_vis;
               video_x_tot_o <= video_x_tot + 1;
               video_x_tot   <= (others => '0');
               video_x_vis   <= (others => '0');
               video_h_freq  <= video_h_freq + 1;

               video_y_tot <= video_y_tot + 1;
               if video_vblank_i = '0' then
                  video_y_vis <= video_y_vis + 1;
               end if;

               if video_vs_d = '0' and video_vs_i = '1' then
                  video_y_vis_o <= video_y_vis;
                  video_y_tot_o <= video_y_tot + 1;
                  video_y_vis   <= (others => '0');
                  video_y_tot   <= (others => '0');
               end if;
            end if;
         end if;

         if video_pps_i = '1' then
            video_h_freq_o <= video_h_freq;
            video_h_freq <= (others => '0');
         end if;
      end if;
   end process;

end architecture synthesis;

