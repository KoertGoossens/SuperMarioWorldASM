; handle block interaction for sprites in normal status


	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ ?+
	LDA $B6,X					; invert the x speed
	EOR #$FF
	INC A
	STA $B6,X
	?+
	
	LDA $B6,X					; if the x speed is not 0...
	BEQ ?+
	STZ $157C,X					; set the face direction based on the x speed
	BPL ?+
	INC $157C,X
	?+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ ?+
	STZ $AA,X					; set the y speed to 0
	?+
	
	%HandleFloor()
	
	LDA $1588,X					; if the sprite is in the air...
	AND #%00000100
	BNE ?+
	STZ $1570,X					; set the animation frame counter to 0
	?+
	
	RTL