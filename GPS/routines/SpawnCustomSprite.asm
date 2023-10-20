; this subroutine spawns a custom sprite of any specified sprite ID, without setting any other parameter
; input:	$00 = custom sprite ID (in list.txt)
; output:	Y = sprite slot (#$FF if no free sprite slots)


	STA $00
	PHX
	LDX #$09					; sprite slot to start the loop at

.loop
	LDA $14C8,X					; if the sprite slot is available, go to .slotfound
	BEQ .slotfound
	DEX
	BPL .loop
	LDY #$FF					; if no sprite slot is available, set Y to #$FF and return
	BRA .return

.slotfound
	LDA #$36					; set sprite ID (36 for custom sprites)
	STA $9E,X
	
	JSL $07F7D2					; reload sprite tables
	
	LDA #$00					; set the extension bytes to 0
	STA $7FAB40,X
	STA $7FAB4C,X
	STA $7FAB58,X
	STA $7FAB64,X
	
	LDA $00						; set custom sprite ID
	STA $7FAB9E,X
	
	JSL $0187A7					; load tweaker bytes for custom sprites
	
	LDA #$08					; mark the sprite as custom
	STA $7FAB10,X
	
	LDA #$01					; set the spawned sprite status to init
	STA $14C8,X
	
	TXY							; store the sprite slot into Y

.return
	PLX
	RTL