; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Screen: Manage the OSM screen and print strings
;
; done by sy2002 in 2023 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Read system properties and initialize shortcut-variables
; ----------------------------------------------------------------------------

SCR$INIT        INCRB

                ; @TODO: Right now we only support one "graphics card" for
                ; QNICE, i.e. we use the same kind of screen real-estate on
                ; both: HDMI and VGA. We plan to change this in future. The
                ; hardware already supports it. Right now we ignore the
                ; HDMI settings and use the VGA settings for both.
                MOVE    M2M$RAMROM_DEV, R0      ; sysinfo device
                MOVE    M2M$SYS_INFO, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; select system info window..
                MOVE    M2M$SYS_VGA, @R0        ; .. for VGA graphics 0

                MOVE    M2M$SYS_DXDY, R0        ; save hardware dx
                MOVE    SCR$SYS_DX, R1
                SWAP    @R0, @R1
                AND     0x00FF, @R1
                MOVE    @R1, R2                 ; R2: remember hardware dx

                MOVE    SCR$SYS_DY, R1          ; save hardware dy
                MOVE    @R0, @R1
                AND     0x00FF, @R1

                MOVE    M2M$SHELL_M_XY, R0      ; save main OSM x
                MOVE    SCR$OSM_M_X, R1
                SWAP    @R0, @R1
                AND     0x00FF, @R1

                MOVE    SCR$OSM_M_Y, R1         ; save main OSM y
                MOVE    @R0, @R1
                AND     0x00FF, @R1

                MOVE    M2M$SHELL_M_DXDY, R0    ; save main OSM dx
                MOVE    SCR$OSM_M_DX, R1
                SWAP    @R0, @R1
                AND     0x00FF, @R1

                MOVE    SCR$OSM_M_DY, R1        ; save main OSM dy
                MOVE    @R0, @R1
                AND     0x00FF, @R1

                ; Option/Help menu
                ; the position of the OSM on screen is derived from the
                ; width: We align it at the top/right corner of the screen
                MOVE    M2M$RAMROM_DEV, R0      ; config.vhd device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; "dimenions" selector
                MOVE    M2M$CFG_OPTM_DIM, @R0

                MOVE    M2M$SHELL_O_DX, R0      ; save option/help OSM dx
                MOVE    SCR$OSM_O_DX, R1
                MOVE    @R0, @R1

                MOVE    SCR$OSM_O_X, R3         ; find out OSM x start pos
                SUB     @R1, R2                 ; R2 still contains screen dx
                MOVE    R2, @R3

                MOVE    SCR$OSM_O_Y, R0         ; y start pos = 0
                MOVE    0, @R0

                MOVE    M2M$SHELL_O_DY, R0      ; save option/help OSM dy
                MOVE    SCR$OSM_O_DY, R1
                MOVE    @R0, @R1

                MOVE    SCR$ILX, R0             ; inner left x coordinate
                MOVE    0, @R0

                XOR     R8, R8                  ; init cursor variables
                XOR     R9, R9
                RSUB    SCR$GOTOXY, 1

                DECRB
                RET

; ----------------------------------------------------------------------------
; Show main OSM
; ----------------------------------------------------------------------------

SCR$OSM_M_ON    INCRB

                MOVE    SCR$OSM_M_X, R0
                MOVE    @R0, R0
                SWAP    R0, R0
                MOVE    SCR$OSM_M_Y, R1
                MOVE    @R1, R1
                AND     0x00FF, R1
                OR      R1, R0
                MOVE    M2M$OSM_XY, R1
                MOVE    R0, @R1

                MOVE    SCR$OSM_M_DX, R0
                MOVE    @R0, R0
                SWAP    R0, R0
                MOVE    SCR$OSM_M_DY, R1
                MOVE    @R1, R1
                AND     0x00FF, R1
                OR      R1, R0
                MOVE    M2M$OSM_DXDY, R1
                MOVE    R0, @R1

                MOVE    M2M$CSR, R0             ; activate OSM
                OR      M2M$CSR_OSM, @R0

                DECRB
                RET

; ----------------------------------------------------------------------------
; Show option OSM (aka Help OSM)
; ----------------------------------------------------------------------------

SCR$OSM_O_ON    INCRB

                MOVE    SCR$OSM_O_X, R0
                MOVE    @R0, R0
                SWAP    R0, R0
                MOVE    SCR$OSM_O_Y, R1
                MOVE    @R1, R1
                AND     0x00FF, R1
                OR      R1, R0
                MOVE    M2M$OSM_XY, R1
                MOVE    R0, @R1

                MOVE    SCR$OSM_O_DX, R0
                MOVE    @R0, R0
                SWAP    R0, R0
                MOVE    SCR$OSM_O_DY, R1
                MOVE    @R1, R1
                AND     0x00FF, R1
                OR      R1, R0
                MOVE    M2M$OSM_DXDY, R1
                MOVE    R0, @R1

                MOVE    M2M$CSR, R0             ; activate OSM
                OR      M2M$CSR_OSM, @R0

                DECRB
                RET

; ----------------------------------------------------------------------------
; Hide OSM
; ----------------------------------------------------------------------------

SCR$OSM_OFF     INCRB
                MOVE    M2M$CSR, R0
                AND     M2M$CSR_UN_OSM, @R0
                DECRB
                RET

; ----------------------------------------------------------------------------
; Clear screen (VRAM) by filling it with 0 which is an empty char in our font
; and fill the attribute VRAM with the default foreground/background color
; ----------------------------------------------------------------------------

SCR$CLR         SYSCALL(enter, 1)

                MOVE    M2M$RAMROM_4KWIN, R0    ; 4k window selector = 0
                MOVE    0, @R0

                MOVE    M2M$RAMROM_DEV, R0      ; device selector
                MOVE    M2M$RAMROM_DATA, R1     ; 4k MMIO window

                MOVE    SCR$SYS_DX, R8          ; calculate fill amount
                MOVE    @R8, R8
                MOVE    SCR$SYS_DY, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)
                MOVE    R10, R2

_SCR$CLR_L      MOVE    M2M$VRAM_DATA, @R0      ; VRAM: data
                MOVE    0, @R1                  ; 0 = CLR = space character
                MOVE    M2M$VRAM_ATTR, @R0      ; VRAM: attributes
                MOVE    M2M$SA_COL_STD, @R1++   ; foreground/backgr. color
                SUB     1, R2
                RBRA    _SCR$CLR_L, !Z

                ; reset internal cursor and left margin
                MOVE    SCR$CUR_X, R0
                MOVE    0, @R0
                MOVE    SCR$CUR_Y, R0
                MOVE    0, @R0             
                MOVE    SCR$ILX, R0
                MOVE    0, @R0

                SYSCALL(leave, 1)
                RET

; clear inner part of the screen (leave the frame)
SCR$CLRINNER    INCRB

                MOVE    M2M$RAMROM_4KWIN, R0    ; 4k window selector = 0
                MOVE    0, @R0

                MOVE    M2M$RAMROM_DEV, R0      ; device selector
                MOVE    M2M$RAMROM_DATA, R1     ; 4k MMIO window

                MOVE    SCR$OSM_M_DX, R2        ; width = DX minus 2 (frame)
                MOVE    @R2, R2
                SUB     2, R2
                MOVE    SCR$OSM_M_DY, R3        ; height = DY minus 2 (frame)
                MOVE    @R3, R3
                SUB     2, R3

                ; start address = DX + 1, because we need to skip the frame
                MOVE    SCR$OSM_M_DX, R4
                MOVE    @R4, R4
                ADD     1, R4
                ADD     R4, R1

_SCR$CLRINNER1  MOVE    R2, R4
_SCR$CLRINNER2  MOVE    M2M$VRAM_DATA, @R0      ; VRAM: data
                MOVE    0, @R1                  ; 0 = CLR = space character
                MOVE    M2M$VRAM_ATTR, @R0      ; VRAM: attributes
                MOVE    M2M$SA_COL_STD, @R1++
                SUB     1, R4
                RBRA    _SCR$CLRINNER2, !Z
                ADD     2, R1
                SUB     1, R3
                RBRA    _SCR$CLRINNER1, !Z
                
                ; move cursor to the upper/left inner area of the frame
                MOVE    SCR$CUR_X, R0
                MOVE    1, @R0
                MOVE    SCR$CUR_Y, R0
                MOVE    1, @R0

                DECRB
                RET

; ----------------------------------------------------------------------------
; Move the internal cursor (the cursor variables) to x|y = R8|R9
; ----------------------------------------------------------------------------

SCR$GOTOXY      INCRB
                MOVE    SCR$CUR_X, R0
                MOVE    R8, @R0
                MOVE    SCR$CUR_Y, R0
                MOVE    R9, @R0
                DECRB
                RET

; ----------------------------------------------------------------------------
; Calculates the VRAM address for the current cursor pos in CUR_X & CUR_Y
;
; Input:   reads the variables ScCUR_X and SCR$CUR_Y
; Oputput: R8: VRAM address
; ----------------------------------------------------------------------------

SCR$CALC_VRAM   SYSCALL(enter, 1)

                MOVE    SCR$CUR_Y, R8           ; SCR$CUR_Y x SCR$SYS_DX 
                MOVE    @R8, R8
                MOVE    SCR$SYS_DX, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)                ; R10 = R8 x R9
                MOVE    SCR$CUR_X, R8
                MOVE    @R8, R8
                ADD     R10, R8                 ; .. + SCR$CUR_X

                MOVE    R8, @--SP
                SYSCALL(leave, 1)
                MOVE    @SP++, R8               ; R8 = offset
                ADD     M2M$RAMROM_DATA, R8     ; move offset into VRAM space

                RET

; ----------------------------------------------------------------------------
; Print a string at the current cursor position (screen only)
; Respects the left side of the frame by starting at 1 at a new line
;
; Input:  R8: String
; Output: R8 stays unmodified
;
; Special characters inside R8:
; CR/LF (0x000D+0x000A characters) next line
; \n (backslash char and n)        ditto
; <  (less than)                   special character in Anikki-16x16 font
; >  (greater than)                ditto
; ----------------------------------------------------------------------------

SCR$PRINTSTR    SYSCALL(enter, 1)

                MOVE    R8, R0                  ; R0: string to be printed
                MOVE    SCR$CUR_X, R1           ; R1: running x-cursor
                MOVE    SCR$CUR_Y, R2           ; R2: running y-cursor

                RSUB    SCR$CALC_VRAM, 1        ; R8: VRAM addr. of curs. pos.

_PS_L1          MOVE    @R0++, R4               ; read char
                CMP     0x000D, R4              ; is it a CR?
                RBRA    _PS_L2, Z               ; yes: process
                CMP     0x005C, R4              ; is it a backslash?
                RBRA    _PS_L2, Z               ; yes: process
                CMP     '<', R4                 ; replace < by special
                RBRA    _PS_L4, !Z
                MOVE    M2M$DIR_L, R4
                RBRA    _PS_L6, 1
_PS_L4          CMP     '>', R4                 ; replace > by special
                RBRA    _PS_L5, !Z
                MOVE    M2M$DIR_R, R4
                RBRA    _PS_L6, 1
_PS_L5          CMP     0, R4                   ; no: end-of-string?
                RBRA    _PS_RET, Z              ; yes: leave
_PS_L6          RSUB    _PS_PRE, 1              ; no: print char
                MOVE    R4, @R8++
                RSUB    _PS_POST, 1
                ADD     1, @R1                  ; x-cursor + 1
                RBRA    _PS_L1, 1               ; next char

_PS_L2          MOVE    R4, R7                  ; remember original char
                MOVE    @R0++, R5               ; next char
                CMP     0x000A, R5              ; is it a LF?
                RBRA    _PS_L3, Z               ; yes: process
                CMP     'n', R5                 ; is it a n after a \?
                RBRA    _PS_L3, Z               ; yes: process
                RSUB    _PS_PRE, 1              ; no: print original chars
                MOVE    R7, @R8++               
                MOVE    R5, @R8++
                RSUB    _PS_POST, 1
                RBRA    _PS_L1, 1

_PS_L3          MOVE    SCR$ILX, R12
                MOVE    @R12, @R1               ; inner-left start x-coord
                ADD     1, @R2                  ; new line
                RSUB    SCR$CALC_VRAM, 1
                RBRA    _PS_L1, 1

_PS_RET         SYSCALL(leave, 1)
                RET

; remember any device and selector setting and change it to VRAM; this is
; necessary, because the input string might come from a device
_PS_PRE         INCRB
                MOVE    R8, @--SP
                MOVE    TEMP_2W, R8
                RSUB    SAVE_DEVSEL, 1
                MOVE    @SP++, R8
                MOVE    M2M$RAMROM_DEV, R0      ; switch device to VRAM
                MOVE    M2M$VRAM_DATA, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; window 0
                MOVE    0, @R0
                DECRB
                RET

; restore the original device and selector settings
_PS_POST        INCRB
                MOVE    R8, @--SP
                MOVE    TEMP_2W, R8
                RSUB    RESTORE_DEVSEL, 1
                MOVE    @SP++, R8
                DECRB
                RET

; ----------------------------------------------------------------------------
; Print the string using SCR$PRINTSTR
; Input:  x|y coords in R9|R10
; Output: None; all registers stay unmodified
; ----------------------------------------------------------------------------            

SCR$PRINTSTRXY  INCRB

                MOVE    SCR$CUR_X, R0           ; remember original cursor
                MOVE    @R0, R1
                MOVE    SCR$CUR_Y, R2
                MOVE    @R2, R3

                MOVE    R9, @R0                 ; print at actual position
                MOVE    R10, @R2
                RSUB    SCR$PRINTSTR, 1

                MOVE    R1, @R0                 ; restore original cursor
                MOVE    R3, @R2

                DECRB
                RET

; ----------------------------------------------------------------------------            
; Draws a frame
; Input:  R8/R9:   start x/y coordinates
;         R10/R11: dx/dy sizes, both need to be larger than 3
; Output: None; all registers stay unmodified
; ----------------------------------------------------------------------------

SCR$PRINTFRAME  SYSCALL(enter, 1)

                ; modify global inner left x coordinate for SCR$PRINTSCR
                ; so that \n stays inside the frame
                MOVE    SCR$ILX, R0
                MOVE    R8, @R0
                ADD     1, @R0

                MOVE    M2M$RAMROM_DEV, R0      ; switch device to VRAM
                MOVE    M2M$VRAM_DATA, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; window 0
                MOVE    0, @R0
                
                RSUB    SCR$GOTOXY, 1
                RSUB    SCR$CALC_VRAM, 1

                MOVE    SCR$CUR_X, R0
                MOVE    SCR$CUR_Y, R1
                ADD     1, @R0                  ; first free inner pos for x
                ADD     1, @R1                  ; ditto y

                ; calculate delta to next line in VRAM
                MOVE    R10, R0                 ; R10: dx
                SUB     1, R0
                MOVE    SCR$SYS_DX, R1
                MOVE    @R1, R1
                SUB     R0, R1                  ; R1: delta = cols - (dx - 1)

                ; draw loop for top line
                MOVE    M2M$FC_TL, @R8++        ; draw top/left corner
                MOVE    R10, R0
                SUB     2, R0                   ; net dx
                MOVE    R0, R2
_PF_DL1         MOVE    M2M$FC_SH, @R8++        ; horizontal line
                SUB     1, R2
                RBRA    _PF_DL1, !Z
                MOVE    M2M$FC_TR, @R8          ; draw top/right corner

                ; draw horizontal border
                MOVE    R11, R3
                SUB     2, R3
                MOVE    R3, R2
_PF_DL2         ADD     R1, R8                  ; next line
                MOVE    M2M$FC_SV, @R8++
                ADD     R0, R8                  ; net dx
                MOVE    M2M$FC_SV, @R8
                SUB     1, R2
                RBRA    _PF_DL2, !Z

                ; draw loop for bottom line
                ADD     R1, R8                  ; next line
                MOVE    M2M$FC_BL, @R8++        ; draw bottom/left corner
                MOVE    R0, R2
_PF_DL3         MOVE    M2M$FC_SH, @R8++        ; horizontal line
                SUB     1, R2
                RBRA    _PF_DL3, !Z
                MOVE    M2M$FC_BR, @R8          ; draw bottom/right corner

                SYSCALL(leave, 1)
                RET
