library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk_synthetic is
   generic (
      G_SRC_FREQ_HZ  : natural;
      G_DEST_FREQ_HZ : natural
   );
   port (
      src_clk_i  : in  std_logic;        -- reference clock
      src_rst_i  : in  std_logic;        -- reference clock reset, asserted high, synchronous
      dest_clk_o : out std_logic;        -- generated clock
      dest_rst_o : out std_logic         -- reset out, asserted high, synchronous
   );
end entity clk_synthetic;

architecture synthesis of clk_synthetic is

   signal counter  : integer range 0 to G_SRC_FREQ_HZ;
   signal dest_clk : std_logic;

begin

   assert 2*G_DEST_FREQ_HZ < G_SRC_FREQ_HZ;

   p_dest_clk : process (src_clk_i)
      variable new_counter : integer range 0 to 2*G_SRC_FREQ_HZ;
   begin
      if rising_edge(src_clk_i) then
         new_counter := counter + 2*G_DEST_FREQ_HZ;

         if new_counter >= G_SRC_FREQ_HZ then
            dest_clk <= not dest_clk;
            counter  <= new_counter - G_SRC_FREQ_HZ;
         else
            counter <= new_counter;
         end if;
      end if;
   end process p_dest_clk;

   i_bufg : bufg
      port map (
         I   => dest_clk,
         O   => dest_clk_o
      ); -- i_bufg

   i_xpm_cdc_sync_rst : xpm_cdc_sync_rst
      generic map (
         INIT_SYNC_FF => 1  -- Enable simulation init values
      )
      port map (
         src_rst  => src_rst_i,      -- 1-bit input: Source reset signal.
         dest_clk => dest_clk_o,     -- 1-bit input: Destination clock.
         dest_rst => dest_rst_o      -- 1-bit output: src_rst synchronized to the destination clock dovideo.
                                     -- This output is registered.
      ); -- i_xpm_cdc_sync_rst

end architecture synthesis;

