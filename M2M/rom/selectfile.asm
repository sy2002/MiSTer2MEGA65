; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; File selector including directory browser
;
; Expects that an on-screen-display is already active and uses the facilities
; of screen.asm for displaying everything. The file selectfile.asm needs the
; environment of shell.asm.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Main routine: SELECT_FILE
; 
; Runs the whole file selection and directory browsing user experience and
; returns a string pointer to the filename.
;
; Input: This function needs a lot of context to run:
;   * HANDLE_DEV needs to be valid.
;   * Expects FB_STACK to be initialized (as well as the stack itself)
;   * B_STACK_SIZE needs to contain the correct number
;   * SD_WAIT needs to be defined (.EQU) and SD_CYC_MID & SD_CYC_HI need
;     to contain the initial cycle counter values
;   * SD_WAIT_DONE needs to be initialized to zero for the very first start
;     of the system and after each reset
;   * SF_CONTEXT needs to be set (defined in sysdef.asm as CTX_* constant)
; Output:
;   R8: Pointer to filename (zero terminated string), if R9=0
;   R9: 0=OK (no error)
;       1=SD card changed (this is no error, but need re-mounting)
;       2=Cancelled via Run/Stop
;       3=Filter filtered everything, see CMSG_BROWSENOTHING in sysdef.asm
; ----------------------------------------------------------------------------

SELECT_FILE     SYSCALL(enter, 1)

                ; stack handling
                MOVE    FB_MAINSTACK, R0        ; remember the original stack
                MOVE    SP, @R0
                MOVE    FB_STACK, R0
                MOVE    @R0, SP                 ; restore the own stack

                ; Perform the SD card "stability" workaround (see shell.asm)
                RSUB    SCR$CLRINNER, 1
                MOVE    STR_INITWAIT, R8
                RSUB    SCR$PRINTSTR, 1         ; Show "Please wait"-message
                RSUB    WAIT_FOR_SD, 1
                RSUB    SCR$CLRINNER, 1

                ; if we already have run the browser before, then let us
                ; continue where we left off
_S_CONT_CHECK   MOVE    FB_HEAD, R10
                MOVE    @R10, R10
                RBRA    _S_BROWSE_START, !Z

                ; retrieve default file browsing start path from config.vhd
                ; DIRBROWSE_READ expects the start path in R9
_S_START        MOVE    M2M$RAMROM_DEV, R9
                MOVE    M2M$CONFIG, @R9
                MOVE    M2M$RAMROM_4KWIN, R9
                MOVE    M2M$CFG_DIR_START, @R9
                MOVE    M2M$RAMROM_DATA, R9

                ; load sorted directory list into memory
                MOVE    HANDLE_DEV, R8
_S_CD_AND_READ  MOVE    FB_HEAP, R10            ; start address of heap
                MOVE    @R10, R10
                MOVE    HEAP_SIZE, R11          ; maximum memory available
                                                ; for storing the linked list
                MOVE    FILTER_FILES, R12       ; filter unwanted files
                RSUB    DIRBROWSE_READ, 1       ; read directory content
                CMP     0, R11                  ; errors?
                RBRA    _S_SAVE_FB_HEAD, Z      ; no
                CMP     1, R11                  ; error: path not found?
                RBRA    _S_ERR_PNF, Z
                CMP     2, R11                  ; max files? (only warn)
                RBRA    _S_WRN_MAX, Z
                RBRA    _S_ERR_UNKNOWN, 1

                ; default path not found, try root instead
_S_ERR_PNF      ADD     1, SP                   ; see comment in shell.asm
                MOVE    FN_ROOT_DIR, R9         ; try root
                MOVE    FB_HEAP, R10
                MOVE    @R10, R10
                MOVE    HEAP_SIZE, R11
                RSUB    DIRBROWSE_READ, 1
                CMP     0, R11
                RBRA    _S_SAVE_FB_HEAD, Z
                CMP     2, R11
                RBRA    _S_WRN_MAX, Z

                ; unknown error: end (TODO: we might want to retry in future)
_S_ERR_UNKNOWN  MOVE    ERR_BROWSE_UNKN, R8
                MOVE    R11, R9
                RBRA    FATAL, 1

                ; warn, that we are not showing all files
_S_WRN_MAX      MOVE    WRN_MAXFILES, R8        ; print warning message
                RSUB    SCR$PRINTSTR, 1
_S_WRN_WAIT     RSUB    HANDLE_IO, 1            ; IO handling (e.g. vdrives)
                MOVE    M2M$KEYBOARD, R8
                AND     M2M$KEY_SPACE, @R8
                RBRA    _S_WRN_WAIT, !Z         ; wait for space; low-active
                RSUB    SCR$CLRINNER, 1         ; clear inner part of window

                ; remember the head of the linked-list of the current dir.
_S_SAVE_FB_HEAD MOVE    FB_HEAD, R8
                MOVE    R10, @R8

                ; ------------------------------------------------------------
                ; DIRECTORY BROWSER
                ; ------------------------------------------------------------

_S_BROWSE_START MOVE    R10, R3                 ; R3: currently visible head

                ; how much items are there in the current directory?
                MOVE    R3, R8
                RSUB    SLL$LASTNCOUNT, 1
                MOVE    R10, R1                 ; R1: amount of items in dir.
                RBRA    _S_NOTHING, Z           ; no items in directory
                MOVE    SCR$OSM_M_DY, R2        ; R2: max rows on screen
                MOVE    @R2, R2
                SUB     2, R2                   ; (frame is 2 rows high)

                MOVE    @SP++, R4               ; R4: currently selected ..
                                                ; ..line relative to window ..
                                                ; ..but on the stack is the..
                                                ; ..absolute value

                XOR     R5, R5                  ; R5: counts the amount of ..
                                                ; ..files that have been shown

                XOR     R6, R6                  ; R6: absolute index of curr..
                                                ; selected file/dir


                ; Determine the current window and convert the absolute value
                ; in R4 into a relative value: R4 is the relative cursor
                ; position in the current window. Store the absolute value in
                ; R6 and make sure that we iterate the linked-list to the
                ; right point so that the user can continue where he left off.
                ;
                ; Case 1: If the max rows on screen (R2) are larger than the
                ; absolute index of the last selected cursor pos (which starts
                ; at 0 and is stored in R4) then we know that we are in window
                ; zero and the absolute index equals the relative index,
                ; i.e. R6 = R4.
                ;
                ; Case 2: Otherwise, we will need to iterate through the
                ; linked list. For avoiding other complexities, we want to
                ; show the selected item at the position denoted by an
                ; integer division (aka window/screen) and modulo (aka
                ; position within the screen):
                ; R4 (abs. index) div R2 (window size) = number of window
                ; R4 mod R2 = position within the window
                ; R5 (amt. of shown files) = (R4 div R2) + R2

                ; Case 1
                CMP     R2, R4                  ; R2 > R4
                RBRA    _S_BROWSE_C2, !N        ; no: we are in case 2
                MOVE    R4, R6                  ; absolute idx = rel. idx
                MOVE    1, R7                   ; R7: we are in case 1
                RBRA    _S_BROWSE_LOG, 1

                ; Case 2
_S_BROWSE_C2    MOVE    2, R7                   ; R7: we are in case 2
                MOVE    R4, R8                  ; R4: absolute index
                MOVE    R2, R9                  ; R2: max rows on screen
                SYSCALL(divu, 1)                ; R10=R4 div R2
                MOVE    R11, R4                 ; R4 =R4 mod R2: cursor pos

                MOVE    R10, R8                 ; R8: window to be shown
                                                ; R9: max rows on screen
                SYSCALL(mulu, 1)                ; R10=R8*R9: items to iterate

                MOVE    R10, R6
                ADD     R4, R6                  ; R6: updated absolute index

                MOVE    R10, R5
                ADD     R2, R5                  ; R5 =(R4 div R2) + R2
                CMP     R5, R1                  ; is R5 larger than total num?
                RBRA    _S_BROWSE_S1, !N        ; no: proceed

                ; correct R10 so that the last page does not underflow, R5
                ; so that is has the correct amount of displayed items and
                ; R4 so that the correct line is selected
                SUB     R1, R5                  ; R5 is now the underflow amt
                SUB     R5, R10                 ; reduce linked-list start
                ADD     R5, R4                  ; correct cursor position
                MOVE    R1, R5                  ; tuck R5 to total # of items

_S_BROWSE_S1    MOVE    R3, R8                  ; R8: linked-list head
                MOVE    1, R9                   ; R9=1 means iterate forward
                                                ; R10: items to iterate
                RSUB    SLL$ITERATE, 1          ; iterate to element
                CMP     0, R11                  ; error?
                RBRA    _S_BROWSE_S2, !Z        ; no: proceed            
                MOVE    ERR_FATAL_ITER, R8      ; yes: fatal error and halt
                XOR     R9, R9
                RBRA    FATAL, 1

_S_BROWSE_S2    MOVE    R11, R3                 ; R3: use new head

_S_BROWSE_LOG   MOVE    LOG_STR_ITM_AMT, R8     ; log amount of items in ..
                SYSCALL(puts, 1)                ; .. current directory to UART
                MOVE    R1, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; list (maximum one screen of) directory entries
_S_DRAW_DIRLIST RSUB    SCR$CLRINNER, 1
                MOVE    R3, R8                  ; R8: pos in LL to show list
                MOVE    R2, R9                  ; R9: amount if lines to show
                RSUB    SHOW_DIR, 1             ; print directory listing         

                CMP     1, R7                   ; are we in case 1?
                RBRA    _S_SELECT_LOOP, !Z      ; no: proceed
                ADD     R10, R5                 ; R5: overall # of files shown
                XOR     R7, R7                  ; "no case" from here on

_S_SELECT_LOOP  MOVE    R4, R8                  ; invert currently sel. line
                MOVE    M2M$SA_COL_STD_INV, R9
                RSUB    SELECT_LINE, 1

                ; non-blocking mechanism to read keys from the MEGA65 keyboard
_S_INPUT_LOOP   RSUB    HANDLE_IO, 1            ; IO handling (e.g. vdrives)
                RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1
                CMP     0, R8                   ; has a key been pressed?
                RBRA    _IL_KEYPRESSED, !Z      ; yes: handle key press

                ; check, if the SD card changed in the meantime
                MOVE    SD_CHANGED, R8
                CMP     1, @R8
                RBRA    _S_INPUT_LOOP, !Z       ; SD card did not change
                MOVE    0, @R8                  ; reset change-flag            

                ; SD card changed
_S_SD_CHANGED   RSUB    WAIT1SEC, 1             ; debounce SD insert process
                XOR     R8, R8                  ; do not return any filename
                MOVE    1, R9                   ; R9=1: SD card changed
                RBRA    _S_RET, 1

                ; handle keypress
_IL_KEYPRESSED  CMP     M2M$KEY_UP, R8          ; cursor up: prev file
                RBRA    _IL_CUR_UP, Z
                CMP     M2M$KEY_DOWN, R8        ; cursor down: next file
                RBRA    _IL_CUR_DOWN, Z
                CMP     M2M$KEY_LEFT, R8        ; cursor left: previous page
                RBRA    _IL_CUR_LEFT, Z
                CMP     M2M$KEY_RIGHT, R8       ; cursor right: next page
                RBRA    _IL_CUR_RIGHT, Z
                CMP     M2M$KEY_RETURN, R8      ; return key
                RBRA    _IL_KEY_RETURN, Z
                CMP     M2M$KEY_RUNSTOP, R8     ; Run/Stop key
                RBRA    _IL_KEY_RUNSTOP, Z
                CMP     M2M$KEY_F1, R8          ; F1 key: internal SD card
                RBRA    _IL_KEY_F1_F3, Z
                CMP     M2M$KEY_F3, R8          ; F3 key: external SD card
                RBRA    _IL_KEY_F1_F3, Z
                RBRA    _S_INPUT_LOOP, 1        ; unknown key

                ; CURSOR UP has been pressed
_IL_CUR_UP      CMP     R4, 0                   ; > 0?
                RBRA    _IL_CUR_UP_CHK, !N      ; no: check if need to scroll
                MOVE    R4, R8                  ; yes: deselect current line
                MOVE    M2M$SA_COL_STD, R9
                RSUB    SELECT_LINE, 1
                SUB     1, R4                   ; one line up
                SUB     1, R6
                RBRA    _S_SELECT_LOOP, 1       ; select new line and continue
_IL_CUR_UP_CHK  CMP     R5, R2                  ; # shown > max rows on scr.?
                RBRA    _S_INPUT_LOOP, !N       ; no: do not scroll; ign. key
                MOVE    -1, R9                  ; R9: iterate backward
                MOVE    1, R10                  ; R10: scroll by one element
                RBRA    _SCROLL, 1              ; scroll, then input loop

                ; CURSOR DOWN has been pressed: next file
_IL_CUR_DOWN    MOVE    R1, R8                  ; R1: amount of items in dir..
                SUB     1, R8                   ; ..-1 as we count from zero
                CMP     R4, R8                  ; R4 = R1 (bottom reached?)
                RBRA    _S_INPUT_LOOP, Z        ; yes: ignore key press
                MOVE    R2, R8                  ; R2: max rows on screen..
                SUB     1, R8                   ; ..-1 as we count from zero
                CMP     R4, R8                  ; R4 = R1: scrolling needed?
                RBRA    _IL_SCRL_DN, Z          ; yes: scroll down
                MOVE    R4, R8                  ; no: deselect current line
                MOVE    M2M$SA_COL_STD, R9
                RSUB    SELECT_LINE, 1
                ADD     1, R4                   ; one line down
                ADD     1, R6
                RBRA    _S_SELECT_LOOP, 1       ; select new line and continue

                ; scroll down by iterating the currently visible head of the
                ; SLL by 1 step; if this is not possible: do not scroll,
                ; because we reached the end of the list
_IL_SCRL_DN     CMP     R5, R1                  ; all items already shown?
                RBRA    _S_INPUT_LOOP, Z        ; yes: ignore key press
                MOVE    1, R9                   ; R9: iterate forward
                MOVE    1, R10                  ; R10: scroll by one element
                RBRA    _SCROLL, 1              ; scroll, then input loop

                ; CURSOR LEFT has been pressed: previous page
                ; check if amount of entries shown minus the amount
                ; of entries on the screen is larger than zero; if yes, then
                ; go back one page; if no then go back to the very first entry
_IL_CUR_LEFT    MOVE    R5, R8                  ; R8: entries shown
                SUB     R2, R8                  ; R2: max entries on screen
                RBRA    _IL_GOTO_TOP, N         ; if < 0 then no scroll
                CMP     R8, R2                  ; R8 > max entries on screen?
                RBRA    _IL_PAGE_DEFUP, N       ; yes: scroll one page up
                MOVE    R8, R10                 ; no: move the residual up..
                RBRA    _IL_PAGE_UP, !Z         ; .. if it is > 0
_IL_GOTO_TOP    XOR     R6, R6                  ; abs. index to the very top
                XOR     R8, R8
                RBRA    _IL_GOTO, 1             ; .. else go to the very top
_IL_PAGE_DEFUP  MOVE    R2, R10                 ; R10: one page up
_IL_PAGE_UP     MOVE    -1, R9                  ; R9: iterate backward
                RBRA    _SCROLL, 1              ; scroll, then input loop

                ; CURSOR RIGHT has been pressed: next page
                ; first: check if amount of entries in the directory minus
                ; the amount of files already shown is larger than zero;
                ; if not, then we are already showing all files
                ; second: check if this difference is larger than the maximum
                ; amount of files that we can show on one screen; if yes
                ; then scroll by one screen, if no then scroll by exactly this
                ; difference
_IL_CUR_RIGHT   MOVE    R1, R8                  ; R8: entries in current dir.
                SUB     R5, R8                  ; R5: # of files already shown
                RBRA    _IL_GOTO_BOTTOM, Z      ; no more files: ignore key
                CMP     R8, R2                  ; R8 > max rows on screen?
                RBRA    _IL_PAGE_DEFDN, N       ; yes: scroll one page down
                MOVE    R8, R10                 ; R10: remaining elm. down
                RBRA    _IL_PAGE_DN, 1
_IL_PAGE_DEFDN  MOVE    R2, R10                 ; R10: one page down
_IL_PAGE_DN     MOVE    1, R9                   ; R9: iterate forward
                RBRA    _SCROLL, 1              ; scroll, then input loop
_IL_GOTO_BOTTOM MOVE    R1, R6                  ; update abs. index: amnt of..
                SUB     1, R6                   ; ..files minus 1 is new index
                CMP     R1, R2                  ; amt files <= max rows scr?
                RBRA    _IL_GOTO_BTTM2, N       ; no: select max rows - 1
                MOVE    R6, R8                  ; max amount of files..
                RBRA    _IL_GOTO, 1
_IL_GOTO_BTTM2  MOVE    R2, R8                  ; max rows on screen..
                SUB     1, R8                   ; ..minus 1 b/c cntng from 0
                RBRA    _IL_GOTO, 1

                ; this code segment is used by all four scrolling modes:
                ; up/down and page up/page down; it is meant to called via
                ; RBRA and not via RSUB because it will return
                ; to _S_DRAW_DIRLIST
                ;
                ; iterates forward or backward depending on R9 being +1 or -1
                ; the iteration amount if given in R10
                ; if the element is not found, then a fatal error is raised
                ; destroys the value of R10
_SCROLL         MOVE    R3, R8                  ; R8: currently visible head
                                                ; R9: iteration direction
                                                ; R10: iteration amount
                RSUB    SLL$ITERATE, 1          ; find element
                CMP     0, R11                  ; found element?
                RBRA    _SCROLL_DO, !Z          ; yes: continue
                MOVE    ERR_FATAL_ITER, R8      ; no: fatal error and halt
                XOR     R9, R9
                RBRA    FATAL, 1
_SCROLL_DO      ADD     R12, R6                 ; R6: abs. index; R12 signed
                CMP     -1, R9                  ; negative iteration dir.?
                RBRA    _SCROLL_DO2, !Z         ; no: continue
                XOR     R3, R3                  ; yes: inverse sign of R10
                SUB     R10, R3
                MOVE    R3, R10
_SCROLL_DO2     MOVE    R11, R3                 ; new visible head
                ADD     R10, R5                 ; R10 more/less visible files
                RBRA    _S_DRAW_DIRLIST, 1      ; redraw directory list

                ; this code segment is used by page up/page down in case
                ; the selection cursor needs to be moved to the very top
                ; or the very bottom: target position is in R8
                ; R4 is used throughout this whole routine as sel. curs. pos.
_IL_GOTO        MOVE    R8, @--SP
                MOVE    R4, R8                  ; deselect current entry
                MOVE    M2M$SA_COL_STD, R9
                RSUB    SELECT_LINE, 1
                MOVE    @SP++, R4               ; select new entry
                MOVE    R4, R8
                MOVE    M2M$SA_COL_STD_INV, R9
                RSUB    SELECT_LINE, 1
                RBRA    _S_INPUT_LOOP, 1

                ; browsing interrupted by Run/Stop:
                ; remember where we are and exit
_IL_KEY_RUNSTOP MOVE    R6, @--SP               ; rem. abs itm idx for cursor

                XOR     R8, R8                  ; do not return any filename
                MOVE    2, R9                   ; R9=2: Run/Stop
                RBRA    _S_RET, 1

                ; let the user switch SD cards: F1=internal / F3=external
_IL_KEY_F1_F3   MOVE    0, R9                   ; R9 = chosen SD card, 0=int
                CMP     M2M$KEY_F3, R8
                RBRA    _IL_SD_INT, !Z          ; not F3: skip
                MOVE    M2M$CSR_SD_ACTIVE, R9   ; R9 = external SD card
_IL_SD_INT      MOVE    SD_ACTIVE, R10          ; curr. active equ. keypress?
                CMP     @R10, R9
                RBRA    _S_INPUT_LOOP, Z        ; yes: ignore keypress

                MOVE    SD_CHANGED, R11         ; SD card change flag
                MOVE    0, @R11                 ; reset SD card changed flag

                MOVE    M2M$CSR, R9             ; switch sd mode to manual
                OR      M2M$CSR_SD_MODE, @R9
                CMP     M2M$KEY_F3, R8          ; F3: switch to external
                RBRA    _IL_SD_INT2, !Z
                OR      M2M$CSR_SD_FORCE, @R9
                MOVE    M2M$CSR_SD_ACTIVE, @R10 ; remember new active: ext.
                RBRA    _S_SD_CHANGED, 1

_IL_SD_INT2     AND     M2M$CSR_UN_SD_FORCE, @R9 ; F1: switch to internal
                MOVE    0, @R10                 ; remember new active: int
                RBRA    _S_SD_CHANGED, 1

                ; "Return" has been pressed: change directory or return
                ; the filename of the selected file.
                ; Iterate the linked list: find the currently seleted element
_IL_KEY_RETURN  MOVE    R3, R8                  ; R8: currently visible head
                MOVE    1, R9                   ; R9: iterate forward
                MOVE    R4, R10                 ; R10: iterate by R4 elements
                RSUB    SLL$ITERATE, 1          ; find element
                CMP     0, R11                  ; found element?
                RBRA    _ELEMENT_FOUND, !Z      ; yes: continue
                MOVE    ERR_FATAL_ITER, R8      ; no: fatal error and halt
                XOR     R9, R9
                RBRA    FATAL, 1

                ; depending on if a directory of a file was selected:
                ; change directory or load data; we therefore need to
                ; find the flag that contains the info "directory" or "file"
_ELEMENT_FOUND  MOVE    R11, R8                 ; R11: selected SLL element
                ADD     SLL$DATA_SIZE, R8
                MOVE    @R8, R9
                MOVE    R11, R8
                ADD     SLL$OVRHD_SIZE, R8
                ADD     R9, R8
                CMP     0, @--R8                ; 0=file, 1=directory
                RBRA    _RETNAME, Z             ; return name

                ; change directory
                MOVE    R4, R8                  ; deselect current line
                MOVE    M2M$SA_COL_STD, R9
                RSUB    SELECT_LINE, 1
                MOVE    LOG_STR_CD, R8          ; log directory change to UART
                SYSCALL(puts, 1)
                RSUB    SCR$CLRINNER, 1         ; clear inner part of frame
                ADD     SLL$DATA, R11
                ADD     1, R11                  ; remove < from name
                MOVE    R11, R8                 ; remove > from name
                SYSCALL(strlen, 1)
                ADD     R9, R8
                SUB     1, R8
                MOVE    0, @R8
                MOVE    R11, R8                 ; R8: clean directory name
                SYSCALL(puts, 1)                ; log it to UART
                SYSCALL(crlf, 1)

                MOVE    FN_UPDIR, R9            ; are we going one dir. up?
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _CHANGEDIR, Z           ; yes: get crsr pos from stack

                MOVE    R6, @--SP               ; rem. abs itm idx for cursor
                MOVE    0, @--SP                ; ..and new dir. starts at 0

_CHANGEDIR      MOVE    R8, R9                  ; use this directory
                MOVE    HANDLE_DEV, R8
                RBRA    _S_CD_AND_READ, 1       ; create new linked-list

_RETNAME        MOVE    R6, @--SP               ; rem. abs itm idx for cursor

                ADD     SLL$DATA, R11
                MOVE    R11, R8                 ; R8: file name
                XOR     R9, R9                  ; R9=0: all OK, no error

_S_RET          ; stack handling
                MOVE    FB_STACK_INIT, R0       ; R0: initial pos of local st.
                MOVE    FB_STACK, R1            ; R1: current pos of local st.
                MOVE    SP, @R1                 ; make local stack persistent                
                MOVE    FB_MAINSTACK, R2        ; R2: global stack position
       
                MOVE    @R0, R3                 ; check for stack overflow
                SUB     @R1, R3
                ADD     2, R3                   ; two additional words given..
                                                ; ..during initialization..
                                                ; ..can lead to "-1" or "-2"..
                                                ; ..when stack is dirty, so..
                                                ; ..compensate this
                CMP     B_STACK_SIZE, R3        ; local st. size > actual use?
                RBRA    _S_RET_1, N             ; yes: all good

                ; stack overflow
                MOVE    ERR_FATAL_BSTCK, R8
                MOVE    R3, R9
                RBRA    FATAL, 1

                ; stack OK: return
                ; caution: label _S_RET_1 is also used by _S_NOTHING
_S_RET_1        MOVE    @R2, SP                 ; restore global stack

                MOVE    R8, @--SP               ; bring R8, R9 over "leave"
                MOVE    R9, @--SP
                SYSCALL(leave, 1)
                MOVE    @SP++, R9
                MOVE    @SP++, R8
                RET

                ; Handle the situation: The filter function did filter
                ; everything, so there is nothing here to browse
_S_NOTHING      MOVE    CMSG_BROWSENOTHING, R8  ; situation
                MOVE    SF_CONTEXT, R9          ; context
                MOVE    @R9, R9
                RSUB    CUSTOM_MSG, 1           ; callback fn. in m2m-rom.asm

                CMP     0, R8
                RBRA    _S_NOTHING_1, !Z        ; custom msg available in R8
                MOVE    WRN_EMPTY_BRW, R8       ; use standard message

_S_NOTHING_1    RSUB    SCR$CLRINNER, 1
                RSUB    SCR$PRINTSTR, 1         ; print warning message
_S_NOTHING_2    RSUB    HANDLE_IO, 1            ; IO handling (e.g. vdrives)
                MOVE    M2M$KEYBOARD, R8
                AND     M2M$KEY_SPACE, @R8
                RBRA    _S_NOTHING_2, !Z        ; wait for space; low-active
_S_NOTHING_3    RSUB    HANDLE_IO, 1
                MOVE    M2M$KEYBOARD, R8
                AND     M2M$KEY_SPACE, @R8
                RBRA    _S_NOTHING_3, Z         ; wait for released space

                XOR     R8, R8                  ; do not return any filename
                MOVE    3, R9                   ; R9=3: CMSG_BROWSENOTHING
                MOVE    FB_MAINSTACK, R2        ; R2: global stack position
                RBRA    _S_RET_1, 1

; ----------------------------------------------------------------------------
; Initialize file browser persistence variables
; ----------------------------------------------------------------------------

FB_INIT         INCRB

                MOVE    FB_HEAD, R0             ; no active head of file brws.
                MOVE    0, @R0

                MOVE    SF_CONTEXT, R0          ; no context
                MOVE    0, @R0

                DECRB
                RET

; use re-init when the local stack is already initialized; for example in
; re-mount situations due to SD card changes
FB_RE_INIT      INCRB

                RSUB    FB_INIT, 1

                MOVE    FB_STACK_INIT, R0
                MOVE    @R0, R0
                MOVE    0, @--R0                ; see comment in shell.asm
                MOVE    0, @--R0
                MOVE    FB_STACK, R1
                MOVE    R0, @R1

                DECRB
                RET

; ----------------------------------------------------------------------------
; Show directory listing
;
; Input:
;   R8: position inside the directory linked-list from which to show it
;   R9: maximum amount of entries to show
; Output:
;  R10: amount of entries shown
; ----------------------------------------------------------------------------

SHOW_DIR        INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                INCRB

                SUB     1, R9                   ; we start counting from 0
                XOR     R0, R0                  ; R0: amount of entries shown

_SHOWDIR_L      MOVE    R8, R1                  ; R1: ptr to next LL element
                ADD     SLL$NEXT, R1
                ADD     SLL$DATA, R8            ; R8: entry name
                XOR     R7, R7                  ; R7: flag: clean up stack?

                ; replace the end part of a too long string by "..."
                MOVE    SCR$OSM_M_DX, R2
                MOVE    @R2, R2
                SUB     2, R2                   ; R2: max stringlen to display
                MOVE    R9, R4                  ; save R9 to restore it later
                SYSCALL(strlen, 1)
                MOVE    R9, R3                  ; R3: length of current item
                MOVE    R4, R9                  ; restore R9: # items to show
                CMP     R3, R2                  ; current length > max strlen?
                RBRA    _SHOWDIR_PRINT, !N      ; R3 <= R2: print items
                MOVE    SP, R4                  ; save SP to restore it later
                MOVE    R9, R5                  ; save R9 to restore it later
                SUB     R3, SP                  ; reserve strlen
                SUB     1, SP                   ; .. including zero-terminator
                MOVE    SP, R9                  ; modified entry name
                SYSCALL(strcpy, 1)

                MOVE    R9, R8                  ; R8: modified item name
                MOVE    R5, R9                  ; restore R9: # items to show               
                MOVE    R8, R5
                ADD     R2, R5
                SUB     3, R5                   ; hardcoded len of FN_ELLIPSIS
                                                ; plus zero-terminator
                MOVE    FN_ELLIPSIS, R6
                MOVE    @R6++, @R5++            ; hardcoded len of FN_ELLIPSIS
                MOVE    @R6++, @R5++            ; TODO: switch to strcpy..
                MOVE    @R6++, @R5++            ; .. as of QNICE V1.7
                MOVE    0, @R5
                MOVE    1, R7                   ; flag to clean up stack

                ; for performance reasons: do not output to UART
                ; if you need to debug: delete "SCR" in the following
                ; two function calls to use the dual-output routines
_SHOWDIR_PRINT  RSUB    SCR$PRINTSTR, 1         ; print dirname/filename
                MOVE    NEWLINE, R8
                RSUB    SCR$PRINTSTR, 1

                CMP     0, R7                   ; clean up stack?
                RBRA    _SHOWDIR_NOCLN, Z       ; no: go on
                MOVE    R4, SP                  ; yes: clean up stack

_SHOWDIR_NOCLN  ADD     1, R0
                CMP     R0, R9                  ; shown <= maximum?
                RBRA    _SHOWDIR_RET, N         ; no: leave
_SHOWDIR_NEXT   MOVE    @R1, R8                 ; more entries available?
                RBRA    _SHOWDIR_L, !Z          ; yes: loop

_SHOWDIR_RET    MOVE    R0, R10                 ; return # of entries shown
                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                DECRB
                RET

; ----------------------------------------------------------------------------
; Change the attribute of the line in R8 to R9
; R8 is considered as "inside the window", i.e. screenrow = R8 + 1
; ----------------------------------------------------------------------------

SELECT_LINE     SYSCALL(enter, 1)

                MOVE    R9, R0
                ADD     1, R8                   ; calculate attrib RAM offset
                MOVE    SCR$OSM_M_DX, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)
                ADD     1, R10                  ; screenpos in RAM

                MOVE    M2M$RAMROM_DEV, R8      ; attribute RAM
                MOVE    M2M$VRAM_ATTR, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    0, @R8
                MOVE    M2M$RAMROM_DATA, R8

                ADD     R10, R8                 ; start position in RAM

                MOVE    SCR$OSM_M_DX, R9
                MOVE    @R9, R9
                SUB     2, R9
_SL_FILL_LOOP   MOVE    R0, @R8++
                SUB     1, R9
                RBRA    _SL_FILL_LOOP, !Z

                SYSCALL(leave, 1)
                RET
