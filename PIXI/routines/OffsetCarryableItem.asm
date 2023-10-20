	PHB
	PHK
	PLB
	JSR OffsetItem
	PLB
	RTL


CarriedXOffset:
	dw $000B,$FFF5,$0004,$FFFC,$0004,$0000

OffsetItem:
	LDA $13E7					; if Mario is climbing...
	ORA $1908					; or inside a boost bubble...
	BEQ +
	LDY #$05					; set the index to 5 (center item in front of Mario)
	BRA .indexstored
	+
	
	LDA $1419					; else, if going down a vertical pipe...
	CMP #$02
	BNE +
	LDY #$05					; set the index to 5 (center item in front of Mario)
	BRA .indexstored
	+
	
	LDA $76						; else, set the index to 0 or 1 based on Mario's face direction (inverted)
	EOR #$01
	TAY
	
	LDA $140D					; if Mario is not spinning...
	BNE +
	LDA $1499					; and Mario's turning timer is set...
	BEQ +
	INY #2						; increase the index by 2 (first part of the turning animation) or 3 (second part of the turning animation)
	CMP #$05
	BCC +
	INY
	+

.indexstored
	TYA							; multiply the index by 2
	ASL
	TAY
	PHY
	LDY #$00					; load a position index based on whether Mario is standing on a platform sprite that checks for Mario's position on the current frame
	LDA $1471
	CMP #$03
	BEQ +
	LDY #$3D
	+
	LDA $94,Y					; store Mario's position to scratch ram
	STA $00
	LDA $95,Y
	STA $01
	LDA $96,Y
	STA $02
	LDA $97,Y
	STA $03
	PLY
	
	REP #$20					; offset the item horizontally from Mario based on the stored index
	LDA $00
	CLC : ADC CarriedXOffset,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA #$0D					; if Mario is small or ducking, offset the item vertically by #$0F, otherwise offset it by #$0D
	LDY $73
	BNE +
	LDY $19
	BNE ++
	+
	LDA #$0F
	++
	
	LDY $1498					; if Mario is picking up the item, offset it vertically by #$0F
	BEQ +
	LDA #$0F
	+
	
	STA $04						; store the offset to scratch ram
	STZ $05
	
	REP #$20					; offset the item vertically from Mario based on the scratch ram value
	LDA $02
	CLC : ADC $04
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA #$01					; set the 'carrying something' flags
	STA $148F
	STA $1470
	RTS