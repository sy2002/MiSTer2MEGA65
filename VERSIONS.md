Version 0.9.1 - January 28, 2023
================================

Works with more HDMI monitors, frame grabbers, HDMI switches, etc.

MiSTer2MEGA65 was not compliant to section 4.2.7 of the HDMI specification
version 1.4b: It did not assert the +5V power signal. Now it does assert the
+5 power signal via the FPGA pin `ct_hpd`.

Version 0.9.0 - January 9, 2023
===============================

After being in development since April 5, 2021 while being in a constant
"alpha state" with continuous changes and refactorings, Version 0.9.0 is the
**first stable version of the MiSTer2MEGA65 (M2M) framework**.

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
