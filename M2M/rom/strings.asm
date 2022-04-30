; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Hardcoded Shell strings that cannot be changed by config.vhd
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

NEWLINE         .ASCII_W "\n"
SPACE           .ASCII_W " "

; The following line is the maximum string length on a PAL output:
; **********************************************

; ----------------------------------------------------------------------------
; File browser
; ----------------------------------------------------------------------------

FN_ROOT_DIR     .ASCII_W "/"
FN_UPDIR        .ASCII_W ".."
FN_ELLIPSIS     .ASCII_W "..." ; hardcoded to a len. of 3, see comment below

; ----------------------------------------------------------------------------
; Debug Mode and log messages for the serial terminal
; (Hold "Run/Stop" + "Cursor Up" and then while holding these, press "Help")
; ----------------------------------------------------------------------------

DBG_START1      .ASCII_P "\nEntering MiSTer2MEGA65 debug mode.\nPress H for "
                .ASCII_W "help and press C R "
#ifdef RELEASE
DBG_START2      .ASCII_P " to return to where you left off\n"
                .ASCII_W "and press C R "
DBG_START3
#else
DBG_START2
#endif
                .ASCII_W " to restart the Shell.\n"

LOG_M2M         .ASCII_P "                                                 \n"
                .ASCII_P "MiSTer2MEGA65 Firmware and Shell, "
                .ASCII_P "done by sy2002 & MJoergen in 2022\n"
                .ASCII_P "https://github.com/sy2002/MiSTer2MEGA65\n\n"
                .ASCII_P "Press 'Run/Stop' + 'Cursor Up' and then while "
                .ASCII_P "holding these press 'Help' to enter the debug "
                .ASCII_W "mode.\n\n"
LOG_STR_SD      .ASCII_W "SD card has been changed. Re-reading...\n"
LOG_STR_CD      .ASCII_W "Changing directory to: "
LOG_STR_ITM_AMT .ASCII_W "Items in current directory (in hex): "
LOG_STR_FILE    .ASCII_W "Selected file: "
LOG_STR_LOADOK  .ASCII_W "Successfully loaded disk image to buffer RAM.\n"
LOG_STR_MOUNT   .ASCII_W "Mounted disk image for drive #"

; ----------------------------------------------------------------------------
; Infos
; ----------------------------------------------------------------------------

STR_INITWAIT    .ASCII_W "Initializing. Please wait..."

; ----------------------------------------------------------------------------
; Warnings
; ----------------------------------------------------------------------------

WRN_MAXFILES    .ASCII_P "Warning: This directory contains more files\n"
                .ASCII_P "than this core is able to load into memory.\n\n"
                .ASCII_P "Please split the files into multiple folders.\n\n"
                .ASCII_P "If you choose to continue by pressing SPACE,\n"
                .ASCII_P "be aware that random files will be missing.\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_ERROR_CODE  .ASCII_W "Error code: "

; ----------------------------------------------------------------------------
; Error Messages
; ----------------------------------------------------------------------------

ERR_FATAL       .ASCII_W "\nFATAL ERROR:\n\n"
ERR_CODE        .ASCII_W "Error code: "
ERR_FATAL_STOP  .ASCII_W "\nCore stopped. Please reset the machine.\n"

ERR_F_MENUSIZE  .ASCII_P "config.vhd: Illegal menu size (OPTM_SIZE):\n"
                .ASCII_W "Must be between 1 and 254\n"
ERR_F_MENUSTART .ASCII_P "config.vhd: No start menu item tag\n"
                .ASCII_W "(OPTM_G_START) found in OPTM_GROUPS\n"

ERR_MOUNT       .ASCII_W "Error: Cannot mount SD card!\nError code: "
ERR_MOUNT_RET   .ASCII_W "\n\nPress Return to retry"
ERR_BROWSE_UNKN .ASCII_W "SD Card: Unknown error while trying to browse.\n"
ERR_FATAL_ITER  .ASCII_W "Corrupt memory structure: Linked-list boundary\n"
ERR_FATAL_FNF   .ASCII_W "File selected in the browser not found.\n"
ERR_FATAL_LOAD  .ASCII_W "SD Card: Unkown error while loading disk image\n"
ERR_FATAL_HEAP1 .ASCII_W "Heap corruption: Hint: MENU_HEAP_SIZE\n"
ERR_FATAL_HEAP2 .ASCII_W "Heap corruption: Hint: OPTM_HEAP_SIZE\n"
ERR_FATAL_BSTCK .ASCII_W "Stack overflow: Hint: B_STACK_SIZE\n"
ERR_FATAL_VDMAX .ASCII_W "Too many virtual drives: Hint: VDRIVES_MAX\n"
ERR_FATAL_VDBUF .ASCII_W "Not enough buffers for virtual drives.\n"

ERR_FATAL_INST  .ASCII_W "Instable system state.\n"

; Error codes for ERR_FATAL_INST: They will help to debug the situation,
; because we will at least know, where the instable system state occured
ERR_FATAL_INST1 .EQU 1 ; options.asm:   _OPTM_CBS_REPL
ERR_FATAL_INST2 .EQU 2 ; shell.asm:     _HM_MOUNTED
ERR_FATAL_INST3 .EQU 3 ; shell.asm:     _HM_SDMOUNTED2A
ERR_FATAL_INST4 .EQU 4 ; options.asm:   _OPTM_GK_MNT

