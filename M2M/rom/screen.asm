; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Screen: Manage the OSM screen and print strings
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Activate fullscreen OSM and initialize x|y and dx|dy OSM registers
; and shortcut-variables 
; ----------------------------------------------------------------------------
                
SCR$OSM_FS_ON   INCRB

                MOVE    M2M$CSR, R0             ; activate OSM
                OR      M2M$CSR_OSM_ON, @R0
                MOVE    M2M$OSM_XY, R0          ; take x|y of OSM from ..
                MOVE    M2M$SHELL_M_XY, R1      ; .. VHDL generics
                MOVE    @R1, @R0
                MOVE    M2M$OSM_DXDY, R0        ; take dx|dy of OSM from ..
                MOVE    M2M$SHELL_M_DXDY, R1    ; .. VHDL generics
                MOVE    @R1, @R0

                SWAP    @R1, R0                 ; save DX in shortcut var.
                AND     0x00FF, R0
                MOVE    SCR$OSD_DX, R2
                MOVE    R0, @R2

                MOVE    @R1, R0                 ; save DY in shortcut var.
                AND     0x00FF, R0
                MOVE    SCR$OSD_DY, R2
                MOVE    R0, @R2

                DECRB
                RET

; ----------------------------------------------------------------------------
; Clear screen (VRAM) by filling it with 0 which is an empty char in our font
; and fill the attribute VRAM with the default foreground/background color
; ----------------------------------------------------------------------------

SCR$CLR         RSUB    ENTER, 1

                MOVE    M2M$RAMROM_4KWIN, R0    ; 4k window selector = 0
                MOVE    0, @R0

                MOVE    M2M$RAMROM_DEV, R0      ; device selector
                MOVE    M2M$RAMROM_DATA, R1     ; 4k MMIO window

                MOVE    SCR$OSD_DX, R8          ; calculate fill amount
                MOVE    @R8, R8
                MOVE    SCR$OSD_DY, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)
                MOVE    R10, R2

_SCR$CLR_L      MOVE    M2M$VRAM_DATA, @R0      ; VRAM: data
                MOVE    0, @R1                  ; 0 = CLR = space character
                MOVE    M2M$VRAM_ATTR, @R0      ; VRAM: attributes
                MOVE    M2M$SA_COL_STD, @R1++   ; foreground/backgr. color
                SUB     1, R2
                RBRA    _SCR$CLR_L, !Z

                RSUB    LEAVE, 1
                RET
