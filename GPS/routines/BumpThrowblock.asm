; this subroutine bounces a throwblock off the side of a solid block

	PHB
	PHK
	PLB
	JSR DoBumpThrowblock
	PLB
	RTL


DoBumpThrowblock:
	LDA $7FAB9E,X				; if the sprite is a throwblock...
	CMP #$0E
	BNE .return
	LDY #$00					; change the block's 'act as' to 25 (non-solid)
	LDA #$25
	STA $1693
	
	LDA #$01					; play bonk sfx
	STA $1DF9
	
	LDA $B6,X					; invert the throwblock's x speed
	EOR #$FF
	INC A
	STA $B6,X

.return
	RTS