; This code spawns a sprite at the position (+offset) of the calling sprite, and returns the sprite index in Y
; This does not run the sprite's INIT; instead it just spawn in the 'normal' state immediately

; input:	A	= sprite id of sprite to spawn
;			C	= custom flag (CLC = vanilla sprite; SEC = custom sprite)
;			$00	= x offset
;			$01	= y offset
;			$02 = starting index of sprite slot
;
; output:	Y	= index to spawned sprite (#$FF means no sprite spawned)

	PHX							; check for a free sprite slot
	XBA
	LDX $02
	?-
		LDA $14C8,x
		BEQ ?+
			DEX
		BPL ?-
		SEC
		BRA .no_slot
	?+
	XBA
	STA $9E,x
	JSL $07F7D2					; reload sprite tables
	
	BCC ?+						; run this part if the carry flag is set (the sprite to spawn is custom)
		LDA !9E,x
		STA !7FAB9E,x
		
		REP #$20
		LDA $00 : PHA
		LDA $02 : PHA
		SEP #$20
		
		JSL $0187A7				; initialize sprite (this routine kills $00-$02, so preserve that)
				
		REP #$20
		PLA : STA $02
		PLA : STA $00
		SEP #$20
		
		LDA #$08
		STA !7FAB10,x
	?+
	
	LDA #$01				; set sprite status to normal
	STA $14C8,x
	
	TXY
	PLX
	
	LDA $00					; \ 
	CLC : ADC $E4,x			; |
	STA.w $E4,y				; | store x position + x offset (low byte)
	LDA #$00				; |
	BIT $00					; | create high byte based on $00 in A and add
	BPL ?+					; | to x position
	DEC						; |
?+	ADC $14E0,x				; |
	STA $14E0,y				; /
	
	LDA $01					; \ 
 	CLC : ADC $D8,x			; |
	STA.w $D8,y				; | store y position + y offset	
	LDA #$00				; |
	BIT $01					; | create high byte based on $01 in A and add
	BPL ?+					; | to y position
	DEC						; |
?+	ADC $14D4,x				; |
	STA $14D4,y				; /
	
	RTL	
	
.no_slot:
	TXY
	PLX
	RTL