; this subroutine spawns 4 shatter particles (e.g. from when big Mario spins on a flipblock)
; uses scratch ram addresses $00-$03

	PHB
	PHK
	PLB
	JSR DoSpawnShatterTiles
	PLB
	RTL


TileXOffset:
	dw $0000,$0008,$0000,$0008
TileYOffset:
	dw $0003,$0003,$000B,$000B
TileXSpeed:
	db $FF,$01,$FF,$01
TileYSpeed:
	db $FB,$FB,$FD,$FD

DoSpawnShatterTiles:
	LDA #$07					; play shatter sfx
	STA $1DFC
	
	LDA $9A						; store the block's x to scratch ram
	AND #%11110000
	STA $00
	LDA $9B
	STA $01
	
	LDA $98						; store the block's y to scratch ram
	AND #%11110000
	STA $02
	LDA $99
	STA $03
	
	PHY
	PHX
	LDY #$03					; set the tile index to 3
	LDX #$0B					; set the minor extended sprite slot index to B

.spriteslotloop
	LDA $17F0,X					; if the minor extended sprite slot is unused, spawn a tile in it
	BEQ .spawntile

.spawnloop
	DEX							; decrement the minor extended sprite slot
	BPL .spriteslotloop			; if still positive, check to see if it's used again
	
	DEC $185D
	BPL .skipfinalslot
	
	LDA #$0B
	STA $185D

.skipfinalslot
	LDX $185D

.spawntile
	LDA #$01					; set the minor extended sprite type to 'shatter particle'
	STA $17F0,X
	
	PHY
	TYA							; multiply the tile index for the x/y offsets
	ASL
	TAY
	
	REP #$20					; offset the particle's x by 4 pixels
	LDA $00
	CLC : ADC TileXOffset,Y
	SEP #$20
	STA $1808,X
	XBA
	STA $18EA,X
	
	REP #$20					; offset the particle's y by 3 pixels
	LDA $02
	CLC : ADC TileYOffset,Y
	SEP #$20
	STA $17FC,X
	XBA
	STA $1814,X
	
	PLY
	
	LDA TileYSpeed,Y			; set x speed
	STA $1820,X
	
	LDA TileXSpeed,Y			; set y speed
	STA $182C,X
	
	STZ $1850,X					; set the particles to not flash
	
	DEY							; loop back until Y = 0
	BPL .spawnloop
	
	PLX
	PLY
	RTS