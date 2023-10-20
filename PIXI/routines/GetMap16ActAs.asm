; routine to get the 'Act As' value (see Map16) of a tile at specified x/y coordinates
;	input:		$98		=	block position y (16-bit)
;				$9A		=	block position x (16-bit)
;				$1933   =	layer (0 = layer 1, 1 = layer 2)
;	output:		A		=	'Act As' value (2 bytes, use 16-bit A)


	%GetMap16()
	
    STA $00
	XBA
	-
	XBA
    LDA $00
    REP #$20
    ASL
    ADC.l $06F624
    STA $0D
    SEP #$20
    LDA.l $06F626
    STA $0F
    REP #$20
    LDA [$0D]
    SEP #$20
    STA $00
    XBA
    CMP #$02
    BCS -
    XBA
    LDA $00
	RTL