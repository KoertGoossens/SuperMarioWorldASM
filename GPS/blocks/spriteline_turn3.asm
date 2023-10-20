; this line tile rotates a line-guided sprite right>down or up>left; insert as 25

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
	
	LDA $157C,X				; if the sprite is moving right...
	BNE +
	LDA #$03				; store the rotation direction as down
	STA $1626,X
	
	LDA $0A					; store the tile's x (low byte)
	AND #%11110000
	STA $1602,X
	+
	
	CMP #$02				; else, if the sprite is moving up...
	BNE Return
	LDA #$01				; store the rotation direction as left
	STA $1626,X
	
	LDA $0C					; store the tile's y (low byte)
	AND #%11110000
	STA $1602,X

Return:
	RTL