; a horizontal climbable vine tile that pushes Mario to the left; insert as 25

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
	LDA $98						; get the block's y position
	AND #%1111111111110000
	SEC : SBC $96				; subtract Mario's y position
	SBC #$0010					; subtract 16 pixels
	STA $00						; store it to scratch ram
	
	BMI +						; if Mario is too high, return
	CMP #$0005
	BCS .return16bit
	BRA .checkgrab
	+
	CMP #$FFFC					; if Mario is too low, return
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
	
	LDA #$05					; set leftward conveyor climbing flag
	STA $13E7
	
	LDA #$01					; set climbing cooldown flag
	STA $79

.skipstartclimb
	LDA $13E7					; if climbing...
	BEQ Return
	
	REP #$20
	LDA $00						; load the y offset between the block and Mario
	BEQ .return16bit			; if 0 (Mario is centered), don't push Mario
	BMI +						; else, if Mario is above, increase his y position
	INC $96
	BRA .return16bit
	+
	DEC $96						; else (Mario is below), decrease his y position

.return16bit
	SEP #$20

Return:
	RTL


print "A conveyor vine tile."