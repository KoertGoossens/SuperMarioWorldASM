; routine to have two sprites walk off each other


	LDA $E4,Y					; load the horizontal direction of the calling sprite towards the indexed sprite to scratch ram
	SEC : SBC $00E4,X
	LDA $14E0,Y
	SBC $14E0,X
	ROL
	AND #$01
	BEQ .callingright			; if the calling sprite is to the left...
	
	LDA $157C,X					; if the calling sprite is facing right, invert its face direction
	BNE ?+
	EOR #$01
	STA $157C,X
	?+
	
	LDA $157C,Y					; if the indexed sprite is facing left, invert its face direction
	BEQ ?+
	EOR #$01
	STA $157C,Y
	?+
	
	RTL

.callingright					; else (the calling sprite is facing right)...
	LDA $157C,X					; if the calling sprite is facing left, invert its face direction
	BEQ ?+
	EOR #$01
	STA $157C,X
	?+
	
	LDA $157C,Y					; if the indexed sprite is facing right, invert its face direction
	BNE ?+
	EOR #$01
	STA $157C,Y
	?+
	
	RTL