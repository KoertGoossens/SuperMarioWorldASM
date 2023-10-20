; routine to handle a sprite's x and y movement with reverse gravity

	PHB
	PHK
	PLB
	JSR DoHandleGravity
	PLB
	RTL


DoHandleGravity:
	JSL $01801A					; update sprite's y position based on the y speed
	
	LDA $AA,X					; decrement the y speed
	SEC : SBC #$03
	STA $AA,X
	BPL ?+						; cap the rising speed at #$C0
	CMP #$C0
	BCS ?+
	LDA #$C0
	STA $AA,X
	?+
	
	JSL $018022					; update sprite's x position based on the x speed
	RTS