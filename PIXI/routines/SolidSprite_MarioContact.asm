; this routine handles interaction with Mario for solid block sprites

	PHB
	PHK
	PLB
	JSR DoHandleContact
	PLB
	RTL

DoHandleContact:
	STZ $1504,X					; set the block interaction flag to 0
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCS MarioContact
	RTS


CeilingOffset:							; small, big, small on Yoshi, big on Yoshi
	dw $0000,$0008,$FFFC,$0000

MarioContact:
	LDA $E4,X					; store the sprite's x to scratch ram
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $1534,X					; store the sprite's width to scratch ram
	STA $08
	STZ $09
	LDA $1570,X					; store the sprite's height to scratch ram
	STA $0A
	STZ $0B
	
	LDA #$18					; load a base y offset of 24 pixels to set Mario above the block sprite
	LDY $187A					; add another 10 pixels if Mario is on Yoshi
	BEQ ?+
	CLC : ADC #$10
	?+
	STA $0E						; store the offset to scratch ram
	STZ $0F
	
	LDA $14D4,X					; if Mario's y is at least [offset] above the sprite's y, set him on top of it; otherwise, check for the ceiling
	XBA
	LDA $D8,X
	REP #$20
	STA $02						; also store the sprite's y to scratch ram
	SEC : SBC $96
	SBC $0E
	BMI .checkceiling
	SEP #$20
	
	LDA $AA,X					; if the sprite is moving down...
	BMI ?+
	LDA $7D						; return if Mario is moving up
	BMI .return1
	BRA .checkxpos
	?+
	SEC : SBC $7D				; else, return only if Mario is moving up faster than the sprite is (to prevent Mario from clipping through)
	BPL .return1

.checkxpos
	REP #$20
	LDA $00						; if Mario is at least 12 pixels left of the sprite or more than 12 pixels + [width offset] right of it, drop him off the side; otherwise, set him on top of the sprite
	SEC : SBC $94				; (behavior like with a solid layer 1 tile)
	SBC #$000C
	BPL .return1
	CLC : ADC #$0018
	ADC $08
	BMI .return1
	SEP #$20

; set Mario on top of the sprite
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
	
	INC $1504,X					; set the block interaction flag to 1
	
	LDA $1662,X					; if $1662,X (tweaker byte) is set to #$3C...
	CMP #$3C
	BNE .return1
	
	REP #$20
	LDA $94						; move Mario along with the block when on top of it
	CLC : ADC $04
	STA $94

.return1
	SEP #$20
	RTS

.checkceiling
	SEP #$20
	LDY #$00					; load an index of 0
	
	LDA $19						; if Mario is big, increment the index
	BEQ ?+
	LDA $73
	BNE ?+
	INY
	?+
	
	LDA $187A					; if Mario is on Yoshi, increment the index
	BEQ ?+
	INY #2
	?+
	
	TYA							; multiply the index by 2
	ASL
	TAY
	
	REP #$20
	
	LDA $02						; load the block sprite's y
	SEC : SBC $96				; subtract Mario's y
	CLC : ADC $0A				; add the block sprite's height offset
	ADC CeilingOffset,Y			; add Mario's height offset
	BMI .return1				; if negative (Mario is too low), don't interact with the block
	
	LDA $02						; load the block sprite's y
	SEC : SBC $0A				; subtract the block sprite's height offset
	SBC $96						; subtract Mario's y
	SBC #$0008
	BPL .pushfromside			; if positive (Mario is too high), push Mario from the side
	
	LDA $00						; else, if Mario is at least 9 pixels left of the sprite or more than 9 pixels [+ width offset] right of it, push him from the side
	SEC : SBC $94
	SBC #$0009
	BPL .pushfromside
	CLC : ADC #$0012
	ADC $08
	BMI .pushfromside
	
	SEP #$20
	
	LDA $7D						; return if Mario is not moving upward, otherwise make him bonk against the underside of the sprite
	BPL .return1

; bonk Mario against the bottom of the sprite
	REP #$20
	LDA $02						; set Mario's y to be the sprite's y...
	CLC : ADC $0A				; + the block sprite's height offset
	ADC CeilingOffset,Y			; + Mario's height offset
	STA $96
	SEP #$20
	
	STZ $7D						; set Mario's y speed to 0 when hitting the sprite on the bottom
	LDA #$01					; play hit sfx
	STA $1DF9
	
	LDA #$02					; set the block interaction flag to 2
	STA $1504,X
	RTS

.pushfromside
	SEP #$20
	%SubHorzPos()				; check horizontal proximity of Mario to sprite and return side in Y (0 = right, 1 = left)
	
	LDA $14E0,X					; take the sprite's x + x offset (based on Mario's relative x direction to the sprite) and store it to Mario's x position
	XBA
	LDA $E4,X
	REP #$20
	
	CPY #$00
	BNE ?+
	CLC : ADC #$000E			; (vanilla flying block = $000E)
	ADC $08
	BRA .pushxoffsetloaded
	?+
	CLC : ADC #$FFF2			; (vanilla flying block = $FFF1)

.pushxoffsetloaded
	STA $94
	SEP #$20
	
	TYA							; set the block interaction flag to 3 or 4, depending on the side of the block Mario is on
	CLC : ADC #$03
	STA $1504,X
	
	CPY #$00					; if Mario is moving right while the sprite is to the left of him...
	BEQ ?+
	LDA $7B
	BPL .nullmarioxspeed
	BRA .return2
	?+
	
	LDA $7B						; or Mario is moving left while the sprite is to the right of him...
	BPL .return2

.nullmarioxspeed
	STZ $7B						; set Mario's x speed to 0
	RTS

.return2
	SEP #$20
	RTS