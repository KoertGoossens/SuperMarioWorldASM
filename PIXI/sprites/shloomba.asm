; shloomba; walking enemy that can be jumped off; it can wear a shell as a helmet and can be stunned and kicked in that form
; the first extension byte sets the x speed
; the second extension byte sets the type:
;	- bit 1:	+01		=	normal (0) vs invincible (1)
;	- bit 8:	+80		=	spawns with a shellmet
; the third extension byte sets the stun duration

; $C2,X		=	mirror of $1540,X (stun timer)
; $151C,X	=	wearing shell flag
; $1540,X	=	stun timer
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)
; $1602,X	=	animation frame
; $1626,X	=	number of consecutive enemies killed
; $187B,X	=	shellmet animation frame
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
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA $7FAB40,X				; set x speed based on the first extension byte
	STA $B6,X
	
	LDA $7FAB4C,X				; set shell wearing flag if the 1st bit in the second extension byte is set
	AND #%10000000
	BEQ +
	INC $151C,X
	+
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	STZ $187B,X					; set the shellmet animation frame to 0
	JSR Graphics
	
	LDA $9D						; if the game is frozen, only draw gfx
	BNE .return
	LDA $14C8,X					; if the sprite is dead, only draw gfx
	CMP #$08
	BNE .return
	
	STZ $190F,X					; don't push the sprite out of walls (checked by JSL $019138)
	
	%SubOffScreen()				; call offscreen despawning routine
	%HandleBlocksSpeeds()
	
	LDA $7FAB40,X				; load the x speed based on the first extension byte
	BPL +						; if negative, make it positive
	EOR #$FF
	INC A
	+
	STA $00						; store it to scratch ram
	
	LDA $1588,X					; if the sprite is touching a solid tile below...
	AND #%00000100
	BEQ +
	LDA $00						; set the positive x speed value
	LDY $157C,X					; invert it based on the face direction
	BEQ ++
	EOR #$FF
	INC A
	++
	STA $B6,X
	+
	
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	
	INC $1570,X					; increment the animation frame counter
	
	LDA $1570,X					; store the animation frame (2 animation frames of 8 frames each)
	LSR #3
	AND #$01
	STA $1602,X
	
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


; CARRIABLE STATUS
CarriableCode:
	STZ $187B,X					; set the shellmet animation frame to 0
	
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	LDA #$80					; push the sprite out of walls (checked by JSL $019138)
	STA $190F,X
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleStunTimer
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	JSR HandleFastAnimation
	JSR HandleSpriteInteraction
	JSR HandleBlockInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


; KICKED STATUS
KickedCode:
	LDA $14
	AND #%00001100
	LSR #2
	STA $187B,X
	
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	LDA #$80					; push the sprite out of walls (checked by JSL $019138)
	STA $190F,X
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	
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
	
	JSR HandleFastAnimation
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
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
	STZ $187B,X					; set the shellmet animation frame to 0
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	JSR HandleStunTimer
	JSR HandleFastAnimation
	JSR HandleSpriteInteraction
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, only draw graphics; else, handle releasing the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	JSR ReleaseItem

.gfx
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


HandleFastAnimation:
	INC $1570,X					; increment the animation frame counter
	
	LDA $1570,X					; store the animation frame (2 animation frames of 4 frames each)
	LSR #2
	AND #$01
	STA $1602,X
	RTS


UnstunXSpeed:
	db $F0,$10

HandleStunTimer:
	LDA $1540,X					; if the stun timer is at 1...
	CMP #$01
	BNE .return
	
	JSR SpawnShell
	
	LDA $14C8,X					; if the shloomba's sprite status is carried...
	CMP #$0B
	BNE +
	%HandleHurtMario()			; always hurt Mario
	+
	
	%SubHorzPos()				; set the shloomba's x speed based on its direction towards Mario
	LDA UnstunXSpeed,Y
	STA $B6,X
	
	LDA #$D8					; give the shloomba upward y speed
	STA $AA,X
	
	LDA #$10					; disable contact for the shloomba with other sprites for 16 frames (to prevent it from clashing with the shell when uptossed)
	STA $1564,X
	
	LDA #$08					; set the shloomba's sprite status back to normal
	STA $14C8,X

.return
	RTS


ShellmetTileID:
	db $C0,$E2,$C2,$E2
ShloombaProp:
	db %00100000,%00100010

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; shellmet tile
	LDA $151C,X					; if the sprite is not wearing a shell, don't draw it
	BEQ .noshellgfx
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $187B,X					; load tile ID based on the shellmet animation frame
	TAY
	LDA ShellmetTileID,Y
	PLY
	STA $0302,Y
	
	PHY
	LDA #%00101010				; tile YXPPCCCT properties
	
	LDY $187B,X					; flip x if the shellmet animation frame is 3
	CPY #$03
	BNE +
	EOR #%01000000
	+
	
	LDY $14C8,X					; flip y if the sprite is not in normal status
	CPY #$08
	BEQ +
	EOR #%10000000
	+
	
	PLY
	ORA $64
	STA $0303,Y
	
	INY #4

; shloomba tile
.noshellgfx
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$E0					; tile ID
	STA $0302,Y
	
	PHY
	LDA $7FAB4C,X				; load tile YXPPCCCT properties based on the shloomba type
	AND #$01
	TAY
	LDA ShloombaProp,Y
	
	LDY $1602,X					; flip x based on the animation frame
	BNE +
	EOR #%01000000
	+
	
	LDY $14C8,X					; flip y if the sprite is not in normal status
	CPY #$08
	BEQ +
	EOR #%10000000
	+
	
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$01					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
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
	CMP #$08
	BEQ NormalInteraction
	CMP #$09
	BEQ CarriableInteraction
	BRA KickedInteraction

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


KickedInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioKicked		; bounce off the sprite
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BounceMarioNormal:
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
	LDA $151C,X					; if the sprite is wearing a shellmet...
	BEQ +
	LDA $7FAB58,X				; set the stun timer to the value specified by the third extension byte
	STA $1540,X
	LDA #$09					; set the sprite status to carriable
	STA $14C8,X
	RTS
	+
	
	LDA $7FAB4C,X				; else, if the shloomba type is not invincible...
	AND #$01
	BNE +
	LDA #$02					; set the sprite status to killed
	STA $14C8,X
	+
	
	RTS


StompXSpeed:
	db $D0,$30

BounceMarioKicked:
	%BounceMario()				; have Mario bounce up
	%HandleBounceCounter()
	
	JSR SpawnShell
	
	%SubHorzPos()				; set the shloomba's x based on Mario's direction towards it
	LDA StompXSpeed,Y
	STA $B6,X
	
	LDA #$E8					; give the shloomba upward y speed
	STA $AA,X
	
	LDA #$08					; disable contact for the shloomba with Mario for 8 frames
	STA $154C,X
	
	LDA #$10					; disable contact for the shloomba with other sprites for 16 frames (to prevent it from interacting with the shell immediately)
	STA $1564,X
	
	LDA #$08					; set the shloomba's sprite status back to normal
	STA $14C8,X
	
	LDA $1588,X					; set the shloomba to not interaction with solid tiles below for the next frame
	AND #%11111011
	STA $1588,X
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
	BEQ +
	JSR Cnt_SolidSprite
	RTS
	+
	
	LDA $14C8,X					; else, branch depending on the sprite status
	CMP #$08
	BEQ Cnt_Normal
	CMP #$09
	BEQ Cnt_ItemCarriable
	CMP #$0A
	BEQ Cnt_ItemKicked
	CMP #$0B
	BEQ Cnt_ItemCarried
	RTS


Cnt_Normal:
	PHX							; if the indexed sprite is a shell...
	TYX
	LDA $7FAB9E,X
	PLX
	CMP #$0F
	BNE +
	LDA $14C8,Y					; and it's not in carried status...
	CMP #$0B
	BEQ +
	LDA $151C,X					; and the shloomba is not already wearing a shell...
	JSR SetCarryShell			; set the shell on top of the dino
	RTS
	+
	
	LDA $14C8,Y
	CMP #$08					; else, if the indexed sprite is also in normal status...
	BEQ DoBumpSprites			; turn both sprites around (for indexed sprites in item statuses, the indexed sprite should initiate the contact check)
	RTS


SetCarryShell:
	LDA #$02					; play contact sfx
	STA $1DF9
	
	INC $151C,X					; set the wearing shell flag
	
	LDA #$00					; erase the shell sprite
	STA $14C8,Y
	RTS


Cnt_ItemCarriable:
	LDA $1588,X					; else, if the item sprite is airborne...
	AND #%00000100
	BNE .itemspriteonground
	
	LDA $14C8,Y					; if the indexed sprite is in normal state, have the item sprite kill it
	CMP #$08
	BEQ DoKillSprite
	
	CMP #$09					; if the indexed sprite is in carriable state as well...
	BNE +
	LDA $1588,Y					; and it's on the ground...
	AND #%00000100
	BNE DoKillSprite			; have the item sprite kill the indexed sprite
	BRA DoClashSprites			; else (indexed sprite is airborne), kill both sprites
	+
	
	CMP #$0A					; if the indexed sprite is in kicked state, have the item sprite kill it
	BEQ DoKillSprite

.itemspriteonground
	LDA $14C8,Y					; else (item sprite is on the ground), if the indexed sprite is in normal status, turn both sprites around
	CMP #$08
	BEQ DoBumpSprites
	
	CMP #$0A					; else, if the indexed sprite is in kicked status...
	BEQ DoKillSprite
	
	RTS


Cnt_ItemKicked:
	LDA $14C8,Y					; if the indexed sprite is in normal state, have the item sprite kill it
	CMP #$08
	BEQ DoKillSprite
	
	CMP #$09					; if the indexed sprite is in carriable state as well...
	BNE +
	LDA $1588,Y					; and it's on the ground...
	AND #%00000100
	BNE DoKillSprite			; have the item sprite kill the indexed sprite
	BRA DoClashSprites			; else (indexed sprite is airborne), kill both sprites
	+
	
	CMP #$0A					; else, if the indexed sprite is also in kicked status, kill both sprites
	BEQ DoClashSprites
	
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


DoBumpSprites:			%BumpSprites() : RTS
DoClashSprites:			%ClashSprites() : RTS
DoKillSprite:			%KillSprite() : RTS


Cnt_SolidSprite:
	LDA $14C8,X						; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	CMP #$0A
	BEQ Cnt_SolidSprite_Kicked
	RTS


Cnt_SolidSprite_Carryable:
	%SolidSpriteInteraction_Carryable()
	RTS


Cnt_SolidSprite_Kicked:
	%SolidSprite_SetupInteract()
	
	LDA $08							; if the 'touching from above' flag is set...
	BNE Cnt_SolidSprite_Kicked_Top
	LDA $0A							; if the 'touching from the side' flag is set...
	BNE Cnt_SolidSprite_Kicked_Side
	RTS


Cnt_SolidSprite_Kicked_Top:
	LDA $AA,X						; don't interact if the calling sprite is moving up
	BMI .return
	
	LDA #$10						; set the calling sprite's y speed to #$10
	STA $AA,X
	%SolidSprite_SetOnTop()			; set the calling sprite on top of the block sprite

.return
	RTS


Cnt_SolidSprite_Kicked_Side:
	%SolidSprite_PushFromSide()
	
	LDA $B6,X						; invert the sprite's x speed
	EOR #$FF
	INC A
	STA $B6,X
	
	LDA #$01						; play bonk sfx
	STA $1DF9
	
	%SolidSprite_Activate()			; check for block activation
	
	LDA $157C,X						; flip the sprite's face direction
	EOR #$01
	STA $157C,X
	RTS


SpawnShell:
	STZ $151C,X					; clear 'wearing shell' flag
	
	LDA #$0F					; spawn a shell (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA $E4,X					; put the spawned shell at the same position as the shloomba
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	LDA $B6,X					; give the shell the shloomba's x and y speed
	STA $B6,Y
	LDA $AA,X
	STA $AA,Y
	
	LDA #$08					; disable contact for the shell with Mario for 8 frames (to prevent Mario from being able to grab it immediately)
	STA $154C,Y
	
	LDA #%10000000				; set the y-flip flag for the shell
	STA $160E,Y
	
	LDA $14D4,X					; raise the shloomba by 4 pixels
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0004
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	RTS