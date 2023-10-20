; create a coin effect

	PHB
	PHK
	PLB
	JSR DoCreateCoinEffect
	PLB
	RTL


DoCreateCoinEffect:
	PHX
	LDX #$03				; load the number of coin effect sprite slots

.loop
	LDA $17D0,X				; if the coin effect sprite slot is empty, spawn a coin effect
	BEQ .spawncoineffect
	
	DEX						; else, loop back to check the next coin effect sprite slot
	BPL .loop
	
	DEC $1865				; decrement the coin effect sprite index
	BPL +					; if negative, set it to 3
	LDA #$03
	STA $1865
	+
	LDX $1865				; store the coin effect sprite index as the coin effect sprite slot

.spawncoineffect
	INC $17D0,X				; set the coin effect sprite slot to be in use
	STZ $17E4,X				; set the coin effect sprite to be on layer 1
	
	LDA #$D0				; give the coin effect sprite upward y speed
	STA $17D8,X
	
	TXY
	PLX
	RTS