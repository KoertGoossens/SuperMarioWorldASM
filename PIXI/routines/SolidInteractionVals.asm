	LDA $E4,X					; store the sprite's coordinates (checked for interaction with other sprites)
	STA $C2,X
	LDA $14E0,X
	STA $151C,X
	LDA $D8,X
	STA $1594,X
	LDA $14D4,X
	STA $160E,X
	RTL