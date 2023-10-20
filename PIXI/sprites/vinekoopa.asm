; koopa that climbs vines; can be jumped on to kill it

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


InitCode:
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$F3 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$15 : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$F2 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$06 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


XSpeed:
	db $18,$E8,$00,$00
YSpeed:
	db $00,$00,$E8,$18

SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; branch if the sprite is dead
	CMP #$08
	BNE .return
	
	INC $1570,X					; increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $C2,X					; if the sprite is on a vine...
	BEQ +
	JSR CheckBlocks				; process interaction with blocks
	
	LDY $157C,X					; set the x and y speeds based on the direction
	LDA XSpeed,Y
	STA $B6,X
	LDA YSpeed,Y
	STA $AA,X
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	BRA .notonvine
	+
	
	JSR HandleGravity			; else, fall with gravity

.notonvine
	JSR CheckHorizVine			; check for horizontal vine tiles
	
	LDA $C2,X					; if not on a horizontal vine...
	BNE +
	JSR CheckVertVine			; check for vertical vine tiles
	+
	
	JSR HandleMarioContact

.return
	RTS


HandleGravity:		%ApplyGravity() : RTS


TileCheckOffsetY:
	dw $0000,$000F

CheckHorizVine:
	STZ $C2,X						; clear the 'on vine' flag
	
	LDY #$00						; load an index of 0
	LDA $AA,X						; if moving upward...
	BPL +
	LDY #$02						; load an index of 2
	+
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008				; add the x offset
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC TileCheckOffsetY,Y	; add the y offset based on the index
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	STZ $1933						; if the Map16 tile is a type of horizontal vine...
	%GetMap16ActAs()
	REP #$20
	CMP #$0006
	SEP #$20
	BNE .return
	
	INC $C2,X						; set the 'on vine' flag
	
	LDY #$01						; set the direction to left
	LDA $B6,X						; if the x speed is more than 0...
	BMI +
	BEQ +
	LDY #$00						; set the direction to right
	+
	TYA
	STA $157C,X
	
	LDA $D8,X						; align the sprite vertically with the vine
	AND #%11110000
	STA $D8,X

.return
	RTS


TileCheckOffsetX:
	dw $0000,$000F

CheckVertVine:
	STZ $C2,X						; clear the 'on vine' flag
	
	LDY #$00						; load an index of 0
	LDA $B6,X						; if moving leftward...
	BPL +
	LDY #$02						; load an index of 2
	+
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC TileCheckOffsetX,Y	; add the x offset based on the index
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0008				; add the y offset
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	STZ $1933						; if the Map16 tile is a type of vertical vine...
	%GetMap16ActAs()
	REP #$20
	CMP #$0007
	SEP #$20
	BNE .return
	
	INC $C2,X						; set the 'on vine' flag
	
	LDY #$02						; set the direction to up
	LDA $AA,X						; if the y speed is positive...
	BMI +
	LDY #$03						; set the direction to down
	+
	TYA
	STA $157C,X
	
	LDA $E4,X						; align the sprite horizontally with the vine
	AND #%11110000
	STA $E4,X

.return
	RTS


BlockCheckOffsetX:
	dw $000D,$0002,$0008,$0008
BlockCheckOffsetY:
	dw $0008,$0008,$0003,$000E

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
	
	LDA $157C,X						; invert the direction
	EOR #$01
	STA $157C,X

.return
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
	
	LDA #$02					; set the sprite status to killed
	STA $14C8,X
	RTS


Graphics:
	STZ $04						; store the x-flip flag to scratch ram every 8 frames
	LDA $1570,X
	AND #%00001000
	BEQ +
	LDA #%01000000
	STA $04
	+
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; head tile
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	SEC : SBC #$10
	STA $0301,Y
	
	LDA #$C8					; tile ID
	STA $0302,Y
	
	LDA #%00101011				; load tile YXPPCCCT properties
	ORA $04						; x-flip the tile every 8 frames
	ORA $64
	STA $0303,Y
	
	INY #4

; body tile
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	LDA #$CA					; tile ID
	STA $0302,Y
	
	LDA #%00101011				; load tile YXPPCCCT properties
	ORA $04						; x-flip the tile every 8 frames
	ORA $64
	STA $0303,Y
	
	LDA #$01					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS