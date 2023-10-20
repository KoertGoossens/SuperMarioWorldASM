; this routine handles standard interaction between a sprite in normal status and a solid sprite
; output: set carry if interacting with a solid sprite, clear carry if not


	%SolidSprite_SetupInteract()
	
	LDA $08						; branch if the 'touching from above' flag is set
	BNE SprInt_Top
	
	LDA $0A						; branch if the 'touching from the side' flag is set
	BNE SprInt_Side
	RTL


SprInt_Top:
	LDA $AA,X					; don't interact if the calling sprite is moving up
	BMI .return
	
	STZ $AA,X					; set the calling sprite's y speed to 0
	%SolidSprite_DragSprite()	; drag the calling sprite horizontally along the block sprite
	%SolidSprite_SetOnTop()		; set the calling sprite on top of the block sprite

.return
	RTL


SprInt_Side:
	%SolidSprite_PushFromSide()
	
	LDA $B6,X					; invert the calling sprite's x speed
	EOR #$FF
	INC A
	STA $B6,X
	
	LDA $B6,Y					; if the block sprite's x speed is higher than the calling sprite's x speed...
	SEC : SBC $B6,X
	BMI ?+
	STZ $157C,X					; set the calling sprite's face direction to 0 (facing right)
	RTL
	?+
	
	LDA #$01					; else, set the calling sprite's face direction to 1 (facing left)
	STA $157C,X
	RTL