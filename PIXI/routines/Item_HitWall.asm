; routine for a kicked sprite to hit a wall

	LDA #$01					; play bonk sfx
	STA $1DF9
	
	LDA $15A0,X					; if the sprite is horizontally offscreen, don't check for block activation
	BNE .doreturn
	
	LDA $E4,X					; if the sprite is not far enough on-screen, don't check for block activation
	SEC : SBC $1A
	CLC : ADC #$14
	CMP #$1C
	BCC .doreturn
	
	LDA $1588,X					; if the block is on layer 2, store this for block activation
	AND #%01000000
	ASL #2
	ROL
	AND #$01
	STA $1933
	
	LDY #$00					; load direction the block was hit from
	LDA $18A7					; load Map16 ID of block
	JSL $00F160					; handle block behavior after it's hit
	
	LDA #$05					; briefly disable water splashes and capespin/punch/etc. interaction for the item
	STA $1FE2,X

.doreturn
	RTL