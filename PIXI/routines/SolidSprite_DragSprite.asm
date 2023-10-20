; routine to drag a sprite along a block sprite when on top of it

	LDA $1662,Y					; if $1662,Y (tweaker byte) is set to #$3C for the block sprite...
	CMP #$3C
	BNE .return
	
	LDA $1528,Y					; store the block sprite's 'number of pixels the sprite has moved' to scratch ram
	STA $0B
	STZ $0C						; add the high byte (set to #$00 or #$FF)
	BPL ?+
	LDA #$FF
	STA $0C
	?+
	
	REP #$20					; move the calling sprite along with the block
	LDA $00
	CLC : ADC $0B
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X

.return
	RTL