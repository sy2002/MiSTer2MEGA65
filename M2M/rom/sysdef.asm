; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; System definition file for registers and MMIO
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Control and status register
; ----------------------------------------------------------------------------

M2M$CSR                 .EQU 0xFFE0
    ; Bit       0: Reset the MiSTer core
    ; Bit       1: Pause the MiSTer core
    ; Bit       2: Show On-Screen-Menu (OSM) as an overlay over core output
    ; Bit       3: Keyboard connection between M65 keyb. and the core
    ; Bit       4: Joy. port 1 connection between M65 joy. port and core
    ; Bit       5: Joy. port 2 connection between M65 joy. port and core
    ; Bit       6: SD Card: Mode: 0=Auto: SD card automatically switches
    ;             between the internal card (bottom tray) and the external
    ;             card (back slot). The external card has higher precedence.
    ; Bit       7: SD Card: If Mode=1: 0=force internal / 1=force external
    ; Bit       8: SD Card: Currently active: 0=internal / 1=external
    ; Bit       9: SD Card: Internal SD card detected
    ; Bit      10: SD Card: External SD card detected
    ; Bit      11: Ascal autoset: If set to 1: M2M$ASCAL_MODE (which is
    ;              controlling QNICE ouput port ascal_mode_o) is automatically
    ;              kept in sync with ascal_mode_i
    ; Bits 12..15: RESERVED
    ;
    ; Bits 8, 9, 10 are read-only

M2M$CSR_RESET           .EQU 0x0001
M2M$CSR_UN_RESET        .EQU 0xFFFE
M2M$CSR_PAUSE           .EQU 0x0002
M2M$CSR_UN_PAUSE        .EQU 0xFFFD
M2M$CSR_OSM             .EQU 0x0004
M2M$CSR_UN_OSM          .EQU 0xFFFB
M2M$CSR_KBD             .EQU 0x0008
M2M$CSR_UN_KBD          .EQU 0xFFF7
M2M$CSR_JOY1            .EQU 0x0010
M2M$CSR_UN_JOY1         .EQU 0xFFEF
M2M$CSR_JOY2            .EQU 0x0020
M2M$CSR_UN_JOY2         .EQU 0xFFDF
M2M$CSR_SD_MODE         .EQU 0x0040
M2M$CSR_UN_SD_MODE      .EQU 0xFFBF
M2M$CSR_SD_FORCE        .EQU 0x0080
M2M$CSR_UN_SD_FORCE     .EQU 0xFF7F
M2M$CSR_SD_ACTIVE       .EQU 0x0100
M2M$CSR_UN_SD_ACTIVE    .EQU 0xFEFF
M2M$CSR_SD_DET_INT      .EQU 0x0200
M2M$CSR_UN_SD_DET_INT   .EQU 0xFDFF
M2M$CSR_SD_DET_EXT      .EQU 0x0400
M2M$CSR_UN_SD_DET_EXT   .EQU 0xFBFF
M2M$CSR_ASCAL_AUTO      .EQU 0x0800
M2M$CSR_UN_ASCAL_AUTO   .EQU 0xF7FF

M2M$CSR_KBD_JOY         .EQU 0x0038
M2M$CSR_UN_KBD_JOY      .EQU 0xFFC7

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

; Screen attributes: Single bits
M2M$SA_INVERSE      .EQU 0x80
M2M$SA_DARK         .EQU 0x40
M2M$SA_BG_RED       .EQU 0x20
M2M$SA_BG_GREEN     .EQU 0x10
M2M$SA_BG_BLUE      .EQU 0x08
M2M$SA_FG_RED       .EQU 0x04
M2M$SA_FG_GREEN     .EQU 0x02
M2M$SA_FG_BLUE      .EQU 0x01

; Screen attributes: Common bit-combinations
M2M$SA_COL_STD      .EQU 0x0B   ; cyan font on blue background
M2M$SA_COL_STD_INV  .EQU 0x8B   ; inverse standard
M2M$SA_COL_TTLE     .EQU 0x0E   ; Title: Yellow on blue background
M2M$SA_COL_TTLE_INV .EQU 0x8E   ; inverse Title
M2M$SA_COL_SEL      .EQU 0x0F   ; selection: white font on blue background

; Special characters in font Anikki-16x16
M2M$FC_TL           .EQU 201    ; fat top/left corner
M2M$FC_SH           .EQU 205    ; fat straight horizontal
M2M$FC_TR           .EQU 187    ; fat top/right corner
M2M$FC_SV           .EQU 186    ; fat straight vertical
M2M$FC_BL           .EQU 200    ; fat bottom/left corner
M2M$FC_BR           .EQU 188    ; fat bottom/right corner
M2M$FC_HE_LEFT      .EQU 185    ; fat straight horiz. line ends: left part
M2M$FC_HE_RIGHT     .EQU 204    ; fat straight horiz. line ends: right part
M2M$NC_SH           .EQU 196    ; normal straight horizontal
M2M$NC_VE_LEFT      .EQU 199    ; normal vertical line end: left part
M2M$NC_VE_RIGHT     .EQU 182    ; normal vertical line end: right part
M2M$DIR_L           .EQU 17     ; left char for displaying a directory
M2M$DIR_R           .EQU 16     ; right char for displaying a directory
M2M$OPT_SEL_MULTI   .EQU 7      ; selection char for options menu: multi-sel.
M2M$OPT_SEL_SINGLE  .EQU 61     ; ditto for single select
M2M$LD_PROGRESS     .EQU 254    ; character used for progress bar
M2M$LD_SPACE        .EQU 32     ; space character

; ----------------------------------------------------------------------------
; HDMI: Avalon Scaler (ascal.vhd)
; ----------------------------------------------------------------------------

M2M$ASCAL_MODE      .EQU 0xFFE3 ; ascal mode register
                                ; this reg. is read-only if CSR bit 11 = 1

; ascal mode: bits 2 downto 0
M2M$ASCAL_NEAREST   .EQU 0x0000 ; Nearest neighbor
M2M$ASCAL_BILINEAR  .EQU 0x0001 ; Bilinear
M2M$ASCAL_SBILINEAR .EQU 0x0002 ; Sharp Bilinear
M2M$ASCAL_BICUBIC   .EQU 0x0003 ; Bicubic
M2M$ASCAL_POLYPHASE .EQU 0x0004 ; Polyphase filter (used for CRT emulation)

; ascal Polyphase addresses
M2M$ASCAL_PP_HORIZ  .EQU 0x0000
M2M$ASCAL_PP_VERT   .EQU 0x0100

; ascal mode: bits 3 and 4
M2M$ASCAL_TRIPLEBUF .EQU 0x0008 ; Activate triple-buffering
M2M$ASCAL_RESERVED  .EQU 0x0010 ; reserved (see ascal.vhd)

; ----------------------------------------------------------------------------
; Special-purpose and general-purpose 16-bit input flags
; Read-only; direct pass through from SOC inputs, not buffered in a register.
; (Currently reserved and not used, yet)
; ----------------------------------------------------------------------------

; special-purpose register that gets its semantics via the Shell firmware
M2M$SPECIAL         .EQU 0xFFE4

; general-purpose register, can be freely used and is not used by the Shell
M2M$GENERAL         .EQU 0xFFE5

; ----------------------------------------------------------------------------
; Keyboard for the framework (independent from the keyboard of the core)
; ----------------------------------------------------------------------------

; Low active realtime snapshot of the currently pressed keys (read-only)
; (MMIO "qnice_keys_o" register of m2m_keys.vhd)
M2M$KEYBOARD        .EQU 0xFFE8

; Typematic delay (DLY) and typematic repeat (SPD)
; DLY: How long needs the key to be pressed, until the typematic repeat starts
; SPD: How fast will the pressed key be repeated
; IMPORTANT: These values are empiric and relative to QNICE V1.61
M2M$TYPEMATIC_DLY   .EQU 0x8000             ; ~0.5sec in QNICE V1.61
M2M$TYPEMATIC_SPD   .EQU 0x1000             ; ~12 per sec

; Definition of the bits in M2M$KEYBOARD
M2M$KEY_UP          .EQU 0x0001
M2M$KEY_DOWN        .EQU 0x0002
M2M$KEY_LEFT        .EQU 0x0004
M2M$KEY_RIGHT       .EQU 0x0008
M2M$KEY_RETURN      .EQU 0x0010
M2M$KEY_SPACE       .EQU 0x0020
M2M$KEY_RUNSTOP     .EQU 0x0040
M2M$KEY_HELP        .EQU 0x0080
M2M$KEY_F1          .EQU 0x0100
M2M$KEY_F3          .EQU 0x0200

; ----------------------------------------------------------------------------
; 256-bit General purpose control flags
; ----------------------------------------------------------------------------

; 256-bit directly controled by the programmer (not used by the Shell)
; Select a window between 0 and 15 in M2M$CFD_ADDR and access the control
; flags sliced into 16-bit chunks via M2M$CFD_DATA
; exposed by QNICE via control_d_o
M2M$CFD_ADDR        .EQU 0xFFF0
M2M$CFD_DATA        .EQU 0xFFF1

; 256-bit controled by the Shell via the options menu, i.e. the menu that
; opens when the core is running and the user presses "Help" on the keyboard:
; the bit order is: bit 0 = topmost menu entry, the mapping is 1-to-1 to
; OPTM_ITEMS / OPTM_GROUPS in config.vhd
; exposed by QNICE via control_m_o; M2M$CFM_ADDR runs from 0 to 15
M2M$CFM_ADDR        .EQU 0xFFF2
M2M$CFM_DATA        .EQU 0xFFF3

; ----------------------------------------------------------------------------
; MMIO 4k-segmented access to RAMs, ROMs and similarily behaving devices
; ----------------------------------------------------------------------------

M2M$RAMROM_DEV      .EQU 0xFFF4
    ; Devices 0x0000 .. 0x00FF:   RESERVED (see below)
    ; Devices 0x0100 .. 0xFFFF:   Free to be used for any RAM, ROM or device
    ;                             that behaves like a RAM or ROM from the
    ;                             perspective of QNICE

M2M$VRAM_DATA       .EQU 0x0000     ; Device for VRAM: Data
M2M$VRAM_ATTR       .EQU 0x0001     ; Device for VRAM: Attributes
M2M$CONFIG          .EQU 0x0002     ; Static Shell config data (config.vhd)
M2M$ASCAL_PPHASE    .EQU 0x0003     ; ascal.vhd Polyphase filter RAM
M2M$HYPERRAM        .EQU 0x0004     ; Device for the built-in 8MB of HyperRAM
M2M$SDRAM           .EQU 0x0005     ; @TODO/RESERVED for future R4 boards 

M2M$SYS_INFO        .EQU 0x00FF     ; Device for System Info

M2M$RAMROM_4KWIN    .EQU 0xFFF5     ; 4k window selector
M2M$RAMROM_DATA     .EQU 0x7000     ; 4k MMIO window to read/write

; ----------------------------------------------------------------------------
; Sysinfo device: Selectors and addresses
; ----------------------------------------------------------------------------

; Selectors (4k windows)
M2M$SYS_VDRIVES     .EQU 0x0000     ; vdrives constants (globals.vhd)
M2M$SYS_VGA         .EQU 0x0010     ; gfx adaptor 0: VGA
M2M$SYS_HDMI        .EQU 0x0011     ; gfx adaptor 1: HDMI
M2M$SYS_CRTSANDROMS .EQU 0x0020     ; sim. CRTs. & ROMs (globals.vhd)
M2M$SYS_CORE        .EQU 0x0030     ; info about the MiSTer core

; The following read-only registers are meant to be used by the QNICE
; firmware. They enable the ability to specify the hardware screen resolution
; in characters as well as the start coordinates and size of the main screen.
; The position and size of the option menu is deducted.
M2M$SYS_DXDY        .EQU 0x7000
M2M$SHELL_M_XY      .EQU 0x7001     ; main screen: x|y start coordinates
M2M$SHELL_M_DXDY    .EQU 0x7002     ; main screen: dx|dy width and height

; M2M$SYS_CORE registers: measurement from ASCAL
M2M$SYS_CORE_X      .EQU 0x7000     ; visible dx measurement from ASCAL
M2M$SYS_CORE_Y      .EQU 0x7001     ; visible dy measurement from ASCAL

; M2M$SYS_CORE registers: measurement from M2M component
M2M$SYS_CORE_H_PXLS .EQU 0x7002     ; visible dx
M2M$SYS_CORE_V_PXLS .EQU 0x7003     ; visible dy
M2M$SYS_CORE_H_PLSE .EQU 0x7004     ; horizontal pulse
M2M$SYS_CORE_H_BP   .EQU 0x7005     ; horizontal back porch
M2M$SYS_CORE_H_FP   .EQU 0x7006     ; horizontal front porch
M2M$SYS_CORE_V_PLSE .EQU 0x7007     ; vertical pulse
M2M$SYS_CORE_V_BP   .EQU 0x7008     ; vertical back porch
M2M$SYS_CORE_V_FP   .EQU 0x7009     ; vertical front porch
M2M$SYS_CORE_H_FREQ .EQU 0x700A     ; horizontal frequency in Hz

; ----------------------------------------------------------------------------
; Static Shell configuration data (config.vhd): Selectors and addresses
; ----------------------------------------------------------------------------

; Selectors (4k windows)

M2M$CFG_WHS         .EQU 0x1000     ; Welcome & Help screens
M2M$CFG_DIR_START   .EQU 0x0100     ; Start folder for file browser
M2M$CFG_CFG_FILE    .EQU 0x0101     ; Config file for OSM persistence
M2M$CFG_GENERAL     .EQU 0x0110     ; General configuration settings
M2M$CFG_CORENAME    .EQU 0x0200     ; String: name and version of core

M2M$CFG_OPTM_ITEMS  .EQU 0x0300     ; "Help" menu / Options menu items
M2M$CFG_OPTM_GROUPS .EQU 0x0301     ; Menu groups
M2M$CFG_OPTM_STDSEL .EQU 0x0302     ; Menu items that are selected by default
M2M$CFG_OPTM_LINES  .EQU 0x0303     ; Separator lines
M2M$CFG_OPTM_START  .EQU 0x0304     ; Position of very first cursor pos
M2M$CFG_OPTM_ICOUNT .EQU 0x0305     ; Amount of menu items
M2M$CFG_OPTM_MOUNT  .EQU 0x0306     ; Menu item = mount a drive
M2M$CFG_OPTM_SINGLE .EQU 0x0307     ; Single-select menu item
M2M$CFG_OPTM_MSTR   .EQU 0x0308     ; Mount string to display instead of %s
M2M$CFG_OPTM_DIM    .EQU 0x0309     ; DX and DY of Options/Help menu
M2M$CFG_OPTM_SSTR   .EQU 0x030A     ; Saving string to display instead of %s
M2M$CFG_OPTM_HELP   .EQU 0x0310     ; Menu item = show a help menu
M2M$CFG_OPTM_CRTROM .EQU 0x0311     ; Menu item = manually load CRT/ROM
M2M$CFG_OPTM_CRSTR  .EQU 0x0312     ; CRT/ROM load str. to show instead of %s

; M2M$CFG_WHS

M2M$WHS_PAGES       .EQU 0x7FFF     ; Amount of pages in current WHS element
M2M$WHS_WELCOME     .EQU 0x0000     ; WHS array element: Welcome page
M2M$WHS_HELP_INDEX  .EQU 0x0001     ; WHS array: Help pages start with index 1
M2M$WHS_HELP_NEXT   .EQU 0x0100     ; WHS array element: Next help structure
M2M$WHS_PAGE_NEXT   .EQU 0x0001     ; WHS array element: Next page / prev page

; M2M$CFG_OPTM_DIM: Addresses

M2M$SHELL_O_DX      .EQU 0x7000     ; Width of Help/Options menu
M2M$SHELL_O_DY      .EQU 0x7001     ; Height of Help/Options menu

; M2M$CFG_GENERAL Addresses

M2M$CFG_RP_COUNTER  .EQU 0x7001     ; keep reset for a "QNICE loop while"
M2M$CFG_RP_PAUSE    .EQU 0x7002     ; pause core when any OSD opens
M2M$CFG_RP_WELCOME  .EQU 0x7003     ; show the welcome screen in general
M2M$CFG_RP_WLCM_RST .EQU 0x7004     ; show welcome screen after reset
M2M$CFG_RP_KB_RST   .EQU 0x7005     ; connect the keyboard at reset
M2M$CFG_RP_J1_RST   .EQU 0x7006     ; connect the joystick 1 at reset
M2M$CFG_RP_J2_RST   .EQU 0x7007     ; connect the joystick 2 at reset
M2M$CFG_RP_KB_OSD   .EQU 0x7008     ; connect the keyboard at OSD
M2M$CFG_RP_J1_OSD   .EQU 0x7009     ; connect the joystick 1 at OSD
M2M$CFG_RP_J2_OSD   .EQU 0x700A     ; connect the joystick 2 at OSD

M2M$CFG_ASCAL_USAGE .EQU 0x700B     ; firmware treatment of ascal mode
M2M$CFG_ASCAL_MODE  .EQU 0x700C     ; hardcoded ascal mode, if applicable

M2M$CFG_VD_AT_DELAY .EQU 0x700D     ; Anti-Thrashing delay (virtual drives)
M2M$CFG_VD_ITERSIZE .EQU 0x700E     ; Bytes that are saving per flushing-iter.

M2M$CFG_SAVEOSDCFG  .EQU 0x700F     ; Remember on-screen-menu settings

; M2M$CFG_ASCAL_USAGE modes
M2M$CFG_AUSE_CFG    .EQU 0x0000     ; use ASCAL_MODE from config.vhd
M2M$CFG_AUSE_CUSTOM .EQU 0x0001     ; controlled via custom QNICE assembly
M2M$CFG_AUSE_AUTO   .EQU 0x0002     ; auto-sync via M2M$CFG_ASCAL_USAGE

; ----------------------------------------------------------------------------
; Virtual Drives Device for MiSTer "SD" interface (vdrives.vhd)
; ----------------------------------------------------------------------------

; sysinfo addresses (data is configured by the user in globals.vhd)
VD_NUM              .EQU 0x7000     ; amount of virtual drives
VD_DEVICE           .EQU 0x7001     ; address of the vdrives.vhd device
VD_RAM_BUFFERS      .EQU 0x7100     ; array of RAM buffers to store dsk images

; window selectors for vdrives.vhd
VD_WIN_CAD          .EQU 0x0000     ; control and data registers
VD_WIN_DRV          .EQU 0x0001     ; drive 0, next window = drive 1, ...

; VD_WIN_CAD: control and data registers
VD_IMG_MOUNT        .EQU 0x7000     ; image mounted, lowest bit = drive 0
VD_RO               .EQU 0x7001     ; read-only for currently mounted drive
VD_SIZE_L           .EQU 0x7002     ; image file size, low word
VD_SIZE_H           .EQU 0x7003     ; image file size, high word
VD_TYPE             .EQU 0x7004     ; image file type (2-bit value)
VD_B_ADDR           .EQU 0x7005     ; drive buffer: address
VD_B_DOUT           .EQU 0x7006     ; drive buffer: data out (to drive)
VD_B_WREN           .EQU 0x7007     ; drive buffer: write enable (also needs ack)
VD_VDNUM            .EQU 0x7008     ; number of virtual drives
VD_BLKSZ            .EQU 0x7009     ; block size for LBA in bytes
VD_DRV_MOUNT        .EQU 0x700A     ; drive mounted, lowest bit = drive 0

; VD_WIN_DRV (and onwards): virtual drive specific registers
VD_LBA_L            .EQU 0x7000     ; SD LBA low word
VD_LBA_H            .EQU 0x7001     ; SD LBA high word
VD_BLKCNT           .EQU 0x7002     ; SD block count
VD_BYTES_L          .EQU 0x7003     ; SD block address in bytes: low word
VD_BYTES_H          .EQU 0x7004     ; SD block address in bytes: high word
VD_SIZEB            .EQU 0x7005     ; SD block data amount in bytes
VD_4K_WIN           .EQU 0x7006     ; SD block address in 4k win logic: window
VD_4K_OFFS          .EQU 0x7007     ; SD block address in 4k win logic: offset
VD_RD               .EQU 0x7008     ; SD read request
VD_WR               .EQU 0x7009     ; SD write request
VD_ACK              .EQU 0x700A     ; SD acknowledge
VD_B_DIN            .EQU 0x700B     ; drive buffer: data in (from drive)
VD_CACHE_DIRTY      .EQU 0x700C     ; cache dirty flag
VD_CACHE_FLUSHING   .EQU 0x700D     ; cache flushing flag
VD_CACHE_FLUSH_ST   .EQU 0x700E     ; cache flushing can start now
VD_CACHE_FLUSH_DE   .EQU 0x700F     ; delay in ms between VD_WR and FLUSH_ST

; ----------------------------------------------------------------------------
; Automatically and manually loadable cartridges and ROMs
; ----------------------------------------------------------------------------

; sysinfo addresses (data is configured by the user in globals.vhd)
CRTROM_MAN_NUM_A    .EQU 0x7000     ; amount of manually loadable CRTs/ROMs
CRTROM_AUT_NUM_A    .EQU 0x7001     ; amount of automatically loadable ROMs
CRTROM_MAN_BUFFERS  .EQU 0x7100     ; array of records: manually loadable
CRTROM_AUT_BUFFERS  .EQU 0x7200     ; array of records: automatically loadable
CRTROM_AUT_FILES    .EQU 0x7300     ; auto-load filesnames

; Type of byte streaming device for receiving the CRT/ROM data
CRTROM_TYPE_DEVICE  .EQU 0x0000     ; any QNICE compatible device
CRTROM_TYPE_HYPRAM  .EQU 0x0001     ; HyperRAM
CRTROM_TYPE_SDRAM   .EQU 0x0002     ; @TODO/RESERVED for future R4 boards
CRTROM_TYPE_MNDTRY  .EQU 0x0003     ; mandatory ROM
CTRROM_TYPE_OPTNL   .EQU 0x0004     ; optional ROM

; Control and status registers of a CRT/ROM device
CRTROM_CSR_4KWIN    .EQU 0xFFFF     ; 4K window in the device addr. space
   
CRTROM_CSR_STATUS   .EQU 0x7000     ; QNICE to device: load status (see below)
CRTROM_CSR_FS_LO    .EQU 0x7001     ; filesize of CRT/ROM: low word
CRTROM_CSR_FS_HI    .EQU 0x7002     ; filesize of CRT/ROM: high word
CRTROM_CSR_PARSEST  .EQU 0x7010     ; device to QNICE: parse status
CRTROM_CSR_PARSEE1  .EQU 0x7011     ; device to QNICE: error code
CRTROM_CSR_ADDR_LO  .EQU 0x7012     ; device to QNICE: load address low word
CRTROM_CSR_ADDR_HI  .EQU 0x7013     ; device to QNICE: load address high word
CRTROM_CSR_ERR_STRT .EQU 0x7100     ; device to QNICE: status string

; QNICE to device: CRT/ROM load status
CRTROM_CSR_ST_IDLE  .EQU 0x0000     ; device is initialized, no loading
CRTROM_CSR_ST_LDNG  .EQU 0x0001     ; loading takes place
CRTROM_CSR_ST_ERR   .EQU 0x0002     ; loading failed
CRTROM_CSR_ST_OK    .EQU 0x0003     ; loading successful

; Device to QNICE: Parsing status
CRTROM_CSR_PT_IDLE  .EQU 0x0000     ; parser is idle
CRTROM_CSR_PT_PRSNG .EQU 0x0001     ; parser is parsing
CRTROM_CSR_PT_OK    .EQU 0x0002     ; parsing successful
CRTROM_CSR_PT_ERR   .EQU 0x0003     ; parsing error

; ----------------------------------------------------------------------------
; Situation and context identifiers for custom messages
; ----------------------------------------------------------------------------

CTX_MASK_CTX        .EQU 0xFF00     ; used to mask out the lower byte
CTX_MASK_PARAM      .EQU 0x00FF     ; used to mask out the higher byte

; Trying to mount a disk or a rom image. The lower byte contains the
; core-specific disk or rom image type and core specific code can use this
; to filter for the right types and to output context-sensitive messages
CTX_MOUNT_DISKIMG   .EQU 0x0100     ; trying to mount a disk image
CTX_LOAD_ROM        .EQU 0x0200     ; trying to mount a rom image

; The filter function returned an empty linked list. This happens when there
; is no file that fits the criteria in the root folder and additionally the
; root folder has no sub-directory
CMSG_BROWSENOTHING  .EQU 0x0001
