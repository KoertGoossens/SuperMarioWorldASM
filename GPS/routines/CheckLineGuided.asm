; check from a table whether a sprite is line-guided
; use only with custom sprites

	PHB
	PHK
	PLB
	JSR DoCheckLineGuided
	PLB
	RTL


LineGuidedSprites:
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00		; 2C = rope
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 40 = spike wheel
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = on/off block, 65 = cloud
	db $01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 73 = big item block

DoCheckLineGuided:
	LDA $7FAB9E,X					; check the line-guided flag based on the sprite ID and store it to scratch ram
	PHY
	TAY
	LDA LineGuidedSprites,Y
	PLY
	STA $00
	RTS