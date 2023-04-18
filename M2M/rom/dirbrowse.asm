; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Directory Browser (with sorted output)
;
; Change in 2023: While this was originally made to be reusable also outside
; of the context of the Shell, from now on dirbrowse.asm is dependent on the
; global variable SF_CONTEXT in shell_vars.asm which will be handed over as a
; parameter R10 to the filter function in _DIRBR_FILTWRAP. To undo this
; change, delete this comment and everything tagged with SF_CONTEXT in
; _DIRBR_FILTWRAP.
;
; done by sy2002 in 2022, 2023 and licensed under GPL v3
; ****************************************************************************

#include "llist.asm"

_DIRBR_DOT      .ASCII_W "."                    ; filter this from dir. views
_DIRBR_DS       .EQU    0x3C                    ; ASCII of "<"
_DIRBR_DE       .EQU    0x3E                    ; ASCII of ">"
_DIRBR_DSDESIZE .EQU    2                       ; amount of characters in sum

; ----------------------------------------------------------------------------
; Read and sort all contents of the given path into a heap memory structure
; Input:
;   R8: Pointer to valid device handle
;   R9: Pointer to path that shall be listed (zero-terminated string)
;  R10: Pointer to heap
;  R11: Maximum amount of available heap memory
;  R12: Optional filter function that filters out files of a certain name.
;       The filter function takes a pointer to a string in R8 and a directory
;       flag in R9 (0=it is a file, 1=it is a directory) and returns 0 in R8,
;       if the file shall not be filtered and 1 if it shall be filtered.
;       The string provided in R8 is always in upper case.
;       If R12 is zero, then no filter is applied.
; Output:
;   R8: (unchanged) Pointer to valid device handle
;   R9: Amount of directory entries read
;  R10: head of sorted linked list
;  R11: Return code:
;       0 = OK
;       1 = directory not found
;       2 = more directory items available than memory permits
;       <other value> = error code
; ----------------------------------------------------------------------------

DIRBROWSE_READ  INCRB
                MOVE    R8, R0
                MOVE    R12, R1
                INCRB

                MOVE    R10, R0                 ; R0: head of the heap
                MOVE    R10, R1                 ; R1: current heap ptr
                MOVE    R11, R2                 ; R2: max memory on heap
                XOR     R3, R3                  ; R3: current heap mem. usage
                XOR     R4, R4                  ; R4: amount of entries read
                XOR     R5, R5                  ; R5: head of linked list
                XOR     R6, R6                  ; R6: filter function or 0
                                                ; R7: directory handle

                CMP     0, R12                  ; filter function given?
                RBRA    _DIRBR_START, Z         ; no: get started
                MOVE    _DIRBR_FILTERFN, R6     ; yes: remember custom func.
                MOVE    R12, @R6
                MOVE    _DIRBR_FILTWRAP, R6     ; R6: internal wrapper func.

                ; change directory to given path and then obtain the
                ; directory handle: R8: device handle, R9: path
_DIRBR_START    XOR     R10, R10                ; use "/" as separator char
                SYSCALL(f32_cd, 1)              ; change directory
                CMP     0, R9                   ; everything OK?
                RBRA    _DIRBR_RD_ECD, !Z       ; no: error and exit
                                                ; R8: still contains dev. hndl
                MOVE    _DIRBR_FH, R9           ; R9: empty directory handle
                SYSCALL(f32_od, 1)              ; obtain directory handle
                MOVE    R8, R7                  ; R7: directory handle
                CMP     0, R9                   ; everything OK?
                RBRA    _DIRBR_RD_EDH, !Z       ; no: exit with error code

                ; iterate through the current directory
_DIRBR_LOOP     MOVE    R7, R8                  ; R8: directory handle
                MOVE    _DIRBR_ENTRY, R9        ; R9: empty dir. entry struct
                MOVE    FAT32$FA_DEFAULT, R10   ; R10: browse for all
                                                ; non-hidden files and dirs
                SYSCALL(f32_ld, 1)              ; get next directory entry
                CMP     0, R11                  ; any errors?
                RBRA    _DIRBR_RD_RET, !Z       ; yes: exit with error in R11
                CMP     1, R10                  ; current entry valid?
                RBRA    _DIRBR_LOOPEND, !Z      ; no: end loop

                MOVE    _DIRBR_DOT, R8          ; filter the "single dot"
                MOVE    _DIRBR_ENTRY, R9
                ADD     FAT32$DE_NAME, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _DIRBR_LOOP, Z

                MOVE    R1, R8                  ; R1: current heap ptr
                MOVE    R2, R9                  ; R2: maximum heap memory
                MOVE    R3, R10                 ; R3: current heap memory
                RSUB    _DIRBR_NEWELM, 1        ; new element on heap
                MOVE    R8, R1                  ; R1: new heap ptr
                MOVE    R10, R3                 ; R3: new current heap memory
                CMP     0, R11                  ; out-of-memory?
                RBRA    _DIRBR_RD_WOOM, !Z      ; yes: exit

                ADD     1, R4                   ; one more entry read

                MOVE    R5, R8                  ; R8: head of linked list
                                                ; R9: still has new element
                MOVE    _DIRBR_COMPARE, R10     ; R10: compare function
                MOVE    R6, R11                 ; R11: filter func. or 0

                RSUB    SLL$S_INSERT, 1
                MOVE    R8, R5                  ; R5: (new) head of linked lst
                RBRA    _DIRBR_LOOP, 1          ; next iteration

_DIRBR_LOOPEND  MOVE    R4, R9                  ; return amount of entries
                MOVE    R5, R10                 ; R10: head of linked list
                XOR     R11, R11                ; 0 = no error
                RBRA    _DIRBR_RD_RET, 1

_DIRBR_RD_ECD   MOVE    1, R11                  ; directory not found
                RBRA    _DIRBR_RD_RET, 1
_DIRBR_RD_WOOM  MOVE    2, R11                  ; out-of-memory
                MOVE    R4, R9                  ; amount of entries
                MOVE    R5, R10                 ; head of linked list
                RBRA    _DIRBR_RD_RET, 1
_DIRBR_RD_EDH   MOVE    R9, R11                 ; return R9 as error code
_DIRBR_RD_RET   DECRB
                MOVE    R0, R8
                MOVE    R1, R12
                DECRB
                RET

; ----------------------------------------------------------------------------
; Internal helper functions
; ----------------------------------------------------------------------------

; Create new linked-list element on the heap, manage the heap-head and return
; a pointer to the new element in R8
; Input:
;   R8: Pointer to the head of the heap
;   assumes a valid directoy entry structure in _DIRBR_ENTRY
;   R9: maximum heap memory
;  R10: current heap memory
; Output;
;   R8: Adjusted pointer to the head of the heap
;   R9: Pointer to new linked-list element on the heap
;  R10: new current heap memory
;  R11: 0: OK, 1: out-of-memory
_DIRBR_NEWELM   INCRB

                MOVE    R8, R11                 ; R11: new linked-list elm.
                MOVE    R8, R0                  ; R0: NEXT
                MOVE    R8, R1                  ; R1: PREV
                MOVE    R8, R2                  ; R2: DATA-SIZE
                MOVE    R8, R3                  ; R3: DATA
                MOVE    R9, R4                  ; R4: maximum heap memory
                MOVE    R10, R5                 ; R5: current heap memory
                XOR     R6, R6                  ; R6: is it a directory?
                ADD     SLL$NEXT, R0            ; init NEXT with 0 
                MOVE    0, @R0
                ADD     SLL$PREV, R1            ; init PREV with 0
                MOVE    0, @R1
                ADD     SLL$DATA_SIZE, R2
                ADD     SLL$DATA, R3

                ; determine the length of the file/directory name and
                ; calculate the size of the data blob
                MOVE    _DIRBR_ENTRY, R7
                ADD     FAT32$DE_NAME, R7
                MOVE    R7, R8
                SYSCALL(strlen, 1)
                ADD     1, R9                   ; R9: length of file name str.
                ADD     1, R9                   ; space for attributes
                MOVE    _DIRBR_ENTRY, R7
                ADD     FAT32$DE_ATTRIB, R7
                AND     FAT32$FA_DIR, @R7       ; is it a directory?
                RBRA    _DIRBR_NEWELM2, Z       ; no
                ADD     _DIRBR_DSDESIZE, R9     ; add size of "<" ">"
                MOVE    1, R6                   ; R6: directory flag = 1

                ; R9 now contains the heap space needed: check if we still
                ; have enough heap to accommodate R9: create the linked-list
                ; data blob using this memory layout:
                ; filename (+ "<" and ">" if directory)
                ; dir-flag: 0: normal file, 1: directory
_DIRBR_NEWELM2  MOVE    R5, R7                  ; current heap memory
                ADD     R9, R7                  ; memory needed by new entry
                MOVE    R7, R10                 ; return new heap memory
                ADD     SLL$OVRHD_SIZE, R10
                CMP     R7, R4                  ; current+new <= max?
                RBRA    _DIRBR_NEOOM, N         ; no: out-of-memory!

                MOVE    R9, @R2                 ; put data size in SLL struct.
                CMP     1, R6                   ; is it a directory?
                RBRA    _DIRBR_NEWELM3, !Z      ; no: continue
                MOVE    _DIRBR_DS, @R3++        ; add "<" before name
_DIRBR_NEWELM3  MOVE    _DIRBR_ENTRY, R7        ; copy file name
                ADD     FAT32$DE_NAME, R7
                MOVE    R7, R8
                MOVE    R3, R9
                SYSCALL(strcpy, 1)

                SYSCALL(strlen, 1)              ; R9 contains len of filename
                ADD     R9, R3                  ; R3 points to zero terminator
                CMP     1, R6                   ; is it a directory?
                RBRA    _DIRBR_NEWELM4, !Z      ; no: continue
                MOVE    _DIRBR_DE, @R3++        ; add ">" after name
                MOVE    0, @R3

_DIRBR_NEWELM4  ADD     1, R3                   ; skip zero terminator
                MOVE    R6, @R3++               ; add directory flag

                MOVE    R3, R8                  ; R8: adjusted head of heap
                MOVE    R11, R9                 ; R9: pointer to new element
                XOR     R11, R11                ; R11: no error
                RBRA    _DIRBR_NERET, 1         ; return

                ; out of memory
_DIRBR_NEOOM    MOVE    R11, R8                 ; heap head did not change
                XOR     R9, R9                  ; no new element
                MOVE    R5, R10                 ; heap usage did not change
                MOVE    1, R11

                ; return
_DIRBR_NERET    DECRB
                RET

; SLL$S_INSERT compare function that returns negative if (S0 < S1),
; zero if (S0 == S1), positive if (S0 > S1). These semantic are
; basically compatible with STR$CMP, but instead of expecting pointers
; to two strings, this compare function is expecting two pointers to
; SLL records, while the pointer to the first one is given in R8 and
; treated as "S0" and the second one in R9 and treated as "S1".
; Also, this compare function compares case-insensitive.

_DIRBR_COMPARE  INCRB
                MOVE    R8, R0 
                MOVE    R9, R1
                INCRB
                MOVE    R8, R0
                MOVE    R9, R1

                ADD     SLL$DATA, R0            ; R0: pointer to first string
                ADD     SLL$DATA, R1            ; R1: pointer to second string

                ; copy R0 to the stack and make it upper case
_DIRBR_CMP      MOVE    R0, R8                  ; copy string to stack
                SYSCALL(strlen, 1)
                ADD     1, R9               
                SUB     R9, SP
                MOVE    R9, R4                  ; R4: stack restore amount
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R8
                SYSCALL(str2upper, 1)
                MOVE    R8, R0

                ; copy R1 to the stack and make it upper case
                MOVE    R1, R8
                SYSCALL(strlen, 1)
                ADD     1, R9
                SUB     R9, SP
                ADD     R9, R4                  ; R4: update stack rest. amnt.
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R8
                SYSCALL(str2upper, 1)
                MOVE    R8, R1

                ; replace the brackets in directory names like <this> by
                ; low ASCII characters to ensure they have sorting priority
                CMP     _DIRBR_DS, @R0          ; performance optimization
                RBRA    _DIRBR_NXTDS, !Z
                MOVE    _DIRBR_DS, R8           ; replace < by 1 in R0
                MOVE    1, R9
                MOVE    R0, R10
                SYSCALL(strrplchr, 1)
                MOVE    _DIRBR_DE, R8           ; replace > by 2 in R0
                MOVE    2, R9
                SYSCALL(strrplchr, 1)

_DIRBR_NXTDS    CMP     _DIRBR_DS, @R1
                RBRA    _DIRBR_DOISANUM, !Z
                MOVE    _DIRBR_DS, R8
                MOVE    1, R9                   ; replace < by 1 in R1
                MOVE    R1, R10
                SYSCALL(strrplchr, 1)
                MOVE    _DIRBR_DE, R8           ; replace > by 2 in R1
                MOVE    2, R9
                SYSCALL(strrplchr, 1)

                ; special treatment for names that are numbers so that files
                ; and folders like 1, 2, 3, ..., 10, 11, ..., 100, 101, ...
                ; are sorted in ascending order: If a string that represents
                ; a number is shorter than another string that represents a
                ; number then the first string is "smaller" than the second
                ; in the context of being a number
_DIRBR_DOISANUM MOVE    R0, R8                  ; if R0 is NaN: norm. strcmp
                RSUB    _DIRBR_ISANUM, 1
                RBRA    _DIRBR_DOCMP, !C
                MOVE    R1, R8                  ; if R1 is NaN: norm. strcmp
                RSUB    _DIRBR_ISANUM, 1
                RBRA    _DIRBR_DOCMP, !C

                MOVE    R0, R8
                SYSCALL(strlen, 1)
                MOVE    R9, R7                  ; R7: strlen of R0
                MOVE    R1, R8
                SYSCALL(strlen, 1)              ; R9: strlen of R1
                CMP     R7, R9
                RBRA    _DIRBR_DOCMP, Z         ; R5=R6: normal strcmp works
                RBRA    _DIRBR_R1, N            ; strlen(R0)>strlen(R1)
                MOVE    -1, R10                 ; R0 < R1
                RBRA    _DIRBR_RET, 1
_DIRBR_R1       MOVE    1, R10                  ; R0 > R1
                RBRA    _DIRBR_RET, 1

                ; case-insensitive comparison (because we are comparing
                ; upper case versions of the names)
_DIRBR_DOCMP    MOVE    R0, R8
                MOVE    R1, R9
                SYSCALL(strcmp, 1)

_DIRBR_RET      ADD     R4, SP                  ; restore stack pointer

                DECRB                
                MOVE    R0, R8
                MOVE    R1, R9   
                DECRB
                RET

; helper function to check if a string is actually a number
; directory brackets like <this> are ignored, i.e. <123> is a number
; R8: string
; Carry flag C=1 if it is a number, C=0 otherwise
_DIRBR_ISANUM   INCRB

                MOVE    R8, R0                  ; zero-string is not a number
                CMP     0, @R0
                RBRA    _DIRBR_IAN_C0, Z

_DIRBR_IAN_LP   MOVE    @R0++, R1               ; checked until the end..
                RBRA    _DIRBR_IAN_C1, Z        ; ..so it is a number
                CMP     1, R1                   ; ignore if <
                RBRA    _DIRBR_IAN_LP, Z
                CMP     2, R1                   ; ignore if >
                RBRA    _DIRBR_IAN_LP, Z
                CMP     R1, 47                  ; > ASCII 47 means 0...
                RBRA    _DIRBR_IAN_C0, !N       ; no: not a number
                CMP     R1, 57                  ; <= ASCII 57 means ...9
                RBRA    _DIRBR_IAN_C0, N        ; no: not a number
                RBRA    _DIRBR_IAN_LP, 1

_DIRBR_IAN_C1   OR      0x0004, SR              ; is a num: set Carry
                RBRA    _DIRBR_IAN_RET, 1

_DIRBR_IAN_C0   AND     0xFFFB, SR              ; not a num: clear Carry

_DIRBR_IAN_RET  DECRB
                RET

; SLL$S_INSERT filter function which is a wrapper for the user-defined
; function specified for DIRBROWSE_READ. This is a simplification so that
; DIRBROWSE_READ just expects a filter function that compares strings and
; that does not need to be aware of the SLL semantics
_DIRBR_FILTWRAP INCRB

                MOVE    R9, R0                  ; backup R9, R10 & R11
                MOVE    R10, R6                 ; SF_CONTEXT
                MOVE    R11, R7                 ; SF_CONTEXT
        
                ; copy the string to the stack and make it upper case
                ADD     SLL$DATA, R8            ; R8: pointer to string
                SYSCALL(strlen, 1)              ; R9: length of string
                ADD     1, R9

                MOVE    R9, R3                  ; behind string sits flag
                ADD     R8, R3
                MOVE    @R3, R3                 ; R3: file/directory flag

                SUB     R9, SP
                MOVE    R9, R2
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R8
                SYSCALL(str2upper, 1)           ; R8 contains upper string

                MOVE    R3, R9

                ; SF_CONTEXT
                MOVE    SF_CONTEXT, R10
                MOVE    @R10, R10
                MOVE    SF_CONTEXT_DATA, R11
                MOVE    @R11, R11

                ; call filter function (callback function)
                ; R8: filename in upper-case
                ; R9: 0=file/1=directory
                ; R10: SF_CONTEXT
                MOVE    _DIRBR_FILTERFN, R1
                ASUB    @R1, 1

                ADD     R2, SP                  ; restore stack
                MOVE    R0, R9                  ; restore R9, R10 & R11
                MOVE    R6, R10                 ; SF_CONTEXT
                MOVE    R7, R11                 ; SF_CONTEXT
                DECRB
                RET
