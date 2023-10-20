; this tile behaves like an on/off switch, but doesn't change its appearance when hit; insert it as 130 (cement tile)

db $37
JMP MarioBelow			; Mario touching the tile from below
JMP Return				; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP SpriteV				; sprite touching the tile from above or below
JMP SpriteH				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP Return				; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block

MarioBelow:
	LDA $7D					; if Mario is moving up, flip the switch
	BMI FlipSwitch
	BRA Return

SpriteV:
	%CheckItemSpriteVertical()
	BCC Return
	BRA SpriteHit

SpriteH:
	%CheckItemSpriteHorizontal_Slow()
	BCC Return

SpriteHit:
	%sprite_block_position()

FlipSwitch:
	LDA $1473				; if the on/off switch cooldown flag is set, don't flip the switch
	BNE Return
	
	LDA $14AF				; toggle the on/off state
	EOR #$01
	STA $14AF
	
	INC $1473				; set the on/off switch cooldown flag

Return:
	RTL