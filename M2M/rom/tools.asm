; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Miscellaneous tools and helper functions
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; M2M$CHK_EXT
; 
; Checks if the given filename has the given extension. Is case-sensitive, so
; you need to convert to upper- or lower-case before, if you want to check
; non-case-sensitive. Per definition, the extension need to be at the end
; of the string, not just somewhere in the middle.
;
; Input:  R8: String: Filename
;         R9: String: Extension
; Output: Carry-flag = 1 if the given filename has the extension, else 0 
; ----------------------------------------------------------------------------

M2M$CHK_EXT     INCRB
                MOVE    R8, R0                  ; save R8..R10
                MOVE    R9, R1
                MOVE    R10, R2

                SYSCALL(strstr, 1)              ; search extension substring
                CMP     0, R10                  ; R10: pointer to substring
                RBRA    _M2M$CHK_EX_C0, Z       ; not found: C=0 and return

                ; is the extension actually at the end of the string?
                ; we add the length of the extension to the position where
                ; we found the extension and check, if we reach the end of
                ; the soruce string
                MOVE    R9, R8
                SYSCALL(strlen, 1)
                ADD     R9, R10
                CMP     0, @R10
                RBRA    _M2M$CHK_EX_C1, Z

_M2M$CHK_EX_C0  AND     0xFFFB, SR              ; clear Carry
                RBRA    _M2M$CHK_EX_RET, 1

_M2M$CHK_EX_C1  OR      0x0004, SR              ; set Carry
                
_M2M$CHK_EX_RET MOVE    R0, R8                  ; restore R8..R10
                MOVE    R1, R9
                MOVE    R2, R10
                DECRB
                RET

; ----------------------------------------------------------------------------
; WAIT1SEC
;   Waits about 1 second
; WAIT333MS
;   Waits about 1/3 second
; ----------------------------------------------------------------------------

WAIT1SEC        INCRB
                MOVE    0x0060, R0
_W1S_L1         MOVE    0xFFFF, R1
_W1S_L2         SUB     1, R1
                RBRA    _W1S_L2, !Z
                SUB     1, R0
                RBRA    _W1S_L1, !Z
                DECRB
                RET

WAIT333MS       INCRB
                MOVE    0x0020, R0
_W333MS_L1      MOVE    0xFFFF, R1
_W333MS_L2      SUB     1, R1
                RBRA    _W333MS_L2, !Z
                SUB     1, R0
                RBRA    _W333MS_L1, !Z
                DECRB
                RET

; ----------------------------------------------------------------------------
; WORD2HEXSTR
;    Convert a word into its hexadecimal zero-terminated string representation
;    R8: word
;    R9: pointer to 5 words of memory
; ----------------------------------------------------------------------------

WORD2HEXSTR     INCRB

                MOVE    4, R0                   ; constant for nibble shifting
                MOVE    R0, R4                  ; set loop counter to four
                MOVE    R8, R5                  ; for restoring R8 later
                MOVE    _WORD2HEXSTR_DG, R1     ; pointer to list of nibbles

_W2HEX_LOOP1    MOVE    R1, R2                  ; scratch copy nibble ptr
                MOVE    R8, R3                  ; local copy of input R8
                AND     0x000F, R3              ; only the four LSBs
                ADD     R3, R2                  ; adjust ptr to desired nibble
                MOVE    @R2, @--SP              ; save the ASCII char on stack
                SHR     4, R8                   ; shift R8 four places right
                                                ; (C is 0 due to ADD)
                SUB     1, R4                   ; decrement loop counter
                RBRA _W2HEX_LOOP1, !Z           ; continue with the next nib.


                MOVE    R0, R4                  ; init loop counter
                MOVE    R9, R7                  ; target pointer
_W2HEX_LOOP2    MOVE    @SP++, @R7++            ; fetch char from stack
                SUB     1, R4                   ; decrement loop counter
                RBRA    _W2HEX_LOOP2, !Z        ; continue with the next char
                MOVE    0, @R7                  ; zero terminator

                MOVE    R5, R8                  ; restore R8
                DECRB
                RET

_WORD2HEXSTR_DG .ASCII_P "0123456789ABCDEF"                 

; ----------------------------------------------------------------------------
; Save/restore current device and selector values to/from a buffer
;
; Input:  R8: Pointer to a two word buffer
; Output: R8 is not changed; buffer is used to save and restore
; ----------------------------------------------------------------------------

SAVE_DEVSEL     INCRB
                MOVE    R8, R1
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    @R0, @R1++
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    @R0, @R1
                DECRB
                RET

RESTORE_DEVSEL  INCRB
                MOVE    R8, R1
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    @R1++, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    @R1, @R0
                DECRB
                RET
