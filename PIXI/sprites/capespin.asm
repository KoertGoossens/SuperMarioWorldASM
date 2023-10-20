; capespin sprite that can kill/stun other sprites
; the extension byte sets the duration of the capespin

; $15AC,X	=	capespin timer


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
	LDA $7FAB40,X				; set the capespin timer based on the extension byte
	STA $15AC,X
	
	LDA #$F3 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$10 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$29 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0C : STA $7FB654,X	; sprite hitbox height for interaction with other sprites (vanilla = #$0F)
	
	LDA $01						; set the sprite's x speed to leftward to allow for horizontal block interaction check
	STA $B6,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	LDA $7FAB40,X				; if the extension byte is #$FF (spinning)...
	BPL +
	
	LDA $140D					; and Mario is not spinning, erase the sprite
	BEQ .erasesprite
	BRA .skiperasesprite
	+
	
	LDA $15AC,X					; else (the extension byte is not #$FF), if the capespin timer is at 0, erase the sprite
	BNE .skiperasesprite

.erasesprite
	STZ $14C8,X					; erase the sprite

.skiperasesprite
	LDA $9D						; return if the game is frozen
	BNE .return
	
	JSR HandleBlockInteraction
	JSR HandleSpriteInteraction

.return
	RTS


BlockInteractionXOffset:
	dw $FFF4,$0017,$FFF4,$0017
BlockInteractionYOffset:
	dw $0010,$0010,$0018,$0018

HandleBlockInteraction:
	LDY #$06					; load a loop index

.blockinteractionloop
	REP #$20					; offset the sprite's x from Mario's x for left-side block interaction based on the index
	LDA $D1
	CLC : ADC BlockInteractionXOffset,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	REP #$20					; offset the sprite's y from Mario's y for block interaction based on the index
	LDA $D3
	CLC : ADC BlockInteractionYOffset,Y
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	PHY							; handle block interaction
	JSL $019138
	PLY
	
	DEY #2						; decrement the loop index by 2
	BPL .blockinteractionloop	; if still positive, loop back
	RTS


HandleSpriteInteraction:
	LDA $D1					; set the sprite's x equal to Mario's x for sprite interaction
	STA $E4,X
	LDA $D2
	STA $14E0,X
	
	LDA $D3					; set the sprite's y equal to Mario's y for sprite interaction
	STA $D8,X
	LDA $D4
	STA $14D4,X
	
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the item sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	LDA $154C,Y				; if the indexed sprite has the 'disable contact with Mario' timer set...
	ORA $1564,X				; or if the item sprite has the 'disable contact with other sprites' timer set...
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
	db $01,$00,$00,$00,$06,$08,$07,$00,$01,$01,$00,$00,$09,$01,$00,$00		; 10 = flying dino, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1C = mushroom, 1D = tallguy
	db $01,$01,$04,$00,$00,$00,$01,$00,$00,$00,$00,$03,$00,$00,$00,$00		; 20 = sparky, 21 = buster beetle, 22 = buzzy beetle, 26 = chuckoomba, 2B = surfboard
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
	PHX
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