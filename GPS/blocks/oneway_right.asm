; this tile is solid for Mario/sprites when moving to the left; insert as 25

!ActsLike = $0130

db $37
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP MarioBlock		; Mario touching the tile from the side
JMP Return			; sprite touching the tile from above or below
JMP SpriteBlock		; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block


MarioBlock:
	LDA $7B					; if Mario is not moving left, leave the tile as non-solid, otherwise make it solid
	BPL Return
	
	REP #$20				; prevent Mario getting stuck inside the tile
	LDA $9A
	AND #$FFF0
	CLC : ADC #$0009
	CMP $94
	SEP #$20
	BCS Return
	
	BRA MakeSolid


SpriteBlock:
	LDA $B6,X				; if the sprite is not moving left, leave the tile as non-solid, otherwise make it solid
	BPL Return


MakeSolid:
	LDY.b #!ActsLike>>8
	LDA.b #!ActsLike
	STA $1693


Return:
	RTL