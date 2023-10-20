; non-solid gravity switch; insert it as 25 (non-solid tile)

db $37
JMP FlipSwitch			; Mario touching the tile from below
JMP FlipSwitch			; Mario touching the tile from above
JMP FlipSwitch			; Mario touching the tile from the side
JMP SpriteHit			; sprite touching the tile from above or below
JMP SpriteHit			; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP FlipSwitch			; Mario touching the upper corners of the tile
JMP FlipSwitch			; Mario's lower half is inside the block
JMP FlipSwitch			; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block


SpriteHit:
	%sprite_block_position()

FlipSwitch:
	LDA #$0B				; on/off switch sound effect
	STA $1DF9
	
	LDA $1879				; toggle the sprite gravity state
	EOR #$01
	STA $1879
	
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