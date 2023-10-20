; this tile behaves like an on/off switch until hit (switched), then it becomes a cement block (130); insert it as 130 (cement tile)

db $37
JMP FlipSwitch			; Mario touching the tile from below
JMP Return				; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP SpriteV				; sprite touching the tile from above or below
JMP SpriteH				; sprite touching the tile from the side
JMP FlipSwitch			; capespin touching the tile
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
	JMP SpriteHit

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
	
	REP #$10				; change tile into cement block (300)
	LDX #$0300
	%change_map16()
	SEP #$10
	
	INC $1473				; set the on/off switch cooldown flag

Return:
	RTL