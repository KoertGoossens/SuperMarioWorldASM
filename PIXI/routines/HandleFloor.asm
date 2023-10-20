	LDA $1588,X					; if the sprite is touching a solid tile below...
	AND #%00000100
	BEQ .doreturn
	
	LDA $AA,X					; and it's not moving upward...
	BMI .doreturn
	
	LDA $1588,X					; if on a slope or on layer 2, set #$18 y speed
	BMI ?+
	LDA #$00					; else set #$00 y speed
	LDY $15B8,X
	BEQ ++
	?+
	LDA #$18
	++
	STA $AA,X

.doreturn
	RTL