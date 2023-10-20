; this block inverts a kicked throwblock's horizontal speed when hit on the left side, rather than breaking it; it is non-solid on the right side
; insert as 25 (if inserted as 130 it will break against the tile regardless)

!ActsLike = $0130

db $37
JMP Solid			; Mario touching the tile from below
JMP Solid			; Mario touching the tile from above
JMP Solid			; Mario touching the tile from the side
JMP Solid			; sprite touching the tile from above or below
JMP BounceSprite	; sprite touching the tile from the side
JMP Solid			; capespin touching the tile
JMP Solid			; fire flower fireball touching the tile
JMP Solid			; Mario touching the upper corners of the tile
JMP Solid			; Mario's lower half is inside the block
JMP Solid			; Mario's upper half is inside the block
JMP Solid			; Mario is wallrunning on the side of the block
JMP Solid			; Mario is wallrunning through the block

BounceSprite:
	LDA $B6,x		; if the sprite is moving left, leave the tile as non-solid
	BMI Return
	
	LDA $9E,x		; if the sprite is not a throwblock, treat as a solid tile
	CMP #$53
	BNE Solid
	
	LDA $14C8,x		; if the throwblock is not in state 0A (kicked), treat as a solid tile (otherwise it has interaction issues)
	CMP #$0A
	BNE Solid
	
	LDA $B6,x		; get throwblock's x speed
	BEQ Solid		; if 0, make the tile solid so the throwblock won't get stuck inside the tile
	EOR #$FF		; otherwise, invert the throwblock's x speed
	INC
	STA $B6,x
	
	LDA #$01		; play wall hit sfx
	STA $1DF9
	
	JMP Return

Solid:
	LDY.b #!ActsLike>>8		; have Mario/sprites treat this tile as if it were tile 130 (solid)
	LDA.b #!ActsLike
	STA $1693

Return:
	RTL

print "This block inverts a throwblock's horizontal speed when hit on the left side, and is non-solid on the right side."