library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_recover_counters is
   port (
      vga_clk_i   : in  std_logic;

      -- VGA input
      vga_ce_i    : in  std_logic;
      vga_red_i   : in  std_logic_vector(7 downto 0);
      vga_green_i : in  std_logic_vector(7 downto 0);
      vga_blue_i  : in  std_logic_vector(7 downto 0);
      vga_hs_i    : in  std_logic;
      vga_vs_i    : in  std_logic;
      vga_de_i    : in  std_logic;

      -- VGA output
      vga_ce_o    : out std_logic;
      vga_pix_x_o : out std_logic_vector(10 downto 0);
      vga_pix_y_o : out std_logic_vector(10 downto 0);
      vga_red_o   : out std_logic_vector(7 downto 0);
      vga_green_o : out std_logic_vector(7 downto 0);
      vga_blue_o  : out std_logic_vector(7 downto 0);
      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_de_o    : out std_logic
   );
end entity vga_recover_counters;

architecture synthesis of vga_recover_counters is

   signal vga_pix_x : std_logic_vector(10 downto 0);
   signal vga_pix_y : std_logic_vector(10 downto 0);
   signal new_frame : std_logic;

begin

   vga_pix_x_o <= vga_pix_x;
   vga_pix_y_o <= vga_pix_y;

   p_counters : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_ce_o <= vga_ce_i;

         if vga_ce_i = '1' then
            vga_red_o   <= vga_red_i;
            vga_green_o <= vga_green_i;
            vga_blue_o  <= vga_blue_i;
            vga_hs_o    <= vga_hs_i;
            vga_vs_o    <= vga_vs_i;
            vga_de_o    <= vga_de_i;

            vga_pix_x <= std_logic_vector(unsigned(vga_pix_x) + 1);
            if vga_de_o = '0' and vga_de_i = '1' then -- Detect rising edge of DE signal
               vga_pix_x <= (others => '0');
               vga_pix_y <= std_logic_vector(unsigned(vga_pix_y) + 1);

               if new_frame = '1' then
                  vga_pix_y <= (others => '0');
                  new_frame <= '0';
               end if;
            end if;

            if vga_vs_i = '1' then  -- TBD: Is the polarity correct ?
               new_frame <= '1';
            end if;
         end if;
      end if;
   end process p_counters;

end architecture synthesis;

