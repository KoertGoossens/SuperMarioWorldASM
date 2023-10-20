; flying dino enemy that can wear a shell and can be jumped off to kill it, after which the shell can be grabbed; it can float in place, or move linearly based on the extension bytes
; the first extension byte sets the x speed
; the second extension byte sets the y speed
; the 1st bit of the third extension byte determines whether the dino can be bounced off infinitely (grey dino vs brown dino)
; the 2nd bit of the third extension byte determines whether the dino spawns with a shell
; the 3rd bit of the third extension byte determines whether the dino is flying
; the last 3 bits of the third extension byte determine the type of shell the dino spawns with (if it spawns with one)
; REQUIRES CUSTOMSPRITEINTERACTION.ASM TO WORK (HIJACK AT $01A9E2)
; $1504,X	=	jumped-off flag (set by customspriteinteraction.asm)
; $151C,X	=	wearing shell if 1, not wearing shell if 0
; $1528,X	=	infinite bounce flag (read by customspriteinteraction.asm)
; $1534,X	=	flag to indicate the sprite can wear a shell (read by customspriteinteraction.asm)
; $1594,X	=	shell type

print "INIT ",pc
	PHB
	PHK
	PLB
	JSR InitCode
	PLB
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL

print "MOUTH ",pc
	LDA #$04					; change the sprite ID to a green koopa
	STA $9E,X
	
	LDA $1594,X					; reload the sprite tables, but preserve the shell type
	PHA
	JSL $07F7D2
	PLA
	STA $1504,X
	
	JSR SetSpawnedShellPalette
	RTL


InitCode:
	LDA $7FAB40,X			; set x speed based on the value in the first extension byte
	STA $B6,X
	
	LDA $7FAB4C,X			; set y speed based on the value in the second extension byte
	STA $AA,X
	
	INC $1534,X				; set the flag to indicate the sprite can wear a shell
	
	LDA $7FAB58,X			; set shell wearing flag if the 1st bit in the third extension byte is set
	AND #%10000000
	BEQ +
	INC $151C,X
	+
	
	LDA $7FAB58,X			; set infinite bounce flag based on the 2nd bit in the third extension byte
	AND #%01000000
	BEQ +
	INC $1528,X
	+
	
	LDA $7FAB58,X			; store the shell type to a normal sprite-indexed address
	AND #%00000111
	STA $1594,X
	
	LDA $151C,X				; if wearing a shell, make it so the sprite stays in Yoshi's mouth
	BEQ +
	LDA #$12
	STA $1686,X
	+
	
	RTS


SpawnedShellPalette:
	db $0A,$02,$04,$04		; green, silver, yellow, yellow

SpriteCode:
	JSR Graphics
	
	LDA $9D					; return if the game is frozen
	BNE .return
	LDA $14C8,X				; return if the sprite is dead
	CMP #$08
	BNE .return
	
	LDA #$00
	%SubOffScreen()			; call offscreen despawning routine (A has to be 0)
	
	STZ $1504,X				; set the bounced-off flag to 0
	JSL $01803A				; process interaction with Mario and other sprites
	
	LDA $7FAB58,X			; if the dino is flying...
	AND #%00100000
	BEQ +
	JSL $018022				; update x position (no gravity)
	JSL $01801A				; update y position (no gravity)
	BRA .positionupdated
	+
	
	JSL $01802A				; else, update the position with gravity and process block interaction
	
	LDA $1588,X				; if the dino is touching a solid tile below, set its y speed to 0
	AND #%00000100
	BEQ +
	STZ $AA,X
	+

.positionupdated
	LDA $151C,X				; if the sprite is wearing a shell...
	BEQ .return
	LDA $1504,X				; and Mario bounced off the sprite...
	BEQ .return
	LDA $15					; and the player is holding Y/X...
	AND #%01000000
	BEQ .return
	LDA $1470				; and not already carrying something...
	ORA $148F
	ORA $187A				; and not on Yoshi, spawn a shell for Mario to carry and set the bounced-off flag to 2
	BNE .return
	
	STZ $00						; x offset of the sprite to spawn
	STZ $01						; y offset of the sprite to spawn
	STZ $02						; x speed of the sprite to spawn
	STZ $03						; y speed of the sprite to spawn
	LDA #$04					; green koopa
	CLC							; vanilla sprite
	%SpawnSprite()				; input:	A = sprite index number
								; 			CLC = vanilla sprite; SEC = custom sprite
								; 			$00 = x offset
								; 			$01 = y offset
								; 			$02 = x speed
								; 			$03 = y speed
								; output:	Y = index to spawned sprite (#$FF means no sprite spawned)
								;			C = if carry set, spawn failed; if carry clear = spawn successful
	
	LDA #$0B					; set the spawned sprite's status to 'carried'
	STA $14C8,Y
	
	LDA $1594,X					; set the spawned sprite's shell type
	STA $1504,Y
	
	PHX
	TYX
	
	JSR SetSpawnedShellPalette
	PLX
	
	LDA #$08					; set the grab animation frames
	STA $1498
	LDA #$08					; disable contact with other sprites for 8 frames (to prevent clashing with the shell you just grabbed)
	STA $1564,X
	INC $1504,X					; set the bounced-off flag to 2
	STZ $151C,X					; set the shell-wearing flag back to 0

.return
	RTS


Tilemap:
	db $6A,$6C
DinoTileProp:
	db %00100001,%00100011
ShellTileProp:
	db %00101011,%00100011,%00100101,%00100101
ShellTileProp_Disco:
	db %00100001,%00100011,%00100101,%00100111,%00101001,%00101011,%00101101,%00101111
WingTiles:
	db $5D,$C6,$5D,$C6
WingSize:
	db $00,$02,$00,$02
WingXDisp:
	db $FB,$F3,$0D,$0D
WingYDisp:
	db $02,$FA,$02,$FA
WingProps:
	db $76,$76,$36,$36

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $14C8,X					; set scratch RAM that contains information on whether the sprite is alive
	EOR #$08
	STA $03

; DINO GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $03						; if the sprite is dead, don't animate the dino tile
	BNE .nodinoanimation
	LDA $7FAB58,X				; if the sprite is not flying, don't animate the dino tile
	AND #%00100000
	BEQ .nodinoanimation
	
	LDA $14						; otherwise, load the frame counter

.nodinoanimation
	LSR #3						; store the dino animation frame into Y (2 animation frames of 8 frames each)
	AND #%00000001
	TAY
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	PHY
	LDY $1528,X
	LDA DinoTileProp,Y			; tile YXPPCCCT properties
	PLY
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

; SHELLMET GRAPHICS
	LDA $151C,X					; if the sprite is not wearing a shell, don't draw it
	BEQ .noshellgfx
	LDA $1504,X					; if the sprite has been bounced on while holding Y/X, don't draw the shell
	CMP #$02
	BEQ .noshellgfx
	
	INY #4
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	CLC : ADC #$FB
	STA $0301,Y
	
	LDA #$6E					; tile ID
	STA $0302,Y
	
	LDA $1594,X					; if it's a disco shell...
	AND #%00000100
	BEQ +
	LDA $13						; cycle through the palettes every other frame
	AND #%00001110
	LSR
	PHY
	TAY
	LDA ShellTileProp_Disco,Y
	PLY
	BRA .shellpalettechosen
	+
	
	LDA $1594,X					; else, have the shell type determine the palette
	AND #%00000011
	PHY
	TAY
	LDA ShellTileProp,Y			; tile YXPPCCCT properties
	PLY

.shellpalettechosen
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

.noshellgfx

; WINGS GRAPHICS
	LDA $7FAB58,X				; if the sprite is not flying, don't draw wings
	AND #%00100000
	BEQ .nowingsgfx
	
	LDA $03						; if the sprite is dead, don't animate the wings
	BNE .NoWingsAnimation
	LDA $14						; otherwise, load the frame counter

.NoWingsAnimation
	LSR #3						; store the wings animation frame into scratch ram (2 animation frames of 8 frames each)
	AND #$01
	STA $02
	
	LDX #$01					; use X for the loop counter - X is set to #$01 since there are 2 wing tiles

.WingsLoop
	INY #4						; increment Y (the OAM index) by 4
	
	PHX							; load the loop counter, multiply it by 2, add the animation frame (0 or 1), and store it to X
	TXA
	ASL
	CLC : ADC $02
	TAX
	
	LDA $00						; offset the wing tile's x position from the sprite's x depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingXDisp,X
	STA $0300,Y
	
	LDA $01						; offset the wing tile's y position from the sprite's y depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingYDisp,X
	STA $0301,Y
	
	LDA WingTiles,X				; store tilemap number (see Map8 in LM) based on the wing tile and animation frame to OAM
	STA $0302,Y
	
	LDA $64						; store the priority and other properties to OAM
	ORA WingProps,X
	STA $0303,Y
	
	PHY							; set the tile size depending on the animation frame (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA WingSize,X
	STA $0460,Y
	PLY
	
	PLX
	
	DEX							; decrement the loop counter and loop to draw the second wing tile if the loop counter is still positive
	BPL .WingsLoop

.nowingsgfx
	LDX $15E9					; restore the sprite slot into X
	LDA #$03					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


SetSpawnedShellPalette:
	LDA $1504,X					; set the palette based on the final two bits of the shell type byte
	AND #%00000011
	PHX
	TAX
	LDA SpawnedShellPalette,X
	PLX
	STA $15F6,X
	
	LDA $1504,X					; if the shell type is disco, set the disco shell flag
	AND #%00000100
	BEQ +
	INC $187B,X
	+
	
	RTS