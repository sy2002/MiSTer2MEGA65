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


START_SHELL     HALT

                ; TODO DELIT SAMPLE CODE FOR FORMATTING
TODO_DELT       MOVE    R8, R8                  ; invalidate device handle
                MOVE    0, @R8

; ----------------------------------------------------------------------------
; Directory browser, keyboard controller, On-Screen-Menu (OSM) and misc. tools
; ----------------------------------------------------------------------------

#include "dirbrowse.asm"
;#include "keyboard.asm"
;#include "tools.asm"

