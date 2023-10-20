; 2x2 tile block platform sprite that kills Mario and is solid for other sprites
; the first extension byte sets the x speed for flying blocks, or the initial direction for line-guided blocks
; the second extension byte sets the y speed for flying blocks, or the absolute speed for line-guided blocks
; the third extension byte sets the type (0 = flying, 1 = line-guided)

; $C2,X		=	stored x position (low byte)
; $1504,X	=	block interaction flag
; $151C,X	=	stored x position (high byte)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $1534,X	=	width (minus 16)
; $1570,X	=	height (minus 16)
; $157C,X	=	direction for line-guided block (0 = right, 1 = left, 2 = up, 3 = down)
; $1594,X	=	stored y position (low byte)
; $1602,X	=	rotation tile x/y (low byte)
; $160E,X	=	stored y position (high byte)
; $1626,X	=	rotation flag (stored by line-guide tiles for direction change)
; $187B,X	=	speed for line-guided block (regardless of direction)


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
	LDA $7FAB58,X				; if the block is flying...
	BNE .lineguided
	
	%RaiseSprite1Pixel()
	
	LDA $7FAB40,X				; set x speed based on the value in the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set y speed based on the value in the second extension byte
	STA $AA,X
	
	BRA .typeset

.lineguided
	LDA $14E0,X					; offset x position 8 pixels rightward
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X					; offset y position 7 pixels downward
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0007
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA $7FAB40,X				; else (the block is line-guided), set the initial direction based on the first extension byte
	STA $157C,X
	STA $1626,X					; set the stored direction as well
	
	LDA $7FAB4C,X				; set the initial speed based on the second extension byte
	STA $187B,X

.typeset
	LDA #$10					; set the width (32 pixels)
	STA $1534,X
	LDA #$10					; set the height (32 pixels)
	STA $1570,X
	
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$1E : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$24 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	LDA #$FD : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites (vanilla flying item block = #$01)
	LDA #$FE : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites (vanilla flying item block = #$FE)
	LDA #$25 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites (vanilla flying item block = #$0D)
	LDA #$26 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites (vanilla flying item block = #$16)
	
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
	
	%SolidInteractionVals()
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $7FAB58,X				; if the block is line-guided, handle the direction
	BEQ +
	JSR HandleDirection
	+
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	
	%HandleLineGuidedRotation()
	JSR HandleMarioContact

.return
	RTS


HandleDirection:	%LineGuided_HandleDirection() : RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite...
	BCC .return
	JSL $00F606					; kill him

.return
	RTS


TileX:
	db $00,$10,$00,$10
TileY:
	db $00,$00,$10,$10
TileMap:
	db $40,$41,$50,$51

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; ICON GRAPHICS
	LDA $00						; tile x position
	CLC : ADC #$08
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC #$08
	STA $0301,Y
	
	LDA #$43					; tile ID
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

; BLOCK GRAPHICS
	INY #4						; increment Y (the OAM index) by 4
	LDX #$03					; use X for the loop counter (number of tiles - 1)

.tileloop
	LDA $00						; tile x position
	CLC : ADC TileX,X
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC TileY,X
	STA $0301,Y
	
	LDA TileMap,X				; tile ID
	STA $0302,Y
	
	LDA #%00101101				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	INY #4						; increment the OAM index
	
	DEX							; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .tileloop
	
	LDX $15E9					; restore the sprite slot into X
	
	LDA #$04					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS