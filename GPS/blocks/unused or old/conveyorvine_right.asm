; a climbable vine tile that pushes Mario to the right when climbing it; insert as 6

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
	LDA #$02			; store the vine alignment (horizontal conveyor)
	STA $13E7
	
	LDA $15
	AND #%00000011
	BNE +
	LDA #$18			; x speed when neutraling the dpad
	BRA SetSpeed
	+
	AND #%00000001
	BNE +
	LDA #$08			; x speed when holding left
	BRA SetSpeed
	+
	LDA #$28			; x speed when holding right

SetSpeed:
	STA $7C
Return:
	RTL

print "A conveyor vine that pushes Mario to the right when climbing it."