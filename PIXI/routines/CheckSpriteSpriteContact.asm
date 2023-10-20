; this subroutine checks for contact between a sprite with a custom hitbox and another sprite
;	input:		$7FB630,X	-	custom hitbox x (for interaction with other sprites)
;				$7FB63C,X	-	custom hitbox y (for interaction with other sprites)
;				$7FB648,X	-	custom hitbox width (for interaction with other sprites)
;				$7FB654,X	-	custom hitbox height (for interaction with other sprites)
;	output:		carry flag (set = in contact, clear = not in contact)

	PHB
	PHK
	PLB
	JSR CheckInteraction
	PLB
	RTL


CheckInteraction:
	%GetSpriteHitbox_Sprite()				; store the calling sprite's hitbox parameters to scratch ram
	JSR GetIndexedSpriteClipping			; apply the custom clipping values for it (store the indexed sprite's hitbox parameters to scratch ram)
	%CheckContact()							; check if the two sprites are in contact
	BCC .return_nocontact					; return with the carry flag set if in contact, or clear if not in contact

.return_contact
	SEC
	RTS

.return_nocontact
	CLC
	RTS


; store the parameters of the indexed sprite's custom hitbox to scratch ram:
;	$00 - x offset (low byte)
;	$01 - y offset (low byte)
;	$02 - width
;	$03 - height
;	$08 - x offset (high byte)
;	$09 - y offset (high byte)

GetIndexedSpriteClipping:
	PHX
	TYX
	
	STZ $0F						;$03B6A8	|
	LDA $7FB630,X
	BPL +						;$03B6AE	|
	DEC $0F						;$03B6B0	|
	+
	CLC : ADC.w $00E4,X			;$03B6B3	|
	STA $00						;$03B6B6	|
	LDA.w $14E0,X				;$03B6B8	|
	ADC $0F						;$03B6BB	|
	STA $08						;$03B6BD	|
	LDA $7FB648,X
	STA $02						;$03B6C3	|
	STZ $0F						;$03B6C5	|
	LDA $7FB63C,X
	BPL +						;$03B6CB	|
	DEC $0F						;$03B6CD	|
	+
	CLC : ADC.w $00D8,X			;$03B6D0	|
	STA $01						;$03B6D3	|
	LDA.w $14D4,X				;$03B6D5	|
	ADC $0F						;$03B6D8	|
	STA $09						;$03B6DA	|
	LDA $7FB654,X
	STA $03						;$03B6E0	|
	
	PLX
	RTS