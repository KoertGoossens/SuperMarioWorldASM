	LDA #$09					; set the sprite status to 'carryable'
	STA $14C8,X
	LDA #$10					; disable contact with Mario for 16 frames
	STA $154C,X
	LDA #$0C					; show Mario's kicking pose for 12 frames
	STA $149A
	STZ $14EC,X					; set the item's y speed fraction bits to 0
	RTL