; rotating spike
; the first extension byte sets the speed
; the second extension byte sets the radius (number of ring segments)
; the third extension byte sets the trigger type (0 = don't change direction, 1 = change direction based on on/off state)

;	$1504,X		=	angle (low byte)
;	$151C,X		=	angle (high byte)
;	$157C,X		=	OAM index offset

!initangle		=	#$0000


print "INIT ",pc
	PHB
	PHK
	PLB
	JSR InitCode
	PLB
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL


InitCode:
	REP #$20					; store the initial angle
	LDA !initangle
	SEP #$20
	STA $1504,X
	XBA
	STA $151C,X
	
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$0D : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$14 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	%RaiseSprite1Pixel()
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	STZ $157C,X					; set the OAM index offset to 0
	
	LDA $9D						; return if the game is frozen
	BNE .skipchangeangle
	
	%SubOffScreen()				; call offscreen despawning routine
	
	STZ $01						; make the speed value 16-bit and store it to scratch ram
	LDA $7FAB40,X
	STA $00
	BPL +
	DEC $01
	+
	
	LDA $151C,X					; load the angle
	XBA
	LDA $1504,X
	REP #$20
	SEC : SBC $00				; subtract the speed value
	SEP #$20
	STA $1504,X					; store the angle
	XBA
	STA $151C,X

.skipchangeangle
	JSR HandleRotation
	
	LDA $7FAB4C,X				; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


HandleRotation:
	JSR CircleSpike
	
	LDA $7FAB4C,X				; load the radius - 1 as an index
	TAY
	DEY

.looprings						; loop to handle ring segments
	PHY
	JSR CircleRing
	PLY
	DEY
	BPL .looprings
	RTS


CircleSpike:
	LDA $E4,X	: PHA			; store the sprite position (center of rotation) to the stack twice
	LDA $14E0,X	: PHA
	LDA $D8,X	: PHA
	LDA $14D4,X	: PHA
	
	LDA $7FAB4C,X				; store the radius x16 to scratch ram
	ASL #4
	STA $04
	
	LDA $151C,X					; load the angle
	XBA
	LDA $1504,X
	REP #$20
	STA $08						; store it to scratch ram
	SEP #$20
	
	JSR ApplyAnglePos
	CLC : ADC $E4,X				; add the offset to the sprite's x position
	STA $E4,X
	LDA $14E0,X
	ADC $06
	STA $14E0,X
	
	LDA $151C,X					; load the angle
	XBA
	LDA $1504,X
	REP #$20
	CLC : ADC #$0080			; add a quarter of a circle
	STA $08						; store it to scratch ram
	SEP #$20
	
	JSR ApplyAnglePos
	CLC : ADC $D8,X
	STA $D8,X
	LDA $14D4,X
	ADC $06
	STA $14D4,X
	
	JSR HandleMarioContact
	JSR Graphics_Spike
	
	PLA : STA $14D4,X			; load the original sprite position (center of rotation) from the stack
	PLA : STA $D8,X
	PLA : STA $14E0,X
	PLA : STA $E4,X
	RTS


CircleRing:
	LDA $E4,X	: PHA			; store the sprite position (center of rotation) to the stack
	LDA $14E0,X	: PHA
	LDA $D8,X	: PHA
	LDA $14D4,X	: PHA
	
	TYA							; store the ring's index x16 as its radius to scratch ram
	ASL #4
	STA $04
	
	LDA $151C,X					; load the angle
	XBA
	LDA $1504,X
	REP #$20
	STA $08						; store it to scratch ram
	SEP #$20
	
	JSR ApplyAnglePos
	CLC : ADC $E4,X				; add the offset to the sprite's x position
	STA $E4,X
	LDA $14E0,X
	ADC $06
	STA $14E0,X
	
	LDA $151C,X					; load the angle
	XBA
	LDA $1504,X
	REP #$20
	CLC : ADC #$0080			; add a quarter of a circle
	STA $08						; store it to scratch ram
	SEP #$20
	
	JSR ApplyAnglePos
	CLC : ADC $D8,X
	STA $D8,X
	LDA $14D4,X
	ADC $06
	STA $14D4,X
	
	JSR Graphics_Ring
	
	PLA : STA $14D4,X			; load the original sprite position (center of rotation) from the stack
	PLA : STA $D8,X
	PLA : STA $14E0,X
	PLA : STA $E4,X
	RTS


ApplyAnglePos:
	PHX
	REP #$30
	LDA $08						; get the cosine of the angle from a table and store it to scratch ram
	AND #$00FF
	ASL
	TAX
	LDA $07F7DB,X
	STA $02
	SEP #$30
	PLX
	
	LDA $02						; multiply the cosine with the radius to get the offset
	STA $4202
	LDA $04
	LDY $03
	BNE +
	STA $4203
	ASL $4216
	LDA $4217
	+
	LSR $09
	BCC +
	EOR #$FF
	INC A
	+
	STA $02
	
	STZ $06						; load the offset
	LDA $02
	BPL +
	DEC $06
	+
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $1490					; if Mario has star power, don't interact
	BNE .return
	
	LDA $154C,X					; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	%BounceMario()				; else, spin-bounce off the sprite
	
	LDA #$02					; play contact sfx
	STA $1DF9
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


Graphics_Spike:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	TYA							; add the OAM index offset to the OAM index
	CLC : ADC $157C,X
	TAY
	
	LDA $157C,X					; raise the OAM index offset by 4
	CLC : ADC #$04
	STA $157C,X
	
	LDA $00						; tile x offset
	STA $0300,Y
	LDA $01						; tile y offset
	STA $0301,Y
	
	LDA #$A2					; tile ID
	STA $0302,Y
	
	LDA #%00000010				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	RTS


Graphics_Ring:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	TYA							; add the OAM index offset to the OAM index
	CLC : ADC $157C,X
	TAY
	
	LDA $157C,X					; raise the OAM index offset by 4
	CLC : ADC #$04
	STA $157C,X
	
	LDA $00						; tile x offset
	STA $0300,Y
	LDA $01						; tile y offset
	STA $0301,Y
	
	LDA #$A2					; tile ID
	STA $0302,Y
	
	LDA #%00000010				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	RTS