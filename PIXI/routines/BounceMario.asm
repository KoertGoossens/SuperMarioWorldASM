; routine to bounce Mario up after he hits a sprite on the top

	LDA $74						; if climbing, don't bounce up
	BNE .skipbounceup
	
	LDA #$D0					; give Mario #$D0 speed without B/A held, or #$A8 with B/A held
	BIT $15
	BPL ?+
	LDA #$A8
	?+
	STA $7D

.skipbounceup
	LDA #$08					; set the 'disable contact with Mario' timer
	STA $154C,X
	
	JSL $01AB99					; display contact star below Mario
	RTL