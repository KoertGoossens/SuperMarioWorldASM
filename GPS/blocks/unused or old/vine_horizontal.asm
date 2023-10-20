; a horizontal climbable vine tile (to with custom physics); insert as 6

db $42
JMP MarioTouch			; Mario touching the tile from below
JMP MarioTouch			; Mario touching the tile from above
JMP MarioTouch			; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioTouch			; Mario touching the upper corners of the tile
JMP MarioTouch			; Mario's lower half is inside the block
JMP MarioTouch			; Mario's upper half is inside the block

MarioTouch:
	STZ $13E7			; store the vine alignment (horizontal)

Return:
	RTL

print "A horizontal vine tile."