; buster beetle - enemy that can pick up and throw items; jump on it to kill it
; the first extension byte sets the walking speed
; the second extension byte sets the type:
;	bit 1:		throw type (+0 = throw horizontal, +1 = throw up)
;	bit 2:		item handle type (+0 = get knocked back, throw item; +1 = don't get knocked back, continue walking without throwing item)
;	bit 8:		gravity type 

; $C2,X		=	phase (0 = walking, 1 = getting pushed back by item, 2 = picking up item, 3 = holding item above head, 4 = walk while picking up item, 5 = walk while holding item)
; $1540,X	=	timer to disable picking up items after throwing an item
; $154C,X	=	timer to disable contact with Mario
; $1558,X	=	pick-up timer
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1602,X	=	animation frame
; $160E,X	=	sprite slot of the sprite the buster beetle is holding (set to #$FF when not holding anything)

!NumHoldFrames		=	#$10		; number of frames to hold the item still above the buster beetle's head after picking it up and before throwing it


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
	BNE .dead
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandlePhases
	%HandleFloor()
	
	LDA $7FAB4C,X				; handle gravity based on the gravity type
	AND #%10000000
	BNE +
	JSR HandleNormalGravity
	BRA .gravitydone
	+
	JSR HandleReverseGravity

.gravitydone
	JSL $019138					; process interaction with blocks
	
	LDA $1588,X					; if the sprite is touching a ceiling...
	AND #%00001000
	BEQ +
	LDA $D8,X					; position the sprite below the ceiling tile
	AND #%11110000
	ORA #%00001110
	STA $D8,X
	
	STZ $AA,X					; set the y speed to 0
	+
	
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS

.dead
	LDA $160E,X					; if the buster beetle is holding an item...
	BMI .return
	
	TAY							; enable block interaction for the indexed sprite
	LDA #$00
	STA $15DC,Y
	RTS


HandleNormalGravity:		%ApplyGravity() : RTS
HandleReverseGravity:		%ApplyReverseGravity() : RTS


HandlePhases:
	LDA $C2,X					; point to different routines based on the phase
	JSL $0086DF
		dw HandleWalking
		dw HandlePushBack
		dw HandlePickingItem
		dw HandleHoldingItem
		dw HandlePickWalking
		dw HandleHoldWalking


HandleWalking:
	LDA #$FF					; set sprite slot of the sprite the buster beetle is holding to #$FF (not holding anything)
	STA $160E,X
	
	JSR DoHandleWalking
	
	LDA $00						; store the animation frame based on the scratch ram value
	STA $1602,X
	RTS


PushBackItemX:
	dw $000E,$FFF2
PushBackXSpeed:
	db $02,$FE

HandlePushBack:
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	STZ $B6,X					; set the buster beetle's x speed to 0
	+
	
	LDY $160E,X					; if the held item is not in carryable status anymore (e.g. Mario grabbed, kicked, or killed it)...
	LDA $14C8,Y
	CMP #$09
	BEQ +
	JMP StartWalking
	+
	
	STZ $1602,X					; set the animation frame to 0
	
	LDA $157C,X					; store an index based on the buster beetle's face direction x2
	ASL
	TAY
	
	REP #$20
	LDA PushBackItemX,Y			; store the item's x offset to scratch ram based on the index
	STA $00
	LDA #$0000					; store the item's y offset to scratch ram
	STA $02
	SEP #$20
	
	JSR SetItemPosition
	
	LDA $B6,X					; if the buster beetle's x speed is 0...
	BNE +
	LDA #$08					; set the pick-up timer to 8 frames
	STA $1558,X
	
	INC $C2,X					; set the phase to 'picking up item'
	RTS
	+
	
	LDY $157C,X					; else, decrement the x speed based on the buster beetle's face direction
	CLC : ADC PushBackXSpeed,Y
	STA $B6,X
	RTS


HandlePickingItem:
	LDY $160E,X					; if the held item is not in carryable status anymore (e.g. Mario grabbed, kicked, or killed it)...
	LDA $14C8,Y
	CMP #$09
	BEQ +
	JMP StartWalking
	+
	
	LDA $1558,X					; if the pick-up timer is below 2...
	CMP #$02
	BCC +
	STZ $1602,X					; set the animation frame to 0
	BRA .animationframeset
	+
	LDA #$02					; else, set the animation frame to 2 (holding item above head)
	STA $1602,X

.animationframeset
	JSR DoHandlePickUp
	
	LDA $1558,X					; if the pick-up timer is 0...
	BNE .return
	
	INC $C2,X					; set the phase to 'holding item above head'
	
	LDA !NumHoldFrames			; set the 'handle item' timer
	STA $1558,X

.return
	RTS


HandlePickWalking:
	JSR DoHandleWalking
	
	LDA $00						; store the animation frame based on the scratch ram value + 2
	CLC : ADC #$02
	STA $1602,X
	
	LDY $160E,X					; if the held item is not in carryable status anymore (e.g. Mario grabbed, kicked, or killed it)...
	LDA $14C8,Y
	CMP #$09
	BEQ +
	JMP StartWalking
	+
	
	JSR DoHandlePickUp
	
	LDA $1558,X					; if the pick-up timer is 0...
	BNE .return
	
	INC $C2,X					; set the phase to 'walk while holding item'

.return
	RTS


HoldItemX:
	dw $0000,$0002,$0004,$0006,$0008,$000A,$000C,$000E		; normal gravity, facing right
	dw $0000,$FFFE,$FFFC,$FFFA,$FFF8,$FFF6,$FFF4,$FFF2		; normal gravity, facing left
	dw $0000,$0002,$0004,$0006,$0008,$000A,$000C,$000E		; reverse gravity, facing right
	dw $0000,$FFFE,$FFFC,$FFFA,$FFF8,$FFF6,$FFF4,$FFF2		; reverse gravity, facing left
HoldItemY:
	dw $FFF1,$FFF3,$FFF5,$FFF7,$FFF9,$FFFB,$FFFD,$FFFF
	dw $FFF1,$FFF3,$FFF5,$FFF7,$FFF9,$FFFB,$FFFD,$FFFF
	dw $000F,$000D,$000B,$0009,$0007,$0005,$0003,$0001
	dw $000F,$000D,$000B,$0009,$0007,$0005,$0003,$0001

DoHandlePickUp:
	LDA $7FAB4C,X				; store the gravity type to scratch ram
	AND #%10000000
	STA $00
	
	LDA $1558,X					; load the pick-up timer
	ASL							; multiply it by 2
	
	LDY $157C,X					; add #$10 based on the buster beetle's face direction
	BEQ +
	CLC : ADC #$10
	+
	
	LDY $00						; add #$20 based on the gravity type
	BEQ +
	CLC : ADC #$20
	+
	
	TAY							; store the value as an index
	
	REP #$20
	LDA HoldItemX,Y
	STA $00
	LDA HoldItemY,Y				; store the item's y offset to scratch ram
	STA $02
	SEP #$20
	
	JSR SetItemPosition
	RTS


ThrowHorizXSpeed:
	db $30,$D0					; (Mario's throw x speed when running at max non-p speed = #$3F)
ThrowVertXSpeed:
	db $10,$F0

HandleHoldingItem:
	%SubHorzPos()				; set the buster beetle to face Mario
	TYA
	STA $157C,X
	
	LDY $160E,X					; if the held item is not in carryable status anymore (e.g. Mario grabbed, kicked, or killed it)...
	LDA $14C8,Y
	CMP #$09
	BEQ +
	JMP StartWalking
	+
	
	LDA #$02					; set the animation frame to 2 (holding item above head)
	STA $1602,X
	
	JSR SetItemPosition_Holding
	
	LDA $1558,X					; if the pick-up timer is 0...
	BNE .return
	
	LDA #$03					; play kick sfx
	STA $1DF9
	
	LDA $7FAB4C,X				; if the type is 'throw horizontal'...
	AND #%00000001
	BNE +
	LDA #$0A					; set the item's sprite status to kicked
	STA $14C8,Y
	
	PHY							; give the item x speed based on the buster beetle's face direction
	LDY $157C,X
	LDA ThrowHorizXSpeed,Y
	PLY
	STA $B6,Y
	
	BRA StartWalking
	+
	
	PHY							; else (the type is 'throw vertical'), give the item x speed based on the buster beetle's face direction
	LDY $157C,X
	LDA ThrowVertXSpeed,Y
	PLY
	STA $B6,Y
	
	LDA #$A0					; give the item upward y speed
	STA $AA,Y
	
	BRA StartWalking

.return
	RTS


HandleHoldWalking:
	JSR DoHandleWalking
	
	LDA $00						; store the animation frame based on the scratch ram value + 2
	CLC : ADC #$02
	STA $1602,X
	
	LDY $160E,X					; if the held item is not in carryable status anymore (e.g. Mario grabbed, kicked, or killed it)...
	LDA $14C8,Y
	CMP #$09
	BEQ +
	JMP StartWalking
	+
	
	JSR SetItemPosition_Holding
	RTS


DoHandleWalking:
	LDA $B6,X					; if the x speed is not 0...
	BEQ +
	INC $1570,X					; increment the animation frame counter
	+
	
	LDA $1570,X					; store the animation frame to scratch ram based on the animation frame counter (2 animation frames of 4 frames each)
	LSR #2
	AND #%00000001
	STA $00
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $157C,X					; invert the face direction
	EOR #$01
	STA $157C,X
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

.return
	RTS


StartWalking:
	LDA #$00					; enable block interaction for the indexed sprite
	STA $15DC,Y
	
	STZ $C2,X					; set the phase to 'walking'
	
	LDA #$10					; set timer to disable picking up items
	STA $1540,X
	RTS


SetItemPosition:
	LDA $1602,X					; store the animation frame to scratch ram
	AND #%00000001
	STA $04
	STZ $05
	
	LDY $160E,X					; load the held item's ID into Y
	
	LDA $14E0,X					; offset the item's x from the buster beetle based on the scratch ram value
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC $00
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $14D4,X					; offset the item's y from the buster beetle based on the scratch ram value
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC $02
	ADC $04						; offset further based on the animation frame
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA #$00					; set the indexed sprite's x and y speeds to 0
	STA $B6,Y
	STA $AA,Y
	RTS


ItemYOffset_Holding:
	dw $FFF1,$000F

SetItemPosition_Holding:
	LDY #$00					; store an index based on the gravity type
	LDA $7FAB4C,X
	AND #%10000000
	BEQ +
	LDY #$02
	+
	
	REP #$20
	LDA #$0000					; store the item's x offset to scratch ram
	STA $00
	LDA ItemYOffset_Holding,Y	; store the item's y offset to scratch ram, based on the index
	STA $02
	SEP #$20
	
	JSR SetItemPosition
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
	
;	LDA $1686,Y				; if the indexed sprite doesn't interact with other sprites...
;	AND #%00001000
	LDA $1564,X				; or the item sprite has the 'disable contact with other sprites' timer set...
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


ThrowableSprites:
	db $00,$00,$02,$01,$00,$00,$01,$01,$00,$00,$00,$00,$00,$00,$01,$01		; 2 = p-switch, 3 = goomba, 6 = spring, 7 = bob-omb, E = throwblock, F = shell
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$01,$00,$00,$00,$00,$00,$02,$00,$02,$01,$00,$00,$00,$00		; 22 = buzzy beetle, 28 = carry block, 2A = magnet block, 2B = surfboard
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 41 = shooter item
	db $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 50 = bounce ball
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


SpriteContact:
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	
	LDA $14C8,Y
	CMP #$08					; if the indexed sprite is also in normal status...
	BEQ DoBumpSprites			; turn both sprites around (for indexed sprites in item statuses, the indexed sprite should initiate the contact check)
	CMP #$0B					; if the indexed sprite is in carried state, kill both the calling sprite and the indexed sprite
	BEQ DoClashSprites
	
	BRA CheckThrowableSprite	; else (the indexed sprite is in carryable or kicked status), check to see if the buster beetle can interact with it
	RTS


CheckThrowableSprite:
	LDA $160E,X					; if the buster beetle is holding the indexed sprite, skip interaction
	STA $00
	CPY $00
	BEQ .return
	
	PHX							; check the indexed sprite's ID to see the buster beetle should interact with it
	TYX
	LDA $7FAB9E,X
	TAX
	LDA ThrowableSprites,X
	STA $0F
	PLX
	
	LDA $0F						; return if not interactable
	BEQ .return
	
	LDA $C2,X					; if the phase is not 'walking' (it's already handling an item)...
	BNE DoKillSprite			; kill the buster beetle
	
	LDA $E4,X					; store the calling sprite's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $E4,Y					; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	LDY #$00					; check which side of the indexed sprite the calling sprite is on, and index it
	REP #$20
	LDA $00
	SEC : SBC $02
	BPL +
	LDY #$01
	+
	SEP #$20
	
	STZ $05						; check whether the buster beetle is facing the indexed sprite and store the result to scratch ram
	LDA $157C,X
	STA $04
	CPY $04
	BNE +
	INC $05
	+
	
	PLY
	
	LDA $05						; if the buster beetle is facing the indexed sprite, have it grab it
	BEQ GrabSprite
	
	BRA DoKillSprite			; else, check for killing the buster beetle

.return
	RTS


DoBumpSprites:			%BumpSprites() : RTS
Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS


DoClashSprites:
	LDA $1686,Y					; if the indexed sprite interacts with other sprites, clash the two sprites
	AND #%00001000
	BNE .return
	
	%ClashSprites()

.return
	RTS


DoKillSprite:
	LDA $0F						; if the item is set to kill the buster beetle...
	CMP #$01
	BNE .return
	
	PHY							; kill the buster beetle (swap X and Y)
	PHX
	TXA
	TYX
	TAY
	%KillSprite()
	PLX
	PLY

.return
	RTS


GrabSprite:
	LDA $1540,X					; if the timer to disable grabbing items is set, return
	BNE .return
	
	LDA $7FAB4C,X				; if the type is 'continue walking'...
	AND #%00000010
	BEQ +
	
	LDA #$08					; set the pick-up timer to 8 frames
	STA $1558,X
	
	LDA #$04					; set the phase to 'walk while picking item'
	STA $C2,X
	
	BRA .handleitem
	+
	
	LDA $B6,X					; if the buster beetle's x speed is positive...
	BMI +
	LDA $B6,Y					; and the item's x speed is also positive...
	BPL .handlepicking			; pick it up immediately
	BRA .handleknockback		; else (the item's x speed is negative), knock back the buster beetle
	+
	LDA $B6,Y					; else (the buster beetle's x speed is negative), if the item's x speed is also negative...
	BMI .handlepicking			; pick it up immediately
	BRA .handleknockback		; else (the item's x speed is positive), knock back the buster beetle

.handlepicking
	STZ $B6,X					; set the buster beetle's x speed to 0
	
	LDA #$08					; set the pick-up timer to 8 frames
	STA $1558,X
	
	LDA #$02					; set the phase to 'picking item'
	STA $C2,X
	BRA .handleitem

.handleknockback
	INC $C2,X					; set the phase to 'getting pushed back by item'
	
	LDA $B6,Y					; load the item's x speed
	AND #%11111110				; make it an even value
	STA $B6,X					; store it to the buster beetle's x speed

.handleitem
	TYA							; store the item's sprite slot
	STA $160E,X
	
	LDA #$09					; set the item's sprite status to carryable
	STA $14C8,Y
	
	LDA #$01					; disable block interaction for the item
	STA $15DC,Y

.return
	RTS


Tilemap:
	db $84,$86,$88,$E6
Palette:
	db %00100111,%00101001,%00100101,%00100101

Graphics:
	LDA $7FAB4C,X				; store the gravity type to scratch ram
	AND #%10000000
	STA $04
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $1602,X					; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	TAY
	LDA Tilemap,Y
	PLY
	STA $0302,Y
	
	PHY
	LDA $7FAB4C,X				; load tile YXPPCCCT properties based on the type
	AND #%00000011
	TAY
	LDA Palette,Y
	
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