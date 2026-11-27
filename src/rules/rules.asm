; The RPG's rules and the bag screen, in ROM bank 42 (run from $AA, the fast half). The game calls in through the
; X_ doors at the end (jsl / rtl); the rules call back through the Far doors of game/far.asm.
.bank 42
.org $8000
.include "arith.asm"
.include "items.asm"
.include "roll.asm"
.include "stats.asm"
.include "names.asm"
.include "play.asm"
.include "bag.asm"

X_NewKit:      jsr NewKit
 rtl
X_StatsRecalc: jsr StatsRecalc
 rtl
X_KillRewards: jsr KillRewards
 rtl
X_KillXp:      jsr KillXp
 rtl
X_GainXp:      jsr GainXp
 rtl
X_HeroBlow:    jsr HeroBlow
 rtl
X_MonsterHit:  jsr MonsterHit
 rtl
X_BagOpen:     jsr BagOpen
 rtl
X_BagInput:    jsr BagInput
 rtl
X_UseBelt:     jsr UseBelt
 rtl
X_PickUp:      jsr PickUp
 rtl
X_Prompt:      jsr Prompt
 rtl
X_DropTile:    jsr DropTile
 rtl
X_BeltKind:    jsr BeltKind
 rtl
X_Spend:       jsr Spend
 rtl
X_StatsDraw:   jsr StatsDraw
 rtl
