; rotating death skull
; the first extension byte sets the speed
; the second extension byte sets the radius
; the third extension byte sets the movement type (the second digit is the number of skulls):
;	00-07	=	circle
;	10-17	=	horizontal wave
;	20-27	=	vertical wave
;	80-87	=	circles around other sprite (place the death skull ring 1 tile to the right of the sprite to center around)

;	$C2,X		=	loop index offset
;	$1528,X		=	angle (low byte)
;	$1534,X		=	angle (high byte)
;	$157C,X		=	OAM index offset
;	$160E,X		=	sprite slot of the sprite to turn around
;	$187B,X		=	number of OAM tiles to draw

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
	STA $1528,X
	XBA
	STA $1534,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA $7FAB58,X				; if the sprite is set to move around another sprite...
	AND #%10000000
	BEQ +
	JSR CheckCenterSprite
	+
	
	%RaiseSprite1Pixel()
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


CheckCenterSprite:
	LDY #$09					; load highest sprite slot for loop

.loopstart
	STY $00						; if the index is the same as the death skull ring ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $D8,Y					; if the death skull ring was placed at the same x/y position as the indexed sprite...
	INC							; (account for floating indexed sprites that had their y position corrected by 1 pixel)
	AND #%11110000
	CMP $D8,X
	BNE .loopcontinue
	LDA $14D4,Y
	CMP $14D4,X
	BNE .loopcontinue
	LDA $E4,Y
	CMP $E4,X
	BNE .loopcontinue
	LDA $14E0,Y
	CMP $14E0,X
	BNE .loopcontinue
	
	TYA							; store the indexed sprite's slot
	STA $160E,X
	BRA .return

.loopcontinue					; else, check the next sprite
	DEY
	BPL .loopstart
	
	LDA #$FF					; if no center sprite was found at the right position, store its sprite slot as #$FF
	STA $160E,X

.return
	RTS


SpriteCode:
	STZ $157C,X					; set the OAM index offset to 0
	
	LDA $9D						; if the game is frozen, don't change the angle
	BNE .skipchangeangle
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $7FAB58,X				; if the sprite is set to move around another (center) sprite...
	AND #%10000000
	BEQ .skipcentersprite
	LDA $160E,X					; and the center sprite's slot is not set to #$FF...
	BMI .skipcentersprite
	
	TAY							; set the sprite slot of the center sprite as an index
	
	LDA $14C8,Y					; if the center sprite is dead...
	BNE +
	LDA #$FF					; store the center sprite slot as #$FF
	STA $160E,X
	BRA .skipcentersprite
	+
	
	LDA $E4,Y					; else, copy the other sprite's x/y position to that of the death skull ring
	STA $E4,X
	LDA $14E0,Y
	STA $14E0,X
	LDA $D8,Y
	STA $D8,X
	LDA $14D4,Y
	STA $14D4,X

.skipcentersprite
	STZ $01						; make the speed value 16-bit and store it to scratch ram
	LDA $7FAB40,X
	STA $00
	BPL +
	DEC $01
	+
	
	LDA $1534,X					; load the angle
	XBA
	LDA $1528,X
	REP #$20
	SEC : SBC $00				; subtract the speed value
	SEP #$20
	STA $1528,X					; store the angle
	XBA
	STA $1534,X

.skipchangeangle
	JSR HandleRotation
	
	LDA $187B,X					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


LoopIndexOffset:
	db $00,$01,$03,$06,$0A,$0F,$15,$1C,$24

HandleRotation:
	LDA $7FAB58,X				; load the loop index offset based on the rotation type (= number of skulls)
	AND #%00000111
	PHA
	TAY
	LDA LoopIndexOffset,Y
	STA $C2,X
	PLA
	JSR HandleCircleSkulls
	RTS


AngleOffsets:
	dw $0000
	dw $0000,$0100
	dw $0000,$00AA,$0155
	dw $0000,$0080,$0100,$0180
	dw $0000,$0066,$00CD,$0133,$019A
	dw $0000,$0055,$00AB,$0100,$0155,$01AB
	dw $0000,$0049,$0092,$00DB,$0125,$016E,$01B7
	dw $0000,$0040,$0080,$00C0,$0100,$0140,$0180,$01C0

HandleCircleSkulls:
	STA $187B,X					; set the number of OAM tiles to draw based on the rotation type
	TAY

.loopskulls
	PHY
	TYA							; load the loop index
	CLC : ADC $C2,X				; add the loop index offset
	ASL							; multiply it
	TAY
	REP #$20
	LDA AngleOffsets,Y			; load the angle offset based on the loop index
	STA $0A
	SEP #$20
	JSR CircleSkull
	PLY
	
	DEY							; decrement the loop index and loop if still positive
	BPL .loopskulls
	RTS


CircleSkull:
	LDA $E4,X	: PHA			; store the sprite position (center of rotation) to the stack
	LDA $14E0,X	: PHA
	LDA $D8,X	: PHA
	LDA $14D4,X	: PHA
	
	LDA $7FAB4C,X				; store the radius to scratch ram
	STA $04
	
	LDA $7FAB58,X				; if the sprite is set to move horizontally...
	AND #%00100000
	BNE +
	
	LDA $1534,X					; load the angle
	XBA
	LDA $1528,X
	REP #$20					; add the x angle offset to the angle and store it to scratch ram
	CLC : ADC $0A
	STA $08
	SEP #$20
	
	JSR ApplyAnglePos
	CLC : ADC $E4,X				; add the offset to the sprite's x position
	STA $E4,X
	LDA $14E0,X
	ADC $06
	STA $14E0,X
	+
	
	LDA $7FAB58,X				; if the sprite is set to move vertically...
	AND #%00010000
	BNE +
	
	LDA $1534,X					; load the angle
	XBA
	LDA $1528,X
	REP #$20					; add the y angle offset to the angle and store it to scratch ram
	CLC : ADC $0A
	ADC #$0080
	STA $08
	SEP #$20
	
	JSR ApplyAnglePos
	CLC : ADC $D8,X
	STA $D8,X
	LDA $14D4,X
	ADC $06
	STA $14D4,X
	+
	
	JSR HandleMarioContact
	JSR Graphics
	
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
;	JSR DoNothing
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
	
	LDA $1490					; if Mario has star power, don't interact with the sprite
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	%HandleHurtMario()
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	TYA							; add the OAM index offset to the OAM index
	CLC : ADC $157C,X
	TAY
	
	LDA $157C,X					; raise the OAM index offset by 4
	CLC : ADC #$04
	STA $157C,X
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$CE					; tile ID
	STA $0302,Y
	
	LDA #%00101100				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	RTS