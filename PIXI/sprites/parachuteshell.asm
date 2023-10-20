; shell hanging from a parachute; it will drop a shell if Mario gets horizontally close
; the extension byte sets the shell type:
;	- first 2 bits:		jump effect		+00		=	vanilla green shell
;										+01		=	single-bounce shell (goes poof when jumped off)
;										+02		=	infinite-bounce shell (stays in kicked state when jumped off)
;										+03		=	regrab shell (gets set to carried state when jumped off while holding Y/X)
;	- bit 3:			disco			+04		=	disco shell (spawns in carryable state unless the kicked bit is set)
; the second extension byte sets the x speed
; the third extension byte sets the y speed

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

print "CARRIABLE ",pc
	PHB
	PHK
	PLB
	JSR CarriableCode
	PLB
	RTL


InitCode:
	LDA $7FAB4C,X				; set x speed based on the value in the second extension byte
	STA $B6,X
	LDA $7FAB58,X				; set y speed based on the value in the third extension byte
	STA $AA,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%RaiseSprite1Pixel()
	
	LDA #$09					; set the sprite status to carryable and run the carryable code
	STA $14C8,X
	BRA CarriableCode


; NORMAL STATUS (FOR KILLED STATUS GFX)
SpriteCode:
	JSR Graphics
	RTS


; CARRIABLE STATUS
CarriableCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleDropSprite

.return
	RTS


HandleDropSprite:
	LDA #$0F					; handle dropping a shell
	STA $0F
	%HandleParachuteSprite()
	
	LDA $7FAB40,X				; transfer the shell type
	PHX
	TYX
	STA $7FAB40,X
	PLX
	RTS


TilePalette:
	db %00001010,%00001100,%00000010,%00000100

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; SHELL GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$8C					; tile ID
	STA $0302,Y
	
	PHY							; handle tile YXPPCCCT properties
	
	LDA $7FAB40,X				; if the 3rd bit of the first extension byte is set (disco shell)...
	AND #%00000100
	BEQ .nodisco
	
	LDA $13						; cycle through the palettes every other frame
	AND #%00001110
	BRA .paletteloaded

.nodisco
	LDA $7FAB40,X				; load the palette based on the shell's jump effect (set by the first extension byte)
	AND #%00000011
	TAY
	LDA TilePalette,Y

.paletteloaded
	PLY
	ORA $15F6,X					; flip y based on the stored YXPPCCCT properties (set by quake sprites externally)
	ORA $64
	STA $0303,Y
	
	INY #4

; PARACHUTE GRAPHICS
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