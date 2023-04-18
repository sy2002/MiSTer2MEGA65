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

                ; initialize "loaded" flags
                MOVE    CRTROM_MAN_LDF, R8
                MOVE    CRTROM_MAN_MAX, R9
                XOR     R10, R10
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

                ; illegal amount of manually loaded CRTs/ROMs
                CMP     R0, CRTROM_MAN_MAX
                RBRA    _CRTRI_L2, !N
                MOVE    ERR_F_CR_M_CNT, R8
                MOVE    R0, R9
                RBRA    FATAL, 1

                ; skip the rest in case of inactive CRT/ROM system
_CRTRI_L2       CMP     0, R0
                RBRA    _CRTRI_RET, Z

                ; ------------------------------------------------------------
                ; Initializations that are only relevant, if we have at 
                ; least one CRT/ROM
                ; ------------------------------------------------------------

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
