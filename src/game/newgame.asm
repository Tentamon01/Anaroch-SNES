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
 stz portalOn
 stz closePortal
 lda #2
 sta.w ekind                ; (the hero's pictures)
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
 stz mode
 stz hitstop
 lda #$FFFF                 ; in Stormreach, where one starts
 sta goX
 lda #2
 sta goDir
 lda #PLACE_TOWN
 jmp EnterPlace
