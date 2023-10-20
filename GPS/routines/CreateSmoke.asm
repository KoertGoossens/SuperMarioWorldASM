; create a puff of smoke
; input:	$00	=	x position
;			$01	=	y position

	PHB
	PHK
	PLB
	JSR DoCreateSmoke
	PLB
	RTL


DoCreateSmoke:
	PHX
	LDX #$03				; load the number of smoke sprite slots

.loop
	LDA $17C0,X				; if the smoke sprite slot is empty...
	BNE .skipsmokesprite
	
	INC $17C0,X				; set the smoke sprite ID to 'smoke'
	
	LDA #$1B				; set the smoke sprite timer
	STA $17CC,X
	
	LDA $00					; set the smoke's x and y position to the input values
	STA $17C8,X
	LDA $01
	STA $17C4,X
	
	BRA .return

.skipsmokesprite
	DEX						; loop back to check the next smoke sprite slot
	BPL .loop
	
.return
	PLX
	RTS