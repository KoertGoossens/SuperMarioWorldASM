; surfboard sprite

; $C2,X		=	'Mario riding surfboard' flag
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1602,X	=	animation frame
; $1626,X	=	number of consecutive enemies killed
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
	
	LDA #$09					; set the sprite status to carryable and run the carryable code
	STA $14C8,X
	BRA CarriableCode


; NORMAL STATUS (FOR KILLED STATUS GFX)
SpriteCode:
	LDA $15F6,X					; set the 'flip y' bit of the stored YXPPCCCT properties address
	ORA #%10000000
	STA $15F6,X
	
	JSR Graphics
	RTS


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleSpriteInteraction
	JSR HandleBlockInteraction
	JSR HandleMarioContact

.gfx
	STZ $1602,X					; set the animation frame to 0
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


; KICKED STATUS
KickedCode:
	LDA $14						; change the animation frame every 4 frames
	LSR #2
	AND #%00000011
	STA $1602,X
	
	JSR Graphics
	
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .return
	
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
	
	LDA $C2,X					; if Mario is riding the surfboard, handle that
	BEQ .return
	JSR RideSurfBoard

.return
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


RideSurfBoard:
	LDA $16						; if Y/X was pressed...
	AND #%01000000
	BEQ +
	STZ $C2,X					; set the 'Mario riding surfboard' flag to 0
	LDA #$0B					; set the sprite status to carried
	STA $14C8,X
	BRA .return
	+
	
	LDA $16						; if B or A was pressed...
	ORA $18
	AND #%10000000
	BEQ +
	STZ $C2,X					; set the 'Mario riding surfboard' flag to 0 (so Mario will jump off)
	
	LDA $15						; if holding Y/X...
	AND #%01000000
	BEQ .return
	LDA #$0B					; set the sprite status to carried
	STA $14C8,X
	
	BRA .return
	+
	
	LDA $AA,X					; give Mario the y speed of the sprite
	CMP #$10					; if it's below #$10, set it to #$10
	BPL +
	LDA #$10
	+				
	STA $7D
	
	LDA #$01					; set Mario as standing on a solid sprite
	STA $1471
	
	LDA $14D4,X					; set Mario's y to be the sprite's y minus 31 pixels
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$001F
	LDY $187A					; subtract another 16 pixels if Mario is on Yoshi
	BEQ +
	SBC #$0010
	+
	STA $96
	SEP #$20
	
	LDA $E4,X					; set Mario's x equal to the sprite's x
	STA $94
	LDA $14E0,X
	STA $95

.return
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
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
	
	LDA #$00					; store the animation frame based on whether the item is drawn in front of Mario (Mario is turning around or entering a vertical pipe)
	LDY $15EA,X
	BNE +
	LDA #$02
	+
	STA $1602,X
	
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


; GRAPHICS
Tilemap:
	db $8C,$8A,$8E,$8A

Graphics:
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
	
	PHY
	
	LDA #%10000000				; tile YXPPCCCT properties
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	LDY $1602,X					; also flip x if the animation frame is 1
	CPY #$01
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
	
	LDA $14C8,X					; branch based on whether the sprite is in carriable status or kicked status
	CMP #$09
	BEQ +
	JSR KickedInteraction
	RTS
	+
	JSR CarriableInteraction

.return
	RTS


KickedInteraction:
	LDA $C2,X					; if Mario is riding the surfboard, return
	BNE .return
	
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	INC $C2,X					; else, set the 'Mario riding surfboard' flag

.return
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


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
	%CheckSpriteSpriteContact()				; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContact:
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	
	LDA $14C8,X					; else, branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_ItemCarriable
	CMP #$0A
	BEQ Cnt_ItemKicked
	CMP #$0B
	BEQ Cnt_ItemCarried
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