; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Variables for Options Menu (menu.asm): Need to be located in RAM
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in February 2021 and licensed under GPL v3
; ****************************************************************************

; screen coordinates
OPTM_X          .BLOCK 1
OPTM_Y          .BLOCK 1
OPTM_DX         .BLOCK 1
OPTM_DY         .BLOCK 1

; pointer to initialization record (see menu.asm for more details)
OPTM_DATA       .BLOCK 1
