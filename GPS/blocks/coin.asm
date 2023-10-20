; coin; activating a coin/block p-switch turns it into a used block; insert as 25

db $37
JMP On_Solid_Mario		; Mario touching the tile from below
JMP On_Solid_Mario		; Mario touching the tile from above
JMP On_Solid_Mario		; Mario touching the tile from the side
JMP On_Solid_SpriteV	; sprite touching the tile from above or below
JMP On_Solid_SpriteH	; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP On_Solid_Mario		; Mario touching the upper corners of the tile
JMP On_Solid_Mario		; Mario's lower half is inside the block
JMP On_Solid_Mario		; Mario's upper half is inside the block
JMP On_Solid_Mario		; Mario is wallrunning on the side of the block
JMP On_Solid_Mario		; Mario is wallrunning through the block


On_Solid_Mario:
	STZ $00					; set the scratch ram address to 0 (default)
	BRA HandleSolid

On_Solid_SpriteV:
	LDA #$01				; set the scratch ram address to 1 for vertical sprite interaction
	STA $00
	BRA HandleSolid

On_Solid_SpriteH:
	LDA #$02				; set the scratch ram address to 2 for horizontal sprite interaction
	STA $00

HandleSolid:
	LDA $14AD				; if the p-switch timer is not 0, make the tile non-solid
	BEQ HandleCoin
	
	LDY #$01				; set 'act as' to 130 (solid)
	LDA #$30
	STA $1693
	
	LDA $00					; for horizontal sprite interaction, handle bumping throwblocks
	CMP #$02
	BNE Return
	%BumpThrowblock()
	RTL

HandleCoin:
	LDY #$00				; set 'act as' to 25 (non-solid)
	LDA #$25
	STA $1693
	
	LDA $00					; for Mario interaction, handle touching the coin
	BNE Return
	
	LDA #$01				; play coin sfx
	STA $1DFC
	
	LDA $9A					; store the block's x and y positions for the glitter routine
	AND #%11110000
	STA $00
	LDA $98
	AND #%11110000
	STA $01
	
	%CreateGlitter()		; erase the block with glitter
	%erase_block()

Return:
	RTL