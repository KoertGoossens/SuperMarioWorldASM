; this subroutine spawns a sprite of any specified sprite ID in an available sprite slot, starting with slot 7, without setting any other parameter
; input:	A = sprite ID
; output:	Y = sprite slot (#$FF if no free sprite slots)
;
; code by Katun24

	STA $00						; store sprite ID into scratch RAM
	PHX
	LDX #$07

.loop							; loop through the sprite slots (starting at 7, since this is the highest slot vanilla bullet bills can spawn in (other slots are buggy for bullet bills))
	LDA $14C8,X
	BEQ .slotfound				; if the sprite slot is available, go to .slotfound
	DEX
	BPL .loop
	LDY #$FF					; if no sprite slot is available, set Y to #$FF and return
	BRA .return

.slotfound
	LDA $00						; set sprite ID
	STA $9E,X
	
	PHX
	JSL $07F7D2					; reload sprite tables
	PLX
	
	TXY							; store the sprite slot into Y

.return
	PLX
	RTL