; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Directory Browser: Test program and development testbed
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

#include "../../QNICE/dist_kit/sysdef.asm"
#include "../../QNICE/dist_kit/monitor.def"

                .ORG    0x8000

                MOVE    M2M$CSR, R0             ; init CSR as the following..
                MOVE    0, @R0                  ; ..routines expect that

                RSUB    SCR$INIT, 1
                RSUB    SCR$OSM_M_ON, 1
                RSUB    SCR$CLR, 1               

;                MOVE    TITLE_STR, R8
;                RSUB    SCR$PRINTSTR, 1

                ; show welcome screen: draw frame and print text
                MOVE    SCR$OSM_M_X, R8
                MOVE    @R8, R8
                MOVE    SCR$OSM_M_Y, R9
                MOVE    @R9, R9
                MOVE    SCR$OSM_M_DX, R10
                MOVE    @R10, R10
                MOVE    SCR$OSM_M_DY, R11
                MOVE    @R11, R11
                RSUB    SCR$PRINTFRAME, 1
                MOVE    M2M$RAMROM_DEV, R0      ; Device = config data
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; Selector = Welcome screen
                MOVE    M2M$CFG_WELCOME, @R0
                MOVE    TITLE_STR, R8           ; R8 = welcome screen string
                RSUB    SCR$PRINTSTR, 1

                SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Strings
; ----------------------------------------------------------------------------

TITLE_STR       .ASCII_P "MiSTer2MEGA65 keyboard development testbed "
                .ASCII_W "done by sy2002 in July 2021\n\n"

; ----------------------------------------------------------------------------
; Framework and Variables 
; ----------------------------------------------------------------------------

#include "keyboard.asm"
#include "screen.asm"
#include "sysdef.asm"
#include "tools.asm"

#include "keyboard_vars.asm"
#include "screen_vars.asm"
