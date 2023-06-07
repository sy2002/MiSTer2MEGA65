; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Shell: User interface and core automation
;
; The Shell provides a uniform user interface and core automation
; for all MiSTer2MEGA65 projects.
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Main Program
;
; START_SHELL is called from m2m-rom.asm as the main entry point to the Shell.
; The call is performed doing an RBRA not an RSUB, so the main program is
; not supposed to return to the caller.
; ----------------------------------------------------------------------------
     
                ; log to serial terminal (not visible to end user)
START_SHELL     MOVE    LOG_M2M, R8             ; M2M start message
                SYSCALL(puts, 1)
                RSUB    LOG_CORENAME, 1         ; core name from config.vhd

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
                ; waiting at least two seconds before allowing to mount it
                ; IO$CYC_MID updates with 50 MHz / 65535 = 763 Hz
                ; 2 seconds are 1526 updates of IO$CYC_MID (1526 = 0x05F6)
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

                ; FAT32 subsystem: initialize SD card device handles for the
                ; vdrive and CRT/ROM loader (HANDLE_DEV) and for the config
                ; file (CONFIG_DEVH) and initialize the config file and the
                ; ROM auto-load filehandle.
                ; It is important that these handles are initialized to zero
                ; as parts of the code use this as a flag.
                MOVE    HANDLE_DEV, R8
                MOVE    0, @R8
                MOVE    CONFIG_DEVH, R8
                MOVE    0, @R8
                MOVE    CONFIG_FILE, R8
                MOVE    0, @R8
                MOVE    CRTROM_AUT_FILE, R8
                MOVE    0, @R8

                ; initialize file browser persistence variables
                MOVE    M2M$CSR, R8             ; get active SD card
                MOVE    @R8, R8
                AND     M2M$CSR_SD_ACTIVE, R8
                MOVE    SD_ACTIVE, R9
                MOVE    R8, @R9
                MOVE    SD_CHANGED, R9
                MOVE    0, @R9
                MOVE    INITIAL_SD, R9
                MOVE    R8, @R9
                MOVE    FB_LASTCALLER, R8
                MOVE    0xFFFF, @R8
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

                ; default = no context
                MOVE    SF_CONTEXT, R8
                MOVE    0, @R8
                MOVE    SF_CONTEXT_DATA, R8
                MOVE    0, @R8

                ; Initialize libraries: The order in which these libraries are
                ; initialized matters and the initialization needs to happen
                ; before RP_SYSTEM_START is called.
                RSUB    SCR$INIT, 1             ; retrieve visual constants
                RSUB    FRAME_FULLSCR, 1        ; draw fullscreen frame
                RSUB    VD_INIT, 1              ; virtual drive system
                RSUB    CRTROM_INIT, 1          ; CRT/ROM loader system
                RSUB    KEYB$INIT, 1            ; keyboard library
                RSUB    HELP_MENU_INIT, 1       ; menu library
                RSUB    CRTROM_AUTOLOAD, 1      ; auto-load ROMs

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
                RBRA    PREP_CONNECT, !C
                RSUB    SHOW_WELCOME, 1

                ; At this point, the core is ready to run, settings are loaded
                ; (if the core uses settings) and the core is still held in
                ; reset (if RESET_KEEP is on). So at this point in time, the
                ; user of the framework can execute tasks that change the
                ; run-state of the core.
PREP_CONNECT    RSUB    PREP_START, 1
                CMP     0, R8
                RBRA    START_CONNECT, Z        ; R8=0: ready to start core
                RBRA    FATAL, 1                ; else fatal and R8/R9 are set
                                                ; by PREP_START

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

                ; As soon as the core is un-reset and up and running:
                ; Reset timer variables for the log timer
                RSUB    LOG_PREP, 1

                ; ------------------------------------------------------------
                ; Main loop:
                ;
                ; The core is running and QNICE is waiting for triggers to
                ; react. Such triggers could be for example the "Help" button
                ; which is meant to open the options menu but also triggers
                ; from the core such as data requests from the IO subsystem
                ; (for example from virtual disk drives).
                ;
                ; The latter one could also be done via interrupts, but we
                ; will try to keep it simple and only increase complexity by
                ; using interrupts if neccessary.
                ; ------------------------------------------------------------

MAIN_LOOP       RSUB    HANDLE_IO, 1            ; IO handling (e.g. vdrives)

                RSUB    KEYB$SCAN, 1            ; scan for single key presses
                RSUB    KEYB$GETKEY, 1

                RSUB    CHECK_DEBUG, 1          ; (Run/Stop+Cursor Up) + Help
                RSUB    HELP_MENU, 1            ; check/manage help menu
                RSUB    LOG_COREINFO, 1         ; once: log core info

                RBRA    MAIN_LOOP, 1

                ; The main loop is an infinite loop therefore we do not need
                ; to restore the stack by adding back BROWSE_DEPTH to the
                ; stack pointer.

; ----------------------------------------------------------------------------
; SD card, virtual drive mount handling & CRT/ROM loading
; ----------------------------------------------------------------------------

; arrays of pointers to all the file handles for the virtual drives
; (needs to be in line with VDRIVES_MAX) and for the CRT/ROM loading mechanism
; (needs to be in line with CRTROM_MAN_MAX, both in shell_vars.asm)
#include "../../CORE/m2m-rom/shell_fh_ptrs.asm"

; Handle mounting of virtual drives and manual loading of CRTs/ROMs
;
; Input:
;   R8 contains the drive or CRT/ROM number
;   R9 is for virtual drives only:
;   R9=OPTM_KEY_SELECT:
;      Just replace the disk image, if it has been mounted
;      before without unmounting the drive (aka without
;      resetting the drive/"switching the drive on/off")
;   R9=OPTM_KEY_SELALT:
;      Unmount the drive (aka "switch the drive off")
;  R10=Mode selector:
;      0: Virtual drives
;      1: Manually loadable CRTs/ROMs
HANDLE_MOUNTING SYSCALL(enter, 1)

                MOVE    R8, R7                  ; R7: drive or CRT/ROM number
                MOVE    R9, R6                  ; R6: key to trigger mounting
                MOVE    R10, R5                 ; R5: mount mode

                CMP     1, R5                   ; CRT/ROM mode?
                RBRA    _HM_START_MOUNT, Z      ; yes

                ; we treat already mounted drives differently
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
_HM_SDMOUNTED1  MOVE    SD_CHANGED, R0
                CMP     1, @R0                  ; did the card change?
                RBRA    _HM_SDCHANGED, Z        ; yes, re-init and re-mount

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
                ;
                ; The idea of FB_LASTCALLER is all about ensuring that
                ; when the user switches between potentially different file
                ; types (for example disk images and different types of
                ; manually loadbale CRTs/ROMs), the file browser is being 
                ; reset so that the directory can be reloaded with the new
                ; file filters.
_HM_SDMOUNTED2  XOR     R8, R8                  ; remember last caller by..
                MOVE    R7, R9                  ; combining the ID of the..
                AND     0x00FF, R9              ; vdrive or CRT/ROM with the..
                OR      R9, R8                  ; mode
                SWAP    R8, R8
                MOVE    R5, R9
                AND     0x00FF, R9
                OR      R9, R8
                MOVE    R8, R9

                MOVE    FB_LASTCALLER, R8       ; first call?
                CMP     0xFFFF, @R8
                RBRA    _HM_SDMOUNTEDXA, !Z     ; no
                MOVE    R9, @R8                 ; yes: remember last caller..
                RBRA    _HM_SDMOUNTEDXS, 1      ; ..begin browsing

_HM_SDMOUNTEDXA CMP     R9, @R8                 ; same caller als last time?
                RBRA    _HM_SDMOUNTEDXS, Z      ; yes; browse where we were
                MOVE    R9, @R8                 ; no: remember last caller..
                RSUB    FB_RE_INIT, 1           ; ..and reset file browser

_HM_SDMOUNTEDXS MOVE    SF_CONTEXT, R8
                CMP     0, R5                   ; virtual drive mode?
                RBRA    _HM_SDMOUNTEDX1, !Z
                MOVE    CTX_MOUNT_DISKIMG, @R8
                RBRA    _HM_SDMOUNTEDX2, 1
_HM_SDMOUNTEDX1 MOVE    CTX_LOAD_ROM, @R8 
_HM_SDMOUNTEDX2 RSUB    SELECT_FILE, 1

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
                MOVE    0, @R0                  ; reset SD_CHANGED
                RBRA    _HM_SDUNMOUNTED, 1      ; re-mount, re-browse files

                ; Cancelled via Run/Stop
_HM_SDMOUNTED2A CMP     2, R9                   ; Run/Stop?
                RBRA    _HM_SDMOUNTED2C, !Z     ; no            
_HM_SDMOUNTED2E RSUB    SCR$OSM_OFF, 1          ; hide the big window
                MOVE    R7, R8                  ; vdrive or CRT/ROM number
                CMP     1, R5                   ; CRT/ROM mode?
                RBRA    _HM_SDMOUNTED2F, Z      ; yes

                RSUB    VD_MENGRP, 1            ; get index of vdrive in R9
                RBRA    _HM_SDMOUNTED2B, C      ; success: continue
                RBRA    _HM_SDMOUNTED2G, 1      ; failure: fatal

_HM_SDMOUNTED2F RSUB    CRTROM_M_GI, 1          ; get index of CRT/ROM in R9
                RBRA    _HM_SDMOUNTED2B, C      ; success: continue

_HM_SDMOUNTED2G MOVE    ERR_FATAL_INST, R8
                MOVE    ERR_FATAL_INST3, R9
                RBRA    FATAL, 1 

_HM_SDMOUNTED2B MOVE    R9, R10                 ; menu index

                CMP     1, R5                   ; CRT/ROM mode?
                RBRA    _HM_SDMOUNTED2V, Z      ; yes

                ; VDrive mode: check if drive is mounted: R9=1 means yes
                MOVE    R7, R8
                RSUB    VD_MOUNTED, 1           ; carry contains mount status
                MOVE    SR, R9
                SHR     2, R9
                AND     1, R9                   ; R9 contains mount status
                RBRA    _HM_SDMOUNTED2W, 1

                ; CRT/ROM mode: check if ROM is loaded
_HM_SDMOUNTED2V MOVE    CRTROM_MAN_LDF, R9
                ADD     R7, R9                  ; R7: CRT/ROM number
                MOVE    @R9, R9

                ; set or unset VDRIVE or CRT/ROM menu item
_HM_SDMOUNTED2W MOVE    R10, R8                 ; menu index
                RSUB    OPTM_SET, 1             ; see comment at _HM_MOUNTED
                RBRA    _HM_SDMOUNTED7, 1       ; return to OSM

                ; Everything filtered, see CMSG_BROWSENOTHING in sysdef.asm
_HM_SDMOUNTED2C CMP     3, R9                   ; CMSG_BROWSENOTHING situation
                RBRA    _HM_SDMOUNTED2D, !Z     ; no
                RSUB    FB_RE_INIT, 1           ; reset file browser
                MOVE    M2M$CSR, R8             ; set SD card..
                AND     M2M$CSR_UN_SD_MODE, @R8 ; ..back to auto-detect
                RBRA    _HM_SDMOUNTED2E, 1      ; continue like Run/Stop

                ; Unknown error / fatal
_HM_SDMOUNTED2D MOVE    ERR_BROWSE_UNKN, R8     ; and R9 contains error code
                RBRA    FATAL, 1                

                ; Step #4: Copy the disk image into the mount buffer
_HM_SDMOUNTED3  MOVE    R8, R0                  ; R8: selected file name
                MOVE    LOG_STR_FILE, R8        ; log to UART
                SYSCALL(puts, 1)
                MOVE    R0, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                ; remember the file name for displaying it in the OSM in R2
                ;
                ; the convention for the position in the @OPTM_HEAP is:
                ; a) for vdrives: vdrive number times @SCR$OSM_O_DX
                ; b) for CRTs/ROMs: (#vdrives+#submenus+crt/rom id)
                ;    times @SCR$OSM_O_DX
                MOVE    R8, R2                  ; R2: file name
                MOVE    OPTM_HEAP, R0
                MOVE    @R0, R0
                RBRA    _HM_SDMOUNTED3A, !Z     ; OPTM_HEAP is ready
                MOVE    ERR_FATAL_INST, R8
                MOVE    ERR_FATAL_INST7, R9
                RBRA    FATAL, 1

_HM_SDMOUNTED3A XOR     R8, R8
                CMP     1, R5                   ; case (b)?
                RBRA    _HM_SDMOUNTED3B, !Z     ; no, case (a)
                MOVE    VDRIVES_NUM, R9
                ADD     @R9, R8
                MOVE    OPTM_SCOUNT, R9
                ADD     @R9, R8

_HM_SDMOUNTED3B ADD     R7, R8
                MOVE    SCR$OSM_O_DX, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)
                ADD     R10, R0                 ; R0: string ptr for file name
                MOVE    R9, R1                  ; R1: maximum string length
                SUB     2, R1                   ; minus 2 because of frame

                ; if the length of the name is <= the maximum size then just
                ; copy as is; otherwise copy maximum size + 1 so that the
                ; ellipsis is triggered (see _OPTM_CBS_REPL in options.asm)
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
                MOVE    SP, R6                  ; remember stack pointer
                MOVE    R7, R8                  ; R8: drive ID to be mounted
                MOVE    R2, R9                  ; R9: file name of disk image
                MOVE    R5, R10                 ; R10: mode: vdrive or CRT/ROM
                RSUB    LOAD_IMAGE, 1           ; copy disk img to mount buf.
                CMP     0, R8                   ; everything OK?
                RBRA    _HM_SDMOUNTED6A, Z      ; yes

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
                CMP     0, R1
                RBRA    _HM_SDMOUNTED5A, Z
                MOVE    NEWLINE, R8
                RSUB    SCR$PRINTSTR, 1
                
                ; retrieve error string from CRT/ROM device and put it
                ; temporarily on the stack so that we can print the
                ; error message on screen
                CMP     1, R5                   ; CRT/ROM: switch device..
                RBRA    _HM_SDMOUNTED5S, !Z     ; ..to make string visible

                MOVE    SCRATCH_HEX, R8         ; save screen device
                RSUB    SAVE_DEVSEL, 1
                MOVE    M2M$RAMROM_DEV, R12     ; switch to CRT/ROM device
                MOVE    CRTROM_MAN_DEV, R11
                ADD     R7, R11
                MOVE    @R11, @R12
                MOVE    M2M$RAMROM_4KWIN, R12
                MOVE    CRTROM_CSR_4KWIN, @R12

                MOVE    R1, R8                  ; R12: string length
                SYSCALL(strlen, 1)
                SUB     R9, SP                  ; reserve space on stack
                SUB     1, SP                   ; incl zero terminator
                MOVE    SP, R9                  ; R9: strcpy target
                MOVE    R1, R8                  ; R8: strcpy source
                SYSCALL(strcpy, 1)
                MOVE    R9, R1

                MOVE    SCRATCH_HEX, R8         ; restore screen device
                RSUB    RESTORE_DEVSEL, 1

_HM_SDMOUNTED5S MOVE    R1, R8                  ; output optional error string
                RSUB    SCR$PRINTSTR, 1
                MOVE    NEWLINE, R8
                RSUB    SCR$PRINTSTR, 1
                MOVE    STR_SPACE, R8
                RSUB    SCR$PRINTSTR, 1
                MOVE    R6, SP                  ; restore SP

_HM_SDMOUNTED5A RSUB    HANDLE_IO, 1            ; wait for Space to be pressed
                RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1
                CMP     M2M$KEY_SPACE, R8
                RBRA    _HM_SDMOUNTED5A, !Z
                RSUB    SCR$CLRINNER, 1         ; next try
                RBRA    _HM_SDMOUNTED2, 1

_HM_SDMOUNTED6A MOVE    R9, R6                  ; R6: disk image type
                RSUB    SCR$OSM_OFF, 1          ; hide the big window

                ; Step #5: Notify MiSTer using the "SD" protocol, if we
                ; are in virtual drive mode, otherwise skip
                CMP     0, R5                   ; vdrive mode?
                RBRA    _HM_SDMOUNTED6B, !Z     ; no
                MOVE    R7, R8                  ; yes: R8: drive number
                MOVE    HNDL_VD_FILES, R9
                ADD     R7, R9
                MOVE    @R9, R9
                MOVE    R9, R10
                ADD     FAT32$FDH_SIZE_LO, R9
                MOVE    @R9, R9                 ; R9: file size: low word
                ADD     FAT32$FDH_SIZE_HI, R10
                MOVE    @R10, R10               ; R10: file size: high word
                XOR     R11, R11                ; 0=read/write disk
                MOVE    R6, R12                 ; R12: disk image type
                RSUB    VD_STROBE_IM, 1         ; notify MiSTer

                MOVE    LOG_STR_MOUNT, R8
                SYSCALL(puts, 1)
                MOVE    R7, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                RBRA    _HM_SDMOUNTED7, 1

                ; We successfully loaded a manually loadable CRT/ROM and need
                ; to ensure that the menu items stays selected. This
                ; situation is similar to the one described in _HM_MOUNTED_S.
_HM_SDMOUNTED6B MOVE    R7, R8
                RSUB    CRTROM_M_GI, 1          ; convert rom id to menu idx
                RBRA    _HM_SDMOUNTED6C, C      ; OK: continue
                MOVE    ERR_FATAL_INST, R8      ; Not OK: fatal
                MOVE    ERR_FATAL_INSTA, R9
                RBRA    FATAL, 1
_HM_SDMOUNTED6C MOVE    R9, R8                  ; R8: menu index
                MOVE    1, R9                   ; R9=1: set menu item
                RSUB    OPTM_SET, 1

                ; Some CRT/ROM load actions are unmounting drives, so we need
                ; to we need to check for that and act accordingly
                RSUB    _OPTM_GK_MNT, 1

                ; 6. Redraw and show the OSM
_HM_SDMOUNTED7  RSUB    OPTM_SHOW, 1            
                RSUB    SCR$OSM_O_ON, 1
                RBRA    _HM_RET, 1

                ; Virtual drive (number in R8) is already mounted

                ; Write cache of drive dirty? Prevent any unmount/remount
_HM_MOUNTED     MOVE    R7, R8
                MOVE    VD_CACHE_DIRTY, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8
                RBRA    _HM_MOUNTED_C, !Z       ; cache not dirty: continue

                ; cache dirty: make sure the menu items mounted-marker is not
                ; deleted and then do nothing else and return
                MOVE    R7, R8                  ; R7: virtual drive number
                RSUB    VD_MENGRP, 1            ; get index of menu item
                RBRA    _HM_MOUNTED_F, !C       ; unsuccessful? fatal!
                MOVE    R9, R8                  ; OK! set menu index
                MOVE    1, R9                   ; set as "mounted"
                RSUB    OPTM_SET, 1
                RBRA    _HM_SDMOUNTED7, 1       ; redraw menu and exit

                ; unmount the whole drive?
_HM_MOUNTED_C   CMP     OPTM_KEY_SELALT, R6
                RBRA    _HM_MOUNTED_S, !Z       ; no

                ; Unmount the whole drive by stobing the image mount signal
                ; while setting the image size to zero
                MOVE    R7, R8                  ; virtual drive number
                XOR     R9, R9                  ; low word of image size
                XOR     R10, R10                ; high word of image size
                XOR     R11, R11                ; 0=read/write disk
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

_HM_MOUNTED_F   MOVE    ERR_FATAL_INST, R8
                MOVE    ERR_FATAL_INST2, R9
                RBRA    FATAL, 1 

_HM_MOUNTED_1   MOVE    R9, R8                  ; menu index
                MOVE    1, R9                   ; set as "mounted"
                RSUB    OPTM_SET, 1
                RBRA    _HM_START_MOUNT, 1      ; show browser and mount

_HM_RET         RSUB    VD_MNT_ST_SET, 1        ; remember mount status
                SYSCALL(leave, 1)
                RET

; Load a disk or CRT/ROM image to the device as configured in globals.vhd
;
; Shows a progress bar while doing so, i.e. it is expected that the large
; window is open before LOAD_IMAGE is called.
;
; Input:
;   R8: drive or CRT/ROM number
;   R9: file name of disk image
;  R10: mode selector: 0=virtual drives 1=manually loadable CRTs/ROMs
;
; And HANDLE_DEV needs to be fully initialized and the status needs to be
; such, that the directory where R9 resides is active
;
; Output:
;   R8: 0=OK, error code otherwise
;   R9: image type if R8=0, otherwise 0 or optional ptr to  error msg string
LOAD_IMAGE      SYSCALL(enter, 1)

                MOVE    R8, R1                  ; R1: drive or CRT/ROM number
                MOVE    R8, R12                 ; R12: dito
                MOVE    R9, R2                  ; R2: file name
                MOVE    R10, R4                 ; R4: mode (0=vdrv, 1=crt/rom)

                CMP     0, R4                   ; mode = vdrives?
                RBRA    _LI_CRTROM, !Z          ; no

                ; Case 0: virtual drives
                MOVE    VDRIVES_BUFS, R0
                ADD     R1, R0
                MOVE    @R0, R0                 ; R0: device number            
                MOVE    HNDL_VD_FILES, R9
                RBRA    _LI_OPENFILE, 1

                ; Case 1: CRTs/ROMs
_LI_CRTROM      MOVE    CRTROM_MAN_DEV, R0
                ADD     R1, R0
                MOVE    @R0, R0                 ; R0: device number
                MOVE    R0, R8
                MOVE    CRTROM_CSR_STATUS, R9   ; set CSR to "loading"
                MOVE    CRTROM_CSR_ST_LDNG, R10
                RSUB    CRTROM_CSR_W, 1
                MOVE    HNDL_RM_FILES, R9

                ; Open file
_LI_OPENFILE    MOVE    HANDLE_DEV, R8          ; R8: sd card device handle
                ADD     R1, R9
                MOVE    @R9, R9                 ; R9: file handle
                MOVE    R9, R5                  ; R5: remember file handle
                MOVE    R2, R10
                XOR     R11, R11
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; R10=error code; 0=OK
                RBRA    _LI_FOPEN_OK, Z
                CMP     0, R4
                RBRA    _LI_OPENFATAL, Z
                MOVE    R0, R8
                MOVE    CRTROM_CSR_STATUS, R9
                MOVE    CRTROM_CSR_ST_ERR, R10
                RSUB    CRTROM_CSR_W, 1
_LI_OPENFATAL   MOVE    ERR_FATAL_FNF, R8
                MOVE    R10, R9
                RBRA    FATAL, 1

                ; Callback function that can handle headers, sanity check
                ; the disk image, determine the type of the disk image, etc.
_LI_FOPEN_OK    MOVE    R5, R8
                MOVE    SF_CONTEXT, R9
                MOVE    @R9, R9
                MOVE    SF_CONTEXT_DATA, R10
                MOVE    @R10, R10
                RSUB    PREP_LOAD_IMAGE, 1
                MOVE    R8, R6                  ; R6: error code=0 (means OK)
                MOVE    R9, R7                  ; R7: img type or error msg
                CMP     0, R6                   ; everything OK?
                RBRA    _LI_FREAD_RET, !Z       ; no

                ; For showing a progress bar: Take the remaining size of the
                ; file, which is filesize minus current read position after
                ; PREP_LOAD_IMAGE and divide it by the amount of printable
                ; "progress bar characters" to obtain the target of a counter
                ; that equals one progress step in the progress bar
                MOVE    SCRATCH_HEX, R8
                MOVE    R5, R1
                ADD     FAT32$FDH_ACCESS_LO, R1
                MOVE    @R1, @R8++
                MOVE    R5, R1
                ADD     FAT32$FDH_ACCESS_HI, R1
                MOVE    @R1, @R8++
                MOVE    R5, R1
                ADD     FAT32$FDH_SIZE_LO, R1
                MOVE    @R1, @R8++
                MOVE    R5, R1
                ADD     FAT32$FDH_SIZE_HI, R1
                MOVE    @R1, @R8++
                MOVE    SCRATCH_HEX, R8
                MOVE    R8, R9
                ADD     2, R9
                SUB     @R8++, @R9++            ; lo/hi of remaining file size
                SUBC    @R8, @R9

                MOVE    SCR$OSM_M_DX, R10       ; R10: width of progress bar
                MOVE    @R10, R10
                SUB     6, R10
                XOR     R11, R11                ; R11: high word of width
                MOVE    SCRATCH_HEX, R1
                ADD     2, R1
                MOVE    @R1++, R8               ; R8: low of remaining file sz
                MOVE    @R1, R9                 ; R9: ditto high
                SYSCALL(divu32, 1)
                MOVE    R8, R6                  ; R6: progress counter low
                MOVE    R9, R7                  ; R7: ditto high
                MOVE    SCRATCH_DWORD, R1
                MOVE    R6, @R1++
                MOVE    R7, @R1

                ; Build a string that represents the space in the main window
                ; where we will print the progress bar
                MOVE    SP, R2                  ; save SP
                MOVE    SCR$OSM_M_DX, R10       ; reserve space on the stack
                MOVE    @R10, R10
                SUB     R10, SP
                MOVE    SP, R11
                SUB     6, R10
                MOVE    R11, R8
                MOVE    M2M$FC_HE_LEFT, @R8++
                MOVE    R10, R9
                MOVE    M2M$LD_SPACE, R10
                SYSCALL(memset, 1)
                ADD     R9, R8
                MOVE    M2M$FC_HE_RIGHT, @R8++
                MOVE    0, @R8
                MOVE    R11, R8
                MOVE    2, R9
                MOVE    SCR$OSM_M_DY, R10
                MOVE    @R10, R10
                SUB     1, R10
                MOVE    M2M$RAMROM_DEV, R1      ; activate the video ram
                MOVE    M2M$VRAM_DATA, @R1
                MOVE    M2M$RAMROM_4KWIN, R1
                MOVE    0, @R1           
                RSUB    SCR$PRINTSTRXY, 1
                MOVE    3, R8
                MOVE    R10, R9
                RSUB    SCR$GOTOXY, 1
                MOVE    R2, SP                  ; restore SP
                MOVE    SCRATCH_HEX, R8         ; SCRATCH_HEX: progress char..
                MOVE    M2M$LD_PROGRESS, @R8++  ; ..plus zero terminator
                MOVE    0, @R8

                ; ------------------------------------------------------------
                ; Load disk image into buffer RAM
                ; ------------------------------------------------------------

                XOR     R1, R1                  ; R1=window: start from 0
                CMP     0, R4                   ; mode=disk image?
                RBRA    _LI_FREAD_S, Z          ; yes
                MOVE    CRTROM_MAN_4KS, R1      ; no: 4k win frpm globals.vhd
                ADD     R12, R1
                MOVE    @R1, R1

_LI_FREAD_S     XOR     R2, R2                  ; R2=start address in window
                ADD     M2M$RAMROM_DATA, R2
                MOVE    M2M$RAMROM_DATA, R3     ; R3=end of 4k page reached
                ADD     0x1000, R3

                MOVE    M2M$RAMROM_DEV, R8
                MOVE    R0, @R8                 ; mount buffer device handle
_LI_FREAD_NXTWN MOVE    M2M$RAMROM_4KWIN, R8    ; set 4k window
                MOVE    R1, @R8

                ; Read next byte
_LI_FREAD_NXTB  MOVE    R5, R8                  ; read next byte to R9
                SYSCALL(f32_fread, 1)
                CMP     FAT32$EOF, R10
                RBRA    _LI_FREAD_EOF, Z
                CMP     0, R10
                RBRA    _LI_FREAD_CONT, Z
                MOVE    ERR_FATAL_LOAD, R8
                MOVE    R10, R9
                RBRA    FATAL, 1

                ; Write byte to mount buffer
_LI_FREAD_CONT  MOVE    R9, @R2++

                ; Progress bar handling
                MOVE    SCRATCH_DWORD, R8       ; next progress char?
                MOVE    @R8++, R9
                MOVE    @R8, R8
                SUB     1, R9                   ; 16-bit decremebt by 1
                SUBC    0, R8
                MOVE    SCRATCH_DWORD, R11      ; remember new value
                MOVE    R9, @R11++
                MOVE    R8, @R11
                CMP     0, R8                   ; if not zero: continue
                RBRA    _LI_FREAD_CONT2, !Z
                CMP     0, R9
                RBRA    _LI_FREAD_CONT2, !Z
                MOVE    SCRATCH_DWORD, R11      ; if zero: progress
                MOVE    R6, @R11++              ; restore original value
                MOVE    R7, @R11
                MOVE    SCRATCH_HEX, R8         ; behind the progress char..
                ADD     2, R8                   ; .. is memory we can use
                RSUB    SAVE_DEVSEL, 1          ; save target device selection
                MOVE    M2M$RAMROM_DEV, R8      ; activate the video ram
                MOVE    M2M$VRAM_DATA, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    0, @R8
                MOVE    SCRATCH_HEX, R8
                RSUB    SCR$PRINTSTR, 1         ; print next progress char
                MOVE    SCRATCH_HEX, R8
                ADD     2, R8
                RSUB    RESTORE_DEVSEL, 1       ; restore target dev. sel.

                ; 4k page handling
_LI_FREAD_CONT2 CMP     R3, R2                  ; end of 4k page reached?
                RBRA    _LI_FREAD_NXTB, !Z      ; no: read next byte
                ADD     1, R1                   ; inc. window counter
                MOVE    M2M$RAMROM_DATA, R2     ; start at beginning of window
                RBRA    _LI_FREAD_NXTWN, 1      ; set next window

                ; End of file reached
_LI_FREAD_EOF   XOR     R6, R6                  ; R6 and R7 are status flags
                XOR     R7, R7                  ; 0 means all good
                CMP     0, R4                   ; disk image mode?
                RBRA    _LI_FREAD_PM, !Z        ; no
                MOVE    LOG_STR_LOADOK, R8      ; yes
                SYSCALL(puts, 1)
                RBRA    _LI_FREAD_RET, 1

                ; ------------------------------------------------------------
                ; Parse cartridge
                ; ------------------------------------------------------------

_LI_FREAD_PM    MOVE    LOG_STR_ROMOK, R8
                SYSCALL(puts, 1)
                MOVE    R0, R8                  ; R8: CRT/ROM device id
                MOVE    R12, R9                 ; R9: CRT/ROM id
                MOVE    HNDL_RM_FILES, R10      ; R10: file handle
                ADD     R12, R10
                MOVE    @R10, R10
                RSUB    HANDLE_CRTROM_M, 1
                MOVE    R8, R6                  ; R6: 0=ok, else error code
                MOVE    R9, R7                  ; R7: error string: only valid
                                                ; if correct device is active

                CMP     0, R6                   ; in case of errors: redraw..
                RSUB    FRAME_FULLSCR, !Z       ; ..the frame: del. prgrs bar

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

                ; Ensure data integrity by preventing random writes to random
                ; SD cards when remembering on-screen-menu settings
                RSUB    ROSM_INTEGRITY, 1

                ; Detect SD card changes to be handled in drive mounting
                ; mechanisms and in the filebrowser
                MOVE    SD_CHANGED, R2
                CMP     1, @R2                  ; "changed" flag alread true?
                RBRA    _HANDLE_IO_0, Z         ; yes: do not allow reset here
                MOVE    SD_ACTIVE, R0           ; no: check status
                MOVE    M2M$CSR, R1             ; extract currently active SD
                MOVE    @R1, R1
                AND     M2M$CSR_SD_ACTIVE, R1
                CMP     @R0, R1                 ; did the card change?
                RBRA    _HANDLE_IO_0, Z         ; no: proceed
                MOVE    R1, @R0                 ; remember new status
                MOVE    1, @R2                  ; set "changed" flag

                ; Loop through all VDRIVES (if any) and check for requests
_HANDLE_IO_0    XOR     R0, R0                  ; R0: number of virtual drive
                MOVE    VDRIVES_NUM, R1
                MOVE    @R1, R1                 ; R1: amount of vdrives
                RBRA    _HANDLE_IO_RET, Z       ; skip, if no VDRIVES

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

                ; write request pending?
                XOR     R0, R0                  ; R0: number of virtual drive
_HANDLE_IO_2    MOVE    R0, R8
                MOVE    VD_WR, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8                   ; write request?
                RBRA    _HANDLE_IO_NXT2, !Z     ; no: next drive, if any

                ; handle write request
                MOVE    R0, R8
                RSUB    HANDLE_DRV_WR, 1

                ; next drive, if applicable
_HANDLE_IO_NXT2 ADD     1, R0                   ; next drive
                CMP     R0, R1                  ; done?
                RBRA    _HANDLE_IO_2, !Z        ; no, continue

                ; any cache dirty => handle background writing
                XOR     R0, R0                  ; R0: number of virtual drive
_HANDLE_IO_3    MOVE    R0, R8
                MOVE    VD_CACHE_DIRTY, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8                   ; cache dirty?
                RBRA    _HANDLE_IO_NXT3, !Z     ; no: next drive, if any

                ; handle dirty cache and background writing (aka flushing)
                MOVE    R0, R8
                RSUB    FLUSH_CACHE, 1

                ; next drive, if applicable
_HANDLE_IO_NXT3 ADD     1, R0                   ; next drive
                CMP     R0, R1                  ; done?
                RBRA    _HANDLE_IO_3, !Z        ; no, continue

_HANDLE_IO_RET  SYSCALL(leave, 1)
                RET

; Handle read request from drive number in R8:
;
; Transfer the data requested by the core from the linear disk image buffer
; to the internal buffer inside the core
;
; @TODO: Sanity check as described in vdrives.vhd protocol comment (3)
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

                MOVE    VD_B_WREN, R8           ; strobe write enable
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
                XOR     R10, R10
                RSUB    VD_DRV_WRITE, 1

                SYSCALL(leave, 1)
                RET

; Handle write request from drive number in R8:
;
; Transfer the data provided by the core to the linear disk image buffer.
; This is something like a RAM disk and provides persistence until the next
; reset or power off.
;
; Caveat: The QNICE SD card system is too slow for some MiSTer cores (for
; example, the C64 core) which expect certain timing characteristics while
; writing. This is why we went for the slightly more complicated
; cached/buffered solution that does the physical writing at a later stage.
HANDLE_DRV_WR   SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: drive number

                ; target write address in bytes HI/LO
                MOVE    R0, R8
                MOVE    VD_BYTES_H, R9
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R1                  ; R1: target bytes hi

                MOVE    R0, R8
                MOVE    VD_BYTES_L, R9
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R2                  ; R2: target bytes lo

                ; to-be-written block-size in bytes
                MOVE    R0, R8
                MOVE    VD_SIZEB, R9
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R3                  ; R3: to-be-written amt bytes

                ; 4k window and offset in disk mount buffer
                MOVE    R0, R8
                MOVE    VD_4K_WIN, R9
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R4                  ; R4: 4k window
                MOVE    R0, R8
                MOVE    VD_4K_OFFS, R9
                RSUB    VD_DRV_READ, 1
                MOVE    M2M$RAMROM_DATA, R5
                ADD     R8, R5                  ; R5: offset in 4k window

                XOR     R6, R6                  ; R6: transmitted bytes
                MOVE    M2M$RAMROM_DATA, R7     ; R7=end of window marker
                ADD     0x1000, R7

                ; read next to-be-written byte from disks internal buffer
_HDW_NEXT_BYTE  MOVE    VD_B_ADDR, R8           ; set address within buffer
                MOVE    R6, R9                  ; R6: transm. bytes = address
                RSUB    VD_CAD_WRITE, 1
                MOVE    R0, R8
                MOVE    VD_B_DIN, R9            ; read byte from above addr
                RSUB    VD_DRV_READ, 1
                MOVE    R8, R12                 ; R12: next byte from int. buf

                ; prepare disk image buffer to store next byte
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    VDRIVES_BUFS, R9        ; array of buf RAM device IDs
                ADD     R0, R9                  ; select right ID for vdrive
                MOVE    @R9, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    R4, @R8

                ; write next byte to disk image buffer
                MOVE    R12, @R5++              ; write byte to RAM buffer
                ADD     1, R6                   ; one more byte transmitted
                CMP     R3, R6                  ; done?
                RBRA    _HDW_DONE, Z            ; yes

                ; handle 4k window boundary
                CMP     R5, R7                  ; 4k boundary reached?
                RBRA    _HDW_NEXT_BYTE, !Z      ; no: next byte
                MOVE    M2M$RAMROM_DATA, R5     ; yes: reset offset
                ADD     1, R4                   ; next 4k window
                RBRA    _HDW_NEXT_BYTE, 1

                ; ackknowledge sd_wr_i
_HDW_DONE       MOVE    R0, R8
                MOVE    VD_ACK, R9
                MOVE    1, R10
                RSUB    VD_DRV_WRITE, 1

                ; unassert ACK
                MOVE    R0, R8
                MOVE    VD_ACK, R9
                XOR     R10, R10
                RSUB    VD_DRV_WRITE, 1

_HDW_RET        SYSCALL(leave, 1)
                RET

; ----------------------------------------------------------------------------
; Disk image cache flushing:
;
; 1. Any write (i.e. any sd_wr_i for the current drive) resets the flushing
;    process because the cache is dirty again and we need to prevent
;    inconsistencies. To "reset" means to "restart at the appropriate time".
; 
; 2. We only start flushing, if for the last two seconds there were no writes.
;    Reason: The drives tend to perform multiple writes to the virtual drive
;    in a row and this would lead to "trashing" when it comes to flushing the
;    cache as each write restarts the whole flushing process.
; 
;    The logic of waiting at least two seconds before we can start flushing
;    and the logic to reset the flushing when a new write comes in is
;    implemented in hardware in vdrives.vhd.
;
; 3. We work in iterations (amount defined in config.vhd): Only a very small
;    amount of bytes is written per iteration to make sure we do not
;    time-out the core: Some cores are very strict when it comes to the
;    intervals between sd_wr_i and sd_ack_o.
;
; 4. The state between iterations is saved in VDRIVES_* variables.
; ----------------------------------------------------------------------------

; FLUSH_CACHE
; Input:   R8 virtual drive number
; Output:  none, registers remain unchanged
FLUSH_CACHE     SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: virtual drive number
                MOVE    HNDL_VD_FILES, R1
                ADD     R0, R1
                MOVE    @R1, R1                 ; R1: image-file handle

                ; has the flushing already begun earlier?
                MOVE    VD_CACHE_FLUSHING, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8
                RBRA    _FC_CONT, Z             ; yes: continue

                ; flushing has not begun, yet: can we start because the
                ; minimum delay is over?
                MOVE    R0, R8
                MOVE    VD_CACHE_FLUSH_ST, R9
                RSUB    VD_DRV_READ, 1
                CMP     1, R8  
                RBRA    _FC_RET, !Z             ; no: return from FLUSH_CACHE

                ; Prepare the flushing process

                ; check for valid file handle
                CMP     0, R1
                RBRA    _FC_PREP, !Z
                MOVE    ERR_FATAL_FZERO, R8
                XOR     R9, R9
                RBRA    FATAL, 1

                ; the size of the image file is equal to the size of the
                ; RAM cache: determine size and store as counter that
                ; will decrement to zero as we are flushing the buffer
                ; (aka amount of bytes still to be written)
_FC_PREP        MOVE    R1, R8
                ADD     FAT32$FDH_SIZE_LO, R8
                MOVE    VDRIVES_FLUSH_L, R9
                ADD     R0, R9
                MOVE    @R8, @R9
                MOVE    R1, R8
                ADD     FAT32$FDH_SIZE_HI, R8
                MOVE    VDRIVES_FLUSH_H, R9
                ADD     R0, R9
                MOVE    @R8, @R9

                ; reset 4K window and offset
                MOVE    VDRIVES_FL_4K, R8
                ADD     R0, R8
                MOVE    0, @R8
                MOVE    VDRIVES_FL_OFS, R8
                ADD     R0, R8
                MOVE    0, @R8

                ; seek to position 0 within the image file
                MOVE    R1, R8
                XOR     R9, R9
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9                   ; seek worked?
                RBRA    _FC_START, Z            ; yes
                MOVE    ERR_FATAL_SEEK, R8      ; no, R9 contains err. no.
                RBRA    FATAL, 1                ; show err msg and halt core

                ; set the flag that signals: flushing in progress
_FC_START       MOVE    R0, R8
                MOVE    VD_CACHE_FLUSHING, R9
                MOVE    1, R10
                RSUB    VD_DRV_WRITE, 1
                RBRA    _FC_RET, 1

                ; Continue with a flushing process that alrady begun earlier

                ; retrieve 4K window and offset and retrieve amount of
                ; bytes that still need to be written
_FC_CONT        XOR     R3, R3                  ; R3: bytes wrtn. in this itr.
                MOVE    VDRIVES_FL_4K, R4
                ADD     R0, R4
                MOVE    @R4, R4                 ; R4: 4k win
                MOVE    VDRIVES_FL_OFS, R5
                ADD     R0, R5
                MOVE    @R5, R5                 ; R5: offset in win
                MOVE    VDRIVES_FLUSH_L, R6
                ADD     R0, R6
                MOVE    @R6, R6                 ; R6: bytes to-be-written lo
                MOVE    VDRIVES_FLUSH_H, R7
                ADD     R0, R7
                MOVE    @R7, R7                 ; R7: bytes to-be-written hi

                ; access cache RAM: select device and 4k window
_FC_FL          MOVE    M2M$RAMROM_DEV, R8
                MOVE    VDRIVES_BUFS, R9        ; array of buf RAM device IDs
                ADD     R0, R9
                MOVE    @R9, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    R4, @R8
                MOVE    M2M$RAMROM_DATA, R8
                ADD     R5, R8
                MOVE    @R8, R9                 ; R9: next byte to be written

                ; write next byte to SD card
                MOVE    R1, R8                  ; R1: file handle
                SYSCALL(f32_fwrite, 1)          ; write R9 to the SD card
                CMP     0, R9                   ; write successful?
                RBRA    _FC_1, Z                ; yes
                MOVE    ERR_FATAL_WRITE, R8     ; no, R9 contains err. no.
                RBRA    FATAL, 1                ; show err msg and halt core

                ; one more byte was written: handle various counters
_FC_1           ADD     1, R3                   ; +1 in current iteration
                ADD     1, R5                   ; +1 in current 4k win. offs.
                SUB     1, R6                   ; 16-bit -1 for tbw counter
                SUBC    0, R7

                ; 16-bit check, if complete buffer was written
                CMP     0, R6
                RBRA    _FC_2, !Z
                CMP     0, R7
                RBRA    _FC_2, !Z

                ; we are done: complete buffer was written
                ; flush SD card internal buffer
                MOVE    R1, R8
                SYSCALL(f32_fflush, 1)
                CMP     0, R9                   ; successful?
                RBRA    _FC_DONE, Z             ; yes
                MOVE    ERR_FATAL_FLUSH, R8     ; no, R9 contains err. no
                RBRA    FATAL, 1                ; show err msg and halt core

                ; done: mark cache as clean and return from subroutine
_FC_DONE        MOVE    R0, R8
                MOVE    VD_CACHE_DIRTY, R9
                MOVE    0, R10
                RSUB    VD_DRV_WRITE, 1
                RBRA    _FC_RET, 1

                ; not done: did the increase of the offs. lead to new 4k win.?
_FC_2           CMP     0x1000, R5
                RBRA    _FC_3, !Z
                XOR     R5, R5                  ; reset offset within window
                ADD     1, R4                   ; next window

                ; iteration complete?
_FC_3           MOVE    VDRIVES_ITERSIZ, R8
                ADD     R0, R8
                CMP     R3, @R8
                RBRA    _FC_FL, !Z              ; no: continue with iteration

                ; iteration complete: remember next valid 4k window and offset
                ; and remember 16-bit to-be-written (tbw) counter
                MOVE    VDRIVES_FL_4K, R8
                ADD     R0, R8
                MOVE    R4, @R8
                MOVE    VDRIVES_FL_OFS, R8
                ADD     R0, R8
                MOVE    R5, @R8
                MOVE    VDRIVES_FLUSH_L, R8
                ADD     R0, R8
                MOVE    R6, @R8
                MOVE    VDRIVES_FLUSH_H, R8
                ADD     R0, R8
                MOVE    R7, @R8

_FC_RET         SYSCALL(leave, 1)
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
; R8: Pointer to error message
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

_FATAL_END      MOVE    NEWLINE, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(crlf, 1)

                MOVE    ERR_FATAL_STOP, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)

                SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Screen handling
; ----------------------------------------------------------------------------

; Fill the whole screen with the main window
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
#include "coreinfo.asm"
#include "crts-and-roms.asm"
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
