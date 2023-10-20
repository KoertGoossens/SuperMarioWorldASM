; routine to handle rotation for big (2x2) line-guided sprites

	LDA $7FAB58,X						; if the block is line-guided...
	BEQ .doreturn
	
	LDA $14E0,X							; temporarily shift the block 8 pixels to the right and 8 pixels down for block interaction and the rotation routine
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0008
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	JSL $019138
	%LineGuided_HandleRotation()
	
	LDA $14E0,X
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC #$0008
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0008
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X

.doreturn
	RTL