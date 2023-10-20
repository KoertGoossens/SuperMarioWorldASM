; handle disabling interaction for a spawned sprite
; make sure to keep this routine synced with the PIXI shared routine 'DisableInteraction_Spawned.asm'


	LDA #$02					; temporarily disable interaction with Mario for the spawned sprite
	STA $154C,Y
	
	LDA #$08					; temporarily disable interaction with other sprites for the spawned sprite
	STA $1564,Y
	
	LDA #$04					; temporarily disable interaction with blocks for the spawned sprite
	STA $15AC,Y
	RTL