; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Welcome and Help Screens (WHS)
;
; WHS can be configured in config.vhd.
; The file whs.asm needs the environment of shell.asm.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Show the welcome screen
; ----------------------------------------------------------------------------

SHOW_WELCOME    INCRB

                MOVE    R8, R0
                MOVE    M2M$WHS_WELCOME, R8
                RSUB    WHS_SHOW_PAGES, 1
                MOVE    R0, R8

                DECRB 
                RET

; ----------------------------------------------------------------------------
; Find out which help item id (aka WHS array id) the given single select
; item in R8 represents (if any) and if it does: Handle the whole process:
; From switching from the OSM to the large window, finding the right
; page-group to making sure that after the help is shown we can continue in
; the OSM "as if nothing happened".
;
; Input:  R8: selected menu group (as defined in OPTM_IR_GROUPS)
; Output: R8: unchanged
;         C=1, if we did find and show a help item, otherwise C=0
; ----------------------------------------------------------------------------

HANDLE_HELP     SYSCALL(enter, 1)

                ; step 1: find the menu item, i.e. get the index relative
                ; to the beginning of the data structure
                MOVE    OPTM_DATA, R0
                MOVE    @R0, R0
                ADD     OPTM_IR_GROUPS, R0
                MOVE    @R0, R0                 ; R0: start of data structure
                MOVE    OPTM_ICOUNT, R1
                MOVE    @R1, R1                 ; R1: amount of menu items
                XOR     R2, R2                  ; R2: index of help men. item

_HH_1           CMP     R8, @R0++
                RBRA    _HH_3, Z                ; menu item found
                ADD     1, R2
                SUB     1, R1
                RBRA    _HH_1, !Z               ; check next item
_HH_2           RBRA    _HH_C0, 1               ; item not found

                ; step 2: check, if the menu item is a help menu item and find
                ; out the help item ID by counting; R2 contains the index of
                ; the menu item that we are looking for
_HH_3           XOR     R1, R1                  ; R1: help idx number, if any
                XOR     R7, R7                  ; R7: index number
                MOVE    M2M$RAMROM_DEV, R0      ; select configuration device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; select help items
                MOVE    M2M$CFG_OPTM_HELP, @R0
                MOVE    M2M$RAMROM_DATA, R0     ; R0: ptr to data structure
_HH_3A          CMP     R7, R2                  ; did we reach the item?
                RBRA    _HH_5, !Z               ; no: continue to search
_HH_4           CMP     1, @R0++                ; is the item a hlp menu itm
                RBRA    _HH_C0, !Z              ; no: return with C=0
                RBRA    _HH_7, 1                ; R1: help menu id
_HH_5           CMP     1, @R0++                ; item at curr idx. hlp. item?
                RBRA    _HH_6, !Z               ; no
                ADD     1, R1                   ; count item as hlp. item
_HH_6           ADD     1, R7                   ; next index position
                RBRA    _HH_3A, 1

                ; step 3: show help page(s)
_HH_7           ADD     M2M$WHS_HELP_INDEX, R1
                MOVE    R1, R8
                RSUB    WHS_SHOW_PAGES, 1

                ; step 4: show the menu again and clean it up: the help menu
                ; item can never be selected, so we need to "hack" the toggle
                ; mechanism of single-select menu items
                RSUB    OPTM_SHOW, 1            
                RSUB    SCR$OSM_O_ON, 1
                MOVE    R2, R8
                XOR     R9, R9
                RSUB    _HM_SETMENU, 1
                RBRA    _HH_C1, 1

_HH_C0          AND     0xFFFB, SR              ; clear Carry
                RBRA    _HH_RET, 1
_HH_C1          OR      0x0004, SR              ; set Carry

_HH_RET         SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Return page in page-set
;
; Input:  R8: page-set id: 0 to 15
;         R9: page id: 0 to 255
; Output: R8: string pointer to page
;         R9: amount of pages in current page-set
; ----------------------------------------------------------------------------

WHS_PAGE_GET    INCRB

                ; calculate page set id manually instead of using a SHL
                ; so that we utilize M2M$WHS_HELP_NEXT constant and make no
                ; further assumptions on the inner working of config.vhd
                XOR     R3, R3                  ; R3: WHS array pos
                XOR     R4, R4                  ; R4: counter
_WHS_PG_1       CMP     R4, R8                  ; R8: page set id
                RBRA    _WHS_PG_2, Z
                ADD     M2M$WHS_HELP_NEXT, R3
                ADD     1, R4
                RBRA    _WHS_PG_1, 1

_WHS_PG_2       MOVE    M2M$RAMROM_DEV, R7
                MOVE    M2M$CONFIG, @R7
                MOVE    M2M$RAMROM_4KWIN, R7
                MOVE    M2M$CFG_WHS, @R7
                ADD     R3, @R7                 ; WHS array pos / page set id
                ADD     R9, @R7                 ; page id

                MOVE    M2M$RAMROM_DATA, R8     ; R8: string pointer
                MOVE    M2M$WHS_PAGES, R9       ; R9: amount of pages
                MOVE    @R9, R9

                DECRB
                RET

; ----------------------------------------------------------------------------
; Show the page given by the page-set id and let the user browse all pages
; of the page-set using Cursor Left/Cursor Right and let the user end the
; dialog by pressing Space. Clears the VRAM before and also draws the frame.
; Input:  R8: page-set
; Output: Unchanged R8
; ----------------------------------------------------------------------------

WHS_SHOW_PAGES  SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: page-set
                XOR     R1, R1                  ; R1: current page id

                RSUB    SCR$OSM_M_ON, 1         ; switch on main OSM


                ; clear screen and draw frame (changes QNICE device registers)
_WHS_SP_0       RSUB    FRAME_FULLSCR, 1

                ; get page string and amount of pages and show current page
                MOVE    R0, R8
                MOVE    R1, R9
                RSUB    WHS_PAGE_GET, 1
                MOVE    R9, R2                  ; R2: maximum page id
                SUB     1, R2                   ; max id = amount - 1
                RSUB    SCR$PRINTSTR, 1         ; show page content

                ; browse forward/backward (Left/Right) or end (Space)
_WHS_SP_1       RSUB    HANDLE_IO, 1            ; IO continues to work
                RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1

                CMP     M2M$KEY_SPACE, R8       ; Space?
                RBRA    _WHS_SP_RET, Z          ; yes: finish

                CMP     M2M$KEY_LEFT, R8        ; Left = previous page
                RBRA    _WHS_SP_2, !Z           ; no: check Right
                CMP     0, R1                   ; already at page 0?
                RBRA    _WHS_SP_1, Z            ; yes: ignore key
                SUB     M2M$WHS_PAGE_NEXT, R1   ; no: one page back
                RBRA    _WHS_SP_0, 1            ; show new page                

_WHS_SP_2       CMP     M2M$KEY_RIGHT, R8       ; Right = next page
                RBRA    _WHS_SP_1, !Z           ; no: ignore key
                CMP     R2, R1                  ; maximum page id reached?
                RBRA    _WHS_SP_1, Z            ; yes: ignore key
                ADD     M2M$WHS_PAGE_NEXT, R1   ; no: one page forward
                RBRA    _WHS_SP_0, 1            ; show new page

_WHS_SP_RET     RSUB    SCR$OSM_OFF, 1          ; Hide OSM
                SYSCALL(leave, 1)
                RET
