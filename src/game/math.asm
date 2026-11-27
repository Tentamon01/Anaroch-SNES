; ---------------------------------------------------------------- arithmetic
; Div: A (16 bit) / tmp7 (1..255) -> A = quotient, tmp6 = remainder
Div:
 .a16
 sta $4204
 sep #$20
 .a8
 lda tmp7
 sta $4206
 rep #$20
 .a16
 wait16
 lda $4216
 sta tmp6
 lda $4214
 rts

Rand:
 .a16
 lda rng
 asl
 asl
 asl
 asl
 asl
 asl
 asl
 eor rng
 sta rng
 xba
 and #$00FF
 lsr
 eor rng
 sta rng
 xba
 and #$FF00
 eor rng
 sta rng
 rts

; RandRange: A = n (1..255) -> A = 0 .. n-1
RandRange:
 .a16
 sta tmp7
 jsr Rand
 jsr Div
 lda tmp6
 rts

Abs16:
 .a16
 bpl @p
 eor #$FFFF
 inc a
@p:
 rts

; Dist: tmp0 = dx, tmp2 = dy -> A = approximate length (max + min * 3/8)
Dist:
 .a16
 lda tmp0
 jsr Abs16
 sta tmp3
 lda tmp2
 jsr Abs16
 sta tmp5
 cmp tmp3
 bcs @ymax
 lda tmp3                   ; |dx| is the bigger: swap
 sta tmp9
 lda tmp5
 sta tmp3
 lda tmp9
 sta tmp5
@ymax:
 lda tmp3                   ; tmp5 = max, tmp3 = min
 lsr
 lsr
 sta tmp9
 lda tmp3
 lsr3
 clc
 adc tmp9
 clc
 adc tmp5
 rts

; DirFrom: tmp0 = dx, tmp2 = dy -> A = direction 0..7 (0 S, 1 SW, 2 W, 3 NW, 4 N, 5 NE, 6 E, 7 SE), $FFFF for none
DirFrom:
 .a16
 lda tmp0
 jsr Abs16
 sta tmp8
 lda tmp2
 jsr Abs16
 sta tmp9
 ora tmp8
 bne @some
 lda #$FFFF
 rts
@some:
 lda tmp9
 asl
 cmp tmp8
 bcs @notx
 lda tmp0
 bmi @w
 lda #6
 rts
@w:
 lda #2
 rts
@notx:
 lda tmp8
 asl
 cmp tmp9
 bcs @diag
 lda tmp2
 bmi @n
 lda #0
 rts
@n:
 lda #4
 rts
@diag:
 lda tmp2
 bmi @up
 lda tmp0
 bmi @sw
 lda #7
 rts
@sw:
 lda #1
 rts
@up:
 lda tmp0
 bmi @nw
 lda #5
 rts
@nw:
 lda #3
 rts

; DotDir: Y = direction * 2, tmp0 = dx, tmp2 = dy -> A = 10 * (the direction's unit vector . (dx, dy)), signed
DotDir:
 .a16
 stz tmp3
 lda.w dirx,y
 beq @fy
 bmi @xm
 lda tmp0
 sta tmp3
 bra @fy
@xm:
 lda #0
 sec
 sbc tmp0
 sta tmp3
@fy:
 lda.w diry,y
 beq @one
 bmi @ym
 lda tmp3
 clc
 adc tmp2
 sta tmp3
 bra @two
@ym:
 lda tmp3
 sec
 sbc tmp2
 sta tmp3
@two:
 lda.w dirx,y
 beq @one
 lda tmp3                   ; diagonal: * 7 (10 / sqrt 2)
 asl
 asl
 asl
 sec
 sbc tmp3
 rts
@one:
 lda tmp3                   ; * 10
 asl
 asl
 clc
 adc tmp3
 asl
 rts

; RelHero: X = actor -> tmp0 = hero.x - x, tmp2 = hero.y - y (px), A = tmp4 = distance
RelHero:
 .a16
 .i16
 lda.w ex
 lsr4
 sta tmp0
 lda.w ex,x
 lsr4
 sta tmp1
 lda tmp0
 sec
 sbc tmp1
 sta tmp0
 lda.w ey
 lsr4
 sta tmp2
 lda.w ey,x
 lsr4
 sta tmp1
 lda tmp2
 sec
 sbc tmp1
 sta tmp2
 sta tmpw2
 lda tmp0
 sta tmpw0
 jsr Dist
 sta tmp4
 jsr Rot
 lda tmp4
 rts

; MulK: A = signed value, mk = 0..255 -> A = (A * mk) / 256, signed; X, Y kept
MulK:
 .a16
 sta mk1
 bpl @p
 eor #$FFFF
 inc a
@p:
 sta mk2
 sep #$20
 .a8
 lda mk
 sta $4202
 lda mk2
 sta $4203
 rep #$20
 .a16
 nop
 nop
 nop
 lda $4216
 xba
 and #$00FF
 sta mk3
 sep #$20
 .a8
 lda mk2+1
 sta $4203
 rep #$20
 .a16
 nop
 nop
 nop
 lda $4216
 clc
 adc mk3
 bit mk1
 bpl @r
 eor #$FFFF
 inc a
@r:
 rts

; Rot: tmp0 / tmp2 = a world vector (or place) -> as seen on screen: x = wx - wz/2, y = (wx + wz)/2
Rot:
 .a16
 lda tmp2
 cmp #$8000
 ror
 sta rt0
 lda tmp0
 clc
 adc tmp2
 cmp #$8000
 ror
 sta rt1
 lda tmp0
 sec
 sbc rt0
 sta tmp0
 lda rt1
 sta tmp2
 rts
