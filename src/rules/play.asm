; What the game asks of the rules while playing: the belt, picking up, spending points, the character window.

; the belt button: the chosen place's potion or scroll
UseBelt:
 .a16
 .i16
 lda beltsel
 xba
 lsr
 lsr
 clc
 adc #BELT0
 tax
 lda.l ITEMS+I_KIND,x
 bne @some
 lda #msg_empty
 jmp SayRules
@some:
 cmp #KIND_SCROLL
 bne @use
 lda.l ITEMS+I_BASE,x
 cmp #1
 bne @use
 phx                        ; a Scroll of Identify: the bag opens to choose
 jsr BagOpen
 plx
 stx bagIdent
 lda #msg_choose
 sta msgp
 jmp BagDraw
@use:
 stz msgp
 jsr UseThing
 bcc @say
 lda #SFX_DRINK
 jsl FarSfx
 lda #1
 sta hudflag
@say:
 lda msgp
 beq @r
 jmp SayRules
@r:
 rts

; A = a message of the rules: shown over the HUD for a moment
SayRules:
 .a16
 jsr Note0
 jsl FarSayName
 stz msgp
 rts

; A = a place on the ground (twice its number) -> carry set: its piece is in the bag
PickUp:
 .a16
 .i16
 xba
 lsr
 lsr
 lsr
 clc
 adc #DROP0
 sta r4
 sta bsrc
 jsr BagAdd
 bcc @full
 ldx r4
 jsr ItemClear
 lda #SFX_PICK
 jsl FarSfx
 lda #1
 sta hudflag
 sec
 rts
@full:
 lda #msg_bagfull
 jsr SayRules
 clc
 rts

; A = a place on the ground -> namebuf = what the prompt says, A = its colour
Prompt:
 .a16
 .i16
 xba
 lsr
 lsr
 lsr
 clc
 adc #DROP0
 sta it
 jsr ItemName
 sta r6
 lda nlen                   ; with "A  " in front if it fits the screen
 cmp #28
 bcs @r
 jsr NameStart
 lda #msg_pickup
 jsr Append
 jsr ItemNameAdd
@r:
 lda nlen
 cmp #31
 bcc @ok
 ldx #30
 stz.w namebuf,x
@ok:
 lda r6
 rts

; A = a place on the ground -> A = the small picture its piece shows
DropTile:
 .a16
 .i16
 xba
 lsr
 lsr
 lsr
 clc
 adc #DROP0
 tax
 lda.l ITEMS+I_KIND,x
 cmp #KIND_POTION
 bne @ns
 lda.l ITEMS+I_BASE,x
 cmp #1
 beq @stam
 lda #$C0
 rts
@stam:
 lda #$EC
 rts
@ns:
 cmp #KIND_SCROLL
 bne @nk
 lda #$E8
 rts
@nk:
 cmp #KIND_KEY
 bne @g
 lda #$EA
 rts
@g:
 lda #$E6
 rts

; A = a belt place (0..3) -> A = its picture on the HUD: 0 none, 1 healing, 2 stamina, 3 a scroll, 4 a key
BeltKind:
 .a16
 .i16
 xba
 lsr
 lsr
 clc
 adc #BELT0
 tax
 lda.l ITEMS+I_KIND,x
 cmp #KIND_POTION
 bne @r                     ; (nothing 0, a scroll 3, a key 4: the kinds' own numbers)
 lda.l ITEMS+I_BASE,x
 cmp #1
 beq @two
 lda #1
 rts
@two:
 lda #2
@r:
 rts

; A = a stat (0 life, 1 strength, 2 defence, 3 dexterity, 4 energy): a point into it
Spend:
 .a16
 .i16
 ldy points
 bne @go
 rts
@go:
 dec points
 cmp #0
 bne @s1
 inc lifeb
 bra @done
@s1:
 cmp #1
 bne @s2
 inc strb
 bra @done
@s2:
 cmp #2
 bne @s3
 inc defb
 bra @done
@s3:
 cmp #3
 bne @s4
 inc sDex
 bra @done
@s4:
 inc sEne
@done:
 lda.w emaxhp
 pha
 jsr StatsRecalc
 pla                        ; life gained is life filled
 sta r0
 lda.w emaxhp
 sec
 sbc r0
 bcc @r
 clc
 adc.w ehp
 sta.w ehp
@r:
 rts

; ---------------------------------------------------------------- the character window
WIN_TOP = 4
WIN_END = 22
StatsDraw:
 .a16
 .i16
 lda #FONT2_BASE - FONT_BASE
 sta fontoff
 ldx #WIN_TOP * 64
@bg:
 txa
 and #$003F
 cmp #3 * 2
 bcc @skip
 cmp #29 * 2
 bcs @skip
 lda #1 | HUD_PRIO
 sta.w hudmap,x
@skip:
 inx
 inx
 cpx #WIN_END * 64
 bne @bg
 ldx #WIN_TOP
 sep #$20
 .a8
 lda #1
@m:
 sta.w hudd,x
 inx
 cpx #WIN_END
 bne @m
 rep #$20
 .a16
 lda #st_level
 jsr Note0
 lda level
 jsr AppendNum
 lda #5 * 32 + 5
 ldy #$0400 | HUD_PRIO
 jsr Show
 jsr XpLine
 lda #6 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 ldx #st_life
 ldy #8 * 32 + 7
 lda.w emaxhp
 jsr StatRow
 ldx #st_str
 ldy #9 * 32 + 7
 lda hstr
 jsr StatRow
 ldx #st_def
 ldy #10 * 32 + 7
 lda hdef
 jsr StatRow
 ldx #st_dex
 ldy #11 * 32 + 7
 lda pDex
 jsr StatRow
 ldx #st_ene
 ldy #12 * 32 + 7
 lda sEne
 jsr StatRow
 lda #st_damage
 jsr Note0
 lda atkmin
 jsr AppendNum
 lda #45
 jsr AppendChar
 lda atkmax
 jsr AppendNum
 lda #14 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 lda #st_crit
 jsr Note0
 lda critPm
 jsr AppendPercent
 lda #st_block
 jsr Append
 lda blockPm
 jsr AppendPercent
 lda #15 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 lda #st_evade
 jsr Note0
 lda evadePm
 jsr AppendPercent
 lda #st_stam
 jsr Append
 lda maxStam
 jsr AppendNum
 lda #16 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 lda #st_resist
 jsr Note0
 ldx #0
@res:
 phx
 lda.w resist,x
 jsr AppendNum
 jsr Space
 plx
 inx
 inx
 cpx #8
 bne @res
 lda #17 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 lda #st_gold
 jsr Note0
 lda gold
 jsr AppendNum
 lda #st_kills
 jsr Append
 lda kills
 jsr AppendNum
 lda #18 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 lda #st_points
 jsr Note0
 lda points
 jsr AppendNum
 lda #19 * 32 + 5
 ldy #$0400 | HUD_PRIO
 jsr Show
 lda #st_slow
 jsr Note0
 lda lagc
 jsr AppendNum
 lda #st_busy
 jsr Append
 lda irqmax
 jsr AppendNum
 lda #20 * 32 + 5
 ldy #HUD_PRIO
 jsr Show
 lda statcur                ; the cursor, left of the chosen stat
 clc
 adc #8
 asl4
 asl
 clc
 adc #5
 asl
 tax
 lda #CH_GT + FONT2_BASE - FONT_BASE | $0400 | HUD_PRIO
 jsl FarPutTile
 stz fontoff
 rts

StatRow:                     ; X = label, Y = place, A = value
 .a16
 .i16
 sty r4
 sta r5
 txa
 jsr Note0
 lda r4
 ldy #HUD_PRIO
 jsr Show
 jsr NameStart
 lda r5
 jsr AppendNum
 lda r4
 clc
 adc #13
 ldy #HUD_PRIO
 jmp Show

; A = a chance of 1000 -> "n%"
AppendPercent:
 .a16
 sta rl
 stz rh
 lda #10
 jsr Div32
 lda rl
 jsr AppendNum
 lda #37
 jmp AppendChar

; "XP 123/4567" (24-bit numbers)
XpLine:
 .a16
 .i16
 lda #st_xp
 jsr Note0
 lda xp
 ldy xph
 jsr AppendLong
 lda level
 cmp #MAX_LEVEL
 bcs @r
 lda #47
 jsr AppendChar
 lda level
 asl
 clc
 adc level
 tax
 lda.l xp_tab+2,x
 and #$00FF
 tay
 lda.l xp_tab,x
 jsr AppendLong
@r:
 rts

st_level:  .byte "LEVEL ", 0
st_xp:     .byte "XP ", 0
st_life:   .byte "LIFE", 0
st_str:    .byte "STRENGTH", 0
st_def:    .byte "DEFENSE", 0
st_dex:    .byte "DEXTERITY", 0
st_ene:    .byte "ENERGY", 0
st_damage: .byte "DAMAGE ", 0
st_crit:   .byte "CRIT ", 0
st_block:  .byte "  BLOCK ", 0
st_evade:  .byte "EVADE ", 0
st_stam:   .byte "  STAMINA ", 0
st_resist: .byte "RESIST ", 0
st_gold:   .byte "GOLD ", 0
st_kills:  .byte "  KILLS ", 0
st_points: .byte "STAT POINTS ", 0
st_slow:   .byte "SLOWDOWNS ", 0
st_busy:   .byte "  BUSY ", 0
