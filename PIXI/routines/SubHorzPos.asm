; subroutine to check horizontal proximity of Mario to a sprite
; returns the side in Y (0 = right, 1 = left)

	LDY #$00
	LDA $94
	SEC : SBC $E4,X
	LDA $95
	SBC $14E0,X
	BPL ?+
	INY
	?+
	RTL