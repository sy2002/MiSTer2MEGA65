How to update NAME-OF-YOUR-PROJECT
==================================

The following changes have been made to MiSTer, MiSTer2MEGA65 and QNICE.
As soon as you update one of these modules, make sure you are applying the
changes described here.

This document is just an example document of a vanilla MiSTer2MEGA65 copy.
Make sure you edit it properly so that it fits your project.

Also make sure that you write this a bit like a "how-to" document.

MiSTer core THE-CORE-YOU-ARE PORTING
------------------------------------

Here is an example of how typical changes, that you would document here,
are looking like. Don't forget to remove this filler-text

### Replaced MiSTer specific RAMs

Replace all "dpram" with "dualport_2clk_ram". When updating to a new MiSTer
core version, this replacement can be done via search/replace because both
RAMs are pin compatible. Replace all `dpram` occurrences in the following
files in the folder `rtl` with `dualport_2clk_ram`:

* `gb.v`
* `sprites.v`

MiSTer2MEGA65
-------------

No changes

QNICE
-----

This is just another example to show you how `exceptions.md` is meant to work.
Change everything to the actual reality of your project.

### Duplicated `qmon.asm` and modified it

Currently, QNICE's project structure is not allowing an easy change of where
the machine should jump to on power-on. This is why `qmon.asm` has been
duplicated and modified:

Modified `reset!` so that it jumps to the label `INIT_FIRMWARE` instead
of `QMON$COLDSTART`.
