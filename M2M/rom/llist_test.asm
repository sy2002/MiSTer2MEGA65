; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Test program and development testbed for Simple Linked List
;
; done by sy2002 in in February 2021 and licensed under GPL v3
; ****************************************************************************

#include "../../QNICE/dist_kit/sysdef.asm"
#include "../../QNICE/dist_kit/monitor.def"

                .ORG    0x8000                  ; start at 0x8000

                MOVE    TITLE_STR, R8           ; output title string
                SYSCALL(puts, 1)

                MOVE    HEAP_START, R8          ; initialize heap
                MOVE    HEAP_HEAD, R9
                MOVE    R8, @R9

                MOVE    TEST_DATA_START, R0     ; R0: test strs start in mem.
                MOVE    TEST_STR_COUNT, R1      ; R1: amount of test strings
                XOR     R2, R2                  ; R2: head of linked list

                MOVE    UNSORTED_STR, R8        ; output UNSORTED
                RSUB    PRINT_SEPARATOR, 1

                ; create the elements of the sorted linked list on the heap
                ; and use the sorted-insert function to actually create the
                ; sorted linked list
INSERT_LOOP     MOVE    R0, R8                  ; R8: string
                RSUB    NEW_ELM, 1              ; R8: new created elm. on heap

                MOVE    R8, R6                  ; print unsorted output
                ADD     SLL$DATA, R8
                MOVE    @R8, R8
                SYSCALL(puts, 1)                
                SYSCALL(crlf, 1)
                MOVE    R6, R8

                MOVE    R8, R9                  ; R9: newly created heap elm
                MOVE    R2, R8                  ; R8: head of linked list
                MOVE    CMP_FUNC, R10           ; R10: compare function
                XOR     R11, R11                ; R11 = 0: no filter
                ;MOVE    FILTER_FUNC, R11        ; R11: filter function
                RSUB    SLL$S_INSERT, 1         ; linked list sorted insert
                MOVE    R8, R2                  ; new head of linked list

                ADD     TEST_STR_LEN, R0        ; next test string
                SUB     1, R1                   ; one less string to go
                RBRA    INSERT_LOOP, !Z         ; done? no: loop

                MOVE    ASCENDING_STR, R8       ; output SORTED (ASCENDING)
                RSUB    PRINT_SEPARATOR, 1
                MOVE    R2, R7                  ; R7: remember head

                ; print the sorted strings by traversing the linked list
PRINT_LOOP_ASC  MOVE    R2, R0                  ; R2: current element
                MOVE    R2, R1
                ADD     SLL$NEXT, R0
                ADD     SLL$DATA, R1
                MOVE    @R1, R8                 ; print string
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                MOVE    @R0, R0                 ; R0: ptr to next element
                RBRA    DESCENDING, Z           ; end of list! end program                
                MOVE    R0, R2                  ; next element
                RBRA    PRINT_LOOP_ASC, 1

DESCENDING      MOVE    DESCENDING_STR, R8      ; output SORTED (DESCENDING)
                RSUB    PRINT_SEPARATOR, 1

                MOVE    R7, R8                  ; R9: last element of SLL
                RSUB    SLL$LASTNCOUNT, 1
                MOVE    R9, R2

PRINT_LOOP_DESC MOVE    R2, R0                  ; R2: current element
                MOVE    R2, R1
                ADD     SLL$PREV, R0
                ADD     SLL$DATA, R1
                MOVE    @R1, R8                 ; print string
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                MOVE    @R0, R0                 ; R0: ptr to prev. element
                RBRA    END, Z                  ; end of list! end program
                MOVE    R0, R2
                RBRA    PRINT_LOOP_DESC, 1

END             SYSCALL(crlf, 1)
                SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Sorted Linked List
; ----------------------------------------------------------------------------

; always include after an .ORG statement so that the linked list functions
; are located a a proper memory position
#include "llist.asm"

; Create new linked-list element on the heap, manage the heap-head and return
; a pointer to the new element in R8
; Input:
; R8: Pointer to string
; Output;
; R8: Pointer to new linked-list element on the heap
NEW_ELM         INCRB

                MOVE    HEAP_HEAD, R0           ; R0: ptr to element
                MOVE    @R0, R0
                MOVE    R0, R1                  ; set NEXT and PREV to 0
                ADD     SLL$NEXT, R1            ; (deliberately do not assume
                MOVE    0, @R1                  ; any hardcoded memory layout)
                MOVE    R0, R1
                ADD     SLL$PREV, R1
                MOVE    0, @R1
                MOVE    R0, R1                  ; R1: ptr to element data..
                ADD     SLL$DATA_SIZE, R1       ; ..size which is always 1..
                MOVE    1, @R1                  ; ..because we just store a..
                                                ; ..ptr to a string
                MOVE    R0, R2                  ; R2: ptr to string
                ADD     SLL$DATA, R2
                MOVE    R8, @R2                 ; store ptr to string

                MOVE    R0, R8                  ; return ptr to new element

                ADD     SLL$DATA, R0            ; calc new head of heap
                ADD     1, R0                   ; length of data
                MOVE    HEAP_HEAD, R4           ; store new heap head
                MOVE    R0, @R4

                DECRB
                RET

; SLL$S_INSERT compare function that returns negative if (S0 < S1),
; zero if (S0 == S1), positive if (S0 > S1). These semantic are
; basically compatible with STR$CMP, but instead of expecting pointers
; to two strings, this compare function is expecting two pointers to
; SLL records, while the pointer to the first one is given in R8 and
; treated as "S0" and the second one in R9 and treated as "S1".
; Also, this compare function compares case-insensitive.

CMP_FUNC        INCRB
                MOVE    R8, R0 
                MOVE    R9, R1
                INCRB
                MOVE    R8, R0
                MOVE    R9, R1

                ADD     SLL$DATA, R0            ; R0: pointer to first string
                MOVE    @R0, R0

                ; copy R0 to the stack and make it upper case
                MOVE    R0, R8                  ; copy string to stack
                SYSCALL(strlen, 1)
                ADD     1, R9               
                SUB     R9, SP
                MOVE    R9, R4                  ; R4: stack restore amount
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R8
                SYSCALL(str2upper, 1)
                MOVE    R8, R0

                ADD     SLL$DATA, R1            ; R1: pointer to second string
                MOVE    @R1, R1

                ; copy R1 to the stack and make it upper case
                MOVE    R1, R8
                SYSCALL(strlen, 1)
                ADD     1, R9
                SUB     R9, SP
                ADD     R9, R4                  ; R4: update stack rest. amnt.
                MOVE    SP, R9
                SYSCALL(strcpy, 1)
                MOVE    R9, R8
                SYSCALL(str2upper, 1)
                MOVE    R8, R1

                ; case-insensitive comparison
                MOVE    R0, R8
                MOVE    R1, R9                
                SYSCALL(strcmp, 1)

                ADD     R4, SP                  ; restore stack pointer

                DECRB                
                MOVE    R0, R8
                MOVE    R1, R9   
                DECRB
                RET

; SLL$S_INSERT filter function that filters out some values, i.e. does not
; insert them into the linked list. Returns 1 for all values that shall be
; filtered and 0 for all values that are OK.
; R8 contains the element-pointer and R8 is also used as return value, i.e.
; R8 is overwritten.
FILTER_FUNC     INCRB

                ADD     SLL$DATA, R8
                MOVE    @R8, R8

                MOVE    FILTER_1, R9            ; filter string 1
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _FF_RET1, Z

                MOVE    FILTER_2, R9            ; filter string 2
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _FF_RET0, !Z
                
_FF_RET1        MOVE    1, R8
                RBRA    _FF_RET, 1
_FF_RET0        XOR     R8, R8
_FF_RET         DECRB
                RET           

; ----------------------------------------------------------------------------
; User interface
; ----------------------------------------------------------------------------

; print embedded separator
PRINT_SEPARATOR INCRB
                MOVE    R8, R0

                SYSCALL(crlf, 1)
                MOVE    SEPARATOR_STR, R8       
                SYSCALL(puts, 1)
                MOVE    R0, R8
                SYSCALL(puts, 1)
                MOVE    SEPARATOR_STR, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                MOVE    R0, R8
                DECRB
                RET

; user interface strings
TITLE_STR       .ASCII_W "Sorted Linked List Development Testbed done by sy2002 in February 2021\n"
SEPARATOR_STR   .ASCII_W "================================================================================\n"
UNSORTED_STR    .ASCII_W "     UNSORTED\n"
ASCENDING_STR   .ASCII_W "     SORTED IN ASCENDING ORDER: 0..9 then A..Z\n"
DESCENDING_STR  .ASCII_W "     SORTED IN DESCENDING ORDER: Z..A then 9..0\n"

; ----------------------------------------------------------------------------
; Sample strings to be sorted
; ----------------------------------------------------------------------------

FILTER_1        .ASCII_W "ssi4HRhP0dvMK0VTA78D"
FILTER_2        .ASCII_W "co4G5GEQDp06cyTWfsmb"

TEST_STR_LEN    .EQU    21
TEST_STR_COUNT  .EQU    500

TEST_DATA_START .ASCII_W "co4G5GEQDp06cyTWfsmb"
                .ASCII_W "gC0Vovkw4vNhPO5SddFF"
                .ASCII_W "zoRWsLR20iRZGRG4IpCF"
                .ASCII_W "k1S2ya3uJQ8kw8ElyTM8"
                .ASCII_W "ySOJ4I7gxMf1o1mnncYH"
                .ASCII_W "1gkmk18prQ3YG3i5Mhft"
                .ASCII_W "lubqMSCwdUrlvcCTyXVP"
                .ASCII_W "1RS1baxaauNUkhMw2HNA"
                .ASCII_W "9qkghEr8scxpNpkiGDiS"
                .ASCII_W "1OaLxK4qZ01EqLt7W9lb"
                .ASCII_W "ht4HHXANAhd24xH0QN45"
                .ASCII_W "ssi4HRhP0dvMK0VTA78D"
                .ASCII_W "PuAHZUByHxggplbr3bzp"
                .ASCII_W "RgNeHuJ2qfjWfBQbONjN"
                .ASCII_W "jMR1qP6XS3epfox5hjLB"
                .ASCII_W "0e6FW45Ba8cx3KBGH2Gi"
                .ASCII_W "J7FCVB3tKiShAIl6mtqu"
                .ASCII_W "WVx1tEGu4MV53Q1svIHP"
                .ASCII_W "2Bt1TuwS1DczDA4fARiQ"
                .ASCII_W "xvaGm5MVRZ6CoV2QLLPp"
                .ASCII_W "zcq55sqCKu5wciawgmxK"
                .ASCII_W "n67cbBeX8EUQLjrqTY6M"
                .ASCII_W "n6dYWzu7pVdkvtufz8NJ"
                .ASCII_W "cxHn8otCQYhAw4LyrR9f"
                .ASCII_W "dKbxUxulABJ2yFBQscmm"
                .ASCII_W "sQdmc63175gz7RUdkZ4n"
                .ASCII_W "mYJtr5bU0W0yyC82TcPj"
                .ASCII_W "0dKgvzYG4S44zadVYXvH"
                .ASCII_W "hhSedUlEVTB4nmAiKATV"
                .ASCII_W "gCNQrVhKmIBUnrqGQxdZ"
                .ASCII_W "aAlxgDmRj3Ptc9JlaaEy"
                .ASCII_W "nCHSGbFK6VYNMtGZ86ss"
                .ASCII_W "MPtaaXXZLWxliSXJR71N"
                .ASCII_W "FslIbJj6j249VN5sc43D"
                .ASCII_W "3x2YktaErg2VGP9olA6T"
                .ASCII_W "1zmHexNhdt1NJBvWqRv3"
                .ASCII_W "Cqpb32jqE9J1GWytt1sS"
                .ASCII_W "hzpZLvEz0FF5IIBgCSam"
                .ASCII_W "kLer7QMkp3lrpmlrYZUh"
                .ASCII_W "P9OW98vDtT6IMdVbzPz3"
                .ASCII_W "GzUG5rcQv4x5gywwPcau"
                .ASCII_W "8R2RH4oKJC0xvfRWZRch"
                .ASCII_W "wVqIdIqDkMjbnY7gJTb3"
                .ASCII_W "Gzq3KiOAmsPuL2orWSEO"
                .ASCII_W "BP2FybyBefVIWUUzwDb1"
                .ASCII_W "mNCSiAodkfW88WDcTS0E"
                .ASCII_W "QXoHnBwwVikWuoyFgzkd"
                .ASCII_W "BRuiZhDqY0cnl4sMl13T"
                .ASCII_W "KRdrxCbSR5TUmxWsok6D"
                .ASCII_W "U4sqwDhxFjfx1LSzTARd"
                .ASCII_W "Ogd33fbM04quKYD94RXH"
                .ASCII_W "L4iCHJrPhZiYXLJL8RKp"
                .ASCII_W "FiF8NkTwPWwy8S7LqJa0"
                .ASCII_W "ZgbqEWzJK1y2gaAPkd1A"
                .ASCII_W "9bRkblKCaMcDc48FpCZ8"
                .ASCII_W "Eg1AYa7JE185hdQeFvBm"
                .ASCII_W "Nu7A1q6kUd5AwG8UYWqt"
                .ASCII_W "VujMQjGvu7HuSFXaTJ8Q"
                .ASCII_W "e369rfpQxxYqchFolvND"
                .ASCII_W "c1P971yqS8Uh5CnWfA7c"
                .ASCII_W "yDb5bh4cinlvtjtzWdqV"
                .ASCII_W "91cC4fwOwxmp3vVd1ghh"
                .ASCII_W "MkTNa4rYDmjAhvTeMTAC"
                .ASCII_W "mFsEbaH0TVeicV1JS3A2"
                .ASCII_W "FZN9uP42u5SnkV9SbVaD"
                .ASCII_W "WJ1F04IWrnqTxQTGCvno"
                .ASCII_W "fh50C4FpHJ8nJ4XV1YQf"
                .ASCII_W "aAH8HBbs3cibSgdfTWSF"
                .ASCII_W "ifD7F30ttbIVonXJXCXa"
                .ASCII_W "THGU4gLbVFW12pO3jCpy"
                .ASCII_W "0f34zIXTWE6jGQu9UQ0K"
                .ASCII_W "Z9lwWO2R4ctFquDSgFYj"
                .ASCII_W "UWpA7PmZePOx0QSe2eDq"
                .ASCII_W "NsAWNSc9isYF1Hyj2k86"
                .ASCII_W "G7lGVLUyq6a4TPr43hzF"
                .ASCII_W "Z9zX5NuV7jJyrkE8Uu7N"
                .ASCII_W "ZaO7PZIXjBrJs5EI6j1A"
                .ASCII_W "sv7GNugr81rPxL4gJerU"
                .ASCII_W "AtduIQ5fk7X6lP4Ctppr"
                .ASCII_W "OiAKLNyDmR6PlWmabPlY"
                .ASCII_W "l9Sjv67E3HQJg9avcXTr"
                .ASCII_W "Belumcljr2aKDhP9Eqa4"
                .ASCII_W "IQhUBZ9qpzpRnEpiu9S0"
                .ASCII_W "ZtlPxb3YyNyys7SEhNZ1"
                .ASCII_W "1awrcxxHRYZ7DiBPip6g"
                .ASCII_W "pYEPniURvCiZCzPstPUA"
                .ASCII_W "gKr0rHAVVh3fIh6hY5dW"
                .ASCII_W "WjdlpXD6B7qODvZhmPQe"
                .ASCII_W "fJc0VP2qcIkKabKSFEas"
                .ASCII_W "am8ZoXQ5CSHxMA26hVqx"
                .ASCII_W "S1HFABwQsaaXwjhr59oq"
                .ASCII_W "agpBAS4HugDjkALATMXj"
                .ASCII_W "ReHVE4dM7kjG3cWhZicP"
                .ASCII_W "fMVJPkZRZxj6Rn3Gy3QH"
                .ASCII_W "ANnL887AbDv55HyKXiAs"
                .ASCII_W "gMC7QUAzDiS0PKPfeWat"
                .ASCII_W "uudIB3fPaCSH2GavGRBQ"
                .ASCII_W "SxkGF5M5o69jcGc88kFM"
                .ASCII_W "XqlpIQARy2v3yOHKknK5"
                .ASCII_W "FWbmQ4K1CneqbzjbOfbv"
                .ASCII_W "hrAkdMagHG56DduXjwFn"
                .ASCII_W "OyyAROwOTnoIA2vG5vFc"
                .ASCII_W "wrANkEtcGJxpj5SdDs52"
                .ASCII_W "kiPkghiAuKugcKalg5Wj"
                .ASCII_W "06r28w282WuMCrHElhl8"
                .ASCII_W "sAWKEe0R76nTFXj8svuE"
                .ASCII_W "AAPeLf5YkgXJoPyYPUEB"
                .ASCII_W "G8bTq31YKAYikyaJmcN8"
                .ASCII_W "Pd9d5GfF5eDf1qL8HvWV"
                .ASCII_W "gnIZYWeSwVHFP66IBuoz"
                .ASCII_W "t7isNRuz32LlbqIUSqiY"
                .ASCII_W "r8aN6vyJhNMMpqAbllyh"
                .ASCII_W "AHjAawV0WnARyjMhGF5L"
                .ASCII_W "hQJ5pxfdW5d6UPbilGlS"
                .ASCII_W "JHP39DANEGLX9MxrVyoC"
                .ASCII_W "m8Wt3XCcpd6SFDSfZn2Z"
                .ASCII_W "dmcqUCR6Fuyiwj0ZD1tq"
                .ASCII_W "KKrEEmOAgpKX7amqoo6L"
                .ASCII_W "0TPJsHy8cDW0oYw8x2aG"
                .ASCII_W "RlSsS7mcncclmeOmhwKV"
                .ASCII_W "CLlD5dpuzyfRTKdGaCQP"
                .ASCII_W "1fjzSvtY4r17sbHv65nV"
                .ASCII_W "I1hUktvyQtEBDbDX4AKH"
                .ASCII_W "tqzEUNdz3v6XJ4ZCKU8Y"
                .ASCII_W "9f4LVMYC7WnlKW0SQLHl"
                .ASCII_W "NbvfY61cjtiWgVCKVUUB"
                .ASCII_W "2tW55ygNV9JjHv8mViat"
                .ASCII_W "cW82v9ztcAmEW7StLMHm"
                .ASCII_W "fCybcIX0OawqLrpkC6N4"
                .ASCII_W "AZ3CPs5EjyPC8ISbuoWH"
                .ASCII_W "aUtzg5taYyLYYa2BZDAu"
                .ASCII_W "wLeJXcfhCTKFtAYym1tu"
                .ASCII_W "IgEk9aavUUFaAeWDdPBm"
                .ASCII_W "cMHm0U04ZsZGbMpq85qN"
                .ASCII_W "M0VCJOo7nTvFC2uK5Bre"
                .ASCII_W "TW9yyLUQtf9O4OBusu02"
                .ASCII_W "hsrdfSRTnF6kGQOf9Twb"
                .ASCII_W "y4P3kf5qE5GvSoEyf1Tk"
                .ASCII_W "hPKopbxx7DLyKhXOjIP5"
                .ASCII_W "keOTdY7n8N1eSqOMyeLz"
                .ASCII_W "gVelAMdscIsUMeRobKXN"
                .ASCII_W "MCaBHPC9CpluDidIH3hk"
                .ASCII_W "nyGb8l1BOFobNe3mBCqv"
                .ASCII_W "5N2L93DaxcMoAdmkYvSc"
                .ASCII_W "GwAc1y0d1627wpxBTwEk"
                .ASCII_W "K8ELAqkLZs0zXCc9bygg"
                .ASCII_W "1pDzmJ7utyP3XKsdmZEG"
                .ASCII_W "jxoTPwGHuunmMi0ZhP4f"
                .ASCII_W "N8EFN3o7X15SUnvV3FqS"
                .ASCII_W "Slniwa8Rizl5MDZyAfzy"
                .ASCII_W "cPtzdnOL5OVnjHW8jHmF"
                .ASCII_W "Uw8f1dUCl33iAeLAVNgf"
                .ASCII_W "MXb9CeOxDQPQrmKlKsXb"
                .ASCII_W "TO2nVtKldTshat98Ak3u"
                .ASCII_W "W8xArsAjxVN23eMX9QSp"
                .ASCII_W "NQeevmDRV5h676i4O0wd"
                .ASCII_W "yN4PjZbV80OWo66HNofA"
                .ASCII_W "eUrrjeDTRGKfofsfx5r0"
                .ASCII_W "pDzHE4K9ZAEJBfaqK3V0"
                .ASCII_W "dnlTbxDjfpvxdpO5AmJr"
                .ASCII_W "Azkaf8JYFSjbFOTvmx5V"
                .ASCII_W "jkRZxvTq1v2JtnEdyV2j"
                .ASCII_W "54t7QEe4oOnfVaG6DaRc"
                .ASCII_W "UqonSYsXGMdwYGFp7Kbl"
                .ASCII_W "eHUDa8XTpso3q3rn2gds"
                .ASCII_W "Rtw0NBUZJHLH4Ss7addb"
                .ASCII_W "F9CwlLXe35wuzDbnf3WG"
                .ASCII_W "uRSY1tkib6I7KtLjYwpC"
                .ASCII_W "x8ZQONyC93JJAFw64cOK"
                .ASCII_W "6GROV8vl6xkURZ9fEkz0"
                .ASCII_W "LlSbNvhZ39guvIRNtglU"
                .ASCII_W "Svd6VTkiHdzA5PyHOT1T"
                .ASCII_W "FdkzBSWPvHLlcWrBBDUi"
                .ASCII_W "Xc7n5j0SEBz5wZa0Nx2C"
                .ASCII_W "OcvPaPvkaKlkUwqQGdvF"
                .ASCII_W "AiZ9GAbCutkacxngKXyq"
                .ASCII_W "Dx2RHWMFRZp9RSD8jXRk"
                .ASCII_W "EoQDQUrgHkUOHAAEGjt1"
                .ASCII_W "gAXM8pB49h511lhRk9os"
                .ASCII_W "c626XvHYDumK0mFEmqgG"
                .ASCII_W "8RnspdDlFAdBxhtNGoZq"
                .ASCII_W "7iQTunb5QfSrEd0f9Gk3"
                .ASCII_W "DMuuk8CsicCRPY3e2jGB"
                .ASCII_W "8dTLoGKp6Cqlbe2CF6e5"
                .ASCII_W "DRS10NQsQ9CM75kNu0HP"
                .ASCII_W "p4hQTJK9y2bNjIkgR52d"
                .ASCII_W "gmPB10jmcBXlYW8YBqWa"
                .ASCII_W "DFhUuWLgu9kctsaxE9aQ"
                .ASCII_W "kZzVoB75WW8YX8Q18LiG"
                .ASCII_W "hicOE9HLhZGZNbb17Bzb"
                .ASCII_W "FZRyTsewIEkYTF4GmELi"
                .ASCII_W "qFGtXXcANSXfmTSvcZYF"
                .ASCII_W "7lQv6JrJZzO7MOBBa41o"
                .ASCII_W "0ffzch40sjrRjTXaOPrZ"
                .ASCII_W "9z8u9cpGEUjIN9oi1GkS"
                .ASCII_W "sqq6sM9FSWdbrsIvZQEm"
                .ASCII_W "DRCVQhrq2033YwgG3bEx"
                .ASCII_W "yQ48TY48SPnmkwKDirp5"
                .ASCII_W "siYGLxEYZ6Cd7r5t2n5d"
                .ASCII_W "0VbSPMpnJ2OT1KQYiuob"
                .ASCII_W "umOkmkOjQ77QqjcavqQi"
                .ASCII_W "MBIUA6pmgszwbfuWIiHj"
                .ASCII_W "VnLYdgAkdKoJkfrPVv0E"
                .ASCII_W "Be3XrUtKOQRDmcuvjGrI"
                .ASCII_W "SRAWxGO1MmxWzfbHXA4z"
                .ASCII_W "iOkWpQgEol3DiCMgiG7D"
                .ASCII_W "voYc74CVSfrjbQqnj8rr"
                .ASCII_W "4I6SyzlUk6j0M2oGJcWy"
                .ASCII_W "tZfHUwRfSD6AHGl7WAGS"
                .ASCII_W "W4r3WkVsUG4dwQzgUAod"
                .ASCII_W "AocdPeJGhYf72DKMuoTn"
                .ASCII_W "yZ4D3Lf3TcykEmFKgJyi"
                .ASCII_W "CJKWnKiBOuazjM4lfc04"
                .ASCII_W "XbtFRG34tXLocQFI9AOp"
                .ASCII_W "lHr4WzrsUZHLhzdEcohG"
                .ASCII_W "84TtldlVKj7dARJYvL7P"
                .ASCII_W "Ja24AbV7WEOx58UT8Szb"
                .ASCII_W "vMfurcxvKhargSJy3xKl"
                .ASCII_W "LZMBdr6BnsgBqJApKuxH"
                .ASCII_W "VyKbbaHrIDFYAjjyGfsV"
                .ASCII_W "QvvwiMGnl2tWREKMIDQY"
                .ASCII_W "OLaDnX33M83KFWlSwAPY"
                .ASCII_W "PwzDi7oJlRNSnmjezsWL"
                .ASCII_W "0Uj2J8qwars0If8aJqfB"
                .ASCII_W "jg23DawUDTj1rBICAqdP"
                .ASCII_W "f39o9NgX7ww7IgyPdunS"
                .ASCII_W "sK9kMmWP9ZAHAIkROWVV"
                .ASCII_W "qepViptYu2kkCvKFh5qV"
                .ASCII_W "bp6LWI8jGT5nhNCr8mGj"
                .ASCII_W "tZ6re6nX8Jft51hSP0Ue"
                .ASCII_W "RdFXrmCi5OXVRZ8k9d9x"
                .ASCII_W "HhaSnfpcUwAJ6BqR8kOs"
                .ASCII_W "lPuU8G66G7EFfdXDNIEA"
                .ASCII_W "CczpJOipFLssFRsS3ij8"
                .ASCII_W "bJif2gLbpU8aB7b5NfNO"
                .ASCII_W "yfDaw9vOc29gLvB3CQcG"
                .ASCII_W "cpw4McF02pqJLLeS5Gmw"
                .ASCII_W "MYRJLlNvSDYZFmhs2IVM"
                .ASCII_W "SpJ9EqgfBAbLFHb9WJNu"
                .ASCII_W "o0K5UfRjrvv3MLpMxv8R"
                .ASCII_W "FEw5s3HNhwTzqPEvzXgR"
                .ASCII_W "ZHCrXluN8c4UKHEE0474"
                .ASCII_W "pE9ctHWUMrvtyBUa1osb"
                .ASCII_W "X1g0zqAZKDwT7kBYS4pj"
                .ASCII_W "MbEXShtdrsYfIvvncs3s"
                .ASCII_W "mIsVjRk2MPKMQaATLLpR"
                .ASCII_W "ds52RjNpP0sRoQgJad2t"
                .ASCII_W "ta7Ht18wo5Ul3IhayWPc"
                .ASCII_W "zox021eTzzoxTSogKVry"
                .ASCII_W "zbDMwNGvOAIS0XI85FeM"
                .ASCII_W "2XnaM7hYY79aeGchzLTc"
                .ASCII_W "OC9dwveehsPCtHOXlRyr"
                .ASCII_W "UFjRRn3zYjrcghgZu74A"
                .ASCII_W "WHCfyTJuROLi8HgVzjd1"
                .ASCII_W "kavpTYsJYdDi3H7KRtlJ"
                .ASCII_W "qGfVL8J1aJD5I6JwDtiw"
                .ASCII_W "B2Q3omkcuLDAPHOQJI89"
                .ASCII_W "IbJNMcrNJHVHTLBmssZg"
                .ASCII_W "MG3kJUAzXZYgoA9Iifbg"
                .ASCII_W "PAwWEzOIAhuXtBwSA6X9"
                .ASCII_W "mf1npurFRPICZjpsV0co"
                .ASCII_W "kkeLMQiPmYIdwdICAc6g"
                .ASCII_W "Gn7L2VDMV6BDbGxBD3oQ"
                .ASCII_W "zPYi7yp8cItu4yTFpJPB"
                .ASCII_W "gaJiyuSpJCo6I8tfo1Wq"
                .ASCII_W "dVE1qVkrZQOKXUXlAlib"
                .ASCII_W "VbLROm41kZhqmFp9D95i"
                .ASCII_W "A9Fo2QQdSObFFKvHyzPd"
                .ASCII_W "UqHINkOpfAEkklTBfnuy"
                .ASCII_W "jbb0ompwqVrFtNXuzJbQ"
                .ASCII_W "7HpgbrrybEaGJwrw1daP"
                .ASCII_W "RDoNgdZNW46sGaXqu1UJ"
                .ASCII_W "Ms7yCdc96MTUBwYlwPn5"
                .ASCII_W "J6T2v9RwsWx3deEVILp3"
                .ASCII_W "HENKHWaM3GODPyQP7TRK"
                .ASCII_W "fd2EdourNd8RdnYhI4A9"
                .ASCII_W "3MaEH8XzK103PeM2Dx8m"
                .ASCII_W "kdkHMAqQjbEVhd4XdfXx"
                .ASCII_W "usHPAQFAL4wmrtezMTNM"
                .ASCII_W "bEd2oXjvmbTpKJVgYkdD"
                .ASCII_W "n5rVyKIDqQjYIrZzGlMB"
                .ASCII_W "xA3Wyy0a6nwMxzAY7AIU"
                .ASCII_W "XrcrNmyVOIDbIG4lgIF3"
                .ASCII_W "Usu7m8Oq624zFd4M1u1u"
                .ASCII_W "NaqkgChqwPBCqHUFiarP"
                .ASCII_W "4csqFXOTw17OcChiICjG"
                .ASCII_W "ObYbtyT7d42PVRXV5h4K"
                .ASCII_W "eQvFyNrH5sl9PYaxc7ji"
                .ASCII_W "NV8BDz1hl3O4SUQdGw21"
                .ASCII_W "n01cNbIwVFWCNzBhHMdJ"
                .ASCII_W "lwkiY08OP59SwvWnFX6q"
                .ASCII_W "aoVTgVGNKXwJ1HhaLiqx"
                .ASCII_W "8rjyS6pvtPglYpA7Jt84"
                .ASCII_W "wKgHgQxTC58bfDgD8EWQ"
                .ASCII_W "8KoAKtmS5OquVeuWJrme"
                .ASCII_W "FnPDo2L9Y5sTjnJ7ClOW"
                .ASCII_W "OTfaI9fMaJS9ddiGx0sZ"
                .ASCII_W "TY8A8pzwxtLzTwKYGHRa"
                .ASCII_W "UG2L6T7TDCpvlr3AfhES"
                .ASCII_W "UPbXvdR5tfYXU343AGKh"
                .ASCII_W "A2IsIe4vcw6nDfaG0uMB"
                .ASCII_W "4LfQyy1YAC5zRsnlx5Pg"
                .ASCII_W "JtmiIQfvEUduNPaX2tHv"
                .ASCII_W "qHWgohXgDi04hhY0MeNx"
                .ASCII_W "HTDIB8Q3LhzeeH2VMWNk"
                .ASCII_W "EkIgltbHS5SHjuq88YGf"
                .ASCII_W "8qVRbErTiTuGW78on8wG"
                .ASCII_W "VYmUEpSxATDAUbfs38TS"
                .ASCII_W "Szdpfqn8a1b0G37tU0Do"
                .ASCII_W "i9npUzvyn5Sx51ReSCul"
                .ASCII_W "N9ZShndrvUbHhJPzsewz"
                .ASCII_W "YMaEeWtoVQzSLeqfQS7g"
                .ASCII_W "svGs3w3rmSbznWL37BiF"
                .ASCII_W "umkjPYevVZkhmqXdDLGj"
                .ASCII_W "eP9xHINi9wNM39G2sc80"
                .ASCII_W "6LkPL3Numn8KiK7hdBln"
                .ASCII_W "KFiFaHymFzioeGvxtqoe"
                .ASCII_W "j02knNvVKAqlS5SqNR5k"
                .ASCII_W "YBKgK4LO2O5KaKRQA4vE"
                .ASCII_W "YRPLBTPdNwotd50weMAK"
                .ASCII_W "W1lkI5pjgZxLdraVM5Y6"
                .ASCII_W "Q8jjaSSwRaDdvGiqFAcS"
                .ASCII_W "pRG6YJfeqkmFQTyK1v16"
                .ASCII_W "llG68wIEd6R08YDawCIC"
                .ASCII_W "0Gxxq5pnWpZxYdkmxAf5"
                .ASCII_W "AJIO2yzuuaoG5iNuNn8Y"
                .ASCII_W "uTJo2E0mIiXzPk5WI1dT"
                .ASCII_W "5qIlG7EZIQrXr0nLJbdR"
                .ASCII_W "9JIPPtHteH18zZXfvSOV"
                .ASCII_W "GkZNC8eaLNGjTo4kWRtt"
                .ASCII_W "k23BoTd3OikrbT8eepXL"
                .ASCII_W "fIgG7ORPNqy7ly93eBt0"
                .ASCII_W "WNTapnZOmSywWoDmCXFh"
                .ASCII_W "EXRa79OlGZaekiRKMxny"
                .ASCII_W "RSs97n4d70QiL8VxsE54"
                .ASCII_W "tLEHejpDcwDFJysD12h3"
                .ASCII_W "tR9dIquwShLTdb5wdW5X"
                .ASCII_W "f2Ckey6GQjxCYK3U0uFr"
                .ASCII_W "LwIlVy8Zi5Th8bOfCEMW"
                .ASCII_W "dIeYQPVpbltuSvQ7mCxi"
                .ASCII_W "GAcDKj57lvjweFEc5Y1d"
                .ASCII_W "8wbJttn2sHYgyW3jsgai"
                .ASCII_W "rim4Djjnuw3zCqEMNNj2"
                .ASCII_W "31QCj7ZoMaKgraeHMUCL"
                .ASCII_W "rNsiZRFCQSUJt7Mfb1vt"
                .ASCII_W "gOjCaUfSFwI6Eez5cdin"
                .ASCII_W "GB9J3iDxnIUshhvZ94IK"
                .ASCII_W "VRZScBiltlEM8sxSDlke"
                .ASCII_W "eGtVaD42sYNKi8QVUroJ"
                .ASCII_W "qeqVaPOffJN8aFxGVZ4T"
                .ASCII_W "7nVMnn3TY6XgtiuagoBb"
                .ASCII_W "51WwVYpDWAhE1369aIN6"
                .ASCII_W "8NtYbRYt8eDkfg1PWoTa"
                .ASCII_W "iofy6f4lt7zhAL8ZAHwt"
                .ASCII_W "P2f4dLkz9Q2BHrWG6ion"
                .ASCII_W "Wuf9TqUYAXdRlMtfDl8p"
                .ASCII_W "1NQxMcDt9dpjc9dij6AF"
                .ASCII_W "uJWjw3ewsbC8Rw72r7Ms"
                .ASCII_W "6l89EPP26qvU49JjL7oe"
                .ASCII_W "v22r4MDmxAbTlT1nBZqY"
                .ASCII_W "AKYdF2w0p5Kux5IciLUY"
                .ASCII_W "rcfzIITevnGFANgxTEYh"
                .ASCII_W "n9atS4QZFb6VXzTbl3KC"
                .ASCII_W "Rq38tv9OMTEFK0YFdCHL"
                .ASCII_W "SSlw8nyfUPVRuD3z5SEo"
                .ASCII_W "tbNSXC4KBj6MH6aJkeGI"
                .ASCII_W "yhVT7C8Py11j4dFwPzPu"
                .ASCII_W "4njwXGb01yYy6TaNhjbe"
                .ASCII_W "m6vmREQpoQyLKV5ye140"
                .ASCII_W "3Kq4BViYwyoArhwmpZWv"
                .ASCII_W "LeInePddm7z6m2HH6bvo"
                .ASCII_W "jJ7ADI5j7tZSfSKAjiJd"
                .ASCII_W "Fs4uZR2D9I9OLeikEHg7"
                .ASCII_W "3EHUPlWVWZ7y2E5fLmUZ"
                .ASCII_W "xx1Tkoty2IFAnBrfXTmv"
                .ASCII_W "If3w0Mv5ge7MHUsim9L0"
                .ASCII_W "yvIfSVklF9IXDOmZ49lB"
                .ASCII_W "Os7u7evXFGMHrsRowLg2"
                .ASCII_W "x9SstIHglF6Ot7fnLIeI"
                .ASCII_W "4mO4l6UHWTedzKA44ek3"
                .ASCII_W "Y5cVwfamiDESFEetVlMm"
                .ASCII_W "kTrLCIzcfy5N040gZHrx"
                .ASCII_W "qgXFqQAstwnBrN6VZrJH"
                .ASCII_W "THgBZYSuAmy8IAL6tY8P"
                .ASCII_W "8iVGR9vFbAHc79aiM4Sd"
                .ASCII_W "mcgOkLGp7kydEvHsPOEV"
                .ASCII_W "VDwVcwhQJpjcECLAQHfR"
                .ASCII_W "AKyc7RIgikCdxeTxvmBg"
                .ASCII_W "ilw2k5LAUOR08GVsQFtV"
                .ASCII_W "Kvh4btu6pR0iGMAZs8V8"
                .ASCII_W "HdyAhf8pInuHbV5NQXwg"
                .ASCII_W "AiAskdDd28JdNMeRFHu0"
                .ASCII_W "bfTMp4Ip2lwv7fhCmuwg"
                .ASCII_W "mSLex6N3cwAkTaY5n31E"
                .ASCII_W "ud2DUxdZZNWymv6xaqbI"
                .ASCII_W "jbjebHzdaAzEJuCbooSE"
                .ASCII_W "4DW5x4AmFbXhNAx8gOC3"
                .ASCII_W "vWnP50F28noC22dSbC3e"
                .ASCII_W "NOuilq1q3qCgBMW5VAB0"
                .ASCII_W "GqJxT6jXjsMfsGSF0kE2"
                .ASCII_W "T1lT5V2IocvkWewjrUr8"
                .ASCII_W "uchYXOVKBNlIMQrX3Cit"
                .ASCII_W "Sl5PCdSnWi6EnfmrROoU"
                .ASCII_W "X73BtJbFwaSq6XqTUtrp"
                .ASCII_W "cbJRoAl2VhciOHOY0cPO"
                .ASCII_W "IABeJPsAZ1RGPueOHSmh"
                .ASCII_W "pYolS2koQh47E7ly2rGj"
                .ASCII_W "DGwOF3p4W1NRuJGd5SxO"
                .ASCII_W "U9uVrgjmaZ4cvOvru7Jp"
                .ASCII_W "mYkvtQiADEy08EBSTAvJ"
                .ASCII_W "2OPmMgl5jhI33Ozc4H6R"
                .ASCII_W "aAP8JWtlAymad3PGkut3"
                .ASCII_W "0iNigCqLFBn9gUthZAhj"
                .ASCII_W "JwKCKzD5bv672pD2EEdU"
                .ASCII_W "YvQzRNKfE9AfX6DEjww3"
                .ASCII_W "ZOaYCX1a8Ltjoi4QrsHy"
                .ASCII_W "dI95MpZcuxu2tzk6HEbK"
                .ASCII_W "qg7xAg4W8YN8SS2jkHNb"
                .ASCII_W "eT7xm0Ftb0UDDbkMP4uL"
                .ASCII_W "k0gtJ2og9bjjmXeQ1ngW"
                .ASCII_W "7Dr6QGSmgLpkFxaT72Id"
                .ASCII_W "q7ZlThXm25p102k94kEj"
                .ASCII_W "Q4euIW8qp8rApuG36ZtN"
                .ASCII_W "5sIlot1LdcOoAhwIbCEB"
                .ASCII_W "yissWG36yKXXXZ1SaS6n"
                .ASCII_W "aq2gaBC3dbhs3Gjowr6I"
                .ASCII_W "7SID5RhgPeEahH3Ngr9A"
                .ASCII_W "k6VX2mvr2bEvwgloPFkz"
                .ASCII_W "lV65IQqUxh2B6hZKwsZh"
                .ASCII_W "WMeNv9chBjP4eD00ti4N"
                .ASCII_W "EQcldGGjETYLyZw6wuyX"
                .ASCII_W "WRTjO4zgpF2AfCgvLJOW"
                .ASCII_W "AqOjowsBbdkRbGmfX5aC"
                .ASCII_W "ARN4p0vDjMeANhCCQI0g"
                .ASCII_W "IaVy2Tb3cMbzZ46itVRW"
                .ASCII_W "FutDOaA8sPGWfoarCR1l"
                .ASCII_W "s4PTPhSO4cpgrQ1x7y3e"
                .ASCII_W "gPnmokzuQXIdd7MzImCF"
                .ASCII_W "b0F8OmjS4SBVvTAyToDZ"
                .ASCII_W "zNY6TK35BLB7lAiyTmEg"
                .ASCII_W "8f7j9vgU9PI2492WxVGJ"
                .ASCII_W "DUMiJo1nyrPHWRjQKner"
                .ASCII_W "HxW8AaVp5N3cKaxmB6iL"
                .ASCII_W "6YYAA9BVVe7pyTTBpgcY"
                .ASCII_W "5QUECY1MAgy6M3UL4qHi"
                .ASCII_W "22TlHHq0GiQcdeyMWPa8"
                .ASCII_W "ddMIhFYgb4dTy4oNgTFC"
                .ASCII_W "0ANQYMyBWtZOhjf9tdFx"
                .ASCII_W "t1yajp0fW3WQHbozCr1k"
                .ASCII_W "lU2ITJvBNk2Pp9AKumxP"
                .ASCII_W "iKHkAxxzSsyVvckiNn3A"
                .ASCII_W "TKlk6BgKYlx4GJWVdXNL"
                .ASCII_W "yYtNTMilFR1bK6xs2WXy"
                .ASCII_W "Y3hAIMhqRLZofdI29uBh"
                .ASCII_W "1Qa5GtiUyZiCPlHqxLwt"
                .ASCII_W "iUqREjetuX5SzGKRsKij"
                .ASCII_W "66oAiIAXZTSbjOeFSSBi"
                .ASCII_W "hHJCqSGxgHZ7Hewz0E8j"
                .ASCII_W "fX5IY5BRhtyLrnAWSMGx"
                .ASCII_W "kMaXFRzLP2dJL9XTcUFb"
                .ASCII_W "wbazzgOCG2wByiWnpbX8"
                .ASCII_W "61WaRC9vdPPyn1gnblbT"
                .ASCII_W "Udel4JMybI8ZVvr059PK"
                .ASCII_W "9rGJ7J80L4ZQmf9SfuuY"
                .ASCII_W "TN8vmYxFxneKqGUkwRJI"
                .ASCII_W "XFUsgqW6e4UX8LZ5C2rX"
                .ASCII_W "iTIizZ6adTEQ4OL8aK5y"
                .ASCII_W "yrDJTxSPwXhICLWYLq4k"
                .ASCII_W "Pnj954UGPDJU3RHKd4Y7"
                .ASCII_W "9XgORAMK5BgRJ507Zsce"
                .ASCII_W "NF2nBfYY8tOszSBsd33R"
                .ASCII_W "uEOYrfBzkFZnNR0zY9pn"
                .ASCII_W "cpREaMCkq9YkI8FLj0S4"
                .ASCII_W "5bY8kVTwv39GzzI5GsTw"
                .ASCII_W "mxhpyintPstCAidH6Bkr"
                .ASCII_W "BQF8KyjMOex2gAeErxar"
                .ASCII_W "RprifVZot3yzCEX684jF"
                .ASCII_W "mdf1FbRSu23WQDTEMFBa"
                .ASCII_W "6H9QK7M2HnTMAbudhEVP"
                .ASCII_W "74iB1iOGkj6uOwu8y0DC"
                .ASCII_W "KKmLANUYN9EFx8R5gDUO"
                .ASCII_W "JDXlgBGFO66mQIi343MJ"
                .ASCII_W "kpX4woRemjNIRs6MGHQt"
                .ASCII_W "7FVlvUe44zrlns5LWICy"
                .ASCII_W "p8TInmFBmvrriyNYJilV"
                .ASCII_W "NBLf0padcoeqRLgeFCzq"
                .ASCII_W "XXIjINcpBxT0zzoQyLIj"
                .ASCII_W "JqYfH8RaDSZLJ9ksYeDs"
                .ASCII_W "GdHAuAOi6873E7dRN4qT"
                .ASCII_W "3dxwPvlczmuN8Z25FLrR"
                .ASCII_W "FOqY5Or9PF5X8570Rd1Q"
                .ASCII_W "AeYOL7EG018VP7lw9djV"
                .ASCII_W "3J24kGoQNiwR0ZZg4Xg6"
                .ASCII_W "3tKC7B5e7h6E4ffusVF3"
                .ASCII_W "mja7bErEryvDlhEP0pfL"
                .ASCII_W "QBLSEliAWILETFD0J87F"
                .ASCII_W "eaIM9KwYKyhpKG2h7PWb"
                .ASCII_W "hQxXa5Jyr3JyMVEuLNz0"
                .ASCII_W "aL8MNyG6VRlsx6LTu6Mr"
                .ASCII_W "yYv6HFeGV5l1cfEI6zXy"


HEAP_HEAD        .BLOCK 1
HEAP_START       .BLOCK 1