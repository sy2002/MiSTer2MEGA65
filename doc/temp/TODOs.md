## Automate Analog Pipeline

Can we get rid of `video_ce_ovl_i` and `video_retro15kHz_i `? Can we automate
things similar to what the ascaler does? I.e. analyze a frame and then derive
what is needed?

The goal is that we simplify the usage of the framework for the user.

## Prepare for variable core frequencies

We need to get rid of all division operations that involve the core frequency.
As long as we only support cores with fixed frequencies, then the situation
is kind of OK, because Vivado optimizes the calculations and we work with
constants. As soon as the core frequency becomes variable (for example as soon
as the C64 would be switchable between PAL and NTSC), then today's system
does not work any more.

Solution: Use something like `M2M/vhdl/av_pipeline/clk_synthetic_enable.vhd`
or some mechanism like this, so that we can get rid of the division at all.

We need to sift through the whole M2M and core, but what immediately comes
to mind is:

* debounce.vhd
* Keyboard handling: mega65kbd_to_matrix.vhdl, matrix_to_keynum.vhdl

## Lower case signal names for hardware ports

We currently have a mixed bag of ALL CAPS and lower case signal names for
hardware ports. Replace them with lower case for:

* top_mega65-r3.vhd
* m2m.vhd

## Offer configurable key mappings and behaviors

* For example cursor left/right to enter/leave subdirectories and other keys
  then for page up/page down
* For example "Close menu after mounting something"
