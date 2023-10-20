; routine to activate a solid sprite to spawn an item

	PHB
	PHK
	PLB
	JSR DoHandle
	PLB
	RTL


SpawnSpriteID:
	db $1C,$0F,$0E,$02,$06,$00,$35		; mushroom, shell, throwblock, p-switch, spring, dino, spiny

DoHandle:
	LDA $1558,X					; if the activation timer is set...
	BEQ .doreturn
	
	LDA #$02					; play 'grow' sfx
	STA $1DFC
	
	LDA $7FAB58,X				; spawned a sprite with the ID based on the 3rd extension byte
	AND #%00001111
	TAY
	LDA SpawnSpriteID,Y
	%SpawnCustomSprite()
	
	LDA $E4,X					; position the spawned sprite at the same x as the item block sprite
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	
	LDA $14D4,X					; position the spawned sprite 8 pixels above the item block sprite
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0008
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA #$D0					; give the spawned sprite upward speed
	STA $AA,Y
	
	%DisableInteraction_Spawned()
	
	LDA #$60					; change the item block's sprite ID to 'solid block'
	STA $7FAB9E,X
	
	DEC $1558,X					; decrement the activation timer (the solid block sprite will further use this for the bounce animation)

.doreturn
	RTS