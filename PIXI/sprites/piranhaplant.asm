; piranha plant going in and out of pipes
; the extension byte sets the direction

; $C2,X		=	phase (0 = emerging, 1 = out, 2 = submerging, 3 = in)
; $151C,X	=	phase timer
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
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


MarioHitboxWidth:
	db $1C,$1C,$0C,$0C
MarioHitboxHeight:
	db $0A,$0A,$1A,$1A
SpriteHitboxWidth:
	db $1F,$1F,$0F,$0F
SpriteHitboxHeight:
	db $0B,$0B,$1B,$1B
XOffset:
	dw $0000,$0000,$0008,$0008
YOffset:
	dw $0007,$0007,$FFFF,$FFFF

InitCode:
	LDA $7FAB40,X				; set the direction based on the extension byte and store it as an index
	STA $157C,X
	TAY
	
	LDA #$02					: STA $7FB600,X		; sprite hitbox x offset for interaction with Mario
	LDA #$03					: STA $7FB60C,X		; sprite hitbox y offset for interaction with Mario
	LDA MarioHitboxWidth,Y		: STA $7FB618,X		; sprite hitbox width for interaction with Mario, based on the direction
	LDA MarioHitboxHeight,Y		: STA $7FB624,X		; sprite hitbox height for interaction with Mario, based on the direction
	
	LDA #$00					: STA $7FB630,X		; sprite hitbox x offset for interaction with other sprites
	LDA #$02					: STA $7FB63C,X		; sprite hitbox y offset for interaction with other sprites
	LDA SpriteHitboxWidth,Y		: STA $7FB648,X		; sprite hitbox width for interaction with other sprites, based on the direction
	LDA SpriteHitboxHeight,Y	: STA $7FB654,X		; sprite hitbox height for interaction with other sprites, based on the direction
	
	TYA							; multiply the index
	ASL
	TAY
	
	LDA $14E0,X					; adjust the x position based on the direction
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC XOffset,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X					; adjust the y position based on the direction
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC YOffset,Y
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	LDA $14C8,X					; if the sprite is dead, erase it immediately
	CMP #$08
	BEQ +
	STZ $14C8,X
	RTS
	+
	
	LDA #%00010000				; draw the sprite behind objects
	STA $64
	
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	
	INC $1570,X					; increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	
	JSR HandlePhase
	
	INC $151C,X					; increment the phase timer
	
	LDA $151C,X					; if the phase timer is at #$20...
	CMP #$20
	BNE +
	LDA $C2,X					; loop the phase
	INC A
	AND #%00000011
	STA $C2,X
	
	STZ $151C,X					; set the phase timer back to 0
	+
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleMarioContact

.return
	RTS


HandlePhase:
	LDA $C2,X					; point to different routines based on the phase
	JSL $0086DF
		dw Phase_Submerge
		dw Phase_Still
		dw Phase_Emerge
		dw Phase_Still
	
	RTS


SubmergeXSpeed:
	db $F0,$10,$00,$00
SubmergeYSpeed:
	db $00,$00,$10,$F0
EmergeXSpeed:
	db $10,$F0,$00,$00
EmergeYSpeed:
	db $00,$00,$F0,$10

Phase_Submerge:
	LDY $157C,X
	LDA SubmergeXSpeed,Y
	STA $B6,X
	LDA SubmergeYSpeed,Y
	STA $AA,X
	RTS

Phase_Emerge:
	LDY $157C,X
	LDA EmergeXSpeed,Y
	STA $B6,X
	LDA EmergeYSpeed,Y
	STA $AA,X
	RTS

Phase_Still:
	STZ $B6,X
	STZ $AA,X
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
	
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BulbXOffset:
	db $10,$00,$00,$00
BulbYOffset:
	db $00,$00,$00,$10
StemXOffset:
	db $00,$10,$00,$00
StemYOffset:
	db $00,$00,$10,$00
BulbTileID:
	db $E0,$E0,$E4,$E4
StemTileID:
	db $80,$80,$82,$82
TileXYFlip:
	db %00000000,%01000000,%00000000,%10000000

Graphics:
	LDY $157C,X					; store the tile x/y offsets to scratch ram, based on the direction
	LDA BulbXOffset,Y
	STA $04
	LDA BulbYOffset,Y
	STA $05
	LDA StemXOffset,Y
	STA $06
	LDA StemYOffset,Y
	STA $07
	
	LDA $1570,X					; load the animation frame x2 (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	ASL
	CLC : ADC BulbTileID,Y		; add the bulb tile ID, based on the direction, and store it to scratch ram
	STA $08
	
	LDA StemTileID,Y			; store the stem tile ID to scratch ram, based on the direction
	STA $09
	
	LDA TileXYFlip,Y			; store the x/y flip flags to scratch ram, based on the direction
	STA $0A
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; bulb tile
	LDA $00						; load tile x position based on the direction
	CLC : ADC $04
	STA $0300,Y
	
	LDA $01						; load tile y position based on the direction
	CLC : ADC $05
	STA $0301,Y
	
	LDA $08						; load tile ID based on the direction
	STA $0302,Y
	
	LDA #%00001001				; load tile YXPPCCCT properties
	ORA $0A						; apply x/y flip flags based on the direction
	ORA $64
	STA $0303,Y

; stem tile
	INY #4
	
	LDA $00						; load tile x position based on the direction
	CLC : ADC $06
	STA $0300,Y
	
	LDA $01						; load tile y position based on the direction
	CLC : ADC $07
	STA $0301,Y
	
	LDA $09						; load tile ID based on the direction
	STA $0302,Y
	
	LDA #%00001011				; load tile YXPPCCCT properties
	ORA $0A						; apply x/y flip flags based on the direction
	ORA $64
	STA $0303,Y
	
	LDA #$01					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS