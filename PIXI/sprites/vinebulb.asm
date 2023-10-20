; vine bulb sprite
; the extension byte sets the type:
;	bit 1+2:	direction (0 = right, 1 = left, 2 = up, 3 = down)
;	bit 3:		+00 = green (no interaction); +04 = red (spin only)
;	bit 4:		(for creating vines) +00 = create normal vine; +08 = create conveyor vine
;	bit 5:		+00 = creating vine; +10 = eating vine

; $1570,X	=	animation frame counter
; $157C,X	=	direction (0 = right, 1 = left, 2 = up, 3 = down)


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


XSpeed:
	db $10,$F0,$00,$00
YSpeed:
	db $00,$00,$F0,$10

InitCode:
	LDA $7FAB40,X				; store the first 2 bits of the extension byte as the direction
	AND #%00000011
	STA $157C,X
	TAY							; set x and y speeds based on the direction
	LDA XSpeed,Y
	STA $B6,X
	LDA YSpeed,Y
	STA $AA,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	%RaiseSprite1Pixel()
	
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
	
	LDA $7FAB40,X				; if it's a creating vine bulb, check for blocks and create vine tiles
	AND #%00010000
	BNE +
	JSR CheckBlocks
	JSR CreateVine
	BRA .updatepos
	+
	
	JSR EatVine					; else, eat vine tiles and check for the next tile
	JSR CheckContinueEat

.updatepos
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleMarioContact

.return
	RTS


BlockCheckOffsetX:
	dw $000C,$0003,$0008,$0008
BlockCheckOffsetY:
	dw $0008,$0008,$0004,$000D

CheckBlocks:
	LDA $157C,X						; load the direction as an index
	ASL
	TAY
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC BlockCheckOffsetX,Y	; add the x offset based on the direction
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC BlockCheckOffsetY,Y	; add the y offset based on the direction
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	%GetMap16Solid()				; if the Map16 tile is a solid...
	BNE .return
	
	%SmokeKillSprite()				; smoke-kill the vine bulb

.return
	RTS


TileCheckOffsetX:
	dw $FFFF,$0010,$0008,$0008
TileCheckOffsetY:
	dw $0008,$0008,$0011,$0000
VineTile:
	dw $0280,$0280,$0281,$0281,$0283,$0282,$0284,$0285

CreateVine:
	LDA $157C,X						; load the direction as an index
	ASL
	TAY
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC TileCheckOffsetX,Y	; add the x offset based on the direction
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC TileCheckOffsetX,Y	; add the y offset based on the direction
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	STZ $1933						; if the Map16 tile is 25...
	%GetMap16()
	REP #$20
	CMP #$0025
	SEP #$20
	BNE .return
	
	LDY #$00						; load an index of 0
	LDA $7FAB40,X					; if the vine bulb is set to create conveyor vines...
	AND #%00001000
	BEQ +
	LDY #$04						; load an index of 4
	+
	TYA
	CLC : ADC $157C,X				; add the direction to the index
	ASL
	TAY
	
	REP #$20
	LDA VineTile,Y					; change the Map16 tile to a vine tile based on the direction
	%ChangeMap16()
	SEP #$20

.return
	RTS


EatVine:
	LDA $157C,X						; load the direction as an index
	ASL
	TAY
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC TileCheckOffsetX,Y	; add the x offset based on the direction
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC TileCheckOffsetY,Y	; add the y offset based on the direction
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	STZ $1933						; if the Map16 tile acts as 6 or 7 (vine tile)...
	%GetMap16ActAs()
	REP #$20
	CMP #$0006
	BEQ .erasetile
	CMP #$0007
	BNE .return

.erasetile
	LDA #$0025						; erase the tile
	%ChangeMap16()

.return
	SEP #$20
	RTS


ContinueCheckOffsetX:
	dw $000F,$0000,$0008,$0008
ContinueCheckOffsetY:
	dw $0008,$0008,$0001,$0010

CheckContinueEat:
	LDA $157C,X							; load the direction as an index
	ASL
	TAY
	
	LDA $14E0,X							; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC ContinueCheckOffsetX,Y	; add the x offset based on the direction
	STA $9A								; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X							; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC ContinueCheckOffsetY,Y	; add the y offset based on the direction
	STA $98								; store it to the block interaction point y
	SEP #$20
	
	STZ $1933							; if the Map16 tile does not act as 6 or 7 (vine tile), smokekill the vine bulb
	%GetMap16ActAs()
	REP #$20
	CMP #$0006
	BEQ .return
	CMP #$0007
	BEQ .return
	
	SEP #$20
	%SmokeKillSprite()

.return
	SEP #$20
	RTS


HandleMarioContact:
	LDA $7FAB40,X				; if the vine bulb does not interaction with Mario, don't handle interaction
	AND #%00000100
	BEQ .return
	
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
	
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


Tilemap:
	db $E0,$E2,$E4,$E6
TileProp:
	db %00101011,%01101011,%00101011,%10101011,%00101001,%01101001,%00101001,%10101001

Graphics:
	LDA $157C,X					; store the vine bulb's direction to scratch ram
	STA $04
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $1570,X					; store the animation frame into Y (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	TAY
	
	LDA $157C,X					; if the vine bulb's direction is vertical, add 2 to Y
	AND #%00000010
	BEQ +
	INY #2
	+
	
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	PHY
	LDA $7FAB40,X				; load the palette (green vs. red), x-flip, and y-flip depending on the type
	AND #%00000111
	TAY
	LDA TileProp,Y
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS