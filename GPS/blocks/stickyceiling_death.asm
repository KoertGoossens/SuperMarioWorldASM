; this tile makes Mario and sprites stick to the ceiling; insert it as 25

db $37
JMP MarioTouchBelow			; Mario touching the tile from below
JMP MarioHurt				; Mario touching the tile from above
JMP MarioHurtHoriz			; Mario touching the tile from the side
JMP SpriteTouch				; sprite touching the tile from above or below
JMP Return					; sprite touching the tile from the side
JMP Return					; capespin touching the tile
JMP Return					; fire flower fireball touching the tile
JMP MarioHurtHoriz			; Mario touching the upper corners of the tile
JMP MarioHurtHoriz			; Mario's lower half is inside the block
JMP MarioHurtHoriz			; Mario's upper half is inside the block
JMP MarioHurtHoriz			; Mario is wallrunning on the side of the block
JMP MarioHurtHoriz			; Mario is wallrunning through the block


MarioTouchBelow:
	LDA $98					; if Mario's head is in the top half of the tile...
	AND #%00001111
	CMP #$09
	BCS Return
	
	BRA MarioHurt


CollisionSide:
	db $02,$0D

MarioHurtHoriz:
	LDX $93					; don't check for the outermost pixels horizontally
	LDA $94
	AND #%00001111
	CMP CollisionSide,X
	BEQ Return

MarioHurt:
	JSL $00F5B7				; hurt Mario
	RTL


SpriteTouch:
	LDA $0C					; if the sprite is in the top half of the tile...
	AND #%00001111
	CMP #$09
	BCS Return
	
	LDA $0D					; else, set the sprite's y position halfway inside the block
	XBA
	LDA $0C
	AND #%11110000
	REP #$20
	CLC : ADC #$0006
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA #$FC				; give the sprite minimal upward y speed
	STA $AA,X
	RTL


Return:
	RTL