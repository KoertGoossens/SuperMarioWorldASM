; this code handles interaction with Mario for custom semi-solid sprites


	LDA $7D						; return if Mario is moving up
	BMI .doreturn
	
	LDA $14D4,X					; if Mario's y is at least 24 pixels above the sprite's y, set him on top of it
	XBA
	LDA $D8,X
	REP #$20
	STA $02						; also store the sprite's y to scratch RAM
	SEC : SBC $96
	SBC #$0018
	BMI .doreturn
	SEP #$20
	
	LDA $AA,X					; if the sprite is moving down...
	BMI ?+
	LDA $7D						; return if Mario is moving up
	BMI .doreturn
	BRA .setontop
	?+
	SEC : SBC $7D				; else, return only if Mario is moving up faster than the sprite is (to prevent Mario from clipping through)
	BPL .doreturn

.setontop
	LDA $AA,X					; give Mario the y speed of the sprite
	CMP #$10					; if it's below #$10, set it to #$10
	BPL ?+
	LDA #$10
	?+				
	STA $7D
	
	LDA #$01					; set Mario as standing on a solid sprite
	STA $1471
	
	REP #$20
	LDA $02						; set Mario's y to be the sprite's y minus 31 pixels
	SEC : SBC #$001F
	LDY $187A					; subtract another 16 pixels if Mario is on Yoshi
	BEQ ?+
	SBC #$0010
	?+
	STA $96
	SEP #$20
	
	LDA $1528,X					; store the 'number of pixels the sprite has moved' to scratch ram
	STA $04
	STZ $05						; add the high byte (set to #$00 or #$FF)
	BPL ?+
	LDA #$FF
	STA $05
	?+
	
	REP #$20
	LDA $94						; move Mario along with the block when on top of it
	CLC : ADC $04
	STA $94

.return_notonplatform
	SEC
	SEP #$20
	RTL

.doreturn
	CLC
	SEP #$20
	RTL