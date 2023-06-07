; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Hardcoded Shell strings that cannot be changed by config.vhd
;
; Hint: There are more hardcoded strings in menu.asm.
;
; done by sy2002 in 2023 and licensed under GPL v3
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
FN_ELLIPSIS     .ASCII_W "..." ; caution: hardcoded to a len. of 3

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
                .ASCII_P "done by sy2002 & MJoergen in 2022 & 2023\n"
                .ASCII_P "https://github.com/sy2002/MiSTer2MEGA65\n\n"
                .ASCII_P "Press 'Run/Stop' + 'Cursor Up' and then while "
                .ASCII_P "holding these press 'Help' to enter the debug "
                .ASCII_W "mode.\n\n"
LOG_CORE        .ASCII_W "Core: "
LOG_CORE_VA1    .ASCII_W "Core's visible area in pixels:\n"
LOG_CORE_VA2    .ASCII_W "  ASCAL: DX="
LOG_CORE_VA3    .ASCII_W "  DY="
LOG_CORE_VA4    .ASCII_W "  M2M:   DX="
LOG_CORE_WRN1   .ASCII_W "Warning: ASCAL and M2M measurements diverge.\n"
LOG_CORE_VTIME  .ASCII_W "Core's video timing parameters:\n"
LOG_CORE_H_PLSE .ASCII_W "  Horizontal pulse:       "
LOG_CORE_H_FP   .ASCII_W "  Horizontal front porch: "
LOG_CORE_H_BP   .ASCII_W "  Horizontal back porch:  "
LOG_CORE_V_PLSE .ASCII_W "  Vertical pulse:         "
LOG_CORE_V_FP   .ASCII_W "  Vertical front porch:   "
LOG_CORE_V_BP   .ASCII_W "  Vertical back porch:    "
LOG_CORE_H_FREQ .ASCII_W "  Horizontal frequency:   "
LOG_CORE_FRAME  .ASCII_W "  Frame rate:             "
LOG_CORE_PIXEL  .ASCII_W "  Pixel rate:             "
LOG_CORE_WRN2   .ASCII_W "<n/a>\n"
LOG_CORE_HZ     .ASCII_W " Hz\n"
LOG_CORE_KHZ    .ASCII_W " kHz\n"
LOG_CORE_MHZ    .ASCII_W " MHz\n"
LOG_CORE_DOT    .ASCII_W "."
LOG_OSM_HEAP1   .ASCII_W "OSM heap utilization:\n"
LOG_OSM_HEAP2   .ASCII_W "  MENU_HEAP_SIZE:               "
LOG_OSM_HEAP3A  .ASCII_W "  Free menu heap space:         "
LOG_OSM_HEAP3B  .ASCII_W "  FATAL overflow of menu heap:  "
LOG_OSM_HEAP4   .ASCII_W "  OPTM_HEAP_SIZE:               "
LOG_OSM_HEAP5A  .ASCII_W "  Free OPTM heap space:         "
LOG_OSM_HEAP5B  .ASCII_W "  FATAL overflow of OPTM heap:  "
LOG_GEN_MEM1    .ASCII_W "Maximum available QNICE memory: "
LOG_GEN_MEM2A   .ASCII_W "  Used as general heap:         "
LOG_GEN_MEM2B   .ASCII_W "  Used as menu heap:            "
LOG_GEN_MEM3    .ASCII_W "  Used as stack:                "
LOG_GEN_MEM4    .ASCII_W "    Used as general stack:      "
LOG_GEN_MEM5    .ASCII_W "    Used as browser stack:      "
LOG_GEN_MEM6    .ASCII_W "  Free QNICE memory:            "
LOG_GEN_ROM     .ASCII_W "Free space in QNICE ROM:        "
LOG_GEN_ROM_NA  .ASCII_W "<n/a: running in RAM>\n"
LOG_STR_SD      .ASCII_W "SD card has been changed. Re-reading...\n"
LOG_STR_CD      .ASCII_W "Changing directory to: "
LOG_STR_ITM_AMT .ASCII_W "Items in current directory (in hex): "
LOG_STR_FILE    .ASCII_W "Selected file: "
LOG_STR_LOADOK  .ASCII_W "Successfully loaded disk image to buffer RAM.\n"
LOG_STR_MOUNT   .ASCII_W "Mounted disk image for drive #"
LOG_STR_CONFIG  .ASCII_W "Configuration: Remember settings: "
LOG_STR_CFG_ON  .ASCII_W "ON  "
LOG_STR_CFG_OFF .ASCII_W "OFF  " 
LOG_STR_CFG_E1  .ASCII_W "Unable to mount SD card.  "
LOG_STR_CFG_E2  .ASCII_W "Config file not found: "
LOG_STR_CFG_E3  .ASCII_W "New config file found: "
LOG_STR_CFG_E4  .ASCII_W "Corrupt config file: "
LOG_STR_CFG_SP  .ASCII_W "  "
LOG_STR_CFG_FOK .ASCII_W "Using config file: "
LOG_STR_CFG_STD .ASCII_W "Using factory defaults.\n"
LOG_STR_CFG_SDC .ASCII_P "Configuration: Remember settings: OFF  "
                .ASCII_W "Reason: SD card changed.\n"
LOG_STR_CFG_REM .ASCII_P "Configuration: New settings successfully stored to "
                .ASCII_W "SD card.\n"
LOG_STR_CFG_NO  .ASCII_P "Configuration: New settings cannot be saved because"
                .ASCII_W " the core is currently saving to a disk image.\n"

LOG_STR_ROMOK   .ASCII_W "Successfully loaded CRT/ROM image to buffer RAM.\n"
LOG_STR_ROMPRS  .ASCII_W "Parsing CRT/ROM image: "
LOG_STR_ROMPRSO .ASCII_W "OK\n"
LOG_STR_ROMPRSE .ASCII_W "ERROR #"
LOG_STR_ROMPRSC .ASCII_W ": "

LOG_STR_ARSTART .ASCII_W " auto-load ROMs are part of this core:\n"
LOG_STR_ARLINE1 .ASCII_W "  ROM #"
LOG_STR_ARLINE2 .ASCII_W ": type="
LOG_STR_ARLINE3 .ASCII_W " device="
LOG_STR_ARLINE4 .ASCII_W " 4k window="
LOG_STR_ARLINE5 .ASCII_W " mode=mandatory"
LOG_STR_ARLINE6 .ASCII_W " mode=optional"
LOG_STR_ARLINE7 .ASCII_W " file="
LOG_STR_ARLINE8 .ASCII_W "LOADING ROM #"
LOG_STR_ROMPRS9 .ASCII_W ": OK\n"
LOG_STR_ROMPRSA .ASCII_W ": FAILED\n"
LOG_STR_RNOMNT  .ASCII_P "Automatic ROM loading failed: Cannot mount SD card."
                .ASCII_P " Will try to continue without loading ROMs."
                .ASCII_W " Mount error code: "

; ----------------------------------------------------------------------------
; Infos
; ----------------------------------------------------------------------------

STR_INITWAIT    .ASCII_W "Initializing. Please wait..."
STR_SPACE       .ASCII_W "Press Space to continue."

; ----------------------------------------------------------------------------
; Warnings
; ----------------------------------------------------------------------------

WRN_MAXFILES    .ASCII_P "Warning: This directory contains more\n"
                .ASCII_P "files than this core is able to load into\n"
                .ASCII_P "memory.\n\n"
                .ASCII_P "Split the files into multiple folders.\n\n"
                .ASCII_P "If you continue by pressing SPACE, be\n"
                .ASCII_P "aware that random files will be missing.\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_EMPTY_BRW   .ASCII_P "The root directory of the SD card contains\n"
                .ASCII_P "no sub-directories that might contain any\n"
                .ASCII_P "files that match the criteria of this core.\n\n"
                .ASCII_P "And the root directory itself also does not\n"
                .ASCII_P "contain any files that match the criteria\n"
                .ASCII_P "of this core.\n\n"
                .ASCII_P "Nothing to browse.\n\n"
                .ASCII_W "Press Space to continue."

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
ERR_F_MENUSUB   .ASCII_P "config.vhd: One or more submenu is not\n"
                .ASCII_W "having an ending OPTM_G_SUBMENU.\n"
ERR_F_MENUNGRP  .ASCII_P "config.vhd: No selected menu group item\n"
                .ASCII_W "found within submenu.\n"
ERR_F_NEWLINE   .ASCII_P "config.vhd: Each line in OPTM_ITEMS needs\n"
                .ASCII_W "to be terminated by a newline character.\n"
ERR_F_MENUDRV   .ASCII_P "config.vhd: More menu items have the\n"
                .ASCII_P "attribute OPTM_G_MOUNT_DRV than there are\n"
                .ASCII_P "virtual drives configured in globals.vhd\n"
                .ASCII_W "using C_VDNUM.\n"
ERR_F_NO_S      .ASCII_W "M2M$RPL_S: No %s found in source string.\n"
ERR_F_CR_M_CNT  .ASCII_P "globals.vhd: C_CRTROMS_MAN_NUM too large.\n"
                .ASCII_W "Hint: CRTROM_MAN_MAX in make-rom.sh\n"
ERR_F_CR_M_TYPE .ASCII_P "globals.vhd: C_CRTROMS_MAN: Illegal type\n"
                .ASCII_W "or device id or 4k window.\n"
ERR_F_CR_A_CNT  .ASCII_P "globals.vhd: C_CRTROMS_AUT_NUM too large.\n"
                .ASCII_W "Hint: CRTROM_AUT_MAX in make-rom.sh\n"
ERR_F_CR_A_TYPE .ASCII_P "globals.vhd: C_CRTROMS_AUT: Illegal type\n"
                .ASCII_W "or device id or 4k window or mode.\n"
ERR_F_ATRMNMNT  .ASCII_P "This core needs to load one or more\n"
                .ASCII_P "mandatory ROMs from SD card. But no SD\n"
                .ASCII_W "card can be mounted.\n"
ERR_F_ATRMLOAD  .ASCII_P "\n\nFile not found or file read error.\n"
                .ASCII_W "The core needs this ROM to start.\n\n"
ERR_MOUNT       .ASCII_W "Error: Cannot mount SD card!\nError code: "
ERR_MOUNT_RET   .ASCII_W "\n\nPress Return to retry"
ERR_BROWSE_UNKN .ASCII_W "SD Card:\nUnknown error while trying to browse.\n"
ERR_FATAL_ITER  .ASCII_W "Corrupt memory structure:\nLinked-list boundary\n"
ERR_FATAL_FNF   .ASCII_W "File selected in the browser not found.\n"
ERR_FATAL_LOAD  .ASCII_W "SD Card:\nUnkown error while loading disk image\n"
ERR_FATAL_HEAP1 .ASCII_W "Heap corruption: Hint: MENU_HEAP_SIZE\n"
ERR_FATAL_HEAP2 .ASCII_W "Heap corruption: Hint: OPTM_HEAP_SIZE\n"
ERR_FATAL_BSTCK .ASCII_W "Stack overflow: Hint: B_STACK_SIZE\n"
ERR_FATAL_VDMAX .ASCII_W "Too many virtual drives: Hint: VDRIVES_MAX\n"
ERR_FATAL_VDBUF .ASCII_W "Not enough buffers for virtual drives.\n"
ERR_FATAL_FZERO .ASCII_W "Write disk: File handle is zero.\n"
ERR_FATAL_SEEK  .ASCII_W "Write disk: Seek failed.\n"
ERR_FATAL_WRITE .ASCII_W "Write disk: Writing failed.\n"
ERR_FATAL_FLUSH .ASCII_W "Write disk:\nFlushing of SD card buffer failed.\n"
ERR_FATAL_ROSMS .ASCII_W "Settings file: Seek failed.\n"
ERR_FATAL_ROSMR .ASCII_W "Settings file: Reading failed.\n"
ERR_FATAL_ROSMW .ASCII_W "Settings file: Writing failed.\n"
ERR_FATAL_ROSMF .ASCII_P "Settings file:\n"
                .ASCII_W "Flushing of SD card buffer failed.\n"
ERR_FATAL_ROSMC .ASCII_W "Settings file:\nCorrupt: Illegal config value.\n"
ERR_FATAL_TG    .ASCII_W "tools.asm: M2M$GET_SETTING: Illegal index.\n"
ERR_FATAL_TS    .ASCII_W "tools.asm: M2M$SET_SETTING: Illegal index.\n"

ERR_FATAL_INST  .ASCII_W "Instable system state.\n"

; Error codes for ERR_FATAL_INST: They will help to debug the situation,
; because we will at least know, where the instable system state occured
ERR_FATAL_INST1 .EQU 1  ; options.asm:       OPTM_CB_SHOW
ERR_FATAL_INST2 .EQU 2  ; shell.asm:         _HM_MOUNTED
ERR_FATAL_INST3 .EQU 3  ; shell.asm:         _HM_SDMOUNTED2A
ERR_FATAL_INST4 .EQU 4  ; options.asm:       _OPTM_GK_MNT
ERR_FATAL_INST5 .EQU 5  ; crts-and-roms.asm  HANDLE_CRTROM_M
ERR_FATAL_INST6 .EQU 6  ; options.asm:       _OPTM_CBS_CTRM
ERR_FATAL_INST7 .EQU 7  ; shell.asm:         _HM_SDMOUNTED3
ERR_FATAL_INST8 .EQU 8  ; options.asm        _OPTM_CBS_I
ERR_FATAL_INST9 .EQU 9  ; options.asm        _OPTM_CBS_I4
ERR_FATAL_INSTA .EQU 10 ; shell.asm:         _HM_SDMOUNTED6B
ERR_FATAL_INSTB .EQU 11 ; options.asm        _OPTM_GK_CRTROM
