	PHB
	PHK
	PLB
	JSR DoPushSideItem
	PLB
	RTL


DoPushSideItem:
	STZ $7B						; set Mario's x speed to 0
	%SubHorzPos()				; push Mario to the side based on his x position relative to the item
	TYA
	ASL
	TAY
	REP #$20
	LDA $94
	CLC : ADC MarioPushXSpeed,Y
	STA $94
	SEP #$20
	RTS

MarioPushXSpeed:
	dw $0001,$FFFF