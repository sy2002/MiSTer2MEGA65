; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Virtual Drives
;
; Drive mounting logic according to MiSTers "SD" interface (see vdrives.vhd).
; The file vdrives.asm needs the environment of shell.asm.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Initialize library
; ----------------------------------------------------------------------------

; use the sysinfo device to initialize the vdrives system:
; get the amount of virtual drives, the device id of the vdrives.vhd device
; and an array of RAM buffers for the disk images
VD_INIT         SYSCALL(enter, 1)

                ; initialize the double-indirectly located file handles for
                ; the virtual drive system
                MOVE    HNDL_VD_FILES, R8
                MOVE    VDRIVES_MAX, R9
_VDI_L1         MOVE    @R8++, R0               ; double indirection leads..
                MOVE    0, @R0                  ; to the data of the file hdl
                SUB     1, R9
                RBRA    _VDI_L1, !Z

                ; make sure to initialize also in case of zero vdrives
                MOVE    OPTM_MNT_STATUS, R8
                MOVE    0, @R8
                MOVE    OPTM_DTY_STATUS, R8
                MOVE    0, @R8

                ; copy data from globals.vhd
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$SYS_INFO, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$SYS_VDRIVES, @R8
                MOVE    VD_NUM, R8
                MOVE    VDRIVES_NUM, R0         ; number of virtual drives
                MOVE    @R8, @R0
                MOVE    @R0, R0
                MOVE    R0, R7                  ; R7: remember # of vdrives
                MOVE    VDRIVES_MAX, R1
                CMP     R0, R1                  ; vdrives > maximum?
                RBRA    _START_VD, !N           ; no: continue

                MOVE    ERR_FATAL_VDMAX, R8     ; yes: stop core
                MOVE    R0, R9
                RBRA    FATAL, 1

_START_VD       MOVE    VD_DEVICE, R1           ; device id of vdrives.vhd
                MOVE    VDRIVES_DEVICE, R2
                MOVE    @R1, @R2

                CMP     0, R0                   ; no vdrives at all?
                RBRA    _VDI_RET, Z             ; yes: skip the rest

                ; ------------------------------------------------------------
                ; Initializations that are only relevant, if we have at 
                ; least one vdrive
                ; ------------------------------------------------------------

                XOR     R1, R1                  ; loop var for buffer array
                MOVE    VD_RAM_BUFFERS, R2      ; Source data from config.vhd
                MOVE    VDRIVES_BUFS, R3        ; Dest. buf. in shell_vars.asm

_START_VD_CPY_1 MOVE    @R2++, @R3

                RBRA    _START_VD_CPY_F, Z      ; illegal values for buffer..
                CMP     0xEEEE, @R3++           ; ..ptrs indicate that there..
                RBRA    _START_VD_CPY_2, !Z     ; ..are not enough of them:
_START_VD_CPY_F MOVE    ERR_FATAL_VDBUF, R8     ; stop core
                XOR     R9, R9
                RBRA    FATAL, 1

_START_VD_CPY_2 ADD     1, R1
                CMP     R0, R1
                RBRA    _START_VD_CPY_1, !Z

                ; remember current mount status
                RSUB    VD_MNT_ST_SET, 1

                ; retrieve anti-trashing-delay from config.vhd and store
                ; it to the appropriate vdrives register for each drive
                ; @TODO: potential for more flexibility see config.vhd
                MOVE    R7, R6                  ; R6: remember drive count
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$CONFIG, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$CFG_GENERAL, @R8
                MOVE    M2M$CFG_VD_AT_DELAY, R8
                MOVE    @R8, R0                 ; R0: anti-trashing-delay
_START_VD_LP1   SUB     1, R7                   ; walk backwards through drvs
                MOVE    R7, R8
                MOVE    VD_CACHE_FLUSH_DE, R9
                MOVE    R0, R10
                RSUB    VD_DRV_WRITE, 1
                CMP     0, R7
                RBRA    _START_VD_LP1, !Z

                ; retrieve amount of bytes saved in one iteration of the 
                ; background saving (buffer flushing) process
                ; @TODO: similar as above; see config.vhd
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$CONFIG, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$CFG_GENERAL, @R8
                MOVE    M2M$CFG_VD_ITERSIZE, R8
                MOVE    @R8, R0                 ; R0: iteration size in bytes
                MOVE    VDRIVES_ITERSIZ, R1
                XOR     R7, R7
_START_VD_LP2   MOVE    R0, @R1++
                ADD     1, R7
                CMP     R6, R7
                RBRA    _START_VD_LP2, !Z

_VDI_RET        SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Query & setter functions
; ----------------------------------------------------------------------------

; Check if the current mount status is different from the one we remembered
; Returns: Carry=1 if mount status is different (and in this case we remember
; automatically the new status), else Carry=0
; Additionally, returns the actual current mount status in R8
; Important: The mount status is for all drives, LSB=drive 0
VD_MNT_ST_GET   INCRB

                ; skip this function if there are no virtual drives at all
                RSUB    VD_ACTIVE, 1
                RBRA    _VDD_C0, !C

                ; retrieve current mount status
                MOVE    OPTM_MNT_STATUS, R0
                MOVE    VD_DRV_MOUNT, R8
                RSUB    VD_CAD_READ, 1

                ; did it change?
                CMP     @R0, R8
                RBRA    _VDD_C0, Z              ; no: leave with Carry=0

                ; yes: it did change: remember the new status and
                ; return with Carry=1
                MOVE    R8, @R0
                RBRA    _VDD_C1, 1

                ; DECRB and 
                ; RET done via _VDD_C0 and _VDD_C1 

; Remember the current mount status
VD_MNT_ST_SET   INCRB

                ; skip this function if there are no virtual drives at all
                RSUB    VD_ACTIVE, 1
                RBRA    _VD_MNT_ST_SR, !C

                MOVE    R8, R1

                MOVE    OPTM_MNT_STATUS, R0
                MOVE    VD_DRV_MOUNT, R8
                RSUB    VD_CAD_READ, 1
                MOVE    R8, @R0

                MOVE    R1, R8
_VD_MNT_ST_SR   DECRB
                RET

; Check if the write cache of any virtual drive is different from the one
; we remembered (and in this case we remember automatically the new status).
;
; Return Carry=1 if this is the case, else Carry=0. Also returns the actual
; status for each virtual drive as a bit-pattern in R8: LSB=drive 0, bit=0
; means write cache is clearn and bit=1 means write cache is dirty
VD_DTY_ST_GET   INCRB
                MOVE    R8, R0
                MOVE    R9, R1

                RSUB    VD_ACTIVE, 1            ; abort in case of no vdrives
                RBRA    _VDDTYGET_RET, !C

                ; get current status in @R5
                INCRB                           ; DECRB done in _VDDTY_GETINFO
                MOVE    R8, R2                  ; R2: amount of vdrives
                MOVE    SCRATCH_HEX, R5         ; R5: current status
                MOVE    0, @R5                  ; clear scratch buffer
                RSUB    _VDDTY_GETINFO, 1
                MOVE    SCRATCH_HEX, R5         ; due to DECRB in subroutine

                MOVE    OPTM_DTY_STATUS, R6
                CMP     @R5, @R6
                RBRA    _VDDTYGET_C0, Z         ; status did not change

                MOVE    @R5, @R6                ; remember new value (if any)
                MOVE    @R5, R8                 ; return status in R8
                MOVE    R1, R9                  ; restore R9
                RBRA    _VDD_C1, 1              ; return with Carry=1

_VDDTYGET_C0    MOVE    @R5, R8                 ; return status in R8
                MOVE    R1, R9                  ; restore R9
                RBRA    _VDD_C0, 1              ; return with Carry=0

_VDDTYGET_RET   MOVE    R0, R8
                MOVE    R1, R9
                RBRA    _VDD_C0, 1

                ; DECRB and 
                ; RET done via _VDD_C0 and _VDD_C1 

; Remember the write cache status of all virtual drives.
; See explanation of VD_DTY_ST_GET for details
VD_DTY_ST_SET   INCRB
                MOVE    R8, R0
                MOVE    R9, R1

                RSUB    VD_ACTIVE, 1            ; abort in case of no vdrives
                RBRA    _VDDTY_RET, !C
                MOVE    R8, R2                  ; R2: amount of vdrives
                MOVE    OPTM_DTY_STATUS, R5     ; R5: variable: remember stat.
                MOVE    0, @R5

                ; _VDDTY_GETINFO will be called from VD_DTY_ST_GET to
                ; retrieve the actual bitpattern and store it to where
                ; R5 points to
_VDDTY_GETINFO  XOR     R3, R3                  ; R3: current vdrive
                MOVE    1, R4                   ; R4: for set/clr bits

_VDDTY_1        MOVE    R3, R8                  ; read status for drv in R3
                MOVE    VD_CACHE_DIRTY, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8                   ; cache dirty?
                RBRA    _VDDTY_2, !Z            ; no
                OR      R4, @R5                 ; set bit at current pos
                RBRA    _VDDTY_3, 1

_VDDTY_2        MOVE    R4, R6                  ; cache clean: clear bit
                NOT     R6, R6
                AND     R6, @R5

_VDDTY_3        AND     0xFFFD, SR              ; delete X as SHL fills with X
                SHL     1, R4                   ; next bit
                ADD     1, R3
                CMP     R2, R3                  ; all drives handled?
                RBRA    _VDDTY_1, !Z            ; no: continue with next vdrv

_VDDTY_RET      MOVE    R0, R8
                MOVE    R1, R9
                DECRB
                RET

; Check if the virtual drive system is active by checking, if there is at
; least one virtual drive.
;
; Returns: Carry=1 if active, else Carry=0
;          R8: Amount of vdrives
VD_ACTIVE       INCRB

                MOVE    VDRIVES_NUM, R8
                MOVE    @R8, R8
                RBRA    _VDA_C1, !Z
                AND     0xFFFB, SR              ; clear Carry
                RBRA    _VDA_RET, 1

_VDA_C1         OR      0x0004, SR              ; set Carry

_VDA_RET        DECRB
                RET

; Return the menu group ID of a single-select menu item that corresponds
; to the given virtual drive ID
;
; The first menu item in config.vhd with a OPTM_G_MOUNT_DRV flag is drive 0,
; the next one drive 1, etc.
;
; Input:        R8: virtual drive ID
; Output:       Carry=1 if any menu item is associated with virtual drive ID
;               R8: menu group ID, only valid if Carry=1
;               R9: menu item index starting from 0 for the first item
VD_MENGRP       INCRB

                XOR     R0, R0                  ; R0: current menu item index
                MOVE    -1, R1                  ; R1: vdrive counter
                MOVE    OPTM_ICOUNT, R2         ; R2: amount of menu items              
                MOVE    @R2, R2

                MOVE    M2M$RAMROM_DEV, R3      ; select configuration device
                MOVE    M2M$CONFIG, @R3
                MOVE    M2M$RAMROM_4KWIN, R3    ; select drv. mount items
                MOVE    M2M$CFG_OPTM_MOUNT, @R3
                MOVE    M2M$RAMROM_DATA, R3     ; R3: drive mount items

_VDMENGRP_1     CMP     1, @R3                  ; current item a drive?
                RBRA    _VDMENGRP_2, !Z         ; no
                ADD     1, R1                   ; yes: increase vdrive counter
                CMP     R8, R1                  ; found vdrive we look for?
                RBRA    _VDMENGRP_3, Z

_VDMENGRP_2     ADD     1, R3                   ; next item in vdrive array
                ADD     1, R0                   ; next menu item index
                CMP     R0, R2                  ; R0=R2 means one itm too much
                RBRA    _VDMENGRP_4, Z
                RBRA    _VDMENGRP_1, 1

                ; success
_VDMENGRP_3     MOVE    M2M$RAMROM_4KWIN, R4    ; select drv. mount items
                MOVE    M2M$CFG_OPTM_GROUPS, @R4
                MOVE    @R3, R8                 ; R8: group ID
                MOVE    R0, R9                  ; R9: index
                RBRA    _VDD_C1, 1

                ; failure
_VDMENGRP_4     MOVE    0xEEEE, R8
                MOVE    0xEEEE, R9
                RBRA    _VDD_C0, 1

                ; DECRB and 
                ; RET done via _VDD_C0 and _VDD_C1

; Return the drive number associated with a single-select menu item that
; as a unique menu group ID
;
; The first menu item in config.vhd with a OPTM_G_MOUNT_DRV flag is drive 0,
; the next one drive 1, etc.
;
; Input:   R8: menu item (menu group ID)
; Returns: Carry=1 if any drive number is associated with a menu item
;          R8: drive number, starting with 0, only valid if Carry=1
VD_DRVNO        INCRB

                ; step 1: find the menu item, i.e. get the index relative
                ; to the beginning of the data structure
                MOVE    OPTM_DATA, R0
                MOVE    @R0, R0
                ADD     OPTM_IR_GROUPS, R0
                MOVE    @R0, R0                 ; R0: start of data structure
                MOVE    OPTM_ICOUNT, R1
                MOVE    @R1, R1                 ; R1: amount of menu items
                XOR     R2, R2                  ; R2: index of drv. men. item

_VDD_1          CMP     R8, @R0++
                RBRA    _VDD_3, Z               ; menu item found
                ADD     1, R2
                SUB     1, R1
                RBRA    _VDD_1, !Z              ; check next item
_VDD_2          MOVE    0xFFFF, R8
                RBRA    _VDD_C0, 1              ; item not found

                ; step 2: check, if the menu item is a drive and find out the
                ; drive number by counting; R2 contains the index of the menu
                ; item that we are looking for
_VDD_3          XOR     R1, R1                  ; R1: drive number, if any
                XOR     R7, R7                  ; R7: index number
                MOVE    M2M$RAMROM_DEV, R0      ; select configuration device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; select drv. mount items
                MOVE    M2M$CFG_OPTM_MOUNT, @R0
                MOVE    M2M$RAMROM_DATA, R0     ; R0: ptr to data structure
_VDD_3A         CMP     R7, R2                  ; did we reach the item?
                RBRA    _VDD_5, !Z              ; no: continue to search
_VDD_4          CMP     1, @R0++                ; is the item a drive?
                RBRA    _VDD_2, !Z              ; no: return with C=0
                MOVE    R1, R8                  ; return drive number...
                RBRA    _VDD_C1, 1              ; ...with C=1
_VDD_5          CMP     1, @R0++                ; item at curr idx. drive?
                RBRA    _VDD_6, !Z              ; no
                ADD     1, R1                   ; count item as drive
_VDD_6          ADD     1, R7                   ; next index position
                RBRA    _VDD_3A, 1

                ; this code is re-used by other functions, do not change
_VDD_C0         AND     0xFFFB, SR              ; clear Carry
                RBRA    _VDD_RET, 1
_VDD_C1         OR      0x0004, SR              ; set Carry

_VDD_RET        DECRB
                RET

; Checks, if the given drive is mounted
;
; Input:   R8: drive number
; Returns: Carry=1 if drive is mounted
;          R8: drive number (unchanged)
VD_MOUNTED      INCRB

                MOVE    R8, R1
                MOVE    1, R0                   ; probe to check drive
                AND     0xFFFD, SR              ; clear X
                SHL     R8, R0                  ; drive 0 = LSB
                MOVE    VD_DRV_MOUNT, R8        ; get bitpattern of mounted..
                RSUB    VD_CAD_READ, 1          ; ..drives
                MOVE    R8, R2
                MOVE    R1, R8                  ; restore R8 (original drv. #)
                AND     R0, R2
                RBRA    _VDD_C1, !Z             ; yes: drive is mounted
                RBRA    _VDD_C0, 1              ; no: drive is not mounted

                ; DECRB and 
                ; RET done via _VDD_C0 and _VDD_C1

; Strobes the "image mount" signal: This is used to mount and to unmount
; drives: When the "image size" registers are non-zero, then the drive is
; mounted, otherwise it is held is reset state
;
; Input:   R8: drive number
;          R9/R10: low/high words of image size
;          R11: 1=read only
;          R12: disk image type
; Returns: R8 .. R12: unchanged
VD_STROBE_IM    INCRB

                ; save original register values
                MOVE    R8, R0                  ; R0: drive number
                MOVE    R9, R1                  ; R1: file size: low word
                MOVE    R10, R2                 ; R2: file size: high word
                MOVE    R11, R3                 ; R3: read-only flag
                MOVE    R12, R4                 ; R4: disk image type

                ; set file size, read-only and disk image type registers
                MOVE    VD_SIZE_L, R8
                MOVE    R1, R9
                RSUB    VD_CAD_WRITE, 1
                MOVE    VD_SIZE_H, R8
                MOVE    R2, R9
                RSUB    VD_CAD_WRITE, 1
                MOVE    VD_RO, R8
                MOVE    R3, R9
                RSUB    VD_CAD_WRITE, 1
                MOVE    VD_TYPE, R8
                MOVE    R4, R9
                RSUB    VD_CAD_WRITE, 1

                ; create bitmask for setting and deleting image mount bit
                MOVE    1, R6
                AND     0xFFFD, SR              ; clear X
                SHL     R0, R6                  ; R6: set flag, drive 0 = LSB
                NOT     R6, R7                  ; R7: used to clear flag

                ; get current bitmask and then strobe the flag
                MOVE    VD_IMG_MOUNT, R8
                RSUB    VD_CAD_READ, 1
                OR      R6, R8                  ; set flag
                MOVE    R8, R9
                MOVE    VD_IMG_MOUNT, R8
                RSUB    VD_CAD_WRITE, 1         ; set flag in register
                AND     R7, R9                  ; delete flag
                RSUB    VD_CAD_WRITE, 1         ; delete flag in register

                ; restore original register values
                MOVE    R0, R8              
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12

                DECRB
                RET

; VDrives device: Read a value from the control and data registers
;
; Input:   R8: Register number
; Returns: R8: Value
VD_CAD_READ     INCRB

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    VDRIVES_DEVICE, R1
                MOVE    @R1, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    VD_WIN_CAD, @R0
                MOVE    @R8, R8

                DECRB
                RET

; VDrives device: Write a value to the control and data registers
;
; Input:   R8: Register number
;          R9: Value
; Returns: Nothing, leaves R8, R9 unchanged
VD_CAD_WRITE    INCRB

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    VDRIVES_DEVICE, R1
                MOVE    @R1, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    VD_WIN_CAD, @R0
                MOVE    R9, @R8

                DECRB
                RET

; VDrives device: Read a value from the virtual drive specific registers
; Input:   R8: Virtual drive number
;          R9: Register number
; Output:  R8: Value
VD_DRV_READ     INCRB

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    VDRIVES_DEVICE, R1
                MOVE    @R1, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    VD_WIN_DRV, @R0
                ADD     R8, @R0                 ; drive windows are ascending
                MOVE    @R9, R8

                DECRB
                RET

; VDrives device: Write a value to the virtual drive specific registers
; Input:   R8:  Virtual drive number
;          R9:  Register number
;          R10: Value
; Output:  Nothing, leaves R8..R10 unchanged
VD_DRV_WRITE    INCRB

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    VDRIVES_DEVICE, R1
                MOVE    @R1, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    VD_WIN_DRV, @R0
                ADD     R8, @R0                 ; drive windows are ascending
                MOVE    R10, @R9

                DECRB
                RET
