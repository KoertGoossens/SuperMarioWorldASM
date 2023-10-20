; routine to kill a sprite by spinning or stomping on it with Yoshi

	PHB
	PHK
	PLB
	JSR DoSpinKillSprite
	PLB
	RTL


DoSpinKillSprite:
	JSL $01AB99					; display contact star
	
	LDA #$F8					; give Mario some small upward y speed
	STA $7D
	
	LDA $187A					; if on Yoshi, boost Mario upward instead
	BEQ ++
	%BounceMario()
	++
	
	%SmokeKillSprite()
	JSL $07FC3B					; generate spinkill stars
	%HandleBounceCounter()
	
	LDA #$08					; play smokekill sfx
	STA $1DF9
	RTS