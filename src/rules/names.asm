; Names and property lines, put together in namebuf (a zero-terminated string in low work memory).
RULES_BANK = $2A0000         ; where the names of src/rules.inc are

NameStart:
 .a16
 stz nlen
 stz.w namebuf
 rts

; A = the address of a string in the rules' bank
Append:
 .a16
 .i16
 phx
 phy
 tax
@l:
 lda.l RULES_BANK,x
 and #$00FF
 beq @r
 jsr AppendChar
 inx
 bra @l
@r:
 ply
 plx
 rts

AppendChar:                  ; A = a character
 .a16
 .i16
 ldy nlen
 cpy #46
 bcs @r
 and #$00FF
 sta.w namebuf,y            ; (the zero after it comes with the word's upper byte)
 inc nlen
@r:
 rts

Space:
 .a16
 lda #32
 bra AppendChar

; A = a number
AppendNum:
 .a16
 .i16
 ldy #0
AppendLong:                  ; A = the low word, Y = the high
 .a16
 .i16
 phx
 sta rl
 sty rh
 ldx #0
@d:
 lda #10
 jsr Div32
 lda rem
 clc
 adc #48
 pha
 inx
 lda rl
 ora rh
 bne @d
@o:
 pla
 jsr AppendChar
 dex
 bne @o
 plx
 rts

; the name of piece `it` into namebuf -> A = its text colour (0 white .. 7 red)
ItemName:
 .a16
 .i16
 jsr NameStart
ItemNameAdd:                 ; (after what namebuf holds)
 .a16
 .i16
 ldx it
 lda.l ITEMS+I_KIND,x
 cmp #KIND_GEAR
 bne @nog
 jmp @gear
@nog:
 cmp #KIND_POTION
 bne @np
 lda.l ITEMS+I_BASE,x
 asl
 tax
 lda.l potion_name,x
 jsr Append
 ldx it
 lda.l ITEMS+I_BASE,x
 tax
 lda.l potion_colour,x
 and #$00FF
 rts
@np:
 cmp #KIND_SCROLL
 bne @nk
 lda.l ITEMS+I_BASE,x
 asl
 tax
 lda.l scroll_name,x
 jsr Append
 ldx it
 lda.l ITEMS+I_BASE,x
 cmp #2
 bcc @sw
 lda #1
 rts
@sw:
 lda #0
 rts
@nk:
 lda.l key_name
 jsr Append
 lda #1
 rts
@gear:
 jsr ItemDef
 ldx it
 lda.l ITEMS+I_IDENT,x
 bne @known
 lda.l ITEMS+I_RAR,x
 cmp #RAR_MAGIC
 bcc @known
 jsr BaseName
 jmp @colour
@known:
 ldx it
 lda.l ITEMS+I_RAR,x
 bne @n1
 lda.l ITEMS+I_W1,x         ; poor
 asl
 tax
 lda.l poor_word,x
 jsr Append
 jsr Space
 jsr BaseName
 jmp @colour
@n1:
 cmp #RAR_MAGIC
 bne @n2
 lda.l ITEMS+I_PRE,x
 bmi @nopre
 jsr AffixWord
 jsr Space
@nopre:
 jsr BaseName
 ldx it
 lda.l ITEMS+I_SUF,x
 bmi @colour
 pha
 jsr Space
 pla
 jsr AffixWord
 bra @colour
@n2:
 cmp #RAR_RARE
 bne @n3
 lda rSlot                  ; the words' group: weapons, armour, jewellery
 beq @g0
 cmp #5
 bcc @g1
 lda #24
 bra @g
@g0:
 lda #0
 bra @g
@g1:
 lda #12
@g:
 sta r6
 ldx it
 clc
 adc.l ITEMS+I_W1,x
 asl
 tax
 lda.l rare_first,x
 jsr Append
 ldx it
 lda r6
 clc
 adc.l ITEMS+I_W2,x
 asl
 tax
 lda.l rare_second,x
 jsr Append
 bra @colour
@n3:
 cmp #RAR_UNIQUE
 bne @plain
 lda.l ITEMS+I_BASE,x
 asl
 tax
 lda.l unique_name,x
 jsr Append
 bra @colour
@plain:
 jsr BaseName
@colour:
 ldx it
 lda.l ITEMS+I_RAR,x
 tax
 lda.l rarity_colour,x
 and #$00FF
 rts

; A = an affix: its word for the piece's level
AffixWord:
 .a16
 .i16
 sta r6
 asl
 clc
 adc r6                     ; three names each
 sta r6
 ldx it
 lda.l ITEMS+I_ILVL,x
 cmp #27
 bcc @t
 inc r6
 cmp #54
 bcc @t
 inc r6
@t:
 lda r6
 asl
 tax
 lda.l affix_name,x
 jmp Append

; "<tier> <kind>" of the piece (a unique not yet identified: the plain base of its level)
BaseName:
 .a16
 .i16
 jsr ItemDef
 ldx it
 lda.l ITEMS+I_RAR,x
 cmp #RAR_UNIQUE
 beq @u
 jsr BaseOff
 lda.l base_tab+2,x         ; tier
 and #$00FF
 sta r4
 ldx it
 lda.l ITEMS+I_BASE,x
 sta r5
 lda r4                     ; kind = base - tier * 15
 asl4
 sec
 sbc r4
 sta r6
 lda r5
 sec
 sbc r6
 sta r5
 bra @write
@u:
 jsr UniqueOff
 lda.l unique_tab+2,x
 and #$00FF
 sta r6                     ; its level: the highest tier at or below it
 stz r4
 ldx #1
@t:
 lda.l tier_level,x
 and #$00FF
 cmp r6
 beq @le
 bcs @k
@le:
 stx r4
 inx
 cpx #TIER_COUNT
 bcc @t
@k:
 lda rFam
 bpl @kf
 lda rSlot
 clc
 adc #8                     ; (9 families, then the six other slots)
@kf:
 sta r5
@write:
 lda r4
 asl
 tax
 lda.l tier_name,x
 jsr Append
 jsr Space
 lda r5
 asl
 tax
 lda.l kind_name,x
 jmp Append

; A = a property, Y = its value: its line in namebuf
ModLine:
 .a16
 .i16
 sta nkey
 sty nval
 jsr NameStart
 lda nkey
 asl
 tax
 lda.l mod_name,x
 sta nsrc
@l:
 ldx nsrc
 lda.l RULES_BANK,x
 and #$00FF
 beq @r
 inc nsrc
 cmp #35                    ; '#': the number
 beq @num
 jsr AppendChar
 bra @l
@num:
 ldx nkey
 lda.l mod_tenths,x
 and #$00FF
 bne @tenth
 lda nval
 jsr AppendNum
 bra @l
@tenth:
 lda nval
 sta rl
 stz rh
 lda #10
 jsr Div32
 lda rem
 pha
 lda rl
 jsr AppendNum
 lda #46
 jsr AppendChar
 pla
 jsr AppendNum
 bra @l
@r:
 rts

rarity_colour: .byte 5, 0, 2, 3, 4
potion_colour: .byte 7, 6, 1

msg_level:    .byte "LEVEL TOO LOW", 0
msg_noroom:   .byte "NO ROOM FOR THAT", 0
msg_nochest:  .byte "NO CHEST TO OPEN YET", 0
msg_points3:  .byte "+3 STAT POINTS", 0
msg_fulllife: .byte "FULL LIFE", 0
msg_fullstam: .byte "FULL STAMINA", 0
msg_stamina:  .byte "STAMINA", 0
msg_winds:    .byte "+10% ALL RESIST", 0
msg_skill:    .byte "+1 SKILL POINT", 0
msg_intown:   .byte "ALREADY IN TOWN", 0
msg_portal:   .byte "A PORTAL OPENS", 0
msg_choose:   .byte "CHOOSE A PIECE", 0
msg_bagfull:  .byte "BAG FULL", 0
msg_beltfull: .byte "BELT FULL", 0
msg_empty:    .byte "EMPTY SLOT", 0
msg_tome:     .byte "+1 STAT POINT", 0
msg_identd:   .byte "IDENTIFIED", 0
msg_known:    .byte "THAT IS ALREADY KNOWN", 0
msg_pickup:   .byte "A  ", 0
msg_nofloor:  .byte "NO ROOM ON THE GROUND", 0
str_bag:      .byte "BAG", 0
str_gold2:    .byte "GOLD", 0
str_belt:     .byte "BELT", 0
str_dmg:      .byte "DAMAGE", 0
str_dmg2:     .byte "DAMAGE ", 0
str_def:      .byte "DEFENSE ", 0
str_life2:    .byte "LIFE ", 0
str_life3:    .byte "LIFE +", 0
str_str:      .byte "STRENGTH ", 0
str_nothing:  .byte "NOTHING WORN", 0
str_needs:    .byte "NEEDS LEVEL ", 0
str_unid:     .byte "NOT IDENTIFIED", 0
str_hint:     .byte "A WEAR  X USE  Y DROP", 0
str_hint_off: .byte "A TAKE OFF  Y DROP", 0
str_hint_id:  .byte "A IDENTIFY  B CANCEL", 0
