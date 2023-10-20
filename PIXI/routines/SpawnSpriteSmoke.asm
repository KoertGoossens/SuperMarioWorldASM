; this subroutine spawns smoke for custom sprites
; input:	$01		=	x offset
;			$02		=	y offset

	PHY
	
	LDA $15A0,X					; return if the sprite is horizontally or vertically offscreen (don't generate smoke)
	ORA $186C,X
	BNE .return
	
	LDY #$03					; find a free slot (4 slots available for smoke)

.loop
	LDA $17C0,Y
	BEQ ?+
	DEY
	BPL .loop
	BRA .return
	?+
	
	LDA #$01					; set effect type (1 = smoke)
	STA $17C0,Y
	
	LDA #$1B					; set timer to show smoke
	STA $17CC,Y
	
	LDA $E4,X					; store the calling sprite's x (low byte) + offset into the smoke's x (low byte)
	CLC : ADC $01
	STA $17C8,Y
	
	LDA $D8,X					; store the calling sprite's y (low byte) + offset into the smoke's y (low byte)
	CLC : ADC $02
	STA $17C4,Y

.return
	PLY
	RTL