; shyguy that can be jumped on to kill it
; the first extension byte sets the walking speed
; the second extension byte sets the type (0 = normal, 1 = chases Mario)

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
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


InitCode:
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%SubHorzPos()				; set the sprite to face Mario
	TYA
	STA $157C,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; branch if the sprite is dead
	CMP #$08
	BNE .return
	
	INC $1570,X					; else, increment the animation frame counter
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleSpeed
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


HandleGravity:		%ApplyGravity() : RTS


HandleSpeed:
	LDA $15AC,X					; if set to interact with blocks...
	BNE .skipblockcheck
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $157C,X					; invert the face direction
	EOR #$01
	STA $157C,X
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()

.skipblockcheck
	LDA $7FAB4C,X				; if the type is 'chases Mario'...
	BNE .typechase
	
	LDA $7FAB40,X				; set the x speed based on the first extension byte
	PHY
	LDY $157C,X					; invert the x speed based on the face direction
	BEQ +
	EOR #$FF
	INC A
	+
	PLY
	STA $B6,X
	BRA .typechecked

.typechase
	%SubHorzPos()				; compare the sprite's horizontal position to Mario's (output to Y)
	BNE .discomoveleft			; if facing left, branch to .discomoveleft
	LDA $B6,X					; if the x speed is below the max speed, increase it by 2
	CMP #$20
	BPL .chasespeedset
	CLC : ADC #$02
	STA $B6,X
	BRA .chasespeedset

.discomoveleft
	LDA $B6,X					; if the x speed is above the min speed, decrease it by 2
	CMP #$E0
	BMI .chasespeedset
	SEC : SBC #$02
	STA $B6,X

.chasespeedset
	%SubHorzPos()				; set the sprite to always face Mario
	TYA
	STA $157C,X

.typechecked
	LDA $1588,X					; if the sprite is in the air...
	AND #%00000100
	BNE +
	STZ $1570,X					; set the animation frame counter to 0
	+
	
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
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; else if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BounceMarioNormal:
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
	LDA #$02					; set the sprite status to killed
	STA $14C8,X
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


SpriteContact:
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	
	LDA $14C8,Y
	CMP #$08					; if the indexed sprite is also in normal status...
	BEQ DoBumpSprites			; turn both sprites around (for indexed sprites in item statuses, the indexed sprite should initiate the contact check)
	
	RTS


DoBumpSprites:			%BumpSprites() : RTS
Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS


Tilemap:
	db $A0,$A2
TileProp:
	db %00101001,%00100101

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
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
	
	PHY
	LDA $7FAB4C,X				; load tile YXPPCCCT properties based on the second extension byte
	TAY
	LDA TileProp,Y
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	LDY $14C8,X					; flip y if the sprite is dead
	CPY #$08
	BCS +
	EOR #%10000000
	+
	
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS