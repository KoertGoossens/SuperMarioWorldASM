; check whether a carryable/kicked item sprite hits a block from the side in kicked state or carryable state
; use only with custom item sprites


	LDA $7FAB9E,X			; if the sprite is a capespin, hit the block
	CMP #$4B
	BEQ .returnhit
	
	LDA $1662,X				; if the sprite is set to not activate an item block, don't hit the block
	AND #%00000011
	CMP #$02
	BEQ .returnnohit
	
	LDA $14C8,X				; else, if the sprite is in kicked status, hit the block
	CMP #$0A
	BEQ .returnhit
	
	LDA $1662,X				; else, if the sprite is set not to activate an item block from the side, don't hit the block
	AND #%00000011
	CMP #$01
	BNE .returnnohit
	
	LDA $14C8,X
	CMP #$09				; else, if the sprite is in carryable status, hit the block
	BRA .returnhit

.returnnohit
	CLC
	RTL

.returnhit
	SEC
	RTL