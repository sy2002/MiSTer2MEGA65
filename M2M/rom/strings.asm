; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Hardcoded Shell strings that cannot be changed by config.vhd
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

STR_SD          .ASCII_W "\n Currently used SD card: "

; ----------------------------------------------------------------------------
; Debug Mode (Run/Stop + Help + Cursor Up)
; ----------------------------------------------------------------------------

DBG_START1		.ASCII_P "Entering MiSTer2MEGA65 debug mode.\nPress H for "
				.ASCII_W "help and press C R "
DBG_START2 		.ASCII_W " to return to the Shell.\n"
