Two types of ROMs:
==================

1) ROMs that are automatically loaded on startup
(i.e. directly after a hard reset)

2) ROMs that are loaded on demand using the Help/Options menu

re 1)

Autoload-ROMs can be mandatory or optional. Example: GameBoy:
If the original GameBoy ROM is not found on the SD card, then a built-in
OpenSource version is being used. It makes sense to notify the user in the
start-up splash screen so that he knows what happened. Of course configurable
using (new) settings in config.vhd

Actually there are three types of ROMs: Type 3 are the ROMs that are not
loaded dynamically at all but that are part of the synthesized bitstream.
But Type 3 is note relevant for these thoughts about how the M2M
firmware implements loading.

How to implement:
=================

Framework level:
---------------

### globals.vhd


* Add a section similar to the virtual drives section.
* There we have the amount of ROMs as a constant.
* And an array of records or something like that that contains the type of ROM
  (see above) and the device ID for each ROM. For Type 1 also the filename.
* The device IDs are used by the user of the framework in mega65.vhd to
  actually wire the QNICE signals to the ROMs and are also used by the
  firmware to fill the ROMs.

### m2m.vhd

* Enhance the sysinfo device (similar to vdrives) so that the firmware is able
  to find out: How many ROMs do we have? And what are the types of these ROMs
  (as the firmware needs to treat them differently) and what are the
  device IDs so that the firmware can actually fill them.

### config.vhd

* config.vhd is for "Type 2" ROMs: Those that are loaded by the user
* Same logic as for drives and help menu items: The first occurance of a
  ROM in the menu is "ROM 0 (of Type 2)", the second one
  is "ROM 1 (of Type 2)", etc. I am distinguishing between "ROM 0 of Type 1"
  and "ROM 0 of Type 2" because the various types need to be treated by the
  firmware rather differently.
* New OPTM_G constant that does set the highest bit (for single-select item,
  similar to drive mounting) and additionaly one more bit for the actual
  ROM topic: I suggest:
  constant OPTM_G_ROM : integer := 16#C000#
* New selector for the firmware to extract ROM menu items (and to count
  which one is 0, 1, 2, 3, ...):
  constant SEL_OPTM_ROM : integer := x"0320"

### Firmware

* sysdef.asm: New access constants for sysinfo device and config.vhd selector
* Startup/reset behavior: Needs to support multiple ROM options
* Options menu callback enhancement in options.asm
* Loader code and handler code in a new asm file that runs in the context of
  shell.asm, I propose "roms.asm"
* Callback function for skipping ROM file headers and for activating various
  core settings depending on flags in the ROM (example: GameBoy)
* Device mounting might need to be refactored: move it out from 
  HANDLE_MOUNTING (shell.asm, this function is all about mounting VIRTUAL
  DRIVES) to a generic function, so that whomever tries to access the SD
  card for the first time is actually mounting it.
* Make sure that you set the right context CTX_LOAD_ROM in SF_CONTEXT before
  calling SELECT_FILE.
* We might also consider factor-out the code that loads the disk image into
  a buffer because this code can be used 1-to-1 also for loading a rom
  image into a rom.
* Code consistency (spaces, comments, max width of a line, etc)_
  https://github.com/sy2002/QNICE-FPGA/blob/develop/doc/best-practices.md#columns-and-spacing
  https://github.com/sy2002/QNICE-FPGA/blob/dev-V1.61/test_programs/template.asm
* Robustness: Everything can fail. Catch all error situations and use specific
  error messages or at least the "point to error mechanism" via
  ERR_FATAL_INST* so that we can find strange behaviors after the firmware is
  in the hands of users.

User level:
-----------

### Type 1

* The user defines the constants/records in globals.vhd (see above) and
  there he also defines the device ID of them ROM(s).
* After that, the user instantiates a dualport_2clk_ram in mega65.vhd's
  section called "Dual Clocks"
* There, he wires one of the inputs to the qnice_clk_i, setting
  the generic FALLING_A or FALLING_B to "true"
* Wire qnice_dev_addr_i and qnice_dev_data_i to the RAM/ROM.
* IMPORTANT: Never directly wire qnice_dev_ce_i, qnice_dev_we_i or
  qnice_dev_data_o to the RAM/ROM. Instead, create signals in mega65.vhd
  and then go to the process core_specific_devices and set them all to a
  default value outside of the "case" structure to make sure we always have
  defaults that are zero.
* Add a new "when" statement to the case and use the device ID to select:
  when C_DEV_MY_ROMS_DEVICE_ID =>
    qnice_my_chip_enable    <= qnice_dev_ce_i;
    qnice_my_write_enable   <= qnice_dev_we_i;
    qnice_dev_data_o        <= qnice_my_data_out;

### Type 2

* The user adds "+OPTM_G_ROM" to a menu item in config.vhd
* After that, he makes sure that globals.vhd has the right record structure
  (see above).
* And then, everything as described above in "Type 1" from the second
  bullet point on

