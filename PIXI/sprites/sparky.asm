; sparky that moves along solid blocks
; the first extension byte sets the direction (see $157C,X)
; the second extension byte sets the speed

; $C2,X		=	solid detection flag (for outer walls)
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	direction:	0 = rightward on floor,		1 = upward on right wall,	2 = leftward on ceiling,	3 = downward on left wall
;							4 = leftward on floor,		5 = upward on left wall,	6 = rightward on ceiling,	7 = downward on right wall


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


InitXShift:
	dw $0000,$0000,$0000,$0010,$0000,$0010,$0000,$0000
InitYShift:
	dw $0000,$0000,$0010,$0000,$0000,$0000,$0010,$0000

InitCode:
	LDA $7FAB40,X				; set the direction based on the first extension byte
	STA $157C,X
	ASL							; multiply by 2 and store as an index
	TAY
	
	LDA $14E0,X					; shift the x position depending on the direction
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC InitXShift,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X					; shift the y position depending on the direction
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC InitYShift,Y
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
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
	
	JSR HandleDirection_Inner
	JSR HandleDirection_Outer
	JSR HandleXYOffset
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


BlockCheckX_Inner:
	dw $000E,$0008,$0001,$0008,$0001,$0008,$000E,$0008
BlockCheckY_Inner:
	dw $0008,$0001,$0008,$000E,$0008,$0001,$0008,$000E

HandleDirection_Inner:
	LDA $157C,X						; load the direction x2 as an index
	ASL
	TAY
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC BlockCheckX_Inner,Y	; add the x offset based on the index
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC BlockCheckY_Inner,Y	; add the y offset based on the index
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	%GetMap16Solid()				; if the Map16 tile is a solid...
	BNE .return
	
	LDA $157C,X						; cycle the direction
	AND #%00000100
	STA $00
	LDA $157C,X
	INC A
	AND #%00000011
	CLC : ADC $00
	STA $157C,X

.return
	RTS


BlockCheckX_Outer:
	dw $0002,$0010,$000D,$0000,$000D,$0000,$0002,$0010
BlockCheckY_Outer:
	dw $0010,$000D,$0000,$0002,$0010,$000D,$0000,$0002

OuterCornerShiftX:
	dw $FFF8,$0000,$0008,$0000,$0008,$0000,$FFF8,$0000
OuterCornerShiftY:
	dw $0000,$0008,$0000,$FFF8,$0000,$0008,$0000,$FFF8

HandleDirection_Outer:
	LDA $157C,X						; load the direction x2 as an index
	ASL
	TAY
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC BlockCheckX_Outer,Y	; add the x offset based on the index
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC BlockCheckY_Outer,Y	; add the y offset based on the index
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	%GetMap16Solid()				; if the Map16 tile is a solid...
	BNE .nosolid
	
	LDA #$01						; set the solid detection flag
	STA $C2,X
	RTS

.nosolid
	LDA $C2,X						; if a solid tile was previously touched after the last direction change...
	BEQ .return
	
	LDA $157C,X						; store the current direction x2 as an index
	ASL
	TAY
	
	LDA $157C,X					; cycle the direction
	AND #%00000100
	STA $00
	LDA $157C,X
	DEC A
	AND #%00000011
	CLC : ADC $00
	STA $157C,X
	
	LDA $14E0,X						; shift the x position so that adding the offset doesn't put the sparky on the wrong tile
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC OuterCornerShiftX,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X						; shift the y position so that adding the offset doesn't put the sparky on the wrong tile
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC OuterCornerShiftY,Y
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	STZ $C2,X						; clear the solid detection flag back

.return
	RTS


XOffset:
	db $00,$02,$00,$0E,$00,$0E,$00,$02
YOffset:
	db $02,$00,$0E,$00,$02,$00,$0E,$00

HandleXYOffset:
	LDA $157C,X					; load the direction as an index
	TAY
	
	LDA XOffset,Y				; if the x offset (based on the direction) is not 0...
	BEQ +
	LDA $E4,X					; shift the sparky
	AND #%11110000
	CLC : ADC XOffset,Y
	STA $E4,X
	+
	
	LDA YOffset,Y				; if the y offset (based on the direction) is not 0...
	BEQ +
	LDA $D8,X					; shift the sparky
	AND #%11110000
	CLC : ADC YOffset,Y
	STA $D8,X
	+
	
	RTS


HandleSpeeds:
	LDA $157C,X					; point to different routines based on the direction
	JSL $0086DF
		dw SpeedRight
		dw SpeedUp
		dw SpeedLeft
		dw SpeedDown
		dw SpeedLeft
		dw SpeedUp
		dw SpeedRight
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