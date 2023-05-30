; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Options Menu
;
; The Options menu is a reusable and self-contained component that consists of
; this file and the file menu_vars.asm. It can be used independently from the
; Shell either in other M2M projects such as an alternative to the Shell or
; completely independent from M2M.
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Special values for OPTM_IR_GROUPS
; ----------------------------------------------------------------------------

OPTM_CLOSE      .EQU 0x00FF                     ; menu item: close (sub)menu
OPTM_HEADLINE   .EQU 0x1000                     ; AND mask: headline/title itm
OPTM_SUBMENU    .EQU 0x4000                     ; AND mask: submenu start/stop
OPTM_SINGLESEL  .EQU 0x8000                     ; AND mask: single select item

; ----------------------------------------------------------------------------
; Option Menu key codes (to be returned by the function in OPTM_FP_GETKEY)
; ----------------------------------------------------------------------------

OPTM_KEY_UP     .EQU 1
OPTM_KEY_DOWN   .EQU 2
OPTM_KEY_SELECT .EQU 3                          ; normally this is Return
OPTM_KEY_CLOSE  .EQU 4                          ; normally this is Help
OPTM_KEY_SELALT .EQU 5                          ; normally this is Space
OPTM_KEY_MENUUP .EQU 6                          ; normally this is Run/Stop

; ----------------------------------------------------------------------------
; Action codes for the OPTM_FP_SELECT function
; ----------------------------------------------------------------------------

OPTM_SEL_STD    .EQU 0
OPTM_SEL_SEL    .EQU 1
OPTM_SEL_TLL    .EQU 2
OPTM_SEL_TLLSEL .EQU 3

; ----------------------------------------------------------------------------
; Hardcoded error messages for OPTM_CLBK_HALT
; ----------------------------------------------------------------------------

OPTM_STR_SPACE  .ASCII_W " "

OPTM_F_MENUSUB  .ASCII_P "menu.asm: One or more submenu is not\n"
                .ASCII_P "specified correctly:\n"
                .ASCII_W "Missing submenu-end-flag.\n"
OPTM_F_F2M      .ASCII_P "menu.asm: _OPTM_R_F2M:\n"
                .ASCII_P "Corrupt memory layout: Flat coordinate is\n"
                .ASCII_W "larger than menu size.\n"
OPTM_F_NOSEL    .ASCII_P "menu.asm: _OPTM_RUN_SM:\n"
                .ASCII_P "Corrupt memory layout: No selectable menu\n"
                .ASCII_W "item found.\n"
OPTM_F_MENUIDX  .ASCII_P "menu.asm: OPTM_RUN:\n"
                .ASCII_P "Corrupt memory layout or logic error:\n"
                .ASCII_P "Menu index does not exist in currently\n"
                .ASCII_W "active menu level.\n"
OPTM_F_MENUGRP  .ASCII_P "menu.asm: OPTM_SET\n"
                .ASCII_P "Corrupt memory layout or structural error\n"
                .ASCII_P "in current menu group (config.vhd):\n"
                .ASCII_P "Did not find any menu group item that\n"
                .ASCII_W "can be deselected. Only one item in group?\n"
OPTM_F_MENUGRP2 .ASCII_P "menu.asm: OPTM_SET\n"
                .ASCII_P "Unsetting (R9=0) is illegal for menu\n"
                .ASCII_W "groups. One item always needs to be 1.\n"
OPTM_F_MENUGRP3 .ASCII_P "menu.asm: OPTM_SET\n"
                .ASCII_W "Logic bug or memory corruption in M2M.\n"

OPTM_F_MSTRUCT  .ASCII_P "menu.asm: OPTM_RUN is not running.\n"
                .ASCII_W "OPTM_STRUCT is invalid.\n"
OPTM_F_MS_SELF  .EQU 0x0001 ; _OPTM_R_F2M_O
OPTM_F_MS_SLCT  .EQU 0x0002 ; OPTM_SELECT
OPTM_F_MS_SET1  .EQU 0x0003 ; OPTM_SET
OPTM_F_MS_SET2  .EQU 0x0004 ; OPTM_SET

; ----------------------------------------------------------------------------
; Initialization record that is filled using OPTM_INIT
; ----------------------------------------------------------------------------

; Function that clears the VRAM
OPTM_FP_CLEAR   .EQU 0  

; Function that draws the frame
; x|y = R8|R9, dx|dy = R10|R11
OPTM_FP_FRAME   .EQU 1

; Print function that handles everything incl. cursor pos and \n by itself
; R8 contains the string that shall be printed
; R9 contains a pointer to a mask array: the first word is the size of the
;    array (and therefore the amount of menu items) and then we have one entry
;    (word) per menu line: If the highest bit is one, then OPTM_FP_PRINT will
;    print the line otherwise it will skip the line
OPTM_FP_PRINT   .EQU 2

; Like OPTM_FP_PRINT but contains target x|y coords in R9|R10
; PRINTXY directly prints on the screen, without any mask array
OPTM_FP_PRINTXY .EQU 3

; Draws a horizontal line/menu separator at the y-pos given in R8
OPTM_FP_LINE    .EQU 4

; Selects/unselects menu item in R8 (counting from 0 and counting also
; non-selectable menu entries such as lines) and highlights headlines/titles
; R9=0: unselect
; R9=1: select
; R9=2: print headline/title highlighted
; R9=3: select highlighted headline/title
OPTM_FP_SELECT  .EQU 5

; Waits until one of the six Option Menu keys is pressed
; and returns the OPTM_KEY_* code in R8
OPTM_FP_GETKEY  .EQU 6

; Callback function: OPTM_RUN will call it back each time the user selects
; anything in the menu
; R8: selected menu group (as defined in OPTM_IR_GROUPS)
; R9: selected item within menu group
;     in case of single selected items: 0=not selected, 1=selected
; R10: OPTM_KEY_SELECT=selection was done using standard key (normally Enter)
;      OPTM_KEY_SELALT=selection was done using alternative key (norm. Space)
OPTM_CLBK_SEL   .EQU 7

; Callback function: OPTM_SHOW will call it each time it finds a "%s" inside
; a menu item string. If you are not using any "%s" in any of your strings,
; then you can use a null pointer instead of specifying a callback.
; Input:
;   R8: pointer to the string that includes the "%s"
;   R9: index of menu item
; Output:
;   R8: Pointer to a completely new string that shall be shown instead of
;       the original string that contains the "%s"; so do not just replace
;       the "%s" inside the string but provide a completely new string.
;       Alternatively, if you do not want to change the string, you can
;       just return R8 unchanged.
OPTM_CLBK_SHOW  .EQU 8

; Callback function: OPTM_FATAL will output an error message and then halt
; the system.
; Input:
;   R8: pointer to a string (error message)
;   R9: zero or optional additional error number
OPTM_CLBK_FATAL .EQU 9

; multi-selection character + zero-terminator, after that:
; single-selection character + zero-terminator, total: 4 words in length!
OPTM_IR_SEL     .EQU 10

; amount of menu items: the length of the arrays to which OPTM_IR_GROUPS,
; OPTM_IR_DEFAULT and OPTM_IR_LINES point needs to be equal to this amount
OPTM_IR_SIZE    .EQU 14

; pointer to string containing the menu items and separating them with \n
OPTM_IR_ITEMS   .EQU 15

; pointer to array of digits that define and group menu items
OPTM_IR_GROUPS  .EQU 16

; pointer to array of 0s and 1s to define menu items that are activated by
; default in case this array is located in RAM, these are the advantages (but
; it can without problems also be located in ROM): the menu remembers the
; various multi- and single selections, if any and the menu prevents calling
; the callback function for already selected items
OPTM_IR_STDSEL  .EQU 17

; array of 0s and 1s to define horizontal separator lines
OPTM_IR_LINES   .EQU 18

; size of initialization record in words
OPTM_STRUCTSIZE .EQU 19

OPTM_NL         .DW  0x005C, 0x006E, 0x0000     ; \n

; ----------------------------------------------------------------------------
; OPTM_INIT: Initialize data structures needed for the menu
;
; Input:
;  R8: pointer to initialization record
;  R9: x-coord
; R10: y-coord
; R11: width
; R12: height
;
; The coordinates are relative to the screen and not to the "window" within
; the menu is being drawn.
;
; Output: None, no registers are changed
; ----------------------------------------------------------------------------

OPTM_INIT       INCRB

                MOVE    OPTM_DATA, R0
                MOVE    R8, @R0
                MOVE    OPTM_X, R0
                MOVE    R9, @R0
                MOVE    OPTM_Y, R0
                MOVE    R10, @R0
                MOVE    OPTM_DX, R0
                MOVE    R11, @R0
                MOVE    OPTM_DY, R0
                MOVE    R12, @R0
                MOVE    OPTM_MENULEVEL, R0
                MOVE    0, @R0
                MOVE    OPTM_MAINSEL, R0
                MOVE    0, @R0
                MOVE    OPTM_CUR_SEL, R0
                MOVE    0, @R0
                MOVE    OPTM_SSMS, R0
                MOVE    0, @R0
                MOVE    OPTM_TEMP, R0
                MOVE    0, @R0
                MOVE    OPTM_STRUCT, R0
                MOVE    0, @R0

                DECRB
                RET

; ----------------------------------------------------------------------------
; Show menu: Draw frame and fill it with the menu items
;
; Input/Output: None, no registers are changed
; ----------------------------------------------------------------------------

OPTM_SHOW       SYSCALL(enter, 1)

                MOVE    OPTM_DATA, R0           ; R0: string to be printed
                MOVE    @R0, R0
                ADD     OPTM_IR_ITEMS, R0
                MOVE    @R0, R0
                MOVE    OPTM_DATA, R1           ; R1: size of menu (# items)
                MOVE    @R1, R1
                ADD     OPTM_IR_SIZE, R1
                MOVE    @R1, R1                
                MOVE    OPTM_DATA, R2           ; R2: default activated elms.
                MOVE    @R2, R2
                ADD     OPTM_IR_STDSEL, R2
                MOVE    @R2, R2
                MOVE    OPTM_DATA, R3           ; R3: pos of horiz. lines
                MOVE    @R3, R3
                ADD     OPTM_IR_LINES, R3
                MOVE    @R3, R3
                MOVE    OPTM_DATA, R4           ; R4: menu groups
                MOVE    @R4, R4
                ADD     OPTM_IR_GROUPS, R4
                MOVE    @R4, R4

                MOVE    OPTM_FP_CLEAR, R7       ; clear VRAM
                RSUB    _OPTM_CALL, 1

                ; ------------------------------------------------------------
                ; Create the menu/submenu structure (array) on the stack
                ; ------------------------------------------------------------

                SUB     R1, SP                  ; reserve memory on the stack
                SUB     1, SP                   ; 1st word in array = size
                MOVE    SP, R8
                MOVE    R8, R5                  ; remember address of array
                MOVE    R1, R9
                RSUB    _OPTM_STRUCT, 1

                ; ------------------------------------------------------------
                ; Draw the first iteration of the menu
                ; (In case there are %s, they will be drawn as %s)
                ; ------------------------------------------------------------

                ; the coordinates are relative to the top/left of the screen
                ; and not relative to the top/left of the "window"/"frame"
                ; that is drawn around the menu
                MOVE    OPTM_X, R8
                MOVE    @R8, R8
                MOVE    OPTM_Y, R9
                MOVE    @R9, R9
                MOVE    OPTM_DX, R10
                MOVE    @R10, R10
                MOVE    OPTM_DY, R11
                MOVE    @R11, R11
                MOVE    OPTM_FP_FRAME, R7       ; draw frame
                RSUB    _OPTM_CALL, 1
                MOVE    R0, R8                  ; R8: strint to be printed
                MOVE    R5, R9                  ; R9: (sub)menu mask array
                MOVE    OPTM_FP_PRINT, R7       ; print menu
                RSUB    _OPTM_CALL, 1

                ; ------------------------------------------------------------
                ; Highlight Headlines/Titles
                ; ------------------------------------------------------------

                ; use INCRB to protect R0..R7
                ; bring R4 and R5 over the INCRB hump
                MOVE    R4, @--SP
                MOVE    R5, @--SP
                INCRB                           ; protect R0..R7
                MOVE    @SP++, R5               ; R5: (sub)menu structure
                MOVE    @SP++, R0               ; R0: menu groups
                MOVE    @R5++, R2               ; R2: amount of menu items

                XOR     R1, R1                  ; R1: hilight itm count frm 0
                XOR     R4, R4                  ; R4: skip counter

_OPTM_TT_0      MOVE    @R0++, R3

                CMP     @R5++, 0x7FFF           ; menu item visible as per..
                RBRA    _OPTM_TT_1A, !N         ; .. (sub)menu structure?

                AND     OPTM_HEADLINE, R3
                RBRA    _OPTM_TT_1B, Z          ; flag not set: continue

                ; flag is set, so print the menu item in highlighted mode
                MOVE    OPTM_FP_SELECT, R7
                MOVE    R1, R8                  ; itm to highlight, cnt frm 0
                SUB     R4, R8                  ; deduct skip counter
                MOVE    OPTM_SEL_TLL, R9
                RSUB    _OPTM_CALL, 1
                RBRA    _OPTM_TT_1B, 1

                ; for each entry that we skip because of an invisible flag in
                ; the (sub)menu structure, we need to increase a skip counter
                ; so that the position of the highlight is still correct
_OPTM_TT_1A     ADD     1, R4

                ; iterate
_OPTM_TT_1B     ADD     1, R1                   ; next item to highlight
                SUB     1, R2                   ; next item; are we done?
                RBRA    _OPTM_TT_0, !Z          ; no: continue

                DECRB                           ; restore R0..R7

                MOVE    R5, @--SP               ; save R5
                MOVE    R5, R1                  ; R1: (sub)menu structure
                ADD     1, R1                   ; skip size info

                ; ------------------------------------------------------------
                ; Handle "%s" in menu items
                ; ------------------------------------------------------------

                ; Is there a callback function specified at all?
                ; If no, we can skip this whole code and speed-up things
                MOVE    OPTM_DATA, R8
                MOVE    @R8, R8
                ADD     OPTM_CLBK_SHOW, R8
                CMP     0, @R8
                RBRA    _OPTM_SHOW_0, Z         ; no: skip

                ; R12: Skip counter: Due to the current (sub)menu situation:
                ; How many invisible elements do we have. We need this to
                ; calculate the correct Y position for printing %s strings.
                ; At this position of the code, we are at item #0, so we need
                ; also to take account for this very element, as the upcoming
                ; loop will not.
                XOR     R12, R12                ; R12: skip counter
                CMP     @R1, 0x7FFF             ; item currently visible?
                RBRA    _OPTM_HM_START, N       ; yes: continue
                ADD     1, R12                  ; no: invis.: incr. skip cnt.

                ; loop through the string, char by char and interpret \n as
                ; newline (i.e. increment the index of the menu item)
_OPTM_HM_START  XOR     R5, R5                  ; R5 = index of menu item
                MOVE    R0, R7                  ; R7 = start of current str
_OPTM_HM_0      CMP     0, @R0                  ; end of string reached?
                RBRA    _OPTM_SHOW_0, Z         ; yes

                CMP     0x005C, @R0             ; search newline: backslash
                RBRA    _OPTM_HM_1A, !Z         ; no
                ADD     1, R0                   ; skip character
                CMP     'n', @R0                ; "\n" found?
                RBRA    _OPTM_HM_1A, !Z         ; no
                ADD     1, R0                   ; skip character
                MOVE    R0, R7                  ; R7 starts from the new line
                ADD     1, R5                   ; next index of menu item                
                ADD     1, R1                   ; ..and next idx of men. strct
                CMP     @R1, 0x7FFF             ; item currently invisible?
                RBRA    _OPTM_HM_0, N           ; no: continue
                ADD     1, R12                  ; yes: invis.: incr. skip cnt.                
                RBRA    _OPTM_HM_0, 1                

                ; search for %s in the string
_OPTM_HM_1A     CMP     '%', @R0                ; search for "%s"
                RBRA    _OPTM_HM_2, !Z          ; no
                ADD     1, R0                   ; skip character
                CMP     's', @R0                ; "%s" found?
                RBRA    _OPTM_HM_2, !Z          ; no
                ADD     1, R0                   ; skip character

                ; respect (sub)menu structure: skip invisible items by
                ; finding the next \n and then advancing behind it (see also
                ; the next comment that starts with "per definition...")
                CMP     @R1, 0x7FFF             ; item visible?
                RBRA    _OPTM_HM_HS, N          ; yes: handle %s
                MOVE    R0, R8                  ; search from behind the %s
                MOVE    OPTM_NL, R9             ; and find \n
                SYSCALL(strstr, 1)
                CMP     0, R10                  ; no \n found means EOS
                RBRA    _OPTM_SHOW_0, Z
                ADD     2, R10                  ; skip \n
                CMP     0, @R10                 ; end of string?
                RBRA    _OPTM_SHOW_0, Z         ; yes
                RBRA    _OPTM_HM_0, 1           ; no: next iteration    

                ; Extract from R7 (start of current string) to \n and provide
                ; this string and the index to the callback function. This
                ; is done by copying the segment on the stack.
                ;
                ; Per definition, each line must end with a \n, so if we do
                ; not find a \n then this means there is an error in
                ; config.vhd, so we kind of gracefully exit the %s handling
                ; and continue with tagging the menu items
_OPTM_HM_HS     MOVE    R0, R8                  ; search from behind the %s
                MOVE    OPTM_NL, R9             ; and find \n
                SYSCALL(strstr, 1)
                CMP     0, R10                  ; no \n found means EOS
                RBRA    _OPTM_SHOW_0, Z

                MOVE    R10, R6                 ; R6: length of substring
                SUB     R7, R6
                ADD     1, R6                   ; space for zero terminator

                MOVE    R7, R8                  ; extract from the beginning
                SUB     R6, SP                  ; make room on the stack ..
                MOVE    SP, R11
                MOVE    SP, R9                  ; .. and copy segment to stack
                MOVE    R6, R10
                SUB     1, R10                  ; zero term. is added manually
                SYSCALL(memcpy, 1)
                MOVE    R11, R8
                ADD     R10, R8
                MOVE    0, @R8

                MOVE    R7, @--SP               ; save ptr to current line

                MOVE    OPTM_CLBK_SHOW, R7      ; call callback function
                MOVE    R11, R8
                MOVE    R5, R9
                RSUB    _OPTM_CALL, 1

                ; print string from callback, which is in R8                
                MOVE    OPTM_FP_PRINTXY, R7
                MOVE    OPTM_X, R9
                MOVE    @R9, R9
                ADD     1, R9                   ; add 1 to x because of frame
                MOVE    OPTM_Y, R10
                MOVE    @R10, R10
                ADD     R5, R10                 ; R5 is # of menu item, so..
                ADD     1, R10                  ; ..add 1 to y b/c of frame
                SUB     R12, R10                ; adjust for skipped items
                MOVE    R11, @--SP              ; save R11
                XOR     R11, R11                ; R11=0: show main menu
                RSUB    _OPTM_CALL, 1
                MOVE    @SP++, R11              ; restore R11

                MOVE    @SP++, R7               ; restore ptr

                ADD     R6, SP                  ; restore stack
                ADD     1, R5                   ; next line
                ADD     1, R1                   ; next (sub)menu struct. item
                CMP     @R1, 0x7FFF             ; next item invisible?
                RBRA    _OPTM_HM_1B, N          ; no: proceed
                ADD     1, R12                  ; yes: increase skip counter
_OPTM_HM_1B     MOVE    R7, R0                  ; next part of original string
                ADD     R6, R0
                MOVE    R0, R7
                ADD     1, R7

                ; continue to search for %s
_OPTM_HM_2      ADD     1, R0
                RBRA    _OPTM_HM_0, 1 

                ; ------------------------------------------------------------
                ; Tag selected menu items and draw lines
                ; ------------------------------------------------------------

_OPTM_SHOW_0    MOVE    @SP++, R5               ; restore R5: (sub)menu struct
                MOVE    @R5++, R1               ; amount of menu items
                MOVE    1, R6                   ; R6: current y-pos
                XOR     R12, R12                ; R12: skip counter

                XOR     R0, R0                  ; R0: iteration position
_OPTM_SHOW_1    CMP     R0, R1                  ; R0 < R1 (start from 0)
                RBRA    _OPTM_SHOW_4, Z         ; end reached

                CMP     @R5++, 0x7FFF           ; active (sub)menu item?
                RBRA    _OPTM_SHOW_1A, N        ; yes
                ADD     1, R12                  ; no: increase skip counter
                RBRA    _OPTM_SHOW_3, 1         ; next iteration

_OPTM_SHOW_1A   CMP     0, @R2                  ; show select. at this point?
                RBRA    _OPTM_SHOW_2, Z         ; no
                MOVE    OPTM_DATA, R8           ; yes: print selection here
                MOVE    @R8, R8

                ADD     OPTM_IR_SEL, R8         ; decide: single or multi-sel.
                MOVE    @R4, R7
                AND     OPTM_SINGLESEL, R7
                RBRA    _OPTM_SHOW_1B, Z        ; multi-select
                ADD     2, R8                   ; single-select

_OPTM_SHOW_1B   MOVE    OPTM_X, R9              ; R9: current x-pos
                MOVE    @R9, R9
                ADD     1, R9
                MOVE    R6, R10                 ; R10: current y-pos
                SUB     R12, R10                ; adjust for skipped items
                MOVE    OPTM_FP_PRINTXY, R7
                MOVE    R11, @--SP              ; save R11
                XOR     R11, R11                ; R11=0: show main menu
                RSUB    _OPTM_CALL, 1
                MOVE    @SP++, R11              ; restore R11
                RBRA    _OPTM_SHOW_3, 1

_OPTM_SHOW_2    CMP     0, @R3                  ; horiz. line here?
                RBRA    _OPTM_SHOW_3, Z         ; no
                MOVE    R6, R8                  ; yes: R8: y-pos of line
                SUB     R12, R8                 ; adjust for skipped items
                MOVE    OPTM_FP_LINE, R7        ; draw line
                RSUB    _OPTM_CALL, 1

_OPTM_SHOW_3    ADD     1, R0                   ; next menu item
                ADD     1, R2                   ; next selected info
                ADD     1, R3                   ; next horiz. line flag
                ADD     1, R4                   ; next single/multi sel. info                
                ADD     1, R6                   ; next y-pos
                RBRA    _OPTM_SHOW_1, 1

                ; End of list reached: Special case: Are we in a submenu and
                ; is the submenu shorter than the window? Then draw a line
                ; under the menu item that closes the submenu if there are
                ; at least two lines before the end of the window (EOW)
_OPTM_SHOW_4    MOVE    OPTM_MENULEVEL, R8
                CMP     0, @R8
                RBRA    _OPTM_SHOW_RET, Z       ; main menu: no special case

                MOVE    OPTM_Y, R8
                MOVE    @R8, R8
                MOVE    OPTM_DY, R9
                ADD     @R9, R8
                SUB     3, R8                   ; at least 2 lines before EOW
                CMP     0, R8                   ; underflow?
                RBRA    _OPTM_SHOW_RET, V       ; yes: do not draw the line
                MOVE    R8, R9

                MOVE    R6, R8                  ; R8: y-pos of line
                SUB     R12, R8                 ; adjust for skipped items
                CMP     R8, R9                  ; should we draw the line?
                RBRA    _OPTM_SHOW_RET, N       ; no
                MOVE    OPTM_FP_LINE, R7        ; yes: draw line
                RSUB    _OPTM_CALL, 1

_OPTM_SHOW_RET  ADD     R1, SP                  ; restore SP / free memory
                ADD     1, SP

                SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; OPTM_RUN: Runs menu and returns result
;
; Input:
;  R8: Default cursor position/selection
;
; Output:
;   R8: Selected cursor position
;   plus: Will callback OPTM_CLBK_SEL (see above) on each press
;         of the selection key (with the exception that pressing the selection
;         key while hovering over a submenu entry or exit point handles the
;         submenu instead of calling OPTM_CLBK_SEL).
;
; Semantics of "cursor position" in R8: It is the position within OPTM_ITEMS
; and OPTM_GROUPS (both from config.vhd), i.e. R8 considers the menu to be
; a big flat list without submenus.
; ----------------------------------------------------------------------------

OPTM_RUN        SYSCALL(enter, 1)

                MOVE    OPTM_DATA, R0           ; R0: size of data structure
                MOVE    @R0, R0
                ADD     OPTM_IR_SIZE, R0
                MOVE    @R0, R0
                MOVE    OPTM_DATA, R1           ; R1: menu item groups
                MOVE    @R1, R1
                ADD     OPTM_IR_GROUPS, R1
                MOVE    @R1, R1
                MOVE    R8, R2                  ; R2: sel. item in flat coord
                MOVE    R2, R3                  ; R3: old selected item

                ; Create the menu/submenu structure (array) on the stack
                ;
                ; SP+2 will point to the menu/submenu structure;
                ;      use SP+3 to skip the size info that is not needed here
                ; SP+1 will point to a pointer that indicates the current
                ;      iteration position within (SP+2)
                ; SP+0 will point to the size of the current (sub)menu
                ;
                ; We will need to add 3 when cleaning up the stack due to the
                ; below-mentioned stack allocations.
                SUB     R0, SP                  ; reserve memory on the stack
                SUB     1, SP                   ; 1st word in array = size
                MOVE    SP, R8
                MOVE    R0, R9
                RSUB    _OPTM_STRUCT, 1
                SUB     1, SP                   ; reserve space for (SP+1)
                MOVE    R9, @--SP               ; size of (sub)men at (SP+0)
                MOVE    OPTM_STRUCT, R7         ; remember pointer to struct.
                MOVE    SP, @R7

                ; Main loop
_OPTM_RUN_SEL   MOVE    SP, R8                  ; update (SP+1), i.e. update..
                ADD     3, R8                   ; ..the pointer to the curr..
                ADD     R2, R8                  ; ..iteration pos
                MOVE    SP, R7
                ADD     1, R7
                MOVE    R8, @R7

                MOVE    OPTM_FP_SELECT, R7      ; select line
                MOVE    R2, R8                  ; R8: selected item
                RSUB    _OPTM_R_F2M, 1          ; convert R8 to screen coord.
                RBRA    _OPTM_R_FATAL, C        ; failed? fatal!
                MOVE    OPTM_SEL_SEL, R9
                RSUB    _OPTM_CALL, 1
                MOVE    OPTM_CUR_SEL, R8        ; remember for ext. routines..
                MOVE    R2, @R8                 ; to be able to process it

                MOVE    OPTM_FP_GETKEY, R7      ; get next keypress
                RSUB    _OPTM_CALL, 1

                ; Cursor up
                CMP     OPTM_KEY_UP, R8         ; key: up?
                RBRA    _OPTM_RUN_3, !Z         ; no: check other key
_OPTM_RUN_1     CMP     0, R2                   ; yes: wrap around at top?
                RBRA    _OPTM_KU_NWA, !Z        ; no: find next menu item
                MOVE    R0, R2                  ; yes: wrap around R2
                SUB     1, R2
                MOVE    SP, R7                  ; wrap around (SP+1)
                ADD     1, R7
                MOVE    SP, R6
                ADD     3, R6
                ADD     R0, R6
                SUB     1, R6
                MOVE    R6, @R7
                RBRA    _OPTM_KU_WA, 1

_OPTM_KU_NWA    SUB     1, R2                   ; one element up
                MOVE    SP, R7                  ; is the prev. element still..
                ADD     1, R7                   ; ..part of the currently..
                SUB     1, @R7                  ; ..active (sub)menu?
_OPTM_KU_WA     MOVE    @R7, R7
                MOVE    @R7, R7                 ; R7: cur elm in (sub)mn strct

                SHL     1, R7                   ; check bit 15
                RBRA    _OPTM_RUN_1, !C         ; no: continue searching

                MOVE    R1, R6                  ; yes: find next menu item:
                ADD     R2, R6                  ; descending
                MOVE    @R6, R6

                MOVE    R6, R7                  ; headline/label of a submenu?
                AND     OPTM_SUBMENU, R7
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on

                AND     0x00FF, R6              ; mask flags such as headline
                CMP     0, R6                   ; menu item found?
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on
                RBRA    _OPTM_RUN_1, 1          ; no: continue searching

                ; Unselect old item and select current item
_OPTM_RUN_2     MOVE    OPTM_FP_SELECT, R7      ; unselect old item
                MOVE    R3, R8
                RSUB    _OPTM_R_F2M, 1          ; convert R8 to screen coord.
                RBRA    _OPTM_R_FATAL, C        ; failed? fatal!                
                MOVE    OPTM_SEL_STD, R9
                RSUB    _OPTM_CALL, 1
                MOVE    R2, R3                  ; remember current item as old
                RBRA    _OPTM_RUN_SEL, 1

                ; Cursor down
_OPTM_RUN_3     CMP     OPTM_KEY_DOWN, R8       ; key: down?
                RBRA    _OPTM_RUN_5A, !Z        ; no: check other key

_OPTM_RUN_4     MOVE    R0, R7                  ; yes: wrap around at bottom?
                SUB     1, R7
                CMP     R7, R2
                RBRA    _OPTM_KD_NWA, !Z        ; no: find next menu item
                XOR     R2, R2                  ; yes: wrap around R2
                MOVE    SP, R7                  ; wrap around/reset (SP+1)
                ADD     1, R7
                MOVE    SP, R6
                ADD     3, R6
                MOVE    R6, @R7
                RBRA    _OPTM_KD_WA, 1

_OPTM_KD_NWA    ADD     1, R2                   ; one element down
                MOVE    SP, R7                  ; is the next element still..
                ADD     1, R7                   ; ..part of the currently..
                ADD     1, @R7                  ; ..active (sub)menu?
_OPTM_KD_WA     MOVE    @R7, R7
                MOVE    @R7, R7                 ; R7: cur elm in (sub)mn strct                 
                SHL     1, R7                   ; check bit 15
                RBRA    _OPTM_RUN_4, !C         ; no: continue searching

                MOVE    R1, R6                  ; yes: find next menu item..
                ADD     R2, R6                  ; ..ascending
                MOVE    @R6, R6

                MOVE    R6, R7                  ; headline/label of a submenu?
                AND     OPTM_SUBMENU, R7
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on

                AND     0x00FF, R6              ; mask out any flags
                CMP     0, R6                   ; menu item found?
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on
                RBRA    _OPTM_RUN_4, 1          ; no: continue searching

                ; Close menu key
_OPTM_RUN_5A    CMP     OPTM_KEY_CLOSE, R8      ; key: close?
                RBRA    _OPTM_RUN_5C, !Z        ; no: check other key
_OPTM_RUN_5B    MOVE    R2, R8                  ; return selected item
                RBRA    _OPTM_RUN_RET, 1

                ; One menu level up (i.e. as long as we only have one submenu
                ; level this means: back to main menu) - or - close menu if
                ; we are already in the main menu
_OPTM_RUN_5C    CMP     OPTM_KEY_MENUUP, R8     ; key: menu up?
                RBRA    _OPTM_RUN_6A, !Z        ; no: check other key
                MOVE    OPTM_MENULEVEL, R7      ; already at main menu level?
                CMP     0, @R7
                RBRA    _OPTM_RUN_5B, Z         ; yes: close menu and return
                MOVE    OPTM_MENULEVEL, R9      ; no: one menu level up
                RBRA    _OPTM_RUN_SM_L, 1

                ; Select key
_OPTM_RUN_6A    CMP     OPTM_KEY_SELECT, R8     ; key: select?
                RBRA    _OPTM_RUN_6C, Z         ; yes
_OPTM_RUN_6B    CMP     OPTM_KEY_SELALT, R8     ; key: alternative select?
                RBRA    _OPTM_RUN_SEL, !Z       ; no: ignore key

                ; avoid "double-firing" of already selected items by
                ; ignoring the selection key in this case
                ;
                ; exception: single-select items actually need to fire each
                ; time you select them as they flip their state
                ; 
                ; this "double-firing prevention" only works in those cases,
                ; where OPTM_IR_STDSE resides in RAM; otherwise the menu
                ; actually does "double-fire" and the application program
                ; needs to be robust enough to not fail in this case
_OPTM_RUN_6C    MOVE    R8, R11                 ; R11: remember selection key

                ; Submenus: Special behavior
                MOVE    R1, R6                  ; R1: ptr. to OPTM_IR_GROUPS 
                ADD     R2, R6                  ; R2: sel. item in flat coord
                MOVE    @R6, R7
                AND     OPTM_SUBMENU, R7        ; is it a submenu?
                RBRA    _OPTM_RUN_SM, !Z        ; yes

                ; No submenu: Standard behavior
                MOVE    OPTM_DATA, R6           ; already selected?
                MOVE    @R6, R6
                ADD     OPTM_IR_STDSEL, R6
                MOVE    @R6, R6
                ADD     R2, R6
                MOVE    R6, R7                  ; remember R6 for later
                CMP     0, @R6
                RBRA    _OPTM_RUN_6D, Z         ; no: not selected

                ; yes: selected: is it a single-select item?
                MOVE    R1, R6                  ; R1: ptr. to OPTM_IR_GROUPS 
                ADD     R2, R6                  ; R2: sel. item in flat coord
                MOVE    @R6, R8                 ; remember @R6 for later
                MOVE    @R6, R6                 ; do not destroy original data
                AND     OPTM_SINGLESEL, R6      ; ..by the AND command but use
                CMP     0, R6                   ; ..a scratch register instead
                RBRA    _OPTM_RUN_SEL, Z        ; is multi select: ignore key

                ; yes: selected item has been selected again and yes, it is a
                ; single-select item, so we need to treat it differently:
                ; we need to flip its state (unselect), remove the selection
                ; indicator on screen and notify the listener by calling
                ; the callback function
                MOVE    0, @R7                  ; unselect single-select item
                                                ; in memory

                MOVE    R8, R12                 ; R8 still contains group id

                MOVE    OPTM_X, R9              ; R9: x-coord
                MOVE    @R9, R9
                ADD     1, R9
                MOVE    OPTM_Y, R10             ; R10: y-coord
                MOVE    @R10, R10
                MOVE    R2, R8                  ; transform R2 from flat..
                RSUB    _OPTM_R_F2M, 1          ; ..to relative to (sub)menu
                RBRA    _OPTM_R_FATAL, C        ; failed? fatal!                
                ADD     R8, R10
                ADD     1, R10
                MOVE    R11, @--SP              ; save R11
                MOVE    OPTM_MENULEVEL, R11     ; R11: (sub)menu level, 0=main
                MOVE    @R11, R11
                MOVE    OPTM_FP_PRINTXY, R7     ; delete marker at current pos
                MOVE    _OPTM_RUN_SPCE, R8      ; R8: use space char to delete            
                RSUB    _OPTM_CALL, 1           ; ..on screen
                MOVE    @SP++, R11              ; restore R11

                MOVE    R12, R8                 ; restore group id
                XOR     R9, R9
                MOVE    R11, R10                ; selection key
                MOVE    OPTM_CLBK_SEL, R7       ; call callback
                RSUB    _OPTM_CALL, 1
                
                RBRA    _OPTM_RUN_SEL, 1        ; continue main loop of menu

                ; proceed in case of multi-sel. with the not yet selected item
_OPTM_RUN_6D    MOVE    OPTM_DATA, R6           ; R6: selected group
                MOVE    @R6, R6
                ADD     OPTM_IR_GROUPS, R6
                MOVE    @R6, R6
                MOVE    R6, R5                  ; R5: remember group start
                ADD     R2, R6                  ; use current selection to ..
                MOVE    @R6, R6                 ; .. find the selected group

                ; single select items
                MOVE    R6, R4
                AND     OPTM_SINGLESEL, R4      ; single-select item?
                RBRA    _OPTM_RUN_16, Z         ; no: proceed as multi-select
                MOVE    OPTM_SSMS, R12          ; yes: set single-select flag
                MOVE    2, @R12
                MOVE    OPTM_X, R9              ; R9: x-coord
                MOVE    @R9, R9
                ADD     1, R9                
                RBRA    _OPTM_RUN_9, 1  

                ; deselect all other group members on screen (and inside the
                ; OPTM_IR_STDSEL array in case that it resides in RAM)
_OPTM_RUN_16    MOVE    OPTM_SSMS, R12          ; Flag on stack: multi-select
                MOVE    0, @R12
                MOVE    OPTM_DATA, R12          ; R12: OPTM_IR_STDSEL ptr
                MOVE    @R12, R12
                ADD     OPTM_IR_STDSEL, R12
                MOVE    @R12, R12
                XOR     R4, R4                  ; R4: loop var
                MOVE    OPTM_X, R9              ; R9: x-coord
                MOVE    @R9, R9
                ADD     1, R9
                XOR     R10, R10                ; R10: flat list item pos

_OPTM_RUN_7     CMP     R4, R0                  ; R4 < R0 (size of structure)
                RBRA    _OPTM_RUN_9, Z          ; no
                CMP     @R5++, R6               ; current entry group member?
                RBRA    _OPTM_RUN_8, !Z         ; no

                MOVE    OPTM_TEMP, R8           ; save R10
                MOVE    R10, @R8

                MOVE    R10, R8                 ; transform flat lst itm pos..
                RSUB    _OPTM_R_F2M, 1          ; ..into relative list pos..
                RBRA    _OPTM_R_FATAL, C        ; failed? fatal!                
                MOVE    OPTM_Y, R7              ; ..and then..
                ADD     @R7, R8                 ; transform into screen coord
                ADD     1, R8                   ; add 1 because of top frame
                MOVE    R8, R10                 ; R10: OPTM_FP_PRINTXY y coord

                MOVE    OPTM_FP_PRINTXY, R7     ; delete marker at current pos
                MOVE    R11, @--SP              ; save R11            
                MOVE    OPTM_MENULEVEL, R11     ; R11: current (sub)menu level
                MOVE    @R11, R11
                MOVE    0, @R12
                MOVE    _OPTM_RUN_SPCE, R8      ; R8: use space char to delete
                RSUB    _OPTM_CALL, 1

                MOVE    @SP++, R11              ; restore R11
                MOVE    OPTM_TEMP, R8           ; restore R10
                MOVE    @R8, R10

_OPTM_RUN_8     ADD     1, R10                  ; y-pos + 1
                ADD     1, R4                   ; loop-var + 1
                ADD     1, R12                  ; stdsel-ptr + 1
                RBRA    _OPTM_RUN_7, 1

                ; select active group member on screen (and inside the
                ; OPTM_IR_STDSEL array in case that it resides in RAM)
_OPTM_RUN_9     MOVE    OPTM_Y, R10
                MOVE    @R10, R10
                ADD     1, R10
                MOVE    R2, R8                  ; transform R2 from flat..
                RSUB    _OPTM_R_F2M, 1          ; ..coords to (sub)menu coords
                RBRA    _OPTM_R_FATAL, C        ; failed? fatal!                
                ADD     R8, R10
                MOVE    OPTM_DATA, R8
                MOVE    @R8, R8
                ADD     OPTM_IR_SEL, R8
                MOVE    OPTM_SSMS, R7           ; single select flag
                ADD     @R7, R8
                MOVE    R11, @--SP              ; save R11
                XOR     R11, R11                ; R11=0: show main menu
                MOVE    OPTM_FP_PRINTXY, R7
                RSUB    _OPTM_CALL, 1
                MOVE    @SP++, R11              ; restore R11
                MOVE    OPTM_DATA, R12          ; R12: OPTM_IR_STDSEL ptr
                MOVE    @R12, R12
                ADD     OPTM_IR_STDSEL, R12
                MOVE    @R12, R12
                ADD     R2, R12
                MOVE    1, @R12

                ; call the callback function, but first find out which element
                ; within the group has been selected
_OPTM_RUN_10    MOVE    OPTM_DATA, R8
                MOVE    @R8, R8
                ADD     OPTM_IR_GROUPS, R8
                MOVE    @R8, R8
                XOR     R9, R9                  ; R9: selection within group
                XOR     R10, R10                ; R10: selection counter
_OPTM_RUN_11    CMP     @R8, R6                 ; find first occurance
                RBRA    _OPTM_RUN_12, Z         ; found!
                ADD     1, R8
                ADD     1, R10
                RBRA    _OPTM_RUN_11, 1
_OPTM_RUN_12    CMP     R10, R2                 ; selection found?
                RBRA    _OPTM_RUN_14, Z         ; yes
                CMP     @R8++, R6               ; are we within the group?
                RBRA    _OPTM_RUN_13, !Z        ; no
                ADD     1, R9                   ; yes: increase relative pos
_OPTM_RUN_13    ADD     1, R10                  ; increase absolute pos
                RBRA    _OPTM_RUN_12, 1

_OPTM_RUN_14    MOVE    R6, R8                  ; R8: return selected group
                                                ; R9: return sel. item in grp
                INCRB                           ; if we reach this code and..
                MOVE    R8, R0                  ; ..it is a single-select..
                AND     OPTM_SINGLESEL, R0      ; ..item then it is an active
                RBRA    _OPTM_RUN_15, Z         ; ..item and therefore we set
                MOVE    1, R9                   ; ..R9 to 1
_OPTM_RUN_15    DECRB                
                MOVE    R11, R10                ; R10: selection key
                MOVE    OPTM_CLBK_SEL, R7       ; call callback
                RSUB    _OPTM_CALL, 1

                CMP     OPTM_CLOSE, R6          ; Close?
                RBRA    _OPTM_RUN_SEL, !Z       ; no: continue menu loop
                MOVE    R2, R8                  ; yes: return selected item               

_OPTM_RUN_RET   MOVE    OPTM_STRUCT, R7         ; important to reset to zero..
                MOVE    0, @R7                  ; b/c it is also used as flag

                ADD     R0, SP                  ; restore SP / free memory
                ADD     3, SP
                MOVE    R8, @--SP               ; carry R8 over the LEAVE bump
                SYSCALL(leave, 1)
                MOVE    @SP++, R8

                RET

                ; ------------------------------------------------------------
                ; Switch menu level (enter/leave submenu)
                ; ------------------------------------------------------------

_OPTM_RUN_SM    MOVE    OPTM_MENULEVEL, R9

                ; Find out: Which submenu level are we talking about
                MOVE    SP, R8                  ; R8: ptr. to submenu struct.
                ADD     3, R8
                ADD     R2, R8                  ; R2: current selection
                MOVE    @R8, R8
                AND     0x7FFF, R8              ; R8: (sub)menu number

                ; Are we entering or leaving a (sub)menu?
                MOVE    @R6, R7                 ; R7: selected group item
                AND     OPTM_CLOSE, R7          ; leave submenu?
                RBRA    _OPTM_RUN_SM_1, Z       ; no: enter submenu

                ; Leave submenu
_OPTM_RUN_SM_L  MOVE    0, @R9                  ; 0=main menu
                MOVE    OPTM_MAINSEL, R8
                MOVE    @R8, R2                 ; restore main menu selection
                RBRA    _OPTM_RUN_SM_4, 1       ; execute level change

                ; Enter submenu
_OPTM_RUN_SM_1  MOVE    R8, @R9                 ; R8: submenu number
                MOVE    OPTM_MAINSEL, R8        ; remember main menu selection
                MOVE    R2, @R8

                ; Calculate the menu item that will be selected
_OPTM_RUN_SM_2  ADD     1, R2                   ; next item
                CMP     R0, R2                  ; error condition?
                RBRA    _OPTM_RUN_SM_3, Z       ; yes
                ADD     1, R6                   ; no error
                MOVE    @R6, R7
                AND     0x00FF, R7              ; selectable item?
                RBRA    _OPTM_RUN_SM_2, Z       ; no: continue to search
                RBRA    _OPTM_RUN_SM_4, 1

                ; Fatal: No selectable menu item found
_OPTM_RUN_SM_3  MOVE    OPTM_CLBK_FATAL, R7
                MOVE    OPTM_F_NOSEL, R8
                XOR     R9, R9
                RBRA    _OPTM_CALL, 1           ; RBRA because of fatal

                ; Execute the (sub)menu level change
_OPTM_RUN_SM_4  ADD     R0, SP                  ; restore SP / free memory
                ADD     3, SP
                RSUB    OPTM_SHOW, 1            ; redraw
                MOVE    R2, @--SP               ; carry R2 over the LEAVE bump
                SYSCALL(leave, 1)
                MOVE    @SP++, R8               ; R8: selected menu item
                RBRA    OPTM_RUN, 1             ; restart _OPTM_RUN

                ; Menu index not found in currently active (sub)menu level
_OPTM_R_FATAL   MOVE    OPTM_CLBK_FATAL, R7
                MOVE    R8, R9
                MOVE    OPTM_F_MENUIDX, R8
                RBRA    _OPTM_CALL, 1           ; RBRA because of fatal

_OPTM_RUN_SPCE  .ASCII_W " "

; ----------------------------------------------------------------------------
; OPTM_SELECT: Selects a menu item using the OPTM_SEL_* constants. Use this
; instead of directly calling OPTM_FP_SELECT, since OPTM_FP_SELECT does not
; do coordinate translation.
;
; Input:
;  R8: Index of menu item / cursor position in flat coordinates
;  R9: OPTM_SEL_* constant
;
; Output:
;  R8: Unchanged: Position in flat coordinates
;
; Semantics of "index" / "cursor position" in R8: It is the position within
; OPTM_ITEMS and OPTM_GROUPS (both from config.vhd), i.e. R8 considers the
; menu to be a big flat list without submenus.
; ----------------------------------------------------------------------------

OPTM_SELECT     SYSCALL(enter, 1)

                MOVE    OPTM_F_MS_SLCT, R9
                RSUB    _OPTM_R_F2M_O, 1        ; convert R8 to screen coord.

                ; Select menu item
                MOVE    OPTM_FP_SELECT, R7      ; select line
                MOVE    OPTM_SEL_SEL, R9        ; R8 contains screen coords.
                RSUB    _OPTM_CALL, 1

                SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; OPTM_SET: Sets or unsets a menu item "from the outside", i.e. while
; OPTM_RUN is running. If you call this function without OPTM_RUN beeing
; active, then the system goes fatal.
;
; Input:
;  R8: Index of menu item / cursor position in flat coordinates
;  R9: 0=unset / 1=set
;
; Output:
;  R8/R9: Unchanged
;  R10: Unchanged if the menu item was a single-select item and in case of the
;       menu item was a menu group: index of menu item that was de-selected
;       because within a group alway only one item can be selected
;
; Semantics of "index" / "cursor position" in R8: It is the position within
; OPTM_ITEMS and OPTM_GROUPS (both from config.vhd), i.e. R8 considers the
; menu to be a big flat list without submenus.
; ----------------------------------------------------------------------------

OPTM_SET        SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: menu index
                MOVE    R9, R1                  ; R1: mode
                MOVE    0xFFFF, R12             ; R12: flag means single-sel.

                ; Find out if this is a single-select menu item
                ; or a menu group: Store the result in R2 and remember
                ; the menu group id (without flags) in R3
                MOVE    OPTM_DATA, R2
                MOVE    @R2, R2
                ADD     OPTM_IR_GROUPS, R2
                MOVE    @R2, R2
                ADD     R0, R2
                MOVE    @R2, R2
                MOVE    R2, R3                  ; R3: men grp id w/o flags
                AND     0x00FF, R3
                AND     OPTM_SINGLESEL, R2      ; R2=0|1 0=singlesel, 1=multi
                RBRA    _OPTM_SET_1A, Z
                MOVE    1, R2

                ; Update menu data structure which is in flat coordinates:
                ; Step #1: Set new value
                ; Step #2: In case of menu group: unset old value
                ;
                ; Step #1
_OPTM_SET_1A    MOVE    OPTM_DATA, R8
                MOVE    @R8, R8
                ADD     OPTM_IR_STDSEL, R8
                MOVE    @R8, R8
                ADD     R0, R8                  ; R0 contains menu index
                MOVE    R1, @R8                 ; set new value

                ; Step #2: How to unset the old value:
                ; a) Skip everything here in case we have a single-select item
                ; b) Since the menu group items can be spread all over the
                ;    menu: Iterate through the menu and set the one group item
                ;    that belongs to the newly to be selected one (R3) to zero
                ;    that is currently set but that is not the current one
                ;    (R0). We can stop as soon as we have set one item
                ;    to zero because there is only one item active at a time
                ;    in any menu group
                CMP     1, R2                   ; single-select?
                RBRA    _OPTM_SET_S, Z          ; yes: skip unselect step

                CMP     0, R9                   ; if menu grp then unsetting..
                RBRA    _OPTM_SET_1B, !Z        ; ..is not allowed..
                MOVE    OPTM_CLBK_FATAL, R7     ; ..so we go fatal
                MOVE    OPTM_F_MENUGRP2, R8
                XOR     R9, R9
                RBRA    _OPTM_CALL, 1

_OPTM_SET_1B    MOVE    OPTM_DATA, R4           ; R4: menu size
                MOVE    @R4, R4
                ADD     OPTM_IR_SIZE, R4
                MOVE    @R4, R4
                MOVE    OPTM_DATA, R5           ; R5: iterator through menu..
                MOVE    @R5, R5                 ; ..groups
                ADD     OPTM_IR_GROUPS, R5
                MOVE    @R5, R5
                XOR     R6, R6                  ; R6: counter
                MOVE    OPTM_DATA, R7           ; R7: item selected?
                MOVE    @R7, R7
                ADD     OPTM_IR_STDSEL, R7
                MOVE    @R7, R7

_OPTM_SET_1C    CMP     R6, R0                  ; skip currently selected item
                RBRA    _OPTM_SET_1D, Z
                MOVE    @R5, R8
                AND     0x00FF, R8              ; remove flags from men group
                CMP     R8, R3                  ; current item belongs to R3?
                RBRA    _OPTM_SET_1D, !Z        ; no
                CMP     1, @R7                  ; is it selected?
                RBRA    _OPTM_SET_1D, !Z        ; no

                ; We now need to unselect the item at three "locations"
                ; 1. Within the OPTM_IR_STDSEL memory structure
                ; 2. Maybe somewhere else, so for this case return it in R10
                ; 3. On screen (will be done in) _OPTM_SET_2
                MOVE    0, @R7                  ; unselect in OPTM_IR_STDSEL
                MOVE    R6, R12                 ; return index in R10 via R12
                RBRA    _OPTM_SET_S, 1          ; leave loop and proceed

_OPTM_SET_1D    ADD     1, R5                   ; next menu group item
                ADD     1, R6                   ; increment counter
                ADD     1, R7                   ; next "is-selected?" item
                CMP     R6, R4                  ; done?
                RBRA    _OPTM_SET_1C, !Z        ; no: iterate

                MOVE    OPTM_CLBK_FATAL, R7
                MOVE    OPTM_F_MENUGRP, R8      ; if we land here then somethg
                MOVE    R3, R9                  ; went wrong: go fatal
                RBRA    _OPTM_CALL, 1

                ; Transform the menu index from flat coordinates to
                ; screen coordinates
_OPTM_SET_S     MOVE    R0, R8
                MOVE    OPTM_F_MS_SET1, R9
                RSUB    _OPTM_R_F2M_O, 1
                RBRA    _OPTM_SET_R, C          ; idx outside curr. (sub)menu
                MOVE    R8, R0

                ; Have either the menu-select character or a space
                ; character in R8, so that OPTM_FP_PRINTXY prints the
                ; right character depending on R1 
                MOVE    OPTM_FP_PRINTXY, R7
                MOVE    OPTM_STR_SPACE, R8      ; R8 = space (unset)
                CMP     0, R1
                RBRA    _OPTM_SET_2, Z

                AND     0xFFFD, SR              ; clear X
                SHL     1, R2                   ; R2 is now either 0 or 2
                MOVE    OPTM_DATA, R8           ; R8: menu-select char
                MOVE    @R8, R8
                ADD     OPTM_IR_SEL, R8
                ADD     R2, R8

_OPTM_SET_2     MOVE    OPTM_X, R9              ; R9: x-pos
                MOVE    @R9, R9
                ADD     1, R9                   ; x-pos on screen b/c frame
                MOVE    OPTM_Y, R10             ; R10: y-pos
                MOVE    @R10, R10
                ADD     R0, R10                 ; add menu index
                ADD     1, R10                  ; y-pos on screen b/c frame
                RSUB    _OPTM_CALL, 1

                CMP     0xFFFF, R12             ; single-select item?
                RBRA    _OPTM_SET_R, Z          ; yes: skip

                ; remove old selection of menu group on screen (step #2.b.3)
                MOVE    R12, R8                 ; transform flat to scr coords
                MOVE    OPTM_F_MS_SET2, R9
                RSUB    _OPTM_R_F2M_O, 1
                RBRA    _OPTM_SET_3, !C
                MOVE    OPTM_CLBK_FATAL, R7     ; we must never land here
                MOVE    OPTM_F_MENUGRP3, R8
                MOVE    R12, R9
                RBRA    _OPTM_CALL, 1
_OPTM_SET_3     MOVE    OPTM_Y, R10
                MOVE    @R10, R10
                ADD     R8, R10                 ; flt to scr transf. coord
                ADD     1, R10
                MOVE    OPTM_STR_SPACE, R8
                MOVE    OPTM_X, R9
                MOVE    @R9, R9
                ADD     1, R9
                RSUB    _OPTM_CALL, 1
_OPTM_SET_R     MOVE    R12, @--SP              ; bring R0 over "leave" "hump"
                SYSCALL(leave, 1)

                ; only change R10 in case of a menu group
                INCRB
                MOVE    @SP++, R0
                CMP     0xFFFF, R0
                RBRA    _OPTM_SET_RR, Z
                MOVE    R0, R10
_OPTM_SET_RR    DECRB

                RET

; ----------------------------------------------------------------------------
; Internal helper functions
; ----------------------------------------------------------------------------                

; call function stored in initialization record
; R7: Function pointer ID (see above)
; R8..R12 input/output parameters
_OPTM_CALL      MOVE    R7, @--SP               ; save R7 for usage & restore

                ; find function pointer
                MOVE    OPTM_DATA, R7           ; local variable with ptr         
                MOVE    @R7, R7                 ; get info record ptr
                ADD     @SP, R7                 ; find correct record element
                MOVE    @R7, R7                 ; get function address
                ASUB    R7, 1                   ; call function

                MOVE    @SP++, R7               ; restore R7
                RET

; Create an array that represents the menu structure: The lower 15-bits (i.e.
; bits 0..14) of each item in the array is a number and represents one menu
; item. A zero represents that this item is located on the main menu level and
; any integer value represents that this item is located in a certain submenu
; (counting from one).
;
; The highest bit (bit 15) is 1, when the entry is shown in the current menu
; level indicated by OPTM_MENULEVEL, otherwise it is 0. There is a special
; case around the very first entry of a sub-menu structure: If we are in the
; main menu (OPTM_MENULEVEL is 0) then we treat the very first entry of the
; sub-menu structure as the "headline"/"label" of the sub-menu, i.e. it needs
; to be shown in the menu menu (bit 15 is 1). If we are within a sub-menu,
; then this very first line is being ignored (bit 15 is 0).
;
; Input:
;   R8: pointer to a memory region that is as large as all items together
;   R9: amount of menu items
; Output:
;   R8: unchanged
;   R9: amount of items in currently active menu level
_OPTM_STRUCT    INCRB

                MOVE    R8, R0                  ; R0: current array element
                MOVE    R9, R1                  ; R1: amount of menu items
                MOVE    OPTM_DATA, R2           ; R2: OPTM_IR_GROUPS array
                MOVE    @R2, R2
                ADD     OPTM_IR_GROUPS, R2
                MOVE    @R2, R2
                XOR     R3, R3                  ; R3: current main/submen id
                MOVE    1, R4                   ; R4: next submen id
                XOR     R5, R5                  ; R5: submenu region flag

                MOVE    R1, @R0++               ; 1st element = size

_OPTM_STRUCT_1  MOVE    @R2++, R6               ; R6: next menu group item
                AND     OPTM_SUBMENU, R6        ; check for submenu marker
                RBRA    _OPTM_STRUCT_3, Z       ; jump, if no submenu marker

                CMP     1, R5                   ; are we already in a region?
                RBRA    _OPTM_STRUCT_2, Z       ; yes: jump
                MOVE    1, R5                   ; no: set region flag
                MOVE    R4, R3                  ; current submen id = next..
                ADD     1, R4                   ; ..submen id and inc. next
                RBRA    _OPTM_STRUCT_3, 1       ; continue with storing

_OPTM_STRUCT_2  MOVE    R3, @R0++               ; store item in struct array
                XOR     R5, R5                  ; clear region flag
                XOR     R3, R3                  ; current id = main menu
                RBRA    _OPTM_STRUCT_4, 1       ; continue with next iteration

_OPTM_STRUCT_3  MOVE    R3, @R0++               ; store item in struct array
_OPTM_STRUCT_4  SUB     1, R1                   ; more menu items?
                RBRA    _OPTM_STRUCT_1, !Z      ; yes: loop

                CMP     1, R5                   ; no: region cntr still actve?
                RBRA    _OPTM_STRUCT_C, !Z      ; no: all good: continue
                MOVE    OPTM_CLBK_FATAL, R7     ; yes: fatal
                MOVE    OPTM_F_MENUSUB, R8
                XOR     R9, R9
                RBRA    _OPTM_CALL, 1           ; RBRA because of fatal

_OPTM_STRUCT_C  MOVE    R9, R0                  ; R0: size of menu (#items)
                MOVE    R8, R1                  ; R1: current array entry
                ADD     1, R1                   ; skip size information
                MOVE    OPTM_MENULEVEL, R3      ; R3: current menu level
                MOVE    @R3, R3
                XOR     R7, R7                  ; R7: count active menu items

_OPTM_STRUCT_5  CMP     R3, @R1                 ; are we in the curr. men. lvl
                RBRA    _OPTM_STRUCT_7, Z       ; yes: set to 1 and next entry
_OPTM_STRUCT_6  AND     0x7FFF, @R1++           ; no: highest bit = 0 and next
                RBRA    _OPTM_STRUCT_8, 1
_OPTM_STRUCT_7  OR      0x8000, @R1++           ; active itm: highest bit to 1
                ADD     1, R7                   ; one more active item
_OPTM_STRUCT_8  SUB     1, R0                   ; more entries?
                RBRA    _OPTM_STRUCT_5, !Z      ; yes: iterate

                MOVE    R9, R4                  ; R4: preserve overall amount
                MOVE    R7, R9                  ; return amount of active itms

                ; Correct for the special case described above: In the case
                ; that we are in main menu, the first item is part of the
                ; list and otherwise it is not.
                XOR     R1, R1                  ; R1: last menu number
                MOVE    1, R5                   ; R5: first occurance flag
                MOVE    R8, R7                  ; R7: ptr. to curr. itm in lst
                ADD     1, R7                   ; skip size info
_OPTM_STRUCT_9  MOVE    @R7, R6
                AND     0x00FF, R6
                CMP     R1, R6                  ; last menu number changed?
                RBRA    _OPTM_STRUCT_10, Z      ; no
                MOVE    R6, R1                  ; yes: store this num as last
                MOVE    1, R5                   ; set first occurance flag

_OPTM_STRUCT_10 MOVE    @R7, R6
                AND     0x8000, R6              ; part of current list?
                RBRA    _OPTM_STRUCT_11, !Z     ; yes

                CMP     0, R3                   ; are we in the main menu?
                RBRA    _OPTM_STRUCT_12, !Z     ; no
                CMP     1, R5                   ; yes: and is it first ocurr.?
                RBRA    _OPTM_STRUCT_12, !Z     ; no
                XOR     R5, R5                  ; yes: delete flag and..
                OR      0x8000, @R7             ; ..make it part of the list
                ADD     1, R9                   ; one more active item
                RBRA    _OPTM_STRUCT_12, 1

_OPTM_STRUCT_11 CMP     0, R3                   ; are we in the main menu?
                RBRA    _OPTM_STRUCT_12, Z      ; yes: move on
                CMP     1, R5                   ; no: and is it first ocurr.?
                RBRA    _OPTM_STRUCT_12, !Z     ; no
                XOR     R5, R5                  ; yes: delete flag and..
                AND     0x7FFF, @R7             ; ..remove it from the list
                SUB     1, R9                   ; one less active item         

_OPTM_STRUCT_12 ADD     1, R7                   ; next list element
                SUB     1, R4                   ; one less item to process
                RBRA    _OPTM_STRUCT_9, !Z

                DECRB
                RET

; _OPTM_R_F2M
;
; Converts a position relative to OPTM_ITEMS or OPTM_GROUPS (starting from 0)
; to a position relative to the currently active (sub)menu
;
; Input:  R8 as flat position
; Output: R8 as position relative to the currently active (sub)menu
;         Carry=0 means: OK transformation worked
;         Carry=1 means: Flat pos. not part of the currently active (sub)menu
;
; Helper subroutine for _OPTM_RUN that expects the stack to be set-up like
; described above. We need to add +1 to the SP because we are in a subroutine.
;
; CAUTION: If we ever refactor this and _OPTM_R_F2M leads to stack
; modifications, for example by calling subroutines via RSUB or SYSCALL then
; we also need to adjust _OPTM_R_F2M_O.
_OPTM_R_F2M     INCRB

                MOVE    SP, R0                  ; R0: size of current (sub)men
                ADD     1, R0
                MOVE    @R0, R0
                MOVE    SP, R1                  ; R1: (sub)menu structure
                ADD     3, R1                   ; R1 now points to size info
                MOVE    R8, R2                  ; R2: flat input position
                XOR     R3, R3                  ; R3: relative output position
                XOR     R4, R4                  ; R4: loop counter
                MOVE    OPTM_DATA, R5           ; R5: flat menu: overall size
                MOVE    @R5, R5
                ADD     OPTM_IR_SIZE, R5
                MOVE    @R5, R5

                ; Check for corrupt memory layout: Is R8 (aka R2) larger than
                ; the size of the current (sub)menu allows? We need to
                ; subtract 1 from the size of the current (sub)menu in R6
                ; because R8 starts to count from zero.
                MOVE    @R1++, R6
                SUB     1, R6
                CMP     R2, R6
                RBRA    _OPTM_R_F2M_1, !N       ; all good: continue
                MOVE    OPTM_CLBK_FATAL, R7     ; otherwise: fatal
                MOVE    OPTM_F_F2M, R8
                MOVE    R2, R9
                RBRA    _OPTM_CALL, 1           ; RBRA because of fatal

_OPTM_R_F2M_1   MOVE    @R1++, R6               ; check bit 15
                SHL     1, R6                   ; cur strct item=cur active?
                RBRA    _OPTM_R_F2M_2, !C       ; no: next item
                CMP     R4, R2                  ; flat position reached?
                RBRA    _OPTM_R_F2M_OK, Z       ; yes: return
                ADD     1, R3                   ; increase rel. pos.
_OPTM_R_F2M_2   ADD     1, R4                   ; increase abs. pos
                CMP     R4, R5                  ; end of data structure?
                RBRA    _OPTM_R_F2M_1, !Z       ; no: iterate
                OR      0x0004, SR              ; yet: set carry and leave
                RBRA    _OPTM_R_F2M_R, 1

_OPTM_R_F2M_OK  AND     0xFFFB, SR              ; clear carry
_OPTM_R_F2M_R   MOVE    R3, R8                  ; return relative output pos.

                DECRB
                RET

; Call _OPTM_R_F2M "from the outside", i.e. the structure stored on the stack
; will be used (OPTM_STRUCT) and also the existing stack will be protected
; Input:  R8: menu index (flat coordinates), just like _OPTM_R_F2M
;         R9: error code for potential fatal
; Output: R8: screen coordinates, just like _OPTM_R_F2M
;         R9: unchanged
_OPTM_R_F2M_O   INCRB

                MOVE    R8, R1                  ; R1: menu index / flat
                MOVE    OPTM_STRUCT, R2         ; R2: pointer to menu struct.
                MOVE    @R2, R2

                ; check for valid OPTM_STRUCT
                RBRA    _OPTM_R_F2M_O1, !Z      ; valid: continue
                MOVE    OPTM_CLBK_FATAL, R7     ; invalid: fatal
                MOVE    OPTM_F_MSTRUCT, R8      ; and R9 contains error code
                RBRA    _OPTM_CALL, 1           ; RBRA because of fatal

                ; check for valid stack: R2 needs to be larger than the
                ; currrent stack pointer, because R2 was put on the stack
                ; earlier and the stack pointer always decreases
_OPTM_R_F2M_O1  CMP     R2, SP
                RBRA    _OPTM_R_F2M_O2, N       ; yes: R2 > SP
                MOVE    OPTM_CLBK_FATAL, R7     ; no: fatal
                MOVE    OPTM_F_MSTRUCT, R8
                MOVE    OPTM_F_MS_SELF, R9
                RBRA    _OPTM_CALL, 1

                ; We need to save the current return address on the stack
                ; right before R2 because when setting the SP to R2, RSUB
                ; will internally put the return address on the stack and
                ; therefore overwrite something. After the call to _OPTM_R_F2M
                ; we restore the stack
_OPTM_R_F2M_O2  MOVE    R2, R7
                MOVE    @--R7, @--SP
                MOVE    SP, R0                  ; remember stack
                MOVE    R2, SP                  ; setup stack like in OPTM_RUN
                RSUB    _OPTM_R_F2M, 1          ; do the coord. transformation
                MOVE    R0, SP                  ; restore stack
                MOVE    @SP++, @R7              ; restore overwritten ret addr

                DECRB
                RET
