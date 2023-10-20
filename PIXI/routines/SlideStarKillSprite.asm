; routine to kill a sprite by sliding or star power

	PHB
	PHK
	PLB
	JSR DoSlideKillSprite
	PLB
	RTL


EnemyKillXSpeed:
	db $F0,$10

DoSlideKillSprite:
	JSL $01AB6F					; display hit graphics
	
	INC $18D2					; increment the starkill counter
	LDA $18D2					; if the starkill counter is 8 or higher, set it to 8
	CMP #$08
	BCC ?++
	LDA #$08
	STA $18D2
	?++
	
	JSL $02ACE5					; give points
	
	LDY $18D2					; play the hit sfx based on the starkill counter
	CPY #$08
	BCS ++
	%PlayEnemyKillSFX()
	++
	
	LDA #$02					; set the sprite status to 'killed'
	STA $14C8,X
	
	LDA #$D0					; give the sprite some upward speed
	STA $AA,X
	
	%SubHorzPos()				; give the sprite some horizontal speed based on its horizontal position towards Mario
	LDA EnemyKillXSpeed,Y
	STA $B6,X
	RTS