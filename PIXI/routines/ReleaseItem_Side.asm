	PHB
	PHK
	PLB
	JSR ReleaseItemSide
	PLB
	RTL


KickSpeedX:
	db $D2,$2E

ReleaseItemSide:
	LDA $13E7				; if climbing, throw the item left if holding left on the dpad, otherwise throw right
	BEQ ?+
	LDY #$01
	LDA $15
	BIT #$02
	BEQ .returnThrow
	LDY #$00
	BRA .returnThrow
	?+
	
	LDA $140D				; else if spinning or capespinning, throw the item into the direction you're holding or the direction Mario is moving
	ORA $14A6
	BNE .directionThrow
	
	LDA $1407				; else if flying, throw the item into Mario's face direction
	BNE .facedirThrow
	
	LDA $15					; else if right is pressed, go to .throwRight_nospin
	BIT #$01
	BEQ ?+
	LDY #$01
	BRA .returnThrow
	?+
	BIT #$02				; else if left is pressed, go to .throwLeft_nospin, else throw the item into Mario's face direction
	BEQ .facedirThrow
	LDY #$00
	BRA .returnThrow

.facedirThrow
	LDY $76					; throw the item into Mario's face direction
	BRA .returnThrow

.directionThrow
	LDA $15					; if right is pressed, throw right
	BIT #$01
	BNE .throwRight_spin
	BIT #$02				; else if left is pressed, throw left
	BNE .throwLeft_spin
	LDA $7B					; if positive or 0 x speed, go to .throwRight_spin, otherwise go to .throwLeft_spin
	BPL .throwRight_spin

.throwLeft_spin
	LDA $D2					; load Mario's x position, high byte
	XBA
	LDA $D1					; load Mario's x position, low byte
	REP #$20				; subtract 11 pixels
	SEC : SBC #$000B
	SEP #$20
	LDY #$00				; throw the item left
	JMP .storeSpritePos

.throwRight_spin
	LDA $D2					; load Mario's x position, high byte
	XBA
	LDA $D1					; load Mario's x position, low byte
	REP #$20				; add 11 pixels
	CLC : ADC #$000B
	SEP #$20
	LDY #$01				; throw the item right

.storeSpritePos
	STA $E4,X				; store to sprite's x position, low byte
	XBA
	STA $14E0,X				; store to sprite's x position, high byte
	BRA .returnThrow

.returnThrow
	JSL $01AB6F				; display 'hit' graphic at sprite's position
	
	LDA $1540,X				; copy the stun timer from $1540,X to $C2,X (mirror)
	STA $C2,X
	
	LDA #$0A				; set sprite status to 'kicked'
	STA $14C8,X
	
	LDA KickSpeedX,Y		; set the sprite's x speed to the base speed + half of Mario's x speed if it's moving in the same direction as him
	STA $B6,X
	EOR $7B
	BMI ?+
	LDA $7B
	STA $00
	ASL $00
	ROR
	CLC : ADC KickSpeedX,Y
	STA $B6,X
	?+
	
	RTS