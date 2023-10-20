; this line tile rotates a line-guided sprite left>up or down>right; insert as 25

db $42
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP Sprite			; sprite touching the tile from above or below
JMP Sprite			; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block


Sprite:
	%CheckLineGuided()		; if the sprite is line-guided...
	BEQ Return
	
	LDA $157C,X				; if the sprite is moving left...
	CMP #$01
	BNE +
	LDA #$02				; store the rotation direction as up
	STA $1626,X
	
	LDA $0A					; store the tile's x (low byte)
	AND #%11110000
	STA $1602,X
	+
	
	CMP #$03				; else, if the sprite is moving down...
	BNE Return
	STZ $1626,X				; store the rotation direction as right
	
	LDA $0C					; store the tile's y (low byte)
	AND #%11110000
	STA $1602,X

Return:
	RTL