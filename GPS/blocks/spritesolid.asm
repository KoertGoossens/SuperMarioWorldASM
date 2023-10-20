; this tile is non-solid for Mario but solid for sprites; insert as 130

!ActsLike = $0025

db $37
JMP MarioPass			; Mario touching the tile from below
JMP MarioPass			; Mario touching the tile from above
JMP MarioPass			; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioPass			; Mario touching the upper corners of the tile
JMP MarioPass			; Mario's lower half is inside the block
JMP MarioPass			; Mario's upper half is inside the block
JMP MarioPass			; Mario is wallrunning on the side of the block
JMP MarioPass			; Mario is wallrunning through the block


MarioPass:
	LDY.b #!ActsLike>>8		; have Mario treat this tile as if it were tile 25 (non-solid)
	LDA.b #!ActsLike
	STA $1693

Return:
	RTL

print "This block is solid for sprites, but Mario can pass through."