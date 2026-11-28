; The skill trees' screen, a page of the bag screen (bagPage 1): one tree at a time, three columns, four tiers.
; BG1 holds the pictures and the lines from each skill to the one it needs, BG2 the words and the cursor.
SK_TILE = 16                 ; the first picture's tile (4 a skill), after the screen's own tiles

SkillOpen:
 .a16
 .i16
 lda #M_BAG
 sta mode
 lda #1
 sta bagPage
 stz msgp

SkillSetup:
 .a16
 .i16
 jsr MenuBegin
 lda #skill_tiles
 sta n0
 lda #^skill_tiles
 sta n1
 lda #SK_TILE * 16
 sta n2
 lda #SKILL_TILES_BYTES
 sta n3
 jsl FarDmaV
 ldx #0
 sep #$20
 .a8
 stz $2121
@col:
 lda.l skill_pal,x
 sta $2122
 inx
 cpx #256
 bne @col
 rep #$20
 .a16
 jsr SkillDraw
 jmp MenuShow

; icon column / row of skill (its offset in sDef) -> dx0, dy0
BoxAt:
 .a16
 .i16
 tax
 lda.l skill_tab+D_COL,x    ; 5 + column * 9
 sta r7
 asl
 asl
 asl
 clc
 adc r7
 clc
 adc #5
 sta dx0
 lda.l skill_tab+D_TIER,x   ; 4 + tier * 4
 asl
 asl
 clc
 adc #4
 sta dy0
 rts

SkillDraw:
 .a16
 .i16
 ldx #2046
 lda #0
@b:
 sta.l MENUMAP,x
 dex
 dex
 bpl @b
 jsl FarClearText
 lda #su_title
 jsr Note0
 lda #32 + 1
 ldy #$0400 | HUD_PRIO
 jsr Show
 lda #su_points
 jsr Note0
 lda skillPts
 jsr AppendNum
 lda #32 + 20
 ldy #HUD_PRIO
 jsr Show
 lda skCur
 jsr DefAt
 lda.l skill_tab+D_TREE,x
 sta curTree
 stz s0                     ; the trees' names, the open one in gold
@t:
 lda s0
 asl
 tax
 lda.l tree_name,x
 jsr Note0
 lda s0
 asl
 asl
 asl
 clc
 adc s0
 clc
 adc #2 * 32 + 4
 ldy #HUD_PRIO | $1400
 ldx s0
 cpx curTree
 bne @tn
 ldy #HUD_PRIO | $0400
@tn:
 jsr Show
 inc s0
 lda s0
 cmp #3
 bcc @t

 stz s1                     ; each skill of the open tree
@s:
 lda s1
 jsr DefAt
 stx s2
 lda.l skill_tab+D_TREE,x
 cmp curTree
 beq @mine
 jmp @n
@mine:
 lda.l skill_tab+D_NEED,x
 bmi @icon
 jsr Connect
@icon:
 lda s2
 jsr BoxAt
 lda s1
 jsr RankOf
 sta s3
 lda curTree                ; the picture: its tree's colours, darkened while not learned
 ldx s3
 bne @lit
 clc
 adc #3
@lit:
 xba
 asl
 asl
 sta r4
 lda s1
 asl
 asl
 clc
 adc #SK_TILE
 clc
 adc r4
 sta r4
 lda #2
 sta dw
 sta dh
 stz r3
@y:
 stz r2
@x:
 ldy r4
 jsr MapPut
 inc r4
 inc r2
 lda r2
 cmp #2
 bcc @x
 inc r3
 lda r3
 cmp #2
 bcc @y
 lda s3                     ; the rank, right of it
 beq @mark
 jsr NameStart
 lda s3
 jsr AppendNum
 lda dy0
 inc a
 asl4
 asl
 clc
 adc dx0
 clc
 adc #3
 ldy #HUD_PRIO
 jsr Show
@mark:
 lda s1                     ; the one on the button
 cmp skActive
 bne @n
 jsr NameStart
 lda #62
 jsr AppendChar
 lda dy0
 asl4
 asl
 clc
 adc dx0
 sec
 sbc #2
 ldy #HUD_PRIO | $0400
 jsr Show
@n:
 inc s1
 lda s1
 cmp #SKILLS
 bcs @drawn
 jmp @s
@drawn:
 jsr SkillInfo
 lda skCur
 jsr DefAt
 txa
 jsr BoxAt
 dec dx0
 dec dy0
 lda #4
 sta dw
 sta dh
 jsr CursorBox
 lda #1
 sta menuDirty
 rts

; the line from the needed skill (A = it) down to the one at s2
Connect:
 .a16
 .i16
 jsr DefAt
 txa
 jsr BoxAt
 lda dx0
 sta s4                     ; from this column
 lda dy0
 clc
 adc #2
 sta s5                     ; from under it
 lda s2
 jsr BoxAt
 lda dx0
 sta s6                     ; to this column
 lda dy0
 dec a
 sta s7                     ; to just over it
 stz r2
 stz r3
 lda s4
 sta dx0
 lda s5
 sta dy0
@down:                      ; down the upper column to the last row
 lda dy0
 cmp s7
 bcs @across
 ldy #14
 jsr MapPut
 inc dy0
 bra @down
@across:
 lda s4
 cmp s6
 beq @end
 sta dx0
 bcc @right
 lda s6
 sta dx0
 lda s4
 sta s6
@right:
 ldy #15
 jsr MapPut
 inc dx0
 lda s6
 cmp dx0
 bcs @right
 rts
@end:
 ldy #14
 jmp MapPut

; the words on the skill under the cursor
SkillInfo:
 .a16
 .i16
 lda skCur
 jsr RankOf
 sta s3
 lda skCur
 jsr DefAt
 stx s2
 lda.l skill_tab+D_NAME,x
 jsr Note0
 ldx s2
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 bne @name
 lda #su_passive
 jsr Append
@name:
 lda #19 * 32 + 1
 ldy #$0400 | HUD_PRIO
 jsr Show
 ldx s2
 lda.l skill_tab+D_TEXT,x
 jsr Note0
 lda #20 * 32 + 1
 ldy #HUD_PRIO
 jsr Show
 ldx s2
 lda.l skill_tab+D_TEXT2,x
 jsr Note0
 lda #21 * 32 + 1
 ldy #HUD_PRIO
 jsr Show
 lda #su_rank
 jsr Note0
 lda s3
 jsr AppendNum
 lda #su_of
 jsr Append
 ldx s2
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 beq @nocost
 lda #su_cost
 jsr Append
 lda skCur
 jsr CostOf
 jsr AppendNum
@nocost:
 lda #22 * 32 + 1
 ldy #HUD_PRIO | $0800
 jsr Show
 ldx s2
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 bne @active
 lda.l skill_tab+D_A,x      ; what a passive gives at this rank (rank 1 while unlearned)
 sta s4
 lda.l skill_tab+D_POWER,x
 sta rm
 lda s3
 bne @pr
 lda #1
@pr:
 jsr Mul16
 lda rl
 sta s5
 jsr NameStart
 lda s4
 asl
 tax
 lda.l passive_name,x
 sta nsrc
@pl:
 ldx nsrc
 lda.l RULES_BANK,x
 and #$00FF
 bne @pc
 jmp @line
@pc:
 inc nsrc
 cmp #35
 beq @num
 jsr AppendChar
 bra @pl
@num:
 lda s4
 cmp #14                    ; (life a second: in tenths of a percent)
 beq @tenths
 lda s5
 jsr AppendNum
 bra @pl
@tenths:
 lda s5
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
 bra @pl
@active:
 sta s4                     ; the kind
 ldy s3
 lda skCur
 jsr PowerAt
 sta s5
 lda s4
 cmp #SK_HEAL
 bne @h
 lda #su_heals
 jsr Note0
 lda s5
 jsr AppendNum
 lda #su_oflife
 jsr Append
 bra @line
@h:
 cmp #SK_CRY
 bne @c
 jsr NameStart
 lda #43
 jsr AppendChar
 lda s5
 jsr AppendNum
 lda #su_damage
 jsr Append
 bra @line
@c:
 cmp #SK_TELEPORT
 bne @tp
 lda #su_tele
 jsr Note0
 bra @line
@tp:
 ldx s2
 lda.l skill_tab+D_TREE,x
 cmp #2
 bne @weapon
 lda #su_about
 jsr Note0
 lda s5
 jsr SpellDamage
 jsr AppendNum
 bra @line
@weapon:
 jsr NameStart
 lda s5
 jsr AppendNum
 lda #su_blow
 jsr Append
@line:
 lda #23 * 32 + 1
 ldy #HUD_PRIO | $0800
 jsr Show
 lda s3
 bne @weap
 ldx s2                     ; not learned: what it waits for
 lda.l skill_tab+D_LEVEL,x
 sta s4
 lda #msg_needs
 jsr Note0
 lda s4
 jsr AppendNum
 lda #24 * 32 + 1
 ldy #HUD_PRIO
 ldx level
 cpx s4
 bcs @lv
 ldy #HUD_PRIO | $1C00
@lv:
 jsr Show
 ldx s2
 lda.l skill_tab+D_NEED,x
 bmi @weap
 sta s5
 lda #su_and
 jsr Note0
 lda s5
 jsr DefAt
 lda.l skill_tab+D_NAME,x
 jsr Append
 lda s5
 jsr RankOf
 ldy #HUD_PRIO
 cmp #0
 bne @nd
 ldy #HUD_PRIO | $1C00
@nd:
 lda #25 * 32 + 1
 jsr Show
 jmp @hint
@weap:
 ldx s2
 lda.l skill_tab+D_WEAPON,x
 beq @hint
 cmp #1
 beq @melee
 lda #sk_bow
 bra @ws
@melee:
 lda #sk_melee
@ws:
 jsr Note0
 lda #24 * 32 + 1
 ldx s3
 bne @wr
 lda #25 * 32 + 1           ; (not learned: under the level it waits for)
@wr:
 ldy #HUD_PRIO | $1400
 jsr Show
@hint:
 lda msgp
 beq @h2
 jsr Note0
 lda #HINT_Y * 32 + 1
 ldy #HUD_PRIO | $0400
 jmp Show
@h2:
 lda #su_hint
 jsr Note0
 lda #HINT_Y * 32 + 1
 ldy #HUD_PRIO | $1400
 jmp Show

SkillInput:
 .a16
 .i16
 lda padnew
 and #PAD_B | PAD_SELECT | PAD_START
 beq @nc
 jmp BagClose
@nc:
 lda padnew
 and #PAD_L
 beq @nl
 jsr BagClose               ; L: the character window, R: the bag
 jsl FarStatsOpen
 rts
@nl:
 lda padnew
 and #PAD_R
 beq @nr
 stz bagPage
 stz msgp
 jmp BagSetup
@nr:
 lda skCur
 jsr DefAt
 stx s2
 lda.l skill_tab+D_TREE,x   ; the trees side by side: columns 0..8
 sta s3
 asl
 clc
 adc s3
 clc
 adc.l skill_tab+D_COL,x
 sta s3
 lda.l skill_tab+D_TIER,x
 sta s4
 lda padnew
 and #PAD_LEFT
 beq @a
 lda s3
 clc
 adc #8
 sta s3
 bra @move
@a:
 lda padnew
 and #PAD_RIGHT
 beq @b
 inc s3
 bra @move
@b:
 lda padnew
 and #PAD_UP
 beq @c
 lda s4
 clc
 adc #3
 sta s4
 bra @move
@c:
 lda padnew
 and #PAD_DOWN
 beq @press
 inc s4
@move:
 lda s3
 cmp #9
 bcc @m1
 sbc #9
 sta s3
@m1:
 lda s4
 and #3
 sta s4
 stz msgp
 stz s1                     ; the skill standing there
@find:
 lda s1
 jsr DefAt
 lda.l skill_tab+D_TREE,x
 sta r7
 asl
 clc
 adc r7
 clc
 adc.l skill_tab+D_COL,x
 cmp s3
 bne @fn
 lda.l skill_tab+D_TIER,x
 cmp s4
 bne @fn
 lda s1
 sta skCur
 jmp @treecheck
@fn:
 inc s1
 lda s1
 cmp #SKILLS
 bcc @find
@treecheck:
 jmp SkillDraw
@press:
 lda padnew
 and #PAD_A
 beq @y
 stz msgp
 lda skCur
 jsr Learn
 bcc @redraw
 lda #SFX_LEVEL
 jsl FarSfx
@redraw:
 jmp SkillDraw
@y:
 lda padnew
 and #PAD_Y
 beq @r
 lda skCur
 jsr DefAt
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 bne @act
 lda #su_always
 bra @say
@act:
 lda skCur
 jsr RankOf
 bne @set
 lda #su_first
 bra @say
@set:
 lda skCur
 sta skActive
 lda #1
 sta skDirty
 lda #su_onbutton
@say:
 sta msgp
 jmp SkillDraw
@r:
 rts

su_title:    .byte "SKILLS", 0
su_points:   .byte "POINTS ", 0
su_passive:  .byte " (PASSIVE)", 0
su_rank:     .byte "RANK ", 0
su_of:       .byte "/20", 0
su_cost:     .byte "  STAMINA ", 0
su_heals:    .byte "HEALS ", 0
su_oflife:   .byte "% OF LIFE", 0
su_damage:   .byte "% DAMAGE", 0
su_tele:     .byte "UP TO 8 METRES AHEAD", 0
su_about:    .byte "DAMAGE ABOUT ", 0
su_blow:     .byte "% OF A BLOW", 0
msg_needs:   .byte "NEEDS LEVEL ", 0
su_and:      .byte "AND ", 0
su_hint:     .byte "A LEARN  Y USE  L R PAGES", 0
su_always:   .byte "A PASSIVE: ALWAYS AT WORK", 0
su_first:    .byte "LEARN IT FIRST", 0
su_onbutton: .byte "ON THE SKILL BUTTON", 0
