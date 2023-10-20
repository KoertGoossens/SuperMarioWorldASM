	LDA $15						; if holding Y/X...
	AND #%01000000
	BEQ ?+
	
	LDA $1470					; and Mario is not carrying something...
	ORA $187A					; and is not on Yoshi...
	BNE ?+
	
	LDA #$0B					; set the sprite status to 'carried'
	STA $14C8,X
	
	INC $1470					; set the 'carrying something' flag
	
	LDA #$08					; set the 'picking up an item' pose timer
	STA $1498
	?+
	
	RTL