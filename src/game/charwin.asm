; ---------------------------------------------------------------- the character window (L or R in the bag)
; drawn by the rules (rules/play.asm); here its buttons
StatsOpen:
 .a16
 .i16
 lda #M_STATS
 sta mode
 stz statcur
 jsl $800000+X_StatsDraw
 rts

StatsClose:
 .a16
 .i16
 ldy #4
@clr:
 tya
 phy
 jsr ClearRow
 ply
 iny
 cpy #22
 bne @clr
 stz mode
 lda #1
 sta hudflag
 rts

GameStats:
 .a16
 .i16
 lda padnew
 and #PAD_SELECT|PAD_B|PAD_START
 beq @tabs
 jmp StatsClose
@tabs:
 lda padnew
 and #PAD_L|PAD_R
 beq @in
 jsr StatsClose
 jsl $800000+X_BagOpen
 rts
@in:
 lda padnew
 and #PAD_UP
 beq @nu
 lda statcur
 beq @nu
 dec statcur
 bra @draw
@nu:
 lda padnew
 and #PAD_DOWN
 beq @nd
 lda statcur
 cmp #4
 bcs @nd
 inc statcur
 bra @draw
@nd:
 lda padnew
 and #PAD_A
 beq @r
 lda statcur
 jsl $800000+X_Spend
@draw:
 jsl $800000+X_StatsDraw
@r:
 rts
