	LDA #$02					; play bounce sfx
	STA $1DF9
	%BounceMario()				; have Mario bounce up
	RTL