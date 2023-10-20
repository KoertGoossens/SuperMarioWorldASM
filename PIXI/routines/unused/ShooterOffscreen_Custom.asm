	LDA $17A3,X					; return if horizontally offscreen 3 tiles or more
	XBA
	LDA $179B,X
	REP #$20
	SEC : SBC $1A
	SBC #$FFC0
	BMI Return
	CMP #$0170
	BPL Return
	SEP #$20