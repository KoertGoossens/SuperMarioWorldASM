; quake sprite that can kill/stun other sprites

; $15AC,X	=	quake timer


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
	LDA #$06					; set the quake timer to 6 frames
	STA $15AC,X
	
	LDA #$FC : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$FC : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$18 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$18 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA $14D4,X					; raise the sprite by 1 pixel (to counter sprites spawning 1 pixel below their intended position)
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
;	JSR Graphics
	
	LDA $15AC,X					; if the quake timer is at 0, erase the sprite
	BNE +
	STZ $14C8,X
	+
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleSpriteInteraction

.return
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
	
	LDA $1564,X				; if the item sprite has the 'disable contact with other sprites' timer set...
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
	LDA $1FE2,Y								; if the indexed sprite has the 'disable quake interaction timer' set, return
	BNE .return
	
	LDA $14C8,Y								; if the indexed sprite is in carried status, return
	CMP #$0B
	BEQ .return
	
	%CheckSpriteSpriteContact()				; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContactType:
	db $01,$01,$00,$04,$05,$01,$00,$02,$01,$01,$01,$01,$01,$05,$00,$03		; 0 = dino, 1 = mole, 3 = goomba, 4 = taptap, 5 = flying spiny, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, F = shell
	db $01,$00,$0A,$00,$06,$08,$07,$00,$01,$01,$00,$00,$09,$01,$00,$00		; 10 = flying dino, 12 = flying buzzy beetle, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1C = mushroom, 1D = tallguy
	db $01,$01,$03,$00,$00,$00,$01,$00,$00,$00,$00,$03,$00,$00,$00,$00		; 20 = sparky, 21 = buster beetle, 22 = buzzy beetle, 26 = chuckoomba, 2B = surfboard
	db $00,$00,$01,$00,$01,$01,$00,$01,$00,$01,$00,$00,$01,$01,$00,$00		; 32 = parabeetle, 34 = ninji, 35 = spiny, 37 = piranha plant, 39 = bouncing rock, 3C = vine koopa, 3D = fuzzy
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

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
		dw KillSprite
		dw StunGeneral
		dw StunShell
		dw StunGoomba
		dw BounceGeneral
		dw StunFlyingShell
		dw StunFlyingGoomba
		dw StunFlyingBobomb
		dw BounceMushroom
		dw StunFlyingBuzzyBeetle

.return
	RTS


KillSprite:
	LDA #$02					; set the sprite status to killed
	STA $14C8,Y
	
	BRA HitSprite

StunShell:
	LDA #%10000000				; set the y-flip flag for the shell
	STA $160E,Y
	
	BRA StunGeneral


StunGoomba:
	PHX
	TYX
	LDA $7FAB4C,X				; set the stun timer to the value specified by the second extension byte
	STA $1540,X
	PLX
	
	BRA StunGeneral


StunGeneral:
	LDA #$09					; set the sprite status to carryable
	STA $14C8,Y
	
	LDA #$08					; disable contact with Mario for 8 frames
	STA $154C,Y
	
	BRA HitSprite


QuakeClashXSpeed:
	db $F8,$08

HitSprite:
	PHX							; set the indexed sprite's x speed depending on the direction towards Mario
	PHY
	TYX
	JSL $01AB6F					; display 'hit' graphic at the indexed sprite's position
	%SubHorzPos()				; set the indexed sprite's x speed depending on the direction towards Mario
	LDA QuakeClashXSpeed,Y
	PLY
	PLX
	STA $B6,Y
	
	BRA BounceGeneral


BounceGeneral:
	LDA #$03					; play hit sfx
	STA $1DF9
	
	LDA #$C0					; give the indexed sprite upward y speed
	STA $AA,Y
	RTS


BounceMushroom:
	PHX							; set the indexed sprite's face direction depending on the direction towards Mario
	PHY
	TYX
	%SubHorzPos()
	TYA
	EOR #$01
	STA $157C,X
	PLY
	PLX
	
	BRA BounceGeneral


StunFlyingShell:
	PHX
	LDA #$0F					; change the PIXI list ID to a regular shell
	STA $7FAB9E,X
	PLX
	
	BRA StunShell


StunFlyingBuzzyBeetle:
	PHX
	LDA #$22					; change the PIXI list ID to a regular buzzy beetle
	STA $7FAB9E,X
	PLX
	
	BRA StunShell


StunFlyingGoomba:
	PHX
	TYX
	LDA #$03					; change the PIXI list ID to a regular goomba
	STA $7FAB9E,X
	PLX
	
	BRA StunGoomba


StunFlyingBobomb:
	PHX
	TYX
	LDA #$07					; change the PIXI list ID to a regular bob-omb
	STA $7FAB9E,X
	PLX
	
	BRA StunGeneral


TileProp:
	db %00100000,%01100000

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDY #$04					; set the OAM index to 4 to draw the quake gfx in front of other sprites
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$2E					; tile ID
	STA $0302,Y
	
	PHY
	LDA $15AC,X					; store the animation frame into Y (2 animation frames of 2 frames each)
	LSR
	AND #%00000001
	TAY
	LDA TileProp,Y				; tile YXPPCCCT properties based on the animation frame
	PLY
	
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA							; ALTHOUGH ONLY ONE TILES IS DRAWN, SETTING THE TILE SIZE SEEMS NECESSARY SINCE THE OAM INDEX WAS CHANGED MANUALLY
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS