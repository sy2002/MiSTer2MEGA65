Use these example file headers for your MiSTer2MEGA65 project.

It is important to credit the great MiSTer development team, since after all
what you are doing here is "just" a port of their outstanding work. This is why
we propose to use the following headers in all of your files to make sure that
this becomes very clear.

### VHDL

#### Template

```
----------------------------------------------------------------------------------
-- NAME-OF-YOUR-PROJECT for MEGA65 (NAME-OF-THE-GITHUB-REPO)
--
-- Name of this module one-line description what this module does
--
-- You can just delete these additional lines. They are used in cases, where you
-- need additional room to comment things that are specific to this module.
-- 
-- This machine is based on EXACT GITHUB REPO NAME OF THE MiSTer REPO
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by YOUR-NAME in YEAR and licensed under GPL v3
----------------------------------------------------------------------------------
```

#### Example (own file)

Here is an example of how the header can be used in a real project in a file that
you have been created by yourself.

```
----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- MEGA65 keyboard controller
--
-- Can be directly connected to the MiSTer Game Boy's core because it stores
-- the key presses in a matrix just like documented here:
-- https://gbdev.io/pandocs/#ff00-p1-joyp-joypad-r-w
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------
```
### Verilog

#### Example (modifying a MiSTer file)

When you modify a MiSTer file, make sure that you leave the original MiSTer header
intact and just add your own header. Don't forget to document all these changes
in `doc/dev/exceptions.md`. Real-world example:

```
// Game Boy Color for MEGA65 (gbc4mega65)
//
// This machine is based on Gameboy_MiSTer
// MEGA65 port done by sy2002 in 2021 and licensed under GPL v3

// Updating notes:
// This is the main file for the actual machine. It is nearly 1-to-1 identical
// with the original MiSTer source. When updating to a newer version, here are
// the changes that need to be applied:
//
// Replace all "dpram" with "dualport_2clk_ram". Basically this can be
// done via search/replace because both RAMs are pin compatible.

//
// gb.v
//
// Gameboy for the MIST board https://github.com/mist-devel
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//
```
