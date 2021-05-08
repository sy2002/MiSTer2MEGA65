; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Check routines for the constraints of the core
;
; This list needs to be consistent with vhdl/mbc.vhd
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; Checks for supported Game Boy Memory Bank Controllers (MBCs)
; R8: MBC ID as described in https://gbdev.io/pandocs/#_0147-cartridge-type
; Returns set C flag for supported MBCs
CHECK_MBC       AND     0xFFFB, SR              ; clear carry flag

                ; list of unsupported MBC configurations
                CMP     0x000B, R8              ; MMM01
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x000C, R8              ; MMM01+RAM
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x000D, R8              ; MMM01+RAM+BATTERY
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x0020, R8              ; MBC6
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x0022, R8              ; MBC7
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x00FC, R8              ; POCKET CAMERA
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x00FD, R8              ; BANDAI TAMA5
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x00FE, R8              ; HuC3
                RBRA    _CHECK_MBC_RET, Z
                CMP     0x00FF, R8              ; HuC1+RAM+BATTERY
                RBRA    _CHECK_MBC_RET, Z

_CHECK_MBC_SC   OR      4, SR                   ; set carry flag
_CHECK_MBC_RET  RET

; Checks for supported ROM size code
; R8: ROM size code according to https://gbdev.io/pandocs/#_0148-rom-size
; Returns set C flag for supported ROM sizes
; R9 points to a size string of the maximum supported ROM size
CHECK_ROM       INCRB
                AND     0xFFFB, SR              ; clear carry flag

                MOVE    GBC$MAXRAMROM, R0       ; read constraints from hw
                MOVE    @R0, R0
                AND     0x00FF, R0              ; lo byte = max ROM code
                CMP     R8, R0                  ; given code > max code?
                RBRA    _CHECK_ROM_SC, !N       ; no: set carry and return

                MOVE    ROMCODE2STRING, R1      ; yes: return string that ..
                ADD     R0, R1                  ; .. contains max size
                MOVE    @R1, R9
                RBRA    _CHECK_ROM_RET, 1       ; leave carry cleared

_CHECK_ROM_SC   OR      4, SR                   ; set carry flag
_CHECK_ROM_RET  DECRB
                RET   

ROMCODE2STRING  .DW _ROM_CODE_00, _ROM_CODE_01, _ROM_CODE_02, _ROM_CODE_03,
                .DW _ROM_CODE_04, _ROM_CODE_05, _ROM_CODE_06, _ROM_CODE_07,
                .DW _ROM_CODE_08

_ROM_CODE_00    .ASCII_W "32 KB"
_ROM_CODE_01    .ASCII_W "64 KB"
_ROM_CODE_02    .ASCII_W "128 KB"
_ROM_CODE_03    .ASCII_W "256 KB"
_ROM_CODE_04    .ASCII_W "512 KB"
_ROM_CODE_05    .ASCII_W "1 MB"
_ROM_CODE_06    .ASCII_W "2 MB"
_ROM_CODE_07    .ASCII_W "4 MB"
_ROM_CODE_08    .ASCII_W "8 MB"

; Checks for supported RAM size code
; R8: RAM size code according to https://gbdev.io/pandocs/#_0149-ram-size
; Returns set C flag for supported RAM sizes
; R9 points to a size string of the maximum supported RAM size
CHECK_RAM       INCRB
                AND     0xFFFB, SR              ; clear carry flag

                MOVE    GBC$MAXRAMROM, R0       ; read constraints from hw
                MOVE    @R0, R0
                AND     0xFF00, R0              ; hi byte = max ROM code
                SWAP    R0, R0                  ; swap hi/lo
                CMP     R8, R0                  ; given code > max code?
                RBRA    _CHECK_RAM_SC, !N       ; no: set carry and return

                MOVE    RAMCODE2STRING, R1      ; yes: return string that ..
                ADD     R0, R1                  ; .. contains max size
                MOVE    @R1, R9
                RBRA    _CHECK_RAM_RET, 1       ; leave carry cleared

_CHECK_RAM_SC   OR      4, SR                   ; set carry flag
_CHECK_RAM_RET  DECRB
                RET

RAMCODE2STRING  .DW _RAM_CODE_00, _RAM_CODE_01, _RAM_CODE_02
                .DW _RAM_CODE_03, _RAM_CODE_04, _RAM_CODE_05

_RAM_CODE_00    .ASCII_W "No RAM"
_RAM_CODE_01    .ASCII_W "2 KB"
_RAM_CODE_02    .ASCII_W "8 KB"
_RAM_CODE_03    .ASCII_W "32 KB"
_RAM_CODE_04    .ASCII_W "128 KB"

; according to Pan Docs this is 64 KB, but as we only support an ascending
; logic, we either support 32 KB or 128 KB
_RAM_CODE_05    .ASCII_W "128 KB"
