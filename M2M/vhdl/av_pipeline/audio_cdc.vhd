library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Clock Domain Crossing specialized for audio data:
-- Only propagate the sample when there is no metastability.
--
-- In the constraint file, add the following line:
-- set_max_delay 8 -datapath_only -from [get_clocks] -to [get_pins -hierarchical "*audio_cdc_gen.dst_*_d_reg[*]/D"]

entity audio_cdc is
   generic (
      G_REGISTER_SRC : boolean  -- Add register to input data
   );
   port (
      src_clk_i   : in  std_logic;
      src_left_i  : in  signed(15 downto 0);
      src_right_i : in  signed(15 downto 0);
      dst_clk_i   : in  std_logic;
      dst_left_o  : out signed(15 downto 0);
      dst_right_o : out signed(15 downto 0)
   );
end entity audio_cdc;

architecture synthesis of audio_cdc is

   signal src_left     : signed(15 downto 0);
   signal src_right    : signed(15 downto 0);
   signal dst_left_d   : signed(15 downto 0);
   signal dst_right_d  : signed(15 downto 0);
   signal dst_left_dd  : signed(15 downto 0);
   signal dst_right_dd : signed(15 downto 0);

   attribute async_reg                 : string;
   attribute async_reg of dst_left_d   : signal is "true";
   attribute async_reg of dst_right_d  : signal is "true";
   attribute async_reg of dst_left_dd  : signal is "true";
   attribute async_reg of dst_right_dd : signal is "true";

begin

   -- Optionally add a register to the input samples
   gen_input_src : if G_REGISTER_SRC generate
      p_input_reg : process (src_clk_i)
      begin
         if rising_edge(src_clk_i) then
            src_left  <= src_left_i;
            src_right <= src_right_i;
         end if;
      end process p_input_reg;
   else generate
      src_left  <= src_left_i;
      src_right <= src_right_i;
   end generate gen_input_src;

   -- Use generate to create a nice unique name for constraining
   audio_cdc_gen : if true generate
      p_sample : process (dst_clk_i)
      begin
         if rising_edge(dst_clk_i) then
            dst_left_d   <= src_left;   -- CDC
            dst_right_d  <= src_right;  -- CDC
            dst_left_dd  <= dst_left_d;
            dst_right_dd <= dst_right_d;

            if dst_left_d = dst_left_dd and dst_right_d = dst_right_dd then
               dst_left_o  <= dst_left_dd;
               dst_right_o <= dst_right_dd;
            end if;
         end if;
      end process p_sample;
   end generate audio_cdc_gen;

end architecture synthesis;

