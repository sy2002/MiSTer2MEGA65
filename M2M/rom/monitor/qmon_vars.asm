; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; a) QNICE ROM: Modified monitor variable section that does not have a
;    hardcoded .ORG statement
; b) Introduced two new variables: _QMON$SP and _QMON$SR
;
; This solution is not (Q)NICE - so with QNICE V1.7 we should find a more
; elegant solution that works without QNICE Monitor code hacking.
;
; done by sy2002 in 2022 and licensed under GPL v3
; ****************************************************************************

;;=========================================================================================
;; Since the current memory layout has ROM in 0x0000 .. 0x7FFF and RAM in 
;; 0x8000 .. 0xFFFF, we need some space for variables used by the monitor in the upper
;; RAM. 
;;
;; These memory locations are defined in the following and have to be located directly 
;; below the IO-page which itself starts on 0xFF00. So the address after the .ORG
;; directive is crucial and has to be adapted manually since the assembler is (as of
;; now) unable to perform address arithmetic!
;;=========================================================================================
;

VAR$STACK_START         .BLOCK  0x0001                  ; Here comes the stack...
;
;******************************************************************************************
;* Soft Start: Remember original stack and status register
;******************************************************************************************
;
_QMON$SP                .BLOCK  0x0001
_QMON$SR                .BLOCK  0x0001
;
;******************************************************************************************
;* VGA control block
;******************************************************************************************
;
_VGA$X                  .BLOCK  0x0001                  ; Current X coordinate
_VGA$Y                  .BLOCK  0x0001                  ; Current Y coordinate
;
;******************************************************************************************
;* SD Card / FAT32 support
;******************************************************************************************
;
_SD$DEVICEHANDLE        .BLOCK  FAT32$DEV_STRUCT_SIZE   ; sysdef.asm: FAT32$DEV_STRUCT_SIZE
