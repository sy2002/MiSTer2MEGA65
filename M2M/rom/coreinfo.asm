; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Log information about the core to the serial terminal
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

LOG_COREINFO    SYSCALL(enter, 1)

                ; CORENAME from config.vhd
                MOVE    LOG_CORE, R8
                SYSCALL(puts, 1)
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$CONFIG, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$CFG_CORENAME, @R8
                MOVE    M2M$RAMROM_DATA, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                ; Set system info device to core infos
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$SYS_INFO, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$SYS_CORE, @R8


                ; DX|DY of the visible area of the core, measured by
                ; ASCAL and by own counters in the M2M framework
                MOVE    LOG_CORE_VA1, R8
                SYSCALL(puts, 1)
                MOVE    LOG_CORE_VA2, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_X, R8
                RSUB    _LOG_DECIMAL, 1
                MOVE    LOG_CORE_VA3, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_Y, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_VA4, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_PXLS, R8
                RSUB    _LOG_DECIMAL, 1
                MOVE    LOG_CORE_VA3, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_V_PXLS, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)

                ; Warning in case ASCAL and M2M contradict
                MOVE    M2M$SYS_CORE_X, R0
                MOVE    M2M$SYS_CORE_H_PXLS, R1
                CMP     @R0, @R1
                RBRA    _LOG_CRENFO_1, !Z
                MOVE    M2M$SYS_CORE_Y, R0
                MOVE    M2M$SYS_CORE_V_PXLS, R1
                CMP     @R0, @R1
                RBRA    _LOG_CRENFO_2, Z
_LOG_CRENFO_1   MOVE    LOG_CORE_WRN1, R8
                SYSCALL(puts, 1)

_LOG_CRENFO_2   SYSCALL(crlf, 1)                ; 1 line betw. this & the rest
                SYSCALL(leave, 1)
                RET


; Takes register address in R8 and logs the value as a decimal value
_LOG_DECIMAL    INCRB

                MOVE    @R8, R8                 ; low word of hex value
                XOR     R9, R9                  ; high word of hex value
                SUB     11, SP                  ; memory for string
                MOVE    SP, R10
                SYSCALL(h2dstr, 1)              ; create decimal string

                MOVE    R11, R8                 ; log string to serial
                SYSCALL(puts, 1)

                ADD     11, SP                  ; free memory on stack

                DECRB
                RET
