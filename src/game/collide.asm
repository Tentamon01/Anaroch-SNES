; ---------------------------------------------------------------- collision and sight
; CellType: tmp6 = x px, tmp7 = y px -> A = the N64 grid's value there (0 free, 1 low, 2 tall; 2 outside); X kept
CellType:
 .a16
 .i16
 lda tmp6
 cmp areaW
 bcs @out
 lda tmp7
 cmp areaH
 bcs @out
 lsr4                       ; row * the grid's width
 sep #$20
 .a8
 sta $4202
 lda gridW
 sta $4203
 rep #$20
 .a16
 lda tmp6
 lsr4
 nop
 clc
 adc $4216
 phx
 tax
 lda.l $7F0000+W_GRID,x
 plx
 and #$00FF
 rts
@out:
 lda #2
 rts

; Blocked: tmp6 / tmp7 = px -> carry set when the cell is blocked (anything in the N64 grid: walls, trees, graves)
Blocked:
 .a16
 jsr CellType
 cmp #1
 rts

CheckFoot:
 .a16
 .i16
 lda tmpF
 lsr4
 sta tmp8
 lda tmpG
 lsr4
 sta tmp9
 lda tmp8
 sec
 sbc #4
 sta tmp6
 lda tmp9
 sec
 sbc #3
 sta tmp7
 jsr Blocked
 bcs @r
 lda tmp8
 clc
 adc #4
 sta tmp6
 jsr Blocked
 bcs @r
 lda tmp9
 clc
 adc #3
 sta tmp7
 jsr Blocked
 bcs @r
 lda tmp8
 sec
 sbc #4
 sta tmp6
 jsr Blocked
@r:
 rts

; MoveEnt: X = actor, tmpC / tmpD = velocity (12.4); each axis alone so walls are slid along (main.c move_slide)
MoveEnt:
 .a16
 .i16
 lda.w ex,x
 clc
 adc tmpC
 sta tmpF
 lda.w ey,x
 sta tmpG
 jsr CheckFoot
 bcs @ny
 lda tmpF
 sta.w ex,x
@ny:
 lda.w ex,x
 sta tmpF
 lda.w ey,x
 clc
 adc tmpD
 sta tmpG
 jsr CheckFoot
 bcs @ret
 lda tmpG
 sta.w ey,x
@ret:
 rts

; ClearLine (main.c clear_line): from actor X to the hero, a look every third of a metre; carry set when something tall
; (a wall, a tree, the crypt: 2 in the N64 grid) is in the way. Uses tmp0 / tmp2 / tmp4 from RelHero, keeps them.
ClearLine:
 .a16
 .i16
 lda #5
 sta tmp7
 lda tmp4
 jsr Div
 cmp #2
 bcs @some
 clc
 rts
@some:
 sta ln
 sta tmp7
 lda tmpw0
 jsr Abs16
 asl4
 jsr Div
 sta lsx
 lda tmpw0
 bpl @px
 lda #0
 sec
 sbc lsx
 sta lsx
@px:
 lda tmpw2
 jsr Abs16
 asl4
 jsr Div
 sta lsy
 lda tmpw2
 bpl @py
 lda #0
 sec
 sbc lsy
 sta lsy
@py:
 lda.w ex,x
 sta lx
 lda.w ey,x
 sta ly
 dec ln
@l:
 lda lx
 clc
 adc lsx
 sta lx
 lsr4
 sta tmp6
 lda ly
 clc
 adc lsy
 sta ly
 lsr4
 sta tmp7
 jsr CellType
 cmp #2
 bcs @blocked
 dec ln
 bne @l
 clc
 rts
@blocked:
 sec
 rts
