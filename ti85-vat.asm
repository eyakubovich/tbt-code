	#include "TI-85.H"

SCRN_ROWS       =7
CUR_ITEM        =TEXT_MEM
CUR_ITEM_TYPE   =TEXT_MEM+2
CUR_ITEM_ADDR   =TEXT_MEM+3
CUR_ITEM_NLEN   =TEXT_MEM+5
CUR_ITEM_PNAM   =TEXT_MEM+6
ARROW_POS       =TEXT_MEM+8
TOP_SCRN_ENTR   =TEXT_MEM+9
BOT_SCRN_ENTR   =TEXT_MEM+11
STACK_TOP       =TEXT_MEM+13
STACK           =TEXT_MEM+15


	.org 0
	.db "VAT Viewer", 0

        ld hl, VAT_START
        ld (TOP_SCRN_ENTR), hl

        ld hl, STACK
        ld (STACK_TOP), hl

        ld a, 0
        ld (CUR_ITEM), a                ; Init CUR_ITEM
        ld (ARROW_POS), a               ; Init ARROW_POS to beg

        CALL_(PrintScreen)
        ld hl, $0001                    ; Put Cursor (0,1)
        ld ($800C), hl
        CALL_(PrintArrow)

WaitKey:
	call GET_KEY
        cp K_UP
        CALL_Z(MoveUp)
        cp K_DOWN
        CALL_Z(MoveDown)
        cp K_ENTER
        JUMP_Z(DispInfo)
        cp K_EXIT
        ret z
        jr WaitKey

MoveUp:
        push af
        ld a, (CUR_ITEM)
        cp 0
        jr z, MoveUpExit                ; Can't Move Up (At the top)
        dec a
        ld (CUR_ITEM), a

        ld a, (ARROW_POS)
        cp 0
        jr nz, MoveUpArrow

        CALL_(StackPop)
        ld (TOP_SCRN_ENTR), hl

        ld a, (CURSOR_ROW)
        dec a
        ld (CURSOR_ROW), a
        CALL_(PrintScreen)

        ld a, 1
        ld (CURSOR_ROW), a
        CALL_(PrintArrow)
        jr MoveUpExit

MoveUpArrow:
        CALL_(ClearArrow)
        dec a
        ld (ARROW_POS), a
        ld a, (CURSOR_ROW)
        dec a
        ld (CURSOR_ROW), a
        CALL_(PrintArrow)

MoveUpExit:
        pop af
        ret

MoveDown:
        push af
        push de
        push hl
        ld hl, (VAT_END)
        ld de, (BOT_SCRN_ENTR)
        call CP_HL_DE
        jr nz, MoveDownL1 
        ld a, (ARROW_POS)
        cp 6
        jr z, MoveDownExit

MoveDownL1:
        ld a, (CUR_ITEM)
        inc a
        ld (CUR_ITEM), a

        ld a, (ARROW_POS)
        cp 6
        jr nz, MoveDownArrow

        ld hl, (TOP_SCRN_ENTR)
        CALL_(StackPush)
        CALL_(IncOneRec)
        ld (TOP_SCRN_ENTR), hl
        CALL_(PrintScreen)

        ld a, 7
        ld (CURSOR_ROW), a
        CALL_(PrintArrow)
        jr MoveDownExit

MoveDownArrow:
        CALL_(ClearArrow)
        inc a
        ld (ARROW_POS), a
        ld a, (CURSOR_ROW)
        inc a
        ld (CURSOR_ROW), a
        CALL_(PrintArrow)
MoveDownExit:
        pop hl
        pop de
        pop af
        ret

PrintScreen:
        ; TOP_SCRN_ENTR - First Entry to Print
        ; SCRN_ROWS    - Number of rows on screen        

        push bc
        push hl
        CALL_(PrintHeader)
        ld hl, (TOP_SCRN_ENTR)
        ld (BOT_SCRN_ENTR), hl
        ld b, SCRN_ROWS
PrintScreen_For:
        ld a, 1
        ld (CURSOR_COL), a
        CALL_(PrintEntry)
        ld a, (CURSOR_ROW)
        inc a
        ld (CURSOR_ROW), a
        djnz PrintScreen_For
        pop hl
        pop bc
        ret

PrintEntry:
        ; -- Print Type --
        push af \ push bc \ push de \ push hl
        ld hl, (BOT_SCRN_ENTR)
        ld a, (hl)
        cp 20
        jr c, L1
        ld a, 20
L1:     ld b, a
        sla a \ sla a                   ; Mult by 4
        add a, b                        ; Now it's Multed by 5
        dec hl
        ld (BOT_SCRN_ENTR), hl
        ld hl, TypeNames
        CALL_(ADD_HL_A)
        ld de, (PROGRAM_ADDR)
        add hl, de
        ROM_CALL(D_ZT_STR)              ; Print Type

        ld a, $20
        ROM_CALL(TX_CHARPUT)            ; Print Space
	
        ; -- Print Addr --
        ld hl, (BOT_SCRN_ENTR)
        ld b, (hl)
        dec hl
        ld c, (hl)
        dec hl
        ld (BOT_SCRN_ENTR), hl
        ld h, c
        ld l, b
        CALL_(DispHexW)                 ; Print Address

        ld a, $20
        ROM_CALL(TX_CHARPUT)            ; Print Space

        ; -- Print Name --
        ld hl, (BOT_SCRN_ENTR)
        ld b, (hl)
PrintNextEntry_For:
        dec hl
        ld a, (hl)
        ROM_CALL(TX_CHARPUT)
        djnz PrintNextEntry_For
        dec hl
        ld (BOT_SCRN_ENTR), hl
        pop hl \ pop de \ pop bc \ pop af
        ret


DispHexW:
	; hl - number to output
        push af
        ld a, h
        srl a \ srl a \ srl a \ srl a
        and $0F
        CALL_(DispHexDigit)
        ld a, h
        and $0F
        CALL_(DispHexDigit)

        ld a, l
        srl a \ srl a \ srl a \ srl a
        and $0F
        CALL_(DispHexDigit)
        ld a, l
        and $0F
        CALL_(DispHexDigit)
        pop af
        ret
	
DispHexB:
        ; a - number to output
        push af
        push bc
        ld b, a
        srl a \ srl a \ srl a \ srl a
        and $0F
        CALL_(DispHexDigit)
        ld a, b
        and $0F
        CALL_(DispHexDigit)
        pop bc
        pop af
        ret

DispHexDigit:
	; a - digit
        add a, $30                      ; Add ASCII offset
        cp $3A
        CALL_NC(Add7H)
        ROM_CALL(TX_CHARPUT)
	ret
Add7H:  add a, $7
        ret
	
DispNumB:
        push af
        push hl
        ld l, a
        ld h, 0
        ROM_CALL(D_HL_DECI)
        pop hl
        pop af
        ret

ADD_HL_A:
        push bc
        ld c, a
        ld b, 0
        add hl, bc
        pop bc
        ret

PrintHeader:
        push af
        push de
        push hl
        ROM_CALL(CLEARLCD)              ; Clear Screen
	ld de, (PROGRAM_ADDR)		; de points to beg of program
        ld hl, $0000
        ld ($800C), hl                  ; Put cursor at (0,0)
	ld hl, HeaderText		; hl points to HeaderText offset
	add hl, de			; Get absolute address
        ld a, (IY+05)                   ; Get Mode
        xor $08                         ; Set to White Text, Black Backgr
        ld (IY+05), a                   ; Put Mode
        ROM_CALL(D_ZT_STR)              ; Output HeaderText
        xor $08                         ; Change Mode Back
        ld (IY+05), a                   ; Put Mode
        pop hl
        pop de
        pop af
        ret

PrintArrow:
        push af
        ld a, 0
        ld (CURSOR_COL), a
        ld a, $05
        ROM_CALL(TX_CHARPUT)
        pop af
        ret

ClearArrow:
        push af
        ld a, 0
        ld (CURSOR_COL), a
        ld a, $20
        ROM_CALL(TX_CHARPUT)
        pop af
        ret

IncOneRec:
        ; hl - Start of rec
        push af
        push bc
        ld a, (hl)
        ld (CUR_ITEM_TYPE), a
        dec hl
        ld ix, CUR_ITEM_ADDR
        ld (ix+1), a
        dec hl
        ld a, (hl)
        ld (CUR_ITEM_ADDR), a
        dec hl
        ld a, (hl)
        ld (CUR_ITEM_NLEN), a
        ld b, a
        dec hl
        ld (CUR_ITEM_PNAM), hl
IncOneRec_For:
        dec hl
        djnz IncOneRec_For
        pop bc
        pop af
        ret

StackPush:
        ; hl - Number to Push
        push de 
        push hl
        ld d, h \ ld e, l
        ld hl, (STACK_TOP)
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        ld (STACK_TOP), hl
        pop hl
        pop de
        ret

StackPop:
        ; hl - Number Poped
        push de
        ld hl, (STACK_TOP)
        dec hl
        ld e, (hl)
        dec hl
        ld d, (hl)
        ld (STACK_TOP), hl
        ld h, d \ ld l, e
        pop de
        ret

RetrInfoEntry:
        ; CUR_ITEM - Item to retrieve info about
        ; CUR_**** - Get updated

        push af
        push bc
        push hl        
        ld hl, (VAT_START)
        ld a, (CUR_ITEM)
        ld b, a
        inc b
RetrInfoEntry_For:
        CALL_(IncOneRec)
        djnz RetrInfoEntry_For
        pop hl
        pop bc
        pop af
        ret

DispInfo:
        CALL_(RetrInfoEntry)
        ROM_CALL(CLEARLCD)
        ld hl, 0
        ld ($800C), hl

        ld a, (CUR_ITEM_TYPE)
        ;ld l, a
        ;ROM_CALL(D_HL_DECI)
        CALL_(DispHexB)

        ld a, $20
        ROM_CALL(TX_CHARPUT)

        ;ld hl, (CUR_ITEM_ADDR)
        ;call LD_HL_MHL
        ;ROM_CALL(D_HL_DECI)

        ;ld a, (CUR_ITEM_NLEN)
        ;ld hl, (CUR_ITEM_PNAM)
        ;inc hl
        ;ROM_CALL(D_LT_STR)
        ;pop af

WaitKey2:
        call GET_KEY
        cp K_EXIT
        ret z
        jr WaitKey2
        
HeaderText:
        .db " TYPE ADDR   NAME    ", 0

TypeNames:
        .db "REAL", 0
        .db "CPLX", 0
        .db "VECT", 0
        .db "VTCP", 0
        .db "LIST", 0
        .db "LSCP", 0
        .db "MATR", 0
        .db "MTCP", 0
        .db "CONS", 0
        .db "CNCP", 0
        .db "EQUN", 0
        .db "RANG", 0
        .db "STRN", 0
        .db "GDB ", 0
        .db "GDB ", 0
        .db "GDB ", 0
        .db "GDB ", 0
        .db "PICT", 0
        .db "PRGM", 0
        .db "RANG", 0
        .db "UNKN", 0

	.end
