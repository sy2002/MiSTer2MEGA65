; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Variables for Directory Browser (dirbrowse.asm): Need to be located in RAM
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

_DIRBR_FILTERFN .BLOCK  1                       ; pointer to filter function

_DIRBR_FH       .BLOCK  FAT32$FDH_STRUCT_SIZE   ; file handle
_DIRBR_ENTRY    .BLOCK  FAT32$DE_STRUCT_SIZE    ; directory entry
