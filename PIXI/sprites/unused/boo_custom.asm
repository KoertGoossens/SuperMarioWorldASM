; this boo sprite is faster than a vanilla boo and can chase Mario around and/or turn into a block boo depending on the extension byte
; bits 7 and 8 of the extension byte determine the chasing behavior:
;	00	=	stationary
;	01	=	always chasing
;	02	=	chasing when Mario is not facing it
;	03	=	chasing when Mario is facing it
; bits 5 and 6 of the extension byte determine the block behavior:
;	00	=	no block (stationary)
;	04	=	always block (stationary)
;	08	=	block when Mario is not facing it (stationary)
;	0C	=	block when Mario is facing it (stationary)
; sprite-indexed addresses (custom uses):
;	$C2,X		=	phase (0 = decelerating; 1 = accelerating)

print "INIT ",pc
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL


XSpeedMax:
	db $18,$E8
YSpeedMax:
	db $18,$E8

AccelTable:
	db $01,$FF

Return:
	RTS

SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE Return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE Return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSL $01A7DC					; handle interaction between Mario and the sprite

.HandleXSpeed
	LDY #$00
	LDA $E4,X					; subtract the boo's x position from Mario's x position
	STA $00
	LDA $14E0,X
	STA $01
	REP #$20
	LDA $94
	SEC : SBC $00
	BPL +						; if positive, set Y to 1
	INY
	+
	SEP #$20
	
	STZ $C2,X					; set the phase to 0 (decelerating) by default
	TYA							; set the boo's face direction to always face Mario
	STA $157C,X
	
	LDA $7FAB40,X				; if the boo is set to be stationary, don't update the speeds
	AND #%00000011
	BEQ Return
	CMP #$01					; else if the boo is set to always chase, accelerate it
	BEQ .AccelerateX
	CMP #$02					; else if the boo is set to chase when Mario is not facing it...
	BNE +
	LDA $157C,X					; if the boo is facing Mario, decelerate it; otherwise accelerate it
	CMP $76
	BEQ .DecelerateX
	BRA .AccelerateX
	+
	LDA $157C,X					; else (the boo is set to chase when Mario is facing it...), ; if the boo is facing Mario, accelerate it; otherwise decelerate it
	CMP $76
	BEQ .AccelerateX
	BRA .DecelerateX

.AccelerateX
	INC $C2,X					; set the phase to 1 (accelerating)
	LDA $B6,X					; if the boo's x speed has not yet reached max speed, increase/decrease it (based on the face direction)
	CMP XSpeedMax,Y
	BEQ +
	CLC : ADC AccelTable,Y
	+
	BRA .HandleYSpeed

.DecelerateX
	LDA $B6,X					; if the boo's x speed is not 0...
	BEQ +
	BMI ++						; if it's positive, decrease it
	CLC : ADC #$FF
	BRA +
	++
	CLC : ADC #$01				; else, increase it
	+

.HandleYSpeed
	STA $B6,X					; store x speed
	LDY #$00
	LDA $D8,X					; subtract the boo's y position from Mario's y position
	STA $00
	LDA $14D4,X
	STA $01
	REP #$20
	LDA $96
	CLC : ADC #$0010
	SEC : SBC $00
	BPL +						; if positive, set Y to 1
	INY
	+
	SEP #$20
	
	LDA $C2,X					; if the phase is 0, decelerate it; else, accelerate it
	BEQ .DecelerateY

.AccelerateY
	LDA $AA,X					; if the boo's x speed has not yet reached max speed, increase/decrease it (based on the face direction)
	CMP YSpeedMax,Y
	BEQ +
	CLC : ADC AccelTable,Y
	+
	BRA .UpdateSpeeds

.DecelerateY
	LDA $AA,X					; if the boo's x speed is not 0...
	BEQ +
	BMI ++						; if it's positive, decrease it
	CLC : ADC #$FF
	BRA +
	++
	CLC : ADC #$01				; else, increase it
	+

.UpdateSpeeds
	STA $AA,X					; store y speed
	JSL $018022					; update sprite's x position (no gravity)
	JSL $01801A					; update sprite's y position (no gravity)
	RTS


Tilemap:
	db $8C,$88

Graphics:
	%GetDrawInfo()				; get sprite coordinates within the screen and OAM index
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDY $C2,X					; store the tile ID based on the sprite's phase
	LDA Tilemap,Y
	PLY
	STA $0302,Y
	
	LDA $157C,X					; if the sprite is facing right (store bit in the carry flag)...
	LSR
	LDA $15F6,X					; x-flip the tile
	BCS +
	EOR #%01000000
	+
	ORA $64						; tile YXPPCCCT properties
	STA $0303,Y
	
	TYA
	LSR #2
	TAY
	
	LDA #$02					; set the tile size (#$02 = 16x16)
	ORA $15A0,X
	STA $0460,Y
	
	PHK
	PER $0006
	PEA $8020
	JML $01A3DF					; set up some stuff in OAM
	
	RTS