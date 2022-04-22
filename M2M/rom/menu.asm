; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Options Menu
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Special values for OPTM_IR_GROUPS
; ----------------------------------------------------------------------------

OPTM_CLOSE      .EQU 0x00FF                     ; menu item that closes menu
OPTM_HEADLINE   .EQU 0x1000                     ; AND mask: headline/title itm
OPTM_SINGLESEL  .EQU 0x8000                     ; AND mask: single select item

; ----------------------------------------------------------------------------
; Option Menu key codes (to be returned by the function in OPTM_FP_GETKEY)
; ----------------------------------------------------------------------------

OPTM_KEY_UP     .EQU 1
OPTM_KEY_DOWN   .EQU 2
OPTM_KEY_SELECT .EQU 3                          ; normally this is Return
OPTM_KEY_CLOSE  .EQU 4
OPTM_KEY_SELALT .EQU 5                          ; normally this is Space

; ----------------------------------------------------------------------------
; Action codes for the OPTM_FP_SELECT function
; ----------------------------------------------------------------------------

OPTM_SEL_STD    .EQU 0
OPTM_SEL_SEL    .EQU 1
OPTM_SEL_TLL    .EQU 2
OPTM_SEL_TLLSEL .EQU 3

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
OPTM_FP_PRINT   .EQU 2

; Like print but contains target x|y coords in R9|R10
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

; Waits until one of the four Option Menu keys is pressed
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

; multi-selection character + zero-terminator, after that:
; single-selection character + zero-terminator, total: 4 words in length!
OPTM_IR_SEL     .EQU 9

; amount of menu items: the length of the arrays to which OPTM_IR_GROUPS,
; OPTM_IR_DEFAULT and OPTM_IR_LINES point needs to be equal to this amount
OPTM_IR_SIZE    .EQU 13

; pointer to string containing the menu items and separating them with \n
OPTM_IR_ITEMS   .EQU 14

; array of digits that define and group menu items,
; 0xEEEE automatically closes the menu when selected by the user
; 0x8xxx denotes single-select menu items
OPTM_IR_GROUPS  .EQU 15

; array of 0s and 1s to define menu items that are activated by default
; in case this array is located in RAM, these are the advantages (but it
; can without problems also be located in ROM): the menu remembers the
; various multi- and single selections, if any and the menu prevents calling
; the callback function for already selected items
OPTM_IR_STDSEL  .EQU 16

; array of 0s and 1s to define horizontal separator lines
OPTM_IR_LINES   .EQU 17

; size of initialization record in words
OPTM_STRUCTSIZE .EQU 18

OPTM_NL         .DW  0x005C, 0x006E, 0x0000     ; \n

; ----------------------------------------------------------------------------
; Options Menu functions
; ----------------------------------------------------------------------------

; Initialize data structures needed for the menu
; R8: pointer to initialization record
; R9:  x-coord
; R10: y-coord
; R11: width
; R12: height
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
                MOVE    OPTM_CUR_SEL, R0
                MOVE    0, @R0
                MOVE    OPTM_SSMS, R0
                MOVE    0, @R0
                DECRB
                RET

; Show menu: Draw frame and fill it with the menu items
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
                MOVE    OPTM_DATA, R4           ; R4: groups (single-select)
                MOVE    @R4, R4
                ADD     OPTM_IR_GROUPS, R4
                MOVE    @R4, R4

                MOVE    OPTM_FP_CLEAR, R7       ; clear VRAM
                RSUB    _OPTM_CALL, 1

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
                MOVE    R0, R8
                MOVE    OPTM_FP_PRINT, R7       ; print menu
                RSUB    _OPTM_CALL, 1

                ; ------------------------------------------------------------
                ; Highlight Headlines/Titles
                ; ------------------------------------------------------------

                INCRB                           ; protect R0..R7

                MOVE    OPTM_DATA, R0
                MOVE    @R0, R0
                ADD     OPTM_IR_GROUPS, R0
                MOVE    @R0, R0                 ; bit flag: #12 in menu group
                XOR     R1, R1
                MOVE    OPTM_DATA, R2           ; amount of menu items
                MOVE    @R2, R2
                ADD     OPTM_IR_SIZE, R2
                MOVE    @R2, R2
_OPTM_TT_0      MOVE    @R0++, R3

                AND     OPTM_HEADLINE, R3
                RBRA    _OPTM_TT_1, Z           ; flag not set: continue

                ; flag is set, so print the menu item in highlighted mode
                MOVE    OPTM_FP_SELECT, R7
                MOVE    R1, R8
                MOVE    OPTM_SEL_TLL, R9
                RSUB    _OPTM_CALL, 1

                ; iterate
_OPTM_TT_1      ADD     1, R1
                CMP     R1, R2                  ; end of menu structure?
                RBRA    _OPTM_TT_0, !Z          ; no: continue

                DECRB                           ; restore R0..R7

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

                ; loop through the string, char by char and interpret \n as
                ; newline (i.e. increment the index of the menu item)
                XOR     R5, R5                  ; R5 = index of menu item
                MOVE    R0, R7                  ; R7 = start of current str
_OPTM_HM_0      CMP     0, @R0                  ; end of string reached?
                RBRA    _OPTM_SHOW_0, Z         ; yes
                CMP     0x005C, @R0             ; search newline: backslash
                RBRA    _OPTM_HM_1, !Z          ; no
                ADD     1, R0                   ; skip character
                CMP     'n', @R0                ; "\n" found?
                RBRA    _OPTM_HM_1, !Z          ; no
                ADD     1, R0                   ; skip character
                MOVE    R0, R7                  ; R7 starts from the new line
                ADD     1, R5                   ; next index of menu item
                RBRA    _OPTM_HM_0, 1                

                ; search for %s in the string
_OPTM_HM_1      CMP     '%', @R0                ; search for "%s"
                RBRA    _OPTM_HM_2, !Z          ; no
                ADD     1, R0                   ; skip character
                CMP     's', @R0                ; "%s" found?
                RBRA    _OPTM_HM_2, !Z          ; no
                ADD     1, R0                   ; skip character

                ; Extract from R7 (start of current string) to \n and provide
                ; this string and the index to the callback function. This
                ; is done by copying the segment on the stack.
                ;
                ; Per definition, each line must end with a \n, so if we do
                ; not find a \n then this means there is an error in
                ; config.vhd, so we kind of gracefully exit the %s handling
                ; and continue with tagging the menu items
                MOVE    R0, R8                  ; search from behind the %s
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
                RSUB    _OPTM_CALL, 1

                MOVE    @SP++, R7               ; restore ptr

                ADD     R6, SP                  ; restore stack
                ADD     1, R5                   ; next line
                MOVE    R7, R0                  ; next part of original string
                ADD     R6, R0
                MOVE    R0, R7
                ADD     1, R7

                ; continue to search for %s
_OPTM_HM_2      ADD     1, R0
                RBRA    _OPTM_HM_0, 1 

                ; ------------------------------------------------------------
                ; Tag selected menu items and draw lines
                ; ------------------------------------------------------------

_OPTM_SHOW_0    MOVE    OPTM_DATA, R0           ; R0: string to be printed
                MOVE    @R0, R0
                ADD     OPTM_IR_ITEMS, R0
                MOVE    @R0, R0

                MOVE    OPTM_X, R5              ; R5: current x-pos
                MOVE    @R5, R5
                ADD     1, R5
                MOVE    1, R6                   ; R6: current y-pos

                XOR     R0, R0                  ; R0: iteration position
_OPTM_SHOW_1    CMP     R0, R1                  ; R0 < R1 (start from 0)
                RBRA    _OPTM_SHOW_RET, Z       ; end reached
                CMP     0, @R2++                ; show select. at this point?
                RBRA    _OPTM_SHOW_2, Z         ; no
                MOVE    OPTM_DATA, R8           ; yes: print selection here
                MOVE    @R8, R8

                ADD     OPTM_IR_SEL, R8         ; decide: single or multi-sel.
                MOVE    @R4, R7
                AND     OPTM_SINGLESEL, R7
                RBRA    _OPTM_SHOW_1A, Z        ; multi-select
                ADD     2, R8                   ; single-select

_OPTM_SHOW_1A   MOVE    R5, R9
                MOVE    R6, R10
                MOVE    OPTM_FP_PRINTXY, R7
                RSUB    _OPTM_CALL, 1

_OPTM_SHOW_2    CMP     0, @R3++                ; horiz. line here?
                RBRA    _OPTM_SHOW_3, Z         ; no
                MOVE    R6, R8                  ; yes: R8: y-pos of line
                MOVE    OPTM_FP_LINE, R7
                RSUB    _OPTM_CALL, 1

_OPTM_SHOW_3    ADD     1, R6                   ; next y-pos
                ADD     1, R0                   ; next menu item
                ADD     1, R4                   ; next single/multi sel. info
                RBRA    _OPTM_SHOW_1, 1

_OPTM_SHOW_RET  SYSCALL(leave, 1)
                RET

; Runs menu and returns results
; Input
;   R8: Default cursor position/selection
; Output
;   R8: Selected cursor position
;   plus: Will callback to OPTM_CLBK_SEL (see above) on each press
;         of the selection key
OPTM_RUN        SYSCALL(enter, 1)

                MOVE    OPTM_DATA, R0           ; R0: size of data structure
                MOVE    @R0, R0
                ADD     OPTM_IR_SIZE, R0
                MOVE    @R0, R0
                MOVE    OPTM_DATA, R1           ; R1: menu item groups
                MOVE    @R1, R1
                ADD     OPTM_IR_GROUPS, R1
                MOVE    @R1, R1
                MOVE    R8, R2                  ; R2: selected item
                MOVE    R2, R3                  ; R3: old selected item

_OPTM_RUN_SEL   MOVE    OPTM_FP_SELECT, R7      ; select line
                MOVE    R2, R8                  ; R8: selected item
                MOVE    OPTM_SEL_SEL, R9
                RSUB    _OPTM_CALL, 1
                MOVE    OPTM_CUR_SEL, R8        ; remember for ext. routines..
                MOVE    R2, @R8                 ; to be able to process it

                MOVE    OPTM_FP_GETKEY, R7      ; get next keypress
                RSUB    _OPTM_CALL, 1

                CMP     OPTM_KEY_UP, R8         ; key: up?
                RBRA    _OPTM_RUN_3, !Z         ; no: check other key
_OPTM_RUN_1     CMP     0, R2                   ; yes: wrap around at top?
                RBRA    _OPTM_KU_NWA, !Z        ; no: find next menu item
                MOVE    R0, R2                  ; yes: wrap around
_OPTM_KU_NWA    SUB     1, R2                   ; one element up
                MOVE    R1, R6                  ; find next menu item: descnd.
                ADD     R2, R6
                MOVE    @R6, R6
                AND     0x00FF, R6              ; mask flags such as headline
                CMP     0, R6                   ; menu item found?
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on
                RBRA    _OPTM_RUN_1, 1          ; no: continue searching

_OPTM_RUN_2     MOVE    OPTM_FP_SELECT, R7      ; unselect old item
                MOVE    R3, R8
                MOVE    OPTM_SEL_STD, R9
                RSUB    _OPTM_CALL, 1
                MOVE    R2, R3                  ; remember current item as old
                RBRA    _OPTM_RUN_SEL, 1

_OPTM_RUN_3     CMP     OPTM_KEY_DOWN, R8       ; key: down?
                RBRA    _OPTM_RUN_5, !Z         ; no: check other key
_OPTM_RUN_4     MOVE    R0, R7                  ; yes: wrap around at bottom?
                SUB     1, R7
                CMP     R7, R2
                RBRA    _OPTM_KD_NWA, !Z        ; no: find next menu item
                MOVE    0xFFFF, R2              ; yes: wrap around
_OPTM_KD_NWA    ADD     1, R2                   ; one element down
                MOVE    R1, R6                  ; find next menu item: ascend.
                ADD     R2, R6
                MOVE    @R6, R6
                AND     0x00FF, R6              ; mask out headline flag
                CMP     0, R6                   ; menu item found?
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on
                RBRA    _OPTM_RUN_4, 1          ; no: continue searching

_OPTM_RUN_5     CMP     OPTM_KEY_CLOSE, R8      ; key: close?
                RBRA    _OPTM_RUN_6A, !Z        ; no: check other key
                MOVE    R2, R8                  ; return selected item
                RBRA    _OPTM_RUN_RET, 1

_OPTM_RUN_6A    CMP     OPTM_KEY_SELECT, R8     ; key: select?
                RBRA    _OPTM_RUN_6B, !Z
                RBRA    _OPTM_RUN_6C, 1
_OPTM_RUN_6B    CMP     OPTM_KEY_SELALT, R8
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

                MOVE    OPTM_DATA, R6           ; already selected?
                MOVE    @R6, R6
                ADD     OPTM_IR_STDSEL, R6
                MOVE    @R6, R6
                ADD     R2, R6
                MOVE    R6, R7                  ; remember R6 for later
                CMP     0, @R6
                RBRA    _OPTM_RUN_6D, Z         ; no: not selected

                ; yes: selected: is it a single-select item?
                MOVE    OPTM_DATA, R6
                MOVE    @R6, R6
                ADD     OPTM_IR_GROUPS, R6
                MOVE    @R6, R6
                ADD     R2, R6
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

                MOVE    R8, @--SP               ; R8 still contains group id

                MOVE    _OPTM_RUN_SPCE, R8      ; R8: use space char to delete
                MOVE    OPTM_X, R9              ; R9: x-coord
                MOVE    @R9, R9
                ADD     1, R9
                MOVE    OPTM_Y, R10             ; R10: y-coord
                MOVE    @R10, R10
                ADD     R2, R10
                ADD     1, R10
                MOVE    OPTM_FP_PRINTXY, R7     ; delete marker at current pos
                RSUB    _OPTM_CALL, 1           ; ..on screen

                MOVE    @SP++, R8               ; group id
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
                MOVE    _OPTM_RUN_SPCE, R8      ; R8: use space char to delete
                MOVE    OPTM_X, R9              ; R9: x-coord
                MOVE    @R9, R9
                ADD     1, R9
                MOVE    OPTM_Y, R10             ; R10: y-coord
                MOVE    @R10, R10
                ADD     1, R10
_OPTM_RUN_7     CMP     R4, R0                  ; R4 < R0 (size of structure)
                RBRA    _OPTM_RUN_9, Z          ; no
                CMP     @R5++, R6               ; current entry group member?
                RBRA    _OPTM_RUN_8, !Z         ; no
                MOVE    OPTM_FP_PRINTXY, R7     ; delete marker at current pos
                MOVE    0, @R12
                RSUB    _OPTM_CALL, 1
_OPTM_RUN_8     ADD     1, R10                  ; y-pos + 1
                ADD     1, R4                   ; loop-var + 1
                ADD     1, R12                  ; stdsel-ptr + 1
                RBRA    _OPTM_RUN_7, 1

                ; select active group member on screen (and inside the
                ; OPTM_IR_STDSEL array in case that it resides in RAM)
_OPTM_RUN_9     MOVE    OPTM_Y, R10
                MOVE    @R10, R10
                ADD     1, R10
                ADD     R2, R10
                MOVE    OPTM_DATA, R8
                MOVE    @R8, R8
                ADD     OPTM_IR_SEL, R8
                MOVE    OPTM_SSMS, R7           ; single select flag
                ADD     @R7, R8
                MOVE    OPTM_FP_PRINTXY, R7
                RSUB    _OPTM_CALL, 1
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
                MOVE    R11, R10                ; R10: selection key
                MOVE    OPTM_CLBK_SEL, R7       ; call callback
                RSUB    _OPTM_CALL, 1

                CMP     OPTM_CLOSE, R6          ; Close?
                RBRA    _OPTM_RUN_SEL, !Z       ; no: continue menu loop
                MOVE    R2, R8                  ; yes: return selected item               

_OPTM_RUN_RET   MOVE    R8, @--SP               ; carry R8 over the LEAVE bump
                SYSCALL(leave, 1)
                MOVE    @SP++, R8
                RET

_OPTM_RUN_SPCE  .ASCII_W " "

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
