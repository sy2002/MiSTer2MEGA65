; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Shell: User interface and core automation
;
; The intention of the Shell is to provide a uniform user interface and core
; automation for all MiSTer2MEGA65 projects.
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

                ; keep core in reset state
                ; activate OSM, configure position and size and clear screen                
START_SHELL     RSUB    KEYB$INIT, 1            ; init keyboard library
                RSUB    SCR$INIT, 1             ; retrieve VHDL generics
                MOVE    M2M$CSR, R0             ; keep core in reset state
                MOVE    M2M$CSR_RESET, @R0
                RSUB    SCR$OSM_M_ON, 1         ; switch on main OSM
                RSUB    SCR$CLR, 1

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
                MOVE    M2M$RAMROM_DATA, R8     ; R8 = welcome screen string
                RSUB    SCR$PRINTSTR, 1

                ; Wait for "Space to continue"
                ; TODO: The whole startup behavior of the Shell needs to be
                ; more flexible than this, see also README.md
START_SPACE     RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1
                CMP     M2M$KEY_SPACE, R8
                RBRA    START_SPACE, !Z         ; loop until Space was pressed

                ; Hide OSM and "un-reset" (aka start) the core
                RSUB    SCR$OSM_OFF, 1
                MOVE    M2M$CSR, R0
                AND     M2M$CSR_UN_RESET, @R0

                ; Main loop:
                ;
                ; The core is running and QNICE is waiting for triggers to
                ; react. Such triggers could be for example the "Help" button
                ; which is meant to open the options menu but also triggers
                ; from the core such as data requests from disk drives.
                ;
                ; The latter one could also be done via interrupts, but we
                ; will try to keep it simple in the first iteration and only
                ; increase complexity by using interrupts if neccessary.
MAIN_LOOP       RSUB    CHECK_DEBUG, 1          ; Run/Stop + Help + Cursor Up

                RSUB    KEYB$SCAN, 1            ; scan for single key presses
                RSUB    KEYB$GETKEY, 1

                RSUB    HELP_MENU, 1            ; check/manage help menu

                RBRA    MAIN_LOOP, 1

; ----------------------------------------------------------------------------
; Help menu / Options menu
; ----------------------------------------------------------------------------

HELP_MENU       INCRB
                CMP     M2M$KEY_HELP, R8        ; help key pressed?
                RBRA    _HLP_RET, !Z

                RSUB    SCR$OSM_O_ON, 1         ; activate overlay (visible)

                SYSCALL(exit, 1)

_HLP_RET        DECRB
                RET                

; ----------------------------------------------------------------------------
; Debug mode: Run/Stop + Help + Cursor Up
; ----------------------------------------------------------------------------

                ; Debug mode: Pressing Run/Stop + Help + Cursor Up
                ; simultaneously exits the main loop and starts the QNICE
                ; Monitor which can be used to debug via UART and a
                ; terminal program
CHECK_DEBUG     INCRB
                MOVE    M2M$KEY_UP, R0
                OR      M2M$KEY_RUNSTOP, R0
                OR      M2M$KEY_HELP, R0
                MOVE    M2M$KEYBOARD, R1        ; read keyboard status
                MOVE    @R1, R2
                NOT     R2, R2                  ; convert low active to hi
                AND     R0, R2
                CMP     R0, R2                  ; key combi pressed?
                DECRB
                RBRA    START_MONITOR, Z        ; yes: enter debug mode
                RET                             ; no: return to main loop
                
START_MONITOR   MOVE    DBG_START1, R8          ; print info message via UART
                SYSCALL(puts, 1)
                MOVE    START_SHELL, R8         ; show how to return to ..
                SYSCALL(puthex, 1)              ; .. the shell
                MOVE    DBG_START2, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)                ; small/irrelevant stack leak

; ----------------------------------------------------------------------------
; Directory browser, keyboard controller, On-Screen-Menu (OSM) and misc. tools
; ----------------------------------------------------------------------------

; hardcoded Shell strings
#include "strings.asm"

; framework libraries
#include "dirbrowse.asm"
#include "keyboard.asm"
#include "screen.asm"
#include "tools.asm"
