	PHB
	PHK
	PLB
	JSR DoReleaseItemUp
	PLB
	RTL


DoReleaseItemUp:
	LDA $140D				; if Mario is spinning...
	BEQ .skipxoffset
	LDA $1908				; and not inside a boost bubble...
	BNE .skipxoffset
	
	LDA $15					; if right is pressed, go to .throwRight
	BIT #$01
	BNE .throwRight
	BIT #$02				; else if left is pressed, go to .throwLeft
	BNE .throwLeft
	LDA $7B					; else (if neutral dpad) if positive or 0 x speed, go to .throwRight, otherwise go to .throwLeft
	BPL .throwRight

.throwLeft
	LDA $D2					; load Mario's x position, high byte
	XBA
	LDA $D1					; load Mario's x position, low byte
	REP #$20				; subtract 4 pixels
	SEC : SBC #$0004
	SEP #$20
	BRA .storeSpritePos

.throwRight
	LDA $D2					; load Mario's x position, high byte
	XBA
	LDA $D1					; load Mario's x position, low byte
	REP #$20				; add 4 pixels
	CLC : ADC #$0004
	SEP #$20

.storeSpritePos
	STA $E4,X				; store to sprite's x position, low byte
	XBA
	STA $14E0,X				; store to sprite's x position, high byte

.skipxoffset
	JSL $01AB6F				; display 'hit' graphic at sprite's position
	
	LDA #$90				; give the item upward y speed
	STA $AA,X
	
	STZ $B6,X				; give the item 0 x speed
	
	LDA $1908				; if Mario is not inside a boost bubble...
	BNE .doreturn
	LDA $13E3				; and not wallrunning straight up...
	CMP #$06
	BCS .doreturn
	
	LDA $7B					; give the item half of Mario's x speed
	STA $B6,X
	ASL
	ROR $B6,X

.doreturn
	RTS