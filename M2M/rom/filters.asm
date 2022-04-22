; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; MiSTer filter management
;
; The file filter.asm needs the environment of shell.asm.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; more details: see ../vhdl/av_pipeline/video_filters/README.md
#include "../video_filters/lanczos2_12.asm"
#include "../video_filters/Scan_Br_110_80.asm"

; currently, we only support filters with 4 signed 10-bit integers per line,
; 64 lines, i.e. 256 data points
ASCAL_FILTER_LEN    .EQU 0x0100


LOAD_ASCAL_FLT  SYSCALL(enter, 1)

                ; setup the ascal Polyphase RAM device
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$ASCAL_PPHASE, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    0, @R0

                MOVE    ASCAL_FILTER_LEN, R10

                ; copy horizontal filter from ROM to ascal Polyphase RAM
                MOVE    LANCZOS2_12, R8
                MOVE    M2M$RAMROM_DATA, R9
                ADD     M2M$ASCAL_PP_HORIZ, R9
                SYSCALL(memcpy, 1)

                ; copy vertical filter from ROM to ascal Polyphase RAM
                MOVE    SCAN_BR_110_80, R8
                MOVE    M2M$RAMROM_DATA, R9
                ADD     M2M$ASCAL_PP_VERT, R9
                SYSCALL(memcpy, 1)

                SYSCALL(leave, 1)
                RET
