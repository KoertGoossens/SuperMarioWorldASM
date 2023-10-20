; flying dino sprite that can wear a shell and can be jumped off to kill it, after which the shell can be grabbed
; the first extension byte sets the x speed
; the second extension byte sets the y speed
; the 1st bit of the third extension byte determines whether the dino spawns with a shell
; the last 3 bits of the third extension byte determine the type of shell the dino spawns with (if it spawns with one)

; $151C,X	=	wearing shell flag
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
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


InitCode:
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA $7FAB40,X				; set x speed based on the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set y speed based on the second extension byte
	STA $AA,X
	
	%RaiseSprite1Pixel()
	
	LDA $7FAB58,X				; set shell wearing flag if the 1st bit in the third extension byte is set
	AND #%10000000
	BEQ +
	INC $151C,X
	+
	
	LDA $7FAB58,X				; store the shell type to a normal sprite-indexed address
	AND #%00000111
	STA $1594,X
	
	LDA $151C,X					; if wearing a shell, make it so the sprite stays in Yoshi's mouth
	BEQ +
	LDA #%00000010
	STA $1686,X
	+
	
	INC $157C,X					; make the sprite face left (base face direction if the sprite has no x speed)
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	INC $1570,X					; increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


Tilemap:
	db $84,$86
ShellTilePalette:
	db %00001010,%00001100,%00000010,%00000100
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
	LDA $1570,X					; store the animation frame into Y (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	TAY
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	PHY
	LDA #%00100000				; tile YXPPCCCT properties
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
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
	
	INY #4
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	CLC : ADC #$FB
	STA $0301,Y
	
	LDA #$A0					; tile ID
	STA $0302,Y
	
	PHY
	
	LDA $1594,X					; if it's a disco shell...
	AND #%00000100
	BEQ .nodisco
	
	LDA $13						; cycle through the palettes every other frame
	AND #%00001110
	BRA .propertiesloaded

.nodisco
	LDA $1594,X					; else, have the shell type determine the palette
	AND #%00000011
	TAY
	LDA ShellTilePalette,Y		; tile YXPPCCCT properties
	
	LDY $157C,X					; flip x based on face direction
	BNE .propertiesloaded
	EOR #%01000000

.propertiesloaded
	PLY
	ORA #%00100000
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
	
	LDX $15E9					; restore the sprite slot into X
	LDA #$03					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $1490					; if Mario has star power, kill the sprite
	BEQ +
	%SlideStarKillSprite()
	RTS
	+
	
	LDA $154C,X					; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; else if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BounceMarioNormal:
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
	LDA #$00					; change the PIXI list ID to a regular dino
	STA $7FAB9E,X
	
	JSR CheckTakeShell
	RTS


CheckTakeShell:
	LDA $151C,X					; if the dino is wearing a shell...
	BEQ .return
	LDA $15						; and the player is holding Y/X...
	AND #%01000000
	BEQ .return
	LDA $1470					; and not already carrying something...
	ORA $148F
	ORA $187A					; and not on Yoshi, spawn a shell for Mario to carry and set the bounced-off flag to 2
	BNE .return
	
	LDA #$0F					; shell (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA #$0B					; store the sprite status to set in init for the spawned shell as 'carried'
	STA $1594,Y
	
	LDA $1594,X					; store the dino's shell type to the spawned shell's shell type
	PHX
	TYX
	STA $7FAB40,X
	PLX
	
	LDA #$08					; set the grab animation frames
	STA $1498
	
	LDA #$08					; disable contact with other sprites for 8 frames (to prevent clashing with the shell you just grabbed)
	STA $1564,X
	
	STZ $151C,X					; set the shell-wearing flag back to 0

.return
	RTS


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the calling sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	LDA $1686,Y				; if the indexed sprite doesn't interact with other sprites...
	AND #%00001000
	ORA $1564,X				; or the calling sprite has the 'disable contact with other sprites' timer set...
	ORA $1564,Y				; or the indexed sprite has the 'disable contact with other sprites' timer set...
	ORA $15D0,Y				; or the indexed sprite is on Yoshi's tongue...
	ORA $1632,X				; or the calling sprite isn't on the same 'layer' as the indexed sprite (i.e. behind net)...
	EOR $1632,Y
	BNE .loopcontinue		; don't check for contact
	
	JSR CheckSpriteContact	; check for contact with the indexed sprite

.loopcontinue				; else, check the next sprite
	DEY
	BPL .loopstart

.return
	RTS


CheckSpriteContact:
	%CheckSpriteSpriteContact()				; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContact:
	PHX							; if the indexed sprite is a shell...
	TYX
	LDA $7FAB9E,X
	PLX
	CMP #$0F
	BNE +
	LDA $14C8,Y					; and it's not in carried status...
	CMP #$0B
	BEQ +
	LDA $151C,X					; and the dino is not wearing a shell...
	BEQ SetCarryShell			; set the shell on top of the dino
	+
	
	RTS


SetCarryShell:
	LDA #$02					; play contact sfx
	STA $1DF9
	
	INC $151C,X					; set the wearing shell flag
	
	PHX							; set the dino's shell type
	TYX
	LDA $7FAB40,X
	PLX
	STA $1594,X
	
	LDA #$00					; erase the shell sprite
	STA $14C8,Y
	RTS