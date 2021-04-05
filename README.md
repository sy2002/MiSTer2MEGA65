MiSTer2MEGA65 (HEAVILY WORK-IN-PROGRESS)
========================================

MiSTer2MEGA65 is a framework to simplify porting MiSTer cores to the MEGA65.

CAUTION: RIGHT NOW THIS IS A HEAVILY WORK-IN-PROGRESS PRE-ALPHA VERSION.
WE WILL RELEASE THIS AS A V1.0 AS SOON AS THE FOLLOWING FIRST MILESTONE HAS
BEEN REACHED: USING THIS FRAMEWORK, steddyman PORTED A FIRST VERSION OF
MiSTer's TRS-80 CORE AND sy2002 PORTED A FIRST VERSION OF MiSTer's NES CORE.

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
* HDMI support
* SD card and FAT32 support
* Load BIOS ROMs and cartridge ROMs and the likes before starting
  the MiSTer core
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

### Step #1: Clone MiSTer2MEGA65

MiSTer2MEGA65 contains sub-modules, so make sure that you do not "just" clone
but also initialize the submodules afterwards:

```
git clone https://github.com/sy2002/MiSTer2MEGA65.git
git submodule update --init --recursive
```

Rename the folder name `MiSTer2MEGA65` to match the GitHub repository name
of your project.

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

* In folder `MEGA65`: `MEGA65-R2.xpr`, `MEGA65-R2.xdc`,
  `MEGA65-R3.xpr`, `MEGA65-R3.xdc`

* `MEGA65/m2m-rom/m2m-rom.asm`

TODO TODO TODO
--------------

"Shell" is the name of the standard user interface and core control automation
that comes with M2M.

You can use the Shell to focus on your Verilog/VHDL code and avoid any QNICE
programming. You can also avoid the Shell and create your own user interface
and core control automation.

xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
