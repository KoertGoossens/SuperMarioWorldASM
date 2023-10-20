	PHY
	INC $1697					; increment Mario's bounce counter
	
	LDA $1697					; load Mario's bounce counter + the sprite's kill counter as an index
	CLC : ADC $1626,X
	TAY
	
	CPY #$07					; cap the index at 7
	BCC ?+
	LDY #$07
	?+
	
	%PlayEnemyKillSFX()			; play the bounce sfx based on the index
	PLY
	RTL