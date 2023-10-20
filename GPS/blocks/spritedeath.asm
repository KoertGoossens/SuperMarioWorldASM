; this tile kills any sprite that touches it, but Mario can pass through; insert as 25

db $37
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP KillSprite		; sprite touching the tile from above or below
JMP KillSprite		; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block


KillSprite:
	LDA #$04				; set sprite status to 'killed with a spinjump'
	STA $14C8,X
	
	LDA #$25				; play stomp sfx
	STA $1DFC
	
	%sprite_block_position()
	
	LDA $E4,X				; store the sprite's x and y positions (low bytes) for the smoke routine
	STA $00
	LDA $D8,X
	STA $01
	
	%CreateSmoke()

Return:
	RTL

print "This block kills any sprite touching it."