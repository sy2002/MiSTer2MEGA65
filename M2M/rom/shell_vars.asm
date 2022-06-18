; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Variables for shell.asm and its direct includes:
; options.asm
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************


#include "dirbrowse_vars.asm"
#include "keyboard_vars.asm"
#include "screen_vars.asm"

#include "menu_vars.asm"

; reset handling
WELCOME_SHOWN   .BLOCK 1                        ; we need to trust that this
                                                ; is 0 on system coldstart

; option menu
OPTM_ICOUNT     .BLOCK 1                        ; amount of menu items
OPTM_START      .BLOCK 1                        ; initially selected menu item
OPTM_SELECTED   .BLOCK 1                        ; last options menu selection
OPTM_MNT_STATUS .BLOCK 1                        ; drive mount status
OPTM_HEAP       .BLOCK 1                        ; pointer to a place that can
                                                ; be used as a scratch buffer
OPTM_HEAP_SIZE  .BLOCK 1                        ; size of this scratch buffer

SCRATCH_HEX     .BLOCK 5

; SD card and file handling
HANDLE_DEV      .BLOCK  FAT32$DEV_STRUCT_SIZE
HANDLE_FILE     .BLOCK  FAT32$FDH_STRUCT_SIZE

SD_ACTIVE       .BLOCK 1                        ; currently active SD card

; SD card "stability" workaround
SD_WAIT         .EQU 0x08F1                     ; 3 seconds @ 50 MHz
SD_CYC_MID      .BLOCK 1                        ; cycle counter for SD card..
SD_CYC_HI       .BLOCK 1                        ; .."stability workaround"
SD_WAIT_DONE    .BLOCK 1                        ; initial waiting done

; file browser persistent status
FB_HEAP         .BLOCK 1                        ; heap used by file browser
FB_STACK        .BLOCK 1                        ; local stack used by  browser
FB_STACK_INIT   .BLOCK 1                        ; initial local browser stack
FB_MAINSTACK    .BLOCK 1                        ; stack of main program
FB_HEAD         .BLOCK 1                        ; lnkd list: curr. disp. head
FB_ITEMS_COUNT  .BLOCK 1                        ; overall amount of items
FB_ITEMS_SHOWN  .BLOCK 1                        ; # of dir. items shown so far

; context variables (see CTX_* constants in sysdef.asm)
SF_CONTEXT      .BLOCK 1                        ; context for SELECT_FILE

; VDRIVES_NUM:      Amount of virtual, mountable drives; needs to correlate
;                   with the actual hardware in vdrives.vhd and the menu items
;                   tagged with OPTM_G_MOUNT_DRV in config.vhd
;
; VDRIVES_DEVICE:   Device ID of the IEC bridge in vdrives.vhd
;
; VDRIVES_BUFS:     Array of device IDs of size VDRIVES_NUM that contains the
;                   RAM buffer-devices that will hold the mounted drives
VDRIVES_NUM     .BLOCK  1
VDRIVES_MAX     .EQU    5
VDRIVES_DEVICE  .BLOCK  1
VDRIVES_BUFS    .BLOCK  VDRIVES_MAX
