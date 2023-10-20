; this subroutine spawns a sprite from a block and bounces it upward
; input:	A = sprite ID

	PHB
	PHK
	PLB
	JSR DoSpawnBlockSprite_Up
	PLB
	RTL


DoSpawnBlockSprite_Up:
	PHY
	PHA
	LDA #$02					; play 'grow' sfx
	STA $1DFC
	
	PLA
	%SpawnCustomSprite()
	
	LDA $9B						; position the spawned sprite 8 pixels to the left of the block
	XBA
	LDA $9A
	AND #%11110000
	REP #$20
	CLC : ADC #$FFF8
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $99						; position the spawned sprite 1 pixel above the block (= visually aligned with it)
	XBA
	LDA $98
	AND #%11110000
	REP #$20
	SEC : SBC #$0001
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	STY $08						; store the spawned sprite's index to scratch ram
	
	%DisableInteraction_Spawned()
	PLY
	
	%SpawnQuakeSprite()
	RTS