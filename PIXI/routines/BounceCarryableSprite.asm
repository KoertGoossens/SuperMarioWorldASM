; routine to bounce a carryable sprite up from a solid surface

	PHB
	PHK
	PLB
	JSR DoBounce
	PLB
	RTL


BounceXSpeed:
	db $00,$00,$00,$F8,$F8,$F8,$F8,$F8,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$E8,$E8,$E8,$E8		; standard bounce heights
	db $00,$00,$00,$00,$FE,$FC,$F8,$EC,$EC,$EC,$E8,$E4,$E0,$DC,$D8,$D4,$D0,$CC,$C8		; goomba bounce heights

DoBounce:
	LDA $B6,X					; halve the sprite's x speed
	PHP
	BPL ?+
	EOR #$FF
	INC A
	?+
	LSR
	PLP
	BPL ?+
	EOR #$FF
	INC A
	?+
	STA $B6,X
	
	LDA $AA,X					; load the sprite's y speed and divide it by 4
	LSR #2
	
	LDY $1662,X					; if $1662,X (tweaker byte, set in CFG Editor) is set to 11 (goomba)...
	CPY #$11
	BNE ?+
	CLC : ADC #$13				; add #$13
	?+
	
	TAY
	LDA BounceXSpeed,Y
	STA $AA,X
	RTS