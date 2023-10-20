; dino hanging from a parachute; it will drop a regular dino if Mario gets horizontally close

; $C2,X		=	phase (0 = hanging, 1 = drop sprite)
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter


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
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%RaiseSprite1Pixel()
	
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
	
	INC $1570,X					; increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleDropSprite

.return
	RTS


HandleDropSprite:
	STZ $0F						; handle dropping a dino sprite
	%HandleParachuteSprite()
	LDA #$00					; set the dino's x speed to 0
	STA $7FAB40,X
	STA $7FAB4C,X				; set the dino to not spawn with a shell
	RTS


Tilemap:
	db $86,$84

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; dino tile
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $1570,X					; store the animation frame into Y (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	TAY
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	LDA #%00100000				; load tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	INY #4

; parachute tile
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; offset the parachute tile 15 pixels above the hanging sprite
	SEC : SBC #$0F
	STA $0301,Y
	
	LDA #$88					; tile ID
	STA $0302,Y
	
	LDA #%00100110				; load tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$01					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS