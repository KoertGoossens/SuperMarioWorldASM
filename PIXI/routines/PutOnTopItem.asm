	LDA $7D						; return if Mario is moving upwards
	BMI .return
	
	STZ $7D						; give Mario 0 y speed
	STZ $72						; set Mario's 'in the air' flag to 0
	INC $1471					; set Mario's 'standing on a solid sprite' flag
	
	STZ $01						; determine Mario's y offset from the item based on whether he's on Yoshi
	LDA #$1F
	LDY $187A
	BEQ ?+
	LDA #$2F
	?+
	STA $00
	LDA $14D4,X					; offset Mario vertically from the item
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $00
	STA $96
	SEP #$20

.return
	RTL