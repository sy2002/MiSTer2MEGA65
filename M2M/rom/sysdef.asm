; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; System definition file for registers and MMIO
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Control and status register
; ----------------------------------------------------------------------------

M2M$CSR             .EQU 0xFFE0
    ; Bit      0: Reset the MiSTer core
    ; Bit      1: Pause the MiSTer core
    ; Bit      2: Show On-Screen-Menu (OSM) as an overlay over the core output
    ; Bit      3: Keyboard connection between M65 keyb. and the core
    ; Bit      4: Joy. port 1 connection between M65 joy. port and core
    ; Bit      5: Joy. port 2 connection between M65 joy. port and core
    ; Bits 6..15: RESERVED

M2M$CSR_RESET       .EQU 0x0001
M2M$CSR_UN_RESET    .EQU 0xFFFE
M2M$CSR_PAUSE       .EQU 0x0002
M2M$CSR_UN_PAUSE    .EQU 0xFFFD
M2M$CSR_OSM         .EQU 0x0004
M2M$CSR_UN_OSM      .EQU 0xFFFB
M2M$CSR_KBD         .EQU 0x0008
M2M$CSR_UN_KBD      .EQU 0xFFF7
M2M$CSR_JOY1        .EQU 0x0010
M2M$CSR_UN_JOY1     .EQU 0xFFEF
M2M$CSR_JOY2        .EQU 0x0020
M2M$CSR_UN_JOY2     .EQU 0xFFDF

; Convenient activating of the OSM means:
; Pause the core, show the OSM, de-couple the keyboard and the joysticks
; from the core so that there is no interference, do not reset.
; Convenient de-activating of the OSM means:
; No reset, no pause, no OSM, but the peripherals are coupled.
; The following two values can be directly MOVEd into the CSR
M2M$CSR_OSM_ON      .EQU 0x0006
M2M$CSR_OSM_OFF     .EQU 0x0038

; ----------------------------------------------------------------------------
; 256-bit General purpose control flags
; ----------------------------------------------------------------------------

; 128-bit directly controled by the programmer:
; Select a window between 0 and 7 in M2M$CFD_ADDR and access the control flags
; sliced into 16-bit chunks via M2M$CFD_DATA
M2M$CFD_ADDR        .EQU 0xFFE1
M2M$CFD_DATA        .EQU 0xFFE2

; 128-bit indirectly controled via the "Help Menu", i.e. the menu that by
; default opens when the core is running and the user presses the
; "Help" key of the MEGA65.
M2M$CFM_ADDR        .EQU 0xFFE3
M2M$CFM_DATA        .EQU 0xFFE4

; ----------------------------------------------------------------------------
; MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
; ----------------------------------------------------------------------------

; TODO: Put everything into the QNICE ROM window so that we have plenty of
; RAM, for example for directory browsing
;M2M$RAMROM_MMIO     .EQU 0x
