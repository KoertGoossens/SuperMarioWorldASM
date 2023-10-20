; routine to damage Mario

	PHB
	PHK
	PLB
	JSR DoDamageMario
	PLB
	RTL


DoDamageMario:
	LDA $1497					; if Mario does not have invulnerability frames (after a damage boost)...
	BNE .doreturn
	
	LDA #$08					; set the 'disable contact with Mario' timer
	STA $154C,X
	
	LDA $187A					; if not riding Yoshi...
	BNE ?+
	JSL $00F5B7					; hurt Mario
	BRA .doreturn
	?+
	
	PHX
	LDX $18DA					; else, load Yoshi's sprite slot for indexing
	LDA $7FAB40,X				; if it's a vanilla-style Yoshi...
	BNE +
	STZ $187A					; set Mario off Yoshi
	
	LDA #$30					; make Mario invulnerable for 48 frames
	STA $1497
	
	LDA #$C0					; set Mario's y speed
	STA $7D
	STZ $7B						; set Mario's x speed to 0
	JSR DamageYoshi
	BRA .returndamage
	+
	
	JSL $00F5B7					; else (custom Yoshi), hurt Mario

.returndamage
	PLX

.doreturn
	RTS


YoshiDamageSpeed:
	db $18,$E8

DamageYoshi:
	PHY
	LDX $18DA					; load Yoshi's sprite slot for indexing
	%SetMarioAboveYoshi()
	
	LDA #$02					; put Yoshi in running state
	STA $C2,X
	
	LDA #$08					; disable contact with other sprites for 8 frames
	STA $163E,X
	
	LDA #$13					; play Yoshi damage sfx
	STA $1DFC
	
	LDA $157C,X					; invert Yoshi's face direction
	TAY							; set Yoshi's x speed based on his face direction
	LDA YoshiDamageSpeed,Y
	STA $B6,X
	
	STZ $1594,X					; set Yoshi's mouth phase to 0
	STZ $151C,X					; set Yoshi's tongue length to 0
	STZ $1626,X					; set Yoshi's tongue extension timer to 0
	
	PLY
	RTS