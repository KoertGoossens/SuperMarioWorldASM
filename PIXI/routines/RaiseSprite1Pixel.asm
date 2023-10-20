	LDA $14D4,X					; raise the sprite by 1 pixel (to counter sprites spawning 1 pixel below their intended position)
	XBA
	LDA $D8,X
	REP #$20
	DEC
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	RTL