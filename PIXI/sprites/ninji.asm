; jumping ninji
; the first extension byte sets the x speed						- base = $18
; the second extension byte sets the y speed (jump height)		- base = $B8
; the third extension byte sets the type:
;	+00 = moves horizontally in one direction,	+01 = follows Mario horizontally
;	+00	= normal gravity,						+02 = reverse gravity
;	+00 = single-hit,							+04 = invincible
;	(UNUSED)	+00 = jumps automatically,					+08 = jumps only when Mario jumps

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
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
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $B6,X					; invert the x speed
	EOR #$FF
	INC A
	STA $B6,X
	+
	
	LDA $B6,X					; if the x speed is not 0...
	BEQ +
	STZ $157C,X					; set the face direction based on the x speed
	BPL +
	INC $157C,X
	+
	
	LDA $7FAB58,X				; handle normal or reverse gravity based on the sprite's gravity bit and the gravity switch state
	AND #%00000010
	LSR
	EOR $1879
	BNE +
	JSR NormalGravity
	BRA .handleinteraction
	+
	JSR ReverseGravity

.handleinteraction
	%ProcessBlockInteraction()
	
	LDA $1588,X					; if the sprite is touching a ceiling...
	AND #%00001000
	BEQ +
	LDA $D8,X					; position the ninji below the ceiling tile
	AND #%11110000
	ORA #%00001110
	STA $D8,X
	+
	
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


NormalGravity:
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	LDA $1588,X					; if the sprite is touching a solid tile below...
	AND #%00000100
	BEQ .updatepos
	
	LDA $AA,X					; and it's not moving upward...
	BMI .updatepos
	
;	LDA $7FAB58,X				; if the jump type is 0 (jumps automatically), have it jump up
;	AND #%00001000
;	BEQ .dojump
;
;	LDA $77						; else (the type is 1 (jumps when Mario jumps)), if Mario is on solid ground...
;	AND #%00000100
;	BEQ .updatepos
;	LDA $16						; and B or A was pressed, have the ninji jump up
;	ORA $18
;	AND #%10000000
;	BEQ .updatepos
;
;.dojump
	JSR SetXSpeed
	
	LDA $7FAB4C,X				; set the y speed based on the second extension byte
	STA $AA,X

.updatepos
	%ApplyGravity()
	RTS


ReverseGravity:
	LDA $1588,X					; if the sprite touches a solid tile below...
	AND #%00000100
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	LDA $1588,X					; if the sprite is touching a ceiling...
	AND #%00001000
	BEQ .updatepos
	
	LDA $AA,X					; and it's not moving downward...
	BPL .updatepos
	
;	LDA $7FAB58,X				; if the jump type is 0 (jumps automatically), have it jump up
;	AND #%00001000
;	BEQ .dojump
;	
;	LDA $77						; else (the type is 1 (jumps when Mario jumps)), if Mario is on solid ground...
;	AND #%00000100
;	BEQ .updatepos
;	LDA $16						; and B or A was pressed, have the ninji jump up
;	ORA $18
;	AND #%10000000
;	BEQ .updatepos
;
;.dojump
	JSR SetXSpeed
	
	LDA $7FAB4C,X				; set inverse y speed based on the second extension byte
	EOR #$FF
	INC A
	STA $AA,X

.updatepos
	%ApplyReverseGravity()
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
	
	LDA $140D					; else, if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BounceMarioNormal:
	%BounceMario()				; have Mario bounce up
	
	LDA $7FAB58,X				; if the invincibility bit is not set...
	AND #%00000100
	BNE .playbouncesfx
	
	%HandleBounceCounter()
	STZ $AA,X					; give the sprite 0 y speed
	
	LDA #$02					; set the sprite status to killed
	STA $14C8,X
	RTS

.playbouncesfx
	LDA #$13					; play bounce sfx
	STA $1DF9
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
	RTS


Cnt_SolidSprite:
	%SolidSpriteInteraction_Standard()
	
	LDA $08						; if touching a solid sprite on the top...
	BEQ .return
	LDA $1588,X					; set the top block interaction flag (so the ninji can jump off)
	ORA #%00000100
	STA $1588,X

.return
	RTS


TileProp:
	db %00101101,%00100001

Graphics:
	LDA $7FAB58,X				; store the gravity type to scratch ram
	AND #%00000010
	LSR
	EOR $1879
	STA $04
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA $AA,X					; load tile ID based on whether the ninji is moving upward or downward
	BPL +
	LDA #$C0
	BRA .storetileid
	+
	
	LDA #$C2

.storetileid
	STA $0302,Y
	
	PHY
	LDA $7FAB58,X				; load the YXPPCCCT properties based on the invincibility bit
	AND #%00000100
	LSR #2
	TAY
	LDA TileProp,Y
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	LDY $04						; flip y if the gravity type is reverse
	BEQ +
	EOR #%10000000
	BRA .skipdeadflip
	+
	
	LDY $14C8,X					; else, flip y if the sprite is dead
	CPY #$08
	BCS .skipdeadflip
	EOR #%10000000

.skipdeadflip
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


SetXSpeed:
	LDA $7FAB58,X				; if set to follow Mario horizontally...
	AND #%00000001
	BEQ .return
	
	%SubHorzPos()				; set the x speed based on the first extension byte and the face direction
	LDA $7FAB40,X
	CPY #$00
	BEQ +
	EOR #$FF
	INC A
	+
	STA $B6,X

.return
	RTS