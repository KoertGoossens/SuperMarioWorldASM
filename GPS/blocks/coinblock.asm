; this block can be activated by Mario or sprites to turn it into a used block; insert as 130

db $37
JMP MarioHitBlock		; Mario touching the tile from below
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
	%CheckItemSpriteHorizontal_Fast()
	BCC Return
	JMP SpriteHit

SpriteHit:
	LDA #$08					; set the item sprite's 'disable quake interaction timer' to 8 frames
	STA $1FE2,X
	
	%sprite_block_position()

HitBlock:
	REP #$10					; change tile into used block (207)
	LDX #$0207
	%change_map16()
	SEP #$10
	
	%SpawnQuakeSprite()
	
	LDA $9A						; set the coin effect sprite's x equal to the block's x
	AND #%11110000
	STA $00
	LDA $9B
	STA $01
	
	LDA $98						; set the coin effect sprite's y 16 pixels above the block's y
	AND #%11110000
	STA $02
	LDA $99
	STA $03
	REP #$20
	LDA $02
	SEC : SBC #$0010
	STA $02
	SEP #$20
	
	%CreateCoinEffect()
	
	LDA #$01					; play coin sfx
	STA $1DFC

Return:
	RTL