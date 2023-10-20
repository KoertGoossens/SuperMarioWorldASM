; routine to display contact gfx for a sprite
; input:	$0E = x offset from sprite
;			$0F = y offset from sprite

	PHB
	PHK
	PLB
	JSR DoContactGFX
	PLB
	RTL


DoContactGFX:
	LDA $15A0,X							; return if the calling sprite is horizontally or vertically offscreen
	ORA $186C,X
	BNE .doreturn
	
	PHY
	LDY #$03							; smoke sprite index to check

.smokespriteloop
	LDA $17C0,Y							; loop to find an empty smoke sprite slot
	BEQ .emptysmokesprite
	
	DEY
	BPL .smokespriteloop
	INY

.emptysmokesprite
	LDA #$02							; smoke sprite type (2 = contact gfx)
	STA $17C0,Y
	
	LDA $E4,X							; set the smoke sprite's x equal to the calling sprite's x
	CLC : ADC $0E
	STA $17C8,Y
	
	LDA $D8,X							; set the smoke sprite's y equal to the calling sprite's y
	CLC : ADC $0F
	STA $17C4,Y
	
	LDA #$08							; number of frames to display the contact gfx
	STA $17CC,Y
	
	PLY

.doreturn
	RTS