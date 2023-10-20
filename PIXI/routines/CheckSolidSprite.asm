; check from a table whether a sprite (indexed in Y) is solid for other sprites

	PHB
	PHK
	PLB
	JSR DoCheck
	PLB
	CMP #$00
	RTL


SolidSpriteList:
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 54 = polarity block, 55 = arrow block
	db $01,$01,$01,$01,$01,$00,$01,$00,$01,$00,$01,$00,$00,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = on/off block, 66 = used block, 68 = eating block, 6A = walking block
	db $01,$01,$01,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 78 = sticky block

DoCheck:
	PHX							; load the 'solid sprite' flag based on the sprite ID
	TYX
	LDA $7FAB9E,X
	TAX
	LDA SolidSpriteList,X
	PLX
	RTS