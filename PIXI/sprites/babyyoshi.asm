; custom baby Yoshi
; the extension byte sets the type:
;	0	=	grows into adult Yoshi after eating 1 sprite
;	1	=	eats infinitely, never grows
;	2	=	eats infinitely, grows by pressing L/R

; $1540,X	=	transform cooldown timer
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1602,X	=	animation frame
; $160E,X	=	sprite slot of the sprite baby Yoshi is eating
; $163E,X	=	eat timer

!GrowManual			=	#$01		; set to 1 to have baby Yoshi grow instantly when pressing L


print "INIT ",pc
	PHB
	PHK
	PLB
	JSR InitCode
	PLB
	RTL

print "CARRIABLE ",pc
	PHB
	PHK
	PLB
	JSR CarriableCode
	PLB
	RTL

print "KICKED ",pc
	PHB
	PHK
	PLB
	JSR KickedCode
	PLB
	RTL

print "CARRIED ",pc
	PHB
	PHK
	PLB
	JSR CarriedCode
	PLB
	RTL


InitCode:
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset
	LDA #$0C : STA $7FB618,X	; sprite hitbox width
	LDA #$0A : STA $7FB624,X	; sprite hitbox height
	
	LDA #$02 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0B : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	INC $157C,X					; set the baby Yoshi to face left
	
	LDA #$09					; set the sprite status to carryable and run the carryable code
	STA $14C8,X
	BRA CarriableCode


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	JSR HandleBlockInteraction
	JSR HandleMarioContact
	JSR HandleSpriteInteraction
	JSR MiscRoutines

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR CarriableInteraction

.return
	RTS


CarriableInteraction:
	%CheckCarryItem()			; handle grabbing the item
	LDA $14C8,X					; if the item wasn't grabbed, bump it
	CMP #$0B
	BEQ +
	%HandleBumpItem()
	+
	
	RTS


; KICKED STATUS
KickedCode:
	JSR Graphics
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	JSR HandleSpriteInteraction
	JSR MiscRoutines
	
	LDA $1419					; if Mario is not going down a pipe, and not holding Y/X, release the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	
	%ReleaseItem_Standard()

.gfx
	LDA $76						; set the sprite's face direction opposite to Mario's face direction
	EOR #$01
	STA $157C,X
	
	LDA $64						; handle OAM priority and draw graphics
	PHA
	%HandleOAMPriority()
	JSR Graphics
	PLA
	STA $64
	RTS


Tilemap:
	db $68,$6A,$6C,$6E,$22
TileProp:
	db %00001011,%00001101,%00001111

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $1602,X					; load tile based on the animation frame
	TAY
	LDA Tilemap,Y
	PLY
	STA $0302,Y
	
	PHY
	LDA $7FAB40,X				; load tile YXPPCCCT properties based on the type
	TAY
	LDA TileProp,Y
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


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	STY $00					; if the index is the same as the calling sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	TYA						; if the indexed sprite is already being eaten by baby Yoshi, don't check for contact
	CMP $160E,X
	BEQ .loopcontinue
	
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
	%CheckSpriteSpriteContact()			; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	
	JSR SpriteContact

.return
	RTS


SpriteContactType:
	db $01,$01,$00,$01,$00,$01,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01		; 0 = dino, 1 = mole, 3 = goomba, 5 = flying spiny, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $01,$01,$01,$01,$01,$01,$01,$00,$01,$01,$00,$01,$01,$01,$00,$00		; 10 = flying dino, 11 = flying coin, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1B = flying milde, 1C = mushroom, 1D = tallguy
	db $00,$01,$01,$00,$00,$00,$01,$00,$02,$00,$00,$01,$00,$00,$00,$00		; 21 = buster beetle, 22 = buzzy beetle, 26 = chuckoomba, 28 = carry block, 2B = surfboard
	db $00,$00,$01,$00,$01,$01,$00,$01,$00,$01,$00,$00,$01,$01,$00,$00		; 32 = parabeetle, 34 = ninji, 35 = spiny, 37 = piranha plant, 39 = bouncing rock, 3C = vine koopa, 3D = fuzzy
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$02,$02,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00		; 54 = polarity block, 55 = arrow block, 58 = parachute dino, 59 = parachute spiny, 5A = parachute shell
	db $02,$02,$02,$02,$02,$00,$02,$00,$02,$00,$02,$00,$00,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = switch block, 66 = used block, 68 = eating block, 6A = walking block
	db $02,$02,$02,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 78 = sticky block

SpriteContact:
	PHY									; store the contact type to scratch ram based on the indexed sprite's ID
	PHX
	TYX
	LDA $7FAB9E,X
	PLX
	TAY
	LDA SpriteContactType,Y
	STA $0F
	PLY
	
	LDA $0F								; point to different routines based on the contact type
	JSL $0086DF
		dw .return
		dw SpriteContact_Eat
		dw SpriteContact_Solid

.return
	RTS


SpriteContact_Eat:
	LDA $14C8,X							; if the baby Yoshi is not in carried status, eat the indexed sprite
	CMP #$0B
	BNE .eatsprite
	
	LDA $14D4,Y							; else, if Mario's y is low enough compared to the indexed sprite's y, have baby Yoshi eat the indexed sprite
	XBA									; (this prevents a carried item from clashing with a sprite that Mario bounces off)
	LDA $D8,Y
	REP #$20
	SEC : SBC $96
	SBC #$0018
	BPL +
	SEP #$20
	BRA .eatsprite
	+
	SEP #$20
	RTS

.eatsprite
	LDA $163E,X							; if the eat timer is set, return
	BNE .return
	
	LDA #$20							; set the eat timer
	STA $163E,X
	
	LDA #$FF
	STA $154C,Y							; set the indexed sprite to not interact with Mario
	STA $1564,Y							; set the indexed sprite to not interact with other sprites
	
	TYA									; store the sprite slot of the indexed sprite
	STA $160E,X

.return
	RTS


SpriteContact_Solid:
	LDA $14C8,X							; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


Cnt_SolidSprite_Carryable:		%SolidSpriteInteraction_Carryable() : RTS


MiscRoutines:
	JSR CheckManualGrow
	
	LDA $163E,X					; if the eat timer is set, branch
	BNE .handleeating
	
	LDA #$FF					; else, set the sprite slot of the sprite baby Yoshi is eating to #$FF (= not eating)
	STA $160E,X
	
	LDA $14C8,X					; if the sprite is in carryable status...
	CMP #$09
	BNE +
	LDA $1588,X					; and on the ground...
	AND #%00000100
	BEQ +
	LDA #$F0					; give it some upward speed
	STA $AA,X
	+
	
	LDY #$00					; set animation frame 0 (24 frames) or 3 (8 frames) based on the global timer
	LDA $14
	AND #%00011000
	BNE +
	LDY #$03
	+
	TYA
	STA $1602,X
	RTS

.handleeating
	STZ $15EA,X					; set OAM index to 0, so Yoshi draws in front of all other sprites
	
	LDA $163E,X					; if the eat timer is above #$10, handle eating the sprite prior to swallowing it
	CMP #$11
	BCS EatSprite
	CMP #$10					; else, if the eat timer is at #$10, swallow the sprite
	BEQ SwallowSprite
	CMP #$08					; else, if the eat timer is at #$08...
	BNE .return
	
	LDA $7FAB40,X				; if baby Yoshi is set to grow after eating a sprite, do so
	BEQ GrowYoshi

.return
	RTS


EatSprite:
	LDA #$01					; set the animation frame to 1 (mouth open)
	STA $1602,X
	
	LDY $160E,X
	
	LDA $163E,X					; store the (eat timer - #$10)/2 to scratch ram
	SEC : SBC #$10
	LSR
	CLC : ADC #$04				; add 4 pixels
	STA $00
	STZ $01
	
	LDA $157C,X					; if facing left...
	BEQ +
	REP #$20
	LDA $00						; invert the scratch ram value
	EOR #$FFFF
	INC A
	STA $00
	SEP #$20
	+
	
	LDA $14E0,X					; set the indexed sprite's x to baby Yoshi's x...
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC $00				; + the scratch ram value
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $D8,X					; set the indexed sprite's y equal to baby Yoshi's y
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	LDA #$00					; set the indexed sprite's y speed to 0 (so it doesn't still oscillate the y position as a result of gravity, which happens in vanilla)
	STA $AA,Y
	RTS


SwallowSprite:
	LDY $160E,X					; erase the indexed sprite
	LDA #$00
	STA $14C8,Y
	
	LDA #$06					; play swallow sfx
	STA $1DF9
	
	LDA #$02					; else, set the animation frame to 2 (full mouth)
	STA $1602,X
	RTS


GrowYoshi:
	STZ $01						; spawn smoke with 0 x/y offset from the baby Yoshi
	STZ $02
	%SpawnSpriteSmoke()
	
	LDA #$1F					; play Yoshi grow sfx
	STA $1DFC
	
	LDA #$24					; adult Yoshi (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA $E4,X					; set the adult Yoshi's x equal to the baby Yoshi's x
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	
	LDA $14D4,X					; set the adult Yoshi's y 16 pixels above the baby Yoshi's y
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0010
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA #$04					; set the adult Yoshi's transform cooldown timer to 4 frames
	STA $1540,Y
	
	LDA $14C8,X					; if baby Yoshi is in carried status...
	CMP #$0B
	BNE .babyyoshicarryable
	
	LDA $7B						; transfer Mario's x and y speeds to adult Yoshi
	STA $B6,Y
	LDA $7D
	STA $AA,Y
	BRA .speedsset

.babyyoshicarryable				; else (carryable status)...
	LDA $B6,X					; transfer baby Yoshi's x and y speeds to adult Yoshi
	STA $B6,Y
	LDA $AA,X
	STA $AA,Y

.speedsset
	LDA $157C,X					; transfer baby Yoshi's face direction to adult Yoshi
	STA $157C,Y
	
	STZ $14C8,X					; erase the baby Yoshi
	RTS


CheckManualGrow:
	LDA $7FAB40,X				; if baby Yoshi is set to grow when pressing L...
	CMP #$02
	BNE .return
	
	LDA $18						; and L is pressed...
	AND #%00100000
	BEQ .return
	
	LDA $1540,X					; and the transform cooldown timer is not set...
	BNE .return
	
	LDA $14C8,X					; store the sprite status to scratch ram
	STA $08
	
	JSR GrowYoshi				; turn baby Yoshi into adult Yoshi immediately
	
	LDA #$01					; store an adult Yoshi type of 1 (custom) to scratch ram
	STA $00
	
	LDA $08						; if the baby Yoshi's sprite status was 'carried'...
	CMP #$0B
	BNE +
	INC $00						; increase the adult Yoshi type to 2 (custom + auto-mount)
	+
	
	LDA $00						; set adult Yoshi to be mounted immediately
	PHX
	TYX
	STA $7FAB40,X
	PLX

.return
	RTS