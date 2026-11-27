; Anaroch's sound driver (SPC700). One stream of events, timed by timer 0 at 200 ticks a second.
;   00 tt                              wait tt ticks (the keys gathered since the last wait start together)
;   01 v pl ph src vl vr a1 a2         play: voice v (0-7), pitch, sample, volumes, envelope
;   02 v g                             release: voice v fades by the gain value g
;   03 v vl vr                         voice volumes
;   04 r d                             any DSP register
;   05                                 back to the loop point
; To the SNES: port 0 = tick counter, port 1 = times looped, port 2 = voices sounding, port 3 = $5A (alive).
; From the SNES: port 1 = a sound effect (1.., or $FE: start the music), then port 2 = a count that changes with every request. An effect takes
; voice 6 (the drum) or voice 4 (the bell), whichever is free or ends sooner; the song's notes for that voice are
; skipped until it is over. Effect table: sample, pitch low, high, volume, envelope 1, 2, length in ticks, pitch spread.
DSPA = $f2
DSPD = $f3
ptr  = $10
kon  = $12
tick = $13
loops = $14
vreg = $15
wait = $16
mask = $17
t6 = $18                            ; ticks left of the effect on voice 6, on voice 4
t4 = $19
seq = $1a
skips = $1b
spread = $1c
pl = $1d
ph = $1e
playing = $1f                        ; 0: the music waits for the SNES (the splash is silent but for its sounds)

start:
  di
  clrp
  mov x, #$ef
  mov sp, x
  mov y, #0
setup:                              ; the DSP's registers from the table (register, value)
  mov a, !dsptab+y
  cmp a, #$ff
  beq setupdone
  mov DSPA, a
  inc y
  mov a, !dsptab+y
  mov DSPD, a
  inc y
  bra setup
setupdone:
  mov $fa, #40                      ; timer 0: 8000 / 40 = 200 Hz
  mov $f1, #$31                     ; (and the ports from the SNES cleared)
  mov t6, #0
  mov t4, #0
  mov seq, #0
  mov playing, #HOLDSTART
  mov $f7, #$5a
  mov wait, #60                     ; let the echo buffer come round before it is written (0.3 s)
settle:
  mov a, $fd
  beq settle
  dbnz wait, settle
  mov DSPA, #$6c                    ; echo writing on, noise clock for the wind
  mov DSPD, #NOISECLK
  mov kon, #0
  mov tick, #0
  mov loops, #0
  mov $f4, #0
  mov $f5, #0                       ; (the IPL left its mark here)
  mov ptr, #(song & $ff)
  mov ptr+1, #(song >> 8)

events:
  mov a, playing
  bne running
idle:
  mov a, $fd
  beq idle
  inc tick
  mov a, tick
  mov $f4, a
  call !meter
  call !effects
  jmp !events
running:
  call !next
  cmp a, #1
  bne notplay
  jmp !play
notplay:
  cmp a, #2
  bne notrelease
  jmp !release
notrelease:
  cmp a, #3
  bne notvolume
  jmp !volume
notvolume:
  cmp a, #4
  bne notpoke
  jmp !poke
notpoke:
  cmp a, #5
  beq again
  call !next                        ; 0: wait
  mov wait, a
  mov DSPA, #$4c                    ; start the gathered voices
  mov a, kon
  mov DSPD, a
  mov kon, #0
waiting:
  mov a, $fd
  beq waiting
  inc tick
  mov a, tick
  mov $f4, a
  call !meter
  call !effects
  dbnz wait, waiting
  jmp !events

again:
  mov ptr, #(songloop & $ff)
  mov ptr+1, #(songloop >> 8)
  inc loops
  mov a, loops
  mov $f5, a
  jmp !events

play:
  call !voicebase                   ; X = voice, vreg = its first register
  call !lent
  beq playfree
  mov skips, #7
  jmp !skip
playfree:
  mov a, vreg
  clrc
  adc a, #5
  mov DSPA, a
  mov DSPD, #0                      ; (envelope off while it changes)
  mov a, vreg
  clrc
  adc a, #2
  call !copy                        ; pitch low
  inc a
  call !copy                        ; pitch high
  inc a
  call !copy                        ; sample
  mov a, vreg
  call !copy                        ; volume left
  inc a
  call !copy                        ; volume right
  mov a, vreg
  clrc
  adc a, #5
  call !copy                        ; adsr 1
  inc a
  call !copy                        ; adsr 2
  mov a, !bits+x
  or a, kon
  mov kon, a
  jmp !events

release:
  call !voicebase
  call !lent
  beq releasefree
  mov skips, #1
  jmp !skip
releasefree:
  mov a, vreg
  clrc
  adc a, #7
  call !copy                        ; the gain first
  mov a, vreg
  clrc
  adc a, #5
  mov DSPA, a
  mov DSPD, #0                      ; then the envelope over to it
  jmp !events

volume:
  call !voicebase
  call !lent
  beq volumefree
  mov skips, #2
  jmp !skip
volumefree:
  mov a, vreg
  call !copy
  inc a
  call !copy
  jmp !events

poke:
  call !next
  mov DSPA, a
  call !next
  mov DSPD, a
  jmp !events

; passes over the rest of an event
skip:
  call !next
  dbnz skips, skip
  jmp !events

; Z clear when voice X is with an effect
lent:
  cmp x, #6
  bne lent4
  mov a, t6
  ret
lent4:
  cmp x, #4
  bne lentno
  mov a, t4
  ret
lentno:
  mov a, #0
  ret

; every tick: the effects' time, and a new request from the SNES
effects:
  mov a, t6
  beq count4
  dec t6
count4:
  mov a, t4
  beq request
  dec t4
request:
  mov a, $f6
  cmp a, seq
  bne wanted
  ret
wanted:
  mov seq, a
  mov a, $f5
  bne known
  ret
known:
  cmp a, #$fe
  bne aneffect
  mov playing, #1
  ret
aneffect:
  dec a
  asl a
  asl a
  asl a
  mov y, a
  mov a, t6                         ; which voice
  beq on6
  mov a, t4
  beq on4
  cmp a, t6
  bcc on4
on6:
  mov x, #6
  mov vreg, #$60
  bra start_effect
on4:
  mov x, #4
  mov vreg, #$40
start_effect:
  mov a, !sfxtab+7+y
  mov spread, a
  mov a, tick
  and a, spread
  mov spread, a
  mov a, !sfxtab+1+y
  clrc
  adc a, spread
  mov pl, a
  mov a, !sfxtab+2+y
  adc a, #0
  mov ph, a
  mov a, vreg
  clrc
  adc a, #5
  mov DSPA, a
  mov DSPD, #0
  mov a, vreg
  mov DSPA, a
  mov a, !sfxtab+3+y
  mov DSPD, a
  mov a, vreg
  inc a
  mov DSPA, a
  mov a, !sfxtab+3+y
  mov DSPD, a
  mov a, vreg
  clrc
  adc a, #2
  mov DSPA, a
  mov a, pl
  mov DSPD, a
  mov a, vreg
  clrc
  adc a, #3
  mov DSPA, a
  mov a, ph
  mov DSPD, a
  mov a, vreg
  clrc
  adc a, #4
  mov DSPA, a
  mov a, !sfxtab+y
  mov DSPD, a
  mov a, vreg
  clrc
  adc a, #5
  mov DSPA, a
  mov a, !sfxtab+4+y
  mov DSPD, a
  mov a, vreg
  clrc
  adc a, #6
  mov DSPA, a
  mov a, !sfxtab+5+y
  mov DSPD, a
  mov a, !sfxtab+6+y
  cmp x, #6
  bne length4
  mov t6, a
  bra keyon
length4:
  mov t4, a
keyon:
  mov DSPA, #$4c
  mov a, !bits+x
  mov DSPD, a
  ret

; X = the voice number from the stream, vreg = voice * 16
voicebase:
  call !next
  mov x, a
  xcn a
  mov vreg, a
  ret

; the next stream byte into DSP register A (A kept)
copy:
  mov DSPA, a
  push a
  call !next
  mov DSPD, a
  pop a
  ret

; A = the next stream byte
next:
  mov y, #0
  mov a, [ptr]+y
  incw ptr
  ret

; which voices have an envelope: port 2
meter:
  mov mask, #0
  mov x, #0
  mov y, #$08
meterloop:
  mov DSPA, y
  mov a, DSPD
  beq quiet
  mov a, !bits+x
  or a, mask
  mov mask, a
quiet:
  mov a, y
  clrc
  adc a, #$10
  mov y, a
  inc x
  cmp x, #8
  bne meterloop
  mov a, mask
  mov $f6, a
  ret

bits:
