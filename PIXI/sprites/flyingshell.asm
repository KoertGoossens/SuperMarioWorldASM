; flying shell that Mario can grab or bump; it can float in place, or move linearly based on the extension bytes
; the first extension byte sets the shell type:
;	- first 2 bits:		jump effect		+00		=	vanilla green shell
;										+01		=	single-bounce shell (goes poof when jumped off)
;										+02		=	infinite-bounce shell (stays in kicked state when jumped off)
;										+03		=	regrab shell (gets set to carried state when jumped off while holding Y/X)
;	- bit 3:			disco			+04		=	disco shell (spawns in carryable state unless the kicked bit is set)
; the second extension byte sets the x speed
; the third extension byte sets the y speed

; $154C,X	=	timer to disable contact with Mario
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
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	INC $1570,X					; increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $1490					; if Mario has star power, kill the sprite
	BEQ +
	%SlideStarKillSprite()
	RTS
	+
	
	LDA $154C,X					; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR CarriableInteraction
	
	LDA $14C8,X					; if the sprite is not in carryable status anymore (it was grabbed or bumped)...
	CMP #$09
	BEQ .return
	
	LDA #$0F					; change the PIXI list ID to a regular shell
	STA $7FAB9E,X

.return
	RTS


CarriableInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, don't spinkill it
	BCC .skipspinkill
	
	LDA $140D					; if Mario is spinjumping...
	ORA $187A					; or on Yoshi...
	BEQ +
	%SpinKillSprite()			; spinkill the sprite
	RTS
	+

.skipspinkill
	%CheckCarryItem()			; else, handle grabbing the item
	LDA $14C8,X					; if the item wasn't grabbed, bump it
	CMP #$0B
	BEQ +
	%HandleBumpItem()
	+
	
	RTS


TilePalette:
	db %00001010,%00001100,%00000010,%00000100
WingTiles:
	db $5D,$C6,$5D,$C6
WingSize:
	db $00,$02,$00,$02
WingXDisp:
	db $FB,$F3,$0D,$0D
WingYDisp:
	db $02,$FA,$02,$FA
WingProps:
	db $76,$76,$36,$36

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
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

; WINGS GRAPHICS
	LDA $1570,X					; store the wings animation frame into scratch ram (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
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
	
	LDA #$02					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS