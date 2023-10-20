; this subroutine spawns 4 shatter particles (e.g. from when a throwblock breaks)
; input:	$00		=	x (16-bit)
;			$02		=	y (16-bit)

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
	
	REP #$20					; offset the particle's x based on the tile index
	LDA $00
	CLC : ADC TileXOffset,Y
	SEP #$20
	STA $1808,X
	XBA
	STA $18EA,X
	
	REP #$20					; offset the particle's y based on the tile index
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
	
	LDA #$02					; set the particles to flash
	STA $1850,X
	
	DEY							; loop back until Y = 0
	BPL .spawnloop
	
	PLX
	PLY
	RTS