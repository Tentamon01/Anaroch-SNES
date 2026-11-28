; Anaroch SNES, the remake: the pre-rendered world in a three-quarter view, with the N64 version's rules.
; World positions are in metres * 16 (the N64 collision grid); the screen shows them through the projection
; picture x = wx - wz/2 + PIC_KX, picture y = (wx + wz)/2 + PIC_KY. The screen: 208 lines between blank bars,
; BG1 the world (a ring of 33 x 27 tiles streamed from ROM), BG2 the HUD, BG3 the braziers' glow, sprites for the
; characters. Everything is sent to the video chip by an interrupt at line 216.

.macro lsr2
 lsr
 lsr
.endmacro
.macro lsr3
 lsr
 lsr
 lsr
.endmacro
.macro lsr4
 lsr
 lsr
 lsr
 lsr
.endmacro
.macro asl4
 asl
 asl
 asl
 asl
.endmacro
.macro wait16
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
.endmacro

; joypad bits
PAD_B = $8000
PAD_Y = $4000
PAD_SELECT = $2000
PAD_START = $1000
PAD_UP = $0800
PAD_DOWN = $0400
PAD_LEFT = $0200
PAD_RIGHT = $0100
PAD_A = $0080
PAD_X = $0040
PAD_L = $0020
PAD_R = $0010

; actor states (main.c ST_*)
ST_IDLE = 0
ST_MOVE = 1
ST_ATTACK = 2
ST_HIT = 3
ST_DEAD = 4
ST_GONE = 5
ST_NPC = 6                   ; a townsperson (past ST_DEAD: nothing can strike them)

; modes
M_PLAY = 0
M_DEAD = 1
M_PAUSE = 2
M_STATS = 3
M_BAG = 4
M_TRAVEL = 5                 ; between two places

NACT = 9                     ; the hero + 8 monsters
RING_C = 33                  ; the streamed window, in tiles
RING_R = 27
QREC = 14                    ; a stream record: source, bank + size, tile address, map address, entry, glow address, entry
SQ = $1000                   ; the stream queue (work RAM)
NDROP = 8
NARROW = 14
FX_N = 16
HUD_PRIO = $2000
MSG_ROW1 = 12
MSG_ROW2 = 14
CH_SLASH = FONT_BASE+37
CH_MINUS = FONT_BASE+40
CH_GT = FONT_BASE+44

.include "game/ram.asm"                   ; work memory
.include "rules/vars.asm"                 ; the RPG's memory
.include "world_ram.inc"                  ; the place's numbers (tools/build_world.py)
.include "game/boot.asm"                  ; reset and the video chip's setup
.include "game/frame.asm"                 ; the frame interrupt: everything for the video chip
.include "game/loop.asm"                  ; the main loop and the game's modes
.include "game/newgame.asm"               ; a new game, rising again
.include "game/math.asm"                  ; arithmetic, directions, damage
.include "game/stream.asm"                ; the world's tiles and the camera
.include "game/collide.asm"               ; collision and sight
.include "game/hero.asm"                  ; the hero
.include "game/rewards.asm"               ; rewards for a kill
.include "game/monsters.asm"              ; monsters
.include "game/arrows.asm"                ; arrows
.include "game/loot.asm"                  ; loot on the ground
.include "game/hud.asm"                   ; the HUD and text
.include "game/charwin.asm"               ; the character window
.include "game/sprites.asm"               ; sprite pictures and the sprite list
.include "game/far.asm"                   ; doors for the rules, the bag screen's video work
.include "game/area.asm"                  ; the places: loading, gates, the town portal
.include "game/people.asm"                ; the townspeople and their words
.include "game/tables.asm"                ; tables and words
.include "occlude.asm"
.include "sound.asm"
.include "data.inc"
.include "world.inc"
.include "rules/rules.asm"                ; the RPG's rules and the bag screen (bank 42)
.include "rules.inc"                      ; their tables and pictures (tools/build_rules.py)
.include "splash.asm"                     ; the studio's splash (bank 43)
.include "splash.inc"                     ; its pictures (tools/build_splash.py)
.bank 40
.org $8000
spc_data: .incbin "../out/audio/spc_0.bin"
.bank 41
.org $8000
 .incbin "../out/audio/spc_1.bin"

; ---------------------------------------------------------------- header + vectors
.bank 0
.org $FFC0
.byte "ANAROCH SNES         "
.org $FFD5
.byte $30, $15, $0B, $07, $01, $33, $00
.org $FFE4
.word Rti, Rti, Rti, Rti, Rti, Frame
.org $FFF4
.word Rti, Rti, Rti, Rti, Reset, Rti
