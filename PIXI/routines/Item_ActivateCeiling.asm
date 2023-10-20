; routine for an item sprite to activate a block after hitting it from below

	LDA $E4,X					; store the item's x and y positions for block activation
	CLC : ADC #$08
	STA $9A
	LDA $14E0,X
	CLC : ADC #$00
	STA $9B
	LDA $D8,X
	AND #$F0
	STA $98
	LDA $14D4,X
	STA $99
	
	LDA $1588,X					; if the block is on layer 2, store this for block activation
	AND #%00100000
	ASL #3
	ROL
	AND #$01
	STA $1933
	
	LDY #$00					; load direction the block was hit from (bottom)
	LDA $1868					; load Map16 ID of block
	JSL $00F160					; handle block behavior after it's hit
	
	LDA #$08					; briefly disable water splashes and capespin/punch/etc. interaction for the item
	STA $1FE2,X
	RTL