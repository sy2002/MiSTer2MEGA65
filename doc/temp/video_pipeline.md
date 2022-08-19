## Video Clock / Pixel Clock

### Questions Mirko

The MiSTer framework expects (quoting from their source):

   //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

a) Is it fair to assume, that M2M right now only supports
   the case CLK_VIDEO == CLK_SYS?
   While MiSTer seems to have a bit more of flexibility here?
b) Is the clock that you receive when AND-ing CLK_VIDEO and CE_PIXEL the
   pixel-clock / dot-clock?
c) Are we assuming a hard-coded input resolution and frequency as these
   comments might suggest (please follow link)
https://github.com/sy2002/MiSTer2MEGA65/blob/master/M2M/vhdl/av_pipeline/analog_pipeline.vhd#L138

### Michael's Answer

I think it's helpful to look at the file M2M/vhdl/m2m.vhd. In that file we see
that only a single clock (main_clk) is used to connect the CORE with the
framework. Additionally, there is a signal "main_video_ce" which is the
pixel clock enable.

(a) The answer is, yes, we only support CLK_VIDEO == CLK_SYS. It's not a big
thing to support different clocks, though. It could relatively easily
be added later.

(b) The current implementation uses a SINGLE clock, but with a clock enable.
This is DIFFERENT from using two clocks. The benefit of using a single
clock + a clock enable, is that there is no Clock Domain Crossing issues.
In other words, we are NOT and'ing any clocks or generating any additional
clocks (in the VGA output). There is a separate HDMI clock, but the CORE
should not have to know about that.

(c) The comments are slightly out-dated (and really C64-centric). But the
bigger picture is - what kind of resolution are we expecting / requiring from
the core? The HDMI output should be largely ignorant and just work, thanks to
the ascaler. But the VGA output, particularly the rendering of the OSM, makes
some assumptions. I do think our framework could benefit from a bit of
cleanup. In particular, there are some hard-coded assumptions a few places,
that need not be there. I'm e.g. thinking about the signal video_ce_overlay
in the file analog_pipeline.vhd. 

Some of these hardcoding-issues will be fixed when working on the 
Apple-II core.

Another non-trivial task will be to "merge" together our latest M2M
framework with the latest C64 core. However, that should probably be
postponed until we make a new "big" release of the C64 core.

### Mirko's question

regarding (b): Is it fair to assume that pixelclock = CLK_VIDEO
(which is CLK_SYS) *AND* Clock_Enable?

### Michael

I don't really like / understand the expression "CLK_VIDEO and Clock_Enable".
If it is logical (bitwise) "and", then no. If it is conceptually
(bundling together) then yes.

### Mirko

Consider a Flip/Flop (Register) that is supposed to store something: I
imagined it being driven by CLK_VIDEO as its input clock while CLK_VIDEO is
bitwise ANDed with Clock_Enable, so that the Flip/Flop can only store
something when Clock_Enable = 1 and CLK_VIDEO is (for example) on rising edge
because when Clock_Enable = 0, the input for the Flip/Flop just stays 0
(no rising edge)...
Obviously this assumption is wrong when I read your answer...
So is it more like:

if rising_edge(CLK_VIDEO) then
   if Clock_Enable then
       Do Stuff

? Which means the flip flop has a separate clock enable signal I guess ?

### Michael

Yes, the Flip-Flop has a separate clock enable pin.

### Mirko

But just being curious: Wouldn't my assumption above (if you built this
discretely and electrically) lead to a perfectly working system, too? (I mean
"muting" the clock using AND Clock_Enable?)

### Michael

Yes, but you would have to take care to avoid glitches. E.g. if the Clock
Enable goes from 0 -> 1 just before the Clock goes from 1 -> 0.

It's possible, just more difficult. Hence, by removing ALL logic on the clock
signals, simplifies the Timing Analysis.

### Mirko

OK - got it. Thank you! :-)

## Next steps

If it is not SD Card for now and SD RAM is too early: Why don't we use the
opportunity to clean-up the analog video pipeline in a way, that we can
configure what kind of input we are providing and the framework derives
from there the next steps?

Remove hardcoded assumptions (see discussion above).

globals.vhd: Do we want to use an "official" video mode constant from
video_modes_pkg.vhd instead of specifiying the resoltion et al manually?
