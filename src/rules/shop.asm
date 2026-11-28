; ---------------------------------------------------------------- the merchant, the appraiser, the portal
; (menu.c shop_stock / shop_a, items.c item_value, main.c appraise)
SHOP0 = 64 * 64              ; his table: 24 pieces after the hero's own places
SHOP_SIZE = 24
SHOP_ENDLESS = 5             ; potions, scrolls and keys never run out
SHOPLIST = $7E3800           ; what the screen lists: pieces' offsets
SHOP_ROWS = 10
SHOP_TOP = 5                 ; the first row of the list

; new wares: the five that never run out, then up to twelve Normal and Magic pieces of the hero's level
ShopStock:
 .a16
 .i16
 ldx #SHOP0
 lda #SHOP_SIZE
 sta q0
@c:
 jsr ItemClear
 txa
 clc
 adc #ITEM_BYTES
 tax
 dec q0
 bne @c
 stz q0                     ; the slot
@e:
 lda q0
 asl
 asl
 tax
 lda.l shop_goods+2,x
 tay
 lda.l shop_goods,x
 jsr MakeThing
 lda q0
 jsr SlotAt
 tay
 ldx #TEMP
 jsr ItemCopy
 inc q0
 lda q0
 cmp #SHOP_ENDLESS
 bcc @e
 stz q1                     ; tries
@r:
 lda level
 sta rlvl
 stz rsrc
 jsr RollDrop
 bcc @n
 lda.l ITEMS+TEMP+I_RAR
 cmp #RAR_NORMAL
 beq @keep
 cmp #RAR_MAGIC
 bne @n
@keep:
 lda #1
 sta.l ITEMS+TEMP+I_IDENT
 lda q0
 jsr SlotAt
 tay
 ldx #TEMP
 jsr ItemCopy
 inc q0
 lda q0
 cmp #SHOP_ENDLESS + 12
 bcs @done
@n:
 inc q1
 lda q1
 cmp #600
 bcc @r
@done:
 rts
shop_goods: .word KIND_POTION, 0, KIND_POTION, 1, KIND_SCROLL, 0, KIND_SCROLL, 1, KIND_KEY, 0

SlotAt:                      ; A = a slot of his table -> A = its offset
 .a16
 xba
 lsr
 lsr
 clc
 adc #SHOP0
 rts

; ---------------------------------------------------------------- prices
; A = a piece -> A = what it costs to buy (at most 65535)
ItemValue:
 .a16
 .i16
 tax
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 beq @gear
 cmp #KIND_POTION
 bne @np
 lda.l ITEMS+I_BASE,x
 cmp #2
 beq @dear
 lda #30
 rts
@dear:
 lda #3000
 rts
@np:
 cmp #KIND_KEY
 bne @scroll
 lda #75
 rts
@scroll:
 lda.l ITEMS+I_BASE,x
 beq @portal
 cmp #1
 bne @dear
 lda #45
 rts
@portal:
 lda #60
 rts
@gear:
 phx
 jsr BaseValue
 plx
 lda.l ITEMS+I_RAR,x
 beq @poor
 cmp #RAR_MAGIC
 beq @magic
 cmp #RAR_RARE
 beq @rare
 cmp #RAR_UNIQUE
 beq @unique
 lda q3
 rts
@poor:                       ; two fifths
 lda q3
 sta rm
 lda #2
 jsr Mul16
 lda #5
 bra @div
@magic:                      ; (25 + 4 a property) tenths
 lda.l ITEMS+I_NMODS,x
 asl
 asl
 clc
 adc #25
 sta q2
 lda q3
 sta rm
 lda q2
 jsr Mul16
 lda #10
@div:
 jsr Div32
 lda rh
 bne @max
 lda rl
 rts
@rare:
 lda #5
 bra @times
@unique:
 lda #10
@times:
 sta q2
 lda q3
 sta rm
 lda q2
 jsr Mul16
 lda rh
 bne @max
 lda rl
 rts
@max:
 lda #$FFFF
 rts

; X = a piece of gear -> q3 = 20 + 6 L + L^2 / 4 for its item level L
BaseValue:
 .a16
 .i16
 lda.l ITEMS+I_ILVL,x
 bne @l
 lda #1
@l:
 sta q3
 sta rm
 jsr Mul16                  ; L * L
 lda rl
 lsr
 lsr
 sta q2
 lda q3
 asl
 sta q3
 asl
 clc
 adc q3                     ; 6 L
 clc
 adc #20
 clc
 adc q2
 sta q3
 rts

; A = a piece -> A = what he pays for it: a quarter; an unread Magic or better as if it had nothing on it
SellValue:
 .a16
 .i16
 tax
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 bne @q
 lda.l ITEMS+I_IDENT,x
 bne @q
 lda.l ITEMS+I_RAR,x
 cmp #RAR_MAGIC
 bcc @q
 jsr BaseValue
 lda q3
 asl
 clc
 adc q3
 lsr
 lsr
 lsr
 rts
@q:
 txa
 jsr ItemValue
 lsr
 lsr
 bne @r
 inc a
@r:
 rts

; A = an unread piece -> A = what the appraiser asks: 40 + 4 L, a half more for a Rare, double for a Unique
IdentCost:
 .a16
 .i16
 tax
 lda.l ITEMS+I_ILVL,x
 asl
 asl
 clc
 adc #40
 sta q3
 lda.l ITEMS+I_RAR,x
 cmp #RAR_RARE
 beq @rare
 cmp #RAR_UNIQUE
 bne @r
 asl q3
@r:
 lda q3
 rts
@rare:
 lsr
 lda q3
 lsr
 clc
 adc q3
 rts

; carry set: the bag piece at X is unread
Unread:
 .a16
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 bne @no
 lda.l ITEMS+I_IDENT,x
 bne @no
 lda.l ITEMS+I_RAR,x
 cmp #RAR_MAGIC
 rts
@no:
 clc
 rts

; The appraiser: first the price, asked again he reads the cheapest first while the gold lasts.
; -> namebuf = what he says, A = what goes under it (0 nothing, 1 ask again)
Appraise:
 .a16
 .i16
 stz s3                     ; pieces
 stz s4                     ; their price
 ldx #BAG0
@c:
 jsr Unread
 bcc @cn
 inc s3
 phx
 txa
 jsr IdentCost
 clc
 adc s4
 bcc @s
 lda #$FFFF
@s:
 sta s4
 plx
@cn:
 txa
 clc
 adc #ITEM_BYTES
 tax
 cpx #BAG0 + BAG_SIZE * ITEM_BYTES
 bcc @c
 lda s3
 bne @some
 lda #str_nosecrets
 jsr Note0
 lda #0
 rts
@some:
 lda appraiseT
 bne @read
 jsr NameStart
 lda s3
 jsr AppendNum
 lda #str_toread
 jsr Append
 lda s4
 jsr AppendNum
 lda #str_goldw
 jsr Append
 lda #300
 sta appraiseT
 lda #1
 rts
@read:
 stz s3                     ; read now
 stz s4                     ; paid
@next:
 stz s5                     ; the cheapest: its place and price
 lda #$FFFF
 sta s6
 ldx #BAG0
@f:
 jsr Unread
 bcc @fn
 phx
 txa
 jsr IdentCost
 plx
 cmp s6
 bcs @fn
 sta s6
 stx s5
@fn:
 txa
 clc
 adc #ITEM_BYTES
 tax
 cpx #BAG0 + BAG_SIZE * ITEM_BYTES
 bcc @f
 lda s6
 cmp #$FFFF
 beq @end
 lda gold
 cmp s6
 bcc @end
 sec
 sbc s6
 sta gold
 lda s4
 clc
 adc s6
 sta s4
 ldx s5
 lda #1
 sta.l ITEMS+I_IDENT,x
 inc s3
 bra @next
@end:
 stz appraiseT
 lda #1
 sta hudflag
 lda s3
 bne @done
 lda #str_cantpay
 jsr Note0
 lda #3
 rts
@done:
 lda #SFX_COIN
 jsl FarSfx
 jsr NameStart
 lda s3
 jsr AppendNum
 lda #str_readfor
 jsr Append
 lda s4
 jsr AppendNum
 lda #str_goldw
 jsr Append
 lda #2
 rts

; ---------------------------------------------------------------- the merchant's screen (page 2 of the bag screen)
ShopOpen:
 .a16
 .i16
 lda #M_BAG
 sta mode
 lda #2
 sta bagPage
 stz shopSell
 stz shopCur
 stz shopTop
 stz shopArm
 stz msgp
 jsr MenuBegin
 jsr MenuColours
 jsr ShopDraw
 jmp MenuShow

; the pieces of this side into SHOPLIST, the cursor kept inside it
ShopList:
 .a16
 .i16
 stz shopN
 ldx #SHOP0
 ldy #SHOP_SIZE
 lda shopSell
 beq @l
 ldx #BAG0
 ldy #BAG_SIZE
@l:
 lda.l ITEMS+I_KIND,x
 beq @n
 phx
 txa
 pha
 lda shopN
 asl
 tax
 pla
 sta.l SHOPLIST,x
 inc shopN
 plx
@n:
 txa
 clc
 adc #ITEM_BYTES
 tax
 dey
 bne @l
 lda shopCur
 cmp shopN
 bcc @in
 lda shopN
 beq @z
 dec a
@z:
 sta shopCur
@in:
 lda shopCur                ; the window follows it
 cmp shopTop
 bcs @below
 sta shopTop
 rts
@below:
 sec
 sbc #SHOP_ROWS - 1
 bmi @r
 cmp shopTop
 bcc @r
 sta shopTop
@r:
 rts

; -> A = the piece under the cursor, $FFFF none
ShopAt:
 .a16
 .i16
 lda shopN
 beq @none
 lda shopCur
 asl
 tax
 lda.l SHOPLIST,x
 rts
@none:
 lda #$FFFF
 rts

ShopDraw:
 .a16
 .i16
 jsr ShopList
 ldx #2046
 lda #0
@b:
 sta.l MENUMAP,x
 dex
 dex
 bpl @b
 jsl FarClearText
 lda #str_gideon
 jsr Note0
 lda #32 + 1
 ldy #$0400 | HUD_PRIO
 jsr Show
 lda #str_goldh
 jsr Note0
 lda gold
 jsr AppendNum
 lda #32 + 21
 ldy #HUD_PRIO
 jsr Show
 lda #str_buy
 jsr Note0
 lda #3 * 32 + 3
 ldy #$0400 | HUD_PRIO
 ldx shopSell
 beq @tb
 ldy #$1400 | HUD_PRIO
@tb:
 jsr Show
 lda #str_sell
 jsr Note0
 lda #3 * 32 + 9
 ldy #$1400 | HUD_PRIO
 ldx shopSell
 beq @ts
 ldy #$0400 | HUD_PRIO
@ts:
 jsr Show
 stz q0                     ; the row
@row:
 lda q0
 clc
 adc shopTop
 cmp shopN
 bcc @have
 jmp @listed
@have:
 sta q1                     ; the line of the list
 asl
 tax
 lda.l SHOPLIST,x
 sta it
 sta s7
 jsr ItemName
 xba                        ; its colour
 asl
 asl
 ora #HUD_PRIO
 sta s8
 sep #$20
 .a8
 stz.w namebuf+22           ; (what fits before the price)
 rep #$20
 .a16
 lda q0
 clc
 adc #SHOP_TOP
 asl4
 asl
 sta s9
 clc
 adc #3
 ldy s8
 jsr Show
 lda q1
 cmp shopCur
 bne @nc
 jsr NameStart
 lda #62                    ; '>'
 jsr AppendChar
 lda s9
 clc
 adc #1
 ldy #$0400 | HUD_PRIO
 jsr Show
@nc:
 lda s7
 ldx shopSell
 bne @sv
 jsr ItemValue
 bra @pv
@sv:
 jsr SellValue
@pv:
 sta s7
 jsr NameStart
 lda s7
 jsr AppendNum
 ldy #HUD_PRIO
 lda shopSell
 bne @col
 lda gold
 cmp s7
 bcs @col
 ldy #$1C00 | HUD_PRIO      ; too dear
@col:
 lda s9
 clc
 adc #31
 sec
 sbc nlen
 jsr Show
 inc q0
 lda q0
 cmp #SHOP_ROWS
 bcs @listed
 jmp @row
@listed:
 jsr ShopAt                 ; the piece's words under the list
 cmp #$FFFF
 beq @hint
 pha
 lda #SHOP_TOP + SHOP_ROWS + 1
 sta infoY
 lda #2
 sta infoX
 pla
 jsr ItemPanel
@hint:
 lda msgp
 beq @h
 jsr Note0
 ldy #HUD_PRIO | $0400
 bra @s
@h:
 lda #str_shop_buy
 ldx shopSell
 beq @hb
 lda #str_shop_sell
@hb:
 jsr Note0
 ldy #HUD_PRIO | $1400
@s:
 lda #HINT_Y * 32 + 1
 jsr Show
 lda #1
 sta menuDirty
 rts

ShopInput:
 .a16
 .i16
 lda padnew
 and #PAD_B | PAD_SELECT | PAD_START
 beq @nc
 jmp BagClose
@nc:
 lda padnew
 and #PAD_L | PAD_R | PAD_LEFT | PAD_RIGHT
 beq @nt
 lda shopSell
 eor #1
 sta shopSell
 stz shopCur
 stz shopTop
 bra @quiet
@nt:
 lda padnew
 and #PAD_UP
 beq @nu
 lda shopCur
 beq @r
 dec shopCur
 bra @quiet
@nu:
 lda padnew
 and #PAD_DOWN
 beq @nd
 lda shopCur
 inc a
 cmp shopN
 bcs @r
 sta shopCur
@quiet:
 stz msgp
 stz shopArm
 jmp ShopDraw
@nd:
 lda padnew
 and #PAD_A
 beq @r
 lda shopSell
 beq @buy
 jsr ShopSellIt
 jmp ShopDraw
@buy:
 jsr ShopBuy
 jmp ShopDraw
@r:
 rts

ShopBuy:
 .a16
 .i16
 jsr ShopAt
 cmp #$FFFF
 beq @r
 sta s7
 jsr ItemValue
 sta s8
 lda gold
 cmp s8
 bcs @pay
 lda #str_nogold
 sta msgp
@r:
 rts
@pay:
 lda s7
 sta bsrc
 cmp #SHOP0 + SHOP_ENDLESS * ITEM_BYTES
 bcs @own
 tax                        ; one of those that never run out: a copy
 ldy #TEMP
 jsr ItemCopy
 lda #TEMP
 sta bsrc
@own:
 jsr BagAdd
 bcs @got
 lda #str_noroom
 sta msgp
 rts
@got:
 lda gold
 sec
 sbc s8
 sta gold
 lda s7
 cmp #SHOP0 + SHOP_ENDLESS * ITEM_BYTES
 bcc @kept
 tax
 jsr ItemClear
@kept:
 lda #str_bought
 sta msgp
 lda #SFX_COIN
 jsl FarSfx
 rts

ShopSellIt:
 .a16
 .i16
 jsr ShopAt
 cmp #$FFFF
 beq @r
 sta s7
 inc a                      ; (so the first place is not "none armed")
 cmp shopArm
 beq @sure
 sta shopArm
 lda #str_again
 sta msgp
@r:
 rts
@sure:
 stz shopArm
 lda s7
 jsr SellValue
 clc
 adc gold
 bcc @g
 lda #$FFFF
@g:
 sta gold
 lda #SHOP_ENDLESS          ; on his table, where it can be bought back
 sta q0
@f:
 lda q0
 jsr SlotAt
 tax
 lda.l ITEMS+I_KIND,x
 beq @free
 inc q0
 lda q0
 cmp #SHOP_SIZE
 bcc @f
 bra @gone
@free:
 txy
 ldx s7
 jsr ItemCopy
@gone:
 ldx s7
 jsr ItemClear
 jsr BagRebuild
 lda #str_sold
 sta msgp
 lda #SFX_COIN
 jsl FarSfx
 rts

; ---------------------------------------------------------------- Town Portal (main.c read_portal_scroll)
; read in the field: a portal opens ahead of the hero. -> carry set when it did
OpenPortal:
 .a16
 .i16
 lda safeArea
 beq @open
 lda #msg_intown
 sta msgp
 clc
 rts
@open:
 lda.w edir
 asl
 tax
 lda.w ex
 lsr4
 sta portalX
 lda.w ey
 lsr4
 sta portalY
 lda.l wspd_hx,x            ; a metre and a half ahead
 sta q0
 cmp #$8000
 ror
 clc
 adc q0
 clc
 adc portalX
 sta portalX
 lda.l wspd_hy,x
 sta q0
 cmp #$8000
 ror
 clc
 adc q0
 clc
 adc portalY
 sta portalY
 lda placeId
 sta portalPlace
 lda #1
 sta portalOn
 sta portalNew
 stz portalT
 lda #msg_portal
 sta msgp
 sec
 rts

; a blue spark rising in the portal at (px, py)
PortalFx:
 .a16
 .i16
 jsl FarRand
 and #15
 sec
 sbc #8
 clc
 adc px
 sta px
 jsl FarRand
 and #7
 sec
 sbc #4
 clc
 adc py
 sta py
 jsl FarRand
 and #7
 sta pz
 lda #1
 sta vz
 stz vx
 stz vy
 lda #22
 ldy #FX_FROST
 jmp Spark

str_gideon:    .byte "GIDEON THE MERCHANT", 0
str_goldh:     .byte "GOLD ", 0
str_buy:       .byte "BUY", 0
str_sell:      .byte "SELL", 0
str_shop_buy:  .byte "A BUY  L SELL  B LEAVE", 0
str_shop_sell: .byte "A SELL  L BUY  B LEAVE", 0
str_nogold:    .byte "NOT ENOUGH GOLD", 0
str_noroom:    .byte "NO ROOM IN THE BAG", 0
str_bought:    .byte "BOUGHT", 0
str_again:     .byte "A AGAIN TO SELL IT", 0
str_sold:      .byte "SOLD", 0
str_nosecrets: .byte "YOUR PACK HOLDS NO SECRETS", 0
str_toread:    .byte " TO READ: ", 0
str_goldw:     .byte " GOLD", 0
str_readfor:   .byte " READ FOR ", 0
str_cantpay:   .byte "YOU CANNOT PAY FOR ONE", 0
