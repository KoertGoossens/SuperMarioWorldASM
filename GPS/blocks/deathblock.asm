; this tile instakills Mario (regardless of his power-up) and has the exact collision box of a muncher; it can be inserted as 130 (solid) or 25 (non-solid)

db $37
JMP MarioDie			; Mario touching the tile from below
JMP MarioDie			; Mario touching the tile from above
JMP MarioTouchHoriz		; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioTouchHoriz		; Mario touching the upper corners of the tile
JMP MarioTouchHoriz		; Mario's lower half is inside the block
JMP MarioTouchHoriz		; Mario's upper half is inside the block
JMP MarioTouchHoriz		; Mario is wallrunning on the side of the block
JMP MarioTouchHoriz		; Mario is wallrunning through the block


CollisionSide:
	db $02,$0D

MarioTouchHoriz:
	LDX $93					; don't check for the outermost pixels horizontally
	LDA $94
	AND #%00001111
	CMP CollisionSide,X
	BEQ Return

MarioDie:
	JSL $00F606				; instakill Mario

Return:
	RTL

print "This block kills Mario when touched, regardless of his power-up."