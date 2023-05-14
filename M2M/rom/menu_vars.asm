; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Variables for Options Menu (menu.asm): Need to be located in RAM
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; screen coordinates
OPTM_X          .BLOCK 1
OPTM_Y          .BLOCK 1
OPTM_DX         .BLOCK 1
OPTM_DY         .BLOCK 1

; currently active (sub)menu level; 0 means main menu
OPTM_MENULEVEL  .BLOCK 1

; selected menu item in main menu before diving into a submenu
OPTM_MAINSEL    .BLOCK 1

; currently selected menu item (real-time)
OPTM_CUR_SEL    .BLOCK 1

; pointer to initialization record (see menu.asm for more details)
OPTM_DATA       .BLOCK 1

; single-select vs multi-select item flag
OPTM_SSMS       .BLOCK 1

; ptr to the _OPTM_STRUCT menu struct. (only valid while OPTM_RUN is running)
OPTM_STRUCT     .BLOCK 1

; temporary variable
OPTM_TEMP       .BLOCK 1
