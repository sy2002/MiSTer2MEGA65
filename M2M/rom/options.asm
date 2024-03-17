; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Options menu / "Help" menu
;
; This On-Screen-Menu (OSM) offers various facilities that can be configured
; using config.vhd. The file options.asm needs the environment of shell.asm.
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Main routine
;
; Expects a M2M$KEY_* in R8 and returns immediatelly, if it is not the
; HELP key. Otherwise it runs the whole OSM logic, manages file browsing
; for drive mounting and also manages M2M$CFM_DATA.
; ----------------------------------------------------------------------------

                ; Check if Help is pressed and if yes, run the Options menu
HELP_MENU       SYSCALL(enter, 1)
                CMP     M2M$KEY_HELP, R8        ; help key pressed?
                RBRA    _HLP_RET_DIRECT, !Z

                ; remember status of the write cache of all vdrives, if any
                RSUB    VD_DTY_ST_SET, 1

                ; If configured in config.vhd, deactivate keyboard and
                ; joysticks, so that the key strokes done during the OSD is on
                ; are not passed along to the core
                RSUB    RP_OPTM_START, 1

                ; Copy menu items from config.vhd to heap
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; R0: config selector
                MOVE    M2M$CFG_OPTM_ITEMS, @R0 ; select menu items
                MOVE    M2M$RAMROM_DATA, R8     ; copy men. items to heap
                MOVE    HEAP, R9
                ADD     OPTM_STRUCTSIZE, R9
                MOVE    R9, R1                  ; R1: points to item string
                SYSCALL(strcpy, 1)

                ; R2 = first free word behind the menu items
                MOVE    R9, R2
                MOVE    R9, R8
                SYSCALL(strlen, 1)              ; R9 = string length
                ADD     R9, R2
                ADD     1, R2                   ; zero terminator

                ; R3 = menu size
                MOVE    OPTM_ICOUNT, R3
                MOVE    @R3, R3

                ; Copy menu data structure from ROM to RAM (heap)
                MOVE    OPT_MENU_DATA, R8
                MOVE    HEAP, R9
                MOVE    OPTM_STRUCTSIZE, R10
                SYSCALL(memcpy, 1)

                ; Modify the menu data structure, so that it points to the 
                ; data from config.vhd
                MOVE    HEAP, R8                ; Set menu size
                ADD     OPTM_IR_SIZE, R8
                MOVE    R3, @R8                 ; R3: menu item counter
                MOVE    HEAP, R8                ; Set menu item string
                ADD     OPTM_IR_ITEMS, R8
                MOVE    R1, @R8                 ; R1: item string

                ; Copy the menu groups to the heap and modify the menu data
                ; structure accordingly.
                ; R2 contains the first free word on the heap behind the item
                ; string, so we will copy to that point and then increase
                ; R2 by R3 (menu item counter)
                ; R0 is used to switch the config selector
                MOVE    M2M$CFG_OPTM_GROUPS, @R0
                MOVE    M2M$RAMROM_DATA, R8
                MOVE    R2, R9                  ; R2: first free word
                ADD     R3, R2                  ; R2: next free word
                MOVE    R3, R10                 ; R3: amount of menu items
                SYSCALL(memcpy, 1)
                MOVE    HEAP, R8                ; store pointer to record
                ADD     OPTM_IR_GROUPS, R8
                MOVE    R9, @R8
                MOVE    R9, R12                 ; R12: pointer to menu groups

                ; Copy the standard selectors (which menu items are selected
                ; by default) from the QNICE M2M$CFM_DATA register to the
                ; heap and modify the menu data structure accordingly.
                ; (The M2M$CFM_DATA register gets its initial values from
                ; config.vhd during HELP_MENU_INIT.)
                MOVE    R2, R9                  ; R9: free word behind groups
                ADD     R3, R2                  ; R2: free wrd beh. selectors                

                MOVE    HEAP, R8                ; modify the menu data struct.
                ADD     OPTM_IR_STDSEL, R8
                MOVE    R9, @R8

                MOVE    R3, R4                  ; R4: amount of menu items                
                MOVE    M2M$CFM_ADDR, R5        ; R5: "bank" selector
                MOVE    0, @R5                  ; start with bank 0
                MOVE    M2M$CFM_DATA, R6        ; R6: the flag register

                XOR     R7, R7                  ; bit within current "bank"
_HLP_SSICA      ADD     1, R7                   ; at 16 bits we need to switch
                CMP     17, R7                  ; the bank, i.e. R7 = 17
                RBRA    _HLP_SSICS, !Z
                ADD     1, @R5                  ; next "bank"
                MOVE    1, R7
_HLP_SSICS      MOVE    @R6, R8                 ; SHR is a destructive op.
                SHR     R7, R8                  ; shift into X
                RBRA    _HLP_SSIC0, !X          ; X = 0 (R7th bit = 0)?
                MOVE    1, @R9++                ; selector true at this pos.
                RBRA    _HLP_SSIC1, 1
_HLP_SSIC0      MOVE    0, @R9++                ; selector false at this pos.
_HLP_SSIC1      SUB     1, R4                   ; one less menu item to go
                RBRA    _HLP_SSICA, !Z          ; next menu item

                ; Copy positions of separator lines & modify men. dta. struct.
                MOVE    M2M$CFG_OPTM_LINES, @R0
                MOVE    M2M$RAMROM_DATA, R8
                MOVE    R2, R9                  ; R9: free word beh. selectors
                MOVE    R3, R10                 ; R10: menu items counter
                SYSCALL(memcpy, 1)
                MOVE    HEAP, R8
                ADD     OPTM_IR_LINES, R8
                MOVE    R9, @R8

                ; Calculate, if the menu is within its heap boundaries
                MOVE    HEAP, R8
                MOVE    R2, R9
                ADD     R10, R9
                SUB     R8, R9
                ADD     1, R9
                RSUB    LOG_HEAP1, 1
                CMP     R9, MENU_HEAP_SIZE      ; used heap > heap size?
                RBRA    _HLP_HEAP1_OK, !N       ; no, all OK

                ; If we land here, then either MENU_HEAP_SIZE is too small
                ; to hold the menu structure (unlikely, if nobody heavily 
                ; modified this value from the default) or we have an error
                ; that leads to heap corruption
                MOVE    ERR_FATAL_HEAP1, R8
                SUB     MENU_HEAP_SIZE, R9      ; R9: overrun
                RSUB    FATAL, 1

                ; find space for OPTM_HEAP after the above-mentioned data
_HLP_HEAP1_OK   MOVE    MENU_HEAP_SIZE, R8
                SUB     R9, R8
                MOVE    OPTM_HEAP_SIZE, R10
                MOVE    R8, @R10
                MOVE    OPTM_HEAP, R8
                MOVE    HEAP, @R8
                ADD     R9, @R8

                ; Check if the planned memory usage in OPTM_HEAP will not
                ; overwrite FP_HEAP: We will use OPTM_HEAP to store the
                ; strings that will be displayed instead of the "%s" strings
                ; from config.vhd. The maximum length per string (rounded up)
                ; equals to @SCR$OSM_O_DX multiplied with the maximum amount
                ; of such kind of "%s" strings, which equals to the actual
                ; amount of virtual drives, i.e. VDRIVES_NUM plus the amount
                ; of submenus plus the amount of manual CRT/ROM loading items
                ; (i.e. CRTROM_MAN_NUM).
                ;
                ; But need one more than that (i.e. VDRIVES_NUM +
                ; amount of submenus + CRTROM_MAN_NUM) because we need a
                ; scratch buffer to remember the adjusted filename during the
                ; period, where OPTM_S_SAVING from config.vhd is being shown,
                ; i.e. while the save buffer is dirty. We store the pointer
                ; to this in OPTM_HEAP_LAST.
                MOVE    OPTM_SCOUNT, R11        ; R11: amount of submenus
                MOVE    @R11, R11
                MOVE    SCR$OSM_O_DX, R8
                MOVE    @R8, R8
                MOVE    VDRIVES_NUM, R9
                MOVE    @R9, R9                 ; R9: amount of virtual drives
                ADD     R11, R9                 ; add amount of submenus
                MOVE    CRTROM_MAN_NUM, R11     ; add amount of CRT/ROM items
                ADD     @R11, R9
                SYSCALL(mulu, 1)                ; R10 = result lo word of mulu
                MOVE    OPTM_HEAP_LAST, R8      ; clc. addr. of OPTM_HEAP_LAST
                MOVE    R10, @R8
                MOVE    OPTM_HEAP, R11
                ADD     @R11, @R8
                MOVE    SCR$OSM_O_DX, R8        ; VDRIVES_NUM + amt submen + 1
                ADD     @R8, R10
                RSUB    LOG_HEAP2, 1
                MOVE    OPTM_HEAP_SIZE, R8
                CMP     R10, @R8                ; demand > heap?
                RBRA    _HLP_HEAP2_OK, !N       ; no, all OK

                ; If we land here, we have a heap size problem or a bug.
                ; See above at ERR_FATAL_HEAP1.
                MOVE    R10, R9                 ; R9 contains overrun
                SUB     @R8, R9
                MOVE    ERR_FATAL_HEAP2, R8
                RSUB    FATAL, 1 

                ; run the menu
_HLP_HEAP2_OK   RSUB    ROSM_REM_OLD, 1         ; remember current settings
                RSUB    OPTM_SHOW, 1            ; fill VRAM
                RSUB    SCR$OSM_O_ON, 1         ; make overlay visible
                MOVE    OPTM_SELECTED, R9       ; use recently selected line
                MOVE    @R9, R8
                RSUB    OPTM_RUN, 1             ; run menu
                RSUB    SCR$OSM_OFF, 1          ; make overlay invisible
                RSUB    ROSM_SAVE, 1            ; save settings if appropriate

                ; Smart handling of last-recently-selected: only remember
                ; LRS when the menu is closed via pressing the Help key again.
                ; Otherwise (when using "Close Menu" or something like this),
                ; restart from the default start position
                MOVE    R12, R10
                ADD     R8, R10
                CMP     OPTM_CLOSE, @R10
                RBRA    _HLP_RESETPOS, Z
                MOVE    R8, @R9                 ; remember recently sel. line
                RBRA    _HLP_RET, 1
_HLP_RESETPOS   MOVE    OPTM_START, R0
                MOVE    @R0, @R9

                ; when the menu was exited via "Close" + Return or via
                ; Run/Stop, make sure that the Return key press is not
                ; registered by the core
_HLP_RET        RSUB    WAIT333MS, 1

                ; Unpause (in case the core was at pause state due to
                ; OPTM_PAUSE in config.vhd) and reactivate keyboard and
                ; joysticks in case they were inactive
                MOVE    M2M$CSR, R0
                AND     M2M$CSR_UN_PAUSE, @R0
                OR      M2M$CSR_KBD_JOY, @R0

_HLP_RET_DIRECT SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Init/configure the menu library
; ----------------------------------------------------------------------------

HELP_MENU_INIT  SYSCALL(enter, 1)

                ; make sure OPTM_HEAP is initialized to zero, as it will be
                ; calculated and activated inside HELP_MENU
                MOVE    OPTM_HEAP, R8
                MOVE    0, @R8
                MOVE    OPTM_HEAP_SIZE, R8
                MOVE    0, @R8

                ; fill menu data structure (see menu.asm)
                MOVE    HEAP, R8
                MOVE    SCR$OSM_O_X, R9
                MOVE    @R9, R9
                MOVE    SCR$OSM_O_Y, R10
                MOVE    @R10, R10
                MOVE    SCR$OSM_O_DX, R11
                MOVE    @R11, R11
                MOVE    SCR$OSM_O_DY, R12
                MOVE    @R12, R12
                RSUB    OPTM_INIT, 1

                ; extract the amount of menu items (including empty lines and
                ; headlines) from config.vhd
                MOVE    M2M$RAMROM_DEV, R0      ; Device=config.vhd
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R1    ; Selector=amount of items
                MOVE    M2M$CFG_OPTM_ICOUNT, @R1
                MOVE    M2M$RAMROM_DATA, R0
                MOVE    @R0, R7                 ; R7=amount of items
                MOVE    OPTM_ICOUNT, R0
                MOVE    R7, @R0

                ; check, if menu size in config.vhd is between 1 and 254
                MOVE    1, R9
                MOVE    R7, R8
                MOVE    255, R10
                SYSCALL(in_range_u, 1)          ; R9 <= R8 < R10?
                RBRA    _HLP_ITEM, C           ; yes: search start item
                MOVE    ERR_F_MENUSIZE, R8      ; no: fatal error and end
                RBRA    FATAL, 1

                ; extract the initially selected item from config.vhd
_HLP_ITEM       XOR     R0, R0                  ; R1=position of start item
                MOVE    M2M$CFG_OPTM_START, @R1 ; Selector=start flag
                MOVE    M2M$RAMROM_DATA, R2
_HLP_SEARCH     CMP     R0, R7
                RBRA    _HLP_ERROR, Z
                CMP     @R2++, 0
                RBRA    _HLP_START, !Z
                ADD     1, R0
                RBRA    _HLP_SEARCH, 1

                ; No start flag found
_HLP_ERROR      MOVE    ERR_F_MENUSTART, R8
                RBRA    FATAL, 1

                ; store initially selected item (start flag)
_HLP_START      MOVE    OPTM_START, R8
                MOVE    OPTM_SELECTED, R9
                MOVE    R0, @R8
                MOVE    R0, @R9

                ; M2M$CFM_DATA controls the QNICE register that contains all
                ; on-screen-menu setting and therefore is responsible for many
                ; aspects of the behavior of the core.
                ;
                ; There are two ways how M2M$CFM_DATA gets initialized:
                ;
                ; a) In config.vhd: If SAVE_SETTINGS is true and the file
                ;    specified by CFG_FILE exists and is exactly OPTM_SIZE
                ;    bytes in size and the first byte of this file is not
                ;    0xFF, then this file is read and each byte of this file
                ;    that is 1 represents a set bit (byte 0 = bit 0).
                ;
                ; b) If the conditions of (a) are not met, then M2M$CFM_DATA
                ;    is initialized using the standard selectors specified by
                ;    OPTM_G_STDSEL in config.vhd

                ; ------------------------------------------------------------
                ; Case (a): Config file / Remember settings
                ; ------------------------------------------------------------

                MOVE    LOG_STR_CONFIG, R8
                SYSCALL(puts, 1)

                ; Is SAVE_SETTINGS (config.vhd) true?
                ; If no, then we proceed with Case (b)
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    M2M$CFG_GENERAL, @R0
                MOVE    M2M$CFG_SAVEOSDCFG, R1
                CMP     1, @R1
                RBRA    _HLP_CA_1, Z            ; yes, SAVE_SETTINGS is true

                MOVE    LOG_STR_CFG_OFF, R8     ; no: log and go to case (b)
                SYSCALL(puts, 1)
                RBRA    _HLP_STDSEL, 1

_HLP_CA_1       MOVE    LOG_STR_CFG_ON, R8
                SYSCALL(puts, 1)

                ; Before trying to mount the SD card, wait the time period
                ; specified by SD_WAIT (shell_vars.asm). This is a workaround
                ; that allows us to mount more SD cards successfully.
                ; 
                ; While we wait: The core needs to be in reset mode. This is
                ; the case, see also CSR_DEFAULT in M2M/vhdl/QNICE/qnice.vhd
                RSUB    WAIT_FOR_SD, 1

                ; Mount SD card
                MOVE    CONFIG_DEVH, R8         ; device handle
                MOVE    1, R9                   ; partition #1 hardcoded
                SYSCALL(f32_mnt_sd, 1)
                CMP     0, R9                   ; R9=error code; 0=OK
                RBRA    _HLP_CA_4, Z

                MOVE    LOG_STR_CFG_E1, R8      ; cannot mount
                SYSCALL(puts, 1)
                RBRA    _HLP_STDSEL, 1          ; use factory defaults

                ; Open config file
_HLP_CA_4       MOVE    M2M$CFG_CFG_FILE, @R0
                MOVE    CONFIG_FILE, R9
                MOVE    M2M$RAMROM_DATA, R10
                XOR     R11, R11
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; file open worked
                RBRA    _HLP_CA_5, Z            ; yes

                ; No config file or corrupt config file
                MOVE    LOG_STR_CFG_E2, R8
_HLP_CA_NCF     SYSCALL(puts, 1)
                MOVE    M2M$RAMROM_DATA, R8
                SYSCALL(puts, 1)
                MOVE    LOG_STR_CFG_SP, R8
                SYSCALL(puts, 1)
                MOVE    CONFIG_FILE, R8         ; file handle dubs as flag
                MOVE    0, @R8                  ; therefore reset it
                RBRA    _HLP_STDSEL, 1          ; use factory defaults

                ; Check filesize of config file
_HLP_CA_5       MOVE    R9, R8                  ; R9: file handle
                ADD     FAT32$FDH_SIZE_HI, R8
                CMP     0, @R8                  ; file larger than 64 KB?
                RBRA    _HLP_CA_CCF, !Z         ; yes: corrupt config file
                MOVE    R9, R8
                ADD     FAT32$FDH_SIZE_LO, R8
                CMP     R7, @R8                 ; filesize = menu size?
                RBRA    _HLP_CA_CCF, !Z         ; no: corrupt config file
                RBRA    _HLP_CA_6, 1            ; yes

_HLP_CA_CCF     MOVE    LOG_STR_CFG_E4, R8      ; corrupt config file
                RBRA    _HLP_CA_NCF, 1          ; use factory defaults

                ; Check first byte of config file: 0xFF means that the config
                ; file is an empty default config file
_HLP_CA_6       MOVE    R9, R8                  ; R9: file handle
                SYSCALL(f32_fread, 1)
                CMP     0, R10                  ; read error?
                RBRA    _HLP_CA_CCF, !Z         ; yes: use factory defaults
                CMP     0xFF, R9                ; new config file?
                RBRA    _HLP_CA_7, !Z           ; no: read it

                MOVE    LOG_STR_CFG_E3, R8      ; yes: use factory defaults..
                SYSCALL(puts, 1)                ; ..but leave CONFIG_FILE..
                MOVE    M2M$RAMROM_DATA, R8     ; ..intact so that the config.
                SYSCALL(puts, 1)                ; ..will be saved later
                MOVE    LOG_STR_CFG_SP, R8
                SYSCALL(puts, 1)
                RBRA    _HLP_STDSEL, 1

                ; Load configuration from file and write it to M2M$CFM_DATA
_HLP_CA_7       XOR     R9, R9                  ; restart reading from byte 0
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9                   ; seek error?
                RBRA    _HLP_CA_8, Z            ; no: proceed
                MOVE    ERR_FATAL_ROSMS, R8     ; yes: fatal; R9: error code
                RBRA    FATAL, 1

_HLP_CA_8       MOVE    R8, R0
                MOVE    LOG_STR_CFG_FOK, R8
                SYSCALL(puts, 1)
                MOVE    M2M$RAMROM_DATA, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)                

                MOVE    R0, R8                  ; R8: file handle
                MOVE    M2M$CFM_ADDR, R0        ; R0: select "bank" (0..15)
                MOVE    M2M$CFM_DATA, R1        ; R1: menu settings
                XOR     R2, R2                  ; R2: current "bank"/"window"
                MOVE    OPTM_ICOUNT, R3         ; R3: amount of bits to write
                MOVE    @R3, R3

_HLP_CA_9       MOVE    R2, @R0                 ; currently active window
                MOVE    1, R4                   ; R4: bit-pointer (bit 0)

_HLP_CA_10      SYSCALL(f32_fread, 1)           ; read byte from config file
                CMP     0, R10                  ; error?
                RBRA    _HLP_CA_11, Z           ; no: proceed
                MOVE    ERR_FATAL_ROSMR, R8     ; yes: fatal; R9: error code
                RBRA    FATAL, 1

_HLP_CA_11      CMP     0, R9                   ; current bit not set?
                RBRA    _HLP_CA_12, Z           ; yes: delete current bit
                CMP     1, R9                   ; current bit set?
                RBRA    _HLP_CA_13, Z           ; yes: set current bit
                MOVE    ERR_FATAL_ROSMC, R8     ; illegal value: corrupt file
                RBRA    FATAL, 1                ; and this is fatal

_HLP_CA_12      MOVE    R4, R5                  ; delete current bit
                NOT     R5, R5
                AND     R5, @R1
                RBRA    _HLP_CA_14, 1

_HLP_CA_13      OR      R4, @R1                 ; set current bit

_HLP_CA_14      SUB     1, R3                   ; done reading config file?
                RBRA    _HLP_CA_15, Z           ; yes

                AND     0xFFFD, SR              ; clear X flag
                SHL     1, R4                   ; move bit-pointer to next bit
                RBRA    _HLP_CA_10, !Z          ; next bit

                ADD     1, R2                   ; next M2M$CFM_DATA window
                CMP     16, R2
                RBRA    _HLP_CA_9, !Z

_HLP_CA_15      RBRA    _HLP_S3, 1              ; Case (a) successful

                ; ------------------------------------------------------------
                ; Case (b): Use standard selectors from config.vhd
                ; ------------------------------------------------------------

_HLP_STDSEL     MOVE    LOG_STR_CFG_STD, R8
                SYSCALL(puts, 1)

                ; Get the standard selectors (which menu items are selcted by
                ; default) from config.vhd and store them in M2M$CFM_DATA                
                MOVE    M2M$CFM_ADDR, R0        ; R0: select "bank" (0..15)
                MOVE    M2M$CFM_DATA, R1        ; R1: write data
                MOVE    16, R2                  ; init all "banks" to zero
                MOVE    15, @R0                 ; (@R0 can only store values
_HLP_S0         MOVE    0, @R1                  ; between 0 and 15, so we need
                SUB     1, R2                   ; R2 to count)
                RBRA    _HLP_S0E, Z             ; Make sure that @R0 = 0 when
                SUB     1, @R0                  ; we leave this loop
                RBRA    _HLP_S0, 1

_HLP_S0E        MOVE    M2M$RAMROM_4KWIN, R2
                MOVE    M2M$CFG_OPTM_STDSEL, @R2
                MOVE    M2M$RAMROM_DATA, R2     ; R2: read config.vhd data
                MOVE    R7, R3                  ; R3: amount of menu items
                XOR     R4, R4                  ; R4: bit counter for R0
                XOR     R5, R5                  ; R5: bit pattern

_HLP_S1         MOVE    @R2++, R6               ; get bit from config.vhd
                AND     0xFFFD, SR              ; clear X
                SHL     R4, R6                  ; shift bit to correct pos.
                OR      R6, R5                  ; R5: target pattern
                ADD     1, R4                   ; next bit
                CMP     16, R4                  ; next bank for M2M$CFM_ADDR?
                RBRA    _HLP_S2, !Z             ; no: check if done
                MOVE    R5, @R1                 ; store bit pattern in ..CFM..
                XOR     R4, R4                  ; reset bit pattern counter
                XOR     R5, R5                  ; reset bit pattern
                ADD     1, @R0                  ; next "bank"
_HLP_S2         SUB     1, R3                   ; one less menu item to go
                RBRA    _HLP_S1, !Z
                CMP     0, R4                   ; something to write to @R1?
                RBRA    _HLP_S3, Z              ; no: do not destroy @R1
                MOVE    R5, @R1                 ; yes: update @R1

                ; determine the amount of submenus (if any)
                ; fatal if the amount is an odd number, because this indicates
                ; that at least one "opened" OPTM_G_SUBMENU in config.vhd is
                ; not "closed" by another instance of OPTM_G_SUBMENU
_HLP_S3         MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    M2M$CFG_OPTM_GROUPS, @R0
                MOVE    M2M$RAMROM_DATA, R0     ; R0: ptr cur men itm grp id

                MOVE    OPTM_ICOUNT, R1
                MOVE    @R1, R1                 ; R1: amount of menu items
                XOR     R8, R8                  ; R8: amount of submenus

_HLP_S4         MOVE    @R0++, R2
                AND     OPTM_SUBMENU, R2        ; is a submenu?
                RBRA    _HLP_S5, Z              ; no
                ADD     1, R8                   ; yes
_HLP_S5         SUB     1, R1                   ; one more item done
                RBRA    _HLP_S4, !Z             ; iterate until done

                AND     0xFFFB, SR              ; clear Carry
                SHR     1, R8                   ; divide R8 by two
                RBRA    _HLP_S_RET, !X          ; R8 was an even number..
                MOVE    ERR_F_MENUSUB, R8       ; ..else fatal
                XOR     R9, R9
                RBRA    FATAL, 1

_HLP_S_RET      MOVE    OPTM_SCOUNT, R0         ; store in variable
                MOVE    R8, @R0

                SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Helper functions for remembering the OSM settings
; ----------------------------------------------------------------------------

; Copy the current state of M2M$CFM_DATA to OLD_SETTINGS
ROSM_REM_OLD    INCRB

                ; If CONFIG_FILE is null: We are not remembering the settings
                MOVE    CONFIG_FILE, R0
                CMP     0, @R0
                RBRA    _ROSMRO_RET, Z

                ; Copy by iterating through the 16 "windows" of M2M$CFM_DATA
                XOR     R0, R0                  ; R1 is only 4-bits (0..15)
                MOVE    M2M$CFM_ADDR, R1
                MOVE    M2M$CFM_DATA, R2
                MOVE    OLD_SETTINGS, R3
_ROSMRO_LOOP    MOVE    R0, @R1                 ; new M2M$CFM_DATA "window"
                MOVE    @R2, @R3++              ; copy to OLD_SETTINGS
                ADD     1, R0
                CMP     16, R0
                RBRA    _ROSMRO_LOOP, !Z

_ROSMRO_RET     DECRB
                RET

; For preventing data corruption by for example writing to random spots on
; SD cards other than the one containing the original config file: Any SD card
; change, even switching cards back and forth in the file browser will stop
; us from remembering settings from that point in time on (until the next
; hard reset or reboot of the core).
; Important: Call this function needs to be polled "always" so that any change
; can be instantly detected. This is why it needs to be called in HANDLE_IO.
ROSM_INTEGRITY  SYSCALL(enter, 1)

                ; If CONFIG_FILE is null: We are not remembering the settings
                MOVE    CONFIG_FILE, R0
                CMP     0, @R0
                RBRA    _ROSMI_RET, Z

                ; If the currently active SD card is different than the one
                ; we remembered upon startup then we clear the CONFIG_FILE
                ; handle as this will stop us from remembering settings.
                MOVE    M2M$CSR, R8             ; get active SD card
                MOVE    @R8, R8
                AND     M2M$CSR_SD_ACTIVE, R8   ; isolate the relevant bit
                MOVE    INITIAL_SD, R9
                CMP     R8, @R9                 ; SD card the same?
                RBRA    _ROSMI_RET, Z           ; yes

                MOVE    LOG_STR_CFG_SDC, R8     ; log switch off remember msg
                SYSCALL(puts, 1)

                MOVE    CONFIG_FILE, R0         ; switch off remembering
                MOVE    0, @R0

_ROSMI_RET      SYSCALL(leave, 1)
                RET

; Detect if the user made any changes to the configuration
; Returns C=1 (Carry flag), if there are changes C=0 otherwise
ROSM_CHANGES    SYSCALL(enter, 1)

                XOR     R0, R0                  ; R1 is only 4-bits (0..15)
                MOVE    M2M$CFM_ADDR, R1
                MOVE    M2M$CFM_DATA, R2
                MOVE    OLD_SETTINGS, R3
                XOR     R4, R4                  ; R4: currently active bit
                MOVE    OPTM_ICOUNT, R5         ; R5: amount of bits to write
                MOVE    @R5, R5                

_ROSMC_LOOP     MOVE    R0, @R1                 ; new M2M$CFM_DATA "window"
                MOVE    1, R7                   ; R7: "pointer" to curr. bit 0

_ROSMC_NEXTBIT  MOVE    M2M$RAMROM_DEV, R6      ; do we need to ignore the..
                MOVE    M2M$CONFIG, @R6         ; current bit?

                ; exclude OPTM_G_MOUNT_DRV items
                MOVE    M2M$RAMROM_4KWIN, R6
                MOVE    M2M$CFG_OPTM_MOUNT, @R6 ; yes we need to ignore, if..
                MOVE    M2M$RAMROM_DATA, R6     ; ..the menu item is about..
                ADD     R4, R6                  ; ..mounting a drive
                CMP     1, @R6
                RBRA    _ROSMC_INCBIT, Z        ; ignore

                ; exclude OPTM_G_LOAD_ROM items
                MOVE    M2M$RAMROM_4KWIN, R6
                MOVE    M2M$CFG_OPTM_CRTROM, @R6
                MOVE    M2M$RAMROM_DATA, R6
                ADD     R4, R6
                CMP     1, @R6
                RBRA    _ROSMC_INCBIT, Z

                ; do not exclude
                MOVE    @R2, R8
                AND     R7, R8
                MOVE    @R3, R9
                AND     R7, R9
                CMP     R8, R9                  ; OLD_SETTINGS=current setngs?
                RBRA    _ROSMC_C1, !Z           ; no: set Carry

_ROSMC_INCBIT   ADD     1, R4                   
                CMP     R4, R5                  ; all bits checked?
                RBRA    _ROSMC_C0, Z            ; yes: clear Carry

                AND     0xFFFD, SR              ; clear X flag
                SHL     1, R7                   ; move bit pointer to next bit
                RBRA    _ROSMC_NEXTBIT, !Z      ; next bit

                ADD     1, R0                   ; next M2M$CFM_DATA "window"
                ADD     1, R3                   ; next OLD_SETTINGS "window"
                CMP     16, R0
                RBRA    _ROSMC_LOOP, !Z

_ROSMC_C0       AND     0xFFFB, SR              ; no changes: clear Carry
                RBRA    _ROSMC_RET, 1

_ROSMC_C1       OR      0x0004, SR              ; changes: set Carry

_ROSMC_RET      SYSCALL(leave, 1)
                RET

; Save the current state of M2M$CFG_DATA to the SD card
; Byte 0 in the file represents bit 0 in the register, byte 1 = bit1, ...
ROSM_SAVE       SYSCALL(enter, 1)

                ; If CONFIG_FILE is null: We are not remembering the settings
                MOVE    CONFIG_FILE, R8
                CMP     0, @R8
                RBRA    _ROSMS_RET, Z

                ; If any write cache of any virtual drive is dirty then
                ; we need to assume that the 512-byte hardware buffer is
                ; currently in use by HANDLE_DEV. See also the comment about
                ; us not following the QNICE best practice here and the
                ; @TODO that we might want to refactor this in future.
                RSUB    VD_ACTIVE, 1            ; any vdrives at all?
                RBRA    _ROSMS_1, !C            ; no, so no danger of corruptn
                MOVE    R8, R0                  ; R0: amount of vdrives
                XOR     R8, R8                  ; vdrive id
_ROSMS_0        MOVE    VD_CACHE_DIRTY, R9
                RSUB    VD_DRV_READ, 1          ; get dirty flag for curr. drv
                CMP     0, R8                   ; dirty?
                RBRA    _ROSMS_NOWR, !Z         ; yes: do not save
                ADD     1, R8                   ; no: check next vdrive
                CMP     R0, R8                  ; done?
                RBRA    _ROSMS_0, !Z            ; no: next iteration
                RBRA    _ROSMS_1, 1             ; yes: detect changes & save

_ROSMS_NOWR     MOVE    LOG_STR_CFG_NO, R8
                SYSCALL(puts, 1)
                RBRA    _ROSMS_RET, 1

_ROSMS_1        ; Iterate through the 16 windows of M2M$CFM_DATA to detect
                ; changes because we only save if there are changes
                RSUB    ROSM_CHANGES, 1
                RBRA    _ROSMS_RET, !C

                ; Start at the beginning of the config file
                MOVE    CONFIG_FILE, R8
                XOR     R9, R9                  ; restart reading from byte 0
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9                   ; seek error?
                RBRA    _ROSMS_2, Z             ; no: proceed
                MOVE    ERR_FATAL_ROSMS, R8     ; yes: fatal; R9: error code
                RBRA    FATAL, 1

                ; Save settings by iterating through the 16 windows of
                ; M2M$CFM_DATA (accessed by R1 & R2; R8: file handle) and then
                ; going from the lowest bit to the highest and saving each
                ; set-bit as a "1" and each deleted-bit as a "0".
                ;
                ; It might be that we need to ignore certain settings for
                ; example the disk mount status because because these kind of
                ; settings are not intended to be saved. Even though
                ; ROSM_CHANGES checks if nothing than these kind of settings
                ; have been changed: It might be that the user for example
                ; mounted a disk and in parallel changed a setting so that
                ; ROSM_CHANGES would still return C=1.
_ROSMS_2        XOR     R0, R0                  ; R0: M2M$CFM_ADDR
                MOVE    M2M$CFM_ADDR, R1
                MOVE    M2M$CFM_DATA, R2
                XOR     R3, R3                  ; no. of currently active bit
                MOVE    OPTM_ICOUNT, R5         ; R5: amount of bits to write
                MOVE    @R5, R5
_ROSMS_3        MOVE    R0, @R1                 ; new M2M$CFM_DATA "window"
                MOVE    1, R7                   ; R7: "pointer" to curr. bit 0

_ROSMS_4A       MOVE    M2M$RAMROM_DEV, R4      ; do we need to ignore the..
                MOVE    M2M$CONFIG, @R4         ; current bit?

                ; exclude OPTM_G_MOUNT_DRV items
                MOVE    M2M$RAMROM_4KWIN, R4
                MOVE    M2M$CFG_OPTM_MOUNT, @R4 ; yes we need to ignore, if..
                MOVE    M2M$RAMROM_DATA, R4     ; ..the menu item is about..
                ADD     R3, R4                  ; ..mounting a drive
                CMP     1, @R4
                RBRA    _ROSMS_4B, !Z           ; it is not: do not ignore
                XOR     R9, R9                  ; ignoring means writing a 0
                RBRA    _ROSMS_5, 1

                ; exclude OPTM_G_LOAD_ROM items
_ROSMS_4B       MOVE    M2M$RAMROM_4KWIN, R4
                MOVE    M2M$CFG_OPTM_CRTROM, @R4
                MOVE    M2M$RAMROM_DATA, R4
                ADD     R3, R4
                CMP     1, @R4
                RBRA    _ROSMS_4C, !Z
                XOR     R9, R9
                RBRA    _ROSMS_5, 1

_ROSMS_4C       XOR     R9, R9
                MOVE    R7, R6
                AND     @R2, R6                 ; current bit set?
                RBRA    _ROSMS_5, Z             ; no: write R9, which is 0
                MOVE    1, R9                   ; yes: set R9 to 1 and write

_ROSMS_5        SYSCALL(f32_fwrite, 1)          ; write byte to config file
                CMP     0, R9                   ; error?
                RBRA    _ROSMS_6, Z             ; no: proceed
                MOVE    ERR_FATAL_ROSMW, R8     ; yes: fatal; R9: error code
                RBRA    FATAL, 1

_ROSMS_6        ADD     1, R3                   ; all menu items written?
                CMP     R3, R5
                RBRA    _ROSMS_7, Z             ; yes

                AND     0xFFFD, SR              ; clear X flag
                SHL     1, R7                   ; move bit pointer to next bit
                RBRA    _ROSMS_4A, !Z           ; next bit

                ADD     1, R0                   ; next M2M$CFM_DATA "window"
                CMP     16, R0
                RBRA    _ROSMS_3, !Z

                ; Flush SD card write buffer (R8: file handle) to write
                ; the file to the actual hardware.
_ROSMS_7        SYSCALL(f32_fflush, 1)          ; flush SD write buffer
                CMP     0, R9                   ; error?
                RBRA    _ROSMS_8, Z             ; no: proceed
                MOVE    ERR_FATAL_ROSMF, R8     ; yes: fatal; R9: error code
                RBRA    FATAL, 1

                ; Log success message
_ROSMS_8        MOVE    LOG_STR_CFG_REM, R8
                SYSCALL(puts, 1)

_ROSMS_RET      SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Data structure and functions for OPTM_INIT
; ----------------------------------------------------------------------------

; Menu initialization record (needed by OPTM_INIT)
; Will be copied to the HEAP, together with the configuration data from
; config.vhd and then modified to point to the right addresses on the heap
OPT_MENU_DATA   .DW     SCR$CLR, SCR$PRINTFRAME, OPT_PRINTSTR, SCR$PRINTSTRXY
                .DW     OPT_PRINTLINE, OPT_SELECT, OPT_MENU_GETKEY
                .DW     OPTM_CB_SEL, OPTM_CB_SHOW, FATAL,
                .DW     M2M$OPT_SEL_MULTI, 0    ; selection char + zero term.:
                .DW     M2M$OPT_SEL_SINGLE, 0   ; multi- and single-select
                .DW     0, 0, 0, 0, 0           ; will be filled dynamically

; Print function that handles everything incl. cursor pos and \n by itself
; R8 contains the string that shall be printed
; R9 contains a pointer to a mask array: the first word is the size of the
;    array (and therefore the amount of menu items) and then we have one entry
;    (word) per menu line: If the highest bit is one, then OPTM_FP_PRINT will
;    print the line otherwise it will skip the line
OPT_PRINTSTR    SYSCALL(enter, 1)

                MOVE    @R9++, R0               ; R0: size of menu
                MOVE    R9, R1                  ; R1: pointer to mask array
                MOVE    R8, R2                  ; R2: current string segment
                MOVE    SP, R3                  ; R3: remember stack pointer
                XOR     R4, R4                  ; R4: item counter

_OPT_PRINTSTR_1 MOVE    R2, R8                  ; treat current seg. as start

                MOVE    OPTM_NL, R9             ; string containing \n
                SYSCALL(strstr, 1)              ; search in input string
                CMP     0, R10                  ; \n found?
                RBRA    _OPT_PRINTSTR_F, Z      ; no: fatal

                MOVE    R10, R6                 ; R6: length of segment..
                SUB     R2, R6                  
                ADD     2, R6                   ; ..including \n                              

                CMP     @R1++, 0x7FFF           ; print current item?
                RBRA    _OPT_PRINTSTR_2, !N     ; no: next iteration

                ; copy current segment to the stack so that we can add a
                ; zero terminator so that SCR$PRINTSTR can print it
                SUB     R6, SP                  ; reserve space on stack
                SUB     1, SP                   ; add space for zero term.
                MOVE    R2, R8                  ; copy string segment
                MOVE    SP, R9
                MOVE    R6, R10
                SYSCALL(memcpy, 1)
                ADD     R6, R9
                MOVE    0, @R9                  ; add zero terminator
                MOVE    SP, R8                  ; print current segment
                RSUB    SCR$PRINTSTR, 1

                MOVE    R3, SP                  ; restore stack pointer

_OPT_PRINTSTR_2 ADD     R6, R2                  ; skip current segment
                ADD     1, R4                   ; next item
                CMP     R0, R4                  ; done?
                RBRA    _OPT_PRINTSTR_1, !Z     ; no: iterate

                SYSCALL(leave, 1)               ; yes, done: return
                RET

_OPT_PRINTSTR_F MOVE    ERR_F_NEWLINE, R8      ; fatal due to missing newline
                XOR     R9, R9
                RBRA    FATAL, 1                

; Draws a horizontal line/menu separator at the y-pos given in R8, dx in R9
OPT_PRINTLINE   INCRB

                MOVE    SP, R0                  ; R0: use to restore stack
                MOVE    R8, R1                  ; R1: y-pos
                MOVE    OPTM_DX, R2             ; R2: width minus left/right..
                MOVE    @R2, R2                 ; ..boundary
                SUB     2, R2                   

                SUB     R2, SP                  ; memory for string
                SUB     3, SP                   ; 3: l/r boundary + zero term.
                MOVE    SP, R3
                MOVE    R3, R4                  ; remember for printing

                MOVE    M2M$NC_VE_LEFT, @R3++                
_PRINTLN_L      MOVE    M2M$NC_SH, @R3++
                SUB     1, R2
                RBRA    _PRINTLN_L, !Z
                MOVE    M2M$NC_VE_RIGHT, @R3++
                MOVE    0, @R3

                MOVE    R4, R8
                MOVE    OPTM_X, R9
                MOVE    @R9, R9
                MOVE    R1, R10
                RSUB    SCR$PRINTSTRXY, 1                

                MOVE    R0, SP
                DECRB
                RET

; Selects/unselects menu item in R8 (counting from 0 and counting also
; non-selectable menu entries such as lines) and highlights headlines/titles
; R9=0: unselect
; R9=1: select
; R9=2: print headline/title highlighted
; R9=3: select highlighted headline/title
OPT_SELECT      INCRB

                MOVE    OPTM_X, R0              ; R0: x start coordinate
                MOVE    @R0, R0
                ADD     1, R0
                MOVE    OPTM_Y, R1              ; R1: y start coordinate
                MOVE    @R1, R1
                ADD     1, R1
                ADD     R8, R1
                MOVE    OPTM_DX, R2             ; R2: width of selection
                MOVE    @R2, R2
                SUB     2, R2

                ; define attribute to apply
                MOVE    M2M$SA_COL_STD, R3      ; unselect = standard text
                CMP     OPTM_SEL_STD, R9        ; unselect/standard?
                RBRA    _OPTM_FPS_2, Z          ; yes
                CMP     OPTM_SEL_SEL, R9        ; select?
                RBRA    _OPTM_FPS1A, !Z         ; no
                MOVE    M2M$SA_COL_STD_INV, R3  ; yes, select
                RBRA    _OPTM_FPS_2, 1
_OPTM_FPS1A     CMP     OPTM_SEL_TLL, R9        ; headline/title?
                RBRA    _OPTM_FPS1B, !Z         ; no
                MOVE    M2M$SA_COL_TTLE, R3     ; yes, headline/title
                RBRA    _OPTM_FPS_2, 1
_OPTM_FPS1B     CMP     OPTM_SEL_TLLSEL, R9     ; selected headline/title?
                RBRA    _OPTM_FPS_2, !Z         ; no: default to standard text
                MOVE    M2M$SA_COL_TTLE_INV, R3 ; yes, selected headl./title          

_OPTM_FPS_2     MOVE    SCR$SYS_DX, R8          ; R10: start address in ..
                MOVE    @R8, R8
                MOVE    R1, R9                  ; .. attribute VRAM
                SYSCALL(mulu, 1)
                ADD     R0, R10
                ADD     M2M$RAMROM_DATA, R10

                MOVE    M2M$RAMROM_DEV, R4      ; switch to ATTR data, win 0
                MOVE    M2M$VRAM_ATTR, @R4
                MOVE    M2M$RAMROM_4KWIN, R4
                MOVE    0, @R4

                XOR     R4, R4
_OPTM_FPS_L     CMP     R2, R4
                RBRA    _OPTM_FPS_RET, Z
                MOVE    R3, @R10++
                ADD     1, R4
                RBRA    _OPTM_FPS_L, 1

_OPTM_FPS_RET   DECRB
                RET                

; Waits until one of the five Option Menu keys is pressed
; and returns the OPTM_KEY_* code in R8
;
; since the "wait for keypress" loop would otherwise block the entire QNICE
; (we are currently not using interrupts), we need to put everything that
; needs to continue to run in the background in here
OPT_MENU_GETKEY INCRB

                ; handle IO and react to IO-induced events so that opening
                ; the options menu is not interrupting any IO and so that the
                ; status shown by the options menu is always real-time
_OPTMGK_LOOP    RSUB    HANDLE_IO, 1            ; IO handling (e.g. vdrives)
                RSUB    VD_MNT_ST_GET, 1        ; did mount status change..
                RSUB    _OPTM_GK_MNT, C         ; ..while OPTM is open?
                RSUB    CRTROM_MLST_GET, 1      ; CRT/ROM ld status changed..
                RSUB    _OPTM_GK_CRTROM, C      ; ..while OPTM is open?
                RSUB    VD_DTY_ST_GET, 1        ; did cache status change..
                RBRA    _OPTMGK_KEYSCAN, !C     ; ..while OPTM is open?
                RSUB    OPTM_SHOW, 1            ; yes: redraw menu and..
                MOVE    OPTM_CUR_SEL, R8        ; ..re-show menu item selector
                MOVE    @R8, R8
                MOVE    OPTM_SEL_SEL, R9
                RSUB    OPTM_SELECT, 1

                ; scan for any key
_OPTMGK_KEYSCAN RSUB    KEYB$SCAN, 1            ; wait until key is pressed
                RSUB    KEYB$GETKEY, 1
                CMP     0, R8
                RBRA    _OPTMGK_LOOP, Z

                ; check, if one of the options menu keys is pressed and
                ; act accordingly

                CMP     M2M$KEY_UP, R8          ; Up
                RBRA    _OPTM_GK_1, !Z
                MOVE    OPTM_KEY_UP, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_1      CMP     M2M$KEY_DOWN, R8        ; Down
                RBRA    _OPTM_GK_2A, !Z
                MOVE    OPTM_KEY_DOWN, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_2A     CMP     M2M$KEY_RETURN, R8      ; Return (select)
                RBRA    _OPTM_GK_2B, !Z
                MOVE    OPTM_KEY_SELECT, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_2B     CMP     M2M$KEY_SPACE, R8       ; Space (alternative select)
                RBRA    _OPTM_GK_3, !Z
                MOVE    OPTM_KEY_SELALT, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_3      CMP     M2M$KEY_HELP, R8        ; Help (close menu)
                RBRA    _OPTM_GK_4, !Z
                MOVE    OPTM_KEY_CLOSE, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_4      CMP     M2M$KEY_RUNSTOP, R8     ; Run/Stop (one menu level up)
                RBRA    _OPTMGK_LOOP, !Z        ; other key: ignore
                MOVE    OPTM_KEY_MENUUP, R8

_OPTMGK_RET     DECRB
                RET

                ; the archetypical situation that the mount status changes
                ; "in the background", i.e. not controlled by any callback
                ; function while the OPTM is open, is a "Smart Reset" reset
                ; of the core. "Core" as in "core only", not the framework.
_OPTM_GK_MNT    SYSCALL(enter, 1)

                RSUB    VD_ACTIVE, 1            ; are there any vdrives?
                RBRA    _OPTM_GK_MNT_R, !C      ; no: return

                ; reset the menu data structure according to the mount status
                ; of the vdrives: iterate through each bit of the mount status
                ; and set the data structure accordingly
                XOR     R0, R0                  ; vdrive counter
                MOVE    VDRIVES_NUM, R1         ; R1: amount of vdrives
                MOVE    @R1, R1
                RSUB    VD_MNT_ST_GET, 1        ; R2: current status
                MOVE    R8, R2

_OPTM_GK_MNT_1  MOVE    R0, R8                  ; R9: index of vdrive men. itm
                RSUB    VD_MENGRP, 1
                RBRA    _OPTM_GK_MNT_2, C

                MOVE    ERR_FATAL_INST, R8      ; no menu itm for drive: fatal
                MOVE    ERR_FATAL_INST4, R9
                RBRA    FATAL, 1

_OPTM_GK_MNT_2  MOVE    R9, R8
                SHR     1, R2                   ; read next status bit
                RBRA    _OPTM_GK_MNT_X1, X
                MOVE    0, R9
                RBRA    _OPTM_GK_MNT_3, 1
_OPTM_GK_MNT_X1 MOVE    1, R9

_OPTM_GK_MNT_3  RSUB    OPTM_SET, 1             ; set/unset menu item
                                                ; (R8=menu item, R9=value)

                ; update M2M$CFM_DATA accordingly:
                ; window within M2M$CFM_DATA = R0 / 16
                ; bit within window = R0 % 16
                MOVE    R8, R3
                MOVE    R8, R4
                AND     0xFFFB, SR              ; clear Carry
                SHR     4, R3                   ; R3 = R0 / 16
                AND     0x000F, R4              ; R4 = R0 % 16
                MOVE    M2M$CFM_ADDR, R5
                MOVE    R3, @R5

                MOVE    1, R6                   ; will be used to set/del bit
                AND     0xFFFD, SR              ; clear X
                SHL     R4, R6

                MOVE    M2M$CFM_DATA, R5

                CMP     0, R9
                RBRA    _OPTM_GK_MNT_4, !Z
                NOT     R6, R6
                AND     R6, @R5                 ; clear bit                               

                RBRA    _OPTM_GK_MNT_5, 1

_OPTM_GK_MNT_4  OR      R6, @R5                 ; set bit

_OPTM_GK_MNT_5  ADD     1, R0
                CMP     R0, R1
                RBRA    _OPTM_GK_MNT_1, !Z              

                ; a core-reset unmounts some or all drives: redraw menu to
                ; make sure that the drives are not shown as mounted any more
                ; (this routine is also used by _OPTM_GK_CRTROM)
_OPTM_GK_MNT_S  RSUB    OPTM_SHOW, 1

                ; re-show the currently selected item
                MOVE    OPTM_CUR_SEL, R8
                MOVE    @R8, R8
                MOVE    OPTM_SEL_SEL, R9
                RSUB    OPTM_SELECT, 1

_OPTM_GK_MNT_R  SYSCALL(leave, 1)
                RET

                ; This helper function is similar _OPTM_GK_MNT but it is
                ; all about manually loadable CRTs/ROMs
                ; R8: CRT/ROM ID of the manually loadable CRT/ROM which
                ;     has a changed status
                ; R9: new status of this very CRT/ROM
_OPTM_GK_CRTROM SYSCALL(enter, 1)

_OPTM_GK_CR_0   MOVE    R9, R0
                RSUB    CRTROM_M_GI, 1          ; convert id into menu idx
                RBRA    _OPTM_GK_CR_1, C        ; OK: continue
                MOVE    ERR_FATAL_INST, R8      ; not OK: fatal
                MOVE    ERR_FATAL_INSTB, R9
                RBRA    FATAL, 1

                ; change visual and register representation
_OPTM_GK_CR_1   MOVE    R9, R8                  ; R8: menu index
                MOVE    R0, R9                  ; R9: set/unset
                RSUB    OPTM_SET, 1             ; visual representation
                RSUB    M2M$SET_SETTING, 1      ; register representation

                ; next iteration: one call of CRTROM_MLST_GET does not
                ; capture all possible changes
                RSUB    CRTROM_MLST_GET, 1
                RBRA    _OPTM_GK_CR_0, C

                ; redraw menu and then call SYSCALL(leave, 1) and RET
                RBRA    _OPTM_GK_MNT_S, 1

_OPTM_GK_CR_R   SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Callback function that is called during the execution of the menu (OPTM_RUN)
;
; R8: selected menu group (as defined in OPTM_IR_GROUPS)
; R9: selected item within menu group
;     in case of single selected items: 0=not selected, 1=selected
;
; R10: OPTM_KEY_SELECT (normally means "Return") or
;      OPTM_KEY_SELALT (normally means "Space")
;
; For making sure that the hardware can react in "real-time" to menu item
; changes, i.e. even before the menu is closed, we are updating the
; QNICE M2M$CFM_DATA register each time something changes.
; ----------------------------------------------------------------------------

OPTM_CB_SEL     SYSCALL(enter, 1)

                ; Remember selected menu group as Context Data so that the
                ; user of the framework can implement specialized behaviors
                ; for certain menu items
                MOVE    SF_CONTEXT_DATA, R1
                MOVE    @R1, R0
                MOVE    R8, @R1
                AND     0x00FF, @R1             ; only the actual ID

                MOVE    R8, R2
                MOVE    R9, R3

                INCRB

                ; OSM_SEL_PRE: CORE/m2m-rom/m2m-rom.asm callback function
                MOVE    R8, R0
                AND     0x00FF, R8              ; remove flags
                MOVE    R9, R1
                RSUB    OSM_SEL_PRE, 1
                CMP     0, R8
                RBRA    _OPTMC_START, Z
                RBRA    FATAL, 1

_OPTMC_START    MOVE    R0, R8
                MOVE    R1, R9

                ; Special treatment for help menu items
                RSUB    HANDLE_HELP, 1
                RBRA    _OPTMC_NOMNT_1, C       ; if help then no drive mount

                ; Special treatment for drive-mount items and for manual
                ; CRT and ROM load items: These type of items are per
                ; definition also single-select items
                MOVE    R8, R0                  ; R8: selected menu group
                MOVE    R0, R1                  ; R1: save selected group
                MOVE    R9, R2                  ; R2: save select item in grp
                AND     OPTM_SINGLESEL, R0      ; single-select item?
                RBRA    _OPTMC_NOMNT_1, Z       ; no: proceed to std. beh.

                ; Virtual drive mounting?
                RSUB    VD_ACTIVE, 1            ; are there any vdrives?
                RBRA    _OPTMC_CHKCR, !C        ; no: proceed to CRT/ROM chk
                MOVE    R1, R8                  ; restore R8
                RSUB    VD_DRVNO, 1             ; is menu item a mount item?
                RBRA    _OPTMC_CHKCR, !C        ; no: proceed to CRT/ROM chk

                ; Handle virtual drive mounting
                ; It is important that the standard behavior runs after the
                ; mounting is done, this is why we do RSUB and not RBRA
_OPTMC_MOUNT    MOVE    R10, R9                 ; selection mode
                XOR     R10, R10                ; virtual drive mode
                RSUB    HANDLE_MOUNTING, 1
                RBRA    _OPTMC_NOMNT_0, 1       ; standard behavior

                ; Manual CRT or ROM loading?
_OPTMC_CHKCR    RSUB    CRTROM_ACTIVE, 1        ; any manual CRTs/ROMs avail.?
                RBRA    _OPTMC_NOMNT_0, !C      ; no: proceed to std. behvr.
                MOVE    R1, R8                  ; restore R8
                RSUB    CRTROM_M_NO, 1          ; is menu item man. CRT/ROM?
                RBRA    _OPTMC_NOMNT_0, !C      ; no: proceed to std. behvr.

                ; Handle manual CRT/ROM loading
                ; R8 contains the CRT/ROM number at this point
                ; It is important that the standard behavior runs after the
                ; loading is done
                MOVE    R10, R9                 ; selection mode
                MOVE    1, R10                  ; CRT/ROM load mode
                RSUB    HANDLE_MOUNTING, 1

_OPTMC_NOMNT_0  MOVE    R1, R8                  ; restore R8
                MOVE    R2, R9                  ; restore R9

                ; Standard behavior
_OPTMC_NOMNT_1  MOVE    R8, R7                  ; For detecting CLOSE, we..
                AND     0x00FF, R7              ; ..only look at low-byte
                CMP     OPTM_CLOSE, R7          ; CLOSE = no changes: leave
                RBRA    _OPTMCB_RET, Z

                MOVE    OPTM_ICOUNT, R0         ; R0: amount of menu items
                MOVE    @R0, R0
                MOVE    HEAP, R1                ; R1: words in consecutive..
                ADD     OPTM_IR_STDSEL, R1      ; ..memory layout containing..
                MOVE    @R1, R1                 ; ..the current selection
                MOVE    M2M$CFM_ADDR, R2        ; R2: "bank" selector
                MOVE    0, @R2
                MOVE    M2M$CFM_DATA, R3        ; R3: QNICE target register
                MOVE    1, R4                   ; R4: mask to set bit
                XOR     R5, R5                  ; R5: bit counter/switch bank

_OPTMCB_A       CMP     @R1++, 1                ; set or clear bit?
                RBRA    _OPTMCB_B, !Z           ; go to: clear
                OR      R4, @R3                 ; set
                RBRA    _OPTMCB_C, 1

_OPTMCB_B       NOT     R4, R6                  ; inverse R4 to clear bit
                AND     R6, @R3
                
_OPTMCB_C       ADD     1, R5                   ; "bank" switch necessary?
                CMP     16, R5
                RBRA    _OPTMCB_D, !Z           ; no
                ADD     1, @R2                  ; yes
                XOR     R5, R5
                MOVE    1, R4
                RBRA    _OPTMCB_E, 1

_OPTMCB_D       AND     0xFFFD, SR              ; clear X
                SHL     1, R4                   ; next bit position

_OPTMCB_E       SUB     1, R0
                RBRA    _OPTMCB_A, !Z

_OPTMCB_RET     DECRB

                ; OSM_SEL_POST: CORE/m2m-rom/m2m-rom.asm callback function
                MOVE    R2, R8
                AND     0x00FF, R8              ; remove flags            
                MOVE    R3, R9
                RSUB    OSM_SEL_POST, 1
                CMP     0, R8
                RBRA    _OPTMC_END, Z
                RBRA    FATAL, 1

_OPTMC_END      MOVE    SF_CONTEXT_DATA, R1
                MOVE    R0, @R1                 ; restore context

                SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Callback function that is called during the drawing of the menu (OPTM_SHOW)
; if there is a "%s" within a menu item.
;
; menu.asm is not aware of the semantics that we are implementing here:
;
; Case (a) Submenus:
;
; In case of submenus, the semantics can be defined by the user of the
; framework in SUBMENU_SUMMARY in m2m-rom.asm. The standard semantics are:
; Replace %s by the selected menu item of the first menu group. If there is
; no menu group then fatal, because then one should not have put an %s in the
; headline - or - one should have used SUBMENU_SUMMARY to define a custom
; semantics.
;
; Case (b) Virtual drives and CRT/ROM loading
;
; "%s" is meant to denote the space where we will either print
; OPTM_S_MOUNT/OPTM_S_CRTROM from config.vhd, which is "<Mount>" and "<Load>"
; by default, if the drive/rom is not mounted/loaded, yet, or we print the
; file name of the disk image, abbreviated to the width of the frame. We also
; handle the "cache dirty" situation and show OPTM_S_SAVING which defaults
; to "<Saving>".
;
; Input:
;   R8: pointer to the string that includes the "%s"
;   R9: index of menu item
; Output:
;   R8: Pointer to a completely new string that shall be shown instead of
;       the original string that contains the "%s"; so do not just replace
;       the "%s" inside the string but provide a completely new string.
;       Alternatively, if you do not want to change the string, you can
;       just return R8 unchanged.
; ----------------------------------------------------------------------------

OPTM_CB_SHOW    SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: string pointer
                MOVE    R0, R7
                MOVE    R9, R5                  ; R5: remember R9

                ; get menu group ID associated with this menu item
                ; (mount menu items need to have unique group IDs)
                MOVE    M2M$RAMROM_DEV, R1
                MOVE    M2M$CONFIG, @R1
                MOVE    M2M$RAMROM_4KWIN, R1
                MOVE    M2M$CFG_OPTM_GROUPS, @R1
                MOVE    M2M$RAMROM_DATA, R1
                ADD     R9, R1
                MOVE    @R1, R1                 ; R1: menu group id

                MOVE    M2M$RAMROM_DATA, R6
                MOVE    OPTM_ICOUNT, R3
                ADD     @R3, R6                 ; R6: 1 word behind last item

                ; ------------------------------------------------------------
                ; Case (a): Submenus
                ; ------------------------------------------------------------

                MOVE    R1, R2
                MOVE    R5, R4                  ; remember R5: menu index
                AND     OPTM_SUBMENU, R2        ; is this group id a submenu?
                RBRA    _OPTM_CBS_VD, Z         ; no: go on with case (b)

                ; Check if the M2M user defined a custom SUBMENU_SUMMARY and
                ; if yes, use the string returned by SUBMENU_SUMMARY
                MOVE    R9, R10
                MOVE    M2M$RAMROM_DATA, R9
                ADD     R10, R9                 ; R9: ptr to current men. item
                MOVE    R6, R10                 ; R10: end-of-menu marker
                RSUB    SUBMENU_SUMMARY, 1
                MOVE    R8, R0                  ; custom SUBMENU_SUMMARY?
                RBRA    _OPTM_CBS_RET, !Z       ; yes
                MOVE    R7, R0                  ; no: standard semantics
                MOVE    R9, R3                  ; R3: ptr to current men. item

                ; Search for the first menu group within the submenu and
                ; within this menu group, find the currently selected item
_OPTM_CBS_A     ADD     1, R3                   ; next item
                CMP     R6, R3                  ; end of (overall)menu?
                RBRA    _OPTM_CBS_B, !Z         ; no: continue
                MOVE    ERR_F_MENUSUB, R8       ; yes: fatal
                XOR     R9, R9
                RBRA    FATAL, 1
_OPTM_CBS_B     MOVE    @R3, R1
                AND     OPTM_SUBMENU, R1        ; end-of-submenu marker?
                RBRA    _OPTM_CBS_C, Z          ; no: continue
                MOVE    ERR_F_MENUNGRP, R8      ; yes: fatal
                MOVE    R5, R9
                RBRA    FATAL, 1
_OPTM_CBS_C     MOVE    @R3, R8
                MOVE    1, R9
                MOVE    255, R10
                SYSCALL(in_range_u, 1)          ; is the item a menu group?
                RBRA    _OPTM_CBS_A, !C         ; no: next item
                MOVE    HEAP, R8                ; get selected menu group item
                ADD     OPTM_IR_STDSEL, R8
                MOVE    @R8, R8
                ADD     R3, R8
                SUB     M2M$RAMROM_DATA, R8     ; R3 is relative to RAMROM_DTA
                MOVE    @R8, R8                 ; is the item selected?
                RBRA    _OPTM_CBS_A, Z          ; no

                ; extract the label of the selected item from the \n separated
                ; OPTM_ITEMS string
                SUB     M2M$RAMROM_DATA, R3     ; R3: index of selected item
                MOVE    HEAP, R1
                ADD     OPTM_IR_ITEMS, R1
                MOVE    @R1, R1                 ; R1: current segment in strng
                XOR     R2, R2                  ; R2: loop variable
_OPTM_CBS_D     MOVE    R1, R8
                MOVE    OPTM_NL, R9
                SYSCALL(strstr, 1)
                CMP     0, R10                  ; \n found?
                RBRA    _OPTM_CBS_E, !Z         ; yes: proceed
                MOVE    ERR_FATAL_INST, R8      ; no: fatal
                MOVE    ERR_FATAL_INST1, R9
                RBRA    FATAL, 1
_OPTM_CBS_E     CMP     R2, R3                  ; selected item reached?
                RBRA    _OPTM_CBS_F, Z          ; yes
                ADD     2, R10                  ; no: skip \n and proceed
                MOVE    R10, R1
                ADD     1, R2
                RBRA    _OPTM_CBS_D, 1          ; next item

                ; find next \n to determine the length of the current segment
                ; and copy it to the stack so that we can add a zero-terminatr
                ; to make sure that the \n is not derailing M2M$RPL_S
_OPTM_CBS_F     MOVE    R1, R8
                MOVE    OPTM_NL, R9
                SYSCALL(strstr, 1)
                CMP     0, R10                  ; \n found?
                RBRA    _OPTM_CBS_G, !Z         ; yes: proceed
                MOVE    ERR_FATAL_INST, R8      ; no: fatal
                MOVE    ERR_FATAL_INST1, R9
                RBRA    FATAL, 1
_OPTM_CBS_G     MOVE    SP, R7                  ; remember SP
                MOVE    R1, R8
                SUB     R8, R10                 ; R10: length until \n
                SUB     R10, SP
                SUB     1, SP                   ; room for zero-terminator
                MOVE    SP, R9
                SYSCALL(memcpy, 1)
                MOVE    R9, R1                  ; R1: replacement string segm.
                ADD     R10, R9
                MOVE    0, @R9                  ; add zero terminator

                ; Get rid of leading spaces. We can assume that the string
                ; consists at least of a %s, so there will be at least a bunch
                ; non-space characters
_OPTM_CBS_H     CMP     0x0020, @R1
                RBRA    _OPTM_CBS_I, !Z         ; non-space character found
                ADD     1, R1
                RBRA    _OPTM_CBS_H, 1

                ; Determine position in OPTM_HEAP that we can use for our
                ; string replacement: The space that can be used for 
                ; the headline/label strings of submenus is directly after the
                ; abbreviated filenames of the vdrives.
                ;
                ; We need to calculate which submenu is currently being
                ; processed by OPTM_CB_SHOW. Since submenus do not have any
                ; unique ID, we need to find out by counting: We walk through
                ; M2M$CFG_OPTM_GROUPS until we reach the index of the
                ; currently processed menu item (which is stored in R5) and
                ; while doing so, we count the index of the current submenu.
                ;
                ; Then we take this result and calculate the position on the
                ; heap which is:
                ; (Amount of vdrives + current submenu index) * @SCR$OSM_O_DX

                ; Calculate such submenu is currently being processed
_OPTM_CBS_I     MOVE    SCRATCH_HEX, R8         ; save cur. device selection
                RSUB    SAVE_DEVSEL, 1
                MOVE    R4, R8                  ; R8: index of menu item
                INCRB

                MOVE    OPTM_ICOUNT, R0         ; check: valid menu index?
                MOVE    @R0, R0
                SUB     1, R0                   ; we count from zero
                CMP     R8, R0                  ; illegal index?
                RBRA    _OPTM_CBS_I1, !N        ; no
                MOVE    ERR_FATAL_INST, R8      ; yes: fatal
                MOVE    ERR_FATAL_INST8, R9
                RBRA    FATAL, 1

_OPTM_CBS_I1    MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    M2M$CFG_OPTM_GROUPS, @R0
                MOVE    M2M$RAMROM_DATA, R0

                MOVE    -1, R9                  ; submenu index

_OPTM_CBS_I2    MOVE    @R0++, R1               ; is current item a submenu?
                MOVE    R1, R2
                AND     OPTM_SUBMENU, R1
                RBRA    _OPTM_CBS_I3, Z         ; no
                AND     0x00FF, R2              ; yes, but is it a close flag?
                CMP     OPTM_CLOSE, R2
                RBRA    _OPTM_CBS_I3, Z         ; yes: so do not count it
                ADD     1, R9                   ; no: increase submenu index

_OPTM_CBS_I3    CMP     0, R8                   ; done?
                RBRA    _OPTM_CBS_I4, Z         ; yes
                SUB     1, R8                   ; one less menu item
                RBRA    _OPTM_CBS_I2, 1         ; no
_OPTM_CBS_I4    DECRB
                MOVE    SCRATCH_HEX, R8         ; restore cur. dev. selection
                RSUB    RESTORE_DEVSEL, 1
                CMP     0, R9                   ; illegal submenu index?
                RBRA    _OPTM_CBS_I5, !V        ; no: proceed
                MOVE    ERR_FATAL_INST, R8      ; yes: fatal
                MOVE    ERR_FATAL_INST9, R9
                RBRA    FATAL, 1

                ; Calculate OPTM_HEAP position we can use for str. replacement
                ; R9 contains the submenu index:
                ; (Amount of vdrives + current submenu index) * @SCR$OSM_O_DX                
_OPTM_CBS_I5    MOVE    VDRIVES_NUM, R8
                MOVE    @R8, R8
                ADD     R9, R8
                MOVE    SCR$OSM_O_DX, R9
                MOVE    @R9, R9
                MOVE    R9, R5                  ; R5: @SCR$OSM_O_DX
                SYSCALL(mulu, 1)                ; R10: result

                ; Perform the string replacement
                MOVE    R0, R8                  ; R8: source string
                MOVE    OPTM_HEAP, R9           ; R9: target string
                MOVE    @R9, R9
                ADD     R10, R9
                MOVE    R1, R10                 ; R10: replacement for %s
                MOVE    R5, R11                 ; R11: max. amt. of chars
                SUB     2, R11
                RSUB    M2M$RPL_S, 1            ; replace %s

                ADD     1, @R2                  ; next iteration of callback
                MOVE    R9, R0                  ; return target string
                MOVE    R7, SP                  ; restore SP

                RBRA    _OPTM_CBS_RET, 1        ; case done; skip other cases

                ; ------------------------------------------------------------
                ; Case (b-1): Virtual Drives
                ; ------------------------------------------------------------

                ; VD_DRVNO checks if the menu item is associated with a
                ; virtual drive and returns the virtual drive number in R8
_OPTM_CBS_VD    MOVE    R1, R8
                RSUB    VD_DRVNO, 1
                RBRA    _OPTM_CBS_CTRM, !C

                ; Check if the amount of VDRIVES that are configured in
                ; globals.vhd is large enough to accomodate the current VDRIVE
                MOVE    R8, R0
                ADD     1, R0
                MOVE    VDRIVES_NUM, R3
                CMP     R0, @R3
                RBRA    _OPTM_CBS_0, !N
                MOVE    R8, R9
                MOVE    ERR_F_MENUDRV, R8
                RSUB    FATAL, 1

                ; the position of the string for each virtual drive number
                ; equals virtual drive number times @SCR$OSM_O_DX, because
                ; each string will be smaller than the width of the menu
_OPTM_CBS_0     MOVE    SCR$OSM_O_DX, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)                ; R10: result lo word of mulu
                MOVE    OPTM_HEAP, R0           ; R0: string pointer
                MOVE    @R0, R0
                ADD     R10, R0

                ; Case #1: Drive is not mounted
                ; R8 still contains the virtual drive id.
                ; If the drive is not mounted, then show OPTM_S_MOUNT
                ; from config.vhd, which is "<Mount Drive>" by default
                RSUB    VD_MOUNTED, 1
                RBRA    _OPTM_CBS_1, C          ; yes: mounted
                MOVE    M2M$RAMROM_DEV, R3
                MOVE    M2M$CONFIG, @R3
                MOVE    M2M$RAMROM_4KWIN, R3
                MOVE    M2M$CFG_OPTM_MSTR, @R3
                MOVE    M2M$RAMROM_DATA, R8
                RSUB    _OPTM_CBS_REPL, 1       ; replace %s with OPTM_S_MOUNT
                RBRA    _OPTM_CBS_RET, 1

                ; Case #2: Drive is mounted: 
                ;
                ; Two sub-cases: If drive is mounted but the write cache is
                ; dirty, then proceed with Case #2a, else with #2b.
                ; R8 still contains the virtual drive id.
_OPTM_CBS_1     MOVE    VD_CACHE_DIRTY, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8                   ; cache dirty?
                RBRA    _OPTM_CBS_2, !Z         ; no: proceed with case #2b

                ; Case #2a: Show OPTM_S_SAVING (default: "<Saving>") if
                ; the cache is dirty, i.e. the core wrote to the disk image
                ; but it has not yet been flushed to the SD card

                ; See comment below at case #2b "Check, if..." to get the
                ; context of what is happening here. But in contrast to case
                ; #2b we use "2" instead of "1" as flag here. This has the
                ; advantage that case #2b can use this "2" to notice
                ; that we need to restore the original filename
                MOVE    SCR$OSM_O_DX, R8        ; read "%s is replaced" flag
                MOVE    @R8, R8
                SUB     1, R8
                ADD     R0, R8
                CMP     2, @R8                  ; did we replace earlier?
                RBRA    _OPTM_CBS_RET, Z        ; yes: return

                MOVE    R0, R8                  ; remember filename
                MOVE    OPTM_HEAP_LAST, R9
                MOVE    @R9, R9
                SYSCALL(strcpy, 1)

                MOVE    M2M$RAMROM_DEV, R3      ; replace %s w. OPTM_S_SAVING
                MOVE    M2M$CONFIG, @R3
                MOVE    M2M$RAMROM_4KWIN, R3
                MOVE    M2M$CFG_OPTM_SSTR, @R3
                MOVE    M2M$RAMROM_DATA, R8
                RSUB    _OPTM_CBS_REPL, 1

                MOVE    SCR$OSM_O_DX, R8        ; set "%s is replaced" flag
                MOVE    @R8, R8
                SUB     1, R8
                ADD     R0, R8
                MOVE    2, @R8                  ; we use "2" instead of "1"

                RBRA    _OPTM_CBS_RET, 1        ; case done; skip other cases

                ; Case #2b: Show name of disk image
                ; the replacement string was placed at R0 by HANDLE_MOUNTING
                ; in shell.asm; since this is "just" the replacement string
                ; for the "%s", we need to save it on the stack so that
                ; _OPTM_CBS_REPL can do its job

                ; Check, if we already did replace "%s" during a former
                ; callback: we use the last byte within the current line
                ; of the scratch buffer as flag. We can do this, because the
                ; scratch buffer is 2 bytes longer than the maximum length
                ; of the string; one of these bytes is used for the zero
                ; terminator in case of a long string and one is used for
                ; this flag.
                ; We need to check this, because otherwise we will have a
                ; nested replacement because %s will replaced by something
                ; that has already been the result of a replacement.
                ;
                ; Flag = 1: We replaced the file name in a former run of #2b
                ; Flag = 2: We replaced due to case #2a, i.e. we need to
                ;           restore the original filename
_OPTM_CBS_2     MOVE    SCR$OSM_O_DX, R8        ; read "%s is replaced" flag
                MOVE    @R8, R8
                SUB     1, R8
                ADD     R0, R8
                CMP     1, @R8                  ; did we replace earlier?
                RBRA    _OPTM_CBS_RET, Z        ; yes: return
                CMP     2, @R8                  ; case #2a before?
                RBRA    _OPTM_CBS_3, !Z         ; no: normal case #2b

                ; we need to restore the original filename
                MOVE    OPTM_HEAP_LAST, R8
                MOVE    @R8, R8
                MOVE    R0, R9
                SYSCALL(strcpy, 1)
                RBRA    _OPTM_CBS_4, 1          ; set replaced flag

                ; Replace %s by filename
_OPTM_CBS_3     MOVE    R0, R8
                SYSCALL(strlen, 1)
                ADD     1, R9                   ; space for zero terminator
                SUB     R9, SP
                MOVE    R9, R3                  ; for restoring the stack
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R8
                MOVE    R3, @--SP               ; _OPTM_CBS_REPL changes R3
                RSUB    _OPTM_CBS_REPL, 1
                MOVE    @SP++, R3
                ADD     R3, SP

_OPTM_CBS_4     MOVE    SCR$OSM_O_DX, R8        ; set "%s is replaced" flag
                MOVE    @R8, R8
                SUB     1, R8
                ADD     R0, R8
                MOVE    1, @R8

                RBRA    _OPTM_CBS_RET, 1        ; case done; skip other cases

                ; ------------------------------------------------------------
                ; Case (b-2): CRTs/ROMs
                ; ------------------------------------------------------------

                ; CRTROM_M_NO checks if the menu item is associated with a
                ; manual loadable CRT/ROM and returns the CRT/ROM number in R8
_OPTM_CBS_CTRM  MOVE    R1, R8
                RSUB    CRTROM_M_NO, 1
                RBRA    _OPTM_CBS_RET, !C
                MOVE    ERR_FATAL_INST6, R9
                RSUB    CRTROM_CHK_NO, 1        ; double-check sys. stability
                MOVE    R8, R1                  ; R1: CRT/ROM number

                ; Calculate the address on the heap that we can use as a
                ; scratch buffer for our string: (Amount of vdrives plus
                ; amount of submenus + CRT/ROM id (in R8)) times @SCR$OSM_O_DX
                MOVE    VDRIVES_NUM, R2
                ADD     @R2, R8
                MOVE    OPTM_SCOUNT, R2
                ADD     @R2, R8
                MOVE    SCR$OSM_O_DX, R9
                MOVE    @R9, R9
                MOVE    R9, R5                  ; R5: @SCR$OSM_O_DX
                SYSCALL(mulu, 1)                ; R10: result
                MOVE    OPTM_HEAP, R0           ; R0: target address on heap
                MOVE    @R0, R0
                ADD     R10, R0

                ; Has any CRT/ROM for the current line item been loaded
                ; already? Yes: Then we replace the %s by the filename,
                ; otherwise we replace it by the default string OPTM_S_CRTROM
                ; from config.vhd
                MOVE    CRTROM_MAN_LDF, R2
                ADD     R1, R2
                CMP     1, @R2
                RBRA    _OPTM_CBS_CTRM1, Z      ; yes: replace by filename

                ; Replace %s by default value
                MOVE    M2M$RAMROM_DEV, R3      ; replace %s w. OPTM_S_CRTROM
                MOVE    M2M$CONFIG, @R3
                MOVE    M2M$RAMROM_4KWIN, R3
                MOVE    M2M$CFG_OPTM_CRSTR, @R3
                MOVE    M2M$RAMROM_DATA, R8
                RSUB    _OPTM_CBS_REPL, 1
                RBRA    _OPTM_CBS_RET, 1

                ; Replace %s by filename by leveraging the existing
                ; routine above in _OPTM_CBS_3, but only if not already
                ; replaced. Within "Case (b-1)" above, see "Case #2b" to learn
                ; how the mechanism works.
_OPTM_CBS_CTRM1 MOVE    SCR$OSM_O_DX, R8        ; read "%s is replaced" flag
                MOVE    @R8, R8
                SUB     1, R8
                ADD     R0, R8
                CMP     1, @R8                  ; did we replace earlier?
                RBRA    _OPTM_CBS_3, !Z         ; no: do the replacement
                                                ; yes: return

_OPTM_CBS_RET   MOVE    R0, @--SP               ; lift R0 over the leave hump
                SYSCALL(leave, 1)
                MOVE    @SP++, R8
                RET

                ; subroutine within OPTM_CB_SHOW: expects R0 to point to
                ; the heap buffer where the ouput string shall land and
                ; expects the input string that has the "%s" that shall
                ; be replaced in R7 and actual replacement for the "%s"
                ; is expected in R8
_OPTM_CBS_REPL  MOVE    R8, R10
                MOVE    R0, R9
                MOVE    R7, R8

                ; the maximum width that we have to display the string is
                ; @SCR$OSM_O_DX minus 2 because of the frame
                MOVE    SCR$OSM_O_DX, R11
                MOVE    @R11, R11
                SUB     2, R11                  ; R11: max width

                RSUB    M2M$RPL_S, 1
                RET
