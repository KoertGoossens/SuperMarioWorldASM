; routine to update a sprite's y position based on its y speed (adaptation of JSL $01801A)

	LDA $AA,X					; if the y speed is 0, return
	BEQ .return
	
	ASL #4						; add the y speed to the y position fraction bits (using the high nibble only)
	CLC : ADC $14EC,X
	STA $14EC,X
	
	PHP							; divide the y speed by 16 and increment the y position by this value
	LDY #$00
	LDA $AA,X
	LSR #4
	CMP #$08
	BCC ?+
	ORA #%11110000
	DEY
	?+
	PLP
	ADC $D8,X
	STA $D8,X
	TYA
	ADC $14D4,X
	STA $14D4,X

.return
	RTL