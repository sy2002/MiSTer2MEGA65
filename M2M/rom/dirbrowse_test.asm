; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Directory Browser: Test program and development testbed
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

#include "../../M2M/QNICE/dist_kit/sysdef.asm"
#include "../../M2M/QNICE/dist_kit/monitor.def"

                .ORG    0x8000                  ; start at 0x8000

                MOVE    TITLE_STR, R8           ; output title string
                SYSCALL(puts, 1)

                ; mount sd card
                MOVE    SD_DEVHANDLE, R8        ; reset device handle
                MOVE    0, @R8
                MOVE    1, R9                   ; partition 1
                SYSCALL(f32_mnt_sd, 1)          ; mount SD card
                CMP     0, R9                   ; mounting worked?
                RBRA    MOUNT_OK, Z             ; yes: continue
                MOVE    ERR_MNT_STR, R8
                SYSCALL(puts, 1)
                MOVE    R9, R8                  ; print error code
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                RBRA    END, 1                  ; end program

MOUNT_OK        MOVE    STARTPATH_STR, R8       ; user enters start path
                SYSCALL(puts, 1)
                MOVE    INPUTBUFFER, R8
                MOVE    INPUTBUF_SIZE, R9
                SYSCALL(gets_s, 1)
                SYSCALL(crlf, 1)

                ; load sorted directory list into memory
                MOVE    R8, R9                  ; start path
                MOVE    HEAP, R10               ; start address of heap   
                MOVE    HEAP_SIZE, R11          ; maximum memory available
                                                ; for storing the linked list
                MOVE    SD_DEVHANDLE, R8        ; pointer to device handle
                RSUB    DIRBROWSE_READ, 1       ; read directory content
                CMP     0, R11                  ; errors?
                RBRA    LOAD_OK, Z              ; no
                CMP     1, R11                  ; error: path not found
                RBRA    ERR_PNF, Z
                CMP     2, R11                  ; max files? (only warn)
                RBRA    WRN_MAX, Z
                RBRA    ERR_UNKNOWN, 1

                ; Output sorted directory listing
LOAD_OK         MOVE    R10, R0
                ADD     SLL$NEXT, R0                
                MOVE    R10, R1
                ADD     SLL$DATA, R1
                MOVE    R1, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                CMP     0, @R0
                RBRA    END, Z
                MOVE    @R0, R10
                RBRA    LOAD_OK, 1

END             SYSCALL(exit, 1)

WRN_MAX         MOVE    WRN_MAX_STR, R8
                SYSCALL(puts, 1)
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                RBRA    LOAD_OK, 1

ERR_PNF         MOVE    ERR_PATH_STR, R8
                SYSCALL(puts, 1)
                MOVE    INPUTBUFFER, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                RBRA    END, 1

ERR_UNKNOWN     MOVE    ERR_PATH_STR, R8
                SYSCALL(puts, 1)
                RBRA    END, 1                

; ----------------------------------------------------------------------------
; Strings
; ----------------------------------------------------------------------------

TITLE_STR       .ASCII_W "Directory Browser Development Testbed done by sy2002 in February 2021\n\n"
STARTPATH_STR   .ASCII_W "Enter start path: "
ERR_MNT_STR     .ASCII_W "Error mounting device: SD Card. Error code: "
ERR_PATH_STR    .ASCII_W "Path not found: "
ERR_UNKNOWN_STR .ASCII_W "Unknown error.\n"
WRN_MAX_STR     .ASCII_W "Warning: More files in this path than memory permits.\nAmount of read file names (in hex): "

; ----------------------------------------------------------------------------
; Variables 
; ----------------------------------------------------------------------------

INPUTBUFFER    .BLOCK  161
INPUTBUF_SIZE  .EQU 161
SD_DEVHANDLE   .BLOCK  FAT32$DEV_STRUCT_SIZE   ; SD card device handle

; ----------------------------------------------------------------------------
; Directory browser including heap for storing the sorted structure
; ----------------------------------------------------------------------------

#include "dirbrowse.asm"

HEAP_SIZE      .EQU 4096        
HEAP           .BLOCK 1
