; custom buzzy beetle
; the first extension byte sets the walking speed
; the second extension byte sets the stun duration

; $C2,X		=	mirror of $1540,X (stun timer)
; $1540,X	=	stun timer
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1594,X	=	sprite status to set upon spawn
; $1602,X	=	animation frame
; $1FE2,X	=	disable quake interaction timer


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
	LDA $1594,X					; set sprite status based on the stored value (set by block or shooter)
	BNE +						; if the stored sprite status was not set by a block or shooter, set the sprite status to normal
	LDA #$08
	+
	STA $14C8,X
	
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


; NORMAL STATUS
SpriteCode:
	LDA $14C8,X					; if the sprite is dead, only draw graphics
	CMP #$08
	BNE .gfx
	
	LDA $9D						; if the game is frozen, skip the main routine
	BNE .skipmain
	
	STZ $190F,X					; don't push the sprite out of walls
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleSpeed
	JSR HandleGravity
	%ProcessBlockInteraction()
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each

.skipmain
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleSpeed:
	LDA $15AC,X					; if set to not interact with blocks, skip block interaction
	BNE .skipblockcheck
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $157C,X					; invert the face direction
	EOR #$01
	STA $157C,X
	
	LDA $B6,X					; invert the x speed (only has effect when in the air)
	EOR #$FF
	INC A
	STA $B6,X
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()

.skipblockcheck
	LDA $1588,X					; if the sprite is on the floor...
	AND #%00000100
	BEQ .inair
	
	LDA $7FAB40,X				; set the x speed based on the first extension byte
	PHY
	LDY $157C,X					; invert the x speed based on the face direction
	BEQ +
	EOR #$FF
	INC A
	+
	PLY
	STA $B6,X
	BRA .return

.inair
	STZ $1570,X					; else, set the animation frame counter to 0

.return
	RTS


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	LDA #$80					; push the sprite out of walls
	STA $190F,X
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleStunTimer
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleBlockInteraction
	JSR HandleSpriteInteraction
	JSR HandleMarioContact
	JSR MiscRoutines			; handle miscellaneous routines

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


; KICKED STATUS
KickedCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	%ProcessBlockInteraction()
	LDA $1588,X					; if the item is on the ground...
	AND #%00000100
	BEQ .checkinteraction
	LDA #$10					; give it some downward speed
	STA $AA,X
	
	LDA $1860					; if the item hits a purple triangle (tiles #$01B4 and #$01B5), give it upward y speed
	CMP #$B5
	BEQ +
	CMP #$B4
	BNE .checkinteraction
	+
	LDA #$B8
	STA $AA,X

.checkinteraction
	LDA $1588,X					; if the item is touching a ceiling, handle interaction with it
	AND #%00001000
	BEQ +
	JSR BlockCeilingInteraction
	+
	
	LDA $1588,X					; if the item hits the side of a block, handle interaction with it
	AND #%00000011
	BEQ +
	JSR BlockSideInteraction
	+
	
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	LDA $14						; change the animation frame every 4 frames
	LSR #2
	AND #%00000011
	STA $1602,X
	
	JSR Graphics
	RTS


BlockSideInteraction:
	LDA $B6,X					; invert the sprite's x speed
	EOR #$FF
	INC A
	STA $B6,X
	
	LDA $157C,X					; flip the sprite's face direction
	EOR #$01
	STA $157C,X
	
	%Item_HitWall()
	RTS


BlockCeilingInteraction:
	LDA #$01					; play bonk sfx
	STA $1DF9
	
	LDA #$10					; give the item downward y speed
	STA $AA,X
	
	%Item_ActivateCeiling()
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	STZ $AA,X					; set the item's y speed to 0
	
	LDA $1540,X					; store the stun timer to $C2,X
	STA $C2,X
	
	JSR HandleStunTimer
	JSR HandleSpriteInteraction
	JSR MiscRoutines
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, offset the sprite from Mario; else, release the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	JSR ReleaseItem

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


MiscRoutines:
	LDA $14						; animate the sprite (change tile every 8 frames)
	LSR #2
	AND #$01
	STA $1602,X
	
	LDA $1540,X					; if the stun timer is at 8...
	CMP #$08
	BNE +
	LDA $1588,X					; and the buzzy beetle is on the ground...
	AND #%00000100
	BEQ +
	LDA	#$D8					; give it some upward y speed
	STA $AA,X
	+
	
	RTS


ReleaseItem:	
	%ReleaseItemMisc()
	
	LDA $15						; if holding up, upthrow the item
	AND #%00001000
	BNE UpThrowItem
	
	LDA $15						; else, if holding down, drop the item
	AND #%00000100
	BNE DropItem
	
	BRA SideThrowItem			; else, throw the item sideways


UpThrowItem:	%ReleaseItem_Up() : RTS
DropItem:		%ReleaseItem_Down() : RTS


SideThrowItem:
	STZ $AA,X					; give the item 0 y speed
	%ReleaseItem_Side()
	RTS


; GRAPHICS
BeetleTile:
	db $A4,$A6
ShellTile:
	db $8C,$8A,$8E,$8A

Graphics:
	STZ $04						; set the x offset to 0
	
	LDA $1540,X					; if the stun timer is below #$40...
	CMP #$40
	BCS +
	AND #%00000010				; set the x offset and store it to scratch ram
	LSR
	STA $04
	+
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	CLC : ADC $04				; add the x offset
	STA $0300,Y
	
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $1602,X					; load the animation frame as an index
	TAY
	
	LDA $14C8,X					; if the sprite is in normal status, load a beetle tile based on the animation frame
	CMP #$08
	BNE +
	LDA BeetleTile,Y
	BRA .tileidloaded
	+
	CMP #$0A					; else, if the sprite is in kicked status, load a shell tile based on the animation frame
	BNE +
	LDA ShellTile,Y
	BRA .tileidloaded
	+
	
	LDA #$8C					; else, load the default shell tile

.tileidloaded
	PLY
	STA $0302,Y
	
	LDA #%00000111				; load tile YXPPCCCT properties
	PHY
	
	LDY $14C8,X					; if the sprite is not in normal status, load different YXPPCCCT properties
	CPY #$08
	BEQ +
	LDA #%00000110
;	EOR #%10000000
	+
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	LDY $1602,X					; also flip x if the animation frame is 3
	CPY #$03
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


HandleStunTimer:
	LDA $1540,X					; if the stun timer is below 4...
	CMP #$04
	BNE .return
	
	LDA $14C8,X					; if the sprite is in carried status...
	CMP #$0B
	BNE .skipcarried
	
	LDA $1490					; if Mario has star power, kill the sprite
	BEQ +
	%SlideStarKillSprite()
	BRA .skipcarried
	+
	
	JSR HitEnemy				; else, get hurt by it

.skipcarried
	LDA #$08					; set the sprite status back to normal
	STA $14C8,X

.return
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
	
	LDA $14C8,X					; branch based on the sprite status
	CMP #$09
	BEQ CarriableInteraction
	BRA NormalInteraction

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
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
	LDA $7FAB4C,X				; set the stun timer to the value specified by the second extension byte
	STA $1540,X
	LDA #$09					; set the sprite status to carriable
	STA $14C8,X
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
	%CheckSpriteSpriteContact()	; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContact:
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$08
	BEQ Cnt_ItemNormal
	CMP #$09
	BEQ Cnt_ItemCarriable
	CMP #$0B
	BEQ Cnt_ItemCarried
	
	RTS


Cnt_ItemNormal:					; the item sprite is in normal status
	LDA $14C8,Y
	CMP #$08					; if the indexed sprite is also in normal status...
	BEQ DoBumpSprites			; turn both sprites around (for indexed sprites in item statuses, the indexed sprite should initiate the contact check)
	
	RTS


Cnt_ItemCarriable:				; the item sprite is in carriable status
	LDA $1588,X					; if the item sprite is airborne, kill both the item sprite and the indexed sprite
	AND #%00000100
	BEQ DoClashSprites
	
	LDA $14C8,Y					; else (on the ground), if the indexed sprite is in normal status, turn both sprites around
	CMP #$08
	BEQ DoBumpSprites
	
	RTS


Cnt_ItemCarried:
	LDA $14D4,Y					; if Mario's y is low enough compared to the indexed sprite's y, clash the item sprite with the indexed sprite
	XBA							; (this prevents a carried item from clashing with a sprite that Mario bounces off)
	LDA $D8,Y
	REP #$20
	SEC : SBC $96
	SBC #$0018
	BPL +
	SEP #$20
	BRA DoClashSprites
	+
	SEP #$20
	RTS


Cnt_SolidSprite:
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$08
	BEQ Cnt_SolidSprite_Normal
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


DoBumpSprites:					%BumpSprites() : RTS
DoClashSprites:					%ClashSprites() : RTS
Cnt_SolidSprite_Normal:			%SolidSpriteInteraction_Standard() : RTS
Cnt_SolidSprite_Carryable:		%SolidSpriteInteraction_Carryable() : RTS