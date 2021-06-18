; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Miscellaneous tools and helper functions
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

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

; ----------------------------------------------------------------------------
; Functions that are part of QNICE Monitor V1.7 and that can be replaced
; as soon as we update gbc4mega65 to QNICE V1.7
; ----------------------------------------------------------------------------

; Alternative to a pure INCRB that also saves R8 .. R12
ENTER           INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4
                INCRB
                RET

; Alternative to a pure DECRB that also restores R8 .. R12
LEAVE           DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12
                DECRB
                RET

; STRCPY copies a zero-terminated string to a destination
; R8: Pointer to the string to be copied
; R9: Pointer to the large enough destination memory
STRCPY          INCRB
                MOVE    R8, R0
                MOVE    R9, R1
_STRCPY_L       MOVE    @R0++, @R1++
                RBRA    _STRCPY_L, !Z
                DECRB
                RET                   
