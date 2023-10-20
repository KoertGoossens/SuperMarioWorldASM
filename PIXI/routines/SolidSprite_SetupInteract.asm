; this routines checks which side of a block sprite the calling sprite is on, and stores it to scratch ram


	STX $00						; if the block sprite's sprite slot is higher than the calling sprite's sprite slot...
	CPY $00
	BPL ?+
	LDA $E4,Y					; store the block sprite's x (current frame) to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	LDA $D8,Y					; store the block sprite's y (current frame) to scratch RAM
	STA $06
	LDA $14D4,Y
	STA $07
	
	BRA .blockposloaded
	?+
	
	LDA $C2,Y					; else, store the block sprite's x (previous frame) to scratch RAM
	STA $02
	LDA $151C,Y
	STA $03
	
	LDA $1594,Y					; store the block sprite's y (previous frame) to scratch RAM
	STA $06
	LDA $160E,Y
	STA $07

.blockposloaded
	LDA $E4,X					; store the calling sprite's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $D8,X					; store the calling sprite's y to scratch RAM
	STA $04
	LDA $14D4,X
	STA $05
	
	LDA $1534,Y					; store the block sprite's width to scratch RAM
	STA $0C
	STZ $0D
	
	LDA $1570,Y					; store the block sprite's height to scratch RAM
	STA $0E
	STZ $0F

; set the blocked flags to 0
	STZ $08						; touching the block sprite from below
	STZ $09						; touching the block sprite from above
	STZ $0A						; touching the block sprite from the side

; check for top interaction
	REP #$20
	
	LDA $02						; if the calling sprite is too far left or right of the block sprite, don't check for top or bottom interactions
	SEC : SBC $00
	SBC #$0008
	BPL .checksides
	CLC : ADC #$0010
	ADC $0C
	BMI .checksides
	
	LDA $06						; and it's is not too far above or below of the block sprite...
	SEC : SBC $04
	BMI .checkbottom
	SBC #$0010
	BPL .checkbottom
	
	INC $08						; set the 'touching from above' flag

; check for bottom interaction
.checkbottom
	LDA $06						; and it's is not too far above or below of the block sprite...
	SEC : SBC $04
	CLC : ADC #$000F
	ADC $0E
	BMI .checksides
	SBC #$000F
	BPL .checksides

	INC $09						; set the 'touching from below' flag

; check for sideways interaction
.checksides
	LDA $06						; if the calling sprite is not too far above or below of the block sprite...
	SEC : SBC $04
	SBC #$0008
	BPL .skipside
	CLC : ADC #$0011
	ADC $0E
	BMI .skipside
	
	LDA $02						; and it's not too far left or right of the block sprite...
	SEC : SBC $00
	SBC #$000F
	BPL .skipside
	CLC : ADC #$001E
	ADC $0C
	BMI .skipside
	
	INC $0A						; set the 'touching from the side' flag

.skipside
	SEP #$20
	
	LDA $09						; if the 'touching from below' flag is set...
	BEQ ?+
	LDA $AA,X					; and the calling sprite is moving up...
	BPL ?+
	LDA #$10					; give it downward speed
	STA $AA,X
	?+
	
	RTL