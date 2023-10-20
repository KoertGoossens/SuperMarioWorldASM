; this subroutine checks for contact between a sprite with a custom hitbox and Mario
;	input:		$7FB600,X	-	custom hitbox x (for interaction with Mario)
;				$7FB60C,X	-	custom hitbox y (for interaction with Mario)
;				$7FB618,X	-	custom hitbox width (for interaction with Mario)
;				$7FB624,X	-	custom hitbox height (for interaction with Mario)
;	output:		carry flag (set = in contact, clear = not in contact)

	PHB
	PHK
	PLB
	JSR CheckInteraction
	PLB
	RTL


CheckInteraction:
	LDA $15A0,X					; return if the sprite is horizontally offscreen
	BNE .return_nocontact
	
	LDA $71						; return if Mario is performing an animation
	BNE .return_nocontact
	
	LDA #$00					; return if Mario and the sprite are on different layers
	BIT $0D9B
	BVS ?+
	LDA $13F9
	EOR $1632,X
	?+
	BNE .return_nocontact
	
	JSR DoGetSpriteHitbox
	JSR GetMarioClipping		; store Mario's hitbox parameters to scratch ram
	JSR CheckForContact			; check if Mario is in contact with the sprite
	BCC .return_nocontact		; return with the carry flag set if in contact, or clear if not in contact

.return_contact
	SEC
	RTS

.return_nocontact
	CLC
	RTS


DoGetSpriteHitbox:
	%GetSpriteHitbox_Mario()
	RTS


CheckForContact:
	%CheckContact()
	RTS


; store the parameters of Mario's hitbox to scratch ram:
;	$00 - x offset (low byte)
;	$01 - y offset (low byte)
;	$02 - width
;	$03 - height
;	$08 - x offset (high byte)
;	$09 - y offset (high byte)

MarioHitboxYOffset:					; Mario's hitbox's y offset (big, small, big on Yoshi, small on Yoshi)
	db $06,$14,$10,$18
MarioHitboxHeight:
	db $1A,$0C,$20,$18

GetMarioClipping:
	PHX
	
	LDA $94							; set Mario's hitbox x offset (low byte) to 2 pixels
	CLC : ADC #$02
	STA $00
	
	LDA $95							; set Mario's hitbox x offset (high byte) to 0
	ADC #$00
	STA $08
	
	LDA #$0C						; set Mario's hitbox width to 12 pixels
	STA $02
	
	LDX #$00						; set the index for Mario's hitbox y/height to 0
	
	LDA $73							; if ducking, increase the index
	BNE .mariosmall
	LDA $19							; else, if Mario is small, increase the index
	BNE .indexloaded
.mariosmall
	INX
.indexloaded
	LDA $187A						; increase the index by 2 if Mario is on Yoshi
	BEQ ?+
	INX #2
	?+
	
	LDA $96							; set Mario's hitbox y offset (low byte) based on the index
	CLC : ADC MarioHitboxYOffset,X
	STA $01
	
	LDA $97							; set Mario's hitbox y offset (high byte) to 0
	ADC #$00
	STA $09
	
	LDA MarioHitboxHeight,X			; set Mario's hitbox height based on the index
	STA $03
	
	PLX
	RTS