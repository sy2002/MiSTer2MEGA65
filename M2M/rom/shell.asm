; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Shell: User interface and core automation
;
; The intention of the Shell is to provide a uniform user interface and core
; automation for all MiSTer2MEGA65 projects.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Main Program
;
; START_SHELL is called from m2m-rom.asm as the main entry point to the Shell.
; The call is performed doing an RBRA not an RSUB, so the main program is
; not supposed to return to the caller.
; ----------------------------------------------------------------------------
     
                ; log M2M message to serial terminal (not visible to end user)
START_SHELL     MOVE    LOG_M2M, R8
                SYSCALL(puts, 1)

                ; ------------------------------------------------------------
                ; More robust SD card reading
                ; ------------------------------------------------------------

                ; Workaround that stabilizes the SD card handling: After a
                ; reset or a power-on: Wait a while. This is obviously neither
                ; a great nor a robust solution, but it increases the amount
                ; of readable SD cards greatly. It seems like the more used
                ; an SD card gets, the longer the initial startup sequence
                ; seems to last.

                ; Remember cycle counter for SD Card "stabilization" via
                ; waiting at least three seconds before allowing to mount it
                ; IO$CYC_MID updates with 50 MHz / 65535 = 763 Hz
                ; 3 seconds are 2289 updates of IO$CYC_MID (2289 = 0x08F1)
                MOVE    SD_WAIT_DONE, R8        ; set boolean flag to false
                MOVE    0, @R8                            
                MOVE    SD_CYC_MID, R8
                MOVE    IO$CYC_MID, R9          ; "mid-word" of sys. cyc. cntr
                MOVE    @R9, @R8
                MOVE    SD_CYC_HI, R8
                MOVE    IO$CYC_HI, R9           ; "hi-word" of sys. cyc. cntr
                MOVE    @R9, @R8

                ; ------------------------------------------------------------
                ; Initialize stack, heap, variables, libraries and IO
                ; ------------------------------------------------------------

                ; initialize device (SD card) and file handle
                MOVE    HANDLE_DEV, R8
                MOVE    0, @R8
                MOVE    HANDLE_FILE, R8
                MOVE    0, @R8

                ; initialize file browser persistence variables
                MOVE    M2M$CSR, R8             ; get active SD card
                MOVE    @R8, R8
                AND     M2M$CSR_SD_ACTIVE, R8
                MOVE    SD_ACTIVE, R9
                MOVE    R8, @R9
                RSUB    FB_INIT, 1              ; init persistence variables
                MOVE    FB_HEAP, R8             ; heap for file browsing
                MOVE    HEAP, @R8                 
                ADD     MENU_HEAP_SIZE, @R8

                ; The file browser remembers the cursor position of all nested
                ; directories so that when we climb up the directory tree, the
                ; cursor selects the correct item on the screen. We assume to
                ; be two levels deep at the beginning. This is why we push two
                ; 0 on the stack and remove one of them, inside SELECT_FILE
                ; in case we revert back to the root folder.
                MOVE    0, @--SP
                MOVE    0, @--SP
                MOVE    FB_STACK_INIT, R8       ; used to restore FB_STACK
                MOVE    SP, @R8
                MOVE    FB_STACK, R8
                MOVE    SP, @R8                
                SUB     B_STACK_SIZE, SP        ; reserve memory on the stack

                ; make sure OPTM_HEAP is initialized to zero, as it will be
                ; calculated and activated inside HELP_MENU
                MOVE    OPTM_HEAP, R8
                MOVE    0, @R8
                MOVE    OPTM_HEAP_SIZE, R8
                MOVE    0, @R8

                ; Initialize libraries: The order in which these libraries are
                ; initialized matters and the initialization needs to happen
                ; before RP_SYSTEM_START is called.
                RSUB    SCR$INIT, 1             ; retrieve VHDL generics
                RSUB    FRAME_FULLSCR, 1        ; draw fullscreen frame
                RSUB    VD_INIT, 1              ; virtual drive system
                RSUB    KEYB$INIT, 1            ; keyboard library
                RSUB    HELP_MENU_INIT, 1       ; menu library

                ; ------------------------------------------------------------
                ; Reset management
                ; ------------------------------------------------------------

                ; The reset management should be executed after HELP_MENU_INIT
                ; so that option menu default settings that affect clock
                ; speeds are already set in the M2M$CFM_DATA register and
                ; therefore influencing the core directly after reset.
                ; Of course this happens only when config.vhd is configured
                ; such, that the core is reset at all at this point in time.
                ; The Control & Status Register (M2M$CSR) is reset/initialized
                ; too, so any setting done before this line is ignored
                RSUB    RP_SYSTEM_START, 1

                ; ------------------------------------------------------------
                ; Welcome screen
                ; ------------------------------------------------------------

                ; Show welcome screen at all?
                RSUB    RP_WELCOME, 1
                RBRA    START_CONNECT, !C
                RSUB    SHOW_WELCOME, 1

                ; Unreset (in case the core is still in reset at this point
                ; due to RESET_KEEP in config.vhd) and connect keyboard and
                ; joysticks to the core (in case they were disconnected)
                ; Avoid that the keypress to exit the splash screen (if any)
                ; gets noticed by the core: Wait 0.3 second and only after
                ; that connect the keyboard and the joysticks to the core
START_CONNECT   RSUB    WAIT333MS, 1
                MOVE    M2M$CSR, R0
                AND     M2M$CSR_UN_RESET, @R0
                OR      M2M$CSR_KBD_JOY, @R0

                ; ------------------------------------------------------------
                ; Main loop:
                ;
                ; The core is running and QNICE is waiting for triggers to
                ; react. Such triggers could be for example the "Help" button
                ; which is meant to open the options menu but also triggers
                ; from the core such as data requests from disk drives.
                ;
                ; The latter one could also be done via interrupts, but we
                ; will try to keep it simple in the first iteration and only
                ; increase complexity by using interrupts if neccessary.
                ; ------------------------------------------------------------

MAIN_LOOP       RSUB    HANDLE_IO, 1            ; IO handling (e.g. vdrives)

                RSUB    KEYB$SCAN, 1            ; scan for single key presses
                RSUB    KEYB$GETKEY, 1

                RSUB    CHECK_DEBUG, 1          ; (Run/Stop+Cursor Up) + Help
                RSUB    HELP_MENU, 1            ; check/manage help menu

                RBRA    MAIN_LOOP, 1

                ; The main loop is an infinite loop therefore we do not need
                ; to restore the stack by adding back BROWSE_DEPTH to the
                ; stack pointer.

; ----------------------------------------------------------------------------
; SD card & virtual drive mount handling
; ----------------------------------------------------------------------------

; Handle mounting:
;
; Input:
;   R8 contains the drive number
;   R9=OPTM_KEY_SELECT:
;      Just replace the disk image, if it has been mounted
;      before without unmounting the drive (aka without
;      resetting the drive/"switching the drive on/off")
;   R9=OPTM_KEY_SELALT:
;      Unmount the drive (aka "switch the drive off")
HANDLE_MOUNTING SYSCALL(enter, 1)

                MOVE    R8, R7                  ; R7: drive number
                MOVE    R9, R6                  ; R6: mount mode

                RSUB    VD_MOUNTED, 1           ; C=1: the given drive in R8..
                RBRA    _HM_MOUNTED, C          ; ..is already mounted

                ; Drive in R8 is not yet mounted:
                ; 1. Hide OSM to enable the full-screen window
                ; 2. If the SD card is not yet mounted: mount it and handle
                ;    errors, allow re-tries, etc.
                ; 3. As soon as the SD card is mounted: Show the file browser
                ;    and let the user select a disk image
                ; 4. Copy the disk image into the mount buffer and hide
                ;    the fullscreen OSM afterwards
                ; 5. Notify MiSTer using the "SD" protocol (see vdrives.vhd)
                ; 6. Redraw and show the OSM, including the disk images
                ;    of the mounted drives

                ; Step #1 - Hide OSM and show full-screen window
_HM_START_MOUNT RSUB    SCR$OSM_OFF, 1
_HM_RETRY_MOUNT RSUB    FRAME_FULLSCR, 1
                MOVE    1, R8
                MOVE    1, R9
                RSUB    SCR$GOTOXY, 1
                RSUB    SCR$OSM_M_ON, 1

                ; Step #2 - Mount SD card
                MOVE    HANDLE_DEV, R8          ; device handle
                CMP     0, @R8
                RBRA    _HM_SDMOUNTED1, !Z

_HM_SDUNMOUNTED MOVE    1, R9                   ; partition #1 hardcoded
                SYSCALL(f32_mnt_sd, 1)
                CMP     0, R9                   ; R9=error code; 0=OK
                RBRA    _HM_SDMOUNTED2, Z

                ; Mounting did not work - offer retry
                RSUB    SCR$CLRINNER, 1
                MOVE    ERR_MOUNT, R8
                RSUB    SCR$PRINTSTR, 1
                MOVE    R9, R8
                MOVE    SCRATCH_HEX, R9
                RSUB    WORD2HEXSTR, 1
                MOVE    R9, R8
                RSUB    SCR$PRINTSTR, 1
                MOVE    ERR_MOUNT_RET, R8
                RSUB    SCR$PRINTSTR, 1
                RSUB    WAIT333MS, 1
_HM_KEYLOOP     MOVE    M2M$KEYBOARD, R8
                AND     M2M$KEY_RETURN, @R8
                RBRA    _HM_KEYLOOP, !Z         ; wait for return; low-active
                MOVE    HANDLE_DEV, R8
                MOVE    0, @R8 
                RBRA    _HM_RETRY_MOUNT, 1

                ; SD card already mounted, but is it still the same card slot?
_HM_SDMOUNTED1  MOVE    SD_ACTIVE, R0
                MOVE    M2M$CSR, R1             ; extract currently active SD
                MOVE    @R1, R1
                AND     M2M$CSR_SD_ACTIVE, R1
                CMP     @R0, R1                 ; did the card change?
                RBRA    _HM_SDMOUNTED2, Z       ; no, continue with browser
                RBRA    _HM_SDCHANGED, 1        ; yes, re-init and re-mount

                ; SD card freshly mounted or already mounted and still
                ; the same card slot:
                ;
                ; Step #3: Show the file browser & let user select disk image
                ;
                ; Run file- and directory browser. Returns:
                ;   R8: pointer to filename string
                ;   R9: status- and error code (see selectfile.asm)
                ;
                ; The status of the device handle HANDLE_DEV will be at the
                ; subdirectory that has been selected so that a subsequent
                ; file open can be directly done.
_HM_SDMOUNTED2  RSUB    SELECT_FILE, 1

                ; No error and no special status
                CMP     0, R9
                RBRA    _HM_SDMOUNTED3, Z

                ; Handle SD card change during file-browsing
                CMP     1, R9                   ; SD card changed?
                RBRA    _HM_SDMOUNTED2A, !Z     ; no

_HM_SDCHANGED   MOVE    LOG_STR_SD, R8
                SYSCALL(puts, 1)
                MOVE    HANDLE_DEV, R8          ; reset device handle
                MOVE    0, @R8
                RSUB    FB_RE_INIT, 1           ; reset file browser

                MOVE    SD_ACTIVE, R0
                MOVE    M2M$CSR, R1             ; extract currently active SD
                MOVE    @R1, R1
                AND     M2M$CSR_SD_ACTIVE, R1
                MOVE    R1, @R0                 ; remember new SD card

                RBRA    _HM_SDUNMOUNTED, 1      ; re-mount, re-browse files

                ; Cancelled via Run/Stop
_HM_SDMOUNTED2A CMP     2, R9                   ; Run/Stop?
                RBRA    _HM_SDMOUNTED2C, !Z     ; no            
                RSUB    SCR$OSM_OFF, 1          ; hide the big window

                MOVE    R7, R8                  ; R7: virtual drive number
                RSUB    VD_MENGRP, 1            ; get index of menu item
                RBRA    _HM_SDMOUNTED2B, C

                MOVE    ERR_FATAL_INST, R8
                MOVE    ERR_FATAL_INST3, R9
                RBRA    FATAL, 1 

_HM_SDMOUNTED2B MOVE    R9, R10                 ; menu index

                MOVE    R7, R8
                RSUB    VD_MOUNTED, 1           ; carry contains mount status
                MOVE    SR, R9
                SHR     2, R9
                AND     1, R9                   ; R9 contains mount status

                MOVE    R10, R8                 ; menu index
                RSUB    _HM_SETMENU, 1          ; see comment at _HM_MOUNTED
                RBRA    _HM_SDMOUNTED7, 1       ; return to OSM

                ; Unknown error / fatal
_HM_SDMOUNTED2C MOVE    ERR_BROWSE_UNKN, R8     ; and R9 contains error code
                RBRA    FATAL, 1                

                ; Step #4: Copy the disk image into the mount buffer
_HM_SDMOUNTED3  MOVE    R8, R0                  ; R8: selected file name
                MOVE    LOG_STR_FILE, R8        ; log to UART
                SYSCALL(puts, 1)
                MOVE    R0, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                ; remember the file name for displaying it in the OSM
                ; the convention for the position in the @OPTM_HEAP is:
                ; virtual drive number times @SCR$OSM_O_DX
                MOVE    R8, R2                  ; R2: file name
                MOVE    OPTM_HEAP, R0
                MOVE    @R0, R0
                RBRA    _HM_SDMOUNTED5, Z       ; OPTM_HEAP not ready, yet
                MOVE    R7, R8
                MOVE    SCR$OSM_O_DX, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)
                ADD     R10, R0                 ; R0: string ptr for file name
                MOVE    R9, R1                  ; R1: maximum string length
                SUB     2, R1                   ; minus 2 because of frame

                ; if the length of the name is <= the maximum size then just
                ; copy as is; otherwise copy maximum size + 1 so that the
                ;  ellipsis is triggered (see _OPTM_CBS_REPL in options.asm)
                MOVE    R2, R8
                SYSCALL(strlen, 1)
                CMP     R9, R1                  ; strlen(name) > maximum?
                RBRA    _HM_SDMOUNTED4, N       ; yes
                MOVE    R2, R8
                MOVE    R0, R9
                SYSCALL(strcpy, 1)
                RBRA    _HM_SDMOUNTED5, 1

                ; strlen(name) > maximum: copy maximum + 1 to trigger ellipsis
_HM_SDMOUNTED4  MOVE    R2, R8
                MOVE    R0, R9
                MOVE    R1, R10
                ADD     1, R10
                SYSCALL(memcpy, 1)
                ADD     R10, R9                 ; add zero terminator
                MOVE    0, @R9

                ; set "%s is replaced" flag for filename string to zero                
_HM_SDMOUNTED5  MOVE    SCR$OSM_O_DX, R8        ; set "%s is replaced" flag
                MOVE    @R8, R8
                SUB     1, R8
                ADD     R0, R8
                MOVE    0, @R8

                ; load the disk image to the mount buffer
                MOVE    R7, R8                  ; R8: drive ID to be mounted
                MOVE    R2, R9                  ; R9: file name of disk image                
                RSUB    LOAD_IMAGE, 1           ; copy disk img to mount buf.
                CMP     0, R8                   ; everything OK?
                RBRA    _HM_SDMOUNTED6, Z       ; yes

                ; loading the disk image did not work
                ; none of the errors that LOAD_IMAGE returns is fatal, so we
                ; will show an error message to the user and then we will
                ; let him chose another file
                RSUB    SCR$CLRINNER, 1         ; print error message
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    WRN_ERROR_CODE, R8
                RSUB    SCR$PRINTSTR, 1
                MOVE    R0, R8
                MOVE    SCRATCH_HEX, R9
                RSUB    WORD2HEXSTR, 1
                MOVE    R9, R8
                RSUB    SCR$PRINTSTR, 1
                MOVE    R1, R8
                RSUB    SCR$PRINTSTR, 1
_HM_SDMOUNTED5A RSUB    HANDLE_IO, 1            ; wait for Space to be pressed
                RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1
                CMP     M2M$KEY_SPACE, R8
                RBRA    _HM_SDMOUNTED5A, !Z
                RSUB    SCR$CLRINNER, 1         ; next try
                RBRA    _HM_SDMOUNTED2, 1

_HM_SDMOUNTED6  MOVE    R9, R6                  ; R6: disk image type
                RSUB    SCR$OSM_OFF, 1          ; hide the big window

                ; Step #5: Notify MiSTer using the "SD" protocol
                MOVE    R7, R8                  ; R8: drive number
                MOVE    HANDLE_FILE, R9
                ADD     FAT32$FDH_SIZE_LO, R9
                MOVE    @R9, R9                 ; R9: file size: low word
                MOVE    HANDLE_FILE, R10
                ADD     FAT32$FDH_SIZE_HI, R10
                MOVE    @R10, R10               ; R10: file size: high word
                MOVE    1, R11                  ; R11=1=read only @TODO
                MOVE    R6, R12                 ; R12: disk image type
                RSUB    VD_STROBE_IM, 1         ; notify MiSTer

                MOVE    LOG_STR_MOUNT, R8
                SYSCALL(puts, 1)
                MOVE    R7, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; 6. Redraw and show the OSM
_HM_SDMOUNTED7  RSUB    OPTM_SHOW, 1            
                RSUB    SCR$OSM_O_ON, 1
                RBRA    _HM_RET, 1

                ; Virtual drive (number in R8) is already mounted
_HM_MOUNTED     CMP     OPTM_KEY_SELALT, R6     ; unmount the whole drive?
                RBRA    _HM_MOUNTED_S, !Z       ; no

                ; Unmount the whole drive by stobing the image mount signal
                ; while setting the image size to zero
                MOVE    R7, R8                  ; virtual drive number
                XOR     R9, R9                  ; low word of image size
                XOR     R10, R10                ; high word of image size
                XOR     R11, R11                ; read-only
                XOR     R12, R12
                RSUB    VD_STROBE_IM, 1
                RBRA    _HM_SDMOUNTED7, 1       ; redraw menu and exit

                ; Make sure the current drive stays selected in M2M$CFM_DATA.
                ; The standard semantics of menu.asm is that single-select
                ; menu items are toggle-items, so a second drive mount is
                ; toggling the single-select item to OFF. We are re-setting
                ; the OPTM_IR_STDSEL data structure to make sure that
                ; M2M$CFM_DATA is correctly treated inside OPTM_CB_SEL in
                ; options.asm. It is actually options.asm that adds drive
                ; mounting semantics to the rather generic menu.asm.
                ; This also makes sure that re-opening the menu shows the
                ; visual representation of "successfuly mounted".
                ;
                ; But menu.asm already has deleted the visual representation
                ; at this point, so we need to hack the visual representation
                ; of the currently open menu and actually print it.
_HM_MOUNTED_S   MOVE    R7, R8                  ; R7: virtual drive number
                RSUB    VD_MENGRP, 1            ; get index of menu item
                RBRA    _HM_MOUNTED_1, C

                MOVE    ERR_FATAL_INST, R8
                MOVE    ERR_FATAL_INST2, R9
                RBRA    FATAL, 1 

_HM_MOUNTED_1   MOVE    R9, R8                  ; menu index
                MOVE    1, R9                   ; set as "mounted"
                RSUB    _HM_SETMENU, 1
                RBRA    _HM_START_MOUNT, 1      ; show browser and mount

_HM_RET         RSUB    VD_MNT_ST_SET, 1        ; remember mount status
                SYSCALL(leave, 1)
                RET

; helper function that executes the menu and data structure modification
; described above in the comment near _HM_MOUNTED
; Input:
;   R8: Index of menu item to change
;   R9: 0=unset / 1=set
_HM_SETMENU     SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: menu index
                MOVE    R9, R1                  ; R1: mode

                MOVE    OPTM_DATA, R8
                MOVE    @R8, R8
                ADD     OPTM_IR_STDSEL, R8
                MOVE    @R8, R8
                ADD     R0, R8                  ; R0 contains menu index
                MOVE    R0, R11                 ; save menu index
                MOVE    R1, @R8                 ; re-set single-select flag

                MOVE    SPACE, R8               ; R8 = space (unset)
                CMP     0, R1
                RBRA    _HM_SETMENU_1, Z

                MOVE    OPTM_DATA, R8           ; R8: single-select char
                MOVE    @R8, R8
                MOVE    OPTM_IR_SEL, R8
                MOVE    @R8, R8
                ADD     2, R8

_HM_SETMENU_1   MOVE    OPTM_X, R9              ; R9: x-pos
                MOVE    @R9, R9
                ADD     1, R9                   ; x-pos on screen b/c frame
                MOVE    OPTM_Y, R10             ; R10: y-pos
                MOVE    @R10, R10
                ADD     R11, R10                ; add menu index
                ADD     1, R10                  ; y-pos on screen b/c frame
                RSUB    SCR$PRINTSTRXY, 1

                SYSCALL(leave, 1)
                RET

; Load disk image to virtual drive buffer (VDRIVES_BUFS)
;
; Input:
;   R8: drive number
;   R9: file name of disk image
;
; And HANDLE_DEV needs to be fully initialized and the status needs to be
; such, that the directory where R9 resides is active
;
; Output:
;   R8: 0=OK, error code otherwise
;   R9: image type if R8=0, otherwise 0 or optional ptr to  error msg string
LOAD_IMAGE      SYSCALL(enter, 1)

                MOVE    VDRIVES_BUFS, R0
                ADD     R8, R0
                MOVE    @R0, R0                 ; R0: device number of buffer
                MOVE    R0, R8

                MOVE    R8, R1                  ; R1: drive number
                MOVE    R9, R2                  ; R2: file name

                ; Open file
                MOVE    HANDLE_DEV, R8
                MOVE    HANDLE_FILE, R9
                MOVE    R2, R10
                XOR     R11, R11
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; R10=error code; 0=OK
                RBRA    _LI_FOPEN_OK, Z
                MOVE    ERR_FATAL_FNF, R8
                MOVE    R10, R9
                RBRA    FATAL, 1

                ; Callback function that can handle headers, sanity check
                ; the disk image, determine the type of the disk image, etc.
_LI_FOPEN_OK    MOVE    HANDLE_FILE, R8
                RSUB    PREP_LOAD_IMAGE, 1
                MOVE    R8, R6                  ; R6: error code=0 (means OK)
                MOVE    R9, R7                  ; R7: img type or error msg
                CMP     0, R6                   ; everything OK?
                RBRA    _LI_FREAD_RET, !Z       ; no

                ; load disk image into buffer RAM
                XOR     R1, R1                  ; R1=window: start from 0
                XOR     R2, R2                  ; R2=start address in window
                ADD     M2M$RAMROM_DATA, R2
                MOVE    M2M$RAMROM_DATA, R3     ; R3=end of 4k page reached
                ADD     0x1000, R3

                MOVE    M2M$RAMROM_DEV, R8
                MOVE    R0, @R8                 ; mount buffer device handle
_LI_FREAD_NXTWN MOVE    M2M$RAMROM_4KWIN, R8    ; set 4k window
                MOVE    R1, @R8

_LI_FREAD_NXTB  MOVE    HANDLE_FILE, R8         ; read next byte to R9
                SYSCALL(f32_fread, 1)
                CMP     FAT32$EOF, R10
                RBRA    _LI_FREAD_EOF, Z
                CMP     0, R10
                RBRA    _LI_FREAD_CONT, Z
                MOVE    ERR_FATAL_LOAD, R8
                MOVE    R10, R9
                RBRA    FATAL, 1

_LI_FREAD_CONT  MOVE    R9, @R2++               ; write byte to mount buffer

                CMP     R3, R2                  ; end of 4k page reached?
                RBRA    _LI_FREAD_NXTB, !Z      ; no: read next byte
                ADD     1, R1                   ; inc. window counter
                MOVE    M2M$RAMROM_DATA, R2     ; start at beginning of window
                RBRA    _LI_FREAD_NXTWN, 1      ; set next window

_LI_FREAD_EOF   MOVE    LOG_STR_LOADOK, R8
                SYSCALL(puts, 1)

_LI_FREAD_RET   MOVE    R6, @--SP               ; lift return codes over ...
                MOVE    R7, @--SP               ; the "leave hump"
                SYSCALL(leave, 1)
                MOVE    @SP++, R9               ; R9: image type
                MOVE    @SP++, R8               ; R8: status/error code
                RET

; ----------------------------------------------------------------------------
; IO Handler:
; Meant to be polled in the main loop and while waiting for keys in the OSM
; ----------------------------------------------------------------------------

HANDLE_IO       SYSCALL(enter, 1)

                ; Loop through all VDRIVES and check for read requests
                XOR     R0, R0                  ; R0: number of virtual drive
                MOVE    VDRIVES_NUM, R1
                MOVE    @R1, R1                 ; R1: amount of vdrives

                ; read request pending?
_HANDLE_IO_1    MOVE    R0, R8
                MOVE    VD_RD, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8                   ; read request?
                RBRA    _HANDLE_IO_NXT, !Z      ; no: next drive, if any

                ; handle read request
                MOVE    R0, R8
                RSUB    HANDLE_DRV_RD, 1

                ; next drive, if applicable
_HANDLE_IO_NXT  ADD     1, R0                   ; next drive
                CMP     R0, R1                  ; done?
                RBRA    _HANDLE_IO_1, !Z        ; no, continue

                SYSCALL(leave, 1)
                RET

; Handle read request from drive number in R8:
;
; Transfer the data requested by the core from the linear disk image buffer
; to the internal buffer inside the core
HANDLE_DRV_RD   SYSCALL(enter, 1)

                MOVE    R8, R11                 ; R11: virtual drive ID

                MOVE    VD_SIZEB, R9            ; virtual drive ID still in R8
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R0                  ; R0=# bytes to be transmitted
                MOVE    R11, R8
                MOVE    VD_4K_WIN, R9
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R1                  ; R1=start 4k win of transmis.
                MOVE    R11, R8
                MOVE    VD_4K_OFFS, R9
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R2                  ; R2=start offs in 4k win

                ; transmit data to internal buffer of drive
                MOVE    R11, R8
                MOVE    VD_ACK, R9              ; ackknowledge sd_rd_i
                MOVE    1, R10
                RSUB    VD_DRV_WRITE, 1

                MOVE    M2M$RAMROM_DEV, R3      ; R3=device selector
                MOVE    M2M$RAMROM_4KWIN, R4    ; R4=window selector
                MOVE    M2M$RAMROM_DATA, R5     ; R5=data window
                ADD     R2, R5                  ; start offset within window
                XOR     R6, R6                  ; R6=# transmitted bytes
                MOVE    M2M$RAMROM_DATA, R7     ; R7=end of window marker
                ADD     0x1000, R7

_HDR_SEND_LOOP  CMP     R6, R0                  ; transmission done?
                RBRA    _HDR_SEND_DONE, Z       ; yes

                MOVE    VDRIVES_BUFS, R9        ; array of buf RAM device IDs
                ADD     R11, R9                 ; select right ID for vdrive
                MOVE    @R9, @R3                ; select device
                MOVE    R1, @R4                 ; select window in RAM
                MOVE    @R5++, R12              ; R12=next byte from disk img

                MOVE    VD_B_ADDR, R8           ; write buffer: address
                MOVE    R6, R9
                RSUB    VD_CAD_WRITE, 1

                MOVE    VD_B_DOUT, R8           ; write buffer: data out
                MOVE    R12, R9
                RSUB    VD_CAD_WRITE, 1

                MOVE    VD_B_WREN, R8       ; strobe write enable
                MOVE    1, R9
                RSUB    VD_CAD_WRITE, 1
                XOR     0, R9
                RSUB    VD_CAD_WRITE, 1

                ADD     1, R6                   ; next byte

                CMP     R5, R7                  ; window boundary reached?
                RBRA    _HDR_SEND_LOOP, !Z      ; no
                ADD     1, R1                   ; next window
                MOVE    M2M$RAMROM_DATA, R5     ; byte zero in next window
                RBRA    _HDR_SEND_LOOP, 1

                ; unassert ACK
_HDR_SEND_DONE  MOVE    R11, R8                 ; virtual drive ID
                MOVE    VD_ACK, R9              ; unassert ACK
                MOVE    0, R10
                RSUB    VD_DRV_WRITE, 1

                SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Debug mode:
; Hold "Run/Stop" + "Cursor Up" and then while holding these, press "Help"
; ----------------------------------------------------------------------------

                ; Debug mode: Exits the main loop and starts the QNICE
                ; Monitor which can be used to debug via UART and a
                ; terminal program. You can return to the Shell by using
                ; the Monitor C/R command while entering an address shown
                ; in the terminal.
CHECK_DEBUG     INCRB
                MOVE    M2M$KEY_UP, R0
                OR      M2M$KEY_RUNSTOP, R0
                OR      M2M$KEY_HELP, R0
                MOVE    M2M$KEYBOARD, R1        ; read keyboard status
                MOVE    @R1, R2
                NOT     R2, R2                  ; convert low active to hi
                AND     R0, R2
                CMP     R0, R2                  ; key combi pressed?
                DECRB
                RBRA    START_MONITOR, Z        ; yes: enter debug mode
                RET                             ; no: return to main loop
                
                ; print info message via UART that shows how to return back
                ; to the shell (either main loop or restart)
                ; in RELEASE mode, you can also return to where you left off
                ; else you can only restart the Shell
START_MONITOR   MOVE    DBG_START1, R8
                SYSCALL(puts, 1)

#ifdef RELEASE
                MOVE    _START_MON_GO, R8 
                SYSCALL(puthex, 1)
                MOVE    DBG_START2, R8
                SYSCALL(puts, 1)
                MOVE    START_SHELL, R8
                SYSCALL(puthex, 1)
                MOVE    DBG_START3, R8
                SYSCALL(puts, 1)

                ; enter the QNICE Monitor without allowing the QNICE Monitor
                ; to tamper the stack or to reset the status register
                INCRB
                RBRA    QMON$SOFTMON, 1
_START_MON_GO   DECRB
                RET
#else
                MOVE    START_SHELL, R8
                SYSCALL(puthex, 1)
                MOVE    DBG_START2, R8
                SYSCALL(puts, 1)

                SYSCALL(exit, 1)                ; small/irrelevant stack leak
#endif

; ----------------------------------------------------------------------------
; Fatal error:
;
; Output message to the screen and to the serial terminal and then quit to the
; QNICE Monitor. This is invisible to end users but might be helpful for
; debugging purposes, if you are able to connect a JTAG interface.
;
; R8: Pointer to error message from strings.asm
; R9: if not zero: contains an error code for additional debugging info
; ----------------------------------------------------------------------------

FATAL           MOVE    R8, R0

                ; make sure we have a large window where we can print
                ; the error message
                RSUB    SCR$OSM_OFF, 1          ; hide opt. menu just in case
                RSUB    SCR$OSM_M_ON, 1
                RSUB    SCR$CLR, 1
                MOVE    SCR$ILX, R8             ; keep 1 space left margin
                MOVE    1, @R8

                ; output error message
                MOVE    ERR_FATAL, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)
                MOVE    R0, R8                  ; actual error message
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)

                CMP     0, R9
                RBRA    _FATAL_END, Z
                MOVE    ERR_CODE, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)
                MOVE    R9, R8
                MOVE    SCRATCH_HEX, R9
                RSUB    WORD2HEXSTR, 1
                MOVE    R9, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)
                MOVE    NEWLINE, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(crlf, 1)

_FATAL_END      MOVE    ERR_FATAL_STOP, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)

                SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Screen handling
; ----------------------------------------------------------------------------

FRAME_FULLSCR   SYSCALL(enter, 1)
                RSUB    SCR$CLR, 1              ; clear screen                                
                MOVE    SCR$OSM_M_X, R8         ; retrieve frame coordinates
                MOVE    @R8, R8
                MOVE    SCR$OSM_M_Y, R9
                MOVE    @R9, R9
                MOVE    SCR$OSM_M_DX, R10
                MOVE    @R10, R10
                MOVE    SCR$OSM_M_DY, R11
                MOVE    @R11, R11
                RSUB    SCR$PRINTFRAME, 1       ; draw frame
                SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Strings and Libraries
; ----------------------------------------------------------------------------

; "Outsourced" code from shell.asm, i.e. this code directly accesses the
; shell.asm environment incl. all variables
#include "filters.asm"
#include "gencfg.asm"
#include "options.asm"
#include "selectfile.asm"
#include "strings.asm"
#include "vdrives.asm"
#include "whs.asm"

; framework libraries
#include "dirbrowse.asm"
#include "keyboard.asm"
#include "menu.asm"
#include "screen.asm"
#include "tools.asm"
