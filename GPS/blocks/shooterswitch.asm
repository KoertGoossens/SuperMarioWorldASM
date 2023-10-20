; this tile causes an on-screen custom shooter to shoot its projectile when hit; insert it as 130 (cement tile)
; this requires UberASM to decrement the shooter cooldown timer (freeram address $7C) after activation

db $37
JMP LockSwitch			; Mario touching the tile from below
JMP Return				; Mario touching the tile from above
JMP Return				; Mario touching the tile from the side
JMP SpriteV				; sprite touching the tile from above or below
JMP SpriteH				; sprite touching the tile from the side
JMP LockSwitch			; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP Return				; Mario touching the upper corners of the tile
JMP Return				; Mario's lower half is inside the block
JMP Return				; Mario's upper half is inside the block
JMP Return				; Mario is wallrunning on the side of the block
JMP Return				; Mario is wallrunning through the block

SpriteV:
	%CheckItemSpriteVertical()
	BCC Return
	JMP SpriteHit

SpriteH:
	%CheckItemSpriteHorizontal_Slow()
	BCC Return

SpriteHit:
	%sprite_block_position()

LockSwitch:
	LDA $7C					; if the shooter cooldown timer is above 0, return
	BNE Return
	
	LDA #$0B				; on/off switch sound effect
	STA $1DF9
	
	LDA #$08				; set the shooter cooldown timer to 8 frames
	STA $7C

Return:
	RTL

print "This tile causes an on-screen custom shooter to shoot its projectile when hit."