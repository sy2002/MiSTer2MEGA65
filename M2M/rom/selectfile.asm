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
; Input:
;   * HANDLE_DEV needs to be valid.
;   * Expects FB_STACK to be initialized (as well as the stack itself)
;   * B_STACK_SIZE needs to contain the correct number
;   * SD_WAIT needs to be defined (.EQU) and SD_CYC_MID & SD_CYC_HI need
;     to contain the initial cycle counter values
;   * SD_WAIT_DONE needs to be initialized to zero for the very first start
;     of the system and after each reset
; Output:
;   R8: Pointer to filename (zero terminated string), if R9=0
;   R9: 0=OK (no error)
;       1=SD card changed (this is no error, but need re-mounting)
;       2=Cancelled via Run/Stop
; ----------------------------------------------------------------------------

SELECT_FILE     SYSCALL(enter, 1)

                ; stack handling
                MOVE    FB_MAINSTACK, R0        ; remember the original stack
                MOVE    SP, @R0
                MOVE    FB_STACK, R0
                MOVE    @R0, SP                 ; restore the own stack

                ; Perform the SD card "stability" workaround (see shell.asm)
                MOVE    SD_WAIT_DONE, R8        ; successfully waited before?
                CMP     0, @R8
                RBRA    _S_CONT_CHECK, !Z       ; yes

                MOVE    SD_CYC_HI, R8           ; did we wait veeeery long?
                MOVE    IO$CYC_HI, R9
                MOVE    @R9, R9
                SUB     @R8, R9
                RBRA    _S_SD_WAITDONE, !Z      ; yes

                MOVE    SD_CYC_MID, R8
                MOVE    @R8, R8
                MOVE    IO$CYC_MID, R9
                MOVE    @R9, R10
                SUB     R8, R10
                MOVE    SD_WAIT, R11
                CMP     R10, R11                ; less or equal wait time?
                RBRA    _S_SD_WAITDONE, N       ; no: proceed with browser

                RSUB    SCR$CLRINNER, 1         
                MOVE    STR_INITWAIT, R8
                RSUB    SCR$PRINTSTR, 1         ; Show "Please wait"-message
                MOVE    SD_CYC_MID, R8
                MOVE    @R8, R8
                MOVE    IO$CYC_MID, R9                
_S_SD_WAIT      MOVE    @R9, R10
                SUB     R8, R10
                CMP     R10, R11
                RBRA    _S_SD_WAIT, !N
                RSUB    SCR$CLRINNER, 1

_S_SD_WAITDONE  MOVE    SD_WAIT_DONE, R8        ; remember that we waited
                MOVE    1, @R8                

                ; if we already have run the browser before, then let us
                ; continue where we left off
_S_CONT_CHECK   MOVE    FB_HEAD, R8
                CMP     0, @R8
                RBRA    _S_START, Z
                MOVE    FB_HEAP, R10
                RBRA    _S_BROWSE_START, 1

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
                RBRA    _S_BROWSE_START, Z      ; no
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
                RBRA    _S_BROWSE_START, Z
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

                ; ------------------------------------------------------------
                ; DIRECTORY BROWSER
                ; ------------------------------------------------------------

_S_BROWSE_START MOVE    R10, R0                 ; R0: dir. linked list head

                MOVE    FB_HEAD, R8
                MOVE    @R8, R8                 ; persistent existing head?
                RBRA    _S_BROWSE_SETUP, Z      ; no: continue
                MOVE    R8, R0                  ; yes: use it

                ; how much items are there in the current directory?
_S_BROWSE_SETUP MOVE    R0, R8
                RSUB    SLL$LASTNCOUNT, 1
                MOVE    R10, R1                 ; R1: amount of items in dir.
                MOVE    SCR$OSM_M_DY, R2        ; R2: max rows on screen
                MOVE    @R2, R2
                SUB     2, R2                   ; (frame is 2 rows high)
                MOVE    R0, R3                  ; R3: currently visible head

                MOVE    @SP++, R4               ; R4: currently selected ..
                                                ; .. line inside window

                XOR     R5, R5                  ; R5: counts the amount of ..
                                                ; ..files that have been shown

                MOVE    LOG_STR_ITM_AMT, R8     ; log amount of items in ..
                SYSCALL(puts, 1)                ; .. current directory to UART
                MOVE    R1, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    FB_ITEMS_COUNT, R8      ; existing persistent # items?
                CMP     0, @R8
                RBRA    _S_BROWSE_STP2, Z       ; no
                MOVE    @R8, R1                 ; yes: store ..
                MOVE    0, @R8                  ; .. and clear value / flag
_S_BROWSE_STP2  MOVE    FB_ITEMS_SHOWN, R8      ; exist. pers. # shown items?
                CMP     0, @R8
                RBRA    _S_DRAW_DIRLIST, Z      ; no
                MOVE    @R8, R5                 ; yes: store

                ; list (maximum one screen of) directory entries
_S_DRAW_DIRLIST RSUB    SCR$CLRINNER, 1
                MOVE    R3, R8                  ; R8: pos in LL to show list
                MOVE    R2, R9                  ; R9: amount if lines to show
                RSUB    SHOW_DIR, 1             ; print directory listing         

                MOVE    FB_ITEMS_SHOWN, R8      ; do not add SHOW_DIR result..
                CMP     0, @R8                  ; ..if R5 was restored using..
                RBRA    _S_ADDSHOWN_ITM, Z      ; FB_ITEMS_SHOWN and..
                MOVE    0, @R8                  ; ..clear FB_ITEMS_SHOWN
                RBRA    _S_SELECT_LOOP, 1

_S_ADDSHOWN_ITM ADD     R10, R5                 ; R5: overall # of files shown

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
                MOVE    M2M$CSR, R8
                MOVE    @R8, R8
                AND     M2M$CSR_SD_ACTIVE, R8
                MOVE    SD_ACTIVE, R9
                CMP     R8, @R9
                RBRA    _S_INPUT_LOOP, Z        ; SD card did not change

                ; SD card changed
                MOVE    R8, @R9                 ; remember new active card

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
                RBRA    _S_INPUT_LOOP, N        ; if < 0 then no scroll
                CMP     R8, R2                  ; R8 > max entries on screen?
                RBRA    _IL_PAGE_DEFUP, N       ; yes: scroll one page up
                MOVE    R8, R10                 ; no: move the residual up..
                RBRA    _IL_PAGE_UP, !Z         ; .. if it is > 0
                RBRA    _S_INPUT_LOOP, 1
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
                RBRA    _S_INPUT_LOOP, Z        ; no more files: ignore key
                CMP     R8, R2                  ; R8 > max rows on screen?
                RBRA    _IL_PAGE_DEFDN, N       ; yes: scroll one page down
                MOVE    R8, R10                 ; R10: remaining elm. down
                RBRA    _IL_PAGE_DN, 1
_IL_PAGE_DEFDN  MOVE    R2, R10                 ; R10: one page down
_IL_PAGE_DN     MOVE    1, R9                   ; R9: iterate forward
                RBRA    _SCROLL, 1              ; scroll, then input loop

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
_SCROLL_DO      CMP     -1, R9                  ; negative iteration dir.?
                RBRA    _SCROLL_DO2, !Z         ; no: continue
                XOR     R3, R3                  ; yes: inverse sign of R10
                SUB     R10, R3
                MOVE    R3, R10
_SCROLL_DO2     MOVE    R11, R3                 ; new visible head
                ADD     R10, R5                 ; R10 more/less visible files
                SUB     R2, R5                  ; compensate for SHOW_DIR
                RBRA    _S_DRAW_DIRLIST, 1         ; redraw directory list

                ; browsing interrupted by Run/Stop:
                ; remember where we are and exit
_IL_KEY_RUNSTOP MOVE    R4, @--SP               ; remember cursor position
                MOVE    FB_HEAD, R8             ; remember currently vis. head
                MOVE    R3, @R8
                MOVE    FB_ITEMS_COUNT, R8      ; remember # of items in dir.
                MOVE    R1, @R8
                MOVE    FB_ITEMS_SHOWN, R8      ; remember # of items shown
                MOVE    R5, @R8

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

                MOVE    M2M$CSR, R9             ; switch sd mode to manual
                OR      M2M$CSR_SD_MODE, @R9
                CMP     M2M$KEY_F3, R8          ; F3: switch to external
                RBRA    _IL_SD_INT2, !Z
                OR      M2M$CSR_SD_FORCE, @R9
                MOVE    M2M$CSR_SD_ACTIVE, @R10 ; remember new active: ext.
                RBRA    _S_SD_CHANGED, 1

_IL_SD_INT2     AND     M2M$CSR_UN_SD_FORCE, @R9 ; F1: switch to internal
                MOVE    0, @R10                 ; remember new active: int.
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
                ; change directory or load cartridge; we therefore need to
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

                MOVE    FB_HEAD, R9             ; reset head for browsing
                MOVE    0, @R9

                MOVE    FN_UPDIR, R9            ; are we going one dir. up?
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _CHANGEDIR, Z           ; yes: get crsr pos from stack

                MOVE    R4, @--SP               ; no: remember cursor pos..
                MOVE    0, @--SP                ; ..and new dir. starts at 0

_CHANGEDIR      MOVE    R8, R9                  ; use this directory
                MOVE    HANDLE_DEV, R8
                RBRA    _S_CD_AND_READ, 1       ; create new linked-list

_RETNAME        MOVE    R4, @--SP               ; remember cursor position
                MOVE    FB_HEAD, R8             ; remember currently vis. head
                MOVE    R3, @R8
                MOVE    FB_ITEMS_COUNT, R8      ; remember # of items in dir.
                MOVE    R1, @R8
                MOVE    FB_ITEMS_SHOWN, R8      ; remember # of items shown
                MOVE    R5, @R8

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
_S_RET_1        MOVE    @R2, SP                 ; restore global stack

                MOVE    R8, @--SP               ; bring R8, R9 over "leave"
                MOVE    R9, @--SP
                SYSCALL(leave, 1)
                MOVE    @SP++, R9
                MOVE    @SP++, R8
                RET

; ----------------------------------------------------------------------------
; Initialize file browser persistence variables
; ----------------------------------------------------------------------------

FB_INIT         INCRB

                MOVE    FB_HEAD, R0             ; no active head of file brws.
                MOVE    0, @R0
                MOVE    FB_ITEMS_COUNT, R0      ; no directory browsed so far
                MOVE    0, @R0
                MOVE    FB_ITEMS_SHOWN, R0      ; no dir. items shown so far
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
