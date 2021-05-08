----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_to_pixels is
   generic (
      GB_DX : integer := 160;          -- Game Boy's X pixel resolution
      GB_DY : integer := 144           -- ditto Y
   );
   port (
      clk_i              : in  std_logic;
      sc_ce_i            : in  std_logic;
      qngbc_color_i      : in  std_logic;
      qngbc_color_mode_i : in  std_logic;
      lcd_clkena_i       : in  std_logic;
      lcd_data_i         : in  std_logic_vector(14 downto 0);
      lcd_mode_i         : in  std_logic_vector(1 downto 0);
      lcd_on_i           : in  std_logic;
      lcd_vsync_i        : in  std_logic;
      pixel_out_we_o     : out std_logic;
      pixel_out_ptr_o    : out integer range 0 to (GB_DX * GB_DY) - 1 := 0;
      pixel_out_data_o   : out std_logic_vector(23 downto 0)
   );
end lcd_to_pixels;

architecture synthesis of lcd_to_pixels is

   signal lcd_r_blank_de      : std_logic := '0';
   signal lcd_r_blank_output  : std_logic := '0';
   signal lcd_r_off           : std_logic := '0';
   signal lcd_r_old_off       : std_logic := '0';
   signal lcd_r_old_on        : std_logic := '0';
   signal lcd_r_old_vs        : std_logic := '0';
   signal lcd_r_blank_hcnt    : integer range 0 to GB_DX - 1 := 0;
   signal lcd_r_blank_vcnt    : integer range 0 to GB_DY - 1 := 0;
   signal lcd_r_blank_data    : std_logic_vector(14 downto 0) := (others => '0');

begin

   lcd_to_pixels : process (clk_i)
      variable r5, g5, b5                : unsigned(4 downto 0);
      variable r8, g8, b8                : std_logic_vector(7 downto 0);
      variable r10, g10, b10             : unsigned(9 downto 0);
      variable r10_min, g10_min, b10_min : unsigned(9 downto 0);
      variable gray                      : unsigned(7 downto 0);
      variable data                      : std_logic_vector(14 downto 0);
      variable pixel_we                  : std_logic;
   begin
      if rising_edge(clk_i) then
         pixel_we := sc_ce_i and (lcd_clkena_i or lcd_r_blank_de);
         pixel_out_we_o <= pixel_we;

         if lcd_on_i = '0' or lcd_mode_i = "01" then
            lcd_r_off <= '1';
         else
            lcd_r_off <= '0';
         end if;

         if lcd_on_i = '0' and lcd_r_blank_output = '1' and lcd_r_blank_hcnt < GB_DX and lcd_r_blank_vcnt < GB_DY then
            lcd_r_blank_de <= '1';
         else
            lcd_r_blank_de <= '0';
         end if;

         if pixel_we = '1' then
            pixel_out_ptr_o <= pixel_out_ptr_o + 1;
         end if;

         lcd_r_old_off <= lcd_r_off;
         if (lcd_r_old_off xor lcd_r_off) = '1' then
            pixel_out_ptr_o <= 0;
         end if;

         lcd_r_old_on <= lcd_on_i;
         if lcd_r_old_on = '1' and lcd_on_i = '0' and lcd_r_blank_output = '0' then
            lcd_r_blank_output <= '1';
            lcd_r_blank_hcnt <= 0;
            lcd_r_blank_vcnt <= 0;
         end if;

         -- regenerate LCD timings for filling with blank color when LCD is off
         if sc_ce_i = '1' and lcd_on_i = '0' and lcd_r_blank_output = '1' then
            lcd_r_blank_data <= lcd_data_i;
            lcd_r_blank_hcnt <= lcd_r_blank_hcnt + 1;
            if lcd_r_blank_hcnt = 455 then
               lcd_r_blank_hcnt <= 0;
               lcd_r_blank_vcnt <= lcd_r_blank_vcnt + 1;
               if lcd_r_blank_vcnt = 153 then
                  lcd_r_blank_vcnt <= 0;
                  pixel_out_ptr_o <= 0;
               end if;
            end if;
         end if;

         -- output 1 blank frame until VSync after LCD is enabled
         lcd_r_old_vs <= lcd_vsync_i;
         if lcd_r_old_vs = '0' and lcd_vsync_i = '1' and lcd_r_blank_output = '1' then
            lcd_r_blank_output <= '0';
         end if;

         if lcd_on_i = '1' and lcd_r_blank_output = '1' then
            data := lcd_r_blank_data;
         else
            data := lcd_data_i;
         end if;

         -- grayscale values taken from MiSTer's lcd.v
         if (qngbc_color_i = '0') then
            case (data(1 downto 0)) is
               when "00"   => gray := to_unsigned(252, 8);
               when "01"   => gray := to_unsigned(168, 8);
               when "10"   => gray := to_unsigned(96, 8);
               when "11"   => gray := x"00";
               when others => gray := x"00";
            end case;
            pixel_out_data_o <= std_logic_vector(gray) & std_logic_vector(gray) & std_logic_vector(gray);
         else
            -- Game Boy's color output is only 5-bit
            r5 := unsigned(data(4 downto 0));
            g5 := unsigned(data(9 downto 5));
            b5 := unsigned(data(14 downto 10));

            -- color grading / lcd emulation, taken from:
            -- https://web.archive.org/web/20210223205311/https://byuu.net/video/color-emulation/
            --
            -- R = (r * 26 + g *  4 + b *  2);
            -- G = (         g * 24 + b *  8);
            -- B = (r *  6 + g *  4 + b * 22);
            -- R = min(960, R) >> 2;
            -- G = min(960, G) >> 2;
            -- B = min(960, B) >> 2;

            r10 := (r5 * 26) + (g5 *  4) + (b5 *  2);
            g10 :=             (g5 * 24) + (b5 *  8);
            b10 := (r5 *  6) + (g5 *  4) + (b5 * 22);

            r10_min := MINIMUM(960, r10); -- just for being on the safe side, we are using separate vars. for the MINIMUM
            g10_min := MINIMUM(960, g10);
            b10_min := MINIMUM(960, b10);

            -- fully saturated color mode (raw rgb): repeat bit pattern to convert 5-bit color to 8-bit color according to byuu.net
            if qngbc_color_mode_i = '0' then
               r8 := std_logic_vector(r5 & r5(4 downto 2));
               g8 := std_logic_vector(g5 & g5(4 downto 2));
               b8 := std_logic_vector(b5 & b5(4 downto 2));

            -- LCD Emulation mode according to byuu.net
            else
               r8 := std_logic_vector(r10_min(9 downto 2)); -- taking 9 downto 2 equals >> 2
               g8 := std_logic_vector(g10_min(9 downto 2));
               b8 := std_logic_vector(b10_min(9 downto 2));
            end if;

            pixel_out_data_o <= r8 & g8 & b8;
         end if;
      end if;
   end process;
end architecture synthesis;

