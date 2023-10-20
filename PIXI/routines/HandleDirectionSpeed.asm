; set a sprite's face direction based on its x speed


	STZ $157C,X				; set the face direction based on the x speed (0 speed = face left)
	
	LDA $B6,X
	BEQ ?+
	BMI ?+
	RTL
	?+
	
	INC $157C,X
	RTL