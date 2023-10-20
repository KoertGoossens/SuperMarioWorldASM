; this block disappears in smoke when Mario jumps off; insert as 130

db $37
JMP Return				; Mario touching the tile from below
JMP MarioTouch			; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioTouch			; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block


MarioTouch:
	LDA $16				; if B was pressed...
	ORA $18				; or A was pressed...
	AND #%10000000
	BEQ Return
	
	LDA $9A				; store the block's x and y positions for the smoke routine
	AND #%11110000
	STA $00
	LDA $98
	AND #%11110000
	STA $01
	
	%CreateSmoke()		; erase the block with smoke
	%erase_block()

Return:
	RTL


print "This cloud tile disappears in smoke when Mario jumps off it."