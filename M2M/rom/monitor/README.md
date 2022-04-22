QNICE monitor changes necessary to run MiSTer2MEGA
--------------------------------------------------

MiSTer2MEGA (M2M) needs QNICE V1.61 or newer. Currently, this is not yet an
official QNICE release, so for being on the safe side, here is the exact
QNICE commit that M2M needs for operating properly:

de7898d1491ce81795971e92c3b0f7edd1f6d2c4

Additionally to that, M2M needs modified version of three QNICE Monitor files
that need to be located in this folder, i.e. in `M2M/rom/monitor`:

* `qmon_m2m.asm`: modified version of `qmon.asm`
* `qmon_vars.asm`: modified version of `variables.asm`
* `io_library_m2m.asm`: modified version of `io_library.asm`

In general, this is not a (Q)NICE way of doing things. We should not need to
modify QNICE Monitor files to make QNICE usable for M2M but find smarter ways
in a future official V1.61 or V1.7 release of QNICE to make QNICE more
"embeddable".

Description of the changes:

### qmon_m2m.asm

#### INIT_FIRMWARE

Jumps to `INIT_FIRMWARE` on cold start instead of jumping to `QMON$COLDSTART`.

This is necessary so that the M2M firmware starts instead of the QNICE
Monitor.

#### Soft Start

* New label `QMON$SOFTSTART`: Called by the modified io_library_m2m.asm on
  CTRL+E and instead of resetting the status register (including the register
  bank counter) and the stack, the QMON$SOFTSTART uses variables in
  `qmon_vars.asm` to restore these values

* To use the soft start, one can enter the monitor via `QMON$SOFTMON`.
  This is for example done by the Shell when entering the debug mode.

Background information:

CTRL+E is used right now to exit any input situation of the Monitor, for
example when you try to enter a value and have a typo, you would typically
press CTRL+E. Also when using "Memory/Load" by pressing `M` and then `L` you
are exiting the data transfer loop by CTRL+E. 

The challenge with the standard behavior of CTRL+E is, that it leads to a
so called "Warm Start" that resets the stack pointer and the register bank
pointer so that the debug mode of the Shell would not be able to allow the
user to return to where he left of.

Therefore the solution we chose is to introduce a "Soft Start" that is in
contrast to the warm start restoring the old values of the stack pointer and
register bank pointer by using initialization values that have been stored
earlier: Either during a "Cold Start" a "Warm Start" or during the call to
the label QMON$SOFTMON.

### qmon_vars.asm

* Removed hardcoded `.ORG 0xFEEB`. Instead the address of the Monitor
  variables is defined in `m2m-rom.asm`

* Introduced two new variables (`_QMON$SP` and `_QMON$SR`) that are used by
  the above-mentioned "Soft Start" logic

### io_library_m2m.asm

Jumps to QMON$SOFTSTART on CTRL+E instead of QMON$COLDSTART. This is used to
implement the above-mentioned "Soft Start" logic.

