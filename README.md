MiSTer2MEGA65 (HEAVILY WORK-IN-PROGRESS)
========================================

MiSTer2MEGA65 is a framework to simplify porting MiSTer cores to the MEGA65.

![Title Image](doc/wiki/assets/MiSTer2MEGA65-Title.png)

Learn more by
[watching this YouTube video](https://youtu.be/9Ib7z64z9N4)
and get started by reading the
[MiSTer2MEGA65 Wiki](https://github.com/sy2002/MiSTer2MEGA65/wiki).

TL;DR
-----

1. Fork MiSTer2MEGA65, rename it to the name of your port, fork the MiSTer
   core you want to port and make it a Git Submodule of your M2M fork.

2. Wrap the MiSTer core inside `MEGA65/vhdl/main.vhd` while
   adjusting the clocks in `MEGA65/vhdl/clk.vhd`. Provide RAMs, ROMs and other
   devices in `MEGA65/vhdl/mega65.vhd` and wire everything correctly.

3. Configure your core's behavior, including how the start screen looks like,
   what ROMs should be loaded (and where to), the abilities of the
   <kbd>Help</kbd> menu and more in `MEGA65/vhdl/config.vhd` and in
   `MEGA65/vhdl/globals.vhd`.

**DONE** your core is ported to MEGA65! :-)

*Obviously, this is a shameless exaggeration of how easy it is to work with
MiSTer2MEGA65, but you get the gist of it.*

Getting started, detailed documentation and support
---------------------------------------------------

* Please visit our official
  [MiSTer2MEGA65 Wiki](https://github.com/sy2002/MiSTer2MEGA65/wiki). It
  contains everything you ever wanted to know about M2M, including a
  "Getting Started" tutorial and a step-by-step guide to port a MiSTer core.

* Post a question in our
  [Discussion Forum](https://github.com/sy2002/MiSTer2MEGA65/discussions)

Progress
--------

CAUTION: RIGHT NOW THIS STILL IS A WORK-IN-PROGRESS VERSION.

Yet, there is already one successful project live and up and
running that is based on this version of the M2M framework:
The [C64 for MEGA65](https://github.com/MJoergen/C64MEGA65).

M2M is not officially released at this moment:

It is somewhere between an Alpha and a Beta version. We try
to keep the M2M architecture as stable as possible from now
on so that you can rely on it and start porting MiSTer cores.
