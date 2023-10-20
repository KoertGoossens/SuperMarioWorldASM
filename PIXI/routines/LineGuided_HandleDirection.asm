; routine to set x/y speeds of a line-guided sprite based on its direction

	PHB
	PHK
	PLB
	JSR DoHandleDirection
	PLB
	RTL


DoHandleDirection:
	LDA $157C,X					; point to different routines based on the direction
	JSL $0086DF
		dw MoveRight
		dw MoveLeft
		dw MoveUp
		dw MoveDown

MoveRight:
	LDA $187B,X					; set the x speed to the speed value
	STA $B6,X
	STZ $AA,X					; set the y speed to 0
	RTS

MoveLeft:
	LDA $187B,X					; set the x speed to the inverted speed value
	EOR #$FF
	INC A
	STA $B6,X
	STZ $AA,X					; set the y speed to 0
	RTS

MoveUp:
	LDA $187B,X					; set the y speed to the inverted speed value
	EOR #$FF
	INC A
	STA $AA,X
	STZ $B6,X					; set the x speed to 0
	RTS

MoveDown:
	LDA $187B,X					; set the y speed to the speed value
	STA $AA,X
	STZ $B6,X					; set the x speed to 0
	RTS