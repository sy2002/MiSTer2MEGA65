; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; General Configuration handling of the core
;
; The behavior can be configured in config.vhd; see also the documentation
; written there. The file gencfg.asm needs the environment of shell.asm.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Reset / Pause handling of the core
; ----------------------------------------------------------------------------

; Meant to be executed when the Shell firmware starts:
; Check, if the core is meant to be put in reset and/or pause and if a certain
; amount of cycles shall be wasted while the system stays in reset
RP_SYSTEM_START INCRB

                MOVE    M2M$RAMROM_DEV, R0      ; select config.vhd device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; choose Reset/Pause handling
                MOVE    M2M$CFG_GENERAL, @R0

                ; The QNICE CSR is in a sophisticated state when we arrive
                ; here, and the core is in RESET state.
                ; (See also CSR_DEFAULT in M2M/vhdl/QNICE/qnice.vhd)

                ; handle keyboard and joystick settings
                MOVE    M2M$CFG_RP_KB_RST, R1
                CMP     0, @R1
                RBRA    _RP_JK_1, Z
                OR      M2M$CSR_KBD, @R7        ; keyoard on
_RP_JK_1        MOVE    M2M$CFG_RP_J1_RST, R1
                CMP     0, @R1
                RBRA    _RP_JK_2, Z
                OR      M2M$CSR_JOY1, @R7       ; joystick 1 on
_RP_JK_2        MOVE    M2M$CFG_RP_J2_RST, R1
                CMP     0, @R1
                RBRA    _RP_JK_3, Z
                OR      M2M$CSR_JOY2, @R7       ; joystick 2 on

                ; wait a certain amount of QNICE loops while keeping reset on
_RP_JK_3        MOVE    M2M$CFG_RP_COUNTER, R1
                MOVE    @R1, R1
                RBRA    _RP_SS_2, Z             ; counter is zero: skip

                XOR     R2, R2
_RP_SS_1_LOOP   CMP     R1, R2                  ; done?
                RBRA    _RP_SS_2, Z             ; yes
                ADD     1, R2
                RBRA    _RP_SS_1_LOOP, 1

_RP_SS_2        AND     M2M$CSR_UN_RESET, @R7   ; delete reset state

                RSUB    ASCAL_INIT, 1           ; handle ascal configuration
                DECRB
                RET

; Returns Carry flag = 1, if the welcome screen shall be shown
RP_WELCOME      INCRB

                MOVE    M2M$RAMROM_DEV, R0      ; select config.vhd device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; choose Reset/Pause handling
                MOVE    M2M$CFG_GENERAL, @R0

                ; Show welcome screen at all?
                MOVE    M2M$CFG_RP_WELCOME, R1
                CMP     0, @R1
                RBRA    _RPW_C0, Z              ; no

                ; Handle welcome screen after reset:
                ; "if (not M2M$CFG_RP_WLCM_RST) and WELCOME_SHOWN then skip"
                MOVE    WELCOME_SHOWN, R2                
                MOVE    M2M$CFG_RP_WLCM_RST, R1 ; welcm. scr. after reset?
                MOVE    @R1, R1
                RBRA    _RPW_SHOW, !Z           ; not zero means: show always

                ; do not show if already shown
                CMP     1, @R2
                RBRA    _RPW_C0, Z

                ; Show welcome screen
_RPW_SHOW       MOVE    1, @R2                  ; remember shown
                RBRA    _RPW_C1, 1

_RPW_C0         AND     0xFFFB, SR              ; clear Carry
                RBRA    _RPW_RET, 1

_RPW_C1         OR      0x0004, SR              ; set Carry

_RPW_RET        DECRB
                RET

; If configured in config.vhd, deactivate keyboard and joysticks when
; entering the Options/Help menu
RP_OPTM_START   INCRB

                MOVE    M2M$RAMROM_DEV, R0      ; select config.vhd device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; choose Reset/Pause handling
                MOVE    M2M$CFG_GENERAL, @R0

                ; Pause state, keyboard and joysticks are OFF by default
                MOVE    M2M$CSR, R7
                AND     M2M$CSR_UN_PAUSE, @R7
                AND     M2M$CSR_UN_KBD, @R7
                AND     M2M$CSR_UN_JOY1, @R7
                AND     M2M$CSR_UN_JOY2, @R7

                ; activate on demand
                MOVE    M2M$CFG_RP_KB_OSD, R1
                CMP     0, @R1
                RBRA    _RP_OS_1, Z
                OR      M2M$CSR_KBD, @R7        ; keyoard on
_RP_OS_1        MOVE    M2M$CFG_RP_J1_OSD, R1
                CMP     0, @R1
                RBRA    _RP_OS_2, Z
                OR      M2M$CSR_JOY1, @R7       ; joystick 1 on
_RP_OS_2        MOVE    M2M$CFG_RP_J2_OSD, R1
                CMP     0, @R1
                RBRA    _RP_OS_3, Z
                OR      M2M$CSR_JOY2, @R7       ; joystick 2 on
_RP_OS_3        MOVE    M2M$CFG_RP_PAUSE, R1
                CMP     0, @R1
                RBRA    _RP_OS_4, Z
                OR      M2M$CSR_PAUSE, @R7      ; Pause state of the core     

_RP_OS_4        DECRB
                RET

; ----------------------------------------------------------------------------
; Ascal handling
; ----------------------------------------------------------------------------

; extract config settings and execute them
ASCAL_INIT      INCRB

                ; Transfer CRT emulation polyphase filter coefficients from
                ; the QNICE ROM to the ascal RAM
                RSUB    LOAD_ASCAL_FLT, 1

                ; get ascal handling from config and execute it            
                MOVE    M2M$RAMROM_DEV, R0      ; select config.vhd device
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; choose ascal handling
                MOVE    M2M$CFG_GENERAL, @R0
   
                ; standard ascal usage is "not auto": save this in CSR and
                ; then extract the usage value from config.vhd
                MOVE    M2M$CSR, R0
                AND     M2M$CSR_UN_ASCAL_AUTO, @R0
                MOVE    M2M$CFG_ASCAL_USAGE, R1
                MOVE    @R1, R1

                CMP     M2M$CFG_AUSE_CFG, R1    ; use value from config.vhd
                RBRA    _ASCAL_INIT_1, !Z
                MOVE    M2M$CFG_ASCAL_MODE, R0
                MOVE    M2M$ASCAL_MODE, R1
                MOVE    @R0, @R1
                RBRA    _ASCAL_INIT_RET, 1

_ASCAL_INIT_1   CMP     M2M$CFG_AUSE_CUSTOM, R1 ; custom = do nothing here
                RBRA    _ASCAL_INIT_RET, Z

                CMP     M2M$CFG_AUSE_AUTO, R1   ; set auto-sync in CSR
                RBRA    _ASCAL_INIT_RET, !Z
                MOVE    M2M$CSR, R0
                OR      M2M$CSR_ASCAL_AUTO, @R0

_ASCAL_INIT_RET DECRB
                RET
