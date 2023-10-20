	LDA $B6,X					; if the x speed is not 0...
	BEQ ?+
	INC $1570,X					; increment the animation frame counter
	?+
	
	LDA $1570,X					; store the animation frame (2 animation frames of 8 frames each)
	LSR #3
	AND #$01
	STA $1602,X
	RTL