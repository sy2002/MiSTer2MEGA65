; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Variables for Directory Browser (dirbrowse.asm): Need to be located in RAM
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in February 2021 and licensed under GPL v3
; ****************************************************************************

_DIRBR_FILTERFN .BLOCK  1                       ; pointer to filter function

_DIRBR_FH       .BLOCK  FAT32$FDH_STRUCT_SIZE   ; file handle
_DIRBR_ENTRY    .BLOCK  FAT32$DE_STRUCT_SIZE    ; directory entry
