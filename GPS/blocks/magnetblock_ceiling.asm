; this tile attaches a magnet block item sprite to it on the bottom, and kills Mario; insert as 130

db $37
JMP MarioDie			; Mario touching the tile from below
JMP MarioDie			; Mario touching the tile from above
JMP MarioTouchHoriz		; Mario touching the tile from the side
JMP MagnetCeiling		; sprite touching the tile from above or below
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
	LDX $93
	LDA $94
	AND #%00001111
	CMP CollisionSide,X
	BEQ Return

MarioDie:
	JSL $00F606			; instakill Mario
	RTL

MagnetCeiling:
	LDA $7FAB9E,X		; if the custom sprite ID (see PIXI list) is 2A (magnet block)...
	CMP #$2A
	BNE Return
	
	LDA $157C,X			; and the block interaction state is 0...
	BNE Return
	
	LDA $AA,X			; and the sprite is moving upward...
	BPL Return
	
	LDA #$02			; set the block interaction state to 'attached to ceiling'
	STA $157C,X
	
	STZ $B6,X			; set the sprite's x speed to 0
	STZ $AA,X			; set the sprite's y speed to 0
	
	LDA $D8,X			; set the sprite's y (low byte) to align with blocks
	CLC : ADC #$08
	AND #%11110000
	DEC #2
	STA $D8,X

Return:
	RTL