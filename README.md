MiSTer2MEGA65 (HEAVILY WORK-IN-PROGRESS)
========================================

![Title Image](doc/wiki/assets/MiSTer2MEGA65-Title.png)

MiSTer2MEGA65 is a framework to simplify porting MiSTer cores to the MEGA65.

TL;DR
-----

1. Copy your your "raw" MiSTer core from MiSTer's RTL folder
   into `/rtl` and wire it inside `MEGA65/vhdl/main.vhd` while
   adjusting the clocks in `MEGA65/vhdk/clk.vhd`.

2. Provide RAMs, ROMs and other devices in `MEGA65/vhdl/mega65.vhd`
   and wire everything correctly.

3. Configure your core's behavior, including how the start screen looks like,
   what ROMs should be loaded (and where to), the abilities of the
   <kbd>Help</kbd> menu and more in `MEGA65/vhdl/config.vhd`.

**DONE** your core is ported to MEGA65! :-)

*Obviously, this is a shameless exaggeration of how easy it is to work with
MiSTer2MEGA65, but you get the gist of it.*

Progress
--------

CAUTION: RIGHT NOW THIS IS A HEAVILY WORK-IN-PROGRESS PRE-ALPHA VERSION.
WE WILL RELEASE THIS AS A V1.0 AS SOON AS THE FOLLOWING FIRST MILESTONE HAS
BEEN REACHED: MJoergen and sy2002 PORTED THE C64 CORE.

Progress of the Commodore 64 Core (which uses this framework):

Have a look at [this YouTube Video](https://youtu.be/wsS1iiozeXA) to learn
about the progress as of end of February 2022. Here is the GitHub repo
of the Commodore 64 Core: https://github.com/MJoergen/C64MEGA65

The [Game Boy for MEGA65 repository](https://github.com/sy2002/gbc4mega65/)
shows you what we are planning to do here.

Details
-------

The MEGA65 does have some significant ROM/RAM constraints compared to the
MiSTer: There is the RAM that is contained in the FPGA and there are 8 MB up
to 16 MB of relatively slow HyperRAM. This is why MiSTer2MEGA65 strives to
be a total bean counter when it comes to saving/preserving ROM/RAM space.
The goal is to leave as much of this precious resources to the actual
MiSTer core that we are porting so that it can utilize as much of it
as possible. Moreover, MEGA65 does not have an ARM core and a fully
fledged Linux operating system. Both is used heavily by the MiSTer
infrstructure and this is why MiSTer2MEGA needs to provide some of these
pleasantries.

Use cases and features of the framework:

* Vivado template project that enables you to synthesize for the MEGA65
  including the necessary port mappings and constraints
* Support for MEGA65 Release 2 and Release 3 machines (aka R2 and R3)
* Drivers for the MEGA65 hardware
* Drop-in replacements for various RAM types that MiSTer uses
* VGA timing generator
* 3.5mm audio jack support (encode LPCM to PDM)
* HDMI video (720p @ 60 Hz) and audio support
  (sample LPCM with 48 kHz and transmit it via HDMI)
* SD card and FAT32 support
* Load BIOS ROMs and cartridge ROMs and the likes before starting
  the MiSTer core
* Easy to use infrastructure to map the disk-drives, HDs, etc. of
  the MiSTer core to MEGA65's SD card and/or to its floppy disk drive
* Control the MiSTer core (start, stop, reset, pause, ...)
* On-Screen-Menu (overlay) that offers configuration options and
  file system functionality for the MiSTer core while it is running
* Support for various screen resolutions

The design goals of MiSTer2MEGA65 are:

1. Simplify and speed-up the porting of MiSTer cores to the MEGA65
   as much as possible

2. Do not force anybody to program QNICE directly but provide an abstraction
   layer via a QNICE ROM that can be configured directly from the VHDL or
   Verilog layer. (But do allow direct QNICE programming for those who
   want maximum control over the user interface experience.)

3. Small QNICE ROM/RAM footprint over programmer's convenience and
   execution speed (the on-screen-menu including the end user experience
   should be snappy though)
   
4. Modular architecture: You only pay for what you use.

5. Flexible architecture: We will start small and grow over time. But that
   means we need to go the last mile when it comes to avoiding architectural
   dead ends.
   
How to use MiSTer2MEGA65 and its basic philosophy
-------------------------------------------------

At the core of the MiSTer2MEGA65 philosophy is this simple but sometimes not
so simple to implement idea:

> Avoid touching the original!

That means: Avoid touching the MiSTer core you are porting and avoid touching
as well the MiSTer2MEGA65 framework and QNICE.

The reason for that is simple: You want to easily be able to update to newer
versions of the MiSTEr core, the MiSTer2MEGA65 framework and QNICE.
Always document each and everything (even the smallest changes) that you
are applying in one of these three modules in `doc/m2m/exceptions.md`.

From this basic philosophy, the following "how-to-use" rules are derived when
it comes to setting-up a new MiSTer2MEGA65 porting project.

### Step #1: Clone MiSTer2MEGA65 and initialize it

#### Unfinished first thoughts

MiSTer2MEGA65 contains sub-modules, so make sure that you do not "just" clone
but also initialize the submodules afterwards:

```
git clone https://github.com/sy2002/MiSTer2MEGA65.git
cd MiSTer2MEGA65
git submodule update --init --recursive
```

After that, make sure that the QNICE development framework and the QNICE's
"operating system" called "Monitor" is available to MiSTer2MEGA65. You can
build it using the following commands:

```
cd QNICE/tools/
./make-toolchain.sh 
```

Answer all questions that you are being asked while the QNICE toolchain
is being build by pressing <kbd>Enter</kbd>. You can check the success of
the process by checking, if the Monitor is available as  `.rom` file:

```
ls -l ../monitor/monitor.rom
```

Rename the root folder name `MiSTer2MEGA65` to match the actual name
of your project.

#### FORK vs. CLONE ?

It might make a lot of sense, if your Core porting project has an
"upstream connection" to the MiSTer2MEGA65 framework, because then it is much
easier for you to to update to new MiSTer2MEGA65 versions; particularly given
that right now everything is still work in process.

In this context, it is currently an open question, if we should CLONE
MiSTer2MEGA65 for a new porting project or if we should FORK.

In the [Commodore 64 porting project](https://github.com/MJoergen/C64MEGA65)
we are currently going down the FORK route using the following commands right
after the fork and after having initialized the submodules (see above):


```
git remote add upstream https://github.com/sy2002/MiSTer2MEGA65.git
git remote -v
```

More documentation on this topic, [click here](https://docs.github.com/en/github/collaborating-with-pull-requests/working-with-forks/configuring-a-remote-for-a-fork).

### Step #2: Copy/paste the MiSTer core

The MiSTer core's directory structure shall sit on the top level of your
MiSTer2MEGA65 directory tree. The most important MiSTer folder is `rtl`. At
a later stage of your porting progress, you might want to remove some of
MiSTer's folders such as `sim`, `sys` and others. But when you are getting
started, just copy everything into your own project folder.

### Step #3: Start porting while using the right directories

TODO TODO TODO TODO TODO
TODO TODO TODO TODO TODO

#### Root level

| Directory     | Explanation                                                                                                                               |
|---------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| M2M           | MiSTer2MEGA65 framework                                                                                                                   |
| MEGA65        | This is "your" directory. The place where your port is located. Learn more about the sub-structure below.                                 |
| QNICE         | QNICE root folder including the QNICE system-on-a-chip, development tools and documentation                                               |
| bin           | Deliver MEGA65 `.cor` and `.bit` files here. Put them into subfolders that are named according to the MEGA65 release, e.g. `R2` and `R3` .|
| doc           | Documentation of your port as well as recommended MiSTer2MEGA65 standard documentation plus all assets for GitHub (e.g. images)           |
| rtl           | MiSTer core main folder: After you copy/pasted the MiSTer core in step #2, this folder will be there.                  

#### Personalize the following files

Personalize all these files by entering your project's name, your name, etc.
into the file headers and by removing template content:

* `AUTHORS`

* `doc/m2m/exceptions.md`

* In folder `MEGA65`: `MEGA65-R2.xdc` and `MEGA65-R3.xdc`

* `MEGA65/m2m-rom/m2m-rom.asm`

* `MEGA65/VHDL` TODO add the names of the two top files for R2 and R3 here

The Shell
---------

"Shell" is the name of the standard user interface and core control automation
that comes with M2M.

You can use the Shell to focus on your Verilog/VHDL code and avoid any QNICE
programming. Alternatively, you can do it the other way round and avoid the
Shell and create your own user interface and core control automation instead.

The Shell executes the following startup sequence for every core while the
invidivual steps of the sequence can be configured and sometimes made optional
using TODO VHDL CONFIG STRING:

1. Show a welcome message
2. Load one or more mandatory or optional BIOS / ROMs. "Mandatory" means:
   If the file is not there, the core stops. "Optional" means: You are able to
   provide an Open Source version of the BIOS / ROM and synthesize it into the
   core. "Mandatory" means: The core stops, if the file is not there. In both
   cases, the Shell informs the user on the screen and outputs additional debug
   info on the UART.
3. It is configurable if you want that the output of (2) is on the same screen
   as (4), or if there should be (without keypress) a clearscreen after
   everything has been successfully loaded or if you want a keypress after
   successfully loading.
4. Show one or more help screens / explanation screens, allow "browsing them"
   in case there is more than one using the cursor keys. <kbd>Space</kbd>
   to start the core.
6. Show a file browser: The user can load a ROM (e.g. cartridge ROM)
   or mount a device (e.g. disk image). (TODO: Do we need to allow 0 .. n
   here or is 0 .. 1 sufficient?)

TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO 

TODO: "Load a ROM" means that you can define Dual Clock Dual Port RAMs in
VHDL, assign a "device number" to them and then the Shell is smart enough
to fill this RAM (that can act as a RAM or ROM to the core).

TODO: "Mount a device" will be a mechanism that pipes data through the
QNICE FAT32 implementation using an interrupt driven approach that will
"look and feel" like a flat data stream to the core.

TODO: Define what happens, when the user presses <kbd>Run/Stop</kbd>
while the core runs. Default behaviour: Pause the core, show the file
broswer (5) and act like during the startup sequene

TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO 

When the user presses <kbd>Help</kbd> while the core is running, the Shell
will show the Options menu. The options menu is configurable to work with
menu groups. TODO: describe; see gbc4mega65

It will return the selection as bit patterns inside control_m_o. So for
example menu group 0 might consist of a 1-bit selection, so this might
be mapped to control_m_o(0), while menu group 1 might consist of a 3-bit
selection, so this might be mapped to control_m_o(3 downto 1). It is
recommended for readability to define signals that are mapped to these very
subsets of control_m_o and then use these signals to configure your core.

TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO

Reminder / design principle: The Shell, what it does, what it automates, how
it controls everything: Heavily inspired by
[gbc4mega65](https://github.com/sy2002/gbc4mega65/).
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
