; routine to update a sprite's x position based on its x speed (adaptation of JSL $018022)
; output:	A = number of pixels the x position is incremented

	LDA $B6,X					; if the x speed is 0, return
	BEQ .return
	
	ASL #4						; add the x speed to the x position fraction bits (using the high nibble only)
	CLC : ADC $14F8,X
	STA $14F8,X
	
	PHP
	PHP							; divide the x speed by 16 and increment the x position by this value
	LDY #$00
	LDA $B6,X
	LSR #4
	CMP #$08
	BCC ?+
	ORA #%11110000
	DEY
	?+
	PLP
	
	PHA							; (store the incrementation value)
	
	ADC $E4,X
	STA $E4,X
	TYA
	ADC $14E0,X
	STA $14E0,X
	
	PLA
	PLP
	ADC.b #$00

.return
	RTL