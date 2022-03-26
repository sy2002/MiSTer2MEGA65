; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Simple Linked List
;
; Simple linked list implementation for the file browser that is able to do
; a sorted insert.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************


; Simple Linked List: Record Layout

SLL$NEXT        .EQU    0x0000                  ; pointer: next element
SLL$PREV        .EQU    0x0001                  ; pointer: previous element
SLL$DATA_SIZE   .EQU    0x0002                  ; amount of data (words)
SLL$DATA        .EQU    0x0003                  ; pointer: data

SLL$OVRHD_SIZE  .EQU    0x0003                  ; size of the structural
                                                ; overhead other than data

; ----------------------------------------------------------------------------
; Find n elements after or before the given point in the list
; Input:
;   R8: Pointer to any element of the linked list
;   R9: -1: iterate backward  1: iterate forward
;  R10: Amount of elements to iterate
; Output:
;  R11: Target element (result of iteration) or 0, if we iterated too far
; ----------------------------------------------------------------------------

SLL$ITERATE     INCRB
                ; if either the pointer is zero or the iteration mode is
                ; invalid or the iteration amount is zero, return
                CMP     0, R8                   ; input ptr zero?
                RBRA    _SLLIT_RETORG, Z        ; yes: return original (zero)
                CMP     0, R9                   ; iteration amount zero?
                RBRA    _SLLIT_RETORG, Z        ; yes: return original
                CMP     0, R10                  ; nothing to iterate?
                RBRA    _SLLIT_RETORG, Z        ; yes: return original
                CMP     -1, R9                  ; valid R9 (-1)?
                RBRA    _SLLIT_PREV, Z          ; yes: remember and start
                CMP     1, R9                   ; another valid R9 (1)?
                RBRA    _SLLIT_NEXT, Z          ; yes: remember and start
                RBRA    _SLLIT_RET0, 1          ; no: return 0

                ; R7: depending on if we are iterating forward or backward:
                ; contains the address to be added to the SLL element to
                ; extract either the NEXT or the PREV pointer
_SLLIT_PREV     MOVE    SLL$PREV, R7            ; -1: iterate backward
                RBRA    _SLLIT_START, 1
_SLLIT_NEXT     MOVE    SLL$NEXT, R7            ; +1: iterate forward

                ; iterate through the list by the given amount
                ; return 0 in case we cross boundaries                
_SLLIT_START    MOVE    R8, R0                  ; R0: iteration pointer
                MOVE    R10, R1                 ; R1: amount of iterations

_SLLIT_ITERATE  ADD     R7, R0                  ; ptr. to next/prev element
                MOVE    @R0, R0                 ; try to go to next element                
                RBRA    _SLLIT_RET0, Z          ; no next element? return 0!
                SUB     1, R1                   ; one less iteration
                RBRA    _SLLIT_ITERATE, !Z

                MOVE    R0, R11                 ; return target element
                RBRA    _SLLIT_RET, 1

_SLLIT_RETORG   MOVE    R8, R11                 ; return the original R8
                RBRA    _SLLIT_RET, 1
_SLLIT_RET0     XOR     R11, R11                ; return zero
_SLLIT_RET      DECRB
                RET

; ----------------------------------------------------------------------------
; Find last element and count the amount of elements
; Input:
;   R8: Pointer to head of linked list
; Output:
;   R9: Pointer to last element
;  R10: Amount of elements
; ----------------------------------------------------------------------------

SLL$LASTNCOUNT  INCRB

                MOVE    R8, R9                  ; R9: pointer to last element
                XOR     R10, R10                ; R10: amount of elements

                CMP     0, R8                   ; head is null
                RBRA    _SLLLNC_RET, Z

_SLLLNC_LOOP    ADD     1, R10                  ; one more element
                MOVE    R9, R0                  ; remember element
                ADD     SLL$NEXT, R9            ; next element available?
                MOVE    @R9, R9
                RBRA    _SLLLNC_RETELM, Z       ; no: return
                RBRA    _SLLLNC_LOOP, 1         ; yes: next element

_SLLLNC_RETELM  MOVE    R0, R9                  ; return last element
_SLLLNC_RET     DECRB
                RET

; ----------------------------------------------------------------------------
; Sorted Insert: Insert the new element at the right position
;
; Input
;   R8: Pointer to head of linked list, zero if this is the first element
;   R9: Pointer to new element
;  R10: Pointer to a COMPARE function that returns negative if (S0 < S1),
;       zero if (S0 == S1), positive if (S0 > S1). These semantic are
;       basically compatible with STR$CMP, but instead of expecting pointers
;       to two strings, this compare function is expecting two pointers to
;       SLL records, while the pointer to the first one is given in R8 and
;       treated as "S0" and the second one in R9 and treated as "S1".
;       R10 is overwritten by the return value
;  R11: Pointer to an optional FILTER function that returns 0, if the current
;       element is OK and shall be inserted and 1, if the current element
;       shall be filtered, i.e. not inserted. R8 contains the element-pointer
;       and R8 is also used as return value, i.e. R8 is overwritten.
;
; Output:
;   R8: (New) head of linked list
; ----------------------------------------------------------------------------

SLL$S_INSERT    INCRB
                MOVE    R9, R0
                MOVE    R10, R1
                MOVE    R11, R2
                INCRB

                MOVE    R8, R0                  ; R0: head of linked list
                MOVE    R9, R1                  ; R1: new element
                MOVE    R0, R2                  ; R2: curr. elm to be checked                
                MOVE    R10, R7                 ; R7: ptr to compare func.

                ; apply filter
                CMP     0, R11                  ; filter function provided?
                RBRA    _SLLSI_NOFILTER, Z      ; no: continue
                MOVE    R1, R8                  ; yes: call filter function
                ASUB    R11, 1
                CMP     1, R8                   ; filter current element?
                RBRA    _SLLSI_OLDHEAD, Z       ; yes: return old head

                ; if the new element is the first element, then we can
                ; directly return
_SLLSI_NOFILTER CMP     0, R0                   ; head = zero?
                RBRA    _SLLSI_LOOP, !Z         ; no: go on
                MOVE    R1, R8                  ; yes: return new elm has head
                RBRA    _SLLSI_RET, 1

                ; iterate through the linked list:
                ; 1. check if the new element is smaller than the existing
                ;    element and if yes, then insert it before the existing
                ;    element
                ; 2. if the existing element was the head, then set new head
_SLLSI_LOOP     MOVE    R1, R8                  ; R8: "S0", new elm
                MOVE    R2, R9                  ; R9: "S1", existing elm
                ASUB    R7, 1                   ; compare: S0 < S1?
                CMP     0, R10                  ; R10 is neg. if S0 < S1
                RBRA    _SLLSI_INSERT, V        ; yes: insert new elm here
                MOVE    R2, R3                  ; go to next element
                ADD     SLL$NEXT, R3
                MOVE    @R3, R3
                RBRA    _SLLSI_EOL, Z           ; end of list reached?
                MOVE    R3, R2                  ; no: proceed to next element
                RBRA    _SLLSI_LOOP, 1

                ; end of list reached: insert new element there and return
                ; original head
_SLLSI_EOL      MOVE    R2, R3                  ; R3: remember R2 for PREV
                ADD     SLL$NEXT, R2            ; store address of new elm..
                MOVE    R1, @R2                 ; ..as NEXT elm of R2
                MOVE    R1, R4                  ; store address of old elm..
                ADD     SLL$PREV, R4            ; as PREV elm of R1
                MOVE    R3, @R4
                MOVE    R1, R4                  ; NEXT pointer is null..
                ADD     SLL$NEXT, R4            ; ..because there is no NEXT
                MOVE    0, @R4
                MOVE    R0, R8                  ; return head
                RBRA    _SLLSI_RET, 1

                ; insert the new element before the current element and
                ; check if it is now the new head
_SLLSI_INSERT   MOVE    R2, R3                  ; add new elm as PREV of old
                ADD     SLL$PREV, R3
                MOVE    @R3, R4                 ; remember old PREV
                MOVE    R1, @R3
                MOVE    R1, R3                  ; add old elm as NEXT of new
                ADD     SLL$NEXT, R3
                MOVE    R2, @R3
                MOVE    R1, R3                  ; use old PREV as new PREV..
                ADD     SLL$PREV, R3            ; ..of new elm
                MOVE    R4, @R3
                MOVE    R4, R3                  ; use new elm as NEXT of old..
                ADD     SLL$NEXT, R3            ; ..PREV
                MOVE    R1, @R3

                CMP     R2, R0                  ; was the old elm the head?
                RBRA    _SLLSI_NEWHEAD, Z
_SLLSI_OLDHEAD  MOVE    R0, R8                  ; no: return the old head
                RBRA    _SLLSI_RET, 1
_SLLSI_NEWHEAD  MOVE    R1, R8                  ; yes: return the new head

_SLLSI_RET      DECRB
                MOVE    R0, R9
                MOVE    R1, R10
                MOVE    R2, R11
                DECRB
                RET
