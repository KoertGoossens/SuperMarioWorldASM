; a vertical climbable vine tile; insert as 25

db $42
JMP MarioTouch			; Mario touching the tile from below
JMP MarioTouch			; Mario touching the tile from above
JMP MarioTouch			; Mario touching the tile from the side
JMP Return				; sprite touching the tile from above or below
JMP Return				; sprite touching the tile from the side
JMP Return				; capespin touching the tile
JMP Return				; fire flower fireball touching the tile
JMP MarioTouch			; Mario touching the upper corners of the tile
JMP MarioTouch			; Mario's lower half is inside the block
JMP MarioTouch			; Mario's upper half is inside the block


MarioTouch:
	LDA $18BE					; if the 'on climbable surface' flag is already set, return
	BNE Return
	
	REP #$20
	LDA $9A						; get the block's x position
	AND #%1111111111110000
	SEC : SBC $94				; subtract Mario's x position
	STA $00						; store it to scratch ram
	BMI +						; if Mario is too far left, return
	CMP #$0009
	BCS .return16bit
	BRA .checkgrab
	+
	CMP #$FFF8					; if Mario is too far right, return
	BCC .return16bit

.checkgrab
	SEP #$20
	
	LDA #$01					; set the 'on climbable surface' flag
	STA $18BE
	
	LDA $79						; if the climbing cooldown flag is clear...
	BNE .skipstartclimb
	LDA $15						; and holding up or down...
	AND #%00001100
	BEQ .skipstartclimb
	LDA $148F					; and not holding an item...
	ORA $187A					; or on Yoshi...
	BNE .skipstartclimb
	
	LDA #$01					; set climbing cooldown flag
	STA $79
	
	LDA $15						; and not both holding down and not airborne...
	AND #%00000100
	BEQ +
	LDA $72
	BEQ .skipstartclimb
	+
	
	LDA #$02					; set vertical climbing flag
	STA $13E7

.skipstartclimb
	LDA $13E7					; if climbing...
	BEQ Return
	
	REP #$20
	LDA $00						; load the x offset between the block and Mario
	BEQ .return16bit			; if 0 (Mario is centered), don't push Mario
	BMI +						; else, if Mario is to the left, increase his x position
	INC $94
	BRA .return16bit
	+
	DEC $94						; else (Mario is to the right), decrease his x position

.return16bit
	SEP #$20

Return:
	RTL


print "A vertical vine tile."