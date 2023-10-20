; rotating platform
; the first extension byte sets the speed
; the second extension byte sets the radius (number of ring segments)
; the third extension byte sets the trigger type (0 = don't change direction, 1 = change direction based on on/off state)

;	$1504,X		=	angle (low byte)
;	$151C,X		=	angle (high byte)
;	$1528,X		=	how many pixels the sprite has moved horizontally per frame
;	$1534,X		=	stored x position (low byte)
;	$1570,X		=	stored x position (high byte)
;	$157C,X		=	OAM index offset
;	$1594,X		=	stored y position (low byte)
;	$160E,X		=	stored y position (high byte)

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
	JSR CirclePlatform
	
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


CirclePlatform:
	LDA $E4,X	: PHA			; store the sprite position (center of rotation) to the stack twice
	LDA $14E0,X	: PHA
	LDA $D8,X	: PHA
	LDA $14D4,X	: PHA
	LDA $E4,X	: PHA
	LDA $14E0,X	: PHA
	LDA $D8,X	: PHA
	LDA $14D4,X	: PHA
	
	LDA $1534,X					; load the sprite position from scratch ram for gfx (= position of the platform segment, previous frame)
	STA $E4,X
	LDA $1570,X
	STA $14E0,X
	LDA $1594,X
	STA $D8,X
	LDA $160E,X
	STA $14D4,X
	
	JSR Graphics_Platform
	
	%CheckSpriteMarioContact()	; set a flag to scratch ram based on whether Mario is interacting with the platform
	STZ $0F
	BCC +
	INC $0F
	+
	
	PLA : STA $14D4,X			; load the original sprite position (center of rotation) from the stack
	PLA : STA $D8,X
	PLA : STA $14E0,X
	PLA : STA $E4,X
	
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
	
	LDA $1534,X					; store the sprite's x position (previous frame) to scratch ram
	STA $00
	LDA $1570,X
	STA $01
	
	LDA $14E0,X					; store the number of pixels the sprite moved horizontally
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC $00
	SEP #$20
	STA $1528,X
	
	LDA $E4,X					; store the sprite's current position
	STA $1534,X
	LDA $14E0,X
	STA $1570,X
	LDA $D8,X
	STA $1594,X
	LDA $14D4,X
	STA $160E,X
	
	LDA $0F						; if Mario interacts with the platform, handle putting him on top
	BEQ +
	JSR MarioContact_OnPlatform
	+
	
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
	
	STZ $0F						; make the speed value 16-bit and store it to scratch ram
	LDA $7FAB40,X
	STA $0E
	BPL +
	DEC $0F
	+
	
	LDA $151C,X					; load the angle
	XBA
	LDA $1504,X
	REP #$20
	ADC $0E						; add one speed value
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
	CLC : ADC $0E				; add one speed value
	ADC #$0080					; add a quarter of a circle
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


MarioContact_OnPlatform:
	LDA $7D						; return if Mario is moving up
	BMI .return
	
	LDA $14D4,X					; if Mario's y is at least 24 pixels above the sprite's y, set him on top of it
	XBA
	LDA $D8,X
	REP #$20
	STA $02						; also store the sprite's y to scratch RAM
	SEC : SBC $96
	SBC #$0018
	BMI .return
	SEP #$20

.setontop
	LDA #$03					; set Mario's y speed to #$03
	STA $7D
	
	LDA #$01					; set Mario as standing on a solid sprite
	STA $1471
	
	REP #$20
	LDA $02						; set Mario's y to be the sprite's y minus 31 pixels
	SEC : SBC #$001F
	LDY $187A					; subtract another 16 pixels if Mario is on Yoshi
	BEQ +
	SBC #$0010
	+
	STA $96
	SEP #$20
	
	LDA $1528,X					; store the 'number of pixels the sprite has moved horizontally' to scratch ram
	STA $04
	STZ $05						; add the high byte (set to #$00 or #$FF)
	BPL +
	LDA #$FF
	STA $05
	+
	
	REP #$20
	LDA $94						; move Mario along with the platform when on top of it
	CLC : ADC $04
	STA $94

.return
	SEP #$20
	RTS


Graphics_Platform:
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
	
	LDA #$CC					; tile ID
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