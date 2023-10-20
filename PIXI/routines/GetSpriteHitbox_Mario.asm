; store the parameters of the sprite's hitbox for interaction with Mario to scratch ram:
;	$04 - x offset (low byte)
;	$05 - y offset (low byte)
;	$06 - width
;	$07 - height
;	$0A - x offset (high byte)
;	$0B - y offset (high byte)

	JSR GetSpriteHitbox
	RTL


GetSpriteHitbox:
	STZ $0F						;$03B6A8	|
	LDA $7FB600,X
	BPL ?+						;$03B6AE	|
	DEC $0F						;$03B6B0	|
	?+
	CLC : ADC.w $00E4,X			;$03B6B3	|
	STA $04						;$03B6B6	|
	LDA.w $14E0,X				;$03B6B8	|
	ADC $0F						;$03B6BB	|
	STA $0A						;$03B6BD	|
	LDA $7FB618,X
	STA $06						;$03B6C3	|
	STZ $0F						;$03B6C5	|
	LDA $7FB60C,X
	BPL ?+						;$03B6CB	|
	DEC $0F						;$03B6CD	|
	?+
	CLC : ADC.w $00D8,X			;$03B6D0	|
	STA $05						;$03B6D3	|
	LDA.w $14D4,X				;$03B6D5	|
	ADC $0F						;$03B6D8	|
	STA $0B						;$03B6DA	|
	LDA $7FB624,X
	STA $07						;$03B6E0	|
	RTS