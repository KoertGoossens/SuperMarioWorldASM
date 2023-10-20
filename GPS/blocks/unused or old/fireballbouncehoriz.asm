; this tile reflects a fireball horizontally, so that it flies into the opposite x direction rather than being erased; insert it as 130 (solid)

!ActsLike = $0025

db $37
JMP Return				; Mario touching the tile from below
JMP Return				; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP FireballHit			; fire flower fireball touching the tile
JMP Return				; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block

FireballHit:
	LDA $1747,X				; invert fireball's x speed
	EOR #$FF
	INC A
	STA $1747,X
	
	LDY.b #!ActsLike>>8		; have fireballs treat this tile as if it were tile 25 (non-solid)
	LDA.b #!ActsLike
	STA $1693
	JMP Return

Return:
	RTL

print "This block reflects a fireball horizontally."