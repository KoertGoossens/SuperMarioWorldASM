; routine to push a sprite from the side of a block sprite
; output:	$0B = side of the block sprite to push the calling sprite from

	PHB
	PHK
	PLB
	JSR DoPush
	PLB
	RTL


DoPush:
	STZ $0B
	
	LDA $1534,Y				; store the block sprite's width to scratch RAM
	STA $0D
	STZ $0E
	
	REP #$20				; push the calling sprite to the side of the block sprite
	LDA $02
	SEC : SBC $00
	BPL ?+
	LDA $02
	CLC : ADC #$000F
	ADC $0D
	INC $0B
	BRA .storeposition
	?+
	
	LDA $02
	CLC : ADC #$FFF1

.storeposition
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	RTS