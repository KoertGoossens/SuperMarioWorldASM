; flame sprite, spawned by fireflower Mario by pressing L or R (see level UberASM)
; it can smoke-kill many sprites, or set off an explosion when touching certain sprites (bob-omb, bullet bill, etc.)
; it is erased when touching solid blocks and block sprites

; $C2,X		=	sprite contact type
; $1570,X	=	animation frame counter
; $157C,X	=	face direction


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


SpawnX:
	dw $0008,$FFF8
XSpeed:
	db $C0,$40

InitCode:
	LDA $140D					; skip if not spinning
	BEQ .nospin
	
	LDA $15						; if right is pressed, shoot right
	AND #%00000001
	BNE .spinshootright
	
	LDA $15						; else, if left is pressed, shoot left
	AND #%00000010
	BNE .spinshootleft
	
	LDA $7B						; else (neutral dpad), if positive or 0 x speed, shoot right, otherwise shoot left
	BPL .spinshootright

.spinshootleft
	LDY #$00
	BRA .shotdirectionset

.spinshootright
	LDY #$01
	BRA .shotdirectionset

.nospin
	LDY $76						; store Mario's face direction x2 as index

.shotdirectionset
	LDA XSpeed,Y				; set the x speed based on Mario's face direction
;	CLC : ADC $7B				; add Mario's x speed
	STA $B6,X
	
	TYA							; set the sprite's face direction inverted to Mario's face direction
	EOR #$01
	STA $157C,X
	
	ASL							; set the flame 8 pixels to the side of Mario based on the index
	TAY
	REP #$20
	LDA $94
	CLC : ADC SpawnX,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	REP #$20					; set the flame 8 pixels below Mario
	LDA $96
	CLC : ADC #$0008
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA $15						; if holding up, give the flame upward speed
	AND #%00001000
	BEQ +
	LDA #$C0
	STA $AA,X
	+
	
	LDA $15						; if holding down, give the flame downward speed
	AND #%00000100
	BEQ +
	LDA #$40
	STA $AA,X
	+
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	LDA $14C8,X					; if the sprite is dead, only draw graphics
	CMP #$08
	BNE .gfx
	
	INC $1570,X					; increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSL $019138					; process interaction with blocks
	
	LDA $1588,X					; if the flame touches a solid tile from any side, smokekill it
	AND #%00001111
	BEQ +
	%SmokeKillSprite()
	+
	
	JSR HandleSpriteInteraction

.gfx
	JSR Graphics
	RTS


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the item sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	LDA $1686,Y				; if the indexed sprite doesn't interact with other sprites...
	AND #%00001000
	ORA $1564,X				; or the item sprite has the 'disable contact with other sprites' timer set...
	ORA $1564,Y				; or the indexed sprite has the 'disable contact with other sprites' timer set...
	ORA $15D0,Y				; or the indexed sprite is on Yoshi's tongue...
	ORA $1632,X				; or the item sprite isn't on the same 'layer' as the indexed sprite (i.e. behind net)...
	EOR $1632,Y
	BNE .loopcontinue		; don't check for contact
	
	JSR CheckSpriteContact	; check for contact with the indexed sprite

.loopcontinue				; else, check the next sprite
	DEY
	BPL .loopstart

.return
	RTS


CheckSpriteContact:
	%CheckSpriteSpriteContact()				; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContactType:
	db $01,$01,$00,$01,$03,$01,$00,$02,$01,$01,$01,$01,$02,$01,$01,$01		; 0 = dino, 1 = mole, 3 = goomba, 4 = taptap, 5 = flying spiny, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $01,$00,$01,$01,$01,$02,$01,$00,$01,$01,$03,$01,$00,$01,$00,$00		; 10 = flying dino, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1A = flying taptap, 1B = flying milde, 1D = tallguy
	db $00,$01,$01,$00,$00,$00,$01,$00,$03,$00,$00,$01,$00,$00,$00,$00		; 21 = buster beetle, 22 = buzzy beetle, 26 = chuckoomba, 28 = carry block, 2B = surfboard
	db $00,$00,$01,$03,$01,$01,$00,$01,$00,$01,$00,$00,$01,$01,$00,$00		; 32 = parabeetle, 33 = chomp, 34 = ninji, 35 = spiny, 37 = piranha plant, 39 = bouncing rock, 3C = vine koopa, 3D = fuzzy
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$03,$03,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00		; 54 = polarity block, 55 = arrow block, 58 = parachute dino, 59 = parachute thwimp, 5A = parachute shell
	db $03,$03,$03,$03,$03,$00,$03,$00,$03,$00,$03,$00,$00,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = switch block, 66 = used block, 68 = eating block, 6A = walking block
	db $03,$03,$03,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 78 = sticky block

SpriteContact:
	PHY							; store the contact type to scratch ram based on the indexed sprite's ID
	PHX
	TYX
	LDA $7FAB9E,X
	PLX
	TAY
	LDA SpriteContactType,Y
	STA $C2,X
	PLY
	
	LDA $C2,X					; point to different routines based on the contact type
	JSL $0086DF
		dw .return
		dw BurnSprite
		dw ExplodeSprite
		dw BlockSprite

.return
	RTS


BurnSprite:
	LDA #$31					; play burn sfx
	STA $1DFC
	
	LDA #$04					; set the indexed sprite's status to 'erased in smoke'
	STA $14C8,Y
	
	LDA #$1F					; set the indexed sprite's death frame counter (for smoke animation)
	STA $1540,Y
	RTS


ExplodeSprite:
	LDA #$1A					; play explosion sfx
	STA $1DFC
	
	STZ $14C8,X					; erase the flame
	
	PHX
	TYX
	
	LDA #$49					; spawn explosion
	%SpawnCustomSprite()
	
	LDA $E4,X					; copy the x and y positions from the indexed sprite to the spawned sprite
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	STZ $14C8,X					; erase the indexed sprite
	PLX
	RTS


BlockSprite:
	%SolidSprite_SetupInteract()		; check for interaction with the block sprite on all sides
	
	LDA $08								; if touching the top, smokekill the flame
	BEQ .smokekill
	LDA $09								; else, if touching the bottom, smokekill the flame
	BEQ .smokekill
	LDA $0A								; else, if touching the side, smokekill the flame
	BEQ .smokekill
	RTS

.smokekill
	%SmokeKillSprite()
	RTS


Tilemap:
	db $80,$82

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHX
	LDA $14
	LSR #3
	AND #$01
	TAX
	LDA Tilemap,X				; tile ID
	STA $0302,Y
	PLX
	
	LDA #%00100101				; load tile YXPPCCCT properties
	PHY
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS