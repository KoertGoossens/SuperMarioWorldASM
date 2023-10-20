; block platform sprite that eats adjacent solid blocks; it is solid for Mario and other sprites
; the first extension byte sets the initial direction
; the second extension byte sets the speed

; $C2,X		=	stored x position (low byte)
; $1504,X	=	block interaction flag
; $151C,X	=	stored x position (high byte)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $1534,X	=	width (minus 16)
; $1558,X	=	activation timer
; $1570,X	=	height (minus 16)
; $157C,X	=	direction (0 = right, 1 = left, 2 = up, 3 = down)
; $1594,X	=	stored y position (low byte)
; $1602,X	=	rotation tile x/y (low byte)
; $160E,X	=	stored y position (high byte)
; $1626,X	=	block check flag
; $187B,X	=	speed (regardless of direction)


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
	%RaiseSprite1Pixel()
	
	STZ $1534,X					; set the width (16 pixels)
	STZ $1570,X					; set the height (16 pixels)
	
	LDA $7FAB40,X				; set the initial direction based on the first extension byte
	STA $157C,X
	
	LDA $7FAB4C,X				; set the initial speed based on the second extension byte
	STA $187B,X
	
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$0E : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$14 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	LDA #$FD : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites (vanilla flying item block = #$01)
	LDA #$FE : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites (vanilla flying item block = #$FE)
	LDA #$15 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites (vanilla flying item block = #$0D)
	LDA #$16 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites (vanilla flying item block = #$16)
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	LDA $14C8,X					; if the sprite is dead, only draw graphics
	CMP #$08
	BNE .gfx
	
	LDA $E4,X					; store the sprite's coordinates (checked for interaction with other sprites)
	STA $C2,X
	LDA $14E0,X
	STA $151C,X
	LDA $D8,X
	STA $1594,X
	LDA $14D4,X
	STA $160E,X
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleDirection
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	
	JSR HandleBlockCheck
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleDirection:	%LineGuided_HandleDirection() : RTS


HandleMarioContact:
	%SolidSprite_MarioContact()	; handle custom solid block interaction with Mario
	RTS


WingTiles:
	db $5D,$C6,$5D,$C6
WingSize:
	db $00,$02,$00,$02
WingXDisp:
	db $FD,$F5,$0B,$0B
WingYDisp:
	db $FE,$F6,$FE,$F6
WingProps:
	db $76,$76,$36,$36

BounceYOffset:
	db $00,$03,$05,$07,$08,$08,$07,$05,$03

Graphics:
	LDA $1558,X					; store the sprite's bounce animation y offset to scratch ram
	TAY
	LDA BounceYOffset,Y
	STA $04
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; BLOCK GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	SEC : SBC $04				; add the bounce animation y offset
	STA $0301,Y
	
	LDA #$46					; tile ID
	STA $0302,Y
	
	LDA #%00100100				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

; WINGS GRAPHICS
	LDA $7FAB58,X				; if the block is not flying, don't draw wings
	BNE .skipwings
	
	LDA $14						; load the frame counter
	LSR #3						; store the wings animation frame into scratch ram (2 animation frames of 8 frames each)
	AND #$01
	STA $02
	
	LDX #$01					; use X for the loop counter - X is set to #$01 since there are 2 wing tiles

.WingsLoop
	INY #4						; increment Y (the OAM index) by 4
	
	PHX							; load the loop counter, multiply it by 2, add the animation frame (0 or 1), and store it to X
	TXA
	ASL
	CLC : ADC $02
	TAX
	
	LDA $00						; offset the wing tile's x position from the sprite's x depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingXDisp,X
	STA $0300,Y
	
	LDA $01						; offset the wing tile's y position from the sprite's y depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingYDisp,X
	STA $0301,Y
	
	LDA WingTiles,X				; store tilemap number (see Map8 in LM) based on the wing tile and animation frame to OAM
	STA $0302,Y
	
	LDA $64						; store the priority and other properties to OAM
	ORA WingProps,X
	STA $0303,Y
	
	PHY							; set the tile size depending on the animation frame (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA WingSize,X
	STA $0460,Y
	PLY
	
	PLX
	
	DEX							; decrement the loop counter and loop to draw the second wing tile if the loop counter is still positive
	BPL .WingsLoop
	
	LDX $15E9					; restore the sprite slot into X

.skipwings
	LDA #$02					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


HandleBlockCheck:
	LDA $157C,X					; point to different routines based on the direction
	JSL $0086DF
		dw CheckMovingRight
		dw CheckMovingLeft
		dw CheckMovingUp
		dw CheckMovingDown

CheckMovingRight:
	LDA $E4,X					; if the sprite is on the right half of a tile, check for the next block
	AND #%00001111
	CMP #$08
	BCS SkipBlockCheck
	BRA DoBlockCheck
	RTS

CheckMovingLeft:
	LDA $E4,X					; if the sprite is on the left half of a tile, check for the next block
	DEC A
	AND #%00001111
	CMP #$08
	BCC SkipBlockCheck
	BRA DoBlockCheck
	RTS

CheckMovingUp:
	LDA $D8,X					; if the sprite is on the top half of a tile, check for the next block
	AND #%00001111
	CMP #$08
	BCC SkipBlockCheck
	BRA DoBlockCheck
	RTS

CheckMovingDown:
	LDA $D8,X					; if the sprite is on the bottom half of a tile, check for the next block
	INC A
	AND #%00001111
	CMP #$08
	BCS SkipBlockCheck
	BRA DoBlockCheck
	RTS

SkipBlockCheck:
	STZ $1626,X					; set the block check flag to 0
	RTS


DoBlockCheck:
	LDA $1626,X					; if the block check flag is 0...
	BNE .return
	
	INC $1626,X					; set the block check flag to 1
	JSR EraseBlock
	JSR HandleRotation

.return
	RTS


EraseBlock:
	LDA $14E0,X					; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008			; add 8 pixels
	STA $9A						; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X					; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0008			; add 8 pixels
	STA $98						; store it to the block interaction point y
	SEP #$20
	
	REP #$20					; change tile to non-solid
	LDA #$0025
	STZ $1933					; layer 1
	%ChangeMap16()
	SEP #$20
	RTS


BlockCheckX:
	dw $0018,$FFF8,$0008,$0008		; right, left, up, down
BlockCheckY:
	dw $0008,$0008,$FFF8,$0018

HandleRotation:
	LDY #$00					; load 0 as an index (direction to check for the next block)

.checkloop
	PHY
	TYA							; multiply the index by 2 (for 16-bit offset)
	ASL
	TAY
	
	LDA $14E0,X					; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC BlockCheckX,Y		; add the x offset based on the index
	STA $9A						; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X					; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC BlockCheckY,Y		; add the y offset based on the index
	STA $98						; store it to the block interaction point y
	SEP #$20
	
	STZ $1933					; if the Map16 tile is 25...
	%GetMap16()
	PLY
	REP #$20
	CMP #$0025
	SEP #$20
	BNE .blockfound
	
	CPY #$03					; if the index is 3 (final block check)...
	BNE +
	%SmokeKillSprite()			; (no solid blocks were found on any side) erase the sprite with smoke
	+
	INY							; else, increase the index and restart the loop
	BRA .checkloop

.blockfound
	TYA							; else (Map16 tile is not 25), set the sprite's movement direction equal to the index
	STA $157C,X
	
	LDA $E4,X					; make sure the sprite is positioned directly on the tile it just ate
	CLC : ADC #$08
	AND #%11110000
	STA $E4,X
	
	LDA $D8,X
	CLC : ADC #$08
	AND #%11110000
	DEC A
	STA $D8,X
	RTS