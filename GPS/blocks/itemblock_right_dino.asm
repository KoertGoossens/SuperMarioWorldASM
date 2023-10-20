; this item block spawns a dino; insert as 130

db $37
JMP MarioHitBlock	; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP SpriteV			; sprite touching the tile from above or below
JMP SpriteH			; sprite touching the tile from the side
JMP HitBlock		; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block


MarioHitBlock:
	LDA $7D						; if Mario is moving upward, hit the block
	BMI HitBlock
	RTL

SpriteV:
	%CheckItemSpriteVertical()
	BCC Return
	JMP SpriteHit

SpriteH:
	%BumpThrowblock()
	%CheckItemSpriteHorizontal_Slow()
	BCC Return

SpriteHit:
	%sprite_block_position()

HitBlock:
	LDA #$00					; spawn a dino
	%SpawnBlockSprite_Right()
	
	PHX
	LDX $08
	LDA #$20					; give the dino rightward speed
	STA $7FAB40,X
	PLX
	
	REP #$10					; change tile into used block (207)
	LDX #$0207
	%change_map16()
	SEP #$10

Return:
	RTL