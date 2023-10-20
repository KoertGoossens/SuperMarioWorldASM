; this block is solid when the on/off state is set to 'on', or non-solid when it's 'off'

db $37
JMP On_Solid			; Mario touching the tile from below
JMP On_Solid			; Mario touching the tile from above
JMP On_Solid			; Mario touching the tile from the side
JMP On_Solid			; sprite touching the tile from above or below
JMP On_Solid			; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP On_Solid			; Mario touching the upper corners of the tile
JMP On_Solid			; Mario's lower half is inside the block
JMP On_Solid			; Mario's upper half is inside the block
JMP On_Solid			; Mario is wallrunning on the side of the block
JMP On_Solid			; Mario is wallrunning through the block


On_Solid:
	LDA $14AF			; if the on/off state is 'off', make the tile non-solid
	BNE Off_NonSolid
	
	LDY #$01			; else, make the tile solid
	LDA #$30
	STA $1693
	RTL

Off_NonSolid:
	LDY #$00			; change 'act as' to 25 (non-solid)
	LDA #$25
	STA $1693

Return:
	RTL