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
; VGA and On-Screen-Menu (OSM)
; ----------------------------------------------------------------------------

; All coordinates and sizes in the OSM context are specified in characters
; The high-byte of the 16-bit value is always x or dx and the low-byte y or dy

; When bit 2 of the CSR = 1, then the OSM is shown at the coordinates
; and in the size given by these two registers, i.e. these registers are used
; by the display hardware
M2M$OSM_XY          .EQU 0xFFE1     ; x|y coordinates
M2M$OSM_DXDY        .EQU 0xFFE2     ; dx|dy width and height

; The following read-only registers are meant to be used by the QNICE
; firmware. They enable the ability to specify the main screen of the Shell
; and the Help menu via VHDL generics: "M" = main screen; "O" = options menu
M2M$SHELL_M_XY      .EQU 0xFFE3     ; main screen: x|y start coordinates
M2M$SHELL_M_DXDY    .EQU 0xFFE4     ; main screen: dx|dy width and height
M2M$SHELL_O_XY      .EQU 0xFFE5     ; options menu: x|y start coordinates
M2M$SHELL_O_DXDX    .EQU 0xFFE6     ; options menu: dx|dy width and height

; ----------------------------------------------------------------------------
; 256-bit General purpose control flags
; ----------------------------------------------------------------------------

; 128-bit directly controled by the programmer:
; Select a window between 0 and 7 in M2M$CFD_ADDR and access the control flags
; sliced into 16-bit chunks via M2M$CFD_DATA
M2M$CFD_ADDR        .EQU 0xFFE7
M2M$CFD_DATA        .EQU 0xFFE8

; 128-bit indirectly controled via the options menu, i.e. the menu that opens
; when the core is running and the user presses "Help" on the keyboard
M2M$CFM_ADDR        .EQU 0xFFE9
M2M$CFM_DATA        .EQU 0xFFEA

; ----------------------------------------------------------------------------
; MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
; ----------------------------------------------------------------------------

M2M$RAMROM_DEV      .EQU 0xFFEB
    ; Device 0x0000:              VRAM: Data
    ; Device 0x0001:              VRAM: Attributes
    ; Devices 0x0002 .. 0x00FF:   RESERVED
    ; Devices 0x0100 .. 0xFFFF:   Free to be used for any RAM, ROM or device
    ;                             that behaves like a RAM or ROM from the
    ;                             perspective of QNICE

M2M$VRAM_DATA       .EQU 0x0000     ; Device for VRAM: Data
M2M$VRAM_ATTR       .EQU 0x0001     ; Device for VRAM: Attributes

M2M$RAMROM_4KWIN    .EQU 0xFFEC     ; 4k window selector
M2M$RAMROM_DATA     .EQU 0x7000     ; 4k MMIO window to read/write
