; check whether a carryable/kicked item sprite hits a block from below
; use only with custom item sprites


	LDA $1662,X				; if the sprite is set to not activate an item block, don't hit the block
	AND #%00000011
	CMP #$02
	BEQ .returnnohit
	
	LDA $AA,X				; if the sprite is not moving upward, return without hitting the block
	BPL .returnnohit
	
	LDA $14C8,X				; if the sprite is in carryable status, hit the block
	CMP #$09
	BEQ .returnhit
	CMP #$0A				; else, if the sprite is in kicked status, hit the block
	BEQ .returnhit

.returnnohit
	CLC
	RTL

.returnhit
	SEC
	RTL