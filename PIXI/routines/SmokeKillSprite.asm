	LDA #$04					; set the sprite status to 'erased in smoke'
	STA $14C8,X
	LDA #$1F					; set the death frame counter
	STA $1540,X
	RTL