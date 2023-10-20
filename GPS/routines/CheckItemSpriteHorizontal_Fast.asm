; check whether a carryable/kicked item sprite hits a block from the side in kicked state or carryable state with a certain speed
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
	CMP #$09				; else, if the sprite is in carryable status, check the x speed to see if it should hit the block
	BEQ .checkspeed
	
	BRA .returnnohit

.checkspeed
	LDA $B6,X				; if the speed is negative, invert the value for comparison
	BPL ?+
	EOR #$FF
	INC
	?+
	CMP #$2E				; if the compared speed value is at least #$2E (minimum throw speed), hit the block
	BCS .returnhit

.returnnohit
	CLC
	RTL

.returnhit
	SEC
	RTL