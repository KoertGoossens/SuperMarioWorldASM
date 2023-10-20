; this tile is solid except horizontally for sprites - use as a ceiling tile where you have to do uptosses, to prevent horizontal collision bugs; insert as 130

!ActsLike = $0025

db $37
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP Return			; sprite touching the tile from above or below
JMP SpritePass		; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block

SpritePass:
	LDY.b #!ActsLike>>8		; have sprites treat this tile as if it were tile 25 (non-solid)
	LDA.b #!ActsLike
	STA $1693

Return:
	RTL

print "This block is solid except horizontally for sprites."