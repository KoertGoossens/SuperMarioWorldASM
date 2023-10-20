; this block is solid when the on/off state is set to 'on', or non-solid when it's 'off'; it instakills Mario when solid

db $37
JMP On_Solid_Mario			; Mario touching the tile from below
JMP On_Solid_Mario			; Mario touching the tile from above
JMP On_Solid_MarioHoriz		; Mario touching the tile from the side
JMP On_Solid_Sprite			; sprite touching the tile from above or below
JMP On_Solid_Sprite			; sprite touching the tile from the side
JMP Return					; capespin touching the tile
JMP Return					; fire flower fireball touching the tile
JMP On_Solid_MarioHoriz		; Mario touching the upper corners of the tile
JMP On_Solid_MarioHoriz		; Mario's lower half is inside the block
JMP On_Solid_MarioHoriz		; Mario's upper half is inside the block
JMP On_Solid_MarioHoriz		; Mario is wallrunning on the side of the block
JMP On_Solid_MarioHoriz		; Mario is wallrunning through the block


On_Solid_Mario:
	LDA $14AF				; if the on/off state is 'off', make the tile non-solid
	BNE Off_NonSolid
	
	JSL $00F606				; else, instakill Mario
	RTL


CollisionSide:
	db $02,$0D

On_Solid_MarioHoriz:
	LDA $14AF				; if the on/off state is 'off', make the tile non-solid
	BNE Off_NonSolid
	
	LDX $93					; don't check for the outermost pixels horizontally
	LDA $94
	AND #%00001111
	CMP CollisionSide,X
	BEQ Off_NonSolid
	
	JSL $00F606				; instakill Mario
	RTL


On_Solid_Sprite:
	LDA $14AF				; if the on/off state is 'off', make the tile non-solid
	BNE Off_NonSolid
	
	LDY #$01				; else, make the tile solid
	LDA #$30
	STA $1693
	RTL


Off_NonSolid:
	LDY #$00				; change 'act as' to 25 (non-solid)
	LDA #$25
	STA $1693
	RTL


Return:
	RTL