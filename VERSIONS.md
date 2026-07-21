Version 2.1.0 - MONTH DAY, YEAR
===============================

Improvements
------------

* Added the generic `make_release.py` packager and a stock-demo
  `CORE/release.toml`. Core identity, file naming, `.cor` metadata, Shell config
  naming, and release-document policies are declarative; genuinely
  core-specific checks or artifacts can use optional `CORE/release_hooks.py`
  callbacks without forking the shared release engine.

* Heavily improved documentation: Wiki and "The Ultimate Porting Guide"

* Support for AI coding assistants: Added AGENTS.md and CLAUDE.md

* Added an optional, core-configurable sync-pulse reshaper for analog VGA
  Standard mode. Core porters configure it in `CORE/vhdl/globals.vhd`; the
  stock profile is an exact wire-through, preserving existing analog behavior.
  Common VESA DMT pulse presets are provided and converted to each core's
  video-clock frequency at elaboration time.

* Added optional, core-configurable HDMI output fitting. A core can select
  independent physical aspect-ratio presets for its uncropped and cropped
  views. The framework accounts for HDMI modes with non-square encoded pixels
  and calculates all target rectangles at elaboration time. The stock legacy
  profile exactly preserves the previous HDMI image placement. Four optional
  rational size fractions can now be selected at runtime for the cropped view;
  the selector is ignored for the uncropped view and all four fractions default
  to full size for backward-compatible behavior. With that stock profile, the
  selector CDC and mux are omitted at elaboration.

Bug fixes
---------

* Restored the HyperRAM controller placement pblock on R3, R4, R5 and R6.
  Keeping the receive FIFO close to the fixed HyperRAM I/O bank ensures that
  the IDDR-to-FIFO paths reliably meet their deliberate 2 ns maximum delay.

Version 2.0.1 - February 22, 2025
=================================

Bug fixes
---------

* Fixed the "jail bar" aka "bar code" HDMI issue that is technically a
  HyperRAM issue. All cores based on V2.0.0 were affected; mostly on R6
  devices but there is at least one known R3 occurance.

  If you want to learn more about the phenomenon and the fix, then look at
  this issue for the R6: https://github.com/MJoergen/C64MEGA65/issues/145
  And at this for the R3: https://github.com/MJoergen/C64MEGA65/issues/166

* R6 only: Joysticks in port #2 did not work. Due to a bug in the R5/R6
  boards, the cartridge port needs to be enabled for joystick port 2 to work.
  Special thanks to rjaremczak for this fix.

* R3 only: Corrected constraint for p1hi_io[0] (cartridge port)


Version 2.0.0 - June 28, 2024
=============================

Improvements
------------

* Added support for multiple MEGA65 models including the 2024 batches aka R6;
  currently we support R3/R3A, R4, R5, R6

* Added support for additional bi-directional Expansion Port signals

* Increased robustness of HyperRAM

* Support for the MEGA65's I2C architecture

* Support for the MEGA65's real-time-clock

* Two more 60Hz screen resolutions: 4:3 480p and 4:3 800x600 and one 59.94Hz
  screen resolution: 3:2 480p. Implemented by a more elegant aka dynamic video
  clock reprogramming.

* Better HDMI compatibilty due to switching to the Tyto2 framework and due
  to fixing an audio bug

* More robust reset handling: Cores start in reset state and the firmware
  is un-resetting the core when time is ripe

* The power led indicates a long reset by switching to blue

* Run/Stop now has a global "go back" semantic: It either closes an open
  window (including help screens or file selectors) or it goes back one menu
  level when the user is in a sub-menu.

Bug fixes
---------

* The "Audio improvements" feature only worked with analog audio (3.5mm jack)
  but not with digital audio via HDMI

* Fixed a crash in the file browser

* Fixed missing ".." in folders created with certain macOS versions

* Fixed Run/Stop propagation bug when closing the OSM

* MEGA65's internal floppy drive kepts spinning when a floppy was inserted.

Version 1.0.0 - June 21, 2023
=============================

Commodore 64 for MEGA65 version 5 is based on this version 1.0.0 of the
MiSTer2MEGA65 framework.

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
