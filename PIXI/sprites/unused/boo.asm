SpeedMax:
	db $08,$F8

IncTable:
	db $01,$FF

Frame:
	db $01,$02,$02,$01

Tilemap:
	db $88,$8C,$A8,$8E,$AA,$AE,$8C,$88,$A8,$AE,$AC,$8C,$8E


; $C2	=	state (0 = following Mario, 1 = stationary)
; $1540	=	timer until the next check of whether Mario is facing the boo
; $1558	=	timer for the boo's 'tongue waggle' animation and big boo's 'peeking' animation (block boos also set this, but don't use it)
; $1570	=	animation frame timer (used to wait until showing the boo's 'tongue waggle' or big boo's 'peeking' animations)
; $157C	=	face direction
; $15AC	=	turnaround timer (set to #$1F at the start of the turnaround)
; $1602	=	animation frame:	boo:		0 = moving, 2/3 = tongue waggle, 6 = stationary
;								block boo:	0 = moving, 1 = semi-block, 2 = block
;								big boo:	0 = moving, 1/2 = turning, 3 = stationary (eyes covered)
; $18B6	=	used temporarily as the height of the sprite, for deciding which way to accelerate vertically towards Mario


print "INIT ",pc
	STZ $1534,X					; clear sprite RAM used for EOR chase table value
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR BooMain
	PLB
	RTL

BooMain:
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA #$10
	STA $18B6					; unknown RAM address?
	
	LDA $14C8,X
	CMP #$08					; if the sprite is not in normal status...
	BNE SkipToGFX
	LDA $9D						; or sprites are locked...
	BEQ ContinueMain			; skip most of the main routine and just run the GFX routine

SkipToGFX:
	JMP InteractGFX

ContinueMain:
	%SubHorzPos()
	
	LDA $1540,X					; if the timer is set...
	BNE NoChangeState
	
	LDA #$20
	STA $1540,X
	LDA $C2,x					; if the sprite state is zero...
	EOR $1534,X					; flip bit 0 if value is set
	BEQ NoCheckProximity
	LDA $0E
	CLC : ADC #$0A
	CMP #$14
	BCC Skip1					; skip the next part of code if the Boo is within a certain distance

NoCheckProximity:
	STZ $C2,X
	CPY $76						; if the Boo is facing the player...
	BNE NoChangeState			; don't make it follow him/her
	INC $C2,X

NoChangeState:
	LDA $0E
	CLC : ADC #$0A
	CMP #$14
	BCC Skip1
	
	LDA $15AC,X					; if the sprite is turning...
	BNE Skip2					; skip the check and set
	TYA
	CMP $157C,X
	BEQ Skip1
	LDA #$1F
	STA $15AC,X					; set the turn timer
	BRA Skip2

Skip1:
	STZ $1602,X
	LDA !C2,X
	EOR $1534,X					; flip bit 0 if value is set
	BEQ Skip3
	LDA #$03
	STA $1602,X
	LDA #$01
	AND $13
	BNE Skip4
	INC $1570,X
	LDA $1570,X
	BNE NoSetTimer2
	LDA #$20
	STA $1558,X

NoSetTimer2:
	LDA $B6,X					; increment or decrement the sprite X speed
	BEQ XSpdZero				; depending on whether it is positive, negative, or zero
	BPL XSpdPlus
	INC #2

XSpdPlus:
	DEC

XSpdZero:
	STA $B6,X
	LDA $AA,X					; same for the Y speed
	BEQ YSpdZero
	BPL YSpdPlus
	INC #2

YSpdPlus:
	DEC

YSpdZero:
	STA $AA,X

Skip4:
	JMP UpdatePosition

Skip2:
	CMP #$10
	BNE NoFlipDir
	PHA
	LDA $157C,X
	EOR #$01					; flip sprite direction
	STA $157C,X
	PLA

NoFlipDir:
	LSR #3
	TAY
	LDA Frame,Y
	STA $1602,X

Skip3:
	STZ $1570,X
	LDA $13
	AND #$07					; skip this every 8 frames
	BNE UpdatePosition

	%SubHorzPos()

	LDA $B6,X
	CMP SpeedMax,Y
	BEQ NoIncXSpeed
	CLC : ADC IncTable,Y
	STA $B6,X

NoIncXSpeed:
	LDA $D3
	PHA
	SEC
	SBC $18B6
	STA $D3
	LDA $D4
	PHA
	SBC #$00
	STA $D4
	
	JSR SubVertPos2
	
	PLA
	STA $D4
	PLA
	STA $D3
	
	LDA $AA,X
	CMP SpeedMax,Y
	BEQ UpdatePosition
	CLC : ADC IncTable,Y
	STA $AA,X

UpdatePosition:
	JSL $018022					; update sprite's x position (no gravity)
	JSL $01801A					; update sprite's y position (no gravity)

InteractGFX:
	LDA $14C8,X					; if the sprite is in normal status, handle interaction between Mario and the sprite
	CMP #$08
	BNE +
	JSL $01A7DC
	+
	JSR BooGFX					; draw graphics
	RTS

BooGFX:
	LDA $1534,X
	STA $00
	LDA #$00
	LDY $C2,X
	CPY $00						; flip bit 0 if value is set
	BEQ SetFrame
	LDA #$06
	LDY $1558,X
	BEQ SetFrame
	TYA
	AND #$04
	LSR #2
	ADC #$02

SetFrame:
	STA $1602,X
	JSR DrawBoo					; this was originally a JSL to $0190B2
	RTS

DrawBoo:
	%GetDrawInfo()
	
	LDA $157C,X
	STA $02
	
	LDA $1602,X
	TAX
	LDA Tilemap,X				; set the sprite tilemap
	STA $0302,Y
	
	LDX $15E9
	LDA $00
	STA $0300,Y					; no X displacement
	LDA $01
	STA $0301,Y					; no Y displacement
	
	LDA $157C,X
	LSR							; if the sprite is facing right...
	LDA $15F6,X
	BCS NoXFlip					; X-flip it
	EOR #$40

NoXFlip:
	ORA $64
	STA $0303,Y
	
	TYA
	LSR #2
	TAY
	
	LDA #$02
	ORA $15A0,X
	STA $0460,Y					; set the tile size
	
	PHK
	PER $0006
	PEA $8020
	JML $01A3DF					; set up some stuff in OAM
	
	RTS

SubVertPos2:
	LDY #$00
	LDA $D3
	SEC
	SBC $D8,X
	STA $0E
	LDA $D4
	SBC $14D4,X
	BPL $01
	INY
	RTS