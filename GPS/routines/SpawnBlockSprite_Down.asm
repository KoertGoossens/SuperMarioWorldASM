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
	
	LDA $9A						; position the spawned sprite at the same x as the block
	AND #%11110000
	STA $E4,Y
	LDA $9B
	STA $14E0,Y
	
	LDA $99						; position the spawned sprite 8 pixels below the block
	XBA
	LDA $98
	AND #%11110000
	REP #$20
	CLC : ADC #$0008
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	STY $08						; store the spawned sprite's index to scratch ram
	
	%DisableInteraction_Spawned()
	PLY
	
	%SpawnQuakeSprite()
	RTS