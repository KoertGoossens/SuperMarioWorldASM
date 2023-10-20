; rope sprite
; the first extension byte sets the x speed for flying ropes, or the initial direction for line-guided ropes
; the second extension byte sets the y speed for flying ropes, or the absolute speed for line-guided ropes
; the third extension byte sets the type:
;	+10		=	flying (0) vs line-guided (10)

; $C2,X		=	Mario on rope flag
; $157C,X	=	direction for line-guided rope (0 = right, 1 = left, 2 = up, 3 = down)
; $1602,X	=	rotation tile x/y (low byte)
; $1626,X	=	rotation flag (stored by line-guide tiles for direction change)
; $187B,X	=	speed for line-guided rope (regardless of direction)


print "INIT ",pc
	PHB
	PHK
	PLB
	JSR InitCode
	PLB
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL


InitCode:
	LDA $14D4,X					; offset y position 1 pixel upward to align the rope with layer 1 tiles
	XBA
	LDA $D8,X
	REP #$20
	DEC
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	JSR CheckLineGuided			; if the rope is flying...
	BNE +
	LDA $7FAB40,X				; set x speed based on the value in the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set y speed based on the value in the second extension byte
	STA $AA,X
	BRA .speedset
	+
	
	LDA $7FAB40,X				; else (the rope is line-guided), set the initial direction based on the first extension byte
	STA $157C,X
	STA $1626,X					; set the stored direction as well
	
	LDA $7FAB4C,X				; set the initial speed based on the second extension byte
	STA $187B,X

.speedset
	LDA #$06 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$1C : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$04 : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$18 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	
	JSR CheckLineGuided			; if the rope is line-guided, handle the direction
	BEQ +
	JSR HandleDirection
	+
	
	JSL $018022					; update x position (no gravity)
	
	LDA $C2,X					; if Mario is climbing the rope...
	BEQ +
	LDA $1491					; store the amount of pixels the rope has moved horizontally to scratch ram
	STA $00
	BMI ++
	STZ $01
	BRA +++
	++
	LDA #$FF
	STA $01
	+++
	REP #$20					; move Mario horizontally accordingly
	LDA $94
	CLC : ADC $00
	STA $94
	SEP #$20
	+
	
	JSL $01801A					; update y position (no gravity)
	
	LDA $C2,X					; if Mario is climbing the rope...
	BEQ +
	LDA $1491					; store the amount of pixels the rope has moved vertically to scratch ram
	STA $00
	BMI ++
	STZ $01
	BRA +++
	++
	LDA #$FF
	STA $01
	+++
	REP #$20					; move Mario vertically accordingly
	LDA $96
	CLC : ADC $00
	STA $96
	SEP #$20
	+
	
	JSR CheckLineGuided			; if the rope is line-guided...
	BEQ +
	JSL $019138					; process interaction with blocks
	JSR HandleRotation
	+
	
	JSR HandleMarioContact
	JSR HandleClimbing

.return
	RTS


HandleDirection:	%LineGuided_HandleDirection() : RTS
HandleRotation:		%LineGuided_HandleRotation() : RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	LDA #$01					; set the 'on climbable surface' flag
	STA $18BE
	
	LDA $79						; if the climbing cooldown flag is clear...
	BNE .return
	LDA $15						; and holding up...
	AND #%00001000
	BEQ .return
	LDA $148F					; and not holding an item...
	ORA $187A					; or on Yoshi...
	BNE .return
	
	LDA #$01					; set climbing cooldown flag
	STA $79
	STA $C2,X					; set the 'climbing the rope' flag

.return
	RTS


HandleClimbing:
	LDA $C2,X					; if Mario is climbing the rope...
	BEQ .return
	
	LDA $16						; if B was pressed, release Mario from the rope
	AND #%10000000
	BNE ReleaseClimb
	
	LDA #$02					; set vertical climbing flag
	STA $13E7
	
	LDA $14E0,X					; load the sprite's x position
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC $94				; subtract Mario's x position
	BEQ .marioxpushed			; if 0 (Mario is centered), don't push Mario
	BMI +						; else, if Mario is to the left, increase his x position
	INC $94
	BRA .marioxpushed
	+
	DEC $94						; else (Mario is to the right), decrease his x position

.marioxpushed
	SEP #$20
	
	LDA $D8,X					; store the sprite's y position to scratch ram
	STA $00
	LDA $14D4,X
	STA $01
	
	REP #$20
	LDA $96						; load Mario's y position
	SEC : SBC $00				; subtract the sprite's y position
	
	BPL +						; if Mario is too high, cap his y position
	LDA $00
	STA $96
	BRA .marioylocked
	+
	CMP #$0020					; else, if Mario is too low, drop him off the rope
	BCS ReleaseClimb

.marioylocked
	SEP #$20

.return
	RTS


ReleaseClimb:
	SEP #$20
	STZ $13E7					; clear Mario's climbing flag
	STZ $C2,X					; clear the climbing the rope flag
	RTS


RopeTileY:
	db $10,$20

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; engine tile
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$AC					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

; rope tiles
	LDX #$01					; use X for the loop counter

.ropetileloop
	INY #4
	
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC RopeTileY,X
	STA $0301,Y
	
	LDA #$8E					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	DEX							; decrement the loop counter and loop to draw the second wing tile if the loop counter is still positive
	BPL .ropetileloop
	
	LDX $15E9					; restore the sprite slot into X

; knot tile
	INY #4
	
	LDA $00						; tile x position
	CLC : ADC #$04
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC #$30
	STA $0301,Y
	
	LDA #$AE					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 8x8 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$00
	STA $0460,Y
	PLY
	
	LDA #$03					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


CheckLineGuided:
	LDA $7FAB58,X
	AND #%00010000
	RTS