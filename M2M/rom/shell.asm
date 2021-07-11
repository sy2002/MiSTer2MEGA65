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

                ; init libraries
                RSUB    KEYB$INIT, 1            ; keyboard library
                RSUB    HELP_MENU_INIT, 1       ; menu library

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
MAIN_LOOP       RSUB    CHECK_DEBUG, 1          ; (Run/Stop+Cursor Up) + Help

                RSUB    KEYB$SCAN, 1            ; scan for single key presses
                RSUB    KEYB$GETKEY, 1

                RSUB    HELP_MENU, 1            ; check/manage help menu

                RBRA    MAIN_LOOP, 1

; ----------------------------------------------------------------------------
; Help menu / Options menu
; ----------------------------------------------------------------------------

                ; Check if Help is pressed and if yes, run the Options menu
HELP_MENU       INCRB
                CMP     M2M$KEY_HELP, R8        ; help key pressed?
                RBRA    _HLP_RET, !Z                

                ; TODO: We might want to pause/unpause the core while
                ; the Options menu is running

                ; run the menu
                RSUB    OPTM_SHOW, 1            ; fill VRAM
                RSUB    SCR$OSM_O_ON, 1         ; make overlay visible
                MOVE    OPTM_SELECTED, R9       ; use recently selected line
                MOVE    @R9, R8
                RSUB    OPTM_RUN, 1             ; run menu
                RSUB    SCR$OSM_OFF, 1          ; make overlay invisible

                ; Smart handling of last-recently-selected: only remember
                ; LRS when the menu is closed via pressing the Help key again.
                ; Otherwise (when using "Close Menu" or something like this),
                ; restart from the default start position
                MOVE    OPT_MENU_GROUPS, R10
                ADD     R8, R10
                CMP     OPTM_CLOSE, @R10
                RBRA    _HLP_RESETPOS, Z
                MOVE    R8, @R9                 ; remember recently sel. line
                RBRA    _HLP_RET, 1
_HLP_RESETPOS   MOVE    OPT_MENU_START, @R9     ; TODO: use config.vhd

_HLP_RET        DECRB
                RET

                ; init/configure the menu library
HELP_MENU_INIT  RSUB    ENTER, 1

                MOVE    OPT_MENU_DATA, R8
                MOVE    SCR$OSM_O_X, R9
                MOVE    @R9, R9
                MOVE    SCR$OSM_O_Y, R10
                MOVE    @R10, R10
                MOVE    SCR$OSM_O_DX, R11
                MOVE    @R11, R11
                MOVE    SCR$OSM_O_DY, R12
                MOVE    @R12, R12
                RSUB    OPTM_INIT, 1
                MOVE    OPTM_SELECTED, R8
                MOVE    OPT_MENU_START, @R8     ; TODO: use config.vhd
                MOVE    OPT_MENU_STDSEL, R8     ; default selections/state
                MOVE    OPT_MENU_CURSEL, R9
                XOR     R10, R10
_HLP_ILOOP      MOVE    @R8++, @R9++
                ADD     1, R10
                CMP     OPT_MENU_SIZE, R10
                RBRA    _HLP_ILOOP, !Z

                RSUB    LEAVE, 1
                RET


OPT_MENU_SIZE   .EQU 18                         ; amount of items
OPT_MENU_START  .EQU 2                          ; initial default selection
OPT_MENU_MODE   .EQU 1                          ; group # for mode selection
OPT_MENU_JOY    .EQU 2                          ; group # for joystock mapping
OPT_MENU_COL    .EQU 3

OPT_MENU_ITEMS  .ASCII_P " Game Boy Mode\n"
                .ASCII_P "\n"
                .ASCII_P " Classic\n"
                .ASCII_P " Color\n"
                .ASCII_P "\n"
                .ASCII_P " Joystick Mode\n"
                .ASCII_P "\n"
                .ASCII_P " Standard, Fire=A\n"
                .ASCII_P " Standard, Fire=B\n"
                .ASCII_P " Up=A, Fire=B\n"
                .ASCII_P " Up=B, Fire=A\n"
                .ASCII_P "\n"
                .ASCII_P " Color Mode\n"
                .ASCII_P "\n"
                .ASCII_P " Fully Saturated\n"
                .ASCII_P " LCD Emulation\n"
                .ASCII_P "\n"
                .ASCII_W " Close Menu\n"

OPT_MENU_GROUPS .DW 0, 0
                .DW OPT_MENU_MODE, OPT_MENU_MODE
                .DW 0, 0, 0
                .DW OPT_MENU_JOY, OPT_MENU_JOY, OPT_MENU_JOY, OPT_MENU_JOY
                .DW 0, 0, 0
                .DW OPT_MENU_COL, OPT_MENU_COL
                .DW 0
                .DW OPTM_CLOSE

OPT_MENU_STDSEL .DW 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0
OPT_MENU_LINES  .DW 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0

OPT_MENU_DATA   .DW     SCR$CLR, SCR$PRINTFRAME, SCR$PRINTSTR, SCR$PRINTSTRXY
                .DW     OPT_PRINTLINE, OPTM_SELECT, OPT_MENU_GETKEY
                .DW     OPTM_CALLBACK,
                .DW     M2M$OPT_SEL, 0
                .DW     OPT_MENU_SIZE, OPT_MENU_ITEMS
                .DW     OPT_MENU_GROUPS
                .DW     OPT_MENU_CURSEL ; is in RAM to remember last settings
                .DW     OPT_MENU_LINES

; Draws a horizontal line/menu separator at the y-pos given in R8, dx in R9
OPT_PRINTLINE   INCRB

                MOVE    SP, R0                  ; R0: use to restore stack
                MOVE    R8, R1                  ; R1: y-pos
                MOVE    OPTM_DX, R2             ; R2: width minus left/right..
                MOVE    @R2, R2                 ; ..boundary
                SUB     2, R2                   

                SUB     R2, SP                  ; memory for string
                SUB     3, SP                   ; 3: l/r boundary + zero term.
                MOVE    SP, R3
                MOVE    R3, R4                  ; remember for printing

                MOVE    M2M$NC_VE_LEFT, @R3++                
_PRINTLN_L      MOVE    M2M$NC_SH, @R3++
                SUB     1, R2
                RBRA    _PRINTLN_L, !Z
                MOVE    M2M$NC_VE_RIGHT, @R3++
                MOVE    0, @R3

                MOVE    R4, R8
                MOVE    OPTM_X, R9
                MOVE    @R9, R9
                MOVE    R1, R10
                RSUB    SCR$PRINTSTRXY, 1                

                MOVE    R0, SP
                DECRB
                RET

; Selects/unselects menu item in R8 (counting from 0 and counting also
; non-selectable menu entries such as lines)
; R9=0: unselect   R9=1: select
OPTM_SELECT     INCRB

                MOVE    OPTM_X, R0              ; R0: x start coordinate
                MOVE    @R0, R0
                ADD     1, R0
                MOVE    OPTM_Y, R1              ; R1: y start coordinate
                MOVE    @R1, R1
                ADD     1, R1
                ADD     R8, R1
                MOVE    OPTM_DX, R2             ; R2: width of selection
                MOVE    @R2, R2
                SUB     2, R2

                CMP     R9, 0                   ; R3: attribute to apply
                RBRA    _OPTM_FPS_1, Z
                MOVE    M2M$SA_COL_STD_INV, R3
                RBRA    _OPTM_FPS_2, 1
_OPTM_FPS_1     MOVE    M2M$SA_COL_STD, R3

_OPTM_FPS_2     MOVE    SCR$SYS_DX, R8          ; R10: start address in ..
                MOVE    @R8, R8
                MOVE    R1, R9                  ; .. attribute VRAM
                SYSCALL(mulu, 1)
                ADD     R0, R10
                ADD     M2M$RAMROM_DATA, R10

                MOVE    M2M$RAMROM_DEV, R4      ; switch to ATTR data, win 0
                MOVE    M2M$VRAM_ATTR, @R4
                MOVE    M2M$RAMROM_4KWIN, R4
                MOVE    0, @R4

                XOR     R4, R4
_OPTM_FPS_L     CMP     R2, R4
                RBRA    _OPTM_FPS_RET, Z
                MOVE    R3, @R10++
                ADD     1, R4
                RBRA    _OPTM_FPS_L, 1

_OPTM_FPS_RET   DECRB
                RET                

; Waits until one of the four Option Menu keys is pressed
; and returns the OPTM_KEY_* code in R8
OPT_MENU_GETKEY INCRB
_OPTMGK_LOOP    RSUB    KEYB$SCAN, 1            ; wait until key is pressed
                RSUB    KEYB$GETKEY, 1
                CMP     0, R8
                RBRA    _OPTMGK_LOOP, Z

                CMP     M2M$KEY_UP, R8          ; up
                RBRA    _OPTM_GK_1, !Z
                MOVE    OPTM_KEY_UP, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_1      CMP     M2M$KEY_DOWN, R8        ; down
                RBRA    _OPTM_GK_2, !Z
                MOVE    OPTM_KEY_DOWN, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_2      CMP     M2M$KEY_RETURN, R8      ; return (select)
                RBRA    _OPTM_GK_3, !Z
                MOVE    OPTM_KEY_SELECT, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_3      CMP     M2M$KEY_HELP, R8        ; help (close menu)
                RBRA    _OPTMGK_LOOP, !Z        ; other key: ignore
                MOVE    OPTM_KEY_CLOSE, R8

_OPTMGK_RET     DECRB
                RET

; Callback function that is called during the execution of the menu (OPTM_RUN)
; R8: selected menu group (as defined in OPTM_IR_GROUPS)
; R9: selected item within menu group
;     in case of single selected items: 0=not selected, 1=selected
OPTM_CALLBACK   RET         

; ----------------------------------------------------------------------------
; Debug mode:
; Hold "Run/Stop" + "Cursor Up" and then while holding these, press "Help"
; ----------------------------------------------------------------------------

                ; Debug mode: Exits the main loop and starts the QNICE
                ; Monitor which can be used to debug via UART and a
                ; terminal program. You can return to the Shell by using
                ; the Monitor C/R command while entering the start address
                ; that is shown in the terminal (using the "puthex" below).
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
#include "menu.asm"
#include "screen.asm"
#include "tools.asm"
