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

#undef RELEASE

; ----------------------------------------------------------------------------
; Firmware: M2M system
; ----------------------------------------------------------------------------

#include "../../M2M/rom/main.asm"

; Only include the Shell, if you want to use the pre-build core automation
; and user experience. If you build your own, then remove this include and
; also remove the include "shell_vars.asm" in the variables section.
#include "../../M2M/rom/shell.asm"

; ----------------------------------------------------------------------------
; Firmware: Main Code
; ----------------------------------------------------------------------------

                ; Run the shell: This is where you could put your own system
                ; instead of the shell
START_FIRMWARE  RSUB    START_SHELL, 1
                HALT

; ----------------------------------------------------------------------------
; Variables and stack: need to be located in RAM
; ----------------------------------------------------------------------------

#ifdef RELEASE
                .ORG    0x8000                  ; RAM starts at 0x8000
#endif

;
; add your own variables here
;

; M2M shell variables (only include, if you included "shell.asm" above)
#include "../../M2M/rom/shell_vars.asm"

; TODO TODO TODO
; THIS IS STILL THE gbc4MEGA65 comment: Completely redo
; 
; The monitor variables use 20 words, round to 32 for being safe and subtract
; it from B000 because this is at the moment the highest address that we
; can use as RAM: 0xAFE0
; The stack starts at 0xAFE0 (search var VAR$STACK_START in osm_rom.lis to
; calculate the address). To see, if there is enough room for the stack
; given the HEAP_SIZE do this calculation: Add 11.264 words to HEAP which
; is currently 0x8157 and subtract the result from 0xAFE0. This yields
; currently a stack size of 649 words, which is sufficient for this program.

STACK_SIZE      .EQU    649

#ifdef RELEASE
                .ORG    0xAFE0                  ; TODO: automate calculation
#endif

#include "../../M2M/rom/main_vars.asm"
