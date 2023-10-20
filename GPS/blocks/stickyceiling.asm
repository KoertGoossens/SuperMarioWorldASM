; this tile makes Mario and sprites stick to the ceiling; insert it as 25

db $37
JMP MarioTouchBelow			; Mario touching the tile from below
JMP Return					; Mario touching the tile from above
JMP Return					; Mario touching the tile from the side
JMP SpriteTouch				; sprite touching the tile from above or below
JMP Return					; sprite touching the tile from the side
JMP Return					; capespin touching the tile
JMP Return					; fire flower fireball touching the tile
JMP Return					; Mario touching the upper corners of the tile
JMP Return					; Mario's lower half is inside the block
JMP Return					; Mario's upper half is inside the block
JMP Return					; Mario is wallrunning on the side of the block
JMP Return					; Mario is wallrunning through the block


MarioTouchBelow:
	LDA $98					; if Mario's head is in the top half of the tile...
	AND #%00001111
	CMP #$09
	BCS Return
	
	LDA $15					; if not holding B/A...
	AND #%10000000
	BNE +
	LDA $7D					; and moving upward...
	BPL Return
	STZ $7D					; set Mario's y speed to 0
	RTL
	+
	
	LDA $99					; else, set Mario's y position halfway inside the block
	XBA
	LDA $98
	AND #%11110000
	REP #$20
	SEC : SBC #$0008
	STA $96
	SEP #$20
	
	LDA #$FD				; give Mario minimal upward y speed
	STA $7D
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