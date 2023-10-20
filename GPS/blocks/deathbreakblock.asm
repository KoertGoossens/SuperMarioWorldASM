; this block instakills Mario, and shatters when hit by an item sprite (interaction like a flipblock); insert as 130

db $37
JMP MarioDie			; Mario touching the tile from below
JMP MarioDie			; Mario touching the tile from above
JMP MarioTouchHoriz		; Mario touching the tile from the side
JMP SpriteV				; sprite touching the tile from above or below
JMP SpriteH				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioTouchHoriz		; Mario touching the upper corners of the tile
JMP MarioTouchHoriz		; Mario's lower half is inside the block
JMP MarioTouchHoriz		; Mario's upper half is inside the block
JMP MarioTouchHoriz		; Mario is wallrunning on the side of the block
JMP MarioTouchHoriz		; Mario is wallrunning through the block


CollisionSide:
	db $02,$0D

MarioTouchHoriz:
	LDX $93								; don't check for the outermost pixels horizontally
	LDA $94
	AND #%00001111
	CMP CollisionSide,X
	BEQ Return

MarioDie:
	JSL $00F606							; instakill Mario
	RTL


SpriteV:
	LDA $7FAB9E,X						; if the sprite is a chomp, break the block
	CMP #$33
	BEQ SpriteHit
	
	%CheckItemSpriteVertical()
	BCC Return
	JMP SpriteHit


SpriteH:
	LDA $7FAB9E,X						; if the sprite is a chomp, break the block
	CMP #$33
	BEQ SpriteHit
	
	%BumpThrowblock()
	%CheckItemSpriteHorizontal_Fast()
	BCC Return


SpriteHit:
	%sprite_block_position()
	
	REP #$10							; change tile into non-solid tile (25)
	LDX #$0025
	%change_map16()
	SEP #$10
	
	%SpawnShatterTiles()
	%SpawnQuakeSprite()


Return:
	RTL