; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Variables for Keyboard Controller (keyboard.asm): Need to be located in RAM
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in February 2021 and licensed under GPL v3
; ****************************************************************************

; each key represented by one bit in these two words
KEYB_PRESSED    .BLOCK 1                        ; currently pressed
KEYB_NEWKEYS    .BLOCK 1                        ; newly pressed since last..
                                                ; ..call of KEYB_GETKEY

; typematic delay variables (expected to be a consecutive block of for words
; overall starting with KEYB_CDN_DELAY)
KEYB_CDN_DELAY  .BLOCK 1
KEYB_CDN_TRIG   .BLOCK 1
KEYB_CUP_DELAY  .BLOCK 1
KEYB_CUP_TRIG   .BLOCK 1
