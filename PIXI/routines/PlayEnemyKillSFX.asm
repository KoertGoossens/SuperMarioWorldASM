	PHB
	PHK
	PLB
	JSR DoPlaySFX
	PLB
	RTL


EnemyKillSFX:
	db $13,$14,$15,$16,$17,$18,$19

DoPlaySFX:
	LDA EnemyKillSFX-1,Y		; play bounce sfx based on the index
	STA $1DF9
	RTS