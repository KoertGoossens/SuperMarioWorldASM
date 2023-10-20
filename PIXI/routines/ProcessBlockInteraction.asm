	LDA $15DC,X					; if the 'disable block interaction' flag is clear...
	BNE ?+
	JSL $019138					; process interaction with blocks
	?+
	
	RTL