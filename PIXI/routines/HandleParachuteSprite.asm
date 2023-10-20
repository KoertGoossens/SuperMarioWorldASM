; routine to handle dropping a parachute sprite
; input:	$0F = sprite ID of the sprite to drop

	PHB
	PHK
	PLB
	JSR DoHandleDrop
	PLB
	RTL


DoHandleDrop:
	LDA $15D0,X					; if the sprite is on Yoshi's tongue, return
	BNE .return
	
	LDA $C2,X					; if the phase is 'drop sprite' (set after being hit by another sprite), drop the sprite
	BNE DropSprite
	
	JSR CheckMarioProx			; check for horizontal proximity with Mario to see whether the sprite should be dropped

.return
	RTS


!AggroDist	=	#$0030

CheckMarioProx:
	LDA $E4,X					; store the sprite's x position to scratch ram
	STA $00
	LDA $14E0,X
	STA $01
	
	REP #$20					; if Mario is less than !AggroDist away from the sprite horizontally, drop the sprite
	LDA $00
	SEC : SBC $94
	STA $02
	SBC !AggroDist
	SBC #$0001
	BPL .return
	LDA $02
	CLC : ADC !AggroDist
	BMI .return
	SEP #$20
	
	BRA DropSprite

.return
	SEP #$20
	RTS


DropSprite:
	LDA #$28					; play fall sfx
	STA $1DF9
	
	LDA $0F						; load the sprite ID (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA $E4,X					; set the spawned sprite's position equal to the parent sprite's position
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	LDA #$08					; temporarily disable contact with other sprites for the spawned sprite
	STA $1564,Y
	
	LDA #$01					; set the spawned sprite's face direction to left
	STA $157C,Y
	
	STZ $01						; draw smoke 1 tile above the sprite
	LDA #$F0
	STA $02
	%SpawnSpriteSmoke()
	
	STZ $14C8,X					; erase the sprite
	RTS