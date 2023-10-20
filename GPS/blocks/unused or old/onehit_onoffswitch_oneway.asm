; this tile behaves like an on/off switch until hit (switched), then it becomes a oneway (horizontal) block (241); insert as 130

!ActsLike = $0025

db $37
JMP LockSwitch			; Mario touching the tile from below
JMP Return				; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP SpriteV				; sprite touching the tile from above or below
JMP SpritePass			; sprite touching the tile from the side
JMP LockSwitch			; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP Return				; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block

SpriteV:
	%check_sprite_kicked_vertical()
	BCC Return
	JMP SpriteHit

SpritePass:
	LDY.b #!ActsLike>>8		; have sprites treat this tile as if it were tile 25 (non-solid)
	LDA.b #!ActsLike
	STA $1693
	JMP Return

SpriteHit:
	%sprite_block_position()

LockSwitch:
	LDA #$0B				; on/off switch sound effect
	STA $1DF9
	
	LDA $14AF				; toggle the on/off state
	EOR #$01
	STA $14AF
	
	REP #$10				; change tile into horizontal oneway cement block (241)
	LDX #$0241
	%change_map16()
	SEP #$10

Return:
	RTL

print "This on/off switch will turn into a horizontal oneway cement block (241) when hit and is not solid for sprites horizontally."