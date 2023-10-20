; custom shell
; the extension byte sets the shell type:
;	- first 2 bits:		jump effect		+00		=	vanilla green shell
;										+01		=	single-bounce shell (goes poof when jumped off)
;										+02		=	infinite-bounce shell (stays in kicked state when jumped off)
;										+03		=	regrab shell (gets set to carried state when jumped off while holding Y/X)
;	- bit 3:			disco			+04		=	disco shell (spawns in carryable state unless the kicked bit is set)
;	- bit 4:			kicked			+08		=	shell spawns in kicked status
;	- bit 5:			spiny			+10		=	spiny shell (can be spun off)

; $1504,X	=	base x speed of sprite inside shell
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1594,X	=	sprite status to set upon spawn
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)
; $1602,X	=	animation frame
; $160E,X	=	y-flip flag
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


KickSpeedX:
	db $2E,$D2

InitCode:
	LDA $1594,X					; set sprite status based on the stored value
	BNE +						; if the stored sprite status was not set, set the sprite status to 'carryable'
	LDA #$09
	+
	STA $14C8,X
	
	LDA $7FAB40,X				; if the 4th bit of the extension byte is set, set the sprite status to 'kicked' and make it move towards Mario
	AND #%00001000
	BEQ .sethitbox
	
	LDA #$0A					; set the sprite status to 'kicked'
	STA $14C8,X
	
	LDA $7FAB40,X				; if the disco bit is not set...
	AND #%00000100
	BNE .sethitbox
	%SubHorzPos()				; give the item x speed based on the horizontal position towards Mario
	LDA KickSpeedX,Y
	STA $B6,X

.sethitbox
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA $14C8,X					; if the sprite status was set to carryable, run the carryable code
	CMP #$09
	BEQ CarriableCode
	CMP #$0A					; else, if it was set to kicked, run the kicked code
	BEQ KickedCode
	JMP CarriedCode				; else, run the carried code


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
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	%ProcessBlockInteraction()
	
	LDA $1588,X					; if the item is on the ground...
	AND #%00000100
	BEQ .checkdiscoshell
	
	LDA #$10					; give it some downward speed
	STA $AA,X
	
	LDA $1860					; if the item hits a purple triangle (tiles #$01B4 and #$01B5), give it upward y speed
	CMP #$B5
	BEQ +
	CMP #$B4
	BNE .checkdiscoshell
	+
	LDA #$B8
	STA $AA,X

.checkdiscoshell
	LDA $7FAB40,X				; if the 3rd bit of the extension byte is set, handle the disco shell tracking Mario horizontally
	AND #%00000100
	BEQ .checkinteraction
	
	%SubHorzPos()				; compare the sprite's horizontal position to Mario's (output to Y)
	BNE .discomoveleft			; if facing left, branch to .discomoveleft
	LDA $B6,X					; if the x speed is below the max speed, increase it by 2
	CMP #$20
	BPL .checkinteraction
	CLC : ADC #$02
	STA $B6,X
	BRA .checkinteraction

.discomoveleft
	LDA $B6,X					; if the x speed is above the min speed, decrease it by 2
	CMP #$E0
	BMI .checkinteraction
	SEC : SBC #$02
	STA $B6,X

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
NormalShellTile:
	db $8C,$8A,$8E,$8A
SpinyShellTile:
	db $EB,$E6,$ED,$E6
TilePalette:
	db %00001010,%00001100,%00000010,%00000100

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY							; store tile number based on the animation frame
	LDA $1602,X
	TAY
	LDA $7FAB40,X				; if the shell is a spiny shell, load a spiny shell tile
	AND #%00010000
	BEQ +
	LDA SpinyShellTile,Y
	BRA .shelltileloaded
	+
	LDA NormalShellTile,Y		; else, load a normal shell tile

.shelltileloaded
	PLY
	STA $0302,Y
	
	PHY							; handle tile YXPPCCCT properties
	
	LDA $7FAB40,X				; if the 3rd bit of the extension byte is set (disco shell)...
	AND #%00000100
	BEQ .nodisco
	
	LDA $13						; cycle through the palettes every other frame
	AND #%00001110
	BRA .paletteloaded

.nodisco
	LDA $7FAB40,X				; else, if the shell is a spiny shell...
	AND #%00010000
	BEQ .nospiny
	
	LDA #%00001000				; load the red palette
	BRA .paletteloaded

.nospiny
	LDA $7FAB40,X				; else, load the palette based on the shell's jump effect (set by the extension byte)
	AND #%00000011
	TAY
	LDA TilePalette,Y

.paletteloaded
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
	ORA $15F6,X					; flip y based on the stored YXPPCCCT properties (set by quake sprites externally)
	ORA $160E,X					; apply y-flip flag
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
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
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $7FAB40,X				; else, if the shell is a spiny shell...
	AND #%00010000
	BEQ +
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS
	+
	
	LDA $140D					; else (no spiny shell), if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioKicked		; bounce off the sprite
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


DiscoBounceXSpeed:
	db $18,$E8

BounceMarioKicked:
	%BounceMario()				; have Mario bounce up
	
	LDA $7FAB40,X				; if the 3rd bit of the extension byte is set (disco shell)...
	AND #%00000100
	BEQ .nodisco
	
	%SubHorzPos()				; give Mario some x speed away from the disco shell
	LDA DiscoBounceXSpeed,Y
	STA $7B
	
	LDA #$02					; play contact sfx
	STA $1DF9
	RTS

.nodisco
	%HandleBounceCounter()
	
	LDA $7FAB40,X				; point to different routines based on the jump effect (set by the extension byte)
	AND #%00000011
	JSL $0086DF
		dw JumpEffect_Vanilla
		dw JumpEffect_SingleBounce
		dw JumpEffect_InfiniteBounce
		dw JumpEffect_Regrab

JumpEffect_Vanilla:
	LDA #$09					; set the sprite status to carriable
	STA $14C8,X
	RTS

JumpEffect_SingleBounce:
	%SmokeKillSprite()
	LDA #$08					; play smokekill sfx
	STA $1DF9
	RTS

JumpEffect_InfiniteBounce:
	RTS							; keep the shell in kicked state

JumpEffect_Regrab:
	%CheckCarryItem()			; handle grabbing the item
	LDA $14C8,X					; if the item wasn't grabbed, set the sprite status to carriable
	CMP #$0B
	BEQ +
	LDA #$09					; set the sprite status to carriable
	STA $14C8,X
	+
	
	RTS


CarriableInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, don't spinkill it
	BCC .skipspinkill
	
	LDA $7FAB40,X				; if the shell is not a spiny shell...
	AND #%00010000
	BNE +
	LDA $140D					; and Mario is spinjumping...
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
	BEQ +
	JSR Cnt_SolidSprite
	RTS
	+
	
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

DoKillSprite:
	PHX								; if the indexed sprite is a dino, flying dino, or shloomba, branch
	TYX
	LDA $7FAB9E,X
	PLX
	CMP #$00
	BEQ .checkwearshell
	CMP #$10
	BEQ .checkwearshell
	CMP #$0B
	BEQ .checkwearshell

.dokill
	%KillSprite()					; else, kill the indexed sprite

.return
	RTS

.checkwearshell
	LDA $151C,Y						; if the sprite is already wearing a shell, kill it
	BNE .dokill
	RTS


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