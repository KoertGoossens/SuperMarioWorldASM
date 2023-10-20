; custom bob-omb
;	- explodes only when touched by a fire source
;	- does not follow Mario when walking
; the extension byte sets the walking speed (vanilla x speed = #$0C)

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1602,X	=	animation frame


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
	LDA $9D						; if the game is frozen...
	BNE .gfx
	LDA $14C8,X					; or the sprite is dead, only draw graphics
	CMP #$08
	BNE .gfx
	
	STZ $190F,X					; don't push the sprite out of walls
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleSpeed
	JSR HandleGravity
	%ProcessBlockInteraction()
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each
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
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()

.skipblockcheck
	LDA $7FAB40,X				; set the x speed based on the first extension byte
	PHY
	LDY $157C,X					; invert the x speed based on the face direction
	BEQ +
	EOR #$FF
	INC A
	+
	PLY
	STA $B6,X
	
	LDA $1588,X					; if the sprite is in the air...
	AND #%00000100
	BNE +
	STZ $1570,X					; set the animation frame counter to 0
	+
	
	RTS


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	LDA #$80					; push the sprite out of walls
	STA $190F,X
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleBlockInteraction
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


; KICKED STATUS
KickedCode:
	LDA #$80					; push the sprite out of walls
	STA $190F,X
	
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each
	JSR Graphics
	
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle offsetting the sprite from Mario
	BNE .gfx
	
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each
	JSR HandleSpriteInteraction
	
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


Tilemap:
	db $CA,$CC

Graphics:
	LDA $14C8,X					; if the sprite is not in normal status...
	CMP #$08
	BEQ +
	LDA $15F6,X					; set the 'flip y' bit of the stored YXPPCCCT properties address
	ORA #%10000000
	STA $15F6,X
	+
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY							; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	LDA $1602,X
	TAY
	LDA Tilemap,Y
	PLY
	STA $0302,Y
	
	LDA #%00000101				; load tile YXPPCCCT properties
	
	PHY
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	PLY
	
	ORA $15F6,X					; flip y based on the stored YXPPCCCT properties (set by quake sprites externally)
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
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
	LDA $1588,X					; if the item sprite is airborne...
	AND #%00000100
	BNE .itemspriteonground
	
	LDA $14C8,Y					; if the indexed sprite is in normal state, have the item sprite kill it
	CMP #$08
	BEQ DoKillSprite
	
	CMP #$09					; if the indexed sprite is in carriable state as well...
	BNE .return
	LDA $1588,Y					; and it's on the ground...
	AND #%00000100
	BNE DoKillSprite			; have the item sprite kill the indexed sprite
	
	BRA DoClashSprites			; else (indexed sprite is airborne), kill both sprites

.itemspriteonground
	LDA $14C8,Y					; else (item sprite is on the ground), if the indexed sprite is in normal status, turn both sprites around
	CMP #$08
	BEQ DoBumpSprites

.return
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
DoKillSprite:					%KillSprite() : RTS
Cnt_SolidSprite_Normal:			%SolidSpriteInteraction_Standard() : RTS
Cnt_SolidSprite_Carryable:		%SolidSpriteInteraction_Carryable() : RTS


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
	
	LDA $14C8,X					; branch based on whether the sprite is in carriable status
	CMP #$09
	BEQ +
	JSR NormalInteraction
	RTS
	+
	JSR CarriableInteraction

.return
	RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy_Bomb
	BCC HitEnemy
	
	LDA $140D					; else if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:		%HandleSlideHurt() : RTS


BounceMarioNormal:
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
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