; cloud platform sprite that is solid on the top for Mario
; the first extension byte sets the x speed for flying blocks, or the initial direction for line-guided blocks
; the second extension byte sets the y speed for flying blocks, or the absolute speed for line-guided blocks
; the third extension byte sets the type:
;	+10		=	flying (0) vs line-guided (10)

; $C2,X		=	stored x position (low byte)
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
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	
	JSR CheckLineGuided			; if the block is line-guided...
	BEQ +
	JSL $019138					; process interaction with blocks
	JSR HandleRotation
	+
	
	JSR HandleMarioContact

.return
	RTS


HandleDirection:	%LineGuided_HandleDirection() : RTS
HandleRotation:		%LineGuided_HandleRotation() : RTS


HandleMarioContact:
	%CheckSpriteMarioContact()			; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	%SemiSolidSprite_MarioContact()

.return
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$4D					; tile ID
	STA $0302,Y
	
	LDA #%00101011				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


CheckLineGuided:
	LDA $7FAB58,X
	AND #%00010000
	RTS