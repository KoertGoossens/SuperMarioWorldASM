; this block makes custom explosive sprites explode upon contact; insert as 25 or 130

db $37
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
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block


ExplodingSprites:
	db $00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$01,$00,$00,$00		; 7 = bob-omb, C = bullet bill
	db $00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 15 = flying bob-omb
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

Sprite:
	PHY							; check whether the sprite is explodable, based on the indexed sprite's ID
	LDA $7FAB9E,X
	TAY
	LDA ExplodingSprites,Y		; if so, explode it
	BEQ +
	JSR ExplodeSprite
	+
	PLY

Return:
	RTL


ExplodeSprite:
	LDA #$1A					; play explosion sfx
	STA $1DFC
	
	PHY
	
	LDA #$49					; spawn explosion
	%SpawnCustomSprite()
	
	LDA $E4,X					; copy the x and y positions from the calling sprite to the explosion sprite
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	PLY
	STZ $14C8,X					; erase the calling sprite
	RTS