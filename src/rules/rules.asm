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
.include "skills.asm"
.include "skillui.asm"

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
X_HeroBlow:    lda #100
 sta skMult
 jsr HeroBlow
 rtl
X_SkillStart:  jsr SkillStart
 rtl
X_SkillFire:   jsr SkillFire
 rtl
X_SkillTick:   jsr SkillTick
 rtl
X_SparkUpdate: jsr SparkUpdate
 rtl
X_NextSkill:   jsr NextSkill
 rtl
X_HeroArrow:   jsr HeroArrow
 rtl
X_ArrowShot:   jsr ArrowShot
 rtl
X_SkillsCalm:  jsr SkillsCalm
 rtl
X_SkillHud:    jsr SkillHud
 rtl
X_SkillOpen:   jsr SkillOpen
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
