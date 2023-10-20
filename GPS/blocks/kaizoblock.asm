; kaizo block; insert as 25

db $37
JMP MarioHitBlock		; Mario touching the tile from below
JMP Return				; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP Return				; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block


MarioHitBlock:
	LDA $7D						; if Mario is moving upward, hit the block
	BPL Return
	
	REP #$10					; change tile into used block (207)
	LDX #$0207
	%change_map16()
	SEP #$10
	
	%SpawnQuakeSprite()
	
	LDA $9A						; set the coin effect sprite's x equal to the block's x
	AND #%11110000
	STA $00
	LDA $9B
	STA $01
	
	LDA $98						; set the coin effect sprite's y 16 pixels above the block's y
	AND #%11110000
	STA $02
	LDA $99
	STA $03
	REP #$20
	LDA $02
	SEC : SBC #$0010
	STA $02
	SEP #$20
	
	%CreateCoinEffect()
	
	LDA #$01					; play coin sfx
	STA $1DFC

Return:
	RTL