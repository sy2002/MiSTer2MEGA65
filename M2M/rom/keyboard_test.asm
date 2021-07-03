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

                RSUB    SCR$INIT, 1             ; switch on screen and show..
                RSUB    SCR$OSM_M_ON, 1         ; ..title string
                RSUB    SCR$CLR, 1               
                MOVE    TITLE_STR, R8
                RSUB    SCR$PRINTSTR, 1

                AND     0xFFFB, SR              ; clear carry for SHR

                ; R0: x-pos of char; init with width/2
                MOVE    SCR$OSM_M_DX, R0
                MOVE    @R0, R0
                SHR     1, R0

                ; R1: y-pos of char; init with height/2
                MOVE    SCR$OSM_M_DY, R1
                MOVE    @R1, R1
                SHR     1, R1

                ; R2/R3: old x-pos/y-pos of char
                MOVE    R0, R2
                MOVE    R1, R3

                MOVE    SPACE_CHR, R4           ; R4 = active char
                RSUB    DRAW_CHR, 1

                RSUB    KEYB$INIT, 1                
MAIN_LOOP       RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1
                CMP     0, R8
                RBRA    MAIN_LOOP, Z            ; loop until key was pressed

                MOVE    R0, R2                  ; remember old position
                MOVE    R1, R3

                CMP     M2M$KEY_UP, R8          ; cursor up
                RBRA    KT_1, !Z
                SUB     1, R1
                RBRA    DC, 1

KT_1            CMP     M2M$KEY_DOWN, R8        ; cursor down
                RBRA    KT_2, !Z
                ADD     1, R1                
                RBRA    DC, 1

KT_2            CMP     M2M$KEY_LEFT, R8        ; cursor left
                RBRA    KT_3, !Z
                SUB     1, R0
                RBRA    DC, 1

KT_3            CMP     M2M$KEY_RIGHT, R8       ; cursor right
                RBRA    KT_4, !Z
                ADD     1, R0
                RBRA    DC, 1

KT_4            CMP     M2M$KEY_SPACE, R8       ; Space
                RBRA    KT_5, !Z
                MOVE    SPACE_CHR, R4
                RBRA    DC, 1

KT_5            CMP     M2M$KEY_RETURN, R8      ; Return
                RBRA    KT_6, !Z
                MOVE    RETURN_CHR, R4
                RBRA    DC, 1

KT_6            CMP     M2M$KEY_RUNSTOP, R8     ; Run/Stop
                RBRA    KT_7, !Z
                MOVE    RUNSTOP_CHR, R4
                RBRA    DC, 1

KT_7            CMP     M2M$KEY_HELP, R8        ; Help
                RBRA    KT_X, !Z
                MOVE    HELP_CHR, R4
                RBRA    DC, 1

DC              RSUB    DRAW_CHR, 1
KT_X            RBRA    MAIN_LOOP, 1

                ; draw character and delete it at old position
DRAW_CHR        MOVE    R2, R8
                MOVE    R3, R9
                RSUB    SCR$GOTOXY, 1
                MOVE    CLEAR_CHR , R8
                RSUB    SCR$PRINTSTR, 1

                MOVE    R0, R8
                MOVE    R1, R9
                RSUB    SCR$GOTOXY, 1
                MOVE    R4, R8
                RSUB    SCR$PRINTSTR, 1
                RET                

; ----------------------------------------------------------------------------
; Strings
; ----------------------------------------------------------------------------

TITLE_STR       .ASCII_P " MiSTer2MEGA65 keyboard development testbed "
                .ASCII_P "done by sy2002 in July 2021\n\n"
                .ASCII_P "Use the cursor keys to move the character and use "
                .ASCII_P "SPACE, ENTER, RUN/STOP\nand HELP to change its "
                .ASCII_P "appearance.\n\n"
                .ASCII_P "Test the typematic repeat of the cursor up and "
                .ASCII_W "down keys by keeping\nthese keys pressed."

SPACE_CHR       .DW 1, 0
RETURN_CHR      .DW 2, 0
RUNSTOP_CHR     .DW 3, 0
HELP_CHR        .DW 4, 0
CLEAR_CHR       .ASCII_W " "

; ----------------------------------------------------------------------------
; Framework and Variables 
; ----------------------------------------------------------------------------

#include "keyboard.asm"
#include "screen.asm"
#include "sysdef.asm"
#include "tools.asm"

#include "keyboard_vars.asm"
#include "screen_vars.asm"
