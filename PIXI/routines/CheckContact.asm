; check for contact between Mario and a sprite, or between two sprites

	JSR CheckForContact
	RTL


;	entity 1 hitbox values:
;		$00 - x offset (low byte)
;		$01 - y offset (low byte)
;		$02 - width
;		$03 - height
;		$08 - x offset (high byte)
;		$09 - y offset (high byte)

;	entity 2 hitbox values:
;		$04 - x offset (low byte)
;		$05 - y offset (low byte)
;		$06 - width
;		$07 - height
;		$0A - x offset (high byte)
;		$0B - y offset (high byte)

CheckForContact:
	LDA $00						; return (carry clear) if not on the same screen horizontally
	SEC : SBC $04
	PHA
	LDA $08
	SBC $0A
	STA $0C
	PLA
	CLC : ADC #$80
	LDA $0C
	ADC #$00
	BNE .return_nocontact
	
	LDA $04						; return (carry clear) if not touching horizontally
	SEC : SBC $00
	CLC : ADC $06
	STA $0F
	LDA $02
	CLC : ADC $06
	CMP $0F
	BCC .return_nocontact
	
	LDA $01						; return (carry clear) if not on the same screen vertically
	SEC : SBC $05
	PHA
	LDA $09
	SBC $0B
	STA $0C
	PLA
	CLC : ADC #$80
	LDA $0C
	ADC #$00
	BNE .return_nocontact
	
	LDA $05						; return (carry clear) if not touching vertically
	SEC : SBC $01
	CLC : ADC $07
	STA $0F
	LDA $03
	CLC : ADC $07
	CMP $0F
	BCC .return_nocontact		; return with the carry flag set if in contact, or clear if not in contact

.return_contact
	SEC
	RTS

.return_nocontact
	CLC
	RTS