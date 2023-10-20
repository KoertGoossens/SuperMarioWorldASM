; routine to bump a carryable item sprite into kicked state

	PHB
	PHK
	PLB
	JSR DoHandleBumpItem
	PLB
	RTL


BumpSpeedX:
	db $D2,$2E

DoHandleBumpItem:
	LDA #$03					; play kick sfx
	STA $1DF9
	
	LDA $1540,X					; store the stun timer to $C2,X
	STA $C2,X
	
	LDA #$0A					; set the sprite status to 'kicked'
	STA $14C8,X
	
	LDA #$10					; disable contact with Mario for 16 frames
	STA $154C,X
	
	%SubHorzPos()				; give the item x speed based on the horizontal position towards Mario
	LDA BumpSpeedX,Y
	STA $B6,X
	RTS