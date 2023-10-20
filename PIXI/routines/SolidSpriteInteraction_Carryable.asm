; this routine handles standard interaction between a sprite in carryable status and a solid sprite


	%SolidSprite_SetupInteract()
	
	LDA $08							; branch if the 'touching from above' flag is set
	BNE SprInt_Top_Carryable
	
	LDA $09							; else, branch if the 'touching from below' flag is set
	BNE SprInt_Bottom_Carryable
	
	LDA $0A							; else, branch if the 'touching from the side' flag is set
	BNE SprInt_Side_Carryable
	RTL


SprInt_Top_Carryable:
	LDA $AA,X						; don't interact if the calling sprite is moving up
	BMI .return
	
	%SolidSprite_DragSprite()		; drag the calling sprite horizontally along the block sprite
	
	PHY
	%BounceCarryableSprite()
	PLY
	
	LDA $AA,X						; if the calling sprite's x speed is 0...
	BNE .return
	
	%SolidSprite_SetOnTop()			; set the calling sprite on top of the block sprite

.return
	RTL


SprInt_Bottom_Carryable:
	LDA $1662,X						; if set to activate an item block from below...
	AND #%00000011
	CMP #$02
	BEQ .return
	
	JSR ActivateSolidSprite			; check for block activation

.return
	RTL


SprInt_Side_Carryable:
	%SolidSprite_PushFromSide()		; move the calling sprite horizontally out of the block sprite
	
	LDA $B6,X						; if the calling sprite's x speed is not 0...
	BEQ .return
	BMI ?+							; and it is moving towards the block sprite...
	LDA $0B
	BNE .return
	BRA .bonkwall
	?+
	LDA $0B
	BEQ .return

.bonkwall
	%Carryable_BonkWall()			; bonk it against the side
	
	LDA $1662,X						; if set to activate an item block from the side...
	AND #%00000011
	CMP #$01
	BNE .return
	
	LDA #$01						; play bonk sfx
	STA $1DF9
	
	JSR ActivateSolidSprite			; check for block activation

.return
	RTL


ActivateSolidSprite:
	%SolidSprite_Activate()
	
	LDA $1558,Y						; if the block sprite's activation timer was set (the block was just activated)...
	CMP #$09
	BNE +
	LDA #$08						; set the item sprite's 'disable quake interaction timer' to 8 frames
	STA $1FE2,X
	+
	
	RTS