; The skills (skills.c and main.c of the N64 version): what the button casts, what lasts, the hero's arrows and
; bolts, and the sparks that show them. Monsters are walked as X = 2, 4 .. (their place among the actors).
; A blow can kill, and a kill runs the rules again (experience, drops): everything kept across a blow is in the s_
; words, never in r0..r7.
SK_SLAM = 0
SK_CONE = 1
SK_CRY = 2
SK_SPIN = 3
SK_LINE = 4
SK_LEAP = 5
SK_FAN = 6
SK_PIERCE = 7
SK_FIREARROW = 8
SK_STRAFE = 9
SK_EXPLODE = 10
SK_FIREBOLT = 11
SK_NOVA = 12
SK_HEAL = 13
SK_FIREBALL = 14
SK_CHAIN = 15
SK_TELEPORT = 16
SK_STOMP = 17
SK_ICEARROW = 18
SK_METEOR = 19
SK_PASSIVE = 20
SKILLS = 36
MAX_RANK = 20
; skill_tab, 32 bytes a skill
D_TREE = 0
D_TIER = 2
D_COL = 4
D_NEED = 6
D_LEVEL = 8
D_WEAPON = 10
D_KIND = 12
D_COST = 14
D_POWER = 16
D_A = 18
D_B = 20
D_WAIT = 22
D_NAME = 24
D_TEXT = 26
D_TEXT2 = 28
; the small pictures of the effects (sprite tiles)
FX_FIRE = $AA
FX_FROST = $AC
FX_SPARK = $AE
FX_HEAL = $EE
STAM_UNIT = 25000

; X = skill A's place in skill_tab
DefAt:
 .a16
 .i16
 asl
 asl
 asl
 asl
 asl
 tax
 rts

; A = skill -> A = its rank
RankOf:
 .a16
 .i16
 asl
 tax
 lda.w skRank,x
 rts

; a new hero knows nothing
SkillsNew:
 .a16
 .i16
 ldx #SKILLS * 2 - 2
@c:
 stz.w skRank,x
 dex
 dex
 bpl @c
 lda #$FFFF
 sta skActive
 stz skCur
 stz stamAcc
; nothing cast, nothing lasting, no sparks
SkillsCalm:
 .a16
 .i16
 lda #$FFFF
 sta casting
 stz cryLeft
 stz healLeft
 stz teleWait
 stz spinLeft
 stz leapLeft
 stz heroLift
 stz metLeft
 stz fighting
 ldx #FX_N * 2 - 2
@f:
 stz.w fxl,x
 dex
 dex
 bpl @f
 lda #1
 sta skDirty
 rts

; A = skill -> A = its cost in stamina at its rank
CostOf:
 .a16
 .i16
 pha
 jsr RankOf
 sta s9
 pla
 jsr DefAt
 lda.l skill_tab+D_COST,x
 sta rm
 lda s9
 beq @one
 dec a
@one:
 sta r7                     ; (rank - 1) * 6 %
 asl
 clc
 adc r7
 asl
 clc
 adc #100
 jsr Mul16
 lda #100
 jsr Div32
 lda rl
 rts

; A = skill, Y = a rank (0 counts as 1) -> A = its power in percent
PowerAt:
 .a16
 .i16
 jsr DefAt
 lda.l skill_tab+D_POWER,x
 sta rm
 tya
 beq @one
 dec a
@one:
 asl                        ; (rank - 1) * 12 %
 asl
 sta r7
 asl
 clc
 adc r7
 clc
 adc #100
 jsr Mul16
 lda #100
 jsr Div32
 lda rl
 rts

; A = a power in percent -> A = a spell's damage: (5 + level * 2.5) * power, the energy's and passives' bonus on top
SpellDamage:
 .a16
 .i16
 sta r7
 lda level
 sta r6
 asl
 asl
 clc
 adc r6
 clc
 adc #10                    ; twice the base
 sta rm
 lda r7
 jsr Mul16
 lda #200
 jsr Div32
 lda rl
 sta rm
 lda spellPm
 clc
 adc #1000
 jsr Mul16
 lda #1000
 jsr Div32
 lda rl
 rts

; A = a skill -> carry set when the weapon worn allows it
WeaponOk:
 .a16
 .i16
 jsr DefAt
 lda.l skill_tab+D_WEAPON,x
 beq @yes
 cmp #1
 beq @melee
 lda ranged
 bne @yes
 clc
 rts
@melee:
 lda ranged
 beq @yes
 clc
 rts
@yes:
 sec
 rts

; ---------------------------------------------------------------- learning
; A = skill -> carry set when a point can go into it; else msgp says why
CanLearn:
 .a16
 .i16
 sta s8
 jsr RankOf
 cmp #MAX_RANK
 bcc @r1
 lda #sk_highest
 bra @no
@r1:
 lda skillPts
 bne @r2
 lda #sk_nopoints
 bra @no
@r2:
 lda s8
 jsr DefAt
 lda level
 cmp.l skill_tab+D_LEVEL,x
 bcs @r3
 lda #msg_level
 bra @no
@r3:
 lda.l skill_tab+D_NEED,x
 bmi @yes
 asl
 tax
 lda.w skRank,x
 bne @yes
 lda #sk_above
@no:
 sta msgp
 clc
 rts
@yes:
 sec
 rts

; A = skill: a point into it, if it may
Learn:
 .a16
 .i16
 sta s8
 jsr CanLearn
 bcs @go
 rts
@go:
 lda s8
 asl
 tax
 inc.w skRank,x
 dec skillPts
 lda #sk_learned
 sta msgp
 lda s8
 jsr DefAt
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 beq @passive
 lda skActive
 bpl @done
 lda s8
 sta skActive
 bra @done
@passive:
 jsr StatsRecalc            ; a passive works at once
@done:
 lda #1
 sta skDirty
 sta hudflag
 sec
 rts

; the next learned skill that can be cast, on the button
NextSkill:
 .a16
 .i16
 lda #SKILLS
 sta s9
 lda skActive
 bpl @l
 lda #SKILLS - 1
@l:
 inc a
 cmp #SKILLS
 bcc @w
 lda #0
@w:
 sta s8
 jsr RankOf
 beq @n
 lda s8
 jsr DefAt
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 beq @n
 lda s8
 sta skActive
 lda #1
 sta skDirty
 lda.l skill_tab+D_NAME,x
 jmp SayRules
@n:
 lda s8
 dec s9
 bne @l
 lda #sk_none
 jmp SayRules

; ---------------------------------------------------------------- the button
; checks the weapon, the stamina and the wait, then starts the cast: it acts at the swing's blow
SkillStart:
 .a16
 .i16
 lda spinLeft
 ora leapLeft
 beq @free
 rts
@free:
 lda skActive
 bmi @none
 sta s8
 jsr RankOf
 bne @known
@none:
 lda #sk_none
 jmp SayRules
@known:
 lda s8
 jsr WeaponOk
 bcs @weapon
 lda s8
 jsr DefAt
 lda.l skill_tab+D_WEAPON,x
 cmp #1
 beq @nm
 lda #sk_bow
 jmp SayRules
@nm:
 lda #sk_melee
 jmp SayRules
@weapon:
 lda s8
 jsr DefAt
 lda.l skill_tab+D_KIND,x
 cmp #SK_TELEPORT
 bne @cost
 lda teleWait
 beq @cost
 rts
@cost:
 lda s8
 jsr CostOf
 sta s9
 lda stam
 cmp s9
 bcs @pay
 lda #sk_stamina
 jmp SayRules
@pay:
 sec
 sbc s9
 sta stam
 lda s8
 sta casting
 lda #ST_ATTACK
 sta.w est
 stz.w etm
 stz.w edealt
 stz atkAcc
 lda #1
 sta skDirty
 lda #SFX_SWING
 jsl FarSfx
 rts

; ---------------------------------------------------------------- monsters
; X = monster -> carry clear when it can be struck
Alive:
 .a16
 .i16
 lda.w est,x
 cmp #ST_DEAD
 rts

; X = monster, from the point (sx, sy) in pixels -> sdx, sdy = the way to it, A = how far (X kept)
Toward:
 .a16
 .i16
 lda.w ex,x
 lsr4
 sec
 sbc sx
 sta sdx
 bpl @ax
 eor #$FFFF
 inc a
@ax:
 sta r6
 lda.w ey,x
 lsr4
 sec
 sbc sy
 sta sdy
 bpl @ay
 eor #$FFFF
 inc a
@ay:
 cmp r6
 bcs @ymax
 sta r7                     ; dx is the longer: r6 + 3/8 r7
 bra @sum
@ymax:
 ldy r6
 sta r6
 sty r7
@sum:
 lda r7
 asl
 clc
 adc r7
 lsr
 lsr
 lsr
 clc
 adc r6
 rts

; the hero's place in pixels into sx, sy
AtHero:
 .a16
 lda.w ex
 lsr4
 sta sx
 lda.w ey
 lsr4
 sta sy
 rts

; A = a direction (+ 8: its right angle): the dot of (sdx, sdy) with it, ten to a pixel (X kept)
Dot:
 .a16
 .i16
 and #15
 asl
 tay
 lda sdx
 sta tmp0
 lda sdy
 sta tmp2
 jsl FarDot
 rts

; a blow of the weapon on monster X, skMult percent of it
HeroHit:
 .a16
 .i16
 phx
 jsr HeroBlow
 lda.w ex
 lsr4
 sta hfx
 lda.w ey
 lsr4
 sta hfy
 plx
 phx
 jsl FarHurt
 plx
 rts

; a spell on monster X: spellDmg, a seventh more or less
SpellHit:
 .a16
 .i16
 phx
 lda #31
 jsr RandN
 clc
 adc #85
 sta rm
 lda spellDmg
 jsr Mul16
 lda #100
 jsr Div32
 lda rl
 bne @d
 lda #1
@d:
 sta hdmg
 stz hcrit
 lda.w ex
 lsr4
 sta hfx
 lda.w ey
 lsr4
 sta hfy
 plx
 phx
 jsl FarHurt
 plx
 rts

; every living monster within sRad of (sx, sy) -> sHit: 0 a blow, 1 a spell; sStun and sChill laid on those left
Around:
 .a16
 .i16
 ldx #2
@l:
 jsr Alive
 bcs @n
 jsr Toward
 cmp sRad
 bcs @n
 lda sHit
 bne @spell
 jsr HeroHit
 bra @after
@spell:
 jsr SpellHit
@after:
 jsr Afflict
@n:
 inx
 inx
 cpx #NACT*2
 bcc @l
 rts

Afflict:                     ; stun and chill on monster X, if it lives
 .a16
 .i16
 jsr Alive
 bcs @r
 lda sStun
 cmp.w estun,x
 bcc @c
 sta.w estun,x
@c:
 lda sChill
 cmp.w echill,x
 bcc @r
 sta.w echill,x
@r:
 rts

; A = signed value, times rm over Y, keeping the sign
SScale:
 .a16
 .i16
 sty r7
 sta r6
 cmp #0
 bpl @p
 eor #$FFFF
 inc a
@p:
 jsr Mul16
 lda r7
 jsr Div32
 lda r6
 bmi @m
 lda rl
 rts
@m:
 lda rl
 eor #$FFFF
 inc a
 rts

; ---------------------------------------------------------------- sparks
; a spark at (px, py) pixels, moving (vx, vy) sixteenths a frame, pz above the floor, vz; A = its life, Y = its picture
Spark:
 .a16
 .i16
 sta s9
 phx
 ldx #0
@f:
 lda.w fxl,x
 beq @got
 inx
 inx
 cpx #FX_N * 2
 bcc @f
 plx
 rts
@got:
 lda s9
 sta.w fxl,x
 tya
 sta.w fxt,x
 lda px
 asl4
 sta.w fxx,x
 lda py
 asl4
 sta.w fxy,x
 lda vx
 sta.w fxvx,x
 lda vy
 sta.w fxvy,x
 lda pz
 sta.w fxz,x
 lda vz
 sta.w fxvz,x
 plx
 rts

; Y = picture, A = radius in pixels: eight sparks run out from (px, py) to that far in 16 frames
Ring:
 .a16
 .i16
 sta ringR
 sty ringT
 phx
 stz pz
 stz vz
 ldx #0
@l:
 stx ringI
 lda.l wspd_hx,x
 jsr RingSpeed
 sta vx
 ldx ringI
 lda.l wspd_hy,x
 jsr RingSpeed
 sta vy
 ldy ringT
 lda #16
 jsr Spark
 ldx ringI
 inx
 inx
 cpx #16
 bcc @l
 plx
 rts
RingSpeed:
 .a16
 ldy ringR
 sty rm
 ldy #15
 jmp SScale

; a spark standing at (px, py) for A frames, Y = picture
Puff:
 .a16
 .i16
 stz vx
 stz vy
 stz vz
 pha
 lda #8
 sta pz
 pla
 jmp Spark

SparkUpdate:
 .a16
 .i16
 ldx #FX_N * 2 - 2
@l:
 lda.w fxl,x
 beq @n
 dec.w fxl,x
 lda.w fxx,x
 clc
 adc.w fxvx,x
 sta.w fxx,x
 lda.w fxy,x
 clc
 adc.w fxvy,x
 sta.w fxy,x
 lda.w fxz,x
 clc
 adc.w fxvz,x
 sta.w fxz,x
@n:
 dex
 dex
 bpl @l
 rts

RingAtHero:                  ; A = radius, Y = picture
 .a16
 pha
 jsr AtHero
 lda sx
 sta px
 lda sy
 sta py
 pla
 jmp Ring

; ---------------------------------------------------------------- shots
; the way the hero faces, at shSpeed sixteenths a frame -> shVx, shVy
Facing:
 .a16
 .i16
 phx
 lda.w edir
 asl
 tax
 lda shSpeed
 sta rm
 phx
 lda.l wspd_hx,x
 ldy #15
 jsr SScale
 sta shVx
 plx
 lda.l wspd_hy,x
 ldy #15
 jsr SScale
 sta shVy
 plx
 rts

; toward monster X from the hero -> shVx, shVy (X kept)
AimAt:
 .a16
 .i16
 jsr AtHero
 jsr Toward
 cmp #1
 bcs @d
 jmp Facing
@d:
 sta s7
 lda shSpeed
 sta rm
 lda sdx
 ldy s7
 jsr SScale
 sta shVx
 lda sdy
 ldy s7
 jsr SScale
 sta shVy
 rts

; the nearest living monster ahead: within aimRange, its dot at least aimCos tenths of its distance -> X, carry set
Nearest:
 .a16
 .i16
 jsr AtHero
 lda aimRange
 sta s6                     ; the best so far
 lda #$FFFF
 sta s5
 ldx #2
@l:
 jsr Alive
 bcs @n
 jsr Toward
 cmp s6
 bcs @n
 sta s7
 lda.w edir
 jsr Dot
 bmi @n
 sta s4
 lda s7
 sta rm
 lda aimCos
 jsr Mul16
 lda s4
 cmp rl
 bcc @n
 lda s7
 sta s6
 stx s5
@n:
 inx
 inx
 cpx #NACT*2
 bcc @l
 ldx s5
 bmi @none
 sec
 rts
@none:
 clc
 rts

; shVx, shVy toward the nearest ahead (aimRange, aimCos), else straight on
AimVel:
 .a16
 .i16
 jsr Nearest
 bcc @on
 jmp AimAt
@on:
 jmp Facing

; an arrow or a bolt from the hero: shVx, shVy, shKind, shMult, shBurst, shPierce, shRange (pixels), shSpeed
Shoot:
 .a16
 .i16
 phx
 ldx #0
@f:
 lda.w alife,x
 beq @got
 inx
 inx
 cpx #NARROW*2
 bcc @f
 plx
 rts
@got:
 lda #1
 sta.w aown,x
 lda.w ex
 sta.w ax,x
 lda.w ey
 sta.w ay,x
 lda shVx
 sta.w avx,x
 lda shVy
 sta.w avy,x
 lda shKind
 sta.w akind,x
 lda shMult
 sta.w amult,x
 lda shBurst
 sta.w aburst,x
 lda shPierce
 sta.w apierce,x
 stz.w ahit,x
 lda shRange                ; frames = range * 16 / speed
 asl4
 sta rl
 stz rh
 lda shSpeed
 jsr Div32
 lda rl
 sta.w alife,x
 phx
 lda shVx
 sta tmp0
 lda shVy
 sta tmp2
 jsl FarDirFrom
 plx
 cmp #8
 bcc @dir
 lda.w edir
@dir:
 sta.w adir,x
 plx
 rts

; a bow's shot: aimed at a foe nearly ahead
ArrowShot:
 .a16
 .i16
 jsr PlainShot
 lda #SFX_BOW
 jsl FarSfx
 rts
PlainShot:
 .a16
 .i16
 jsr ShotDefaults
 jsr AimVel
 jmp Shoot
ShotDefaults:
 .a16
 stz shKind
 stz shBurst
 stz shPierce
 lda #100
 sta shMult
 lda #55                    ; 13 m/s
 sta shSpeed
 lda reachPx
 sta shRange
 sta aimRange
 lda #8                     ; within about 35 degrees
 sta aimCos
 rts

; the hero's arrow or bolt at X flies one frame
HeroArrow:
 .a16
 .i16
 dec.w alife,x
 bne @fly
 jmp ShotEnds
@fly:
 lda.w ax,x
 clc
 adc.w avx,x
 sta.w ax,x
 lsr4
 sta sx
 sta tmp6
 lda.w ay,x
 clc
 adc.w avy,x
 sta.w ay,x
 lsr4
 sta sy
 sta tmp7
 phx
 jsl FarBlocked
 plx
 bcc @open
 jmp ShotEnds
@open:
 lda.w akind,x              ; a trail behind the burning and the freezing ones
 beq @seek
 lda frame
 and #3
 bne @seek
 lda sx
 sta px
 lda sy
 sta py
 ldy #FX_FIRE
 lda.w akind,x
 cmp #5
 bne @t
 ldy #FX_FROST
@t:
 lda #8
 jsr Puff
@seek:
 stx shot                   ; (the arrow)
 ldx #2
@m:
 jsr Alive
 bcc @_far1
 jmp @next
@_far1:
 ldy shot
 txa
 lsr
 phx
 tax
 lda.l bit_of-1,x
 and #$00FF
 sta s7
 plx
 lda.w ahit,y
 and s7
 bne @next
 lda.w ex,x
 lsr4
 sec
 sbc sx
 bpl @a1
 eor #$FFFF
 inc a
@a1:
 cmp #8
 bcs @next
 lda.w ey,x
 lsr4
 sec
 sbc sy
 bpl @a2
 eor #$FFFF
 inc a
@a2:
 cmp #8
 bcs @next
 lda.w ahit,y
 ora s7
 sta.w ahit,y
 lda.w aburst,y
 beq @hit
 ldx shot
 jmp ShotEnds
@hit:
 phy
 lda.w akind,y
 cmp #2
 beq @bolt
 sta s7
 lda.w amult,y
 sta skMult
 jsr HeroHit
 lda s7
 cmp #5
 bne @struck
 stz sStun
 lda #180                   ; an ice arrow chills
 sta sChill
 jsr Afflict
 bra @struck
@bolt:
 lda.w amult,y
 sta spellDmg
 jsr SpellHit
@struck:
 ply
 lda.w apierce,y
 bne @next
 tyx
 stz.w alife,x
 rts
@next:
 inx
 inx
 cpx #NACT*2
 bcs @_far2
 jmp @m
@_far2:
 rts

; the shot at X is over: one that bursts, bursts
ShotEnds:
 .a16
 .i16
 stz.w alife,x
 lda.w aburst,x
 bne @burst
 rts
@burst:
 sta sRad
 lda.w ax,x
 lsr4
 sta sx
 sta px
 lda.w ay,x
 lsr4
 sta sy
 sta py
 lda.w amult,x
 sta skMult
 sta spellDmg
 stz sHit
 stz sStun
 stz sChill
 lda.w akind,x
 cmp #3
 bne @w
 lda #1                     ; a fireball is a spell; the burning arrows strike with the weapon
 sta sHit
@w:
; the burst: sparks to its edge, then what it does there
Burst:
 .a16
 .i16
 lda sRad
 ldy #FX_FIRE
 jsr Ring
 lda #SFX_HIT
 jsl FarSfx
 jmp Around

; ---------------------------------------------------------------- the cast, at the swing's blow
SkillFire:
 .a16
 .i16
 lda casting
 bmi @r
 sta sk
 lda #$FFFF
 sta casting
 lda sk
 jsr RankOf
 tay
 lda sk
 jsr PowerAt
 sta skPow
 lda sk
 jsr DefAt
 lda.l skill_tab+D_A,x
 sta skA
 lda.l skill_tab+D_B,x
 sta skB
 lda.l skill_tab+D_WAIT,x
 sta skW
 lda.l skill_tab+D_KIND,x
 asl
 tax
 jsr (cast_tab,x)
@r:
 rts

cast_tab:
 .word CSlam, CSlam, CCry, CSpin, CLine, CLeap, CFan, CPierce, CFireArrow, CStrafe, CExplode
 .word CFireBolt, CNova, CHeal, CFireBall, CChain, CTeleport, CStomp, CIceArrow, CMeteor

; Bash (one foe, stunned) and Cleave (all before him)
CSlam:
 .a16
 .i16
 lda skPow
 sta skMult
 jsr AtHero
 lda reachPx
 clc
 adc #5
 sta sRad
 lda sk
 jsr DefAt
 lda.l skill_tab+D_KIND,x
 sta s3                     ; 0 Bash, 1 Cleave
 beq @r
 lda sRad
 clc
 adc #5
 sta sRad
@r:
 ldx #2
@l:
 jsr Alive
 bcs @n
 jsr Toward
 cmp sRad
 bcs @n
 sta s7
 lda.w edir
 jsr Dot
 bmi @n
 sta s4
 lda s7                     ; within 60 degrees of ahead
 asl
 asl
 clc
 adc s7
 cmp s4
 beq @in
 bcs @n
@in:
 jsr HeroHit
 lda.w ex,x
 lsr4
 sta px
 lda.w ey,x
 lsr4
 sta py
 ldy #FX_SPARK
 lda #12
 jsr Ring
 lda s3
 bne @n
 lda skB
 sta sStun
 stz sChill
 jmp Afflict                ; Bash: one foe
@n:
 inx
 inx
 cpx #NACT*2
 bcc @l
 rts

CCry:
 .a16
 lda skA
 sta cryLeft
 lda skPow
 sta cryBonus
 lda #56
 ldy #FX_SPARK
 jsr RingAtHero
 lda #SFX_LEVEL
 jsl FarSfx
 rts

CSpin:
 .a16
 lda #75
 sta spinLeft
 stz spinPulse
 rts

; Shockwave: a wave runs ahead
CLine:
 .a16
 .i16
 lda skPow
 sta skMult
 jsr AtHero
 lda skA                    ; length and half width, ten to a pixel
 asl
 asl
 clc
 adc skA
 asl
 sta s2
 lda skB
 asl
 asl
 clc
 adc skB
 asl
 sta s1
 ldx #2
@l:
 jsr Alive
 bcs @n
 jsr Toward
 lda.w edir
 jsr Dot
 bmi @n
 cmp s2
 bcs @n
 lda.w edir
 ora #8
 jsr Dot
 bpl @side
 eor #$FFFF
 inc a
@side:
 cmp s1
 bcs @n
 jsr HeroHit
 lda #36
 sta sStun
 stz sChill
 jsr Afflict
@n:
 inx
 inx
 cpx #NACT*2
 bcc @l
 jsr ShotDefaults           ; the wave: sparks running ahead
 lda #48
 sta shSpeed
 jsr Facing
 jsr AtHero
 lda sx
 sta px
 lda sy
 sta py
 stz pz
 stz vz
 lda #4
 sta s3
@w:
 lda shVx
 ldy s3
 jsr Quarter
 sta vx
 lda shVy
 ldy s3
 jsr Quarter
 sta vy
 ldy #FX_SPARK
 lda #30
 jsr Spark
 dec s3
 bne @w
 lda #SFX_HIT
 jsl FarSfx
 rts

; Leap Slam: through the air onto the foe ahead
CLeap:
 .a16
 .i16
 lda skA
 sta aimRange
 lda #5
 sta aimCos
 jsr Nearest
 bcc @on
 jsr AtHero
 jsr Toward
 cmp #12
 bcc @on
 sta s7                     ; just short of it: the way * (d - 10) / d
 sec
 sbc #10
 sta s6
 lda sdx
 ldy s6
 sty rm
 ldy s7
 jsr SScale
 sta s2
 lda sdy
 ldy s6
 sty rm
 ldy s7
 jsr SScale
 sta s1
 bra @go
@on:
 lda skA                    ; seven tenths of the range, straight on
 asl
 asl
 asl
 sec
 sbc skA
 sta rm
 lda #16
 sta shSpeed
 lda rm
 sta s6
 lda.w edir
 asl
 tax
 lda s6
 sta rm
 lda.l wspd_hx,x
 ldy #150
 jsr SScale
 sta s2
 lda.w edir
 asl
 tax
 lda s6
 sta rm
 lda.l wspd_hy,x
 ldy #150
 jsr SScale
 sta s1
@go:
 lda #16                    ; sixteenths a frame over 29 frames
 sta rm
 lda s2
 ldy #29
 jsr SScale
 sta leapVx
 lda #16
 sta rm
 lda s1
 ldy #29
 jsr SScale
 sta leapVy
 lda #29
 sta leapLeft
 rts

CFan:
 .a16
 .i16
 jsr ShotDefaults
 lda skPow
 sta shMult
 jsr Facing
 lda shVx
 sta s2
 lda shVy
 sta s1
 stz s3
@l:
 lda s3
 asl
 tax
 lda skA
 cmp #6
 bcs @nine
 lda.l fan5,x
 bra @k
@nine:
 lda.l fan9,x
@k:
 sta s0                     ; this arrow's turn: v + (-vy, vx) * k / 256
 bpl @kp
 eor #$FFFF
 inc a
@kp:
 sta rm
 lda s1
 ldy #256
 jsr SScale
 ldx s0
 bmi @n1
 eor #$FFFF
 inc a
@n1:
 clc
 adc s2
 sta shVx
 lda s0
 bpl @kq
 eor #$FFFF
 inc a
@kq:
 sta rm
 lda s2
 ldy #256
 jsr SScale
 ldx s0
 bpl @n2
 eor #$FFFF
 inc a
@n2:
 clc
 adc s1
 sta shVy
 jsr Shoot
 inc s3
 lda s3
 cmp skA
 bcc @l
 lda #SFX_BOW
 jsl FarSfx
 rts

CPierce:
 .a16
 lda #0                     ; kind, burst, pierce, speed
 ldx #83
 ldy #1
 jmp OneArrow
CFireArrow:
 .a16
 lda #1
 ldx #55
 ldy #0
 jmp OneArrow
CExplode:
 .a16
 lda #4
 ldx #55
 ldy #0
 jmp OneArrow
CIceArrow:
 .a16
 lda #5
 ldx #72
 ldy #1
 jmp OneArrow
OneArrow:
 .a16
 .i16
 pha
 phx
 phy
 jsr ShotDefaults
 pla
 sta shPierce
 pla
 sta shSpeed
 pla
 sta shKind
 cmp #1
 beq @burst
 cmp #4
 bne @go
@burst:
 lda skA
 sta shBurst
@go:
 lda skPow
 sta shMult
 jsr AimVel
 jsr Shoot
 lda #SFX_BOW
 jsl FarSfx
 rts

; Strafe: an arrow at each foe near, up to six
CStrafe:
 .a16
 .i16
 jsr ShotDefaults
 lda skPow
 sta shMult
 stz s3
 ldx #2
@l:
 jsr Alive
 bcs @n
 jsr AtHero
 jsr Toward
 cmp reachPx
 bcs @n
 jsr AimAt
 jsr Shoot
 inc s3
 lda s3
 cmp skA
 bcs @done
@n:
 inx
 inx
 cpx #NACT*2
 bcc @l
 lda s3
 bne @done
 jsr Facing
 jsr Shoot
@done:
 lda #SFX_BOW
 jsl FarSfx
 rts

CFireBolt:
 .a16
 lda #2
 ldx #51
 ldy #0
 jmp Bolt
CFireBall:
 .a16
 lda #3
 ldx #43
 ldy skA
Bolt:                        ; A = kind, X = speed, Y = burst
 .a16
 .i16
 pha
 phx
 phy
 jsr ShotDefaults
 pla
 sta shBurst
 pla
 sta shSpeed
 pla
 sta shKind
 lda #160                   ; 10 m
 sta shRange
 sta aimRange
 lda skPow
 jsr SpellDamage
 sta shMult
 jsr AimVel
 jsr Shoot
 lda #SFX_GROWL
 jsl FarSfx
 rts

CNova:
 .a16
 lda skPow
 jsr SpellDamage
 sta spellDmg
 jsr AtHero
 lda skA
 sta sRad
 lda #1
 sta sHit
 stz sStun
 lda skB
 sta sChill
 lda skA
 ldy #FX_FROST
 jsr RingAtHero
 lda skA
 lsr
 ldy #FX_FROST
 jsr RingAtHero
 lda #SFX_HIT
 jsl FarSfx
 jsr AtHero
 jmp Around

CStomp:
 .a16
 lda skPow
 sta skMult
 lda skA
 sta sRad
 stz sHit
 lda skB
 sta sStun
 stz sChill
 lda skA
 ldy #FX_SPARK
 jsr RingAtHero
 lda #SFX_HIT
 jsl FarSfx
 jsr AtHero
 jmp Around

CHeal:                       ; Second Wind: a share of life over a few seconds
 .a16
 .i16
 lda skA
 sta healLeft
 lda.w emaxhp
 sta rm
 lda skPow
 jsr Mul16
 lda #100
 jsr Div32
 lda rl                     ; life * 256 / frames, a frame
 xba
 and #$00FF
 sta rh
 lda rl
 xba
 and #$FF00
 sta rl
 lda skA
 jsr Div32
 lda rl
 sta healAdd
 stz healAcc
 lda #24
 ldy #FX_HEAL
 jsr RingAtHero
 lda #SFX_DRINK
 jsl FarSfx
 rts

; Chain Lightning: from foe to foe
CChain:
 .a16
 .i16
 lda skPow
 jsr SpellDamage
 sta spellDmg
 jsr AtHero
 stz s2                     ; whom it has leapt to
 lda skA
 sta s1                     ; leaps left
@next:
 lda skB
 sta s6
 lda #$FFFF
 sta s5
 ldx #2
@l:
 jsr Alive
 bcs @n
 txa
 lsr
 phx
 tax
 lda.l bit_of-1,x
 plx
 and #$00FF
 and s2
 bne @n
 jsr Toward
 cmp s6
 bcs @n
 sta s6
 stx s5
@n:
 inx
 inx
 cpx #NACT*2
 bcc @l
 ldx s5
 bmi @done
 txa
 lsr
 tax
 lda.l bit_of-1,x
 and #$00FF
 ora s2
 sta s2
 ldx s5
 jsr Toward                 ; sparks along the leap
 lda #3
 sta s3
@s:
 lda sdx
 ldy s3
 jsr Quarter
 clc
 adc sx
 sta px
 lda sdy
 ldy s3
 jsr Quarter
 clc
 adc sy
 sta py
 ldy #FX_SPARK
 lda #14
 jsr Puff
 dec s3
 bne @s
 lda.w ex,x
 lsr4
 sta sx
 lda.w ey,x
 lsr4
 sta sy
 jsr SpellHit
 dec s1
 beq @_far3
 jmp @next
@_far3:
@done:
 lda #SFX_HIT
 jsl FarSfx
 rts
Quarter:                     ; A * Y / 4, signed (Y 1..3)
 .a16
 .i16
 sty rm
 ldy #4
 jmp SScale

; Teleport: the furthest free spot ahead, up to 8 m
CTeleport:
 .a16
 .i16
 lda skW
 sta teleWait
 lda #16
 ldy #FX_FROST
 jsr RingAtHero
 jsr AtHero
 lda sx
 sta s2
 lda sy
 sta s1
 lda #8
 sta s3                     ; how far this look is
@l:
 lda.w edir
 asl
 tax
 lda s3
 sta rm
 lda.l wspd_hx,x
 ldy #15
 jsr SScale
 clc
 adc sx
 sta s5
 lda.w edir
 asl
 tax
 lda s3
 sta rm
 lda.l wspd_hy,x
 ldy #15
 jsr SScale
 clc
 adc sy
 sta s4
 lda s5
 asl4
 sta tmpF
 lda s4
 asl4
 sta tmpG
 jsl FarFoot
 bcs @blocked
 lda s5
 sta s2
 lda s4
 sta s1
@blocked:
 lda s3
 clc
 adc #8
 sta s3
 cmp skA
 beq @l
 bcc @l
 lda s2
 asl4
 sta.w ex
 lda s1
 asl4
 sta.w ey
 lda #32
 ldy #FX_FROST
 jsr RingAtHero
 lda #SFX_LEVEL
 jsl FarSfx
 rts

; Meteor: where the nearest foe in front stands, or ahead, a stone falls
CMeteor:
 .a16
 .i16
 lda #192
 sta aimRange
 lda #7
 sta aimCos
 jsr Nearest
 bcc @ahead
 lda.w ex,x
 lsr4
 sta metX
 lda.w ey,x
 lsr4
 sta metY
 bra @set
@ahead:
 lda.w edir
 asl
 tax
 lda #96
 sta rm
 phx
 lda.l wspd_hx,x
 ldy #15
 jsr SScale
 clc
 adc sx
 sta metX
 plx
 lda #96
 sta rm
 lda.l wspd_hy,x
 ldy #15
 jsr SScale
 clc
 adc sy
 sta metY
@set:
 lda skB
 sta metLeft
 lda skA
 sta metRad
 lda skPow
 jsr SpellDamage
 sta metDmg
 rts

; ---------------------------------------------------------------- what lasts, once a frame
; -> A = 0 the hero is free, 1 spinning (he may walk), 2 in the air
SkillTick:
 .a16
 .i16
 lda frame
 and #7
 bne @stam
 stz fighting               ; a living foe within 8 m
 jsr AtHero
 ldx #2
@f:
 jsr Alive
 bcs @fn
 jsr Toward
 cmp #128
 bcs @fn
 lda #1
 sta fighting
@fn:
 inx
 inx
 cpx #NACT*2
 bcc @f
@stam:
 lda stam                   ; stamina comes back, slower in a fight
 cmp maxStam
 bcs @timers
 lda stamRate
 ldx fighting
 beq @add
 lda stamFight
@add:
 clc
 adc stamAcc
@more:
 cmp #STAM_UNIT
 bcc @kept
 sec
 sbc #STAM_UNIT
 ldx stam
 cpx maxStam
 bcs @more
 inc stam
 ldx #1
 stx skDirty
 bra @more
@kept:
 sta stamAcc
@timers:
 lda cryLeft
 beq @nc
 dec cryLeft
 lda frame
 and #15
 bne @nc
 lda #10
 ldy #FX_SPARK
 jsr RingAtHero
@nc:
 lda teleWait
 beq @nt
 dec teleWait
@nt:
 lda healLeft
 beq @nh
 dec healLeft
 lda healAcc
 clc
 adc healAdd
 pha
 and #$00FF
 sta healAcc
 pla
 xba
 and #$00FF
 beq @nh
 clc
 adc.w ehp
 cmp.w emaxhp
 bcc @hp
 lda.w emaxhp
@hp:
 sta.w ehp
 lda #1
 sta hudflag
 lda frame
 and #7
 bne @nh
 jsr AtHero
 lda sx
 sta px
 lda sy
 sta py
 ldy #FX_HEAL
 lda #12
 jsr Puff
@nh:
 lda metLeft
 beq @nm
 lda metX                   ; falling: fire from the sky
 sta px
 lda metY
 sta py
 stz vx
 stz vy
 stz vz
 lda metLeft
 asl
 sta pz
 ldy #FX_FIRE
 lda #6
 jsr Spark
 dec metLeft
 bne @nm
 lda metX
 sta sx
 sta px
 lda metY
 sta sy
 sta py
 lda metRad
 sta sRad
 lda metDmg
 sta spellDmg
 lda #1
 sta sHit
 stz sStun
 stz sChill
 jsr Burst
@nm:
 lda skDirty
 beq @nd
 jsr SkillHud
@nd:
 lda spinLeft
 beq @nospin
 dec spinLeft               ; Whirlwind: turn fast, strike all around four times
 lda spinLeft
 lsr
 and #7
 sta.w edir
 lda spinPulse
 beq @pulse
 dec spinPulse
 lda #1
 rts
@pulse:
 lda #18
 sta spinPulse
 lda #3                     ; (Whirlwind)
 tax
 lda.w skRank+6
 tay
 txa
 jsr PowerAt
 sta skMult
 lda #3
 jsr DefAt
 lda.l skill_tab+D_A,x
 sta sRad
 ldy #FX_SPARK
 jsr RingAtHero
 stz sHit
 stz sStun
 stz sChill
 jsr AtHero
 jsr Around
 lda #SFX_SWING
 jsl FarSfx
 lda #1
 rts
@nospin:
 lda leapLeft
 bne @leap
 lda #0
 rts
@leap:
 dec leapLeft
 lda leapVx
 sta tmpC
 lda leapVy
 sta tmpD
 ldx #0
 jsl FarMove
 lda leapLeft
 asl
 tax
 lda.l leap_lift,x
 sta heroLift
 lda leapLeft
 bne @air
 stz heroLift               ; the crash
 stz.w est
 stz.w etm
 lda.w skRank+10            ; (Leap Slam, skill 5)
 tay
 lda #5
 jsr PowerAt
 sta skMult
 lda #5
 jsr DefAt
 lda.l skill_tab+D_B,x
 sta sRad
 ldy #FX_SPARK
 jsr RingAtHero
 stz sHit
 lda #60
 sta sStun
 stz sChill
 jsr AtHero
 jsr Around
 lda #SFX_HIT
 jsl FarSfx
@air:
 lda #2
 rts

leap_lift:
 .word 0, 5, 9, 13, 16, 19, 21, 23, 24, 25, 26, 26, 26, 26, 26, 25, 25, 24, 23, 22, 21, 19, 17, 15, 13, 11, 8, 5, 3, 0
bit_of: .byte 1, 2, 4, 8, 16, 32, 64, 128

; ---------------------------------------------------------------- the passives (stats_recalc)
Passives:
 .a16
 .i16
 stz spellPm
 stz stamRegen
 ldx famNow
 lda.l fam_ranged,x
 and #$00FF
 sta q3                     ; a bow is worn
 stz q0
@l:
 lda q0
 asl
 tax
 lda.w skRank,x
 beq @n
 sta q2
 lda q0
 jsr DefAt
 lda.l skill_tab+D_KIND,x
 cmp #SK_PASSIVE
 bne @n
 lda.l skill_tab+D_POWER,x
 sta rm
 lda.l skill_tab+D_A,x
 sta q1                     ; what it gives
 lda q2
 jsr Mul16
 ldy rl                     ; rank * per rank
 lda q1
 asl
 tax
 jsr (passive_tab,x)
@n:
 inc q0
 lda q0
 cmp #SKILLS
 bcc @l
 rts
passive_tab:
 .word PMelee, PDef, PSteal, PMeleeSpeed, PLife, PBow, PCrit, PEvade, PBowSpeed, PMove, PSpell, PStam, PBlock, PFire, PRegen
PMelee:
 .a16
 lda q3
 bne PNone
PEnh:
 tya
 clc
 adc pmods+K_ENHANCE_DAMAGE_PERCENT*2
 sta pmods+K_ENHANCE_DAMAGE_PERCENT*2
PNone:
 rts
PBow:
 .a16
 lda q3
 bne PEnh
 rts
PDef:
 .a16
 tya
 clc
 adc pmods+K_DEFENSE_PERCENT*2
 sta pmods+K_DEFENSE_PERCENT*2
 rts
PSteal:
 .a16
 .i16
 cpy #16
 bcc @s
 ldy #15
@s:
 tya
 clc
 adc pmods+K_LIFESTEAL_PERCENT*2
 sta pmods+K_LIFESTEAL_PERCENT*2
 rts
PMeleeSpeed:
 .a16
 lda q3
 bne PNone
PSpeed:
 tya
 clc
 adc pmods+K_ATTACK_SPEED_PERCENT*2
 sta pmods+K_ATTACK_SPEED_PERCENT*2
 rts
PBowSpeed:
 .a16
 lda q3
 bne PSpeed
 rts
PLife:
 .a16
 tya
 clc
 adc pmods+K_MAX_LIFE_PERCENT*2
 sta pmods+K_MAX_LIFE_PERCENT*2
 rts
PCrit:
 .a16
 tya
 clc
 adc pmods+K_CRIT_CHANCE_PERCENT*2
 sta pmods+K_CRIT_CHANCE_PERCENT*2
 rts
PEvade:
 .a16
 tya
 clc
 adc pmods+K_EVADE_CHANCE_PERCENT*2
 sta pmods+K_EVADE_CHANCE_PERCENT*2
 rts
PMove:
 .a16
 tya
 clc
 adc pmods+K_MOVE_SPEED_PERCENT*2
 sta pmods+K_MOVE_SPEED_PERCENT*2
 rts
PSpell:
 .a16
 tya                        ; percent -> of a thousand
 asl
 sta r7
 asl
 asl
 clc
 adc r7
 clc
 adc spellPm
 sta spellPm
 rts
PStam:
 .a16
 tya
 clc
 adc stamRegen
 sta stamRegen
 rts
PBlock:
 .a16
 tya
 clc
 adc pmods+K_BLOCK_CHANCE_PERCENT*2
 sta pmods+K_BLOCK_CHANCE_PERCENT*2
 rts
PFire:
 .a16
 tya
 clc
 adc pmods+K_FIRE_DAMAGE*2
 sta pmods+K_FIRE_DAMAGE*2
 rts
PRegen:
 .a16
 tya
 clc
 adc pmods+K_LIFE_REGEN_PERCENT*2
 sta pmods+K_LIFE_REGEN_PERCENT*2
 rts

; ---------------------------------------------------------------- the button's skill and the stamina, right of the belt
HUD_SKILL = 23 * 32 + 20
SkillHud:
 .a16
 .i16
 stz skDirty
 lda mode
 beq @play
 rts
@play:
 jsr NameStart
 ldx #0
@pad:
 jsr Space
 inx
 cpx #12
 bcc @pad
 lda #HUD_SKILL
 ldy #HUD_PRIO
 jsr Show
 lda #HUD_SKILL + 32
 ldy #HUD_PRIO
 jsr Show
 lda skActive
 bmi @stam
 jsr DefAt
 lda.l skill_tab+D_NAME,x
 jsr Note0
 lda nlen                   ; a long name is cut at its last space that fits
 cmp #13
 bcc @fits
 ldx #12
@back:
 lda.w namebuf,x
 and #$00FF
 cmp #32
 beq @cut
 dex
 bne @back
 ldx #12
@cut:
 stz.w namebuf,x
@fits:
 lda skActive
 jsr CostOf
 sta s9
 lda skActive
 jsr WeaponOk
 ldy #HUD_PRIO              ; white when it cannot be cast now
 bcc @n
 lda stam
 cmp s9
 bcc @n
 ldy #$0400 | HUD_PRIO
@n:
 lda #HUD_SKILL
 jsr Show
@stam:
 lda #sk_st
 jsr Note0
 lda stam
 jsr AppendNum
 lda #47
 jsr AppendChar
 lda maxStam
 jsr AppendNum
 lda #HUD_SKILL + 32
 ldy #HUD_PRIO
 jmp Show

sk_highest:  .byte "HIGHEST RANK", 0
sk_nopoints: .byte "NO SKILL POINTS: GAIN A LEVEL", 0
sk_above:    .byte "LEARN THE ONE ABOVE FIRST", 0
sk_learned:  .byte "LEARNED", 0
sk_none:     .byte "NO SKILL CHOSEN", 0
sk_bow:      .byte "NEEDS A BOW", 0
sk_melee:    .byte "NEEDS A MELEE WEAPON", 0
sk_stamina:  .byte "NOT ENOUGH STAMINA", 0
sk_st:       .byte "ST ", 0
