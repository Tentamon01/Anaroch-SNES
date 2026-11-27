; ---------------------------------------------------------------- the hero (main.c hero_update)
HERO_SWING = 45              ; the Wooden Sword: 0.75 s
HERO_HIT_AT = 20             ; heroAtkHit[sword] 0.44 of the swing
HERO_CHAIN = 41              ; a press after 0.92 of the swing chains the next
HERO_CANCEL = 36             ; movement cancels it after 0.8
REGEN_STEP = 12000           ; half a percent of life a second: maxHp / 12000 per frame

UpdateHero:
 .a16
 .i16
 inc.w etm
 lda.w est                  ; a swing runs at the weapon's speed
 cmp #ST_ATTACK
 bne @pace
 lda atkAcc
 clc
 adc swingStep
 sta atkAcc
 xba
 and #$00FF
 sta.w etm
@pace:
 lda.w eflash
 beq @nf
 dec.w eflash
@nf:
 lda padnew                 ; the belt: L / R choose a slot, X drinks from it
 and #PAD_L
 beq @nl
 lda beltsel
 clc
 adc #3
 and #3
 sta beltsel
 lda #1
 sta hudflag
@nl:
 lda padnew
 and #PAD_R
 beq @nr
 lda beltsel
 inc a
 and #3
 sta beltsel
 lda #1
 sta hudflag
@nr:
 lda padnew
 and #PAD_X
 beq @nx
 jsr BeltDrink
 lda mode
 beq @nx
 rts                        ; (the bag opened to read a scroll)
@nx:
 lda regen                  ; regeneration
 clc
 adc regenAdd
 sta regen
 cmp #REGEN_STEP
 bcc @nreg
 sec
 sbc #REGEN_STEP
 sta regen
 lda.w ehp
 cmp.w emaxhp
 bcs @nreg
 inc a
 sta.w ehp
 lda #1
 sta hudflag
@nreg:
 jsr PadDir
 sta tmpB                   ; the d-pad's direction or $FFFF
 lda.w est
 cmp #ST_ATTACK
 bne @na
 jmp @attack
@na:
 cmp #ST_HIT
 bne @nh
 lda.w etm
 cmp #15
 bcc @r
 stz.w est
 stz.w etm
@r:
 rts
@nh:
 lda padnew
 and #PAD_B|PAD_Y
 beq @move
 lda tmpB
 cmp #$FFFF
 beq @sw
 sta.w edir
@sw:
 lda #ST_ATTACK
 sta.w est
 stz.w etm
 stz.w edealt
 stz atkAcc
 lda #SFX_SWING
 jmp Sfx
@move:
 lda tmpB
 cmp #$FFFF
 beq @idle
 sta.w edir
 asl
 tax
 lda.w hspd,x
 sta tmpC
 lda.w hspd+16,x
 sta tmpD
 ldx #0
 jsr MoveEnt
 lda.w est
 cmp #ST_MOVE
 beq @wk
 lda #ST_MOVE
 sta.w est
 stz.w etm
@wk:
 lda.w eanimt
 clc
 adc #16
 sta.w eanimt
 rts
@idle:
 lda.w est
 beq @i2
 stz.w est
 stz.w etm
@i2:
 rts
@attack:
 lda.w etm
 cmp #HERO_HIT_AT
 bcc @nd
 lda.w edealt
 bne @nd
 inc.w edealt
 jsr HeroStrike
@nd:
 lda.w etm
 cmp #HERO_CHAIN
 bcc @nochain
 lda padnew
 and #PAD_B|PAD_Y
 beq @nochain
 lda tmpB
 cmp #$FFFF
 beq @c2
 sta.w edir
@c2:
 stz.w etm
 stz.w edealt
 stz atkAcc
 rts
@nochain:
 lda.w etm
 cmp #HERO_SWING
 bcs @toidle
 cmp #HERO_CANCEL
 bcc @r2
 lda tmpB
 cmp #$FFFF
 beq @r2
@toidle:
 stz.w est
 stz.w etm
@r2:
 rts

; PadDir -> A = direction from the d-pad, $FFFF for none
PadDir:
 .a16
 lda pad
 xba
 and #$000F
 asl
 tax
 lda dir_of,x
 rts

BeltDrink:
 .a16
 .i16
 jsl $800000+X_UseBelt
 rts

; the sword: every live monster within reach (1.8 m + 0.3) and in front (cos > 0.2)
HeroStrike:
 .a16
 .i16
 lda ranged
 beq @melee
 jmp ShootHero
@melee:
 stz landed
 ldx #2
@l:
 lda.w est,x
 cmp #ST_DEAD
 bcc @alive
 jmp @n
@alive:
 jsr RelHero
 lda #0
 sec
 sbc tmp0
 sta tmp0
 lda #0
 sec
 sbc tmp2
 sta tmp2                   ; hero -> monster
 lda tmp4
 cmp reachPx
 bcc @inreach
 jmp @n
@inreach:
 lda.w edir
 asl
 tay
 jsr DotDir
 sta tmp5
 lda tmp4
 asl
 sta tmp3
 lda tmp5
 bmi @n
 cmp tmp3
 bcc @n
 jsl $800000+X_HeroBlow
 lda.w ex
 lsr4
 sta hfx
 lda.w ey
 lsr4
 sta hfy
 lda hcrit
 beq @nc
 lda #2
 sta landed
 bra @hit
@nc:
 lda landed
 bne @hit
 lda #1
 sta landed
@hit:
 phx
 jsr HurtActor
 plx
@n:
 inx
 inx
 cpx #NACT*2
 beq @end
 jmp @l
@end:
 lda landed                 ; hitstop: 0.05 s, 0.09 s on a crit
 beq @r
 cmp #2
 beq @hc
 lda #3
 sta hitstop
 rts
@hc:
 lda #5
 sta hitstop
@r:
 rts

; HurtActor (main.c hurt): X = actor, hdmg, hfx / hfy = where the blow came from (px), hcrit = a bigger knockback
HurtActor:
 .a16
 .i16
 lda.w est,x
 cmp #ST_DEAD
 bcc @alive
 rts
@alive:
 lda #SFX_HIT
 cpx #0
 bne @snd
 lda #SFX_HURT
@snd:
 jsr Sfx
 lda.w ehp,x
 sec
 sbc hdmg
 bcs @hp
 lda #0
@hp:
 sta.w ehp,x
 lda #9
 sta.w eflash,x
 cpx #0
 bne @kb
 lda #1
 sta hudflag
@kb:
 lda.w ex,x                 ; knockback: 0.25 m, 0.45 m on a crit
 lsr4
 sec
 sbc hfx
 sta tmp0
 lda.w ey,x
 lsr4
 sec
 sbc hfy
 sta tmp2
 jsr Rot
 jsr DirFrom
 cmp #$FFFF
 beq @nokb
 asl
 tay
 lda hcrit
 bne @big
 lda.w wspd_kx,y
 sta tmpC
 lda.w wspd_ky,y
 sta tmpD
 bra @mv
@big:
 lda.w wspd_cx,y
 sta tmpC
 lda.w wspd_cy,y
 sta tmpD
@mv:
 jsr MoveEnt
@nokb:
 cpx #0
 beq @state
 lda #1                     ; a monster struck knows where it came from
 sta.w ealert,x
 stz.w elost,x
@state:
 lda.w ehp,x
 bne @live
 lda #SFX_MDIE
 cpx #0
 bne @snd2
 lda #SFX_DIE
@snd2:
 jsr Sfx
 lda #ST_DEAD
 sta.w est,x
 stz.w etm,x
 cpx #0
 beq @herodead
 jmp MonsterKilled
@herodead:
 lda #M_DEAD
 sta mode
 stz modet
 rts
@live:
 cpx #0
 bne @tohit
 lda.w est
 cmp #ST_ATTACK
 beq @r
@tohit:
 lda #ST_HIT
 sta.w est,x
 stz.w etm,x
@r:
 rts
