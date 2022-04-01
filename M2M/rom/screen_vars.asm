; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Variables for screen.asm
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; cursor screen coordinates in chars: next character will be printed here
SCR$CUR_X       .BLOCK 1                        ; OSD cursor x coordinate
SCR$CUR_Y       .BLOCK 1                        ; ditto y

; shortcut-variables (read-only): hardware screen size in chars:
; used to calculate VRAM positions of characters, clear screen amount, etc. 
SCR$SYS_DX      .BLOCK 1
SCR$SYS_DY      .BLOCK 1

; shortcut-variables (read-only): attributes of the main OSM and Help OSM:
; used to display the main OSM and the Help-Key ingame OSM (aka Options Menu)
SCR$OSM_M_X     .BLOCK 1
SCR$OSM_M_Y     .BLOCK 1
SCR$OSM_M_DX    .BLOCK 1
SCR$OSM_M_DY    .BLOCK 1
SCR$OSM_O_X     .BLOCK 1
SCR$OSM_O_Y     .BLOCK 1
SCR$OSM_O_DX    .BLOCK 1
SCR$OSM_O_DY    .BLOCK 1

; inner left start coordinate for SCR$PRINTSTR: It depends on the
; x-coordinate of the frame
SCR$ILX         .BLOCK 1

; Scratch variables
TEMP_2W         .BLOCK 2
