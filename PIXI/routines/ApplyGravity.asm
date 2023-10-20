; routine to handle a sprite's x and y movement with gravity

	PHB
	PHK
	PLB
	JSR DoHandleGravity
	PLB
	RTL


DoHandleGravity:
	JSL $01801A					; update sprite's y position based on the y speed
	
	LDA $164A,X					; branch if the sprite is in water
	BNE .inwater
	
	LDA $AA,X					; increment the y speed
	CLC : ADC #$03
	STA $AA,X
	BMI ?+						; cap the falling speed at #$40
	CMP #$40
	BCC ?+
	LDA #$40
	STA $AA,X
	?+
	BRA .updatexpos

.inwater
	LDA $AA,X					; cap the sprite's upward y speed in to E8
	BPL ?+
	CMP #$E8
	BCS ?+
	LDA #$E8
	STA $AA,X
	?+

	LDA $AA,X					; increment the y speed
	CLC : ADC #$01
	STA $AA,X
	BMI ?+						; cap the falling speed at #$10
	CMP #$10
	BCC ?+
	LDA #$10
	STA $AA,X
	?+

.updatexpos
	JSL $018022					; update sprite's x position based on the x speed
	RTS