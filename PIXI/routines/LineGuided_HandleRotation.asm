; routine to set the direction and position of a line-guided sprite based when it's set to rotate

	PHB
	PHK
	PLB
	JSR DoHandleRotation
	PLB
	RTL


DoHandleRotation:
	LDA $157C,X					; point to different routines based on the direction
	CMP $1626,X
	BEQ .doreturn
	
	JSL $0086DF
		dw RotateFromRight
		dw RotateFromLeft
		dw RotateFromUp
		dw RotateFromDown

.doreturn
	RTS

RotateFromRight:
	LDA $E4,X					; if the sprite's x is to the right of the tile's x, rotate
	CMP $1602,X
	BMI ?+
	LDA $1626,X					; change the direction to the stored direction
	STA $157C,X
	LDA $1602,X					; set the sprite's x equal to the tile's x
	STA $E4,X
	?+
	RTS

RotateFromLeft:
	LDA $E4,X					; if the sprite's x is to the left of the tile's x, rotate
	DEC
	CMP $1602,X
	BPL ?+
	LDA $1626,X					; change the direction to the stored direction
	STA $157C,X
	LDA $1602,X					; set the sprite's x equal to the tile's x
	STA $E4,X
	?+
	RTS

RotateFromUp:
	LDA $D8,X					; if the sprite's y is above the tile's y, rotate
	CMP $1602,X
	BPL ?+
	LDA $1626,X					; change the direction to the stored direction
	STA $157C,X
	LDA $1602,X					; set the sprite's y equal to the tile's y
	DEC
	STA $D8,X
	?+
	RTS

RotateFromDown:
	LDA $D8,X					; if the sprite's y is below the tile's y, rotate
	INC
	CMP $1602,X
	BMI ?+
	LDA $1626,X					; change the direction to the stored direction
	STA $157C,X
	LDA $1602,X					; set the sprite's y equal to the tile's y
	DEC
	STA $D8,X
	?+
	RTS