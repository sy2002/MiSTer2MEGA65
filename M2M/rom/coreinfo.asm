; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Log information about the core to the serial terminal
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; Log the core name from config.vhd
LOG_CORENAME    SYSCALL(enter, 1)

                MOVE    LOG_CORE, R8
                SYSCALL(puts, 1)
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$CONFIG, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$CFG_CORENAME, @R8
                MOVE    M2M$RAMROM_DATA, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                SYSCALL(leave, 1)
                RET

; Reset flag and timing variables
LOG_PREP        INCRB

                MOVE    LOG_HFREQ_FLAG, R0
                MOVE    0, @R0

                ; determine current system time
                MOVE    LOG_CYC_MID, R0
                MOVE    IO$CYC_MID, R7
                MOVE    @R7, @R0                
                MOVE    LOG_CYC_HI, R1
                MOVE    IO$CYC_HI, R7
                MOVE    @R7, @R1

                ; add 2.5 seconds
                ADD     LOG_HFREQ_WAIT, @R0
                ADDC    0, @R1

                DECRB
                RET                

; Log coreinfo 2.5 seconds after the core has started
; This function is meant to be called inside the main loop
LOG_COREINFO    SYSCALL(enter, 1)

                ; If we already logged the info: skip this function
                MOVE    LOG_HFREQ_FLAG, R0
                CMP     1, @R0
                RBRA    _LOG_CRENFO_R2, Z

                ; Check if the 2.5 seconds are over
                MOVE    LOG_CYC_HI, R1
                MOVE    IO$CYC_HI, R7
                CMP     @R7, @R1
                RBRA    _LOG_CRENFO_S, N
                MOVE    LOG_CYC_MID, R1
                MOVE    IO$CYC_MID, R7
                CMP     @R7, @R1
                RBRA    _LOG_CRENFO_R2, !N

_LOG_CRENFO_S   MOVE    1, @R0                  ; remember that log was shown

                ; Set system info device to core infos
                MOVE    M2M$RAMROM_DEV, R8
                MOVE    M2M$SYS_INFO, @R8
                MOVE    M2M$RAMROM_4KWIN, R8
                MOVE    M2M$SYS_CORE, @R8

                ; DX|DY of the visible area of the core, measured by
                ; ASCAL and by own counters in the M2M framework
                SYSCALL(crlf, 1)
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

                ; Output video timing parameters
_LOG_CRENFO_2   MOVE    LOG_CORE_VTIME, R8
                SYSCALL(puts, 1)
                MOVE    LOG_CORE_H_PLSE, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_PLSE, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_H_FP , R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_FP, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_H_BP , R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_BP, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_V_PLSE, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_V_PLSE, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_V_FP , R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_V_FP, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_V_BP , R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_V_BP, R8
                RSUB    _LOG_DECIMAL, 1
                SYSCALL(crlf, 1)
                MOVE    LOG_CORE_H_FREQ, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_FREQ, R8
                MOVE    @R8, R8
                MOVE    3, R9
                RSUB    _LOG_DECIMAL_D, 1
                MOVE    LOG_CORE_KHZ, R8
                SYSCALL(puts, 1)

                ; Calculate and output frame rate in Hz:
                ; H_FREQ / (V_PIXELS + V_PULSE + V_BP + V_FP)
                ; Integer math: multiply H_FREQ with 100 so that we can
                ; easily compute and round the decimal values
                MOVE    LOG_CORE_FRAME, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_FREQ, R8
                MOVE    @R8, R8
                MOVE    100, R9
                SYSCALL(mulu, 1)                ; R11|R10 = 32bit (R8 x R9)
                XOR     R1, R1
                MOVE    M2M$SYS_CORE_V_PXLS, R0
                ADD     @R0, R1
                MOVE    M2M$SYS_CORE_V_PLSE, R0
                ADD     @R0, R1
                MOVE    M2M$SYS_CORE_V_FP, R0
                ADD     @R0, R1
                MOVE    M2M$SYS_CORE_V_BP, R0
                ADD     @R0, R1
                MOVE    R10, R8
                MOVE    R11, R9
                MOVE    R1, R10
                XOR     R11, R11
                SYSCALL(divu32, 1)              ; R8 contains framerate
                ADD     5, R8                   ; rounding to one decimal
                MOVE    10, R9
                SYSCALL(divu, 1)
                MOVE    R10, R8
                MOVE    1, R9
                RSUB    _LOG_DECIMAL_D, 1
                MOVE    LOG_CORE_HZ, R8
                SYSCALL(puts, 1)

                ; Calculate and output pixel rate in MHz:
                ; H_FREQ * (H_PIXELS + H_PULSE + H_BP + H_FP)
                MOVE    LOG_CORE_PIXEL, R8
                SYSCALL(puts, 1)
                MOVE    M2M$SYS_CORE_H_FREQ, R8
                MOVE    @R8, R8
                XOR     R9, R9
                MOVE    M2M$SYS_CORE_H_PXLS, R0
                ADD     @R0, R9
                MOVE    M2M$SYS_CORE_H_PLSE, R0
                ADD     @R0, R9
                MOVE    M2M$SYS_CORE_H_FP, R0
                ADD     @R0, R9
                MOVE    M2M$SYS_CORE_H_BP, R0
                ADD     @R0, R9
                SYSCALL(mulu, 1)
                MOVE    R10, R8
                MOVE    R11, R9
                ADD     500, R8                 ; rounding to three decimals
                MOVE    1000, R10
                XOR     R11, R11
                SYSCALL(divu32, 1)
                CMP     0, R9
                RBRA    _LOG_CRENFO_3, !Z
                MOVE    3, R9
                RSUB    _LOG_DECIMAL_D, 1
                MOVE    LOG_CORE_MHZ, R8
                SYSCALL(puts, 1)
                RBRA    _LOG_CRENFO_R1, 1

                ; Output <n/a> in case of "overflow" in pixel rate calculation
                ; @TODO: Actually, this is currently only a contraint when
                ; it comes to the _LOG_DECIMAL_D function. So as soon as we
                ; will work with retro cores that have such high pixel rates
                ; we "just" need to write a smarter _LOG_DECIMAL_D function
_LOG_CRENFO_3   MOVE    LOG_CORE_WRN2, R8
                SYSCALL(puts, 1)

_LOG_CRENFO_R1  SYSCALL(crlf, 1)                ; 1 line betw. this & the rest
_LOG_CRENFO_R2  SYSCALL(leave, 1)
                RET

; Takes register address in R8 and logs the value as a decimal value
_LOG_DECIMAL    SYSCALL(enter, 1)

                MOVE    @R8, R8                 ; low word of hex value
                XOR     R9, R9                  ; high word of hex value
                SUB     11, SP                  ; memory for string
                MOVE    SP, R10
                SYSCALL(h2dstr, 1)              ; create decimal string

                MOVE    R11, R8                 ; log string to serial
                SYSCALL(puts, 1)

                ADD     11, SP                  ; free memory on stack

                SYSCALL(leave, 1)
                RET

; Similar to _LOG_DECIMAL but in contrast:
; The value in R8 is taken verbatim and "divided" by 10^R9
;
; Caveat: This function simply puts a decimal point left to the digit denoted
; by R9 so make sure the input number is large enough. No sanity checks
_LOG_DECIMAL_D  SYSCALL(enter, 1)

                MOVE    R8, R0
                MOVE    R9, R1

                XOR     R9, R9                  ; high word of hex value
                SUB     11, SP                  ; memory for string
                MOVE    SP, R10
                SYSCALL(h2dstr, 1)              ; create decimal string

                MOVE    R11, R8                 ; R11: decimal as a string
                SYSCALL(strlen, 1)              ; R9: length of string

                ; put a "." before the last R9 digits by first printing
                ; the string before the "." by inserting a zero terminator and
                ; using the normal string functionality, then restoring the
                ; digit "under" the "." and then printing the rest
                SUB     R1, R9
                ADD     R9, R8
                MOVE    @R8, R2                 ; remember original character
                MOVE    0, @R8
                MOVE    R8, R3                  ; remember pos. of org. char
                MOVE    R11, R8
                SYSCALL(puts, 1)                ; output value before the dot
                MOVE    LOG_CORE_DOT, R8        ; output the dot
                SYSCALL(puts, 1)
                MOVE    R2, @R3
                MOVE    R3, R8
                SYSCALL(puts, 1)                ; output value after the dot

                ADD     11, SP                  ; free memory on stack

                SYSCALL(leave, 1)
                RET 
