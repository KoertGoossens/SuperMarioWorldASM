; routine to get the Map16 value at specified x/y coordinates
;	input:		$98		=	block position y (16-bit)
;				$9A		=	block position x (16-bit)
;				$1933   =	layer (0 = layer 1, 1 = layer 2)
;	output:		A		=	Map16 value (2 bytes, use 16-bit A)


	PHX
	PHP
	REP #$10
	PHB
	LDY $98
	STY $0E
	LDY $9A
	STY $0C
	SEP #$30
	LDA $5B
	LDX $1933
	BEQ .layer1
	LSR A
.layer1
	STA $0A
	LSR A
	BCC .horz
	LDA $9B
	LDY $99
	STY $9B
	STA $99
.horz
.verticalCheck
	LDA $99
	CMP #$02
.check
	BCC .noEnd
	REP #$20		; \ load return value for call in 16bit mode
	LDA #$FFFF		; /
	PLB
	PLP
	PLX
	TAY				; load high byte of return value for 8bit mode and fix N and Z flags
	RTL
	
.noEnd
	LDA $9B
	STA $0B
	ASL A
	ADC $0B
	TAY
	REP #$20
	LDA $98
	AND.w #$FFF0
	STA $08
	AND.w #$00F0
	ASL #2			; 0000 00YY YY00 0000
	XBA				; YY00 0000 0000 00YY
	STA $06
	TXA
	SEP #$20
	ASL A
	TAX
	
	LDA $0D
	LSR A
	LDA $0F
	AND #$01		; 0000 000y
	ROL A			; 0000 00yx
	ASL #2			; 0000 yx00
	ORA #$20		; 0010 yx00
	CPX #$00
	BEQ .noAdd
	ORA #$10		; 001l yx00
.noAdd
	TSB $06			; $06 : 001l yxYY
	LDA $9A			; X LowByte
	AND #$F0		; XXXX 0000
	LSR #3			; 000X XXX0
	TSB $07			; $07 : YY0X XXX0
	LSR A
	TSB $08

	LDA $1925
	ASL A
	REP #$31
	ADC $00BEA8,x
	TAX
	TYA
	
    ADC $00,x
    TAX
    LDA $08
    ADC $00,x
	
	TAX
	SEP #$20
	
	LDA $7F0000,x
	XBA
	LDA $7E0000,x
	
	SEP #$30
	XBA
	TAY
	XBA

	PLB
	PLP
	PLX
	RTL