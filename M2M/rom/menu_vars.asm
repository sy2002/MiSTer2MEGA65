; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Variables for Options Menu (menu.asm): Need to be located in RAM
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; screen coordinates
OPTM_X          .BLOCK 1
OPTM_Y          .BLOCK 1
OPTM_DX         .BLOCK 1
OPTM_DY         .BLOCK 1

; currently selected menu item (real-time)
OPTM_CUR_SEL    .BLOCK 1

; pointer to initialization record (see menu.asm for more details)
OPTM_DATA       .BLOCK 1

; single-select vs multi-select item flag
OPTM_SSMS       .BLOCK 1
