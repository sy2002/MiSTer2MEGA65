; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Cartridges and ROMs
;
; System to handle manually and automatically loaded cartridges and ROMs.
; Manually means via the OSM (configured in config.vhd) and automatically
; means via the list that is configured in globals.vhd.
;
; The file crts-and-roms.asm needs the environment of shell.asm.
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Initialize library
; ----------------------------------------------------------------------------

CRTROM_INIT     SYSCALL(enter, 1)

                ; initialize the double-indirectly located file handles for
                ; the CRT/ROM loading system                
                MOVE    HNDL_RM_FILES, R8
                MOVE    CRTROM_MAN_MAX, R9
_CRTRI_L1       MOVE    @R8++, R0
                MOVE    0, @R0
                SUB     1, R9
                RBRA    _CRTRI_L1, !Z

                ; initialize records and flags
                XOR     R10, R10                ; R10: memset zero                
                MOVE    CRTROM_MAN_MAX, R9      ; R9: amount
                MOVE    CRTROM_MAN_LDF, R8
                SYSCALL(memset, 1)
                MOVE    CRTROM_MAN_DEV, R8
                SYSCALL(memset, 1)
                MOVE    CRTROM_MAN_4KS, R8
                SYSCALL(memset, 1)
                MOVE    CRTROM_AUT_MAX, R9
                MOVE    CRTROM_AUT_LDF, R8
                SYSCALL(memset, 1)
                MOVE    CRTROM_AUT_4KS, R8
                SYSCALL(memset, 1)
                MOVE    CRTROM_AUT_MOD, R8
                SYSCALL(memset, 1)
                MOVE    CRTROM_AUT_NAM, R8
                SYSCALL(memset, 1)

                ; use the sysinfo device to get the relevant data from
                ; globals.vhd to initialize the CRT/ROM loading system
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$SYS_INFO, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$SYS_CRTSANDROMS, @R8
                MOVE    CRTROM_MAN_NUM_A, R8
                MOVE    CRTROM_MAN_NUM, R0      ; num. manually ld. CRTs/ROMs
                MOVE    @R8, @R0
                MOVE    @R8, R0

                CMP     R0, CRTROM_MAN_MAX      ; illegal amount of man. ld.
                RBRA    _CRTRI_L2A, !N
                MOVE    ERR_F_CR_M_CNT, R8
                MOVE    R0, R9
                RBRA    FATAL, 1

_CRTRI_L2A      MOVE    CRTROM_AUT_NUM_A, R8    ; num. auto-load ROMs
                MOVE    CRTROM_AUT_NUM, R1
                MOVE    @R8, @R1
                MOVE    @R8, R1

                CMP     R1, CRTROM_AUT_MAX      ; illegal amount of aut. ld.
                RBRA    _CRTRI_L2B, !N
                MOVE    ERR_F_CR_M_CNT, R8
                MOVE    R1, R9
                RBRA    FATAL, 1

                ; ------------------------------------------------------------
                ; Initializations that are only relevant, if we have at 
                ; least one manually loadable CRT/ROM
                ; ------------------------------------------------------------

                ; skip the rest in case of inactive man-load CRT/ROM system
_CRTRI_L2B      CMP     0, R0
                RBRA    _CRTRI_A1, Z                

                ; retrieve the byte streaming devices, decode their type and
                ; store their device IDs and 4k window start positions
                MOVE    CRTROM_MAN_BUFFERS, R1
                MOVE    CRTROM_MAN_DEV, R6      ; R6: array of device IDs
                MOVE    CRTROM_MAN_4KS, R7      ; R7: array of 4k windows

_CRTRI_L3       MOVE    @R1++, R2               ; R2: type
                MOVE    @R1++, R3               ; R3: device id or 4k window
                XOR     R4, R4                  ; R4: default device is zero
                XOR     R5, R5                  ; R5: std 4k window is zero            

                CMP     CRTROM_TYPE_DEVICE, R2  ; QNICE device?
                RBRA    _CRTRI_L4, !Z           ; no
                MOVE    R3, R4                  ; in this case: R3=device id
                RBRA    _CRTRI_L7, 1

_CRTRI_L4       CMP     CRTROM_TYPE_HYPRAM, R2  ; HyperRAM device?
                RBRA    _CRTRI_L5, !Z           ; no
                MOVE    M2M$HYPERRAM, R4        ; use M2M HyperRAM device
                MOVE    R3, R5                  ; start address: 4k window
                RBRA    _CRTRI_L7, 1

_CRTRI_L5       CMP     CRTROM_TYPE_SDRAM, R2   ; SDRAM device?
                RBRA    _CRTRI_L6, !Z           ; no
                                                ; @TODO: future R4 boards
                                                ; for now: fatal

_CRTRI_L6       MOVE    ERR_F_CR_M_TYPE, R8     ; Fatal: Illegal type
                MOVE    R2, R9
                RBRA    FATAL, 1

_CRTRI_L7       MOVE    R4, @R6++               ; store device id in array
                MOVE    R5, @R7++               ; store 4k win in array

                CMP     0xEEEE, R5
                RBRA    _CRTRI_L8, !Z
                MOVE    ERR_F_CR_M_TYPE, R8
                XOR     R9, R9
                RBRA    FATAL, 1

_CRTRI_L8       SUB     1, R0
                RBRA    _CRTRI_L3, !Z

                ; set all CSRs of all CRT/ROM devices to "idle"
                MOVE    CRTROM_MAN_NUM, R0
                MOVE    @R0, R0
                MOVE    CRTROM_MAN_DEV, R1
                MOVE    CRTROM_CSR_STATUS, R9
                MOVE    CRTROM_CSR_ST_IDLE, R10            
_CRTRI_L9       MOVE    @R1++, R8
                RSUB    CRTROM_CSR_W, 1
                SUB     1, R0
                RBRA    _CRTRI_L9, !Z

                ; ------------------------------------------------------------
                ; Auto-load ROMs
                ; ------------------------------------------------------------

                ; skip the rest in case of inactive man-load ROM system
_CRTRI_A1       MOVE    CRTROM_AUT_NUM, R0
                MOVE    @R0, R0                 ; R0: amount of auto-load ROMs
                RBRA    _CRTRI_RET, Z

                ; log auto-load ROMs to serial terminal
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    LOG_STR_ARSTART, R8
                SYSCALL(puts, 1)
                XOR     R12, R12                ; R12: ROM cntr for log output

                ; retrieve the byte streaming devices, decode their type and
                ; store their device IDs, 4k window start positions, the
                ; mode (mandatory or optional) and the pointer to the
                ; file-name in the CRTROM_AUT_* shell variables
                MOVE    M2M$RAMROM_DEV, R1
                MOVE    M2M$SYS_INFO, @R1
                MOVE    M2M$RAMROM_4KWIN, R1
                MOVE    M2M$SYS_CRTSANDROMS, @R1
                MOVE    CRTROM_AUT_BUFFERS, R1  ; R1: data from globals.vhd
                MOVE    CRTROM_AUT_DEV, R2      ; R2: array of device IDs
                MOVE    CRTROM_AUT_4KS, R3      ; R3: array of 4k windows
                MOVE    CRTROM_AUT_MOD, R4      ; R4: array of modes
                MOVE    CRTROM_AUT_NAM, R5      ; R5: array of name pointers

                ; log to serial terminal
_CRTRI_A_LOOP   MOVE    LOG_STR_ARLINE1, R8
                SYSCALL(puts, 1)
                MOVE    R12, R8
                SYSCALL(puthex, 1)
                MOVE    LOG_STR_ARLINE2, R8
                SYSCALL(puts, 1)

                MOVE    @R1++, R8               ; get entry type..
                SYSCALL(puthex, 1)              ; ..and log it
                CMP     CRTROM_TYPE_DEVICE, R8  ; Is it a QNICE device?
                RBRA    _CRTRI_A2, !Z           ; no
                MOVE    @R1++, @R2              ; yes: store device id..
                MOVE    0, @R3                  ; ..and set 4k window to zero
                RBRA    _CRTRI_A5, 1

_CRTRI_A2       CMP    CRTROM_TYPE_HYPRAM, R2   ; HyperRAM device?
                RBRA    _CRTRI_A3, !Z           ; no
                MOVE   M2M$HYPERRAM, @R2        ; yes: use HyperRAM dev. id..
                MOVE   @R1++, @R3               ; ..and store the 4k window

_CRTRI_A3       CMP     CRTROM_TYPE_SDRAM, R2   ; SRAM device?
                RBRA   _CRTRI_A4, !Z            ; no
                                                ; @TODO: future R4 boards
                                                ; for now: fatal

_CRTRI_A4       MOVE    R8, R9                  ; illegal entry type
                MOVE    ERR_F_CR_A_TYPE, R8
                RBRA    FATAL, 1

                ; log device and 4k window and advance record write pointers
_CRTRI_A5       MOVE    LOG_STR_ARLINE3, R8
                SYSCALL(puts, 1)
                MOVE    @R2++, R8
                SYSCALL(puthex, 1)
                MOVE    LOG_STR_ARLINE4, R8
                SYSCALL(puts, 1)
                MOVE    @R3++, R8
                SYSCALL(puthex, 1)

                ; determine mode
                MOVE    @R1++, R7
                CMP     CRTROM_TYPE_MNDTRY, R7
                RBRA    _CRTRI_A6, !Z           ; not mandatory
                MOVE    LOG_STR_ARLINE5, R8     ; yes: mandatory: log it
                SYSCALL(puts, 1)
                RBRA    _CRTRI_A8, 1
_CRTRI_A6       CMP     CTRROM_TYPE_OPTNL, R7
                RBRA    _CRTRI_A7, !Z           ; not optional
                MOVE    LOG_STR_ARLINE6, R8     ; yes: optional: log it
                SYSCALL(puts, 1)
                RBRA    _CRTRI_A8, 1
_CRTRI_A7       RBRA    _CRTRI_A4, 1            ; illegal mode: fatal
_CRTRI_A8       MOVE    R7, @R4++               ; store mode to record array

                ; store filename pointer and log filename
                ; there is no really good way to check the validity so this
                ; is a critical point for the user in globals.vhd
                MOVE    @R1++, R8
                MOVE    R8, @R5++
                CMP     0xEEEE, R8              ; data corruption?
                RBRA    _CRTRI_A9, !Z           ; no
                RBRA    _CRTRI_A4, 1            ; yes: fatal
_CRTRI_A9       MOVE    R8, R6
                MOVE    LOG_STR_ARLINE7, R8
                SYSCALL(puts, 1)
                MOVE    CRTROM_AUT_FILES, R7
                ADD     R7, R6
                MOVE    R6, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                ADD     1, R12                  ; next iteration
                SUB     1, R0            
                RBRA    _CRTRI_A_LOOP, !Z

_CRTRI_RET      SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Query & setter functions
; ----------------------------------------------------------------------------

; Check if the manual loading system is active by checking, if there is at
; least one manually loadable CRT/ROM
;
; Returns: Carry=1 if active, else Carry=0
;          R8: Amount of manually loadable CRTs/ROMs
CRTROM_ACTIVE   INCRB

                MOVE    CRTROM_MAN_NUM, R8
                MOVE    @R8, R8
                RBRA    _CRA_C1, !Z
                AND     0xFFFB, SR              ; clear Carry
                RBRA    _CRA_RET, 1

_CRA_C1         OR      0x0004, SR              ; set Carry

_CRA_RET        DECRB
                RET

; Return the number of the manually loadable ROM or CRT that
; is associated with a single-select menu item that as a unique menu group ID
;
; The first menu item in config.vhd with a OPTM_G_LOAD_ROM flag is ROM/CRT 0,
; the next one ROM/CRT 1, etc.
;
; Input:   R8: menu item (menu group ID)
; Returns: Carry=1 if any CRT/ROM is associated with a menu item
;          R8: CRT/ROM number, starting with 0, only valid if Carry=1
CRTROM_M_NO     INCRB

                ; step 1: find the menu item, i.e. get the index relative
                ; to the beginning of the data structure
                MOVE    OPTM_DATA, R0
                MOVE    @R0, R0
                ADD     OPTM_IR_GROUPS, R0
                MOVE    @R0, R0                 ; R0: start of data structure
                MOVE    OPTM_ICOUNT, R1
                MOVE    @R1, R1                 ; R1: amount of menu items
                XOR     R2, R2                  ; R2: index of drv. men. item

_CRMN_1         CMP     R8, @R0++
                RBRA    _CRMN_3, Z              ; menu item found
                ADD     1, R2
                SUB     1, R1
                RBRA    _CRMN_1, !Z             ; check next item
_CRMN_2         MOVE    0xFFFF, R8
                RBRA    _CRMN_C0, 1             ; item not found

                ; step 2: check, if the menu item is a CRT/ROM loader and find
                ; out the CRT/ROM load number by counting; R2 contains the
                ; index of the menu item that we are looking for
_CRMN_3         XOR     R1, R1                  ; R1: CRT/ROM number, if any
                XOR     R7, R7                  ; R7: index number
                MOVE    M2M$RAMROM_DEV, R0      ; select configuration device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; select drv. mount items
                MOVE    M2M$CFG_OPTM_CRTROM, @R0
                MOVE    M2M$RAMROM_DATA, R0     ; R0: ptr to data structure
_CRMN_3A        CMP     R7, R2                  ; did we reach the item?
                RBRA    _CRMN_5, !Z             ; no: continue to search
_CRMN_4         CMP     1, @R0++                ; is the item a CRT/ROM?
                RBRA    _CRMN_2, !Z             ; no: return with C=0
                MOVE    R1, R8                  ; return CRT/ROM number...
                RBRA    _CRMN_C1, 1             ; ...with C=1
_CRMN_5         CMP     1, @R0++                ; item at curr idx. CRT/ROM?
                RBRA    _CRMN_6, !Z             ; no
                ADD     1, R1                   ; count item as CRT/ROM
_CRMN_6         ADD     1, R7                   ; next index position
                RBRA    _CRMN_3A, 1

                ; this code is re-used by other functions, do not change
_CRMN_C0        AND     0xFFFB, SR              ; clear Carry
                RBRA    _CRMN_RET, 1
_CRMN_C1        OR      0x0004, SR              ; set Carry

_CRMN_RET       DECRB
                RET


; Check if the CRT/ROM item number in R8 is valid: Goes fatal if no and
; uses the error code in R9 in this case
CRTROM_CHK_NO   INCRB

                ; Unstable system state: R8 is larger than the amount of
                ; available CRT/ROM menu items in config.vhd
                MOVE    CRTROM_MAN_NUM, R0
                MOVE    @R0, R0
                CMP     R8, R0
                RBRA    _CRRMCN_RET, !N
                MOVE    ERR_FATAL_INST, R8
                RBRA    FATAL, 1

_CRRMCN_RET     DECRB
                RET

; Return the menu group ID and the index within the menu of the manually
; loadable ROM or CRT with a given CRT/ROM id.
;
; The first menu item in config.vhd with a OPTM_G_LOAD_ROM flag is ROM/CRT 0,
; the next one ROM/CRT 1, etc.
;
; Input:   R8: CRT/ROM id
; Returns: Carry=1 if any menu item is associated with this CRT/ROM ID
;                  else Carry=0
;          Only valid if Carry=1:
;          R8: menu group ID
;          R9: menu index
CRTROM_M_GI     INCRB

                XOR     R0, R0                  ; R0: current menu item index
                MOVE    -1, R1                  ; R1: CRT/ROM counter
                MOVE    OPTM_ICOUNT, R2         ; R2: amount of menu items
                MOVE    @R2, R2
                
                MOVE    M2M$RAMROM_DEV, R3      ; select configuration device
                MOVE    M2M$CONFIG, @R3
                MOVE    M2M$RAMROM_4KWIN, R3    ; select CRT/ROM menu items
                MOVE    M2M$CFG_OPTM_CRTROM, @R3
                MOVE    M2M$RAMROM_DATA, R3     ; R3: CRT/ROM items

_CRTRMGI_1      CMP     1, @R3                  ; current item a CRT/ROM?
                RBRA    _CRTRMGI_2, !Z          ; no
                ADD     1, R1                   ; yes: inc. CRT/ROM counter
                CMP     R8, R1                  ; found CRT/ROM we look for?
                RBRA    _CRTRMGI_3, Z

_CRTRMGI_2      ADD     1, R3                   ; next item in vdrive array
                ADD     1, R0                   ; next menu item index
                CMP     R0, R2                  ; R0=R2 means one itm too much
                RBRA    _CRTRMGI_4, Z
                RBRA    _CRTRMGI_1, 1

                ; success
_CRTRMGI_3      MOVE    M2M$RAMROM_4KWIN, R4    ; select drv. mount items
                MOVE    M2M$CFG_OPTM_GROUPS, @R4
                MOVE    @R3, R8                 ; R8: group ID
                MOVE    R0, R9                  ; R9: index
                RBRA    _CRMN_C1, 1             ; set Carry and return

                ; failure
_CRTRMGI_4      MOVE    0xEEEE, R8
                MOVE    0xEEEE, R9
                RBRA    _CRMN_C0, 1             ; clear Carry and return

                ; DECRB and 
                ; RET done via _CRMN_C0 and _CRMN_C1

; Write to the control and status register of a CRT/ROM device
; Input:
;   R8: device id
;   R9: CSR register
;   R10: value
; Output: none, all registers remain unchanged
CRTROM_CSR_W    INCRB

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    R8, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    CRTROM_CSR_4KWIN, @R0
                MOVE    R10, @R9

                DECRB
                RET

; Read from the control and status register of a CRT/ROM device
; Input:
;   R8: device id
;   R9: CSR register
; Output:
;   R8/R9: unchanged
;   R10: value
CRTROM_CSR_R    INCRB

                MOVE    M2M$RAMROM_DEV, R0
                MOVE    R8, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    CRTROM_CSR_4KWIN, @R0
                MOVE    @R9, R10

                DECRB
                RET

; Read amount of mandatory ROMs
; Returns: Carry=1 if any mandatory ROMs were found else Carry=0
;          R8: Amount of mandatory ROMs (zero in case of Carry=0)
CRTROM_MNDTRY_R INCRB

                MOVE    CRTROM_AUT_NUM, R0
                MOVE    @R0, R0                 ; R0: amount of auto-load ROMs
                MOVE    CRTROM_AUT_MOD, R1      ; R1: mode array
                XOR     R8, R8                  ; R8: amount of mndtry ROMs

_CRMTRY_LOOP    CMP     CRTROM_TYPE_MNDTRY, @R1++
                RBRA    _CRMTRY_OPTNL, !Z       ; not mandatory
                ADD     1, R8                   ; mandatory
_CRMTRY_OPTNL   SUB     1, R0                   ; next iteration
                RBRA    _CRMTRY_LOOP, !Z

                CMP     0, R8
                RBRA    _CRMN_C1, !Z            ; C=1: there are mndtry ROMs
                RBRA    _CRMN_C0, 1             ; C=0: no mandatory ROMs

                ; DECRB and 
                ; RET done via _CRMN_C0 and _CRMN_C1

; Check if the current load status of any manually loadable CRT/ROM is
; different from the one we remembered.
;
; Returns: Carry=1 if load status is different (and in this case we remember
; automatically the new status), else Carry=0
;
; Important: This function is meant to be called repeatedly in case of
; Carry=1 because there might be an additional CRT/ROM status that has
; changed.
;
; Only valid if Carry=1:
; R8: CRT/ROM ID of the manually loadable CRT/ROM which has a changed status
; R9: new status of this very CRT/ROM
CRTROM_MLST_GET INCRB

                ; We can skip this function if there are no manually loadable
                ; CRTs/ROMs at all
                RSUB    CRTROM_ACTIVE, 1
                RBRA    _CRTROM_MLSTGTR, !C 

                ; @TODO: Skip whole function if no man. ld. CRT/ROMs

                MOVE    CRTROM_MAN_NUM, R0      ; R0: amnt of man. ld CRT/ROMs
                MOVE    @R0, R0
                MOVE    CRTROM_MAN_LDF, R1      ; R1: array of rem. ld flgs
                MOVE    CRTROM_MAN_DEV, R2      ; R2: dev ids man. ld CRT/ROM
                XOR     R3, R3                  ; R3: current CRT/ROM ID

_CRTROM_MLSTGT0 MOVE    M2M$RAMROM_DEV, R5      ; switch to CRT/ROM device
                MOVE    @R2++, @R5
                MOVE    M2M$RAMROM_4KWIN, R5
                MOVE    CRTROM_CSR_4KWIN, @R5

                MOVE    CRTROM_CSR_STATUS, R6   ; read actual status and..
                MOVE    @R6, R7
                CMP     CRTROM_CSR_ST_OK, R7    ; ..change R6 to 1 if loaded..
                RBRA    _CRTROM_MLSTGT1, Z      ; ..and 0 if not
                MOVE    0, R6
                RBRA    _CRTROM_MLSTGT2, 1
_CRTROM_MLSTGT1 MOVE    1, R6

_CRTROM_MLSTGT2 CMP     @R1++, R6               ; status still the same?
                RBRA    _CRTROM_MLSTGT3, !Z     ; no: status changed
                ADD     1, R3                   ; yes: the same: iterate
                CMP     R0, R3
                RBRA    _CRTROM_MLSTGT0, !Z

                ; If we arrive here, we have no changes, so Carry=0 and return
                AND     0xFFFB, SR              ; clear Carry
                RBRA    _CRTROM_MLSTGTR, 1      ; return

                ; If we arrive here, then we have changes, so set Carry=1 and
                ; save the new status and return the new status
_CRTROM_MLSTGT3 MOVE    R3, R8                  ; R8=R3: current CRT/ROM ID
                MOVE    R6, R9                  ; R9=R6: new status
                MOVE    CRTROM_MAN_LDF, R1      ; remember new status
                ADD     R3, R1
                MOVE    R6, @R1
                OR      0x0004, SR              ; set Carry

_CRTROM_MLSTGTR DECRB
                RET

; ----------------------------------------------------------------------------
; Handle manual CRT/ROM loading
; Input:
;    R8: CRT/ROM device
;    R9: CRT/ROM id
;   R10: File handle
; Output:
;    R8: 0=OK, otherwise error code
;    R9: 0=OK, otherwise pointer to error string that is only readable,
;              if the correct CRT/ROM device is being set
;   R10: unchanged
; ----------------------------------------------------------------------------

HANDLE_CRTROM_M INCRB

                MOVE    R8, R0                  ; R0: CRT/ROM device
                MOVE    R9, R1                  ; R1: CRT/ROM id
                MOVE    R10, R2                 ; R2: file handle

                ; sanity check the CRT/ROM id
                MOVE    R1, R8
                MOVE    ERR_FATAL_INST5, R9
                RSUB    CRTROM_CHK_NO, 1

                ; log to serial terminal
                MOVE    LOG_STR_ROMPRS, R8
                SYSCALL(puts, 1)

                ; start the parsing of the CRT/ROM by providing the file size
                ; of the loaded CRT/ROM via CSR registers, set CSR status to
                ; OK and set the load flag so that the filename can be shown
                MOVE    R0, R8                  ; R0: CRT/ROM device id
                MOVE    CRTROM_CSR_FS_LO, R9    ; transmit filesize: low
                MOVE    R2, R10
                ADD     FAT32$FDH_SIZE_LO, R10
                MOVE    @R10, R10
                RSUB    CRTROM_CSR_W, 1
                MOVE    CRTROM_CSR_FS_HI, R9    ; transmit filesize: high
                MOVE    R2, R10
                ADD     FAT32$FDH_SIZE_HI, R10
                MOVE    @R10, R10
                RSUB    CRTROM_CSR_W, 1
                MOVE    CRTROM_CSR_STATUS, R9   ; start cartridge parser
                MOVE    CRTROM_CSR_ST_OK, R10
                RSUB    CRTROM_CSR_W, 1
                MOVE    CRTROM_MAN_LDF, R8      ; set "loaded" flag
                ADD     R1, R8
                MOVE    1, @R8

                ; wait until parsing is done and retrieve status
                MOVE    R0, R8
                MOVE    CRTROM_CSR_PARSEST, R9
_HNDLCRTROM_1   RSUB    CRTROM_CSR_R, 1
                CMP     CRTROM_CSR_PT_OK, R10
                RBRA    _HNDLCRTROM_2, Z
                CMP     CRTROM_CSR_PT_ERR, R10
                RBRA    _HNDLCRTROM_3, Z
                RBRA    _HNDLCRTROM_1, 1

_HNDLCRTROM_2   MOVE    LOG_STR_ROMPRSO, R8     ; log OK to serial terminal
                SYSCALL(puts, 1)
                XOR     R8, R8                  ; everything OK, no error
                XOR     R9, R9
                RBRA    _HNDLCRTROM_R, 1

_HNDLCRTROM_3   MOVE    CRTROM_CSR_PARSEE1, R9  ; retrieve error code
                RSUB    CRTROM_CSR_R, 1
                MOVE    R10, R0                 ; R0: error code
                MOVE    CRTROM_CSR_ERR_STRT, R1 ; R1: ptr. to error string
                MOVE    LOG_STR_ROMPRSE, R8     ; log error to serial terminal
                SYSCALL(puts, 1)
                MOVE    R0, R8                  ; log error code
                SYSCALL(puthex, 1)
                MOVE    LOG_STR_ROMPRSC, R8
                SYSCALL(puts, 1)
                MOVE    R1, R8                  ; log error string
                RSUB    LOG_STR, 1
                MOVE    R0, R8                  ; return error code and
                MOVE    R1, R9                  ; error string

_HNDLCRTROM_R   MOVE    R2, R10                 ; R10: unchanged
                DECRB
                RET

; ----------------------------------------------------------------------------
; Perform the automatic loading of ROMs
;
; Goes fatal if a mandatory ROM is missing.
; ----------------------------------------------------------------------------

CRTROM_AUTOLOAD SYSCALL(enter, 1)

                ; We can skip this function if there are no autoload ROMs
                MOVE    CRTROM_AUT_NUM, R0
                MOVE    @R0, R0                 ; R0: amount of autoload ROMs
                RBRA    _CRMA_RET, Z
                XOR     R1, R1                  ; R1: ROM number counter

                ; We assume that CRTROM_AUTOLOAD is called after
                ; HELP_MENU_INIT and we will (re-)use the device handle from
                ; the config file loading (CONFIG_DEVH). But we cannot rely
                ; on CONFIG_DEVH being valid, because the user of the
                ; framework could have switched-off the config file handling
                ; in config.vhd by setting SAVE_SETTINGS to false.
                MOVE    CONFIG_DEVH, R8
                CMP     0, @R8
                RBRA    _CRMA_1, !Z             ; seems to be valid: continue
                RSUB    WAIT_FOR_SD, 1          ; stability workaround
                MOVE    1, R9                   ; partition #1 hardcoded
                SYSCALL(f32_mnt_sd, 1)
                CMP     0, R9                   ; R9=error code; 0=OK
                RBRA    _CRMA_1, Z              ; mount OK: continue

                ; Mount not OK: We will gracefully exit in case that the
                ; core has no mandatory ROMs
                RSUB    CRTROM_MNDTRY_R, 1
                RBRA    _CRMA_MNTFATAL, C       ; fatal: mandatory ROMs
                MOVE    LOG_STR_RNOMNT, R8
                SYSCALL(puts, 1)
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                RBRA    _CRMA_RET, 1
_CRMA_MNTFATAL  MOVE    ERR_F_ATRMNMNT, R8
                RBRA    FATAL, 1

_CRMA_1         MOVE    LOG_STR_ARLINE8, R8
                SYSCALL(puts, 1)
                MOVE    R1, R8
                SYSCALL(puthex, 1)

                ; retrieve file name from globals.vhd and put it on the
                ; stack because the FAT32 routines are changing the device
                ; during their operation
                MOVE    SP, R7                  ; R7: save stack pointer
                MOVE    M2M$RAMROM_DEV, R3
                MOVE    M2M$SYS_INFO, @R3
                MOVE    M2M$RAMROM_4KWIN, R3
                MOVE    M2M$SYS_CRTSANDROMS, @R3
                MOVE    CRTROM_AUT_FILES, R3
                MOVE    CRTROM_AUT_NAM, R4
                ADD     R1, R4
                ADD     @R4, R3                 ; R3 points to filename
                MOVE    R3, R8
                SYSCALL(strlen, 1)
                SUB     R9, SP                  ; free memory on stack..
                SUB     1, SP                   ; ..and include zero term.
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R10                 ; R10: name for f32_fopen
                MOVE    R9, R6                  ; R6: remember name for fatal
                MOVE    CONFIG_DEVH, R8
                MOVE    CRTROM_AUT_FILE, R9     ; file handle
                XOR     R11, R11                ; use / as path separator
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; R10=error code; 0=OK
                RBRA    _CRMA_2, Z              ; file open OK
                MOVE    LOG_STR_ROMPRSA, R8     ; file open NOT ok
                SYSCALL(puts, 1)
                MOVE    CRTROM_AUT_MOD, R8      ; OK that we cannot open?
                ADD     R1, R8                  ; b/c of optional ROM?

                CMP     CTRROM_TYPE_OPTNL, @R8  ; optional ROM?
                RBRA    _CRMA_NEXT, Z           ; yes: proceed

                ; Fatal: Show file name of the missing ROM, the error message
                ; and the error code and then go fatal
_CRMA_FATAL     MOVE    R10, R7                 ; R7: error code
                MOVE    R6, R8                  ; R6: file name
                SYSCALL(strlen, 1)
                SUB     R9, SP                  ; stack space for file name
                MOVE    R9, R1
                MOVE    ERR_F_ATRMLOAD, R8
                SYSCALL(strlen, 1)
                SUB     R9, SP                  ; stack space for error
                SUB     1, SP
                MOVE    R6, R8
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    ERR_F_ATRMLOAD, R8      ; error message
                ADD     R1, R9                  ; concatenate fname + error
                SYSCALL(strcpy, 1)
                MOVE    SP, R8
                MOVE    R7, R9
                RBRA    FATAL, 1

                ; ------------------------------------------------------------
                ; Load ROM
                ; ------------------------------------------------------------

_CRMA_2         MOVE    CRTROM_AUT_DEV, R2      ; R2: target device
                ADD     R1, R2
                MOVE    @R2, R2
                MOVE    CRTROM_AUT_4KS, R3      ; R3: 4k window
                ADD     R1, R3
                MOVE    @R3, R3
                MOVE    M2M$RAMROM_DATA, R4     ; R4: next 4k win indicator
                ADD     0x1000, R4
                MOVE    M2M$RAMROM_DATA, R5     ; R5: target address

_CRMA_3         MOVE    CRTROM_AUT_FILE, R8     ; read next byte from SD card
                SYSCALL(f32_fread, 1)
                CMP     FAT32$EOF, R10          ; end of file?
                RBRA    _CRMA_EOF, Z
                CMP     0, R10                  ; other read error?
                RBRA    _CRMA_4, Z              ; no

                ; In case of a read error: check if this ROM is optional. In
                ; this case we try the next ROM otherwise we go fatal
                MOVE    CRTROM_AUT_MOD, R8
                ADD     R1, R8
                CMP     CTRROM_TYPE_OPTNL, @R8  ; ROM is optional?
                RBRA    _CRMA_FATAL, !Z         ; no: go fatal
                MOVE    LOG_STR_ROMPRSA, R8     ; log failed
                SYSCALL(puts, 1)
                RBRA    _CRMA_NEXT, 1

                ; Byte successfully read: Now write it into target device
_CRMA_4         MOVE    M2M$RAMROM_DEV, R8
                MOVE    R2, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    R3, @R8
                MOVE    R9, @R5++               ; write to target address

                ; 4k window boundary handling
                CMP     R4, R5                  ; boundary reached?
                RBRA    _CRMA_5, !Z             ; no
                MOVE    M2M$RAMROM_DATA, R5     ; yes: reset target address..
                ADD     1, R3                   ; .. and increase targ. 4k win

_CRMA_5         RBRA    _CRMA_3, 1              ; next byte           

_CRMA_EOF       MOVE    LOG_STR_ROMPRS9, R8     ; EOF: log OK
                SYSCALL(puts, 1)
                MOVE    CRTROM_AUT_LDF, R8      ; remember successful loading
                ADD     R1, R8                  ; R1: ROM counter
                MOVE    1, @R8

                ; Next ROM
_CRMA_NEXT      MOVE    R7, SP                  ; restore stack pointer
                ADD     1, R1                   ; next iteration
                CMP     R0, R1
                RBRA    _CRMA_1, !Z

_CRMA_RET       SYSCALL(leave, 1)
                RET
