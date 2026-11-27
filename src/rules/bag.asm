; The bag and equipment screen (Select). BG1 holds the pieces' pictures and the empty cells, BG2 the words and the
; cursor. Pictures are copied to video memory while the screen is blank; moving pieces about only rewrites the maps,
; which the frame interrupt sends.
MENUMAP = $7E4000            ; BG1's map while the screen is open (32 x 32)
ICONAT = $7E4800             ; for each picture the tile it was loaded at (0: not loaded)
ICONS = 134
Z_DOLL = 0
Z_GRID = 1
Z_BELT = 2
GRID_X = 12                  ; (tiles)
GRID_Y = 2
BELT_X = 18
BELT_Y = 11
INFO_X = 13
INFO_Y = 13
HINT_Y = 26
INFO_W = 19

; the doll's boxes (tile x, y, width, height) for weapon, head, chest, legs, shield, ring, amulet
doll_x: .byte 0, 4, 4, 4, 8, 1, 9
doll_y: .byte 5, 2, 7, 14, 7, 14, 3
doll_w: .byte 4, 4, 4, 4, 4, 2, 2
doll_h: .byte 8, 4, 6, 4, 6, 2, 2
; where the cursor goes from a box: up, down, left, right ($FF stays, $80 the grid)
doll_nav:
 .byte 1, 5, $FF, 2
 .byte $FF, 2, 0, 6
 .byte 1, 3, 0, 4
 .byte 2, $FF, 5, $80
 .byte 6, 3, 2, $80
 .byte 0, $FF, $FF, 3
 .byte $FF, 4, 1, $80
doll_row: .byte 2, 0, 1, 3, 1, 3, 0            ; the grid row beside a box

BagOpen:
 .a16
 .i16
 lda #M_BAG
 sta mode
 lda #Z_GRID
 sta bagZone
 stz bagCx
 stz bagCy
 stz bagDoll
 stz bagBelt
 lda #$FFFF
 sta bagIdent
 stz msgp
 jmp BagSetup

; the whole screen, with the screen blank: tiles, colours, pictures, maps
BagSetup:
 .a16
 .i16
 sep #$20
 .a8
 stz $420C
 lda #$80
 sta $2100
 rep #$20
 .a16
 lda #1
 sta inMenu
 jsl FarClearScreen         ; sprites away, the text layer empty
 sep #$20
 .a8
 lda #$03
 sta $212C                  ; BG1 + BG2
 stz $212D
 stz $2130
 stz $2131
 stz $210D
 stz $210D
 lda #$FF
 sta $210E
 sta $210E
 rep #$20
 .a16
 lda #menu_tiles
 sta n0
 lda #^menu_tiles
 sta n1
 stz n2
 lda #MENU_TILES_BYTES
 sta n3
 jsl FarDmaV
 ldx #0                     ; the colours
 sep #$20
 .a8
 stz $2121
@col:
 lda.l menu_pal,x
 sta $2122
 inx
 cpx #256
 bne @col
 rep #$20
 .a16
 ldx #ICONS * 2 - 2
 lda #0
@cl:
 sta.l ICONAT,x
 dex
 dex
 bpl @cl
 lda #14                    ; the first free tile (after the cells and the box frame)
 sta bagTile
 ldx #BAG0                  ; every piece's picture: the bag, worn, the belt
@p:
 phx
 stx it
 lda.l ITEMS+I_KIND,x
 beq @np
 jsr IconId
 jsr IconLoad
@np:
 plx
 txa
 clc
 adc #ITEM_BYTES
 tax
 cpx #DROP0
 bcc @p
 jsr BagDraw
 jsl FarMenuSend            ; both maps now (the screen is blank)
 sep #$20
 .a8
 lda #$80
 sta $420C                  ; the bars again: the picture from the next frame
 rep #$20
 .a16
 rts

; -> A = the picture of piece `it` (icons.c icon_id)
IconId:
 .a16
 .i16
 ldx it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_POTION
 bne @ns
 lda.l ITEMS+I_BASE,x
 beq @heal
 cmp #1
 beq @stam
 lda #133
 rts
@heal:
 lda #120
 rts
@stam:
 lda #123
 rts
@ns:
 cmp #KIND_SCROLL
 bne @nk
 lda.l ITEMS+I_BASE,x
 beq @portal
 cmp #2
 beq @book
 lda #122
 rts
@portal:
 lda #121
 rts
@book:
 lda #132
 rts
@nk:
 cmp #KIND_KEY
 bne @gear
 lda #131
 rts
@gear:
 jsr ItemDef
 ldx it
 lda.l ITEMS+I_RAR,x
 cmp #RAR_UNIQUE
 beq @u
 jsr BaseOff
 lda.l base_tab+2,x
 and #$00FF
 sta r4
 bra @pic
@u:
 lda.l ITEMS+I_IDENT,x
 beq @ut
 lda rSlot
 bne @ut
 lda.l ITEMS+I_BASE,x
 cmp #7                     ; the first seven uniques are weapons with their own pictures
 bcs @ut
 clc
 adc #124
 rts
@ut:
 jsr UniqueOff
 lda.l unique_tab+2,x
 and #$00FF
 sta r5
 stz r4
 ldx #1
@t:
 lda.l tier_level,x
 and #$00FF
 cmp r5
 beq @le
 bcs @pic
@le:
 stx r4
 inx
 cpx #TIER_COUNT
 bcc @t
@pic:
 lda rSlot
 bne @armour
 lda rFam
 asl
 asl
 asl
 clc
 adc r4
 rts
@armour:
 dec a
 asl
 asl
 asl
 clc
 adc r4
 clc
 adc #72
 rts

; A = a picture: copied to video memory unless it is there
IconLoad:
 .a16
 .i16
 sta r5
 asl
 tax
 lda.l ICONAT,x
 beq @load
 rts
@load:
 lda bagTile
 sta.l ICONAT,x
 lda r5
 asl
 asl
 asl
 tax
 lda.l icon_info,x
 sta n0
 lda.l icon_info+5,x
 and #$00FF
 sta n1
 lda.l icon_info+2,x
 and #$00FF
 sta rm
 lda.l icon_info+3,x
 and #$00FF
 jsr Mul16                  ; tiles
 lda rl
 pha
 asl4
 asl
 sta n3                     ; * 32 bytes
 lda bagTile
 asl4
 sta n2                     ; * 16 words
 pla
 clc
 adc bagTile
 sta bagTile
 jsl FarDmaV
 rts

; ---------------------------------------------------------------- drawing
; the maps: BG1 cells and pictures (MENUMAP), BG2 words (the text map), then both are marked to be sent
BagDraw:
 .a16
 .i16
 ldx #2046                  ; backdrop
 lda #0
@b:
 sta.l MENUMAP,x
 dex
 dex
 bpl @b
 jsl FarClearText
 lda #str_bag
 jsr Note0
 lda #32 + 1
 ldy #$0400 | HUD_PRIO
 jsr Show
 lda #str_gold2
 jsr Note0
 lda #32 + 20
 ldy #HUD_PRIO
 jsr Show
 ldx #(32 + 25) * 2
 lda gold
 jsl FarPrintNum

 stz r6                     ; the worn boxes
@doll:
 ldx r6
 lda.l doll_x,x
 and #$00FF
 sta dx0
 lda.l doll_y,x
 and #$00FF
 sta dy0
 lda.l doll_w,x
 and #$00FF
 sta dw
 lda.l doll_h,x
 and #$00FF
 sta dh
 jsr FillBox
 lda r6
 xba
 lsr
 lsr
 clc
 adc #EQUIP0
 sta it
 tax
 lda.l ITEMS+I_KIND,x
 beq @dn
 lda r6
 pha
 jsr IconId
 jsr IconBox                ; centred in the box
 pla
 sta r6
@dn:
 inc r6
 lda r6
 cmp #7
 bcc @doll

 lda #GRID_X                ; the bag
 sta dx0
 lda #GRID_Y
 sta dy0
 lda #BAG_COLS * 2
 sta dw
 lda #BAG_ROWS * 2
 sta dh
 jsr FillCells
 lda #BAG0
 sta r6
@bag:
 ldx r6
 stx it
 lda.l ITEMS+I_KIND,x
 beq @bn
 lda.l ITEMS+I_X,x
 asl
 clc
 adc #GRID_X
 sta dx0
 lda.l ITEMS+I_Y,x
 asl
 clc
 adc #GRID_Y
 sta dy0
 lda r6
 pha
 jsr IconId
 jsr IconAt
 pla
 sta r6
@bn:
 lda r6
 clc
 adc #ITEM_BYTES
 sta r6
 cmp #BAG0 + BAG_SIZE * ITEM_BYTES
 bcc @bag

 lda #str_belt
 jsr Note0
 lda #BELT_Y * 32 + 13
 ldy #HUD_PRIO
 jsr Show
 lda #BELT_X
 sta dx0
 lda #BELT_Y
 sta dy0
 lda #8
 sta dw
 lda #2
 sta dh
 jsr FillCells
 stz r6
@belt:
 lda r6
 xba
 lsr
 lsr
 clc
 adc #BELT0
 sta it
 tax
 lda.l ITEMS+I_KIND,x
 beq @ln
 lda r6
 asl
 clc
 adc #BELT_X
 sta dx0
 lda #BELT_Y
 sta dy0
 lda r6
 pha
 jsr IconId
 jsr IconAt
 pla
 sta r6
@ln:
 inc r6
 lda r6
 cmp #4
 bcc @belt
 jsr BagNumbers
 jsr BagInfo
 jsr BagHint
 jsr BagCursor
 lda #1
 sta menuDirty
 rts

; a framed box over the tile rectangle dx0, dy0, dw, dh (tiles 5..13)
FillBox:
 .a16
 .i16
 stz r3
@y:
 stz r2
@x:
 ldy #8                     ; the middle row's middle piece is 9
 lda r3
 bne @ny
 ldy #5
@ny:
 inc a
 cmp dh
 bne @col
 ldy #11
@col:
 iny
 lda r2
 bne @nx
 dey
@nx:
 inc a
 cmp dw
 bne @put
 iny
@put:
 jsr MapPut
 inc r2
 lda r2
 cmp dw
 bcc @x
 inc r3
 lda r3
 cmp dh
 bcc @y
 rts

; empty cells over the tile rectangle dx0, dy0, dw, dh
FillCells:
 .a16
 .i16
 stz r3                     ; the row
@y:
 stz r2
@x:
 lda r3
 and #1
 asl
 sta r1
 lda r2
 and #1
 clc
 adc r1
 inc a                      ; tiles 1..4
 tay
 jsr MapPut
 inc r2
 lda r2
 cmp dw
 bcc @x
 inc r3
 lda r3
 cmp dh
 bcc @y
 rts

; Y = a map entry for tile (dx0 + r2, dy0 + r3)
MapPut:
 .a16
 .i16
 lda dy0
 clc
 adc r3
 asl4
 asl
 clc
 adc dx0
 clc
 adc r2
 asl
 tax
 tya
 sta.l MENUMAP,x
 rts

; A = a picture, drawn centred in the box dx0, dy0, dw, dh
IconBox:
 .a16
 .i16
 sta r5
 asl
 asl
 asl
 tax
 lda.l icon_info+2,x
 and #$00FF
 sta r0
 lda dw
 sec
 sbc r0
 bmi @nx
 lsr
 clc
 adc dx0
 sta dx0
@nx:
 lda.l icon_info+3,x
 and #$00FF
 sta r0
 lda dh
 sec
 sbc r0
 bmi @ny
 lsr
 clc
 adc dy0
 sta dy0
@ny:
 lda r5
; A = a picture at tile (dx0, dy0)
IconAt:
 .a16
 .i16
 sta r5
 asl
 tax
 lda.l ICONAT,x
 beq @r
 sta r4                     ; its first tile
 lda r5
 asl
 asl
 asl
 tax
 lda.l icon_info+2,x
 and #$00FF
 sta dw
 lda.l icon_info+3,x
 and #$00FF
 sta dh
 lda.l icon_info+4,x
 and #$00FF
 xba
 asl
 asl
 clc
 adc r4
 sta r4                     ; tile and palette
 stz r3
@y:
 stz r2
@x:
 ldy r4
 jsr MapPut
 inc r4
 inc r2
 lda r2
 cmp dw
 bcc @x
 inc r3
 lda r3
 cmp dh
 bcc @y
@r:
 rts

; A = a string in the rules' bank -> namebuf
Note0:
 .a16
 pha
 jsr NameStart
 pla
 jmp Append

; prints namebuf: A = row * 32 + column, Y = attributes
Show:
 .a16
 .i16
 ldx #namebuf
 jsl FarPrintAt
 rts

; the hero's numbers under the doll
BagNumbers:
 .a16
 .i16
 lda #str_dmg
 jsr Note0
 lda #20 * 32 + 1
 ldy #HUD_PRIO
 jsr Show
 jsr NameStart
 lda atkmin
 jsr AppendNum
 lda #45
 jsr AppendChar
 lda atkmax
 jsr AppendNum
 lda #21 * 32 + 2
 ldy #$0400 | HUD_PRIO
 jsr Show
 lda #str_def
 jsr Note0
 lda hdef
 jsr AppendNum
 lda #22 * 32 + 1
 ldy #HUD_PRIO
 jsr Show
 lda #str_life2
 jsr Note0
 lda.w ehp
 jsr AppendNum
 lda #47
 jsr AppendChar
 lda.w emaxhp
 jsr AppendNum
 lda #23 * 32 + 1
 ldy #HUD_PRIO
 jsr Show
 lda #str_str
 jsr Note0
 lda hstr
 jsr AppendNum
 lda #24 * 32 + 1
 ldy #HUD_PRIO
 jsr Show
 rts

; -> A = the piece under the cursor (its offset), $FFFF none
Selected:
 .a16
 .i16
 lda bagZone
 beq @doll
 cmp #Z_BELT
 beq @belt
 lda bagCy
 asl
 sta r0
 asl
 asl
 clc
 adc r0
 clc
 adc bagCx
 asl
 tax
 lda.w bagmap,x
 rts
@doll:
 lda bagDoll
 xba
 lsr
 lsr
 clc
 adc #EQUIP0
 bra @have
@belt:
 lda bagBelt
 xba
 lsr
 lsr
 clc
 adc #BELT0
@have:
 tax
 lda.l ITEMS+I_KIND,x
 beq @none
 txa
 rts
@none:
 lda #$FFFF
 rts

; the words on the piece under the cursor
BagInfo:
 .a16
 .i16
 lda #INFO_Y
 sta infoY
 jsr Selected
 cmp #$FFFF
 bne @item
 lda bagZone
 bne @r
 lda bagDoll                ; an empty box: what goes there
 asl
 tax
 lda.l slot_name,x
 jsr Note0
 ldy #HUD_PRIO | $1400
 jsr InfoLine
 lda #str_nothing
 jsr Note0
 ldy #HUD_PRIO | $1400
 jmp InfoLine
@r:
 rts
@item:
 sta it
 sta infoIt
 jsr ItemName
 xba
 asl
 asl
 ora #HUD_PRIO
 sta infoCol
 jsr InfoWrap               ; the name, on two lines if need be
 lda infoIt
 sta it
 ldx it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 beq @gear
 cmp #KIND_POTION
 bne @s
 lda.l ITEMS+I_BASE,x
 asl
 tax
 lda.l potion_text,x
 bra @say
@s:
 cmp #KIND_SCROLL
 bne @k
 lda.l ITEMS+I_BASE,x
 asl
 tax
 lda.l scroll_text,x
 bra @say
@k:
 lda.l key_text
@say:
 jsr Note0
 ldy #HUD_PRIO
 jmp InfoLine
@gear:
 jsr ItemDef
 lda rFam
 bmi @slot
 asl
 tax
 lda.l family_name,x
 bra @type
@slot:
 lda rSlot
 asl
 tax
 lda.l slot_name,x
@type:
 jsr Note0
 ldy #HUD_PRIO | $1400
 jsr InfoLine
 jsr ItemNumbers
 lda iWmax
 beq @nd
 lda #str_dmg2
 jsr Note0
 lda iWmin
 jsr AppendNum
 lda #45
 jsr AppendChar
 lda iWmax
 jsr AppendNum
 ldy #HUD_PRIO
 jsr InfoLine
@nd:
 lda iDef
 beq @nf
 lda #str_def
 ldx iDef
 jsr InfoNum
@nf:
 lda iHp
 beq @nh
 lda #str_life3
 ldx iHp
 jsr InfoNum
@nh:
 lda iStr
 beq @ns
 lda #str_str
 ldx iStr
 jsr InfoNum
@ns:
 lda infoIt
 sta it
 jsr ItemDef
 lda rReq
 beq @nl
 lda #str_needs
 jsr Note0
 lda rReq
 jsr AppendNum
 ldy #HUD_PRIO
 lda level
 cmp rReq
 bcs @ok
 ldy #HUD_PRIO | $1C00
@ok:
 jsr InfoLine
@nl:
 ldx infoIt
 lda.l ITEMS+I_IDENT,x
 bne @mods
 lda #str_unid
 jsr Note0
 ldy #HUD_PRIO | $1C00
 jmp InfoLine
@mods:
 lda.l ITEMS+I_NMODS,x
 beq @done
 sta infoMods
 stz infoMod
@m:
 lda infoMod
 asl
 clc
 adc infoIt
 tax
 lda.l ITEMS+I_VALS,x
 tay
 lda.l ITEMS+I_KEYS,x
 cmp #K_HP                  ; (life, strength and defence are in the numbers above)
 beq @skip
 cmp #K_STR
 beq @skip
 cmp #K_DEF
 beq @skip
 jsr ModLine
 ldy #HUD_PRIO | $0800
 jsr InfoLine
@skip:
 inc infoMod
 lda infoMod
 cmp infoMods
 bcc @m
@done:
 rts

InfoNum:                     ; A = a label, X = its number
 .a16
 phx
 jsr Note0
 pla
 jsr AppendNum
 ldy #HUD_PRIO
; namebuf on the next line of the panel, Y = attributes
InfoLine:
 .a16
 .i16
 lda infoY
 cmp #HINT_Y
 bcs @r
 asl4
 asl
 clc
 adc #INFO_X
 jsr Show
 inc infoY
@r:
 rts

; the name in namebuf, broken at a space when it is longer than the panel
InfoWrap:
 .a16
 .i16
 lda nlen
 cmp #INFO_W + 1
 bcc @one
 ldy #INFO_W
@f:
 lda.w namebuf,y
 and #$00FF
 cmp #32
 beq @cut
 dey
 bne @f
 ldy #INFO_W
@cut:
 sty infoCut
 lda.w namebuf,y
 pha
 and #$FF00
 sta.w namebuf,y
 ldy infoCol
 jsr InfoLine
 pla
 ldy infoCut
 sta.w namebuf,y
 ldx infoCut                ; the rest moved to the front
 inx
 ldy #0
@mv:
 lda.w namebuf,x
 sta.w namebuf,y
 and #$00FF
 beq @one
 inx
 iny
 bra @mv
@one:
 ldy infoCol
 jmp InfoLine

BagHint:
 .a16
 .i16
 lda msgp
 beq @h
 jsr Note0
 lda #HINT_Y * 32 + 1
 ldy #HUD_PRIO | $0400
 jmp Show
@h:
 lda bagIdent
 cmp #$FFFF
 beq @n
 lda #str_hint_id
 bra @s
@n:
 lda bagZone
 cmp #Z_GRID
 beq @g
 lda #str_hint_off
 bra @s
@g:
 lda #str_hint
@s:
 jsr Note0
 lda #HINT_Y * 32 + 1
 ldy #HUD_PRIO | $1400
 jmp Show

; the frame round the piece or cell under the cursor
BagCursor:
 .a16
 .i16
 lda bagZone
 beq @doll
 cmp #Z_BELT
 beq @belt
 jsr Selected
 cmp #$FFFF
 beq @cell
 sta it
 jsr ItemSize
 ldx it
 lda.l ITEMS+I_X,x
 asl
 clc
 adc #GRID_X
 sta dx0
 lda.l ITEMS+I_Y,x
 asl
 clc
 adc #GRID_Y
 sta dy0
 lda rW
 asl
 sta dw
 lda rH
 asl
 sta dh
 bra @draw
@cell:
 lda bagCx
 asl
 clc
 adc #GRID_X
 sta dx0
 lda bagCy
 asl
 clc
 adc #GRID_Y
 sta dy0
 lda #2
 sta dw
 sta dh
 bra @draw
@belt:
 lda bagBelt
 asl
 clc
 adc #BELT_X
 sta dx0
 lda #BELT_Y
 sta dy0
 lda #2
 sta dw
 sta dh
 bra @draw
@doll:
 ldx bagDoll
 lda.l doll_x,x
 and #$00FF
 sta dx0
 lda.l doll_y,x
 and #$00FF
 sta dy0
 lda.l doll_w,x
 and #$00FF
 sta dw
 lda.l doll_h,x
 and #$00FF
 sta dh
@draw:
 stz r3
@y:
 stz r2
@x:
 stz r0                     ; bit 0 left, 1 right, 2 top, 3 bottom edge
 lda r2
 bne @nl
 inc r0
@nl:
 inc a
 cmp dw
 bne @nr
 lda r0
 ora #2
 sta r0
@nr:
 lda r3
 bne @nt
 lda r0
 ora #4
 sta r0
 lda r3
@nt:
 inc a
 cmp dh
 bne @nb
 lda r0
 ora #8
 sta r0
@nb:
 ldx r0
 lda.l cur_of,x
 and #$00FF
 cmp #$00FF
 beq @skip
 clc
 adc #CUR_BASE | $0400 | HUD_PRIO
 pha
 lda dy0
 clc
 adc r3
 asl4
 asl
 clc
 adc dx0
 clc
 adc r2
 asl
 tax
 pla
 jsl FarPutTile
@skip:
 inc r2
 lda r2
 cmp dw
 bcc @x
 inc r3
 lda r3
 cmp dh
 bcs @_far3
 jmp @y
@_far3:
 rts
; for each mix of edges the cursor's tile: corners 0-3, edges 4 top, 5 bottom, 6 left, 7 right
cur_of: .byte $FF, 6, 7, $FF, 4, 0, 1, $FF, 5, 2, 3, $FF, $FF, $FF, $FF, $FF

; ---------------------------------------------------------------- the buttons
BagInput:
 .a16
 .i16
 lda padnew
 and #PAD_B | PAD_SELECT | PAD_START
 beq @nc
 lda bagIdent
 cmp #$FFFF
 beq @close
 lda #$FFFF                 ; not reading after all
 sta bagIdent
 stz msgp
 jmp BagDraw
@close:
 jmp BagClose
@nc:
 lda padnew
 and #PAD_L | PAD_R
 beq @nt
 jsr BagClose
 jsl FarStatsOpen
 rts
@nt:
 lda padnew
 and #PAD_UP
 beq @nu
 ldy #0
 jmp MoveCursor
@nu:
 lda padnew
 and #PAD_DOWN
 beq @nd
 ldy #1
 jmp MoveCursor
@nd:
 lda padnew
 and #PAD_LEFT
 beq @nlf
 ldy #2
 jmp MoveCursor
@nlf:
 lda padnew
 and #PAD_RIGHT
 beq @nri
 ldy #3
 jmp MoveCursor
@nri:
 lda padnew
 and #PAD_A
 beq @na
 jmp PressA
@na:
 lda padnew
 and #PAD_X
 beq @nx
 jmp PressX
@nx:
 lda padnew
 and #PAD_Y
 beq @ny
 jmp PressY
@ny:
 rts

; Y = up 0, down 1, left 2, right 3
MoveCursor:
 .a16
 .i16
 stz msgp
 sty mvDir
 lda bagZone
 bne @_far0
 jmp @doll
@_far0:
 cmp #Z_BELT
 bne @_far1
 jmp @belt
@_far1:
 jsr Selected               ; the grid: past the whole piece under the cursor
 cmp #$FFFF
 beq @one
 sta it
 jsr ItemSize
 ldx it
 lda.l ITEMS+I_X,x
 sta bx0
 lda.l ITEMS+I_Y,x
 sta by0
 bra @mv
@one:
 lda bagCx
 sta bx0
 lda bagCy
 sta by0
 lda #1
 sta rW
 sta rH
@mv:
 lda mvDir
 beq @gu
 cmp #1
 beq @gd
 cmp #2
 beq @gl
 lda bx0
 clc
 adc rW
 cmp #BAG_COLS
 bcs @redraw
 sta bagCx
 bra @redraw
@gl:
 lda bx0
 beq @todoll
 dec a
 sta bagCx
 bra @redraw
@gu:
 lda by0
 beq @redraw
 dec a
 sta bagCy
 bra @redraw
@gd:
 lda by0
 clc
 adc rH
 cmp #BAG_ROWS
 bcs @tobelt
 sta bagCy
 bra @redraw
@tobelt:
 lda #Z_BELT
 sta bagZone
 lda bagCx
 sec
 sbc #3
 bpl @b1
 lda #0
@b1:
 lsr
 cmp #4
 bcc @b2
 lda #3
@b2:
 sta bagBelt
 bra @redraw
@todoll:
 lda #Z_DOLL
 sta bagZone
 ldx bagCy                  ; the box beside this row: amulet, shield, shield, legs
 lda.l row_doll,x
 and #$00FF
 sta bagDoll
@redraw:
 jmp BagDraw
@belt:
 lda mvDir
 bne @bd
 lda #Z_GRID
 sta bagZone
 lda #BAG_ROWS - 1
 sta bagCy
 lda bagBelt
 asl
 clc
 adc #3
 sta bagCx
 bra @redraw
@bd:
 cmp #2
 bne @br
 lda bagBelt
 bne @bl1
 lda #Z_DOLL
 sta bagZone
 lda #3
 sta bagDoll
 bra @redraw
@bl1:
 dec bagBelt
 bra @redraw
@br:
 cmp #3
 bne @redraw
 lda bagBelt
 cmp #3
 bcs @redraw
 inc bagBelt
 bra @redraw
@doll:
 lda bagDoll
 asl
 asl
 clc
 adc mvDir
 tax
 lda.l doll_nav,x
 and #$00FF
 cmp #$00FF
 beq @redraw
 cmp #$0080
 beq @togrid
 sta bagDoll
 bra @redraw
@togrid:
 lda #Z_GRID
 sta bagZone
 stz bagCx
 ldx bagDoll
 lda.l doll_row,x
 and #$00FF
 sta bagCy
 jmp @redraw
row_doll: .byte 6, 4, 4, 3

PressA:
 .a16
 .i16
 stz msgp
 jsr Selected
 cmp #$FFFF
 bne @some
 jmp BagDraw
@some:
 sta it
 ldx bagIdent
 cpx #$FFFF
 beq @noid
 jmp Identify
@noid:
 ldx bagZone
 cpx #Z_GRID
 beq @grid
 tax                        ; worn or on the belt: back into the bag
 jsr BackToBag
 bcs @moved
 lda #msg_bagfull
 sta msgp
 jmp BagDraw
@moved:
 jsr StatsRecalc
 bra @sound
@grid:
 tax
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 bne @thing
 jsr Equip
 bcc @redraw
 bra @sound
@thing:
 cmp #KIND_KEY
 beq @redraw
 ldx it
 jsr BeltPut
 bcs @sound
 lda #msg_beltfull
 sta msgp
 bra @redraw
@sound:
 lda #SFX_PICK
 jsl FarSfx
@redraw:
 jsr BagRebuild
 jmp BagDraw

PressX:
 .a16
 .i16
 stz msgp
 jsr Selected
 cmp #$FFFF
 beq @r
 tax
 sta it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 beq @r
 cmp #KIND_SCROLL
 bne @use
 lda.l ITEMS+I_BASE,x
 cmp #1
 bne @use
 stx bagIdent               ; a Scroll of Identify: now the piece it reads
 lda #msg_choose
 sta msgp
 jmp BagDraw
@use:
 lda #$FFFF
 sta bagIdent
 jsr UseThing
 bcc @r
 jsr BagRebuild
 lda #SFX_DRINK
 jsl FarSfx
@r:
 jmp BagDraw

; reads the scroll at bagIdent on piece `it`
Identify:
 .a16
 .i16
 ldx it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 bne @no
 lda.l ITEMS+I_IDENT,x
 bne @no
 lda #1
 sta.l ITEMS+I_IDENT,x
 ldx bagIdent
 jsr ItemClear
 lda #$FFFF
 sta bagIdent
 jsr BagRebuild
 jsr StatsRecalc
 lda #msg_identd
 sta msgp
 lda #SFX_LEVEL
 jsl FarSfx
 jmp BagSetup               ; (a unique shows its own picture now)
@no:
 lda #msg_known
 sta msgp
 jmp BagDraw

; the piece under the cursor falls at the hero's feet
PressY:
 .a16
 .i16
 stz msgp
 lda #$FFFF
 sta bagIdent
 jsr Selected
 cmp #$FFFF
 beq @r
 sta it
 ldx #0
 ldy #0
 lda #2
 jsl FarDrop
 bcs @fell
 lda #msg_nofloor
 sta msgp
 bra @r
@fell:
 tya
 xba
 lsr
 lsr
 lsr
 clc
 adc #DROP0
 tay
 ldx it
 jsr ItemCopy
 ldx it
 jsr ItemClear
 jsr BagRebuild
 jsr StatsRecalc
@r:
 jmp BagDraw

BagClose:
 .a16
 .i16
 sep #$20
 .a8
 stz $420C
 lda #$80
 sta $2100
 rep #$20
 .a16
 stz inMenu
 stz msgp
 stz mode
 jsl FarRestoreVideo        ; the colours, the layers; the world is drawn again
 rts
