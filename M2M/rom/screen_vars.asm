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

; shortcut-variables (read-only)
SCR$OSD_DX      .BLOCK 1                        ; width of OSD in chars
SCR$OSD_DY      .BLOCK 1                        ; height of OSD in chars