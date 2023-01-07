MiSTer2MEGA65
=============

MiSTer2MEGA65 is a framework to simplify porting MiSTer cores to the MEGA65.

![Title Image](doc/wiki/assets/MiSTer2MEGA65-Title.png)

Learn more by
[watching this YouTube video](https://youtu.be/9Ib7z64z9N4)
and get started by reading the
[MiSTer2MEGA65 Wiki](https://github.com/sy2002/MiSTer2MEGA65/wiki).

TL;DR
-----

1. Scroll up and press the "Use this template" button to start a new
   MiSTer2MEGA65 project. Then fork the MiSTer core you want to port
   and make it a Git submodule of your newly created project.

2. Wrap the MiSTer core inside `CORE/vhdl/main.vhd` while
   adjusting the clocks in `CORE/vhdl/clk.vhd`. Provide RAMs, ROMs and other
   devices in `CORE/vhdl/mega65.vhd` and wire everything correctly.

3. Configure your core's behavior, including how the start screen looks like,
   what ROMs should be loaded (and where to), the abilities of the
   <kbd>Help</kbd> menu and more in `CORE/vhdl/config.vhd` and in
   `CORE/vhdl/globals.vhd`.

**DONE** your core is ported to MEGA65! :-)

*Obviously, this is a shameless exaggeration of how easy it is to work with
MiSTer2MEGA65, but you get the gist of it.*

Getting started, detailed documentation and support
---------------------------------------------------

* Please visit our official
  [MiSTer2MEGA65 Wiki](https://github.com/sy2002/MiSTer2MEGA65/wiki). It
  contains everything you ever wanted to know about M2M, including a
  "Getting Started" tutorial and a step-by-step guide to port a MiSTer core.
  You might whant to start your journey
  [here](https://github.com/sy2002/MiSTer2MEGA65/wiki/1.-What-is-MiSTer2MEGA65)
  and then follow the reading track that is pointed out in the
  respective chapters.

* Post a question in our
  [Discussion Forum](https://github.com/sy2002/MiSTer2MEGA65/discussions).

Status of the framework
-----------------------

**The MiSTer2MEGA (M2M) framework is stable and ready for being used.**
The first production quality core that is based on M2M is the
[Commodore 64 for MEGA65](https://github.com/MJoergen/C64MEGA65/tree/M2M-V0.9).
Additionally there is a work-in-progress
[Apple II core](https://github.com/lydon42/Apple-II_MEGA65/tree/progress)
based on M2M. The main reason why we are currently using "Version 0.9"
(0.9.x) for the M2M framework instead of "Version 1.0" is that there is not
enough documentation available, yet. If you have a look at the
[MiSTer2MEGA65 Wiki](https://github.com/sy2002/MiSTer2MEGA65/wiki)
then you will notice, that there are many gaps in the documentation.

This should not discourage you from using the MiSTer2MEGA65 framework right
now to port MiSTer cores and other cores to the MEGA65. You can use the
source code of the
[Commodore 64 for MEGA65](https://github.com/MJoergen/C64MEGA65/tree/M2M-V0.9)
as your "user's manual" and "reference handbook" for the M2M framework;
additionally to the existing
[Wiki pages](https://github.com/sy2002/MiSTer2MEGA65/wiki).
For being able to actually use the C64 core's source code as your
documentation of how to use the M2M framework, we added a tag called
`M2M-V0.9` to the GitHub repository of the
[Commodore 64 for MEGA65](https://github.com/MJoergen/C64MEGA65/tree/M2M-V0.9).
The tag is necessary, because Version 4 of the C64 core was based on an
earlier version of the M2M framwork and only from the tag `M2M-V0.9` on the
C64 core is aligned with Version 0.9 of M2M.

Additionally to helping yourself with the Wiki (and the turorials there) and
the C64 source code as your "user's manual" and "reference handbook": Post
your question in the
[Discussion Forum](https://github.com/sy2002/MiSTer2MEGA65/discussions)
and join the
[friendly MEGA65 community on Discord](https://discord.gg/PMBxcDvbX8).
