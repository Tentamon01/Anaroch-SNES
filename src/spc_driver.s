; Anaroch's sound driver (SPC700). One stream of events, timed by timer 0 at 200 ticks a second.
;   00 tt                              wait tt ticks (the keys gathered since the last wait start together)
;   01 v pl ph src vl vr a1 a2         play: voice v (0-7), pitch, sample, volumes, envelope
;   02 v g                             release: voice v fades by the gain value g
;   03 v vl vr                         voice volumes
;   04 r d                             any DSP register
;   05                                 back to the loop point
; To the SNES: port 0 = tick counter, port 1 = times looped, port 2 = voices sounding, port 3 = $5A (alive).
DSPA = $f2
DSPD = $f3
ptr  = $10
kon  = $12
tick = $13
loops = $14
vreg = $15
wait = $16
mask = $17

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
  mov $f1, #$01
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
  call !next
  cmp a, #1
  beq play
  cmp a, #2
  beq release
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
