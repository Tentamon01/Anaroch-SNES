; Rolling a piece for a kill (lib/loot.js and lib/affixes.js of the original, through items.c).
TAG_WEAPON = 1
TAG_MELEE = 2
TAG_RANGED = 4
TAG_ARMOR = 8
TAG_SHIELD = 16
TAG_LEGS = 32
TAG_JEWELRY = 64

; rlvl = the monster's level, rsrc = SRC_*  -> carry set: a piece lies in TEMP
RollDrop:
 .a16
 .i16
 lda rsrc
 bne @yes                   ; champions and bosses always drop
 jsl FarRand
 cmp #GEAR_CHANCE
 bcc @yes
 clc
 rts
@yes:
 ldx #TEMP
 stx it
 jsr ItemClear
 ldx #TEMP
 lda #KIND_GEAR
 sta.l ITEMS+I_KIND,x
 lda #$FFFF
 sta.l ITEMS+I_PRE,x
 sta.l ITEMS+I_SUF,x
 lda rlvl                   ; item level: the monster's, at most 120
 cmp #121
 bcc @il
 lda #120
@il:
 sta.l ITEMS+I_ILVL,x

 ; a unique, from champions and bosses, when one is made for a level the monster has reached
 lda rsrc
 asl
 tax
 lda.l unique_chance,x
 bne @_far2
 jmp @plain
@_far2:
 sta r0                     ; times (300 + magic find) / 300
 lda pmods+K_MAGIC_FIND_PERCENT*2
 clc
 adc #300
 sta rm
 lda r0
 jsr Mul16
 lda #300
 jsr Div32
 jsl FarRand
 cmp rl
 bcc @_far3
 jmp @plain
@_far3:
 stz rcnt
 ldx #0
 stz r0                     ; the unique's number
@u:
 lda.l unique_tab+2,x
 and #$00FF
 sta r1
 lda rlvl
 clc
 adc #3
 cmp r1
 bcc @un
 lda rcnt
 asl
 tay
 lda r0
 sta.w affok,y
 inc rcnt
@un:
 txa
 clc
 adc #34
 tax
 inc r0
 lda r0
 cmp #UNIQUE_COUNT
 bcc @u
 lda rcnt
 beq @plain
 jsr RandN
 asl
 tay
 lda.w affok,y
 ldx #TEMP
 sta.l ITEMS+I_BASE,x
 lda #RAR_UNIQUE
 sta.l ITEMS+I_RAR,x
 jsr UniqueOff              ; its fixed properties
 stx r3
 lda.l unique_tab+14,x
 and #$00FF
 sta r2
 stz r5
@um:
 lda r5
 cmp r2
 bcs @ud
 clc
 adc r3
 tax
 lda.l unique_tab+16,x      ; the keys (bytes)
 and #$00FF
 sta r4
 lda r5
 asl
 clc
 adc r3
 tax
 lda.l unique_tab+22,x      ; the values (words)
 tay
 lda r4
 jsr AddMod
 inc r5
 bra @um
@ud:
 sec
 rts

@plain:
 jsr RollQuality
 ldx #TEMP
 sta.l ITEMS+I_RAR,x
 jsr RollTier
 jsr RollBase
 ldx #TEMP
 sta.l ITEMS+I_BASE,x
 jsr ItemDef
 jsr ItemTags
 ldx #TEMP
 lda.l ITEMS+I_RAR,x
 bne @np
 lda #6                     ; poor: an adjective
 jsr RandN
 ldx #TEMP
 sta.l ITEMS+I_W1,x
 bra @done
@np:
 cmp #RAR_MAGIC
 bne @nm
 jsr RollMagic
 bra @done
@nm:
 cmp #RAR_RARE
 bne @done
 jsr RollRare
@done:
 ldx #TEMP
 ldy #1
 lda.l ITEMS+I_RAR,x
 cmp #RAR_MAGIC             ; magic and better must be identified
 bcc @id
 ldy #0
@id:
 tya
 sta.l ITEMS+I_IDENT,x
 sec
 rts

; adds property A with value Y to piece `it`
AddMod:
 .a16
 .i16
 sta r6
 sty r7
 ldx it
 lda.l ITEMS+I_NMODS,x
 cmp #6
 bcs @r
 asl
 clc
 adc it
 tax
 lda r6
 sta.l ITEMS+I_KEYS,x
 lda r7
 sta.l ITEMS+I_VALS,x
 ldx it
 lda.l ITEMS+I_NMODS,x
 inc a
 sta.l ITEMS+I_NMODS,x
@r:
 rts

; -> A = the quality (0 poor .. 3 rare), the weights bent by magic find
RollQuality:
 .a16
 .i16
 lda rsrc
 asl
 asl
 asl
 tax
 lda.l quality_tab,x        ; poor: / (1 + mf)
 sta rm
 lda #10000
 jsr Mul16
 lda pmods+K_MAGIC_FIND_PERCENT*2
 clc
 adc #100
 jsr Div32
 lda rl
 sta r0
 lda.l quality_tab+2,x      ; normal
 sta rm
 lda #100
 jsr Mul16
 lda rl
 sta r1
 lda.l quality_tab+4,x      ; magic: * (1 + mf / 2)
 sta rm
 lda pmods+K_MAGIC_FIND_PERCENT*2
 lsr
 clc
 adc #100
 jsr Mul16
 lda rl
 sta r2
 lda pmods+K_MAGIC_FIND_PERCENT*2   ; rare: * (1 + mf * 1.2)
 sta rm
 lda #6
 jsr Mul16
 lda #5
 jsr Div32
 lda rl
 clc
 adc #100
 sta rm
 lda.l quality_tab+6,x
 jsr Mul16
 lda rl
 sta r3
 clc
 adc r2
 adc r1
 adc r0
 jsr RandN
 cmp r0
 bcc @q0
 sec
 sbc r0
 cmp r1
 bcc @q1
 sec
 sbc r1
 cmp r2
 bcc @q2
 lda #RAR_RARE
 rts
@q0:
 lda #RAR_POOR
 rts
@q1:
 lda #RAR_NORMAL
 rts
@q2:
 lda #RAR_MAGIC
 rts

; -> r0 = a tier for a monster of level rlvl: the nearest, now and then one off
RollTier:
 .a16
 .i16
 stz r0                     ; the best
 lda #$7FFF
 sta r1                     ; its distance
 ldx #0
@t:
 lda.l tier_level,x
 and #$00FF
 sec
 sbc rlvl
 bpl @p
 eor #$FFFF
 inc a
@p:
 cmp r1
 bcs @n
 sta r1
 stx r0
@n:
 inx
 cpx #TIER_COUNT
 bcc @t
 ldx r0
 lda.l tier_level,x
 and #$00FF
 clc
 adc #3
 cmp rlvl
 bcs @low                   ; level > tier's + 3 ?
 cpx #TIER_COUNT - 1
 bcs @r
 jsl FarRand
 cmp #22938                 ; 35 %
 bcs @r
 inc r0
 rts
@low:
 lda.l tier_level,x
 and #$00FF
 sec
 sbc #3
 bmi @r
 sta r1
 lda rlvl
 cmp r1
 bcs @r
 cpx #0
 beq @r
 jsl FarRand
 cmp #22938
 bcs @r
 dec r0
@r:
 rts

; r0 = tier -> A = a base: every weapon family 5 %, the other six share the rest
RollBase:
 .a16
 .i16
 lda #100
 jsr RandN
 cmp #45
 bcs @armor
 sta rm                     ; r / 5
 lda #13108                 ; 65536 / 5, rounded up
 jsr Mul16
 lda rh
 bra @t
@armor:
 sec
 sbc #45
 sta r1
 asl
 clc
 adc r1
 asl                        ; * 6
 sta rl
 stz rh
 lda #55
 jsr Div32
 lda rl
 clc
 adc #9
@t:
 sta r1
 lda r0                     ; tier * 15
 asl4
 sec
 sbc r0
 clc
 adc r1
 rts

; rtags for the piece's slot and family
ItemTags:
 .a16
 .i16
 lda rSlot
 bne @ns
 ldy #TAG_WEAPON | TAG_MELEE
 ldx rFam
 lda.l fam_ranged,x
 and #$00FF
 beq @w
 ldy #TAG_WEAPON | TAG_RANGED
@w:
 sty rtags
 rts
@ns:
 cmp #SLOT_SHIELD
 bne @nsh
 lda #TAG_ARMOR | TAG_SHIELD
 bra @s
@nsh:
 cmp #3
 bne @nl
 lda #TAG_ARMOR | TAG_LEGS
 bra @s
@nl:
 cmp #3
 bcs @j
 lda #TAG_ARMOR             ; head, chest
 bra @s
@j:
 lda #TAG_JEWELRY
@s:
 sta rtags
 rts

RollMagic:
 .a16
 .i16
 jsl FarRand
 sta r0                     ; both kinds: 45 %
 jsl FarRand
 sta r1                     ; else the prefix (50 %) or the suffix
 stz r2                     ; bit 0: a prefix, bit 1: a suffix
 lda r0
 cmp #29491
 bcs @one
 lda #3
 bra @k
@one:
 lda #2
 ldx r1
 bmi @k
 lda #1
@k:
 sta rns                    ; which
 and #1
 beq @s
 lda #0
 jsr AddAffix
 ldx #TEMP
 sta.l ITEMS+I_PRE,x
@s:
 lda rns
 and #2
 beq @n
 lda #1
 jsr AddAffix
 ldx #TEMP
 sta.l ITEMS+I_SUF,x
@n:
 ldx #TEMP
 lda.l ITEMS+I_NMODS,x
 bne @r
 lda #RAR_NORMAL
 sta.l ITEMS+I_RAR,x
@r:
 rts

RollRare:
 .a16
 .i16
 lda #4                     ; three to six properties, at most three of each kind
 jsr RandN
 clc
 adc #3
 sta rcnt
 lda #7
 sec
 sbc rcnt
 jsr RandN
 clc
 adc rcnt
 sec
 sbc #3
 cmp #4
 bcc @np
 lda #3
@np:
 sta rnp
 lda rcnt
 sec
 sbc rnp
 sta rns
 cmp #4
 bcc @go
 sec
 sbc #3
 clc
 adc rnp
 sta rnp
 lda #3
 sta rns
@go:
@p:
 lda rnp
 beq @s
 dec rnp
 lda #0
 jsr AddAffix
 bra @p
@s:
 lda rns
 beq @w
 dec rns
 lda #1
 jsr AddAffix
 bra @s
@w:
 lda #12
 jsr RandN
 ldx #TEMP
 sta.l ITEMS+I_W1,x
 lda #12
 jsr RandN
 ldx #TEMP
 sta.l ITEMS+I_W2,x
 rts

; A = 0 a prefix, 1 a suffix: one that fits the piece in TEMP (its tags, its level, no property twice) is added
; with a value for the item level -> A = which affix, $FFFF none
AddAffix:
 .a16
 .i16
 sta rsuf
 stz rtot
 stz rcnt
 ldx #TEMP
 lda.l ITEMS+I_NMODS,x
 cmp #6
 bcc @room
 lda #$FFFF
 rts
@room:
 stz r0                     ; the affix's number
@a:
 lda r0
 asl
 asl
 asl
 tax
 lda.l affix_tab,x          ; suffix
 and #$00FF
 cmp rsuf
 bne @n
 lda.l affix_tab+2,x        ; tags
 and #$00FF
 and rtags
 beq @n
 ldy #TEMP
 lda.l affix_tab+3,x        ; the lowest item level
 and #$00FF
 sta r1
 lda.l ITEMS+TEMP+I_ILVL
 cmp r1
 bcc @n
 lda.l affix_tab+1,x        ; its property: not already there
 and #$00FF
 sta r1
 lda.l ITEMS+TEMP+I_NMODS
 beq @ok
 tay
 phx
 ldx #0
@d:
 lda.l ITEMS+TEMP+I_KEYS,x
 cmp r1
 beq @dup
 inx
 inx
 dey
 bne @d
 plx
 bra @ok
@dup:
 plx
 bra @n
@ok:
 lda.l affix_tab+4,x        ; weight
 and #$00FF
 clc
 adc rtot
 sta rtot
 lda rcnt
 asl
 tay
 lda r0
 sta.w affok,y
 inc rcnt
@n:
 inc r0
 lda r0
 cmp #AFFIX_COUNT
 bcs @_far4
 jmp @a
@_far4:
 lda rcnt
 bne @some
 lda #$FFFF
 rts
@some:
 lda rtot
 jsr RandN
 sta r1
 ldy #0
@w:
 lda.w affok,y
 sta r0
 asl
 asl
 asl
 tax
 lda.l affix_tab+4,x
 and #$00FF
 sta r2
 lda r1
 sec
 sbc r2
 bcc @pick
 sta r1
 iny
 iny
 bra @w
@pick:                      ; the affix r0: its value from the table [affix][level][low, high]
 lda.l affix_tab+1,x
 and #$00FF
 sta r3                     ; the property
 lda r0
 sta rm
 lda #121
 jsr Mul16
 lda rl
 clc
 adc.l ITEMS+TEMP+I_ILVL
 asl
 asl
 tax
 lda.l affix_values,x
 sta r4
 lda.l affix_values+2,x
 sec
 sbc r4
 inc a
 jsr RandN
 clc
 adc r4
 tay
 lda #TEMP
 sta it
 lda r3
 jsr AddMod
 lda r0
 rts

; ---------------------------------------------------------------- the drops of a kill (main.c ghoul_killed)
; X = the monster's place among the actors (twice its number)
KillRewards:
 .a16
 .i16
 stx rwho
 lda.w elvl,x
 sta rlvl
 lda #SRC_NORMAL
 ldy.w echamp,x
 beq @s
 lda #SRC_CHAMPION
@s:
 sta rsrc
 lda #150                   ; gold now and then: 15 %, a champion 60 %
 ldy rsrc
 beq @g1
 lda #600
@g1:
 jsr Chance
 bcc @nogold
 lda rlvl                   ; 9 * (1 + level * 0.06), x3 a champion, gold find on top
 asl
 sta r0
 asl
 clc
 adc r0
 clc
 adc #100
 sta rm
 lda #9
 ldy rsrc
 beq @g2
 lda #27
@g2:
 jsr Mul16
 lda #100
 jsr Div32
 ldy pmods+K_GOLD_FIND_PERCENT*2
 lda rl
 jsr Pct
 tay
 lda #1                     ; (gold)
 ldx rwho
 jsl FarDrop
@nogold:
 lda #50                    ; a healing potion 5 %, a stamina potion 3 %
 jsr Chance
 bcc @n1
 lda #KIND_POTION
 ldy #0
 jsr DropThing
@n1:
 lda #30
 jsr Chance
 bcc @n2
 lda #KIND_POTION
 ldy #1
 jsr DropThing
@n2:
 lda #20                    ; a scroll 2 %, a champion 12 %: town portal or identify
 ldy rsrc
 beq @c3
 lda #120
@c3:
 jsr Chance
 bcc @n3
 lda #2
 jsr RandN
 tay
 lda #KIND_SCROLL
 jsr DropThing
@n3:
 lda #10                    ; a Tome (one stat point) 1 %, a champion 10 %
 ldy rsrc
 beq @c4
 lda #100
@c4:
 jsr Chance
 bcc @n4
 ldy #0
 lda #3
 ldx rwho
 jsl FarDrop
@n4:
 lda #20                    ; a key 2 %, a champion 12 %
 ldy rsrc
 beq @c5
 lda #120
@c5:
 jsr Chance
 bcc @n5
 lda #KIND_KEY
 ldy #0
 jsr DropThing
@n5:
 jsr RollDrop
 bcc @n6
 jsr DropTemp
@n6:
 lda rsrc                   ; a champion: a quarter of the time a second piece
 beq @n7
 jsl FarRand
 cmp #16384
 bcs @n7
 jsr RollDrop
 bcc @n7
 jsr DropTemp
@n7:
 lda pmods+K_LIFE_PER_KILL*2
 beq @r
 clc
 adc.w ehp
 cmp.w emaxhp
 bcc @h
 lda.w emaxhp
@h:
 sta.w ehp
 lda #1
 sta hudflag
@r:
 rts

DropThing:                   ; A = kind, Y = which
 .a16
 .i16
 jsr MakeThing
DropTemp:                    ; the piece in TEMP falls by the monster rwho
 .a16
 .i16
 ldy #0
 lda #2                     ; (an item)
 ldx rwho
 jsl FarDrop                ; -> Y = its place on the ground (twice), carry clear: no room
 bcc @r
 tya
 xba
 lsr
 lsr
 lsr                        ; (Y / 2) * 64
 clc
 adc #DROP0
 tay
 ldx #TEMP
 jsr ItemCopy
@r:
 rts
