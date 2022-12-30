; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Main include for m2m-rom.asm
;
; As the main include is intended to be included in each and every M2M
; project, it does not contain any part of the Shell yet to leave it up to
; the user of the M2M framework to decide. If the Shell is not used, then the
; respective overhead is being avoided.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

#include "../../M2M/QNICE/dist_kit/sysdef.asm"
#include "sysdef.asm"

; ----------------------------------------------------------------------------
; Release Mode: Run in ROM
; ----------------------------------------------------------------------------

#ifdef RELEASE
                .ORG    0x0000                  ; start in ROM

; include QNICE Monitor for SYSCALL "operating system" functions
#include "monitor/qmon_m2m.asm"
#include "monitor/io_library_m2m.asm"
#include "../../M2M/QNICE/monitor/string_library.asm"
#include "../../M2M/QNICE/monitor/mem_library.asm"
#include "../../M2M/QNICE/monitor/debug_library.asm"
#include "../../M2M/QNICE/monitor/misc_library.asm"
#include "../../M2M/QNICE/monitor/uart_library.asm"
#include "../../M2M/QNICE/monitor/usb_keyboard_library.asm"
#include "../../M2M/QNICE/monitor/vga_library.asm"
#include "../../M2M/QNICE/monitor/math_library.asm"
#include "../../M2M/QNICE/monitor/sd_library.asm"
#include "../../M2M/QNICE/monitor/fat32_library.asm"

QMON$LAST_ADDR  HALT

INIT_FIRMWARE   AND     0x00FF, SR              ; activate register bank 0
                MOVE    VAR$STACK_START, SP     ; initialize stack pointer
                MOVE    IO$KBD_STATE, R8        ; set DE keyboard locale
                OR      KBD$LOCALE_DE, @R8
                MOVE    _SD$DEVICEHANDLE, R8    ; unmount the SD Card
                XOR     @R8, @R8
                RBRA    START_FIRMWARE, 1

; ----------------------------------------------------------------------------
; Develop & Debug Mode: Run in RAM
; ----------------------------------------------------------------------------

#else

#include "../../M2M/QNICE/dist_kit/monitor.def"

                .ORG    0x8000                  ; start in RAM
                RBRA    START_FIRMWARE, 1
#endif
