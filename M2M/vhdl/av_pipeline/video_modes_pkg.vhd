library ieee;
use ieee.std_logic_1164.all;

package video_modes_pkg is

   type video_modes_t is record
      CLK_KHZ     : integer;                       -- Pixel clock frequency in kHz
      CLK_SEL     : std_logic_vector(2 downto 0);  -- Pixel clock selection
                                                   -- 000 =  25.200 MHz
                                                   -- 001 =  27.000 MHz
                                                   -- 010 =  74.250 MHz
                                                   -- 011 = 148.500 MHz
                                                   -- 100 =  25.175 MHz
                                                   -- 101 =  27.027 MHz
                                                   -- 110 =  74.176 MHz
                                                   -- 111 = undefined
      CEA_CTA_VIC : integer;                       -- CEA/CTA VIC
      ASPECT      : std_logic_vector(1 downto 0);  -- aspect ratio: 01=4:3, 10=16:9
      PIXEL_REP   : std_logic;                     -- 0=no pixel repetition; 1=pixel repetition
      H_PIXELS    : integer;                       -- horizontal display width in pixels
      V_PIXELS    : integer;                       -- vertical display width in rows
      H_PULSE     : integer;                       -- horizontal sync pulse width in pixels
      H_BP        : integer;                       -- horizontal back porch width in pixels
      H_FP        : integer;                       -- horizontal front porch width in pixels
      V_PULSE     : integer;                       -- vertical sync pulse width in rows
      V_BP        : integer;                       -- vertical back porch width in rows
      V_FP        : integer;                       -- vertical front porch width in rows
      H_POL       : std_logic;                     -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       : std_logic;                     -- vertical sync pulse polarity (1 = positive, 0 = negative)
   end record video_modes_t;

   -- In the following, the supported video modes
   -- are sorted according to the CEA-861-D document

   --------------------------------------------------------
   -- 50 Hz modes
   --------------------------------------------------------

   -- PAL 720x576 @ 50 Hz
   -- Taken from section 4.9 in the document CEA-861-D
   constant C_PAL_720_576_50 : video_modes_t := (
      CLK_KHZ     => 27000,      -- 27.000 MHz
      CLK_SEL     => "001",
      CEA_CTA_VIC => 17,         -- CEA/CTA VIC 17=PAL 720x576 @ 50 Hz
      ASPECT      => "01",       -- aspect ratio: 01=4:3, 10=16:9: "01" for PAL
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 720,        -- horizontal display width in pixels
      V_PIXELS    => 576,        -- vertical display width in rows
      H_PULSE     => 64,         -- horizontal sync pulse width in pixels
      H_BP        => 63,         -- horizontal back porch width in pixels
      H_FP        => 17,         -- horizontal front porch width in pixels
      V_PULSE     => 5,          -- vertical sync pulse width in rows
      V_BP        => 39,         -- vertical back porch width in rows
      V_FP        => 5,          -- vertical front porch width in rows
      H_POL       => '0',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '0'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   -- HDMI 576p @ 50 Hz (720x576)
   -- Taken from section 4.9 in the document CEA-861-D
   constant C_HDMI_576p_50 : video_modes_t := (
      CLK_KHZ     => 27000,      -- 27.000 MHz
      CLK_SEL     => "001",
      CEA_CTA_VIC => 17,         -- CEA/CTA VIC: 720x576p, 50 Hz, 4:3
      ASPECT      => "01",       -- apsect ratio: 01=4:3, 10=16:9
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 720,        -- horizontal display width in pixels
      V_PIXELS    => 576,        -- vertical display width in rows
      H_FP        => 12,         -- horizontal front porch width in pixels
      H_PULSE     => 64,         -- horizontal sync pulse width in pixels
      H_BP        => 68,         -- horizontal back porch width in pixels
      V_FP        => 5,          -- vertical front porch width in rows
      V_PULSE     => 5,          -- vertical sync pulse width in rows
      V_BP        => 39,         -- vertical back porch width in rows
      H_POL       => '1',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '1'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   -- HDMI 720p @ 50 Hz (1280x720)
   -- Taken from section 4.7 in the document CEA-861-D
   constant C_HDMI_720p_50 : video_modes_t := (
      CLK_KHZ     => 74250,      -- 74.250 MHz
      CLK_SEL     => "010",
      CEA_CTA_VIC => 19,         -- CEA/CTA VIC: 1280x720p, 50 Hz, 16:9
      ASPECT      => "10",       -- apsect ratio: 01=4:3, 10=16:9
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 1280,       -- horizontal display width in pixels
      V_PIXELS    => 720,        -- vertical display width in rows
      H_FP        => 440,        -- horizontal front porch width in pixels
      H_PULSE     => 40,         -- horizontal sync pulse width in pixels
      H_BP        => 220,        -- horizontal back porch width in pixels
      V_FP        => 5,          -- vertical front porch width in rows
      V_PULSE     => 5,          -- vertical sync pulse width in rows
      V_BP        => 20,         -- vertical back porch width in rows
      H_POL       => '1',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '1'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );


   --------------------------------------------------------
   -- 59.94 Hz modes
   --------------------------------------------------------

   -- HDMI 480p @ 59.94 Hz (720x480)
   constant C_HDMI_720x480p_5994 : video_modes_t := (
      CLK_KHZ     => 27000,      -- 27.000 MHz
      CLK_SEL     => "001",
      CEA_CTA_VIC => 2,
      ASPECT      => "01",       -- apsect ratio: 01=4:3, 10=16:9
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 720,        -- horizontal display width in pixels
      V_PIXELS    => 480,        -- vertical display width in rows
      H_FP        => 16,         -- horizontal front porch width in pixels
      H_PULSE     => 62,         -- horizontal sync pulse width in pixels
      H_BP        => 60,         -- horizontal back porch width in pixels
      V_FP        => 9,          -- vertical front porch width in rows
      V_PULSE     => 6,          -- vertical sync pulse width in rows
      V_BP        => 30,         -- vertical back porch width in rows
      H_POL       => '0',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '0'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );


   --------------------------------------------------------
   -- 60.00 Hz modes
   --------------------------------------------------------

   -- HDMI 480p @ 60 Hz (640x480)
   constant C_HDMI_640x480p_60 : video_modes_t := (
      CLK_KHZ     => 25200,      -- 25.200 MHz
      CLK_SEL     => "000",
      CEA_CTA_VIC => 1,
      ASPECT      => "01",       -- apsect ratio: 01=4:3, 10=16:9
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 640,        -- horizontal display width in pixels
      V_PIXELS    => 480,        -- vertical display width in rows
      H_FP        => 16,         -- horizontal front porch width in pixels
      H_PULSE     => 96,         -- horizontal sync pulse width in pixels
      H_BP        => 48,         -- horizontal back porch width in pixels
      V_FP        => 10,         -- vertical front porch width in rows
      V_PULSE     => 2,          -- vertical sync pulse width in rows
      V_BP        => 33,         -- vertical back porch width in rows
      H_POL       => '0',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '0'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   -- HDMI 720p @ 60 Hz (1280x720)
   -- Taken from section 4.3 in the document CEA-861-D
   constant C_HDMI_720p_60 : video_modes_t := (
      CLK_KHZ     => 74250,      -- 74.250 MHz
      CLK_SEL     => "010",
      CEA_CTA_VIC => 4,          -- CEA/CTA VIC: 1280x720p, 60 Hz, 16:9
      ASPECT      => "10",       -- apsect ratio: 01=4:3, 10=16:9
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 1280,       -- horizontal display width in pixels
      V_PIXELS    => 720,        -- vertical display width in rows
      H_FP        => 110,        -- horizontal front porch width in pixels
      H_PULSE     => 40,         -- horizontal sync pulse width in pixels
      H_BP        => 220,        -- horizontal back porch width in pixels
      V_FP        => 5,          -- vertical front porch width in rows
      V_PULSE     => 5,          -- vertical sync pulse width in rows
      V_BP        => 20,         -- vertical back porch width in rows
      H_POL       => '0',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '0'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   -- SVGA 800x600 @ 60 Hz
   -- Taken from this link: http://tinyvga.com/vga-timing/800x600@60Hz
   -- CAUTION: CTA/CTV VIC does not officially support SVGA 800x600; there are some monitors, where it works, though
   constant C_SVGA_800_600_60 : video_modes_t := (
      CLK_KHZ     => 40000,      -- 40.000 MHz
      CLK_SEL     => "111",
      CEA_CTA_VIC => 65,         -- SVGA is not an official mode; "65" taken from here: https://www.raspberrypi.org/documentation/configuration/config-txt/video.md
      ASPECT      => "01",       -- aspect ratio: 01=4:3, 10=16:9: "01" for SVGA
      PIXEL_REP   => '0',        -- no pixel repetition
      H_PIXELS    => 800,        -- horizontal display width in pixels
      V_PIXELS    => 600,        -- vertical display width in rows
      H_PULSE     => 128,        -- horizontal sync pulse width in pixels
      H_BP        => 88,         -- horizontal back porch width in pixels
      H_FP        => 40,         -- horizontal front porch width in pixels
      V_PULSE     => 4,          -- vertical sync pulse width in rows
      V_BP        => 23,         -- vertical back porch width in rows
      V_FP        => 1,          -- vertical front porch width in rows
      H_POL       => '1',        -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      V_POL       => '1'         -- vertical sync pulse polarity (1 = positive, 0 = negative)
   );

   type video_modes_vector is array(natural range<>) of video_modes_t;

   --------------------------------------------------------
   -- Analog VGA sync reshaper
   --------------------------------------------------------

   -- The source syncs at the M2M core-video boundary are active-high.  When
   -- enabled, the reshaper preserves their leading edges and the complete
   -- raster period, but replaces the pulse widths and output polarities.
   type vga_sync_reshaper_cfg_t is record
      ENABLED           : boolean;
      HSYNC_WIDTH_CLKS  : natural;
      VSYNC_WIDTH_LINES : natural;
      HSYNC_POLARITY    : std_logic;
      VSYNC_POLARITY    : std_logic;
   end record vga_sync_reshaper_cfg_t;

   -- Backward-compatible default: no logic and an exact sync wire-through.
   constant C_VGA_SYNC_RESHAPER_OFF : vga_sync_reshaper_cfg_t := (
      ENABLED           => false,
      HSYNC_WIDTH_CLKS  => 0,
      VSYNC_WIDTH_LINES => 0,
      HSYNC_POLARITY    => '1',
      VSYNC_POLARITY    => '1'
   );

   -- A pulse-only preset describes the physical HS duration through a
   -- reference pixel clock and width. It does not describe or alter the
   -- active geometry, line period or frame period of the core's raster.
   type vga_sync_preset_t is record
      PIXEL_CLOCK_KHZ    : positive;
      HSYNC_WIDTH_PIXELS : positive;
      VSYNC_WIDTH_LINES : positive;
      HSYNC_POLARITY    : std_logic;
      VSYNC_POLARITY    : std_logic;
   end record vga_sync_preset_t;

   -- Common VESA DMT pulse profiles. make_vga_sync_reshaper_cfg converts the
   -- reference HS duration to the number of clocks in the core's video_clk.
   constant C_VGA_SYNC_DMT_640X480_60 : vga_sync_preset_t := (
      PIXEL_CLOCK_KHZ    => 25_175,
      HSYNC_WIDTH_PIXELS => 96,
      VSYNC_WIDTH_LINES  => 2,
      HSYNC_POLARITY     => '0',
      VSYNC_POLARITY     => '0'
   );

   constant C_VGA_SYNC_DMT_800X600_60 : vga_sync_preset_t := (
      PIXEL_CLOCK_KHZ    => 40_000,
      HSYNC_WIDTH_PIXELS => 128,
      VSYNC_WIDTH_LINES  => 4,
      HSYNC_POLARITY     => '1',
      VSYNC_POLARITY     => '1'
   );

   constant C_VGA_SYNC_DMT_1024X768_60 : vga_sync_preset_t := (
      PIXEL_CLOCK_KHZ    => 65_000,
      HSYNC_WIDTH_PIXELS => 136,
      VSYNC_WIDTH_LINES  => 6,
      HSYNC_POLARITY     => '0',
      VSYNC_POLARITY     => '0'
   );

   pure function make_vga_sync_reshaper_cfg (
      preset       : vga_sync_preset_t;
      video_clk_hz : positive
   ) return vga_sync_reshaper_cfg_t;

   type video_mode_type is (
      C_VIDEO_HDMI_16_9_50  ,  -- HDMI 1280x720    @ 50 Hz
      C_VIDEO_HDMI_16_9_60  ,  -- HDMI 1280x720    @ 60 Hz
      C_VIDEO_HDMI_4_3_50   ,  -- PAL  576p in 4:3 @ 50 Hz
      C_VIDEO_HDMI_5_4_50   ,  -- PAL  576p in 5:4 @ 50 Hz
      C_VIDEO_HDMI_640_60   ,  -- HDMI 640x480     @ 60 Hz
      C_VIDEO_HDMI_720_5994 ,  -- HDMI 720x480     @ 59.94 Hz
      C_VIDEO_SVGA_800_60      -- SVGA 800x600     @ 60 Hz
   );

   --------------------------------------------------------
   -- Digital HDMI output fitting
   --------------------------------------------------------

   -- HDMI fitting changes only the rectangle into which ascal draws the
   -- core image. The aspect ratio is the intended physical display aspect,
   -- not necessarily the ratio of encoded pixels (e.g. 720x480 is 4:3).
   type hdmi_fit_mode_t is (
      HDMI_FIT_MODE_LEGACY,      -- Preserve M2M's historical per-mode rectangle
      HDMI_FIT_MODE_FULL_FRAME,  -- Fill the complete HDMI active area
      HDMI_FIT_MODE_ASPECT       -- Fit a physical aspect ratio inside the frame
   );

   -- Ratios should be reduced to small integers. The bound also keeps every
   -- product for the supported HDMI modes inside VHDL's integer range.
   subtype hdmi_aspect_value_t is positive range 1 to 255;

   -- Runtime-selectable cropped-view sizes are rational fractions of the
   -- maximum rectangle produced by the selected HDMI fit. Fractions greater
   -- than one are rejected by make_hdmi_output_rect.
   subtype hdmi_scale_value_t is positive range 1 to 255;

   type hdmi_scale_t is record
      NUMERATOR   : hdmi_scale_value_t;
      DENOMINATOR : hdmi_scale_value_t;
   end record hdmi_scale_t;

   type hdmi_view_sizes_t is array(0 to 3) of hdmi_scale_t;

   constant C_HDMI_SCALE_FULL : hdmi_scale_t := (
      NUMERATOR   => 1,
      DENOMINATOR => 1
   );

   constant C_HDMI_VIEW_SIZES_FULL : hdmi_view_sizes_t :=
      (others => C_HDMI_SCALE_FULL);

   pure function make_hdmi_scale (
      numerator   : hdmi_scale_value_t;
      denominator : hdmi_scale_value_t
   ) return hdmi_scale_t;

   type hdmi_fit_t is record
      MODE          : hdmi_fit_mode_t;
      ASPECT_WIDTH  : hdmi_aspect_value_t;
      ASPECT_HEIGHT : hdmi_aspect_value_t;
   end record hdmi_fit_t;

   type hdmi_view_cfg_t is record
      UNCROPPED     : hdmi_fit_t;
      CROPPED       : hdmi_fit_t;
      CROPPED_SIZES : hdmi_view_sizes_t;
   end record hdmi_view_cfg_t;

   type hdmi_output_rect_t is record
      H_MIN : natural;
      H_MAX : natural;
      V_MIN : natural;
      V_MAX : natural;
   end record hdmi_output_rect_t;

   constant C_HDMI_FIT_LEGACY : hdmi_fit_t := (
      MODE          => HDMI_FIT_MODE_LEGACY,
      ASPECT_WIDTH  => 1,
      ASPECT_HEIGHT => 1
   );

   constant C_HDMI_FIT_FULL_FRAME : hdmi_fit_t := (
      MODE          => HDMI_FIT_MODE_FULL_FRAME,
      ASPECT_WIDTH  => 1,
      ASPECT_HEIGHT => 1
   );

   pure function make_hdmi_fit (
      aspect_width  : hdmi_aspect_value_t;
      aspect_height : hdmi_aspect_value_t
   ) return hdmi_fit_t;

   -- Common physical display-aspect presets for core porters.
   constant C_HDMI_FIT_1_1 : hdmi_fit_t := (
      MODE => HDMI_FIT_MODE_ASPECT, ASPECT_WIDTH => 1, ASPECT_HEIGHT => 1
   );
   constant C_HDMI_FIT_4_3 : hdmi_fit_t := (
      MODE => HDMI_FIT_MODE_ASPECT, ASPECT_WIDTH => 4, ASPECT_HEIGHT => 3
   );
   constant C_HDMI_FIT_5_4 : hdmi_fit_t := (
      MODE => HDMI_FIT_MODE_ASPECT, ASPECT_WIDTH => 5, ASPECT_HEIGHT => 4
   );
   constant C_HDMI_FIT_8_7 : hdmi_fit_t := (
      MODE => HDMI_FIT_MODE_ASPECT, ASPECT_WIDTH => 8, ASPECT_HEIGHT => 7
   );
   constant C_HDMI_FIT_10_9 : hdmi_fit_t := (
      MODE => HDMI_FIT_MODE_ASPECT, ASPECT_WIDTH => 10, ASPECT_HEIGHT => 9
   );
   constant C_HDMI_FIT_16_9 : hdmi_fit_t := (
      MODE => HDMI_FIT_MODE_ASPECT, ASPECT_WIDTH => 16, ASPECT_HEIGHT => 9
   );

   pure function make_hdmi_view_cfg (
      uncropped     : hdmi_fit_t;
      cropped       : hdmi_fit_t;
      cropped_sizes : hdmi_view_sizes_t := C_HDMI_VIEW_SIZES_FULL
   ) return hdmi_view_cfg_t;

   -- Exact backward-compatible default: the normal view uses M2M's
   -- historical per-mode placement and crop/zoom fills the complete frame.
   constant C_HDMI_VIEW_LEGACY : hdmi_view_cfg_t := (
      UNCROPPED     => C_HDMI_FIT_LEGACY,
      CROPPED       => C_HDMI_FIT_FULL_FRAME,
      CROPPED_SIZES => C_HDMI_VIEW_SIZES_FULL
   );

   -- Intended for elaboration-time use. The returned coordinates are
   -- inclusive as required by ascal's hmin/hmax/vmin/vmax inputs.
   pure function make_hdmi_output_rect (
      video_mode    : video_modes_t;
      video_mode_id : video_mode_type;
      fit           : hdmi_fit_t;
      scale         : hdmi_scale_t := C_HDMI_SCALE_FULL
   ) return hdmi_output_rect_t;

   pure function video_mode_to_slv(video_mode : video_mode_type) return std_logic_vector;

   pure function slv_to_video_mode(video_mode_slv : std_logic_vector) return video_mode_type;

end package video_modes_pkg;

package body video_modes_pkg is

   pure function divide_rounded (
      numerator   : natural;
      denominator : positive
   ) return natural is
   begin
      return (numerator + denominator / 2) / denominator;
   end function divide_rounded;

   pure function make_vga_sync_reshaper_cfg (
      preset       : vga_sync_preset_t;
      video_clk_hz : positive
   ) return vga_sync_reshaper_cfg_t is
      variable hsync_width_clks : natural;
   begin
      -- Dividing Hz to kHz first keeps the multiplication in a synthesis-safe
      -- integer range. The sub-kHz truncation is far below one output clock.
      hsync_width_clks := (((video_clk_hz / 1_000) * preset.HSYNC_WIDTH_PIXELS) +
                            (preset.PIXEL_CLOCK_KHZ / 2)) /
                           preset.PIXEL_CLOCK_KHZ;

      assert hsync_width_clks > 0
         report "make_vga_sync_reshaper_cfg: video clock is too slow for preset"
         severity failure;

      return (
         ENABLED           => true,
         HSYNC_WIDTH_CLKS  => hsync_width_clks,
         VSYNC_WIDTH_LINES => preset.VSYNC_WIDTH_LINES,
         HSYNC_POLARITY    => preset.HSYNC_POLARITY,
         VSYNC_POLARITY    => preset.VSYNC_POLARITY
      );
   end function make_vga_sync_reshaper_cfg;

   pure function make_hdmi_fit (
      aspect_width  : hdmi_aspect_value_t;
      aspect_height : hdmi_aspect_value_t
   ) return hdmi_fit_t is
   begin
      return (
         MODE          => HDMI_FIT_MODE_ASPECT,
         ASPECT_WIDTH  => aspect_width,
         ASPECT_HEIGHT => aspect_height
      );
   end function make_hdmi_fit;

   pure function make_hdmi_scale (
      numerator   : hdmi_scale_value_t;
      denominator : hdmi_scale_value_t
   ) return hdmi_scale_t is
   begin
      assert numerator <= denominator
         report "make_hdmi_scale: numerator must not exceed denominator"
         severity failure;

      return (
         NUMERATOR   => numerator,
         DENOMINATOR => denominator
      );
   end function make_hdmi_scale;

   pure function make_hdmi_view_cfg (
      uncropped     : hdmi_fit_t;
      cropped       : hdmi_fit_t;
      cropped_sizes : hdmi_view_sizes_t := C_HDMI_VIEW_SIZES_FULL
   ) return hdmi_view_cfg_t is
   begin
      return (
         UNCROPPED     => uncropped,
         CROPPED       => cropped,
         CROPPED_SIZES => cropped_sizes
      );
   end function make_hdmi_view_cfg;

   pure function make_hdmi_output_rect (
      video_mode    : video_modes_t;
      video_mode_id : video_mode_type;
      fit           : hdmi_fit_t;
      scale         : hdmi_scale_t := C_HDMI_SCALE_FULL
   ) return hdmi_output_rect_t is
      variable result        : hdmi_output_rect_t;
      variable frame_width   : positive := 1;
      variable frame_height  : positive := 1;
      variable target_width  : natural;
      variable target_height : natural;
   begin
      assert video_mode.H_PIXELS > 0 and video_mode.V_PIXELS > 0
         report "make_hdmi_output_rect: HDMI active dimensions must be positive"
         severity failure;

      result := (
         H_MIN => 0,
         H_MAX => natural(video_mode.H_PIXELS - 1),
         V_MIN => 0,
         V_MAX => natural(video_mode.V_PIXELS - 1)
      );

      case fit.MODE is
         when HDMI_FIT_MODE_FULL_FRAME =>
            null;

         when HDMI_FIT_MODE_LEGACY =>
            -- These are the original digital_pipeline equations. Keep them
            -- literal so C_HDMI_VIEW_LEGACY remains pixel-for-pixel stable.
            case video_mode_id is
               when C_VIDEO_HDMI_16_9_50 | C_VIDEO_HDMI_16_9_60 =>
                  target_width := natural(video_mode.V_PIXELS * 4 / 3);
                  assert video_mode.H_PIXELS >= target_width
                     report "make_hdmi_output_rect: legacy 4:3 image exceeds HDMI width"
                     severity failure;
                  result.H_MIN := natural((video_mode.H_PIXELS - target_width) / 2);
                  result.H_MAX := natural((video_mode.H_PIXELS + target_width) / 2 - 1);

               when C_VIDEO_HDMI_5_4_50 =>
                  target_height := natural(video_mode.H_PIXELS * 3 / 4);
                  assert video_mode.V_PIXELS >= target_height
                     report "make_hdmi_output_rect: legacy 5:4 image exceeds HDMI height"
                     severity failure;
                  result.V_MIN := natural((video_mode.V_PIXELS - target_height) / 2);
                  result.V_MAX := natural((video_mode.V_PIXELS + target_height) / 2 - 1);

               when others =>
                  null;
            end case;

         when HDMI_FIT_MODE_ASPECT =>
            -- The HDMI InfoFrame describes the physical shape of the active
            -- frame. Deriving the pixel aspect from it also handles CEA modes
            -- such as 720x480 and 720x576 with non-square encoded pixels.
            case video_mode.ASPECT is
               when "01" =>
                  frame_width  := 4;
                  frame_height := 3;

               when "10" =>
                  frame_width  := 16;
                  frame_height := 9;

               when others =>
                  assert false
                     report "make_hdmi_output_rect: unsupported HDMI frame aspect"
                     severity failure;
            end case;

            target_width  := natural(video_mode.H_PIXELS);
            target_height := natural(video_mode.V_PIXELS);

            if fit.ASPECT_WIDTH * frame_height <= fit.ASPECT_HEIGHT * frame_width then
               target_width := divide_rounded(
                  natural(video_mode.H_PIXELS) * fit.ASPECT_WIDTH * frame_height,
                  fit.ASPECT_HEIGHT * frame_width
               );
            else
               target_height := divide_rounded(
                  natural(video_mode.V_PIXELS) * frame_width * fit.ASPECT_HEIGHT,
                  frame_height * fit.ASPECT_WIDTH
               );
            end if;

            -- Protect ascal from an empty rectangle if a porter supplies an
            -- extreme custom ratio, and from rounding one pixel past a frame.
            if target_width = 0 then
               target_width := 1;
            elsif target_width > video_mode.H_PIXELS then
               target_width := natural(video_mode.H_PIXELS);
            end if;

            if target_height = 0 then
               target_height := 1;
            elsif target_height > video_mode.V_PIXELS then
               target_height := natural(video_mode.V_PIXELS);
            end if;

            result.H_MIN := natural((video_mode.H_PIXELS - target_width) / 2);
            result.H_MAX := result.H_MIN + target_width - 1;
            result.V_MIN := natural((video_mode.V_PIXELS - target_height) / 2);
            result.V_MAX := result.V_MIN + target_height - 1;
      end case;

      -- A 1/1 scale is a deliberate short path: it preserves every legacy
      -- coordinate exactly instead of recalculating an equivalent rectangle.
      if scale.NUMERATOR > scale.DENOMINATOR then
         assert false
            report "make_hdmi_output_rect: scale numerator must not exceed denominator"
            severity failure;
         return result;
      elsif scale.NUMERATOR < scale.DENOMINATOR then
         target_width := divide_rounded(
            (result.H_MAX - result.H_MIN + 1) * scale.NUMERATOR,
            scale.DENOMINATOR
         );
         target_height := divide_rounded(
            (result.V_MAX - result.V_MIN + 1) * scale.NUMERATOR,
            scale.DENOMINATOR
         );

         -- A legal positive fraction can still round a very small rectangle
         -- to zero, which ascal cannot accept.
         if target_width = 0 then
            target_width := 1;
         end if;
         if target_height = 0 then
            target_height := 1;
         end if;

         result.H_MIN := natural((video_mode.H_PIXELS - target_width) / 2);
         result.H_MAX := result.H_MIN + target_width - 1;
         result.V_MIN := natural((video_mode.V_PIXELS - target_height) / 2);
         result.V_MAX := result.V_MIN + target_height - 1;
      end if;

      return result;
   end function make_hdmi_output_rect;

   pure function video_mode_to_slv(video_mode : video_mode_type) return std_logic_vector is
   begin
      case video_mode is
         when C_VIDEO_HDMI_16_9_50  => return "0000";
         when C_VIDEO_HDMI_16_9_60  => return "0001";
         when C_VIDEO_HDMI_4_3_50   => return "0010";
         when C_VIDEO_HDMI_5_4_50   => return "0011";
         when C_VIDEO_HDMI_640_60   => return "0100";
         when C_VIDEO_HDMI_720_5994 => return "0101";
         when C_VIDEO_SVGA_800_60   => return "0110";
      end case;
   end function video_mode_to_slv;

   pure function slv_to_video_mode(video_mode_slv : std_logic_vector) return video_mode_type is
   begin
      case video_mode_slv is
         when "0000" => return C_VIDEO_HDMI_16_9_50;
         when "0001" => return C_VIDEO_HDMI_16_9_60;
         when "0010" => return C_VIDEO_HDMI_4_3_50;
         when "0011" => return C_VIDEO_HDMI_5_4_50;
         when "0100" => return C_VIDEO_HDMI_640_60;
         when "0101" => return C_VIDEO_HDMI_720_5994;
         when "0110" => return C_VIDEO_SVGA_800_60;
         when others => return C_VIDEO_HDMI_16_9_50;
      end case;
   end function slv_to_video_mode;

end package body video_modes_pkg;
