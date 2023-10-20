; routine to set Mario above Yoshi after taking damage on Yoshi or dismounting


	LDA $14D4,X					; set Mario's y 4 pixels above Yoshi's y (so it actually makes him dismount slightly from below Yoshi's saddle)
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0004
	
	LDY $154C,X					; (custom) if the mount cooldown is set (drop-dismount), raise Mario another 4 pixels
	BEQ ?+
	SEC : SBC #$0004
	?+
	
	STA $96
	STA $D3
	SEP #$20
	RTL