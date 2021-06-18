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
START_SHELL     RSUB    SCR$INIT, 1             ; retrieve VHDL generics
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

                SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Directory browser, keyboard controller, On-Screen-Menu (OSM) and misc. tools
; ----------------------------------------------------------------------------

#include "dirbrowse.asm"
#include "screen.asm"
#include "tools.asm"
;#include "keyboard.asm"
