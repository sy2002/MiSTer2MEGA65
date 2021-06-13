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

#include "screen.asm"
#include "tools.asm"

                ; keep core in reset state
                ; activate OSM, configure position and size and clear screen                
START_SHELL     MOVE    M2M$CSR, R0
                MOVE    M2M$CSR_RESET, @R0
                RSUB    SCR$OSM_FS_ON, 1
                RSUB    SCR$CLR, 1

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$VRAM_DATA, @R0              
                MOVE    M2M$RAMROM_DATA, R1

LOOP1_S         MOVE    M2M$CONFIG, @R0
                MOVE    @R1, R2
                RBRA    LOOP1_E, Z
                MOVE    M2M$VRAM_DATA, @R0
                MOVE    R2, @R1++
                RBRA    LOOP1_S, 1
                
LOOP1_E         SYSCALL(exit, 1)



                ; TODO DELIT SAMPLE CODE FOR FORMATTING
TODO_DELT       MOVE    R8, R8                  ; invalidate device handle
                MOVE    0, @R8

; ----------------------------------------------------------------------------
; Directory browser, keyboard controller, On-Screen-Menu (OSM) and misc. tools
; ----------------------------------------------------------------------------

#include "dirbrowse.asm"
;#include "keyboard.asm"
;#include "tools.asm"

