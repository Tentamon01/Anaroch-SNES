; The pieces (items.c of the N64 version): what they are, how big, their numbers, the bag, the worn slots, the belt.
; `it` is the piece worked on (its offset in ITEMS).

; item copy: X = from, Y = to (offsets)
ItemCopy:
 .a16
 .i16
 phx
 phy
 lda #ITEM_BYTES / 2
 sta r7
@l:
 lda.l ITEMS,x
 phx
 tyx
 sta.l ITEMS,x
 plx
 inx
 inx
 iny
 iny
 dec r7
 bne @l
 ply
 plx
 rts

; X = the place to empty
ItemClear:
 .a16
 .i16
 phx
 ldy #ITEM_BYTES / 2
 lda #0
@l:
 sta.l ITEMS,x
 inx
 inx
 dey
 bne @l
 plx
 rts

; rSlot, rFam, rReq of piece `it` (gear; for anything else rSlot = $FFFF)
ItemDef:
 .a16
 .i16
 ldx it
 stz rReq
 lda #$FFFF
 sta rSlot
 sta rFam
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 bne @r
 lda.l ITEMS+I_RAR,x
 cmp #RAR_UNIQUE
 beq @u
 jsr BaseOff
 lda.l base_tab,x
 and #$00FF
 sta rSlot
 lda.l base_tab+1,x
 jsr SByte
 sta rFam
 lda.l base_tab+3,x
 and #$00FF
 sta rReq
@r:
 rts
@u:
 jsr UniqueOff
 lda.l unique_tab,x
 and #$00FF
 sta rSlot
 lda.l unique_tab+1,x
 jsr SByte
 sta rFam
 lda.l unique_tab+3,x
 and #$00FF
 sta rReq
 rts

SByte:                       ; the low byte of A with its sign
 .a16
 and #$00FF
 cmp #$0080
 bcc @r
 ora #$FF00
@r:
 rts

; X = the offset in base_tab of piece `it`
BaseOff:
 .a16
 .i16
 ldx it
 lda.l ITEMS+I_BASE,x
 asl4
 tax
 rts
UniqueOff:                   ; 34 bytes each
 .a16
 .i16
 ldx it
 lda.l ITEMS+I_BASE,x
 asl
 sta r7
 asl4
 clc
 adc r7
 tax
 rts

; rW, rH: the cells piece `it` covers
ItemSize:
 .a16
 .i16
 jsr ItemDef
 lda #1
 sta rW
 sta rH
 lda rSlot
 bmi @r
 beq @weapon
 tax
 lda.l slot_w,x
 and #$00FF
 sta rW
 lda.l slot_h,x
 and #$00FF
 sta rH
@r:
 rts
@weapon:
 ldx rFam
 lda.l family_w,x
 and #$00FF
 sta rW
 lda.l family_h,x
 and #$00FF
 sta rH
 rts

; iWmin, iWmax, iStr, iHp, iDef of piece `it`
ItemNumbers:
 .a16
 .i16
 stz iWmin
 stz iWmax
 stz iStr
 stz iHp
 stz iDef
 ldx it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 beq @gear
 rts
@gear:
 lda.l ITEMS+I_RAR,x
 cmp #RAR_UNIQUE
 bne @_far0
 jmp @unique
@_far0:
 jsr BaseOff
 lda.l base_tab+4,x
 sta iWmin
 lda.l base_tab+6,x
 sta iWmax
 lda.l base_tab+8,x
 sta iStr
 lda.l base_tab+10,x
 sta iHp
 lda.l base_tab+12,x
 sta iDef
 ldx it
 lda.l ITEMS+I_RAR,x
 bne @mods
 lda iWmin                  ; a poor piece: three quarters of the numbers
 jsr ThreeQ
 sta iWmin
 lda iWmax
 jsr ThreeQ
 sta iWmax
 lda iStr
 jsr ThreeQ
 sta iStr
 lda iHp
 jsr ThreeQ
 sta iHp
 lda iDef
 jsr ThreeQ
 sta iDef
@mods:                      ; properties that add to the plain numbers
 ldx it
 lda.l ITEMS+I_NMODS,x
 beq @r
 sta r6
 ldx it
@m:
 lda.l ITEMS+I_KEYS,x
 cmp #K_HP
 bne @s
 lda.l ITEMS+I_VALS,x
 clc
 adc iHp
 sta iHp
 bra @n
@s:
 cmp #K_STR
 bne @d
 lda.l ITEMS+I_VALS,x
 clc
 adc iStr
 sta iStr
 bra @n
@d:
 cmp #K_DEF
 bne @n
 lda.l ITEMS+I_VALS,x
 clc
 adc iDef
 sta iDef
@n:
 inx
 inx
 dec r6
 bne @m
@r:
 rts
@unique:
 jsr UniqueOff
 lda.l unique_tab+4,x
 sta iWmin
 lda.l unique_tab+6,x
 sta iWmax
 lda.l unique_tab+8,x
 sta iStr
 lda.l unique_tab+10,x
 sta iHp
 lda.l unique_tab+12,x
 sta iDef
 rts
ThreeQ:
 .a16
 sta r7
 asl
 clc
 adc r7
 lsr
 lsr
 rts

; ---------------------------------------------------------------- the bag
; which piece covers each cell
BagRebuild:
 .a16
 .i16
 ldx #BAG_SIZE * 2 - 2
 lda #$FFFF
@c:
 sta.w bagmap,x
 dex
 dex
 bpl @c
 lda it
 pha
 lda #BAG0
 sta it
@l:
 ldx it
 lda.l ITEMS+I_KIND,x
 beq @n
 jsr ItemSize
 ldx it
 lda.l ITEMS+I_Y,x
 sta r0                     ; the row
 lda rH
 sta r1
@row:
 lda r0
 asl                        ; row * 10
 sta r3
 asl
 asl
 clc
 adc r3
 ldx it
 clc
 adc.l ITEMS+I_X,x
 asl
 tax
 lda rW
 sta r2
@cell:
 lda it
 sta.w bagmap,x
 inx
 inx
 dec r2
 bne @cell
 inc r0
 dec r1
 bne @row
@n:
 lda it
 clc
 adc #ITEM_BYTES
 sta it
 cmp #BAG0 + BAG_SIZE * ITEM_BYTES
 bcc @l
 pla
 sta it
 rts

; would an rW x rH piece lie with its corner at (bx0, by0), not counting the piece bold? carry set: yes
BagFits:
 .a16
 .i16
 lda bx0
 clc
 adc rW
 cmp #BAG_COLS + 1
 bcs @no
 lda by0
 clc
 adc rH
 cmp #BAG_ROWS + 1
 bcs @no
 lda by0
 sta r0
 lda rH
 sta r1
@row:
 lda r0
 asl
 sta r3
 asl
 asl
 clc
 adc r3
 clc
 adc bx0
 asl
 tax
 lda rW
 sta r2
@cell:
 lda.w bagmap,x
 cmp #$FFFF
 beq @free
 cmp bold
 bne @no
@free:
 inx
 inx
 dec r2
 bne @cell
 inc r0
 dec r1
 bne @row
 sec
 rts
@no:
 clc
 rts

; puts the piece at offset bsrc at (bx0, by0) into a free bag place; carry clear if the cells are taken
BagPlace:
 .a16
 .i16
 lda bsrc
 sta it
 jsr ItemSize
 lda #$FFFF
 sta bold
 jsr BagFits
 bcc @r
 ldx #BAG0
@f:
 lda.l ITEMS+I_KIND,x
 beq @got
 txa
 clc
 adc #ITEM_BYTES
 tax
 cpx #BAG0 + BAG_SIZE * ITEM_BYTES
 bcc @f
 clc
@r:
 rts
@got:
 txy
 ldx bsrc
 jsr ItemCopy
 tyx
 lda bx0
 sta.l ITEMS+I_X,x
 lda by0
 sta.l ITEMS+I_Y,x
 sty bdst
 jsr BagRebuild
 sec
 rts

; the piece at bsrc into the first place it fits, column by column as Diablo fills it; carry clear: the bag is full
BagAdd:
 .a16
 .i16
 stz bx0
@x:
 stz by0
@y:
 jsr BagPlace
 bcs @r
 inc by0
 lda by0
 cmp #BAG_ROWS
 bcc @y
 inc bx0
 lda bx0
 cmp #BAG_COLS
 bcc @x
 clc
@r:
 rts

; the bag piece at X onto a free belt place (gear and keys stay in the bag); carry clear: no room
BeltPut:
 .a16
 .i16
 stx r4
 lda.l ITEMS+I_KIND,x
 beq @no
 cmp #KIND_GEAR
 beq @no
 cmp #KIND_KEY
 beq @no
 ldy #BELT0
@f:
 tyx
 lda.l ITEMS+I_KIND,x
 beq @got
 tya
 clc
 adc #ITEM_BYTES
 tay
 cpy #BELT0 + 4 * ITEM_BYTES
 bcc @f
@no:
 clc
 rts
@got:
 ldx r4
 jsr ItemCopy
 jsr ItemClear
 jsr BagRebuild
 sec
 rts

; the belt (or worn) piece at X back into the bag; carry clear: the bag is full
BackToBag:
 .a16
 .i16
 stx bsrc
 jsr BagAdd
 bcc @r
 ldx bsrc
 jsr ItemClear
 sec
@r:
 rts

; wears the bag piece at X; what was worn goes into the bag, into the freed place if it fits.
; carry clear: msgp says why not
Equip:
 .a16
 .i16
 stx it
 stx r4
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 beq @gear
 clc
 rts
@gear:
 jsr ItemDef
 lda level
 cmp rReq
 bcs @lvl
 lda #msg_level
 sta msgp
 clc
 rts
@lvl:
 lda rSlot                  ; worn place = EQUIP0 + slot * 64
 xba
 lsr
 lsr
 clc
 adc #EQUIP0
 sta r5
 ldx r4
 ldy #TEMP2
 jsr ItemCopy
 ldx r4
 jsr ItemClear
 jsr BagRebuild
 ldx r5
 lda.l ITEMS+I_KIND,x
 beq @wear
 stx bsrc                   ; the old one: where the new one lay, else anywhere
 ldx #TEMP2
 lda.l ITEMS+I_X,x
 sta bx0
 lda.l ITEMS+I_Y,x
 sta by0
 jsr BagPlace
 bcs @wear
 jsr BagAdd
 bcs @wear
 ldx #TEMP2                 ; no room: nothing changes
 stx bsrc
 lda.l ITEMS+I_X,x
 sta bx0
 lda.l ITEMS+I_Y,x
 sta by0
 jsr BagPlace
 lda #msg_noroom
 sta msgp
 clc
 rts
@wear:
 ldx #TEMP2
 ldy r5
 jsr ItemCopy
 jsr StatsRecalc
 sec
 rts

; ---------------------------------------------------------------- things that are drunk and read
; a potion, a scroll or a key into TEMP: A = kind, Y = which
MakeThing:
 .a16
 .i16
 pha
 phy
 ldx #TEMP
 jsr ItemClear
 ply
 pla
 ldx #TEMP
 sta.l ITEMS+I_KIND,x
 tya
 sta.l ITEMS+I_BASE,x
 lda #RAR_NORMAL
 sta.l ITEMS+I_RAR,x
 lda #1
 sta.l ITEMS+I_IDENT,x
 lda #$FFFF
 sta.l ITEMS+I_PRE,x
 sta.l ITEMS+I_SUF,x
 rts

; a plain piece of base A into TEMP
MakeNormal:
 .a16
 .i16
 pha
 lda #KIND_GEAR
 ldy #0
 jsr MakeThing
 pla
 ldx #TEMP
 sta.l ITEMS+I_BASE,x
 asl4
 tax
 lda.l base_tab+2,x         ; its tier's level
 and #$00FF
 tax
 lda.l tier_level,x
 and #$00FF
 ldx #TEMP
 sta.l ITEMS+I_ILVL,x
 rts

; drinks or reads the piece at X; carry set when it was used up (msgp: a word about it)
UseThing:
 .a16
 .i16
 stx it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_POTION
 beq @potion
 cmp #KIND_SCROLL
 beq @scroll
 cmp #KIND_KEY
 bne @no0
 lda #msg_nochest
 sta msgp
@no0:
 clc
 rts
@potion:
 lda.l ITEMS+I_BASE,x
 beq @heal
 cmp #1
 beq @stam
 lda points                 ; the Elixir: three stat points
 clc
 adc #3
 sta points
 lda #msg_points3
 jmp @used
@heal:
 lda.w ehp
 cmp.w emaxhp
 bcc @h1
 lda #msg_fulllife
 sta msgp
 clc
 rts
@h1:
 lda.w emaxhp
 jsr PotionShare
 clc
 adc.w ehp
 cmp.w emaxhp
 bcc @h3
 lda.w emaxhp
@h3:
 sta.w ehp
 stz msgp
 bra @gone
@stam:
 lda stam
 cmp maxStam
 bcc @s1
 lda #msg_fullstam
 sta msgp
 clc
 rts
@s1:
 lda maxStam
 jsr PotionShare
 clc
 adc stam
 cmp maxStam
 bcc @s2
 lda maxStam
@s2:
 sta stam
 lda #msg_stamina
 bra @used
@scroll:
 lda.l ITEMS+I_BASE,x
 beq @portal
 cmp #1
 beq @identify
 cmp #2
 beq @book
 lda heroFlags              ; the Four Winds: +10 % to all resistances, for good
 ora #1
 sta heroFlags
 jsr StatsRecalc
 lda #msg_winds
 bra @used
@book:
 inc skillPts
 lda #msg_skill
 bra @used
@portal:
 jsr OpenPortal             ; (it says why not)
 bcs @gone
 rts
@identify:
 lda #msg_choose
 sta msgp
 clc
 rts
@used:
 sta msgp
@gone:
 ldx it
 jsr ItemClear
 sec
 rts

; what a potion gives back of A: 45 %, potions' bonus on top, at least 1
PotionShare:
 .a16
 .i16
 sta rm
 lda #45
 jsr Mul16
 lda #100
 jsr Div32
 ldy pmods+K_POTION_EFFECT_PERCENT*2
 lda rl
 jsr Pct
 cmp #1
 bcs @r
 lda #1
@r:
 rts
