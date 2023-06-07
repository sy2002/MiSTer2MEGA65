; ****************************************************************************
; YOUR-PROJECT-NAME (GITHUB-REPO-SHORTNAME) QNICE ROM
;
; Main program that is used to build m2m-rom.rom by make-rom.sh.
; The ROM is loaded by TODO-ADD-NAME-OF-VHDL-FILE-HERE.
;
; The execution starts at the label START_FIRMWARE.
;
; done by YOURNAME in YEAR and licensed under GPL v3
; ****************************************************************************

; If the define RELEASE is defined, then the ROM will be a self-contained and
; self-starting ROM that includes the Monitor (QNICE "operating system") and
; jumps to START_FIRMWARE. In this case it is assumed, that the firmware is
; located in ROM and the variables are located in RAM.
;
; If RELEASE is not defined, then it is assumed that we are in the develop and
; debug mode so that the firmware runs in RAM and can be changed/loaded using
; the standard QNICE Monitor mechanisms such as "M/L" or QTransfer.

#define RELEASE

; ----------------------------------------------------------------------------
; Firmware: M2M system
; ----------------------------------------------------------------------------

; main.asm is the mandatory, so always include it
; It jumps to START_FIRMWARE (see below) after the QNICE "operating system"
; called "Monitor" has been included and initialized
#include "../../M2M/rom/main.asm"

; Only include the Shell, if you want to use the pre-build core automation
; and user experience. If you build your own, then remove this include and
; also remove the include "shell_vars.asm" in the variables section below.
#include "../../M2M/rom/shell.asm"

; ----------------------------------------------------------------------------
; Firmware: Main Code
; ----------------------------------------------------------------------------

                ; Run the Shell: This is where you could put your own system
                ; instead of the shell
START_FIRMWARE  RBRA    START_SHELL, 1

; ----------------------------------------------------------------------------
; Core specific callback functions: Submenus
; ----------------------------------------------------------------------------

; SUBMENU_SUMMARY callback function:
;
; Called when displaying the main menu for every %s that is found in the
; "headline" / starting point of any submenu in config.vhd: You are able to
; change the standard semantics when it comes to summarizing the status of the
; very submenu that is meant by the "headline" / starting point.
;
; Input:
;   R8: pointer to the string that includes the "%s"
;   R9: pointer to the menu item within the M2M$CFG_OPTM_GROUPS structure
;  R10: end-of-menu-marker: if R9 == R10: we reached end of the menu structure
; Output:
;   R8: 0, if no custom SUBMENU_SUMMARY, else:
;       string pointer to completely new headline (do not modify/re-use R8)
;   R9, R10: unchanged

SUBMENU_SUMMARY XOR     R8, R8                  ; R8 = 0 = no custom string
                RET

; ----------------------------------------------------------------------------
; Core specific callback functions: File browsing and disk image mounting
; ----------------------------------------------------------------------------

; FILTER_FILES callback function:
;
; Called by the file- and directory browser. Used to make sure that the 
; browser is only showing valid files and directories.
;
; Input:
;   R8: Name of the file in capital letters
;   R9: 0=file, 1=directory
;  R10: @TODO: Future release: Context (see CTX_* in sysdef.asm)
; Output:
;   R8: 0=do not filter file, i.e. show file
FILTER_FILES    XOR     R8, R8                  ; R8 = 0 = do not filter file
                RET

; PREP_LOAD_IMAGE callback function:
;
; Some images need to be parsed, for example to extract configuration data or
; to move the file read pointer to the start position of the actual data.
; Sanity checks ("is this a valid file") can also be implemented here.
; Last but not least: The mount system supports the concept of a 2-bit
; "image type". In case this is used at the core of your choice, make sure
; you return the correct image type.
;
; Input:
;   R8: File handle: You are allowed to modify the read pointer of the handle
;   R9: @TODO: Future release: Context (see CTX_* in sysdef.asm)
; Output:
;   R8: 0=OK, error code otherwise
;   R9: image type if R8=0, otherwise 0 or optional ptr to  error msg string
PREP_LOAD_IMAGE XOR     R8, R8                  ; no errors
                XOR     R9, R9                  ; image type hardcoded to 0
                RET

; ----------------------------------------------------------------------------
; Core specific callback functions: Custom tasks
; ----------------------------------------------------------------------------

; PREP_START callback function:
;
; Called right before the core is being started. At this point, the core
; is ready to run, settings are loaded (if the core uses settings) and the
; core is still held in reset (if RESET_KEEP is on). So at this point in time,
; you can execute tasks that change the run-state of the core.
;
; Input: None
; Output:
;   R8: 0=OK, else pointer to string with error message
;   R9: 0=OK, else error code
PREP_START      INCRB
                XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; OSM_SEL_POST callback function:
;
; Called each time the user selects something in the on-screen-menu (OSM),
; and while the OSM is still visible. This means, that this callback function
; is called on each press of one of the valid selection keys with the
; exception that pressing a selection key while hovering over a submenu entry
; or exit point does not call this function. All the functionality and
; semantics associated with a certain menu item is already handled by the
; framework when OSM_SELECTED is called, so you are not able to change the
; basic semantics but you are able to add core specific additional
; "intelligent" semantics and behaviors.
;
; Input:
;   R8: selected menu group (as defined in config.vhd)
;   R9: selected item within menu group
;       in case of single selected items: 0=not selected, 1=selected
;   R10: OPTM_KEY_SELECT (by default means "Return") or
;        OPTM_KEY_SELALT (by default means "Space")
; Output:
;   R8: 0=OK, else pointer to string with error message
;   R9: 0=OK, else error code
OSM_SEL_POST    INCRB
                XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; OSM_SEL_PRE callback function:
;
; Identical to the OSM_SEL_POST callback function (see above) but it is being
; called before the functionality and semantics associated with a certain
; menu item has been handled by the framework.
OSM_SEL_PRE     INCRB
                XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; ----------------------------------------------------------------------------
; Core specific callback functions: Custom messages
; ----------------------------------------------------------------------------

; CUSTOM_MSG callback function:
;
; Called in various situations where the Shell needs to output a message
; to the end user. The situations and contexts are described in sysdef.asm
;
; Input:
;   R8: Situation (CMSG_* constants in sysdef.asm)
;   R9: Context   (CTX_* constants in sysdef.asm)
; Output:
;   R8: 0=no custom message available, otherwise pointer to string

CUSTOM_MSG      XOR     R8, R8
                RET              

; ----------------------------------------------------------------------------
; Core specific constants and strings
; ----------------------------------------------------------------------------

; Add your core specific constants and strings here

; This needs to be the last thing before the "Variables" sections starts
END_OF_ROM      .DW 0

; ----------------------------------------------------------------------------
; Variables: Need to be located in RAM
; ----------------------------------------------------------------------------

#ifdef RELEASE
                .ORG    0x8000                  ; RAM starts at 0x8000
#endif

;
; add your own variables here
;

; M2M Shell variables (only include, if you included "shell.asm" above)
#include "../../M2M/rom/shell_vars.asm"

; ----------------------------------------------------------------------------
; Heap and Stack: Need to be located in RAM after the variables
; ----------------------------------------------------------------------------

; The On-Screen-Menu uses the heap for several data structures. This heap
; is located before the main system heap in memory.
; You need to deduct MENU_HEAP_SIZE from the actual heap size below.
; Example: If your HEAP_SIZE would be 29696, then you write 29696-1024=28672
; instead, but when doing the sanity check calculations, you use 29696
MENU_HEAP_SIZE  .EQU 1024

#ifndef RELEASE

; heap for storing the sorted structure of the current directory entries
; this needs to be the last variable before the monitor variables as it is
; only defined as "BLOCK 1" to avoid a large amount of null-values in
; the ROM file
HEAP_SIZE       .EQU 6144                       ; 7168 - 1024 = 6144
HEAP            .BLOCK 1

; in RELEASE mode: 28k of heap which leads to a better user experience when
; it comes to folders with a lot of files
#else

HEAP_SIZE       .EQU 28672                      ; 29696 - 1024 = 28672
HEAP            .BLOCK 1

; The monitor variables use 22 words, round to 32 for being safe and subtract
; it from FF00 because this is at the moment the highest address that we
; can use as RAM: 0xFEE0
; The stack starts at 0xFEE0 (search var VAR$STACK_START in osm_rom.lis to
; calculate the address). To see, if there is enough room for the stack
; given the HEAP_SIZE do this calculation: Add 29696 words to HEAP which
; is currently 0xXXXX and subtract the result from 0xFEE0. This yields
; currently a stack size of more than 1.5k words, which is sufficient
; for this program.

                .ORG    0xFEE0                  ; TODO: automate calculation
#endif

; STACK_SIZE: Size of the global stack and should be a minimum of 768 words
; after you subtract B_STACK_SIZE.
; B_STACK_SIZE: Size of local stack of the the file- and directory browser. It
; should also have a minimum size of 768 words. If you are not using the
; Shell, then B_STACK_SIZE is not used.
STACK_SIZE      .EQU    1536
B_STACK_SIZE    .EQU    768

#include "../../M2M/rom/main_vars.asm"
