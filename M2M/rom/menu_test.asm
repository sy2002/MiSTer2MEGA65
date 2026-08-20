; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Test program and development testbed for the menu size checks in menu.asm:
; OPTM_CHK_WIN (menu window versus screen size) and the fit check in
; OPTM_SHOW (visible menu items versus menu window height).
;
; The testbed drives the real production code of menu.asm with a stub
; initialization record: All draw functions are no-operation stubs and the
; fatal callback prints the type of the fatal error plus the error code and
; then continues with the next test case instead of halting.
;
; Assemble and run it in the QNICE emulator using batch mode:
;    cd M2M/rom && ../QNICE/assembler/asm menu_test.asm
;    ../QNICE/emulator/qnice -b 0x8000 ../QNICE/monitor/monitor.out \
;                            menu_test.out < /dev/null
;
; Expected output: see comments at the test case table below. Each test case
; prints one line "CASE <number>: <result>" and the run ends with "DONE".
;
; done by sy2002 in 2026 and licensed under GPL v3
; ****************************************************************************

#include "../../M2M/QNICE/dist_kit/sysdef.asm"
#include "../../M2M/QNICE/dist_kit/monitor.def"

                .ORG    0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    TB_CUR, R0              ; start at first test case
                MOVE    TB_CASES, @R0
                MOVE    TB_CASENUM, R0
                MOVE    1, @R0

                ; ------------------------------------------------------------
                ; Test case driver loop
                ; ------------------------------------------------------------

TB_LOOP         MOVE    TB_CUR, R0
                MOVE    @R0, R1                 ; R1: current test case
                CMP     0xFFFF, @R1             ; end of test cases?
                RBRA    TB_DONE, Z

                MOVE    STR_CASE, R8            ; print "CASE <number>: "
                SYSCALL(puts, 1)
                MOVE    TB_CASENUM, R0
                MOVE    @R0, R8
                SYSCALL(puthex, 1)
                MOVE    STR_COLON, R8
                SYSCALL(puts, 1)

                MOVE    TB_SP, R0               ; remember stack pointer and
                MOVE    SP, @R0                 ; ..register bank so that the
                MOVE    TB_SR, R0               ; ..fatal callback is able to
                MOVE    R14, @R0                ; ..continue w. the next case

                MOVE    TB_CUR, R0              ; unpack the test case record
                MOVE    @R0, R1
                MOVE    @R1++, R2               ; R2: kind: 0=CHK_WIN 1=SHOW
                MOVE    @R1++, R3               ; R3: screen dx
                MOVE    @R1++, R4               ; R4: screen dy
                MOVE    @R1++, R5               ; R5: window dx incl. frame
                MOVE    @R1++, R6               ; R6: window dy incl. frame
                MOVE    @R1++, R7               ; R7: (sub)menu level

                MOVE    TB_RECORD, R0           ; poke amount of menu items..
                ADD     OPTM_IR_SIZE, R0        ; ..into the stub init record
                MOVE    @R1++, @R0
                MOVE    TB_RECORD, R0           ; poke menu groups pointer
                ADD     OPTM_IR_GROUPS, R0
                MOVE    @R1++, @R0

                MOVE    TB_CALLS, R0            ; reset stub invocation cntr.
                MOVE    0, @R0

                MOVE    TB_RECORD, R8           ; init the menu library
                XOR     R9, R9                  ; x-coordinate = 0
                XOR     R10, R10                ; y-coordinate = 0
                MOVE    R5, R11                 ; window dx
                MOVE    R6, R12                 ; window dy
                RSUB    OPTM_INIT, 1
                MOVE    OPTM_MENULEVEL, R0      ; OPTM_INIT sets the level..
                MOVE    R7, @R0                 ; ..to 0, so set it afterwards

                CMP     1, R2                   ; which kind of test case?
                RBRA    TB_K_SHOW, Z

                MOVE    R3, R8                  ; kind 0: check window versus
                MOVE    R4, R9                  ; ..screen size
                RSUB    OPTM_CHK_WIN, 1
                RBRA    TB_PASS, 1

TB_K_SHOW       RSUB    OPTM_SHOW, 1            ; kind 1: show the menu

TB_PASS         MOVE    STR_PASS, R8            ; no fatal error occured
                SYSCALL(puts, 1)
                MOVE    TB_CALLS, R8            ; amount of stub invocations
                MOVE    @R8, R8                 ; ..proves that a menu that..
                SYSCALL(puthex, 1)              ; ..fits is really drawn
                SYSCALL(crlf, 1)

TB_CASE_END     MOVE    TB_CUR, R0              ; advance to next test case
                ADD     8, @R0
                MOVE    TB_CASENUM, R0
                ADD     1, @R0
                RBRA    TB_LOOP, 1

TB_DONE         MOVE    STR_DONE, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

                ; ------------------------------------------------------------
                ; Stub callback functions for the menu init record
                ; ------------------------------------------------------------

                ; draw and keyboard functions: count the invocations, so
                ; that the testbed can prove that a menu that fits is really
                ; drawn (fatal test cases stop after the clear function, so
                ; they show exactly one invocation)
TB_STUB         INCRB
                MOVE    TB_CALLS, R0
                ADD     1, @R0
                DECRB
                RET

                ; fatal callback: R8: pointer to error message, R9: error
                ; code; print the type of the message plus the error code,
                ; then restore the environment that was saved by the driver
                ; loop and continue with the next test case
TB_FATAL        MOVE    R9, R11                 ; R11: remember error code
                MOVE    R8, R10                 ; R10: remember error message

                CMP     OPTM_F_WINX, R10
                RBRA    _TBF_1, !Z
                MOVE    STR_WINX, R8
                RBRA    _TBF_P, 1
_TBF_1          CMP     OPTM_F_WINY, R10
                RBRA    _TBF_2, !Z
                MOVE    STR_WINY, R8
                RBRA    _TBF_P, 1
_TBF_2          CMP     OPTM_F_MENUFIT, R10
                RBRA    _TBF_3, !Z
                MOVE    STR_FIT, R8
                RBRA    _TBF_P, 1
_TBF_3          CMP     OPTM_F_MENUSUB, R10
                RBRA    _TBF_4, !Z
                MOVE    STR_SUB, R8
                RBRA    _TBF_P, 1
_TBF_4          MOVE    STR_UNK, R8
_TBF_P          SYSCALL(puts, 1)
                MOVE    R11, R8                 ; print error code
                SYSCALL(puthex, 1)
                MOVE    STR_CALLS, R8           ; print stub invocations:
                SYSCALL(puts, 1)                ; ..proves that the fit check
                MOVE    TB_CALLS, R8            ; ..fires after the clear and
                MOVE    @R8, R8                 ; ..before anything is drawn
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    TB_SR, R8               ; restore register bank..
                MOVE    @R8, R14
                MOVE    TB_SP, R8               ; ..and stack pointer
                MOVE    @R8, SP
                RBRA    TB_CASE_END, 1          ; continue with next case

                ; ------------------------------------------------------------
                ; Stub menu initialization record (see menu.asm)
                ; OPTM_IR_SIZE and OPTM_IR_GROUPS are poked per test case
                ; ------------------------------------------------------------

TB_RECORD       .DW     TB_STUB, TB_STUB, TB_STUB, TB_STUB                      ; CLEAR, FRAME, PRINT, PRINTXY
                .DW     TB_STUB, TB_STUB, TB_STUB                               ; LINE, SELECT, GETKEY
                .DW     0, 0, TB_FATAL                                          ; CLBK_SEL, CLBK_SHOW, CLBK_FATAL
                .DW     7, 0, 61, 0                                             ; selection characters
                .DW     0, TB_ITEMS, 0, TB_ZEROS, TB_ZEROS                      ; SIZE, ITEMS, GROUPS, STDSEL, LINES

TB_ITEMS        .ASCII_W "X\n"

                ; shared arrays for the menu groups (values see menu.asm):
                ; plain menu items, a balanced submenu, an unbalanced submenu
                ; and a headline; the zeros array doubles as no-item-selected
                ; and no-separator-lines
TB_GRP_PLAIN    .DW     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
                .DW     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
TB_GRP_SUB      .DW     1, 0x4000, 1, 1, 0x40FF, 1
TB_GRP_BAD      .DW     1, 0x4000, 1
TB_GRP_HEAD     .DW     0x1000, 1, 1
TB_ZEROS        .DW     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                .DW     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

                ; ------------------------------------------------------------
                ; Test case table: 8 words per test case:
                ; kind, screen dx, screen dy, window dx, window dy, level,
                ; amount of menu items, pointer to menu groups
                ;
                ; kind 0 = OPTM_CHK_WIN:  uses screen dx/dy and window dx/dy
                ; kind 1 = OPTM_SHOW fit: uses window dy, level, amount of
                ;                         menu items and the groups pointer
                ; ------------------------------------------------------------

TB_CASES        ; window equals screen: fits: expect PASS
                .DW     0, 12, 12, 12, 12, 0, 0, 0
                ; window one char wider than screen: expect WINX code 0x000A
                .DW     0, 12, 12, 13, 12, 0, 0, 0
                ; window one char higher than screen: expect WINY code 0x000A
                .DW     0, 12, 12, 12, 13, 0, 0, 0
                ; both dims too big: dx is checked first: exp. WINX c. 0x002B
                .DW     0, 45, 36, 47, 38, 0, 0, 0
                ; the Amiga core (AExp): window 45x36 on a 720x576 screen:
                ; window equals screen exactly: expect PASS
                .DW     0, 45, 36, 45, 36, 0, 0, 0
                ; the Apple IIe scenario: 560x384 screen is 35x24 chars,
                ; OPTM_DY=24 makes a 26 high window: expect WINY code 0x0016,
                ; i.e. 22 = the maximum valid OPTM_DY on this screen
                .DW     0, 35, 24, 26, 26, 0, 0, 0
                ; the M2M template: window 25x26 on a 45x36 screen: exp. PASS
                .DW     0, 45, 36, 25, 26, 0, 0, 0
                ; extreme values: expect WINX code 0x002B
                .DW     0, 45, 36, 255, 255, 0, 0, 0
                ; dx fits exactly and dy is one too high: exp. WINY c. 0x0016
                .DW     0, 35, 24, 35, 25, 0, 0, 0
                ; degenerate but equal: expect PASS
                .DW     0, 2, 2, 2, 2, 0, 0, 0

                ; 10 plain items in a 12 high window (10 usable): exp. PASS
                .DW     1, 0, 0, 20, 12, 0, 10, TB_GRP_PLAIN
                ; 11 plain items in a 12 high window: exp. FIT code 0x000B
                .DW     1, 0, 0, 20, 12, 0, 11, TB_GRP_PLAIN
                ; the M2M template: 24 visible items, window height 26:
                ; boundary case: expect PASS
                .DW     1, 0, 0, 25, 26, 0, 24, TB_GRP_PLAIN
                ; 25 visible items, window height 26: exp. FIT code 0x0019
                .DW     1, 0, 0, 25, 26, 0, 25, TB_GRP_PLAIN
                ; submenu structure, main level: 3 visible items (item,
                ; submenu label, item) in a 5 high window: expect PASS
                .DW     1, 0, 0, 20, 5, 0, 6, TB_GRP_SUB
                ; ditto in a 4 high window (2 usable): exp. FIT code 0x0003
                .DW     1, 0, 0, 20, 4, 0, 6, TB_GRP_SUB
                ; submenu structure, submenu level: 3 visible items (two
                ; items plus the close item) in a 5 high window: expect PASS
                .DW     1, 0, 0, 20, 5, 1, 6, TB_GRP_SUB
                ; ditto in a 4 high window (2 usable): exp. FIT code 0x0003
                .DW     1, 0, 0, 20, 4, 1, 6, TB_GRP_SUB
                ; regression: unbalanced submenu: the already existing check
                ; in _OPTM_STRUCT still works: expect SUB code 0x0000
                .DW     1, 0, 0, 20, 12, 0, 3, TB_GRP_BAD
                ; regression: headline handling: 3 visible items incl. a
                ; headline in a 5 high window: expect PASS
                .DW     1, 0, 0, 20, 5, 0, 3, TB_GRP_HEAD
                ; smallest useful window: 1 item in a 3 high window: PASS
                .DW     1, 0, 0, 20, 3, 0, 1, TB_GRP_PLAIN
                ; 2 items in a 3 high window (1 usable): exp. FIT code 0x0002
                .DW     1, 0, 0, 20, 3, 0, 2, TB_GRP_PLAIN

                .DW     0xFFFF                  ; end of test cases

                ; ------------------------------------------------------------
                ; Strings and variables
                ; ------------------------------------------------------------

STR_TITLE       .ASCII_W "menu.asm size checks testbed\n"
STR_CASE        .ASCII_W "CASE "
STR_COLON       .ASCII_W ": "
STR_PASS        .ASCII_W "PASS CALLS "
STR_CALLS       .ASCII_W " CALLS "
STR_WINX        .ASCII_W "FATAL WINX "
STR_WINY        .ASCII_W "FATAL WINY "
STR_FIT         .ASCII_W "FATAL FIT "
STR_SUB         .ASCII_W "FATAL SUB "
STR_UNK         .ASCII_W "FATAL UNKNOWN "
STR_DONE        .ASCII_W "DONE\n"

TB_CUR          .BLOCK 1                        ; pointer to current test case
TB_CASENUM      .BLOCK 1                        ; number of current test case
TB_SP           .BLOCK 1                        ; saved stack pointer
TB_SR           .BLOCK 1                        ; saved status register
TB_CALLS        .BLOCK 1                        ; amount of stub invocations

; ----------------------------------------------------------------------------
; Production code under test plus its variables
; ----------------------------------------------------------------------------

#include "menu_vars.asm"
#include "menu.asm"
