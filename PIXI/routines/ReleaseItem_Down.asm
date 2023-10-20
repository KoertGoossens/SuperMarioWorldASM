	PHB
	PHK
	PLB
	JSR DoReleaseItemDown
	PLB
	RTL


DropXOffset:
	dw $FFF3,$000D				; drop left, drop right
DropXSpeed:
	db $FC,$04

DoReleaseItemDown:
	LDA $13E7					; if Mario is climbing, don't offset the item's position, and set the item's x and y speeds equal to Mario's
	BEQ ?+
	LDA $7B
	STA $B6,X
	LDA $7D
	STA $AA,X
	RTS
	?+
	
	LDA $1908					; if Mario is inside a boost bubble, don't offset the item's position, and give the item 0 x and y speed
	BEQ ?+
	STZ $B6,X
	STZ $AA,X
	RTS
	?+
	
	STZ $AA,X					; else, set the item's y speed to 0
	
	LDA $140D					; skip if not spinning
	BEQ .nospin
	
	LDA $15						; if right is pressed, throw right
	BIT #$01
	BNE .spinthrowright
	BIT #$02					; else, if left is pressed, throw left
	BNE .spinthrowleft
	LDA $7B						; else (neutral dpad), if positive or 0 x speed, throw right, otherwise throw left
	BPL .spinthrowright

.spinthrowleft
	LDY #$00
	BRA .setposition

.spinthrowright
	LDY #$02
	BRA .setposition

.nospin
	LDA $76						; store Mario's face direction x2 as index
	ASL
	TAY

.setposition
	LDA $D2						; load Mario's x position
	XBA
	LDA $D1
	REP #$20					; add the offset
	CLC : ADC DropXOffset,Y
	SEP #$20
	STA $E4,X					; store to sprite's x position
	XBA
	STA $14E0,X
	
	%SubHorzPos()				; set the item's x speed to Mario's x speed plus/minus 4
	LDA DropXSpeed,Y
	CLC : ADC $7B
	STA $B6,X
	RTS