SpeedMax:
	db $10,$F0

IncTable:
	db $01,$FF


print "INIT ",pc
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR BooMain
	PLB
	RTL

BooMain:
	LDA #$00					; handle spawn/despawn radius
	%SubOffScreen()
	
	LDA $14C8,X					; if the sprite is not in normal status...
	CMP #$08
	BNE +
	LDA $9D						; or sprites are locked...
	BEQ ContinueMain			; skip most of the main routine and just run the interaction and GFX routine
	+
	
	JMP InteractGFX

ContinueMain:
	LDY #$00
	LDA $E4,X					; store the boo's x position into scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	REP #$20					; subtract the boo's x position from Mario's x position and store it to $0E
	LDA $94
	SEC : SBC $00
	STA $0E
	BPL +						; if positive, set Y to 1
	INY
	+
	SEP #$20
	
	TYA							; set the boo's face direction to always face Mario
	STA $157C,X
	
	LDA $0E
	BMI +
	CMP SpeedMax,Y
	BCC .xSpeedSet
	LDA SpeedMax,Y
	BRA .xSpeedSet
	+
	CMP SpeedMax,Y
	BCS .xSpeedSet
	LDA SpeedMax,Y
.xSpeedSet
	STA $B6,X
	
;	LDA $B6,X					; if the max x speed has not yet been reached, increment or decrement it by 1
;	CMP SpeedMax,Y
;	BEQ +
;	CLC : ADC IncTable,Y
;	STA $B6,X
;	+
	
	LDY #$00
	LDA $D8,X					; store the boo's y position into scratch RAM
	STA $00
	LDA $14D4,X
	STA $01
	REP #$20					; subtract the boo's y position from Mario's y position and store it to $0E
	LDA $96
	CLC : ADC #$0010
	SEC : SBC $00
	STA $0E
	BPL +						; if positive, set Y to 1
	INY
	+
	SEP #$20
	
;	LDA $0E
;	BMI +
;	CMP SpeedMax,Y
;	BCC .ySpeedSet
;	LDA SpeedMax,Y
;	BRA .ySpeedSet
;	+
;	CMP SpeedMax,Y
;	BCS .ySpeedSet
;	LDA SpeedMax,Y
;.ySpeedSet
;	STA $AA,X
	
	LDA $AA,X					; if the max y speed has been reached, update the position; otherwise, increment or decrement it by 1
	CMP SpeedMax,Y
	BEQ +
	CLC : ADC IncTable,Y
	STA $AA,X
	+
	
	JSL $018022					; update sprite's x position (no gravity)
	JSL $01801A					; update sprite's y position (no gravity)

InteractGFX:
	LDA $14C8,X					; if the sprite is in normal status, handle interaction between Mario and the sprite
	CMP #$08
	BNE +
	JSL $01A7DC
	+
	
	%GetDrawInfo()				; get sprite coordinates within the screen and OAM index
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	LDA #$88					; tile ID
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