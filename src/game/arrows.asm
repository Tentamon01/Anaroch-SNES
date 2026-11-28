; ---------------------------------------------------------------- arrows (main.c earrows_update)
ShootArrow:
 .a16
 .i16
 ldy #0
@f:
 lda.w alife,y
 beq @got
 iny
 iny
 cpy #NARROW*2
 bne @f
 rts
@got:
 lda #0
 sta.w aown,y
 sta.w akind,y
 sty tmpB
 jsr RelHero
 lda tmp4
 bne @d
 rts
@d:
 sta tmp7                   ; 2.75 m/s: 12/16 px a frame along the line to the hero
 lda #SFX_BOW
 jsr Sfx
 lda tmpw0
 jsr Abs16
 sta tmp8
 asl
 clc
 adc tmp8
 asl
 asl
 jsr Div
 sta tmp8
 lda tmpw0
 bpl @vx
 lda #0
 sec
 sbc tmp8
 sta tmp8
@vx:
 lda tmpw2
 jsr Abs16
 sta tmp9
 asl
 clc
 adc tmp9
 asl
 asl
 jsr Div
 sta tmp9
 lda tmpw2
 bpl @vy
 lda #0
 sec
 sbc tmp9
 sta tmp9
@vy:
 jsr DirFrom
 ldy tmpB
 sta.w adir,y
 lda tmp8
 sta.w avx,y
 lda tmp9
 sta.w avy,y
 lda.w ex,x
 sta.w ax,y
 lda.w ey,x
 sta.w ay,y
 lda.w estr,x
 sta.w astr,y
 lda #300                   ; 14 m
 sta.w alife,y
 rts

UpdateArrows:
 .a16
 .i16
 ldx #0
@l:
 lda.w alife,x
 bne @on
 jmp @n
@on:
 ldy.w aown,x
 beq @enemy
 phx
 jsl $800000+X_HeroArrow
 plx
 jmp @n
@enemy:
 dec a
 sta.w alife,x
 bne @fly0
 jmp @n
@fly0:
 lda.w ax,x
 clc
 adc.w avx,x
 sta.w ax,x
 lsr4
 sta tmp6
 lda.w ay,x
 clc
 adc.w avy,x
 sta.w ay,x
 lsr4
 sta tmp7
 jsr Blocked
 bcc @fly
 stz.w alife,x
 bra @n
@fly:
 lda.w est
 cmp #ST_DEAD
 bcs @n
 lda.w ex
 lsr4
 sec
 sbc tmp6
 jsr Abs16
 cmp #7
 bcs @n
 lda.w ey
 lsr4
 sec
 sbc tmp7
 jsr Abs16
 cmp #7
 bcs @n
 stz.w alife,x
 phx
 lda.w astr,x
 jsl $800000+X_MonsterHit
 plx
 lda.w ax,x
 sec
 sbc.w avx,x
 lsr4
 sta hfx
 lda.w ay,x
 sec
 sbc.w avy,x
 lsr4
 sta hfy
 lda cMiss
 bne @n
 phx
 ldx #0
 jsr HurtActor
 plx
@n:
 inx
 inx
 cpx #NARROW*2
 beq @end
 jmp @l
@end:
 rts
