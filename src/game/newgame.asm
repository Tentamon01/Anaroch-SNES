; ---------------------------------------------------------------- a new game / rising again (main.c new_game, respawn)
NewGame:
 .a16
 .i16
 lda #1
 sta level
 stz xp
 stz points
 stz gold
 stz kills
 stz beltsel
 lda #$FFFF
 sta nearshown
 ldx #0
@k:
 stz.w ekind,x
 inx
 inx
 cpx #NACT*2
 bne @k
 lda #1
 ldx #6
 sta.w ekind,x
 ldx #12
 sta.w ekind,x
 lda #2
 sta.w ekind               ; (the hero's pictures)
 jsl $800000+X_NewKit
 lda.w emaxhp
 sta.w ehp
 jmp RiseAgain

RiseAgain:
 .a16
 .i16
 jsl $800000+X_SkillsCalm
 lda.w emaxhp
 sta.w ehp
 lda #START_X*16
 sta.w ex
 lda #START_Y*16
 sta.w ey
 lda #2
 sta.w edir
 stz.w est
 stz.w etm
 stz.w eflash
 stz mode
 stz hitstop
 ldx #0
 lda #$FFFF
@e:
 sta.w ecur,x
 inx
 inx
 cpx #NACT*2
 bne @e
 ldx #0
@d:
 stz.w dtyp,x
 inx
 inx
 cpx #NDROP*2
 bne @d
 ldx #0
@a:
 stz.w alife,x
 inx
 inx
 cpx #NARROW*2
 bne @a
 ldx #2
@g:
 phx
 jsr MonsterSpawn
 plx
 inx
 inx
 cpx #NACT*2
 bne @g
 lda #1
 sta rebuild
 sta hudflag
 rts
