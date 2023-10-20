; create a coin effect from a block
; input:	$00	=	x position (16-bit)
;			$02	=	y position (16-bit)

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
	
	LDA $00					; set the coin effect sprite's x and y positions to the input values
	STA $17E0,X
	LDA $01
	STA $17EC,X
	LDA $02
	STA $17D4,X
	LDA $03
	STA $17E8,X
	
	STZ $17E4,X				; set the coin effect sprite to be on layer 1
	
	LDA #$D0				; give the coin effect sprite upward y speed
	STA $17D8,X
	
	PLX
	RTS