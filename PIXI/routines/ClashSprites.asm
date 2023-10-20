; routine to kill two sprites that are in contact with each other


	LDA #$02					; set the item sprite's status to 'killed'
	STA $14C8,X
	LDA #$02					; set the indexed sprite's status to 'killed'
	STA $14C8,Y
	
	LDA #$D0					; give the item sprite upward speed
	STA $AA,X
	STA $AA,Y					; give the indexed sprite upward speed
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	
	LDA #$04					; give points
	JSL $02ACE5
	
	LDA $B6,Y					; give the indexed sprite an x speed of #$10 or #$F0 based on the direction it was moving in
	ASL
	LDA #$10
	BCS ?+
	LDA #$F0
	?+
	
	STA $B6,Y
	EOR #$FF					; give the item sprite the opposite x speed
	INC A
	STA $B6,X
	RTL