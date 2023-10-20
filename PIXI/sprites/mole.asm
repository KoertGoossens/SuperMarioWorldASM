; custom monty mole that can jump over walls and thrown items
; the extension byte sets the walking speed

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


HitWallXOffset:
	db $01,$0E

SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; branch if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	%ProcessBlockInteraction()
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	
	DEC A						; offset the mole's x position from the block
	TAY
	LDA $E4,X
	AND #%11110000
	CLC : ADC HitWallXOffset,Y
	STA $E4,X
	
	LDA $1588,X					; if the sprite is on the floor, make it jump
	AND #%00000100
	BEQ +
	JSR HandleJump
	+
	
	LDA $7FAB40,X				; set the x speed based on the first extension byte
	PHY
	LDY $157C,X					; invert the x speed based on the face direction
	BEQ +
	EOR #$FF
	INC A
	+
	PLY
	STA $B6,X
	
	LDA $B6,X					; if the x speed is not 0...
	BEQ +
	INC $1570,X					; increment the animation frame counter
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()
	
	LDA $1588,X					; if the sprite is in the air...
	AND #%00000100
	BNE +
	STZ $1570,X					; set the animation frame counter to 0
	+
	
	JSR HandleJumpKicked
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


HandleGravity:		%ApplyGravity() : RTS


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


Cnt_SolidSprite:
	%SolidSprite_SetupInteract()
	
	LDA $08						; branch if the 'touching from above' flag is set
	BNE SprInt_Top
	
	LDA $0A						; branch if the 'touching from the side' flag is set
	BNE SprInt_Side
	RTS


SprInt_Top:
	LDA $AA,X					; don't interact if the calling sprite is moving up
	BMI .return
	
	STZ $AA,X					; set the calling sprite's y speed to 0
	%SolidSprite_DragSprite()	; drag the calling sprite horizontally along the block sprite
	%SolidSprite_SetOnTop()		; set the calling sprite on top of the block sprite

.return
	RTS


SprInt_Side:
	%SolidSprite_PushFromSide()
	
	LDA $1588,X					; if the sprite is on the floor...
	AND #%00000100
	BEQ .return
	
	JSR HandleJump				; handle jumping

.return
	RTS


HandleJumpKicked:
	LDA $1588,X					; if the sprite is on the floor...
	AND #%00000100
	BEQ .return
	
	LDY #$0B					; load highest sprite slot for loop

.loopstart
	LDA $14C8,Y					; if the indexed sprite is in kicked status, skip it
	CMP #$0A
	BNE .loopcontinue
	
	JSR CheckJump

.loopcontinue					; else, check the next sprite
	DEY
	BPL .loopstart

.return
	RTS


CheckJump:
	LDA $E4,Y					; store the kicked item's x position to scratch ram
	STA $00
	LDA $14E0,Y
	STA $01
	
	LDA $14E0,X					; load the mole's x position...
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC $00				; subtract the kicked item's x position...
	CLC : ADC #$0030			; add #$0030
	BMI .return					; if between 0 and #$0060...
	CMP #$0060
	BPL .return
	SEP #$20
	
	JSR HandleJump				; handle jumping

.return
	SEP #$20
	RTS


HandleJump:
	LDA #$C0					; give the sprite upward y speed
	STA $AA,X
	RTS


Tilemap:
	db $8A,$8C

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
	
	LDA #%00100001				; load tile YXPPCCCT properties
	PHY
	
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