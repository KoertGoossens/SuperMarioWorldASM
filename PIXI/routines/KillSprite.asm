; routine to have the calling sprite kill an indexed sprite


	LDA $1662,Y					; if $1662,Y (tweaker byte) is #$2F for the indexed sprite (parachute sprite)...
	CMP #$2F
	BNE ?+
	LDA #$01					; set the parachute sprite's phase to 'drop sprite'
	STA $C2,Y
	BRA .doreturn
	?+
	
	PHY
	INC $1626,X					; increment the item sprite's 'number of consecutive enemies killed' counter
	LDY $1626,X					; if below 8...
	CPY #$08
	BCS ++
	%PlayEnemyKillSFX()			; play the hit sfx based on this counter
	++
	TYA							; give points based on the counter, but cap it at 8
	CMP #$08
	BCC ?+
	LDA #$08
	?+
	PLY
	JSL $02ACE5					; give points
	
	LDA #$02					; set the indexed sprite's status to killed
	STA $14C8,Y
	
	PHX							; display contact gfx at the killed sprite's position
	TYX
	JSL $01AB72
	PLX
	
	LDA $B6,X					; give the indexed sprite an x speed of #$10 or #$F0 based on the direction the item sprite is moving in
	ASL
	LDA #$10
	BCC ?+
	LDA #$F0
	?+
	STA $B6,Y
	
	LDA #$D0					; give the indexed sprite upward y speed
	STA $AA,Y

.doreturn
	RTL