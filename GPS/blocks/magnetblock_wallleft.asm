; this tile attaches a magnet block item sprite to it on the left, and kills Mario; insert as 130

!NonSolidTile = $0025

db $37
JMP MarioDie					; Mario touching the tile from below
JMP MarioDie					; Mario touching the tile from above
JMP MarioTouchHoriz				; Mario touching the tile from the side
JMP Return						; sprite touching the tile from above or below
JMP MagnetWall					; sprite touching the tile from the side
JMP Return						; capespin touching the tile
JMP Return						; fire flower fireball touching the tile
JMP MarioTouchHoriz				; Mario touching the upper corners of the tile
JMP MarioTouchHoriz				; Mario's lower half is inside the block
JMP MarioTouchHoriz				; Mario's upper half is inside the block
JMP MarioTouchHoriz				; Mario is wallrunning on the side of the block
JMP MarioTouchHoriz				; Mario is wallrunning through the block

CollisionSide:
	db $02,$0D

MarioTouchHoriz:
	LDX $93
	LDA $94
	AND #%00001111
	CMP CollisionSide,X
	BEQ Return

MarioDie:
	JSL $00F606					; instakill Mario
	RTL

MagnetWall:
	LDA $7FAB9E,X				; if the custom sprite ID (see PIXI list) is 2A (magnet block)...
	CMP #$2A
	BNE Return
	
	LDA $9E,X					; and the sprite is custom...
	CMP #$36
	BNE Return
	
	LDA $157C,X					; and the block interaction state is 0...
	BNE Return
	
	LDA $B6,X					; and the sprite is moving rightward...
	DEC
	BMI Return
	
	LDA #$01					; set the block interaction state to 'attached to wall'
	STA $157C,X
	
	STZ $B6,X					; set the sprite's x speed to 0
	STZ $AA,X					; set the sprite's y speed to 0
	
	LDA $E4,X					; set the sprite's x (low byte) to align with blocks
	AND #%11110000
	INC
	STA $E4,X
	
	LDY.b #!NonSolidTile>>8		; have sprites treat this tile as if it were tile 25 (non-solid)
	LDA.b #!NonSolidTile
	STA $1693

Return:
	RTL

print ""