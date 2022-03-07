------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Demo core that produces a test image including test sound, so that MiSTer2MEGA65
-- can be synthesized and tested stand alone even before the MiSTer core is being
-- applied. The MEGA65 "Help" menu can be used to change the behavior of the core.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2021 and licensed under GPL v3
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity democore is
   generic (
      G_CORE_CLK_SPEED     : natural;
      G_OUTPUT_DX          : natural;
      G_OUTPUT_DY          : natural
   );
   port (
      clk_main_i           : in  std_logic;
      reset_i              : in  std_logic;
      pause_i              : in  std_logic;
      keyboard_n_i         : in  std_logic_vector(2 downto 0);

      -- VGA output
      vga_ce_o             : out std_logic;
      vga_red_o            : out std_logic_vector(7 downto 0);
      vga_green_o          : out std_logic_vector(7 downto 0);
      vga_blue_o           : out std_logic_vector(7 downto 0);
      vga_vs_o             : out std_logic;
      vga_hs_o             : out std_logic;
      vga_de_o             : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o         : out signed(15 downto 0);
      audio_right_o        : out signed(15 downto 0)

   );
end entity democore;

architecture synthesis of democore is

    -- The democore is configured to generate a PAL signal at 720x576 resolution.
   constant CLK_KHZ   : integer := 27000;
   constant PIX_SIZE  : integer := 11;
   constant H_PIXELS  : integer :=  720;      -- horizontal display width in pixels
   constant V_PIXELS  : integer :=  576;      -- vertical display width in rows
   constant H_FP      : integer :=   17;      -- horizontal front porch width in pixels
   constant H_PULSE   : integer :=   64;      -- horizontal sync pulse width in pixels
   constant H_BP      : integer :=   63;      -- horizontal back porch width in pixels
   constant V_FP      : integer :=    5;      -- vertical front porch width in rows
   constant V_PULSE   : integer :=    5;      -- vertical sync pulse width in rows
   constant V_BP      : integer :=   39;      -- vertical back porch width in rows
   constant H_MAX     : integer :=  864;
   constant V_MAX     : integer :=  625;
   constant H_POL     : std_logic := '1';     -- horizontal sync pulse polarity (1 = positive, 0 = negative)
   constant V_POL     : std_logic := '1';     -- vertical sync pulse polarity (1 = positive, 0 = negative)

   signal vga_pixel_x : std_logic_vector(PIX_SIZE-1 downto 0) := (others => '0');
   signal vga_pixel_y : std_logic_vector(PIX_SIZE-1 downto 0) := (others => '0');

   constant C_HS_START : integer := H_PIXELS + H_FP;
   constant C_VS_START : integer := V_PIXELS + V_FP;

   constant C_BORDER  : integer := 4;  -- Number of pixels
   constant C_SQ_SIZE : integer := 50; -- Number of pixels

   signal pos_x : integer range 0 to H_PIXELS-1 := H_PIXELS/2;
   signal pos_y : integer range 0 to V_PIXELS-1 := V_PIXELS/2;
   signal vel_x : integer range -7 to 7         := 1;
   signal vel_y : integer range -7 to 7         := 1;

   alias vga_clk_i : std_logic is clk_main_i;

begin

   audio_left_o  <= (others => '0');
   audio_right_o <= (others => '0');


   -------------------------------------
   -- Generate horizontal pixel counter
   -------------------------------------

   p_pixel_x : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if unsigned(vga_pixel_x) = H_MAX-1 then
            vga_pixel_x <= (others => '0');
         else
            vga_pixel_x <= std_logic_vector(unsigned(vga_pixel_x) + 1);
         end if;
      end if;
   end process p_pixel_x;


   -----------------------------------
   -- Generate vertical pixel counter
   -----------------------------------

   p_pixel_y : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if unsigned(vga_pixel_x) = H_MAX-1 then
            if unsigned(vga_pixel_y) = V_MAX-1 then
               vga_pixel_y <= (others => '0');
            else
               vga_pixel_y <= std_logic_vector(unsigned(vga_pixel_y) + 1);
            end if;
         end if;
      end if;
   end process p_pixel_y;


   -----------------------------------
   -- Generate sync pulses
   -----------------------------------

   p_sync : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Generate horizontal sync signal
         if unsigned(vga_pixel_x) >= C_HS_START and
            unsigned(vga_pixel_x) < C_HS_START+H_PULSE then

            vga_hs_o <= H_POL;
         else
            vga_hs_o <= not H_POL;
         end if;

         -- Generate vertical sync signal
         if unsigned(vga_pixel_y) >= C_VS_START and
            unsigned(vga_pixel_y) < C_VS_START+V_PULSE then

            vga_vs_o <= V_POL;
         else
            vga_vs_o <= not V_POL;
         end if;

         -- Default is black
         vga_de_o <= '0';

         -- Only show color when inside visible screen area
         if unsigned(vga_pixel_x) < H_PIXELS and
            unsigned(vga_pixel_y) < V_PIXELS then

            vga_de_o <= '1';
         end if;
      end if;
   end process p_sync;


   p_rgb : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Render background
         vga_red_o   <= X"88";
         vga_green_o <= X"CC";
         vga_blue_o  <= X"AA";

         -- Render white border
         if unsigned(vga_pixel_x) < C_BORDER or unsigned(vga_pixel_x) + C_BORDER >= H_PIXELS or
            unsigned(vga_pixel_y) < C_BORDER or unsigned(vga_pixel_y) + C_BORDER >= V_PIXELS then
            vga_red_o   <= X"FF";
            vga_green_o <= X"FF";
            vga_blue_o  <= X"FF";
         end if;

         -- Render red-ish square
         if unsigned(vga_pixel_x) >= pos_x and unsigned(vga_pixel_x) < pos_x + C_SQ_SIZE and
            unsigned(vga_pixel_y) >= pos_y and unsigned(vga_pixel_y) < pos_y + C_SQ_SIZE then
            vga_red_o   <= X"EE";
            vga_green_o <= X"20";
            vga_blue_o  <= X"40";
         end if;
      end if;
   end process p_rgb;


   -- Move the square
   p_move : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         -- Update once each frame
         if unsigned(vga_pixel_x) = 0 and unsigned(vga_pixel_y) = 0 then
            pos_x <= pos_x + vel_x;
            pos_y <= pos_y + vel_y;

            if pos_x + vel_x >= H_PIXELS - C_SQ_SIZE - C_BORDER and vel_x > 0 then
               vel_x <= -vel_x;
            end if;

            if pos_x + vel_x < C_BORDER and vel_x < 0 then
               vel_x <= -vel_x;
            end if;

            if pos_y + vel_y >= V_PIXELS - C_SQ_SIZE - C_BORDER and vel_y > 0 then
               vel_y <= -vel_y;
            end if;

            if pos_y + vel_y < C_BORDER and vel_y < 0 then
               vel_y <= -vel_y;
            end if;
         end if;
      end if;
   end process p_move;

   vga_ce_o <= '1';

end architecture synthesis;

