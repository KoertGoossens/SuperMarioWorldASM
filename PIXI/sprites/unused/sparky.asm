; sparky that moves along solid blocks and block sprites
; the first extension byte sets the direction (see $157C,X)
; the second extension byte sets the speed (should be #$00 through #$10, #$20, or #$40)

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	direction:	0 = right, 1 = left, 2 = up, 3 = down	>> clockwise around outer corners
;							4 = right, 5 = left, 6 = up, 7 = down	>> counter-clockwise around outer corners


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
	LDA $7FAB40,X				; set the direction based on the first extension byte
	STA $157C,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$02 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$01 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
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
	
	JSR HandleDirection
	JSR HandleSpeeds
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleMarioContact

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
	
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


TileProp:
	db %00100000,%01100000,%10100000,%11100000

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	DEC A
	STA $0301,Y
	
	LDA #$AE					; tile ID
	STA $0302,Y
	
	PHY
	LDA $1570,X					; store the animation frame into Y (4 animation frames of 4 frames each)
	LSR #2
	AND #%00000011
	TAY
	LDA TileProp,Y				; load tile YXPPCCCT properties, with x-flip and y-flip based on the animation frame
	PLY
	
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


BlockCheckX:
	dw $0018,$FFF8,$0008,$0008		; right, left, up, down
BlockCheckY:
	dw $0008,$0008,$FFF8,$0018

CheckBlockInteraction:
	LDA $14E0,X					; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC BlockCheckX,Y		; add the x offset based on the index
	STA $9A						; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X					; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC BlockCheckY,Y		; add the y offset based on the index
	STA $98						; store it to the block interaction point y
	SEP #$20
	
	STZ $1933					; if the Map16 tile is 25...
	%GetMap16()
	REP #$20
	CMP #$0025
	SEP #$20
	RTS


InnerCornerDirCheck:
	db $06,$04,$00,$02,$04,$06,$02,$00
InnerCornerDirResult:
	db $03,$02,$00,$01,$06,$07,$05,$04
OuterCornerDirCheck:
	db $00,$02,$04,$06,$00,$02,$04,$06
OuterCornerDirResult:
	db $02,$03,$01,$00,$07,$06,$04,$05

HandleDirection:
	LDA $E4,X					; if the sprite's position is directly on a tile...
	AND #%00001111
	BNE .return
	LDA $D8,X
	AND #%00001111
	BNE .return
	
	LDY $157C,X					; store indexes to scratch ram based on the direction
	LDA InnerCornerDirCheck,Y
	STA $02
	LDA InnerCornerDirResult,Y
	STA $03
	LDA OuterCornerDirCheck,Y
	STA $04
	LDA OuterCornerDirResult,Y
	STA $05
	
	LDY $02						; if not touching a solid tile in the direction of $02...
	JSR CheckBlockInteraction
	BNE +
	LDA $03						; change the direction to $03
	STA $157C,X
	+
	
	LDY $04						; else, if touching a solid tile in the direction of $04...
	JSR CheckBlockInteraction
	BEQ .return
	LDA $05						; change the direction to $05
	STA $157C,X

.return
	RTS


HandleSpeeds:
	LDA $157C,X					; point to different routines based on the direction
	AND #%00000011
	JSL $0086DF
		dw SpeedRight
		dw SpeedLeft
		dw SpeedUp
		dw SpeedDown

SpeedRight:
	LDA $7FAB4C,X				; set rightward x speed (value based on the second extension byte)
	STA $B6,X
	STZ	$AA,X					; set y speed to 0
	RTS

SpeedLeft:
	LDA $7FAB4C,X				; set leftward x speed (value based on the second extension byte)
	EOR #$FF
	INC A
	STA $B6,X
	STZ	$AA,X					; set y speed to 0
	RTS

SpeedUp:
	LDA $7FAB4C,X				; set upward y speed (value based on the second extension byte)
	EOR #$FF
	INC A
	STA $AA,X
	STZ	$B6,X					; set x speed to 0
	RTS

SpeedDown:
	LDA $7FAB4C,X				; set downward y speed (value based on the second extension byte)
	STA $AA,X
	STZ	$B6,X					; set x speed to 0
	RTS