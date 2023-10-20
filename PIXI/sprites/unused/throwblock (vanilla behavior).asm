; custom throwblock sprite
; don't use together with vanilla item sprites

; $C2,X		=	stun timer (how long the throwblock lasts)
; $1540,X	=	stun timer (how long the throwblock lasts)
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1594,X	=	sprite status to set upon spawn
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)
; $1626,X	=	number of consecutive enemies killed
; $1FE2,X	=	disable quake interaction timer


print "INIT ",pc
	LDA $1594,X					; set sprite status based on the stored value (set to 'carried' by throwblock block or 'kicked' by throwblock shooter)
	BNE +						; if the stored sprite status was not set by a block or shooter, set the sprite status to 'carriable'
	LDA #$09
	+
	STA $14C8,X
	
	LDA #$FF					; set the stun timer
	STA $1540,X
	
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$FE : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0D : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$16 : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
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


; MAIN CODE
SpriteCode:
	LDA $14C8,X					; if the sprite status is 2 (killed), break the throwblock
	CMP #$02
	BNE +
	JSR BreakThrowBlock
	+
	
	RTS


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleStunTimer
	JSL $01802A					; update x/y position with gravity, and process interaction with blocks
	JSR HandleBlockInteraction
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleStunTimer:
	LDA $1540,X					; if the stun timer is at 3...
	CMP #$03
	BNE +
	LDA #$04					; set the sprite status to smoke-killed
	STA $14C8,X
	LDA #$1F					; set the smoke timer
	STA $1540,X
	BRA .return
	+
	
	LDA $13						; else, increment it every other frame (in effect this will decrement it every other frame, since $1540,X is automatically decremented every frame for all sprites)
	AND #$01
	BNE .return
	INC $1540,X

.return
	RTS


HandleBlockInteraction:
	LDA $1588,X					; if the sprite is touching a ground, handle interaction with it
	AND #%00000100
	BEQ +
	JSR BlockGroundInteraction
	+
	
	LDA $1588,X					; else, if the item is touching a ceiling, handle interaction with it
	AND #%00001000
	BEQ +
	JSR BlockCeilingInteraction
	BRA .return
	+
	
	JSR BlockSideInteraction

.return
	RTS


BounceXSpeed:
	db $00,$00,$00,$F8,$F8,$F8,$F8,$F8,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$E8,$E8,$E8,$E8		; standard bounce heights

BlockGroundInteraction:
	LDA $B6,X					; halve the sprite's x speed
	PHP
	BPL +
	EOR #$FF
	INC A
	+
	LSR
	PLP
	BPL +
	EOR #$FF
	INC A
	+
	STA $B6,X
	
	LDA $AA,X					; set the sprite's y speed from a table, indexed by its current y speed divided by 4
	LSR #2
	TAY
	LDA BounceXSpeed,Y
	STA $AA,X
	RTS


BlockCeilingInteraction:
	LDA #$01					; play bonk sfx
	STA $1DF9
	
	LDA #$10					; give the item downward y speed
	STA $AA,X
	
	%Item_ActivateCeiling()
	RTS


BlockSideInteraction:
	LDA $1588,X					; if the item hits the side of a block, handle interaction with it
	AND #%00000011
	BEQ .return
	
	%Item_HitWall()
	JSR BreakThrowBlock

.return
	RTS


; KICKED STATUS
KickedCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSL $01802A					; update x/y position with gravity, and process interaction with blocks
	
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
	
	JSR BlockSideInteraction
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	JSR HandleStunTimer
	JSR HandleSpriteInteraction
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, only draw graphics; else, handle releasing the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	
	%ReleaseItem_Standard()

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


; GRAPHICS
Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; ICON GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$45					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y

; BLOCK GRAPHICS
	INY #4						; increment Y (the OAM index) by 4
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$46					; tilemap number (see Map8 in LM)
	STA $0302,Y
	
	LDA $14						; tile YXPPCCCT properties; cycle the palette every frame
	AND #%00000111
	ASL
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
	
	LDA #$08					; set the 'disable contact with Mario' timer
	STA $154C,X
	
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
	%CheckBounceMario()			; if Mario is positioned to bounce off the sprite...
	BCC .return
	
	LDA $140D					; and spinjumping or riding Yoshi...
	ORA $187A
	BEQ .return
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite

.return
	RTS


CarriableInteraction:	
	%CheckCarryItem()			; handle grabbing the item
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
	
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_ItemCarriable
	CMP #$0A
	BEQ Cnt_ItemKicked
	CMP #$0B					; if the item sprite is in carried state, kill both the item sprite and the indexed sprite
	BEQ DoClashSprites
	RTS


Cnt_ItemCarriable:
	LDA $1588,X					; if the item sprite is airborne...
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
	STZ $0D							; normal bounce height when the sprite falls on the top of a solid sprite
	%SolidSprite_SetupInteract()
	
	LDA $08							; branch if the 'touching from above' flag is set
	BNE Cnt_SprInt_Carryable_Top
	
	LDA $09							; else, branch if the 'touching from below' flag is set
	BNE Cnt_SprInt_Carryable_Bottom
	
	LDA $0A							; else, branch if the 'touching from the side' flag is set
	BNE Cnt_SprInt_Carryable_Side
	RTS


Cnt_SprInt_Carryable_Top:
	LDA $AA,X						; don't interact if the calling sprite is moving up
	BMI .return
	
	%SolidSprite_DragSprite()		; drag the calling sprite horizontally along the block sprite
	
	PHY
	%BounceCarryableSprite()
	PLY
	
	LDA $AA,X						; if the calling sprite's x speed is 0...
	BNE .return
	
	%SolidSprite_SetOnTop()			; set the calling sprite on top of the block sprite

.return
	RTS


Cnt_SprInt_Carryable_Bottom:
	%SolidSprite_Activate()			; check for block activation
	RTS


Cnt_SprInt_Carryable_Side:
	%SolidSprite_PushFromSide()		; move the calling sprite horizontally out of the block sprite
	
	LDA $B6,X						; if the calling sprite's x speed is not 0...
	BEQ .return
	BMI +							; and it is moving towards the block sprite...
	LDA $0B
	BNE .return
	BRA .bonkwall
	+
	LDA $0B
	BEQ .return

.bonkwall
	BRA Cnt_SolidSprite_Break		; break the throwblock

.return
	RTS


Cnt_SolidSprite_Kicked:
	%SolidSprite_SetupInteract()
	
	LDA $08							; if the 'touching from above' flag is set...
	BNE Cnt_SolidSprite_Kicked_Top
	LDA $0A							; if the 'touching from the side' flag is set...
	BNE Cnt_SolidSprite_Break
	RTS


Cnt_SolidSprite_Kicked_Top:
	LDA $AA,X						; don't interact if the calling sprite is moving up
	BMI .return
	
	LDA #$10						; set the calling sprite's y speed to #$10
	STA $AA,X
	%SolidSprite_SetOnTop()			; set the calling sprite on top of the block sprite

.return
	RTS

Cnt_SolidSprite_Break:
	LDA #$01						; play bonk sfx
	STA $1DF9
	
	%SolidSprite_Activate()			; check for block activation
	
	JSR BreakThrowBlock
	RTS


BreakThrowBlock:
	STZ $14C8,X						; set the sprite status to 0
	
	LDA $15A0,X						; return if the sprite is offscreen
	ORA $186C,X
	BNE .return
	
	LDA $E4,X						; load the shatter pieces coordinate input variables based on the sprite's position
	STA $9A
	LDA $14E0,X
	STA $9B
	LDA $D8,X
	STA $98
	LDA $14D4,X
	STA $99
	
	PHB								; create shatter pieces (A = 2, meaning that the pieces will flash)
	LDA #$02
	PHA
	PLB
	TYA
	JSL $028663
	PLB

.return
	RTS