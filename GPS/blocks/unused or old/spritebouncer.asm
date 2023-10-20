; this tile bounces up any sprite that touches it, but Mario can pass through; insert as 25

db $37
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP BounceSprite	; sprite touching the tile from above or below
JMP BounceSprite	; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block

BounceSprite:
	LDA $14C8,X				; return if the sprite status is below 8 (= non-alive)
	CMP #$08
	BCC Return
	
	LDA #$C0				; give upward speed to the sprite
	STA $AA,X

Return:
	RTL

print "This block bounces up any sprite touching it."