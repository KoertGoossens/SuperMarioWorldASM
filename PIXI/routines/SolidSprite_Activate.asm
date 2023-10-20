; routine to activate an activatable solid sprite

	PHB
	PHK
	PLB
	JSR DoActivate
	PLB
	RTL


ItemBlockSpriteList:
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $01,$00,$00,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 60 = solid block, 63 = item block, 64 = on/off block
	db $00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 73 = big item block

DoActivate:
	PHX								; load the 'item block sprite' flag based on the sprite ID
	TYX
	LDA $7FAB9E,X
	TAX
	LDA ItemBlockSpriteList,X
	BEQ ?+							; if the sprite is an item block sprite...
	
	LDA $1558,Y						; and its activation timer is 0...
	BNE ?+
	
	LDA #$09						; set the block sprite's activation timer
	STA $1558,Y
	?+
	
	PLX
	RTS