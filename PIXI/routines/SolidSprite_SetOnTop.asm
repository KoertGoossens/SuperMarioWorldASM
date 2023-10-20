; routine to set a sprite on top of a block sprite

	REP #$20					; set the calling sprite's y to be the block sprite's y minus 15 pixels
	LDA $06
	SEC : SBC #$000F
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	SEP #$20
	RTL