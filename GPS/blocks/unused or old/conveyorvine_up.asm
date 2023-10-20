; a climbable vine tile that pushes Mario up when climbing it; insert as 6

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
	LDA #$03			; store the vine alignment (vertical conveyor)
	STA $13E7
	
	LDA $15
	AND #%00001100
	BNE +
	LDA #$E8			; y speed when neutraling the dpad
	BRA SetSpeed
	+
	AND #%00000100
	BNE +
	LDA #$D8			; y speed when holding up
	BRA SetSpeed
	+
	LDA #$F8			; y speed when holding down

SetSpeed:
	STA $1864
Return:
	RTL

print "A conveyor vine that pushes Mario up when climbing it."