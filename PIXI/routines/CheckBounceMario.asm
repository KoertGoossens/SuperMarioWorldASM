; routine to check whether Mario should bounce off the top of a sprite or hit the side of it

	PHB
	PHK
	PLB
	JSR DoCheckBounceMario
	PLB
	RTL


HeightCheck:
	db $14,$28,$28

DoCheckBounceMario:
	LDA $7D						; if Mario is moving downward...
	BMI .nobounce
	
	PHY
	LDY $187A					; load index based on whether Mario is riding Yoshi
	LDA HeightCheck,Y			; if Mario is less than [indexed value] above the sprite, return with carry clear
	STA $01
	PLY
	
	LDA $05
	SEC : SBC $01
	ROL $00
	CMP $D3
	PHP
	LSR $00
	LDA $0B
	SBC.b #$00
	PLP
	SBC $D4
	BMI .nobounce
	
	LDA $1588,X					; if the sprite is on the ground...
	AND #%00000100
	BEQ ?+
	LDA $72						; and Mario is on the ground, branch to return with carry clear
	BEQ .nobounce
	?+
	
	SEC							; return with carry set
	RTS

.nobounce
	CLC
	RTS