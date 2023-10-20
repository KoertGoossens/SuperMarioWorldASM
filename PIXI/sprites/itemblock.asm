; block platform sprite that you can get an item out of like with a vanilla item block
; the first extension byte sets the x speed for flying blocks, or the initial direction for line-guided blocks
; the second extension byte sets the y speed for flying blocks, or the absolute speed for line-guided blocks
; the third extension byte sets the type:
;	0		=	mushroom
;	1		=	shell
;	2		=	throwblock
;	3		=	p-switch
;	4		=	dino
;	5		=	spiny
;	6		=	goomba
;	+10		=	flying (0) vs line-guided (10)
; the fourth extension byte sets the sprite spawn direction (0 = right, 1 = left, 2 = up, 3 = down)

; $C2,X		=	stored x position (low byte)
; $1504,X	=	block interaction flag
; $151C,X	=	stored x position (high byte)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $1534,X	=	width (minus 16)
; $1558,X	=	activation timer
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
	%RaiseSprite1Pixel()
	
	STZ $1534,X					; set the width (16 pixels)
	STZ $1570,X					; set the height (16 pixels)
	
	JSR CheckLineGuided			; if the block is flying...
	BNE +
	LDA $7FAB40,X				; set x speed based on the value in the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set y speed based on the value in the second extension byte
	STA $AA,X
	BRA .speedset
	+
	
	LDA $7FAB40,X				; else (the block is line-guided), set the initial direction based on the first extension byte
	STA $157C,X
	STA $1626,X					; set the stored direction as well
	
	LDA $7FAB4C,X				; set the initial speed based on the second extension byte
	STA $187B,X

.speedset
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
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SolidInteractionVals()
	%SubOffScreen()				; call offscreen despawning routine
	
	JSR CheckLineGuided			; if the block is line-guided, handle the direction
	BEQ +
	JSR HandleDirection
	+
	
	LDA $7FAB58,X				; if the sprite is set to use gravity, branch
	AND #%00100000
	BNE .usegravity
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	
	JSR CheckLineGuided			; if the block is line-guided...
	BEQ +
	JSL $019138					; process interaction with blocks
	JSR HandleRotation
	+
	
	BRA .handlecontact

.usegravity
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $B6,X					; invert the x speed
	EOR #$FF
	INC A
	STA $B6,X
	+
	
	%HandleFloor()

.handlecontact
	JSR HandleMarioContact
	JSR HandleActivation

.return
	RTS


HandleGravity:
	%ApplyGravity()
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	RTS


HandleDirection:	%LineGuided_HandleDirection() : RTS
HandleRotation:		%LineGuided_HandleRotation() : RTS


HandleMarioContact:
	%SolidSprite_MarioContact()	; handle custom solid block interaction with Mario
	
	LDA $1504,X					; if the block interaction flag is 2 (hitting from below)...
	CMP #$02
	BNE .return
	LDA #$09					; set the activation timer
	STA $1558,X

.return
	RTS


SpawnSpriteID:
	db $1C,$0F,$0E,$02,$00,$35,$03		; mushroom, shell, throwblock, p-switch, dino, spiny, goomba
SpawnSpriteXOffset:
	dw $0008,$FFF8,$0000,$0000
SpawnSpriteYOffset:
	dw $0000,$0000,$FFF8,$0008
SpawnSpriteXSpeed:
	db $2E,$D2,$00,$00
SpawnSpriteYSpeed:
	db $00,$00,$C0,$00

HandleActivation:
	LDA $1558,X					; if the activation timer is set...
	BNE +
	RTS
	+
	
	LDA #$02					; play 'grow' sfx
	STA $1DFC
	
	LDA $7FAB58,X				; spawned a sprite with the ID based on the 3rd extension byte
	AND #%00001111
	TAY
	LDA SpawnSpriteID,Y
	%SpawnCustomSprite()
	
	PHX
	LDA $7FAB64,X				; store the spawned sprite's x and y speeds based on the sprite spawn direction to scratch ram
	TAX
	LDA SpawnSpriteXSpeed,X
	STA $0C
	LDA SpawnSpriteYSpeed,X
	STA $0D
	
	TXA							; store the spawned sprite's x and y offsets based on the sprite spawn direction to scratch ram
	ASL
	TAX
	REP #$20
	LDA SpawnSpriteXOffset,X
	STA $08
	LDA SpawnSpriteYOffset,X
	STA $0A
	SEP #$20
	PLX
	
	LDA $14E0,X					; set the spawned sprite's x based on the stored x offset
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC $08
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $14D4,X					; set the spawned sprite's y based on the stored y offset
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC $0A
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA $0C						; give the spawned sprite the stored x speed
	STA $B6,Y
	LDA $0D						; give the spawned sprite the stored y speed
	STA $AA,Y
	
	PHX
	TYX
	LDA $7FAB9E,X				; if the spawned sprite is a goomba...
	CMP #$03
	BNE +
	LDA #$00					; set the goomba's walking speed to 0
	STA $7FAB40,X
	LDA #$0A					; set the goomba's sprite status to kicked (load after init)
	STA $1594,X
	+
	
	LDA $B6,X					; if the spawned sprite's x speed is not 0 (it was shot horizontally)...
	BEQ .skiphoriz
	
	LDA $7FAB9E,X				; if the spawned sprite is a shell...
	CMP #$0F
	BEQ .setkicked
	CMP #$0E					; or a throwblock...
	BEQ .setkicked
	BRA .skipkicked

.setkicked
	LDA #$0A					; set the spawned sprite's status to kicked (load after init)
	STA $1594,X

.skipkicked
	CMP #$00
	BEQ .setxspeedalt
	CMP #$35
	BEQ .setxspeedalt
	BRA .skiphoriz

.setxspeedalt
	LDA $B6,X					; if the spawned sprite was given rightward speed...
	BMI +
	LDA #$20					; give it rightward speed through the extension byte (different speed value)
	BRA .setextbytexspeed
	+
	LDA #$E0					; else, give it leftward speed through the extension byte

.setextbytexspeed
	STA $7FAB40,X

.skiphoriz
	PLX
	
	%DisableInteraction_Spawned()
	
	LDA #$4A					; spawn a quake sprite
	%SpawnCustomSprite()
	
	LDA $E4,X					; put the quake sprite at the same position as the block sprite
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	LDA #$66					; change the item block's sprite ID to 'used block'
	STA $7FAB9E,X
	RTS


IconTileID:
	db $2C,$2C,$47,$47
IconTileProp:
	db %00100001,%01100001,%00100001,%10100001
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

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; ICON GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHX							; store the sprite spawn direction as an index
	LDA $7FAB64,X
	TAX
	
	LDA IconTileID,X			; set the tile ID based on the spawn direction
	STA $0302,Y
	
	LDA IconTileProp,X			; set the tile YXPPCCCT properties based on the spawn direction
	ORA $64
	STA $0303,Y
	PLX
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

; BLOCK GRAPHICS
	INY #4						; increment Y (the OAM index) by 4
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
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
	LDA #$03					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


CheckLineGuided:
	LDA $7FAB58,X
	AND #%00010000
	RTS