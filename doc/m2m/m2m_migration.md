# Migrating from M2M V1 to M2M V2

The purpose of the new M2M V2 is to support additional hardware platforms, specifically
the new R4 and R5 boards of the MEGA65.

This document describes the steps necessary when migrating an existing core from M2M V1
to M2M V2

First of all, in order to support multiple platforms, we need to build separate bitstreams
for each board. Therefore, there must be a separate project file for each board variant.

In the CORE/ folder there must now be a separate project file for each board, named
`CORE-R3.xpr`, `CORE-R4.xpr`, and `CORE-R5.xpr`.

Additionally, the project file needs updating due to source files added and deleted:
* Remove `vhdl/top_mega65-r3.vhd`.
* Add one of `../M2M/vhdl/top_mega65-r3.vhd`, `../M2M/vhdl/top_mega65-r4.vhd`, or
  `../M2M/vhdl/top_mega65-r5.vhd`, depending upon which board this project is targetting.
* Remove `../M2M/vhdl/m2m.vhd`.
* Add `../M2M/vhdl/controllers/HDMI/video_out_clock.vhd`.
* Remove constraint file `CORE-R3.xdc`.
* Add constraint file, one of  `../M2M/MEGA65-R3.xdc`.  `../M2M/MEGA65-R4.xdc`, or `../M2M/MEGA65-R5.xdc`,
  depending upon which board this project is targetting.
* Add constraint file `../M2M/common.xdc`.
* Add optional constraint file `CORE.xdc` if needed.

In the CORE/ folder, the core-independent parts of the constraint file (`CORE-R3.xdc`) has
been moved to the M2M/ folder, and should therefore be deleted from the CORE/ folder.

In the CORE/ folder, there should instead be a board-independent (but core-specific) small
constraint file named CORE.xdc. This would e.g. include constraints for any additional
core-specific clocks. This file is optional, depending on the needs of the core.

In the CORE/vhdl/ folder, the top level file (`top_mega65-r3.vhd`) has been moved to the M2M/
folder, and should therefore be deleted from the CORE/vhdl/ folder.

In the CORE/vhdl/ folder the core top level file (`mega65.vhd`) has some changes:
* There must be a generic `G_BOARD` of type string. This will contain either
  `"MEGA65_R3"`, `"MEGA65_R4"`, or `"MEGA65_R5"`.
* The port signal `RESET_M2M_N` has been removed. Use instead one of `main_reset_m2m_i` or
  `main_reset_core_i`.
* The port signal `qnice_video_mode_o` now has `range 0 to 5`.
* New port output signals `main_joy_1_up_n_o`, etc. have been added to support
  bi-directional joystick ports. If not used, tie them to '1'.
* New port signals for the IEC serial port and the C64 expansion port have been added. See
  the democore for which default values to assign to them, if they are not used.

