----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Constants that differentiate the MEGA65 R2 and R3 models
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package m65_const is

-- Maximum size of cartridge ROM and RAM
-- as long as we are not yet leveraging HyperRAM, these two parameters
-- are the main distinction between the MEGA65 R2 and R3, as R3 has a much larger FPGA
constant CART_ROM_MAX_R2   : integer :=  256 * 1024;
constant CART_RAM_MAX_R2   : integer :=   32 * 1024;
constant CART_ROM_MAX_R3   : integer := 1024 * 1024;
constant CART_RAM_MAX_R3   : integer :=  128 * 1024;

-- modes according to https://gbdev.io/pandocs/#_0148-rom-size and https://gbdev.io/pandocs/#_0149-ram-size
constant SYS_ROM_MAX_R2    : integer := 3; -- 256 kB
constant SYS_RAM_MAX_R2    : integer := 3; -- 32 kB 
constant SYS_ROM_MAX_R3    : integer := 5; -- 1 MB
constant SYS_RAM_MAX_R3    : integer := 5; -- 128 kB (5 = 64 kB, 4 = 128 kB: since we use "<" in the ROM to check, 5 includes 128 kB)

end m65_const;

package body m65_const is
end m65_const;
