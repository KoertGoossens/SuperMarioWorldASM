; this tile locks sprites in place when the on/off state is set to 'off'; insert as 25

db $42
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP Sprite			; sprite touching the tile from above or below
JMP Sprite			; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block


Sprite:
	LDA $14AF					; return if the on/off state is 'on'
	BEQ Return
	
	LDA $14C8,X					; if the sprite is not in normal/carryable/kicked status, return
	CMP #$08
	BCC Return
	CMP #$0B
	BCS Return
	
	%sprite_block_position()
	
	LDA $14E0,X					; if the sprite is not horizontally centered enough inside the block (7-pixel range), return
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC $9A
	CLC : ADC #$0003
	BMI Return
	CMP #$0007
	BCS Return
	SEP #$20
	
	LDA $14D4,X					; if the sprite is not vertically centered enough inside the block (7-pixel range), return
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $98
	CLC : ADC #$0003
	BMI Return
	CMP #$0007
	BCS Return
	SEP #$20
	
	LDA $9A						; lock the sprite's x position to the block's x position
	STA $E4,X
	LDA $9B
	STA $14E0,X
	
	REP #$20					; load the block's y position minus 1
	LDA $98
	DEC
	
;	PHY							; if the sprite is a Yoshi, subtract another 16 pixels
;	LDY $9E,X
;	CPY #$69
;	BNE +
;	SEC : SBC #$0010
;	+
;	PLY
	
	SEP #$20					; store it to the sprite's y position
	STA $D8,X
	XBA		
	STA $14D4,X
	
	STZ $AA,X					; set the sprite's y speed to 0 (to prevent items from able to move through the block with an uptoss)

Return:
	SEP #$20
	RTL