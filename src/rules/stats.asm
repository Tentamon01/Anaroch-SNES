; The hero's numbers (stats_recalc), experience and the damage formula (items.c).
DR_FULL = 149                ; defence from which the damage reduction is at its 65 % cap (def / (def + 80))

NewKit:                      ; a new hero: stats at 10, a wooden sword and armour, two potions and a way home
 .a16
 .i16
 ldx #0
@c:
 jsr ItemClear
 txa
 clc
 adc #ITEM_BYTES
 tax
 cpx #ITEM_PLACES * ITEM_BYTES
 bcc @c
 lda #10
 sta strb
 sta defb
 sta lifeb
 sta sDex
 sta sEne
 stz skillPts
 stz xph
 stz heroFlags
 lda #1                     ; Wooden Sword
 jsr MakeNormal
 ldx #TEMP
 ldy #EQUIP0 + 0 * 64
 jsr ItemCopy
 lda #10                    ; Wooden Armor
 jsr MakeNormal
 ldx #TEMP
 ldy #EQUIP0 + 2 * 64
 jsr ItemCopy
 lda #KIND_POTION
 ldy #0
 jsr MakeThing
 ldx #TEMP
 ldy #BELT0
 jsr ItemCopy
 ldy #BELT0 + 64
 jsr ItemCopy
 lda #KIND_SCROLL
 ldy #0
 jsr MakeThing
 ldx #TEMP
 ldy #BELT0 + 128
 jsr ItemCopy
 jsr BagRebuild
 jsr StatsRecalc
 lda maxStam
 sta stam
 rts

; everything worked out from the stats and what is worn
StatsRecalc:
 .a16
 .i16
 lda it
 pha
 ldx #64
@z:
 stz.w pmods,x
 dex
 dex
 bpl @z
 lda strb
 sta hstr
 lda defb
 sta hdef
 lda lifeb
 sta.w emaxhp
 stz wMin
 stz wMax
 lda #9                     ; bare hands
 sta famNow
 lda #EQUIP0
 sta it
@slot:
 ldx it
 lda.l ITEMS+I_KIND,x
 beq @next
 jsr ItemNumbers
 lda iStr
 clc
 adc hstr
 sta hstr
 lda iHp
 clc
 adc.w emaxhp
 sta.w emaxhp
 lda iDef
 clc
 adc hdef
 sta hdef
 lda it
 cmp #EQUIP0
 bne @mods
 lda iWmin
 sta wMin
 lda iWmax
 sta wMax
 jsr ItemDef
 lda rFam
 bmi @mods
 sta famNow
@mods:
 ldx it
 lda.l ITEMS+I_NMODS,x
 beq @next
 sta r6
 ldx it
@m:
 lda.l ITEMS+I_KEYS,x
 cmp #K_HP
 beq @skip
 cmp #K_STR
 beq @skip
 cmp #K_DEF
 beq @skip
 asl
 tay
 lda.l ITEMS+I_VALS,x
 clc
 adc.w pmods,y
 sta.w pmods,y
@skip:
 inx
 inx
 dec r6
 bne @m
@next:
 lda it
 clc
 adc #ITEM_BYTES
 sta it
 cmp #EQUIP0 + 7 * ITEM_BYTES
 bcs @_far0
 jmp @slot
@_far0:
 pla
 sta it

 ldx #0                     ; resistances: the pieces', all of them, the Four Winds; at most 75
@res:
 lda.w pmods+K_FIRE_RESIST_PERCENT*2,x
 clc
 adc pmods+K_RESIST_ALL_PERCENT*2
 ldy heroFlags
 beq @nw
 clc
 adc #10
@nw:
 cmp #76
 bcc @rok
 lda #75
@rok:
 sta.w resist,x
 inx
 inx
 cpx #8
 bne @res
 lda hstr
 ldy pmods+K_STRENGTH_PERCENT*2
 jsr Pct
 sta hstr
 lda hdef
 ldy pmods+K_DEFENSE_PERCENT*2
 jsr Pct
 sta hdef
 lda.w emaxhp
 ldy pmods+K_MAX_LIFE_PERCENT*2
 jsr Pct
 sta.w emaxhp
 cmp.w ehp
 bcs @hp
 sta.w ehp
@hp:
 lda sDex                   ; dexterity and energy, above 10
 sta pDex
 sec
 sbc #10
 bpl @dx
 lda #0
@dx:
 sta r0                     ; dx
 lda sEne
 sec
 sbc #10
 bpl @en
 lda #0
@en:
 asl
 sta r1                     ; stamina: 100 + 2 a level + 2 a point of energy
 lda level
 dec a
 asl
 clc
 adc #100
 clc
 adc r1
 sta maxStam
 cmp stam
 bcs @st
 sta stam
@st:
 lda pmods+K_CRIT_CHANCE_PERCENT*2   ; critical: 5 % + the pieces' + 0.1 % a point of dexterity
 clc
 adc pmods+K_DEADLY_STRIKE_PERCENT*2
 jsr Times10
 clc
 adc #50
 clc
 adc r0
 sta critPm
 lda pmods+K_EVADE_CHANCE_PERCENT*2
 jsr Times10
 clc
 adc r0
 sta evadePm
 lda pmods+K_BLOCK_CHANCE_PERCENT*2
 jsr Times10
 sta blockPm

 ; the weapon: swing, reach, shooting
 lda famNow
 asl
 tax
 lda.l fam_reach,x
 sta reachPx
 lda.l fam_swing,x
 sta r2
 ldx famNow
 lda.l fam_ranged,x
 and #$00FF
 sta ranged
 lda r0                     ; speed: attack speed % * 10 + dexterity 5 a point (at most 500), in thousandths
 sta r1
 asl
 asl
 clc
 adc r1
 cmp #501
 bcc @sp
 lda #500
@sp:
 sta r1
 lda pmods+K_ATTACK_SPEED_PERCENT*2
 jsr Times10
 clc
 adc r1
 clc
 adc #1000
 sta r1
 lda r2                     ; frames = swing * 1000 / (1000 + speed)
 sta rm
 lda #1000
 jsr Mul16
 lda r1
 jsr Div32
 lda rl
 cmp #12
 bcs @fr
 lda #12
@fr:
 sta swingF
 lda #HERO_SWING            ; the swing's pictures are timed for HERO_SWING frames (8.8 a frame)
 sta rm
 lda #256
 jsr Mul16
 lda swingF
 jsr Div32
 lda rl
 sta swingStep

 ; the damage range: strength (a bow: dexterity) + the weapon grown by it
 lda hstr
 ldy ranged
 beq @s2
 lda pDex
@s2:
 sta r2
 lda r2
 clc
 adc #100
 sta rm
 lda wMin
 jsr Mul16
 lda #100
 jsr Div32
 lda rl
 sta atkmin
 lda wMax
 jsr Mul16
 lda #100
 jsr Div32
 lda rl
 clc
 adc r2
 sta atkmax

 ; life coming back: 0.5 % a second and the pieces' (tenths of a percent): a frame's share of REGEN_STEP
 lda pmods+K_LIFE_REGEN_PERCENT*2
 clc
 adc #5
 sta rm
 lda.w emaxhp
 jsr Mul16
 lda #5
 jsr Div32
 lda rl
 sta regenAdd

 ; walking speed with the pieces' bonus
 ldx #0
@hs:
 lda.l wspd_hx,x
 jsr Faster
 sta.w hspd,x
 lda.l wspd_hy,x
 jsr Faster
 sta.w hspd+16,x
 inx
 inx
 cpx #16
 bne @hs
 lda #1
 sta hudflag
 rts

Faster:                      ; a signed speed A, made faster by the movement bonus
 .a16
 phx
 sta r3
 bpl @p
 eor #$FFFF
 inc a
@p:
 ldy pmods+K_MOVE_SPEED_PERCENT*2
 jsr Pct
 ldy r3
 bpl @r
 eor #$FFFF
 inc a
@r:
 plx
 rts

Times10:
 .a16
 asl
 sta r7
 asl
 asl
 clc
 adc r7
 rts

; ---------------------------------------------------------------- experience
; a kill of the monster at X (twice its number) -> A = experience: 8 + 4 per level (x3 champion), 20 % less for
; every level it is below the hero, never under 5 %
KillXp:
 .a16
 .i16
 lda.w elvl,x
 inc a
 sta r0                     ; its level
 asl
 asl
 clc
 adc #8
 ldy.w echamp,x
 beq @nc
 sta r1
 asl
 clc
 adc r1
@nc:
 sta r1                     ; xp
 lda level
 sec
 sbc r0
 beq @full
 bmi @full
 asl
 asl
 sta r2
 lda #20                    ; twentieths: 20 - 4 per level below, at least 1
 sec
 sbc r2
 beq @tiny
 bpl @k
@tiny:
 lda #1
@k:
 sta rm
 lda r1
 jsr Mul16
 lda #20
 jsr Div32
 lda rem                    ; the fraction is a chance of one more
 sta r2
 lda rl
 sta r1
 lda #20
 jsr RandN
 cmp r2
 bcs @full
 inc r1
@full:
 lda r1
 rts

; A = experience: levels gained give two stat points and a skill point, and heal
GainXp:
 .a16
 .i16
 ldy level
 cpy #MAX_LEVEL
 bcc @go
 rts
@go:
 clc
 adc xp
 sta xp
 bcc @nc
 inc xph
@nc:
 stz r5
@lv:
 lda level
 cmp #MAX_LEVEL
 bcs @max
 asl
 clc
 adc level
 tax                        ; 3 bytes a level
 lda xph
 sta r0
 lda.l xp_tab+2,x
 and #$00FF
 sta r1
 lda xp
 sec
 sbc.l xp_tab,x
 sta r2
 lda r0
 sbc r1
 bcc @done                  ; not enough yet
 sta xph
 lda r2
 sta xp
 inc level
 inc points
 inc points
 inc skillPts
 inc r5
 bra @lv
@max:
 stz xp
 stz xph
@done:
 lda r5
 beq @r
 jsr StatsRecalc
 lda.w emaxhp
 sta.w ehp
 lda maxStam
 sta stam
 lda #1
 sta hudflag
 sec
 rts
@r:
 clc
 rts

; the hero's blow on the monster at X: the weapon, the pieces' extras -> hdmg, hcrit
HeroBlow:
 .a16
 .i16
 lda atkmin
 sta tmpC
 lda atkmax
 sta tmpD
 lda.w edef,x
 sta tmpF
 lda pmods+K_ENHANCE_DAMAGE_PERCENT*2
 sta cEnh
 lda critPm
 sta cCrit
 stz cEvade
 stz cBlock
 jsr Damage
 ldy pmods+K_DAMAGE_VS_UNDEAD_PERCENT*2    ; (the graveyard's dead walk)
 jsr Pct
 clc
 adc pmods+K_FIRE_DAMAGE*2
 adc pmods+K_COLD_DAMAGE*2
 adc pmods+K_LIGHTNING_DAMAGE*2
 adc pmods+K_POISON_DAMAGE*2
 sta hdmg
 lda pmods+K_CULLING_STRIKE_PERCENT*2      ; culling: a blow that leaves less than this share kills
 beq @nocull
 lda.w ehp,x
 sec
 sbc hdmg
 beq @nocull
 bcc @nocull
 sta rm
 lda #100
 jsr Mul16                  ; left * 100
 lda rl
 sta r0
 lda rh
 sta r1
 lda pmods+K_CULLING_STRIKE_PERCENT*2
 sta rm
 lda.w emaxhp,x
 jsr Mul16                  ; < max * share ?
 lda r1
 cmp rh
 bne @cmp
 lda r0
 cmp rl
@cmp:
 bcs @nocull
 lda.w ehp,x
 sta hdmg
@nocull:
 lda pmods+K_KNOCKBACK_PERCENT*2
 beq @noknock
 jsr Times10
 jsr Chance
 bcc @noknock
 lda #1
 sta hcrit
@noknock:
 lda pmods+K_LIFESTEAL_PERCENT*2
 beq @r
 ldy hdmg
 beq @r
 sta rm
 lda hdmg
 jsr Mul16
 lda #100
 jsr Div32
 lda rl
 bne @steal
 lda #1
@steal:
 clc
 adc.w ehp
 cmp.w emaxhp
 bcc @s2
 lda.w emaxhp
@s2:
 sta.w ehp
 lda #1
 sta hudflag
@r:
 rts

; a monster's blow or arrow on the hero, A = its strength -> hdmg, cMiss (1 evaded, 2 blocked), hcrit 0
MonsterHit:
 .a16
 .i16
 sta tmpD
 stz tmpC
 lda hdef
 sta tmpF
 stz cEnh
 lda #50
 sta cCrit
 lda evadePm
 sta cEvade
 lda blockPm
 sta cBlock
 jsr Damage
 sec
 sbc pmods+K_DAMAGE_REDUCTION*2
 bcs @d
 lda #0
@d:
 sta hdmg
 stz hcrit
 rts

; ---------------------------------------------------------------- the damage formula (calc_damage of the original)
; tmpC .. tmpD = the attack before extras, tmpF = the defender's defence; cEnh enhance %, cCrit, cEvade, cBlock of
; 1000 -> A = damage, hcrit, cMiss
Damage:
 .a16
 .i16
 stz hcrit
 stz cMiss
 lda cEvade
 beq @ne
 jsr Chance
 bcc @ne
 lda #1
 sta cMiss
 lda #0
 rts
@ne:
 lda tmpC
 sta r0
 lda tmpD
 sta r1
 lda cEnh
 beq @roll
 bmi @roll
 cmp #301
 bcc @e
 lda #300
@e:
 tay
 lda r0
 jsr Pct
 sta r0
 ldy cEnh
 cpy #301
 bcc @e2
 ldy #300
@e2:
 lda r1
 jsr Pct
 sta r1
@roll:
 lda cBlock
 beq @nb
 jsr Chance
 bcc @nb
 lda #2
 sta cMiss
 lda #0
 rts
@nb:
 lda r1
 sec
 sbc r0
 inc a
 jsr RandN
 clc
 adc r0
 sta r2                     ; the attack roll
 lda tmpF
 inc a
 jsr RandN
 sta r3
 lda r2
 sec
 sbc r3
 bcs @pos
 lda #0
@pos:
 sta r2                     ; raw
 lda tmpF
 cmp #DR_FULL
 bcc @dr
 lda #35
 sta rm
 lda r2
 jsr Mul16
 lda rl                     ; (rounded)
 clc
 adc #50
 sta rl
 bcc @c1
 inc rh
@c1:
 lda #100
 jsr Div32
 bra @crit
@dr:
 lda #80
 sta rm
 lda r2
 jsr Mul16
 lda tmpF
 clc
 adc #80
 sta r3
 lsr
 clc
 adc rl
 sta rl
 bcc @c2
 inc rh
@c2:
 lda r3
 jsr Div32
@crit:
 lda rl
 sta r2
 lda cCrit
 beq @out
 jsr Chance
 bcc @out
 lda #1
 sta hcrit
 lda #8                     ; x 1.6
 sta rm
 lda r2
 jsr Mul16
 lda rl
 clc
 adc #2
 sta rl
 bcc @c3
 inc rh
@c3:
 lda #5
 jsr Div32
 lda rl
 sta r2
@out:
 lda r2
 rts
