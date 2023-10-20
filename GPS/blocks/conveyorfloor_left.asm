; this block drags Mario and sprites to the left when they're on it; insert as 130

db $37
JMP Return				; Mario touching the tile from below
JMP MarioTop			; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP SpriteTouch			; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioTop			; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block


MarioTop:
	REP #$20				; move Mario's x position 2 pixels to the left
	LDA $94
	CLC : ADC #$FFFE
	STA $94
	SEP #$20
	RTL


SpriteTouch:
	LDA $14E0,X				; move the sprite's x position 2 pixels to the left
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$FFFE
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	RTL


Return:
	RTL