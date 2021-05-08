; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Definitions for MMIO access to the Game Boy Color core
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Control and status register
; ----------------------------------------------------------------------------

GBC$CSR             .EQU 0xFFE0
    ; Bit      0: Reset
    ; Bit      1: Pause
    ; Bit      2: Show On-Screen-Menu (OSM)
    ; Bit      3: Keyboard connection between M65 keyb. and GB is ON
    ; Bit      4: Joystick connection between M65 joy. ports and GB is ON
    ; Bit      5: 1 = Game Boy Color, 0 = Game Boy Classic
    ; Bit    6-7: Joystick mapping: 00 = Standard, Fire=A
    ;                               01 = Standard, Fire=B
    ;                               10 = Up=A, Fire=B
    ;                               11 = Up=B, Fire=A
    ; Bit      8: Color mode: 0=Fuly Saturated (Raw RGB), 1=LCD Emulation

GBC$CSR_RESET       .EQU 0x0001
GBC$CSR_UN_RESET    .EQU 0xFFFE
GBC$CSR_PAUSE       .EQU 0x0002
GBC$CSR_UN_PAUSE    .EQU 0xFFFD
GBC$CSR_OSM         .EQU 0x0004
GBC$CSR_UN_OSM      .EQU 0xFFFB
GBC$CSR_KEYBOARD    .EQU 0x0008
GBC$CSR_UN_KEYB     .EQU 0xFFF7
GBC$CSR_JOYSTICK    .EQU 0x0010
GBC$CSR_UN_JOY      .EQU 0xFFEF
GBC$CSR_GBC         .EQU 0x0020
GBC$CSR_UN_GBC      .EQU 0xFFDF

; constants used to directly transfer the menu selection to the right spot
; inside the CSR bitpattern
GBC$CSR_JOYMAP_CLR  .EQU 0xFF3F                 ; AND mask to clear joy map
GBC$CSR_JOYMAP_SHL  .EQU 0x0006                 ; SHL amount to joy map
GBC$CSR_COLM_CLR    .EQU 0xFEFF                 ; AND mask to clear color mode
GBC$CSR_COLM_SHL    .EQU 0x0008                 ; SHL amount to color mode

; ----------------------------------------------------------------------------
; Window selector for MEM_CARTRIDGE_WIN
; ----------------------------------------------------------------------------

; actual cartridge RAM address = GBC$CART_SEL x 4096 + MEM_CARTRIDGE_WIN 
GBC$CART_SEL        .EQU 0xFFE1 

; ----------------------------------------------------------------------------
; On-Screen-Menu (OSM)
; ----------------------------------------------------------------------------

; When bit 2 of the CSR = 1, then the OSM is shown at the coordinates
; and in the size given by these two registers. The coordinates and the
; size are specified in characters.
GBC$OSM_XY          .EQU 0xFFE2 ; hi-byte = x-start coord, lo-byte = ditto y
GBC$OSM_DXDY        .EQU 0xFFE3 ; hi-byte = dx, lo-byte = dy

GBC$OSM_COLS        .EQU 50     ; columns (max chars per line)
GBC$OSM_ROWS        .EQU 37     ; rows (max lines per screen)

GBC$OPT_DX          .EQU 20     ; width of option menu
GBC$OPT_DY          .EQU 20     ; height of option menu

; ----------------------------------------------------------------------------
; Keyboard matrix (read-only)
; ----------------------------------------------------------------------------

GBC$KEYMATRIX       .EQU 0xFFE4

; AND-masks for keys
KEY_CUR_UP          .EQU 0x0004
KEY_CUR_DOWN        .EQU 0x0008
KEY_CUR_LEFT        .EQU 0x0002
KEY_CUR_RIGHT       .EQU 0x0001
KEY_RETURN          .EQU 0x0040
KEY_SPACE           .EQU 0x0080
KEY_LSHIFT          .EQU 0x0010
KEY_MEGA            .EQU 0x0020
KEY_RUNSTOP         .EQU 0x0100
KEY_HELP            .EQU 0x0200

; ----------------------------------------------------------------------------
; MMIO Cartridge flags
; ----------------------------------------------------------------------------

; MMIO address
GBC$CF_CGB          .EQU 0xFFE5
GBC$CF_SGB          .EQU 0xFFE6
GBC$CF_MBC          .EQU 0xFFE7
GBC$CF_ROM_SIZE     .EQU 0xFFE8
GBC$CF_RAM_SIZE     .EQU 0xFFE9
GBC$CF_OLDLICENSEE  .EQU 0xFFEA

; Codes of the highest supported ROM and RAM amounts
; hi-byte: RAM code, lo-byte: ROM code
GBC$MAXRAMROM       .EQU 0xFFEB

; Address within the cartridge header
GBC$CF_CGB_CHA      .EQU 0x0143
GBC$CF_SGB_CHA      .EQU 0x0146
GBC$CF_MBC_CHA      .EQU 0x0147
GBC$CF_ROM_SIZE_CHA .EQU 0x0148
GBC$CF_RAM_SIZE_CHA .EQU 0x0149
GBC$CF_OLDLIC_CHA   .EQU 0x014B

; ----------------------------------------------------------------------------
; MMIO Cartridge, BIOS and VRAM
; ----------------------------------------------------------------------------

MEM_CARTRIDGE_WIN   .EQU 0xB000 ; 4kb window defined by GBC$CART_SEL
MEM_BIOS            .EQU 0xC000 ; GBC or GB BIOS
MEM_VRAM            .EQU 0xD000 ; Video RAM: "ASCII" characters
MEM_VRAM_ATTR       .EQU 0xD800 ; Video RAM: Attributes

MEM_BIOS_MAXLEN     .EQU 0x1000 ; maximum length of BIOS
MEM_CARTWIN_MAXLEN  .EQU 0x1000 ; length of cartridge window

; Screen attributes: Single bits
SA_INVERSE          .EQU 0x80
SA_DARK             .EQU 0x40
SA_BG_RED           .EQU 0x20
SA_BG_GREEN         .EQU 0x10
SA_BG_BLUE          .EQU 0x08
SA_FG_RED           .EQU 0x04
SA_FG_GREEN         .EQU 0x02
SA_FG_BLUE          .EQU 0x01

; Screen attributes: Common bit-combinations
SA_COL_STD          .EQU 0x0B   ; cyan font on blue background
SA_COL_STD_INV      .EQU 0x8B   ; inverse standard
SA_COL_SEL          .EQU 0x0F   ; selection: white font on blue background

; Special characters in font Anikki-16x16
CHR_FC_TL           .EQU 201    ; fat top/left corner
CHR_FC_SH           .EQU 205    ; fat straight horizontal
CHR_FC_TR           .EQU 187    ; fat top/right corner
CHR_FC_SV           .EQU 186    ; fat straight vertical
CHR_FC_BL           .EQU 200    ; fat bottom/left corner
CHR_FC_BR           .EQU 188    ; fat bottom/right corner
CHR_FC_HE_LEFT      .EQU 185    ; fat straight horiz. line ends: left part
CHR_FC_HE_RIGHT     .EQU 204    ; fat straight horiz. line ends: right part
CHR_NC_SH           .EQU 196    ; normal straight horizontal
CHR_NC_VE_LEFT      .EQU 199    ; normal vertical line end: left part
CHR_NC_VE_RIGHT     .EQU 182    ; normal vertical line end: right part
CHR_DIR_L           .EQU 17     ; left char for displaying a directory
CHR_DIR_R           .EQU 16     ; right char for displaying a directory
CHR_OPT_SEL         .EQU 7      ; selection char for options menu

