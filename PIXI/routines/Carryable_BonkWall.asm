; routine to bonk a carryable sprite against a wall

	LDA $B6,X					; invert the calling sprite's x speed...
	EOR #$FF
	INC A
	STA $B6,X
	ASL							; and divide it by 4
	PHP
	ROR $B6,X
	PLP
	ROR $B6,X
	RTL