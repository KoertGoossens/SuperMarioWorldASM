; this subroutine spawns quake sprite and centers it on the block

	PHB
	PHK
	PLB
	JSR DoSpawnQuakeSprite
	PLB
	RTL


DoSpawnQuakeSprite:
	PHY
	
	LDA #$4A					; spawn a quake sprite
	%SpawnCustomSprite()
	
	LDA $9A						; give the quake sprite the same position as the block
	AND #%11110000
	STA $E4,Y
	LDA $9B
	STA $14E0,Y
	
	LDA $98
	AND #%11110000
	STA $D8,Y
	LDA $99
	STA $14D4,Y
	
	PLY
	RTS