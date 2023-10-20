; (custom) handles block interaction for sprites in carryable status

	PHB
	PHK
	PLB
	JSR CheckBlock
	PLB
	RTL


CheckBlock:
	LDA $1588,X					; if the sprite is touching a ground, handle interaction with it
	AND #%00000100
	BEQ +
	JSR BlockGroundInteraction
	+
	
	LDA $1588,X					; if the item is touching a ceiling, handle interaction with it
	AND #%00001000
	BEQ +
	JSR BlockCeilingInteraction
	BRA .return
	+
	
	LDA $1588,X					; else, if the item is touching a block from the side, handle interaction with it
	AND #%00000011
	BEQ .return
	JSR BlockSideInteraction

.return
	RTS


BlockGroundInteraction:
	%BounceCarryableSprite()
	RTS


BlockCeilingInteraction:
	LDA #$10					; else (touching a ceiling), give the item downward y speed
	STA $AA,X
	
	LDA $1662,X					; if set to activate an item block from below...
	AND #%00000011
	CMP #$02
	BEQ .return
	%Item_ActivateCeiling()

.return
	RTS


BlockSideInteraction:
	%Carryable_BonkWall()
	
	LDA $157C,X					; invert the face direction
	EOR #$01
	STA $157C,X
	
	LDA $1662,X					; if set to activate an item block from the side...
	AND #%00000011
	CMP #$01
	BNE .return
	
	%Item_HitWall()

.return
	RTS