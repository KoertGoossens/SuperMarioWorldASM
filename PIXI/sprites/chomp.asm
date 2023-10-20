; chomp sprite that bounces on surfaces; it can break breakblocks when touching them from any side
; the first extension byte sets the x speed						- base = $18
; the second extension byte sets the y speed (jump height)		- base = $B8
; the third extension byte sets the type:
;	+00 = moves horizontally in one direction,	+01 = follows Mario horizontally
;	+00	= normal gravity,						+02 = reverse gravity

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
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	INC $1570,X					; increment the animation frame counter
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
	JSL $019138					; process interaction with blocks
	
	LDA $1588,X					; if the sprite is touching a ceiling...
	AND #%00001000
	BEQ +
	LDA $D8,X					; position the sprite below the ceiling tile
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
	
	JSR SetXSpeed
	
	LDA $7FAB4C,X				; set the y speed based on the second extension byte
	STA $AA,X

.updatepos
	%ApplyGravity()
	RTS


ReverseGravity:
	LDA $1588,X					; if the sprite is touching a solid tile below...
	AND #%00000100
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ .updatepos
	
	LDA $AA,X					; and it's not moving downward...
	BPL .updatepos
	
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
	
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


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
	
	LDA $14C8,Y					; if the indexed sprite is in normal status...
	CMP #$08
	BEQ DoKillSprite			; kill the indexed sprite
	CMP #$09					; if the indexed sprite is in carryable status...
;	BEQ KickCarryableItem		; kick the item
	BEQ DoKillSprite
	CMP #$0A					; if the indexed sprite is in kicked status...
;	BEQ BumpKickedItem			; bump it off the chomp as if the chomp were solid
	BEQ DoKillSprite
	RTS


Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS
DoKillSprite:			%KillSprite() : RTS


ClashXSpeed:
	db $30,$D0

KickCarryableItem:
	LDA $E4,X					; store the chomp's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $E4,Y					; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	
	LDY #$00					; check which side of the chomp the indexed sprite is on, and store it to Y
	REP #$20
	LDA $00
	SEC : SBC $02
	BPL +
	LDY #$01
	+
	SEP #$20
	
;	LDA $B6,X					; invert the chomp's x speed
;	EOR #$FF
;	INC A
;	STA $B6,X
	
	LDA ClashXSpeed,Y			; set the indexed sprite's x speed depending on the direction towards the chomp
	PLY
	EOR #$FF
	INC A
	STA $B6,Y
	
	LDA #$0A					; set the indexed sprite's status to kicked
	STA $14C8,Y
	
	LDA #$08					; disable contact with other sprites for 8 frames for the chomp
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	RTS


BumpKickedItem:
;	LDA $B6,X					; invert the chomp's x speed
;	EOR #$FF
;	INC A
;	STA $B6,X
	
	LDA $B6,Y					; invert the indexed sprite's x speed
	EOR #$FF
	INC A
	STA $B6,Y
	
	LDA #$08					; disable contact with other sprites for 8 frames for the chomp
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	RTS


Tilemap:
	db $A4,$A6
TileProp:
	db %00100111,%00100001

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
	
	PHY
	LDA $1570,X					; store the animation frame into Y (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	TAY
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	PHY
	LDA $7FAB58,X				; load the YXPPCCCT properties based on the jump type
	AND #%00000001
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
	LDA #$01					; play bump sfx
	STA $1DF9
	
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