; arrow block platform sprite that will move horizontally or vertically when hit
; the extension byte sets the direction (00 = right, 01 = left, 02 = up, 03 = down)

; sprite-indexed addresses:
;	 $1504,X	=	activation trigger


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
	LDA $14D4,X				; offset y position 1 pixel upward to align the block with layer 1 tiles
	XBA
	LDA $D8,X
	REP #$20
	DEC
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE Return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE Return
	
	%SubOffScreen()				; call offscreen despawning routine
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
;	%CustomSolidSprite()		; handle custom solid block interaction for Mario and items
	
	LDA $B6,X					; if the sprite's x speed is not 0, decrease/increase it
	BEQ +
	BMI ++
	SEC : SBC #$02
	STA $B6,X
	BRA +
	++
	CLC : ADC #$02
	STA $B6,X
	+
	
	LDA $AA,X					; if the sprite's y speed is not 0, decrease/increase it
	BEQ +
	BMI ++
	SEC : SBC #$02
	STA $AA,X
	BRA +
	++
	CLC : ADC #$02
	STA $AA,X
	+

CheckActivation:
	LDA $1504,X					; if the 'activation' flag was set (see %CustomSolidSprite()), initiate the boost
	BEQ Return
	LDA #$0B					; play switch sfx
	STA $1DF9
	
	LDA $7FAB40,X				; set x/y speed based on extension byte
	BNE +
	LDA #$30					; set positive x speed
	STA $B6,X
	BRA Return
	+
	CMP #$01
	BNE +
	LDA #$D0					; set negative x speed
	STA $B6,X
	BRA Return
	+
	CMP #$02
	BNE +
	LDA #$D0					; set negative y speed
	STA $AA,X
	BRA Return
	+
	CMP #$03
	BNE +
	LDA #$30					; set positive y speed
	STA $AA,X
	+

Return:
	RTS


Tilemap:
	db $22,$42,$60,$68

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; BLOCK GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $7FAB40,X				; tile ID
	TAY
	LDA Tilemap,Y
	PLY
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
	
	LDA #$03					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS