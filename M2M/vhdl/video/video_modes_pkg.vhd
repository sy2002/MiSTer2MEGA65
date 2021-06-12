library ieee;
use ieee.std_logic_1164.all;

package video_modes_pkg is

   type video_modes_t is record
      CLK_KHZ   : integer;    -- Pixel clock frequency in kHz
      H_PIXELS  : integer;    -- horizontal display width in pixels
      V_PIXELS  : integer;    -- vertical display width in rows
      H_PULSE   : integer;    -- horizontal sync pulse width in pixels
      H_BP      : integer;    -- horizontal back porch width in pixels
      H_FP      : integer;    -- horizontal front porch width in pixels
      V_PULSE   : integer;    -- vertical sync pulse width in rows
      V_BP      : integer;    -- vertical back porch width in rows
      V_FP      : integer;    -- vertical front porch width in rows
      H_POL     : std_logic;  -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL     : std_logic;  -- vertical sync pulse polarity (1 = positive, 0 = negative)
   end record video_modes_t;

   -- SVGA 800x600 @ 60 Hz
   -- Taken from this link: http://tinyvga.com/vga-timing/800x600@60Hz
   constant C_SVGA_800_600_60 : video_modes_t := (
      CLK_KHZ   => 40000,     -- 40 MHz
      H_PIXELS  => 800,       -- horizontal display width in pixels
      V_PIXELS  => 600,       -- vertical display width in rows
      H_PULSE   => 128,       -- horizontal sync pulse width in pixels
      H_BP      => 88,        -- horizontal back porch width in pixels
      H_FP      => 40,        -- horizontal front porch width in pixels
      V_PULSE   => 4,         -- vertical sync pulse width in rows
      V_BP      => 23,        -- vertical back porch width in rows
      V_FP      => 1,         -- vertical front porch width in rows
      H_POL     => '1',       -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL     => '1'        -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   -- PAL 720x576 @ 50 Hz
   -- Taken from section 4.9 in the document CEA-861-D
   constant C_PAL_720_576_50 : video_modes_t := (
      CLK_KHZ   => 27000,     -- 27 MHz
      H_PIXELS  => 720,       -- horizontal display width in pixels
      V_PIXELS  => 576,       -- vertical display width in rows
      H_PULSE   => 64,        -- horizontal sync pulse width in pixels
      H_BP      => 63,        -- horizontal back porch width in pixels
      H_FP      => 17,        -- horizontal front porch width in pixels
      V_PULSE   => 5,         -- vertical sync pulse width in rows
      V_BP      => 39,        -- vertical back porch width in rows
      V_FP      => 5,         -- vertical front porch width in rows
      H_POL     => '0',       -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL     => '0'        -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   -- HDMI 720p @ 60 Hz (1280x720)
   -- Taken from section 4.3 in the document CEA-861-D
   constant C_HDMI_720p_60 : video_modes_t := (
      CLK_KHZ   => 74250,     -- 74.25 MHz
      H_PIXELS  => 1280,      -- horizontal display width in pixels
      V_PIXELS  =>  720,      -- vertical display width in rows
      H_FP      =>  110,      -- horizontal front porch width in pixels
      H_PULSE   =>   40,      -- horizontal sync pulse width in pixels
      H_BP      =>  220,      -- horizontal back porch width in pixels
      V_FP      =>    5,      -- vertical front porch width in rows
      V_PULSE   =>    5,      -- vertical sync pulse width in rows
      V_BP      =>   20,      -- vertical back porch width in rows
      H_POL     => '0',       -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL     => '0'        -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

end package video_modes_pkg;

package body video_modes_pkg is
end package body video_modes_pkg;

