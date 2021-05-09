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


; EVERYTHING HERE IS DEBUG CODE - DELETE EVERYTHING

STR_DEBUG       .ASCII_W "MiSTer2MEGA65 Debug Message"

                ; activate OSM and configure position and size
START_SHELL     MOVE    M2M$CSR, R0             ; activate OSM
                MOVE    M2M$CSR_OSM_ON, @R0
                MOVE    M2M$OSM_XY, R0          ; take x|y of OSM from ..
                MOVE    M2M$SHELL_M_XY, R1      ; .. VHDL generics
                MOVE    @R1, @R0
                MOVE    M2M$OSM_DXDY, R0        ; tkae dx|dy of OSM from ..
                MOVE    M2M$SHELL_M_DXDY, R1    ; .. VHDL generics
                MOVE    @R1, @R0

                ; print debug string
                MOVE    STR_DEBUG, R0           ; R0: string pointer
                MOVE    M2M$RAMROM_DEV, R1      ; R1: device selector
                MOVE    M2M$RAMROM_DATA, R2     ; R2: MMIO data area
LOOP_S          MOVE    M2M$VRAM_DATA, @R1      ; switch to VRAM data
                MOVE    @R0++, @R2              ; copy char
                MOVE    M2M$VRAM_ATTR, @R1      ; switch to VRAM attributes
                MOVE    0x000F, @R2++           ; white font & blue background
                CMP     @R0, 0                  ; end of string?
                RBRA    LOOP_S, !Z              ; no; continue loop
                SYSCALL(exit, 1)      

                ; TODO DELIT SAMPLE CODE FOR FORMATTING
TODO_DELT       MOVE    R8, R8                  ; invalidate device handle
                MOVE    0, @R8

; ----------------------------------------------------------------------------
; Directory browser, keyboard controller, On-Screen-Menu (OSM) and misc. tools
; ----------------------------------------------------------------------------

#include "dirbrowse.asm"
;#include "keyboard.asm"
;#include "tools.asm"

