; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Miscellaneous tools and helper functions
;
; done by sy2002 in 2023 and licensed under GPL v3
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
; M2M$RPL_S
; 
; Replaces the first instance of %s in a string by another string. There needs
; to be at least one occurance of %s in the string otherwise fatal. If the
; resulting string (Target string including %s) is longer than R11 then the
; resulting string is shortened using FN_ELLIPSIS. The memory region specified
; by the target string needs to be large enough to actually hold it.
;
; Input:  R8: Source string
;         R9: Target string
;        R10: Replacement string for %s
;        R11: Maximum amount of characters for target string
; Output: None. No registers are changed
; ----------------------------------------------------------------------------

M2M$RPL_S       SYSCALL(enter, 1)

                MOVE    R9, R0                  ; R0: target string
                MOVE    R8, R7                  ; R7: input string
                MOVE    R10, R8                 ; R8: replacement string
                MOVE    R11, R4                 ; R4: max width

                MOVE    R8, R6                  ; remember R8
                MOVE    R7, R8                  ; find "%s" in R7
                MOVE    _M2M$RPL_S_S, R9
                SYSCALL(strstr, 1)
                CMP     0, R10                  ; R10: position of %s
                RBRA    _M2M$RPL_S_1, !Z

                ; if "%s" is not being found at this place, then something
                ; went wrong terribly
                MOVE    ERR_F_NO_S, R8
                XOR     R9, R9
                RBRA    FATAL, 1

                ; copy the string from 0 to one before %s to the output buf.
_M2M$RPL_S_1    MOVE    R10, R2                 ; R2: save %s pos, later use
                SUB     R7, R10
                MOVE    R7, R8
                MOVE    R0, R9
                SYSCALL(memcpy, 1)

                ; overwrite the "%s" from the "%" on with new string, make
                ; sure that we are not longer than the max width, which is
                ; @SCR$OSM_O_DX
                ; R10 contains the length of the string before the %s
                MOVE    R6, R8                  ; replacement string
                SYSCALL(strlen, 1)
                ADD     R10, R9                 ; prefix string + repl. string

                CMP     R9, R4                  ; is it larger than max width?
                RBRA    _M2M$RPL_S_3, N         ; yes
                MOVE    R0, R9                  ; R8 still points to repl. str
                ADD     R10, R9                 ; ptr to "%"
                SYSCALL(strcpy, 1)

                ; if we land here, we successfully used "prefix" + "%s"; now
                ; lets check, if we can add parts or everything of the
                ; "suffix", i.e. the part after the "%s"
                MOVE    R0, R8
                SYSCALL(strlen, 1)
                MOVE    R9, R3                  ; R3: size of concat string
                CMP     R3, R4                  ; R3 < max width?
                RBRA    _M2M$RPL_S_RET, Z       ; no (< means not Z)
                RBRA    _M2M$RPL_S_RET, N       ; no (< means also not N)
                
                ADD     2, R2                   ; R2: first char behind "%s"
                MOVE    R2, R8
                SYSCALL(strlen, 1)
                CMP     0, R9                   ; is there anything to add?
                RBRA    _M2M$RPL_S_RET, Z       ; no

                SUB     R3, R4                  ; R4 = max amt. chars to add

                ; pick the minimum of (R4: max. amt. chars to add) and
                ; (R9: size of "suffix") and copy the data into the buffer
                CMP     R4, R9                  ; R4 > R9?
                RBRA    _M2M$RPL_S_2, !N        ; no
                MOVE    R9, R4                  ; yes: then use R9 instead
_M2M$RPL_S_2    MOVE    R2, R8                  ; first char behind "%s"
                MOVE    R0, R9
                ADD     R3, R9                  ; last char of concat string
                MOVE    R4, R10                 ; amount of chars to copy
                SYSCALL(memcpy, 1)
                ADD     R10, R9                 ; add zero terminator
                MOVE    0, @R9
                RBRA    _M2M$RPL_S_RET, 1

                ; if we land here, the overall string consisting of the first
                ; two parts ("prefix" + "%s") is too long, so we may only copy
                ; the maximum amount and we need to add an
                ; ellipsis (aka "...") at the end
_M2M$RPL_S_3    MOVE    R0, R9
                ADD     R10, R9
                MOVE    R4, R5
                SUB     R10, R5                 ; max amount we can copy
                MOVE    R5, R10         
                SYSCALL(memcpy, 1)
                ADD     R10, R9                 ; add zero terminator
                MOVE    0, @R9
                SUB     3, R9                   ; add ellipsis
                MOVE    FN_ELLIPSIS, R8
                SYSCALL(strcpy, 1)

_M2M$RPL_S_RET  SYSCALL(leave, 1)
                RET

_M2M$RPL_S_S    .ASCII_W "%s"

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
