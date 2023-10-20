; this block boosts Mario and sprites rightward; insert as 25

db $37
JMP MarioTouch		; Mario touching the tile from below
JMP MarioTouch		; Mario touching the tile from above
JMP MarioTouch		; Mario touching the tile from the side
JMP Return			; sprite touching the tile from above or below
JMP Return			; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP MarioTouch		; Mario touching the upper corners of the tile
JMP MarioTouch		; Mario's lower half is inside the block
JMP MarioTouch		; Mario's upper half is inside the block
JMP MarioTouch		; Mario is wallrunning on the side of the block
JMP MarioTouch		; Mario is wallrunning through the block

!speed_x	= $30
!speed_y	= $30


MarioTouch:
	LDA #!speed_x				; give Mario rightward speed
	STA $7B
	LDA #!speed_y				; give Mario downward speed
	STA $7D
	
	LDA $9A						; store the block's x and y positions for the smoke routine
	AND #%11110000
	STA $00
	LDA $98
	AND #%11110000
	STA $01
	
	%CreateSmoke()				; erase the block with smoke
	%erase_block()
	
	LDA #$09					; play shot sfx
	STA $1DFC

Return:
	RTL