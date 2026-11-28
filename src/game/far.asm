; Doors for the rules (bank 42) into the game's routines, and the bag screen's work with the video chip.
FarRise:                     ; a loaded game: into Stormreach
 jsr RiseAgain
 rtl
FarRand:
 jsr Rand
 rtl
FarSfx:
 jsr Sfx
 rtl
FarSayName:                  ; the words in namebuf, as a message over the HUD
 phx
 ldx #namebuf
 jsr Say
 plx
 rtl
FarPrintAt:                  ; A = row * 32 + column, X = string, Y = attributes
 jsr PrintAt
 rtl
FarPrintNum:
 jsr PrintNum
 rtl
FarPutTile:
 jsr PutTile
 rtl
FarDmaV:                     ; n0 source, n1 bank, n2 video address, n3 bytes
 .a16
 lda #$80
 sta n4
 jsr DmaV
 rtl
; something falls: A = type (1 gold, 2 a piece, 3 tome), Y = amount, X = the actor it falls from
; -> Y = its place (twice its number), carry clear: no room
FarDrop:
 .a16
 sty tmpB
 jsr DropAt
 rtl

FarHurt:                     ; X = the monster: hurt by hdmg from (hfx, hfy)
 jsr HurtActor
 rtl
FarDot:                      ; (tmp0, tmp2) along direction Y/2 -> A, ten to a pixel
 jsr DotDir
 cmp #0
 rtl
FarFoot:                     ; (tmpF, tmpG): carry set when the hero could not stand there
 jsr CheckFoot
 rtl
FarMove:
 jsr MoveEnt
 rtl
FarDirFrom:                  ; a world movement (tmp0, tmp2) -> A = the screen direction it shows as
 jsr Rot
 jsr DirFrom
 rtl
FarBlocked:
 jsr Blocked
 rtl
FarStatsOpen:
 jsr StatsOpen
 rtl

; the bag screen: no sprites, an empty text layer (the screen is blank)
FarClearScreen:
 .a16
 .i16
 ldx #0
 lda #$E000
@o:
 sta.w oam,x
 inx
 inx
 cpx #512
 bne @o
 sep #$20
 .a8
 stz $2102
 stz $2103
 stz $4300
 lda #4
 sta $4301
 ldx #oam
 stx $4302
 stz $4304
 ldx #544
 stx $4305
 lda #1
 sta $420B
 rep #$20
 .a16
FarClearText:
 .a16
 .i16
 jsr ClearText
 rtl

ClearText:
 .a16
 .i16
 ldx #2046
 lda #0
@t:
 sta.w hudmap,x
 dex
 dex
 bpl @t
 ldx #30
 lda #$0101
@d:
 sta.w hudd,x
 dex
 dex
 bpl @d
 rts

; both maps of the bag screen to video memory (in the blank)
FarMenuSend:
 jsr MenuSend
 rtl
MenuSend:
 .a16
 .i16
 stz menuDirty
 lda #$80
 sta n4
 lda #$4000                 ; BG1's, from work RAM $7E:4000
 sta n0
 sta n2
 lda #$007E
 sta n1
 lda #2048
 sta n3
 jsr DmaV
 lda #hudmap
 sta n0
 stz n1
 lda #$4800
 sta n2
 lda #2048
 sta n3
 jmp DmaV

; the frame interrupt while the bag is open
MenuFrame:
 .a16
 .i16
 lda menuDirty
 beq @none
 jsr MenuSend
 ldx #30
@d:
 stz.w hudd,x               ; (the rows went with the whole map)
 dex
 dex
 bpl @d
@none:
 sep #$20
 .a8
 stz $210D
 stz $210D
 lda #$FF
 sta $210E
 sta $210E
 lda #$80
 sta $420C
 rep #$20
 .a16
 rts

; back to the game: the colours, the layers, the text layer; the world is drawn again by the main loop
FarRestoreVideo:
 .a16
 .i16
 jsr InitColors
 sep #$20
 .a8
 lda #$13
 sta $212C
 lda #$04
 sta $212D
 lda #$02
 sta $2130
 lda #$11
 sta $2131
 rep #$20
 .a16
 jsr ClearText
 lda #1
 sta rebuild
 sta hudflag
 sta skDirty
 lda #$FFFF
 sta nearshown
 stz sayt
 rtl
