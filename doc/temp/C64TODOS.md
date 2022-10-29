Migrating the C64 core to the new version/architecture of M2M will be challenging

Here is a probably incomplete list of things/features that we need to migrate to M2M from the C64MEGA65 codebase first
before we can even attempt to bring the C64 to the new M2M version:

* New ROM from C64
* Floppy led color control: m2m_keyb.vhd, mega65kbd_to_matrix.vhdl
* Write support for virtual drives: vdrives.vhd, new ROM version, to-be-decided: the led logic (green: core's operation, yellow: Shell is currently saving to the SD card): is this something that the framework will do automatically in future, so this is framework logic - or - do we leave a more freedom to the user? Current thought is: should be framework logic
* Reset control: preventing a reset while the write cache is dirty: should this be framework logic - or - do we leave more freedom to the user? Current thought: should be framework logic
* Updated config.vhd to have a clock signal
* Updated config.vhd to support a configuration file
* Config file creation tool in M2M/tools

What we need to improve in M2M before migrating the C64 core:

* Adjust hardcoded keyboard control timings (see also keyboard.md)
* Clean-up video pipeline
* Solve instability issues around the MAX10 (reset issue, ambulance light issues, ...)
