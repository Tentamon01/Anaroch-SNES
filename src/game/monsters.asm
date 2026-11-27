; ---------------------------------------------------------------- monsters (main.c ghoul_update, ghoul_spawn)
SIGHT = 144                  ; 9 m
HEAR = 48                    ; 3 m
LOSE = 256                   ; 16 m
LOSE_TIME = 240              ; 4 s
CALL_RANGE = 96              ; 6 m

MonsterSpawn:
 .a16
 .i16
 lda #40                    ; a spawn point 9 to 24 m from the hero
 sta tmpB
@try:
 jsr PickSpawn
 jsr RelHero
 lda tmp4
 cmp #144
 bcc @near
 cmp #384
 bcc @ok
@near:
 dec tmpB
 bne @try
 lda #16                    ; none there: anywhere not too close
 sta tmpB
@try2:
 jsr PickSpawn
 jsr RelHero
 lda tmp4
 cmp #128
 bcs @ok
 dec tmpB
 bne @try2
@ok:
 lda.w ex,x
 lsr4
 sta.w ehomex,x
 sta.w ewx,x
 lda.w ey,x
 lsr4
 sta.w ehomey,x
 sta.w ewy,x
 lda #3                     ; the graveyard: monster levels 1 to 3
 jsr RandRange
 inc a
 sta.w elvl,x
 stz.w echamp,x
 lda #100                   ; a champion 8 %: blue, three times the life
 jsr RandRange
 cmp #8
 bcs @nch
 lda #1
 sta.w echamp,x
@nch:
 lda.w ekind,x              ; mon_tab[(archer * 2 + champion) * 8 + level] = hp, str, def
 asl
 clc
 adc.w echamp,x
 asl
 asl
 asl
 clc
 adc.w elvl,x
 sta tmp0
 asl
 clc
 adc tmp0
 asl
 tay
 lda.w mon_tab,y
 sta.w ehp,x
 sta.w emaxhp,x
 lda.w mon_tab+2,y
 sta.w estr,x
 lda.w mon_tab+4,y
 sta.w edef,x
 lda #8
 jsr RandRange
 sta.w edir,x
 stz.w est,x
 stz.w etm,x
 lda #60
 sta.w ecool,x
 stz.w eflash,x
 stz.w ealert,x
 stz.w elost,x
 stz.w ecall,x
 stz.w estk,x
 lda #180
 jsr RandRange
 sta.w ewt,x
 rts

PickSpawn:
 .a16
 .i16
 lda #SPAWN_COUNT
 jsr RandRange
 asl
 asl
 tay
 lda.w spawn_tab,y
 asl4
 sta.w ex,x
 lda.w spawn_tab+2,y
 asl4
 sta.w ey,x
 rts

UpdateMonster:
 .a16
 .i16
 inc.w etm,x
 lda.w est,x
 cmp #ST_DEAD
 bcc @alive
 jmp @dead
@alive:
 lda.w ecool,x
 beq @c
 dec.w ecool,x
@c:
 lda.w eflash,x
 beq @f
 dec.w eflash,x
@f:
 lda.w ealert,x             ; senses: a look every fourth frame
 bne @alert
 txa
 lsr
 clc
 adc frame
 and #3
 bne @think
 jsr Sees
 bcc @think
 lda #1
 sta.w ealert,x
 stz.w elost,x
@alert:
 jsr RelHero
 lda.w est
 cmp #ST_DEAD
 bcs @lose
 lda tmp4
 cmp #LOSE
 bcc @kept
@lose:
 inc.w elost,x              ; it forgets the hero far away after a while
 lda.w elost,x
 cmp #LOSE_TIME
 bcc @call
 stz.w ealert,x
 lda.w ex,x
 lsr4
 sta.w ehomex,x
 sta.w ewx,x
 lda.w ey,x
 lsr4
 sta.w ehomey,x
 sta.w ewy,x
 bra @think
@kept:
 stz.w elost,x
@call:
 lda.w ecall,x              ; and calls the others near it, once a second
 beq @docall
 dec.w ecall,x
 bra @think
@docall:
 lda #60
 sta.w ecall,x
 jsr CallOthers
@think:
 lda.w est,x
 asl
 tay
 lda mon_jt,y
 sta jmpv
 jmp (jmpv)
@dead:
 cmp #ST_GONE
 beq @gone
 lda.w etm,x
 cmp #210                   ; the body lies 3.5 s
 bcc @r
 lda #ST_GONE
 sta.w est,x
 stz.w etm,x
@r:
 rts
@gone:
 lda.w etm,x
 cmp #360                   ; then 6 s before another rises
 bcc @r
 jmp MonsterSpawn

mon_jt: .word MonIdle, MonIdle, MonAttack, MonHit

; Sees (main.c sees): X = monster -> carry set when it sees the hero
Sees:
 .a16
 .i16
 lda.w est
 cmp #ST_DEAD
 bcs @no
 jsr RelHero
 cmp #SIGHT
 bcs @no
 cmp #HEAR
 bcc @line
 lda.w edir,x               ; behind it: (d . facing) / |d| < -0.3
 asl
 tay
 jsr DotDir
 sta tmp5
 lda tmp4
 asl
 clc
 adc tmp4
 clc
 adc tmp5
 bmi @no
@line:
 jsr ClearLine
 bcs @no
 sec
 rts
@no:
 clc
 rts

; CallOthers: an alerted monster calls the others within 6 m
CallOthers:
 .a16
 .i16
 stx tmpB
 ldy #2
@l:
 cpy tmpB
 beq @n
 lda.w est,y
 cmp #ST_DEAD
 bcs @n
 lda.w ealert,y
 bne @n
 lda.w ex,y
 lsr4
 sta tmp0
 lda.w ex,x
 lsr4
 sta tmp1
 lda tmp0
 sec
 sbc tmp1
 sta tmp0
 lda.w ey,y
 lsr4
 sta tmp2
 lda.w ey,x
 lsr4
 sta tmp1
 lda tmp2
 sec
 sbc tmp1
 sta tmp2
 phy
 jsr Dist
 ply
 cmp #CALL_RANGE
 bcs @n
 lda #1
 sta.w ealert,y
 lda #60
 sta.w ecall,y
@n:
 iny
 iny
 cpy #NACT*2
 bne @l
 ldx tmpB
 rts

; idle / moving
MonIdle:
 .a16
 .i16
 lda.w ealert,x
 bne @hunt
 jmp MonWander
@hunt:
 lda.w est
 cmp #ST_DEAD
 bcc @heroup
 stz.w est,x
 rts
@heroup:
 jsr RelHero
 lda.w ekind,x
 beq @ghoul
 jmp MonArcher
@ghoul:
 jsr DirFrom
 cmp #$FFFF
 beq @close
 sta.w edir,x
 lda tmp4
 cmp #19                    ; 1.15 m
 bcc @close
 lda.w edir,x
 jsr Walk
 lda #ST_MOVE
 sta.w est,x
 lda.w eanimt,x
 clc
 adc #13
 sta.w eanimt,x
 rts
@close:
 stz.w est,x
 lda.w ecool,x
 bne @r
 lda #ST_ATTACK
 sta.w est,x
 stz.w etm,x
 stz.w edealt,x
@r:
 rts

; Walk: X = monster, A = direction; at the ghouls' 1.5 m/s, round what is in the way (main.c steer)
Walk:
 .a16
 .i16
 ldy.w estk,x
 beq @dir
 dec.w estk,x
 lda.w ealt,x
@dir:
 asl
 tay
 lda.w wspd_gx,y
 sta tmpC
 lda.w wspd_gy,y
 sta tmpD
WalkV:
 lda.w ex,x
 sta us0
 lda.w ey,x
 sta us1
 jsr MoveEnt
 lda.w ex,x
 cmp us0
 bne @moved
 lda.w ey,x
 cmp us1
 bne @moved
 lda #24
 sta.w estk,x
 jsr Rand
 and #4
 dec a
 dec a
 clc
 adc.w edir,x
 and #7
 sta.w ealt,x
@moved:
 rts

; wandering near home: a few steps, a pause, a few steps (0.6 m/s)
MonWander:
 .a16
 .i16
 lda.w ewt,x
 dec a
 sta.w ewt,x
 bpl @go
 lda #240
 jsr RandRange
 clc
 adc #150
 sta.w ewt,x
 lda #113
 jsr RandRange
 sec
 sbc #56
 clc
 adc.w ehomex,x
 sta.w ewx,x
 lda #113
 jsr RandRange
 sec
 sbc #56
 clc
 adc.w ehomey,x
 sta.w ewy,x
@go:
 lda.w ex,x
 lsr4
 sta tmp1
 lda.w ewx,x
 sec
 sbc tmp1
 sta tmp0
 lda.w ey,x
 lsr4
 sta tmp1
 lda.w ewy,x
 sec
 sbc tmp1
 sta tmp2
 jsr Dist
 cmp #7
 bcc @stand
 lda.w ewt,x
 cmp #150
 bcs @stand
 jsr Rot
 jsr DirFrom
 sta.w edir,x
 asl
 tay
 lda.w wspd_wx,y
 sta tmpC
 lda.w wspd_wy,y
 sta tmpD
 jsr WalkV
 lda #ST_MOVE
 sta.w est,x
 lda.w eanimt,x
 clc
 adc #6
 sta.w eanimt,x
 rts
@stand:
 stz.w est,x
 rts

; the skeleton archer: shoots whenever it can, keeps 4.5 to 9 m away between shots
MonArcher:
 .a16
 .i16
 jsr DirFrom
 cmp #$FFFF
 beq @r
 sta tmpB
 jsr ClearLine
 bcs @approach
 lda tmp4
 cmp #176                   ; 11 m
 bcs @farline
 lda.w ecool,x
 bne @farline
 lda tmpB
 sta.w edir,x
 lda #ST_ATTACK
 sta.w est,x
 stz.w etm,x
 stz.w edealt,x
@r:
 rts
@farline:
 lda tmp4
 cmp #144
 bcs @approach
 cmp #72
 bcc @back
 lda tmpB
 sta.w edir,x
 stz.w est,x
 rts
@approach:
 lda tmpB
 sta.w edir,x
 jsr Walk
 bra @moving
@back:
 lda tmpB
 eor #4                     ; the other way, a little slower
 sta.w edir,x
 asl
 tay
 lda.w wspd_rx,y
 sta tmpC
 lda.w wspd_ry,y
 sta tmpD
 jsr WalkV
@moving:
 lda #ST_MOVE
 sta.w est,x
 lda.w eanimt,x
 clc
 adc #13
 sta.w eanimt,x
 rts

MonAttack:
 .a16
 .i16
 lda.w ekind,x
 beq @ghoul
 jsr RelHero                ; the archer: turns to aim while drawing, looses half way (0.35 s of 0.7)
 jsr DirFrom
 cmp #$FFFF
 beq @a1
 sta.w edir,x
@a1:
 lda.w etm,x
 cmp #21
 bne @a2
 jsr ShootArrow
@a2:
 lda.w etm,x
 cmp #42
 bcc @r
 stz.w est,x
 lda #72
 jsr RandRange
 clc
 adc #84
 sta.w ecool,x
@r:
 rts
@ghoul:
 lda.w etm,x
 cmp #25                    ; the blow lands at 0.42 s
 bne @end
 jsr RelHero
 lda tmp4
 cmp #26                    ; 1.6 m, in front
 bcs @end
 lda.w edir,x
 asl
 tay
 jsr DotDir
 sta tmp5
 lda tmp4
 asl
 clc
 adc tmp4
 sta tmp3
 lda tmp5
 bmi @end
 cmp tmp3
 bcc @end
 jsr MonsterBlow
@end:
 lda.w etm,x
 cmp #60
 bcc @r2
 stz.w est,x
 lda #48
 jsr RandRange
 clc
 adc #48
 sta.w ecool,x
@r2:
 rts

; MonsterBlow: X = monster: its strength (0 .. STR) against the hero's defense
MonsterBlow:
 .a16
 .i16
 lda.w estr,x
 jsl $800000+X_MonsterHit
 lda.w ex,x
 lsr4
 sta hfx
 lda.w ey,x
 lsr4
 sta hfy
 lda cMiss
 bne @miss
 phx
 ldx #0
 jsr HurtActor
 plx
@miss:
 jmp Thorns

MonHit:
 .a16
 .i16
 lda #25                    ; the ghoul's recoil 0.42 s, the skeleton's 0.33 s
 ldy.w ekind,x
 beq @g
 lda #20
@g:
 cmp.w etm,x
 beq @done
 bcs @r
@done:
 stz.w est,x
 lda #30
 sta.w ecool,x
@r:
 rts
