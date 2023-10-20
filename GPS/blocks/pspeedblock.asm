; this tile give Mario p-speed immediately when walked over; insert it as 130 (solid)

db $37
JMP Return					; Mario touching the tile from below
JMP MarioTouchAbove			; Mario touching the tile from above
JMP Return					; Mario touching the tile from the side
JMP Return					; sprite touching the tile from above or below
JMP Return					; sprite touching the tile from the side
JMP Return					; capespin touching the tile
JMP Return					; fire flower fireball touching the tile
JMP MarioTouchAbove			; Mario touching the upper corners of the tile
JMP Return					; Mario's lower half is inside the block
JMP Return					; Mario's upper half is inside the block
JMP Return					; Mario is wallrunning on the side of the block
JMP Return					; Mario is wallrunning through the block

MarioTouchAbove:
	LDA #$70				; set the p-meter to max running speed
	STA $13E4

Return:
	RTL