; ---------------------------------------------------------------- the rewards (main.c ghoul_killed, items.c xp_for_kill / gain_xp)
MonsterKilled:
 .a16
 .i16
 inc kills
 phx
 jsl $800000+X_KillXp
 jsl $800000+X_GainXp
 bcc @nl
 lda #SFX_LEVEL
 jsr Sfx
@nl:
 plx
 phx
 jsl $800000+X_KillRewards
 plx
 rts

; X = the monster that struck: it takes the thorns' damage, unless the hero evaded
Thorns:
 .a16
 .i16
 lda pmods+K_THORNS*2
 beq @r
 ldy cMiss
 cpy #1
 beq @r
 sta hdmg
 stz hcrit
 lda.w ex
 lsr4
 sta hfx
 lda.w ey
 lsr4
 sta hfy
 phx
 jsr HurtActor
 plx
@r:
 rts
