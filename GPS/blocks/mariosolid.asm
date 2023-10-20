; this tile is solid for Mario but sprites can pass through; insert as 25

!ActsLike = $0130

db $37
JMP MarioSolid			; Mario touching the tile from below
JMP MarioSolid			; Mario touching the tile from above
JMP MarioSolid			; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioSolid			; Mario touching the upper corners of the tile
JMP MarioSolid			; Mario's lower half is inside the block
JMP MarioSolid			; Mario's upper half is inside the block
JMP MarioSolid			; Mario is wallrunning on the side of the block
JMP MarioSolid			; Mario is wallrunning through the block


MarioSolid:
	LDY.b #!ActsLike>>8		; have Mario treat this tile as if it were tile 130 (solid)
	LDA.b #!ActsLike
	STA $1693

Return:
	RTL

print "This block is solid for Mario, but sprites can pass through."