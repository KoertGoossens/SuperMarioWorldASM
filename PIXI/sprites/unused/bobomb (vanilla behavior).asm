; custom bob-omb
; unlike a vanilla bob-omb, this sprite does not follow Mario when walking and does not handle the flashing animation when it's about to explode
; don't use together with vanilla item sprites

; $C2,X		=	mirror of $1540,X (stun timer)
; $1534,X	=	explosion flag
; $1540,X	=	stun timer:		- set to #$FF when spawning, when thrown/bumped by Mario, or when kicked by a blue koopa
;								- if it reaches 0 with $1534,X at 0, the bob-omb becomes carryable and the stun timer gets set to #$40 (explosion countdown)
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1602,X	=	animation frame
; $1626,X	=	'number of consecutive enemies killed' counter
; $1FE2,X	=	disable quake interaction timer


print "INIT ",pc
	LDA #$0C					; set the x speed
	STA $B6,X
	
	LDA #$FF					; set the stun timer
	STA $1540,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox (bomb form) x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox (bomb form) y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox (bomb form) width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox (bomb form) height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox (bomb form) x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox (bomb form) y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox (bomb form) width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox (bomb form) height for interaction with other sprites
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


; NORMAL STATUS
SpriteCode:
	LDA $14C8,X					; if the sprite is dead, only draw graphics
	CMP #$08
	BNE .gfx
	
	LDA $1534,X					; if the explosion flag is set, handle exploding instead of the normal bomb routine
	BNE ExplosionCode
	
	LDA $9D						; if the game is frozen, skip the main routine
	BNE .skipmain
	
	LDA $1540,X					; if the stun timer is at 0...
	BNE +
	LDA #$09					; set the sprite status to carryable
	STA $14C8,X
	LDA #$40					; set the stun timer
	STA $1540,X
	BRA .gfx
	+
	
	%SubOffScreen()				; call offscreen despawning routine
	%HandleBlocksSpeeds()
	JSL $01802A					; update x/y position with gravity, and process interaction with blocks
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each

.skipmain
	JSR HandleSpriteInteraction
	JSR HandleMarioContact_Bomb

.gfx
	JSR BombGraphics
	RTS


ExplosionCode:
	LDA $9D						; if the game isn't frozen, increment the animation frame timer
	BNE +
	INC $1570,X
	+
	
	LDA $1540,X					; if the explosion timer is at 0, set the sprite status to 0
	BNE +
	STZ $14C8,X
	BRA .return
	+
	
	JSR HandleSpriteInteraction
	JSR HandleMarioContact_Explosion
	JSR ExplosionGraphics

.return
	RTS


ExplosionTileX:													; (sets of 5 tiles)
	db $00,$08,$06,$FA,$F8,		$06,$08,$00,$F8,$FA				; narrowest spacing		-	narrowest spacing upside-down
	db $00,$10,$0C,$F4,$F0,		$0C,$10,$00,$F0,$F4				; narrow spacing		-	narrow spacing upside-down
	db $00,$18,$12,$EE,$E8,		$12,$18,$00,$E8,$EE				; wide spacing			-	wide spacing upside-down
	db $00,$20,$18,$E8,$E0,		$18,$20,$00,$E0,$E8				; widest spacing		-	widest spacing upside-down
ExplosionTileY:
	db $F8,$FE,$06,$06,$FE,		$FA,$02,$08,$02,$FA
	db $F0,$FC,$0C,$0C,$FC,		$F4,$04,$10,$04,$F4
	db $E8,$FA,$12,$12,$FA,		$EE,$06,$18,$06,$EE
	db $E0,$F8,$18,$18,$F8,		$E8,$08,$20,$08,$E8

ExplosionTileCoorIndex:
	db $00,$0A,$14,$1E,$05,$0F,$19,$23


ExplosionGraphics:	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	PHX
	
	LDA $1540,X					; store the explosion tile coordinate index based on the explosion timer
	AND #%00001110
	LSR
	TAX
	LDA ExplosionTileCoorIndex,X
	STA $02
	
	LDX #$04					; load loop counter (5 tiles)

.tileloop
	PHX
	TXA
	CLC : ADC $02
	TAX
	
	LDA $00						; tile x position based on the explosion tile coordinate index
	CLC : ADC ExplosionTileX,X
	ADC #$04
	STA $0300,Y
	
	LDA $01						; tile y position based on the explosion tile coordinate index
	CLC : ADC ExplosionTileY,X
	ADC #$04
	STA $0301,Y
	
	PLX
	
	LDA #$BC					; tile ID
	STA $0302,Y
	
	LDA $13						; tile YXPPCCCT properties; store the palette based on the frame counter (different palette every 4 frames)
	LSR #2
	AND #$03
	SEC
	ROL
	ORA $64
	STA $0303,Y
	
	INY #4						; increment OAM index
	DEX							; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .tileloop
	
	PLX
	LDA #$04					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$00 = all 8x8 tiles)
	LDY #$00
	JSL $01B7B3
	RTS


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR CheckExplode
	JSL $01802A					; update x/y position with gravity, and process interaction with blocks
	JSR HandleBlockInteraction
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each
	JSR HandleSpriteInteraction
	JSR HandleMarioContact_Bomb

.gfx
	JSR BombGraphics
	RTS


HandleBlockInteraction:
	STZ $01						; allow block activation
	STZ $02						; allow sideways block activation
	STZ $0D						; set ground bounce height index offset to 0 (normal bounce height)
	%CheckBlockInteraction()
	RTS


; KICKED STATUS
KickedCode:
	%SetAnimationFrame()		; animation frame routine to handle 2 animation frames of 8 frames each
	JSR BombGraphics
	
	LDA $C2,X					; if $C2,X is zero, set the stun timer to 0
	BNE +
	STZ $1540,X
	BRA .setascarriable
	+
	LDA #$FF					; else, set the stun timer to #$FF
	STA $1540,X
.setascarriable
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle offsetting the sprite from Mario
	BNE .gfx
	
	LDA $1540,X					; store the stun timer to $C2,X
	STA $C2,X
	
	JSR CheckExplode
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
	JSR BombGraphics
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


; BOMB GRAPHICS
Tilemap:
	db $CA,$CC

BombGraphics:
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


CheckExplode:
	LDA $1540,X					; if the stun timer is at 1, initiate the explosion
	CMP #$01
	BNE +
	
	LDA #$1A					; play explosion sfx
	STA $1DFC
	
	INC $1534,X					; set the explosion flag
	
	LDA #$40					; set the stun timer (explosion countdown)
	STA $1540,X
	
	LDA #$08					; set the sprite status to normal
	STA $14C8,X
	
	LDA $1686,X					; set the explosion to not interact with other sprites (only the explosion can check for interaction)
	ORA #%00001000
	STA $1686,X
	
	LDA #$E8 : STA $7FB600,X : STA $7FB630,X		; set the sprite's hitbox coordinates for interaction with Mario and with other sprites
	LDA #$E8 : STA $7FB60C,X : STA $7FB63C,X
	LDA #$40 : STA $7FB618,X : STA $7FB648,X
	LDA #$40 : STA $7FB624,X : STA $7FB654,X
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
	
	LDA $1534,X
	BEQ SpriteContact_Bomb
	BRA SpriteContact_Explosion

.return
	RTS


SpriteContact_Explosion:
	LDA $167A,Y					; if the indexed sprite is set to not die by an explosion, return
	AND #%00000010
	BNE .return
	
	LDA #$02					; set the indexed sprite's status to killed
	STA $14C8,Y
	LDA #$00					; give the indexed sprite 0 x speed
	STA $B6,Y
	LDA #$C0					; give the indexed sprite upward y speed
	STA $AA,Y

.return
	RTS


SpriteContact_Bomb:
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$08
	BEQ Cnt_ItemNormal
	CMP #$09
	BEQ Cnt_ItemCarriable
	CMP #$0B					; if the item sprite is in carried state, kill both the item sprite and the indexed sprite
	BEQ DoClashSprites
	
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


Cnt_SolidSprite:
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$08
	BEQ Cnt_SolidSprite_Normal
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


Cnt_SolidSprite_Carryable:
	STZ $0D						; normal bounce height when the sprite falls on the top of a solid sprite
	LDA #$01					; play bonk sfx when the sprite hits the side of a solid sprite
	STA $0E
	%SolidSpriteInteraction_Carryable()
	RTS


DoBumpSprites:				%BumpSprites() : RTS
DoClashSprites:				%ClashSprites() : RTS
DoKillSprite:				%KillSprite() : RTS
Cnt_SolidSprite_Normal:		%SolidSpriteInteraction_Standard() : RTS


HandleMarioContact_Bomb:
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
	JSR NormalInteraction_Bomb
	RTS
	+
	JSR CarriableInteraction

.return
	RTS


NormalInteraction_Bomb:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy_Bomb
	BCC HitEnemy_Bomb
	
	LDA $140D					; else if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy_Bomb:
	%HandleSlideKillSprite()
	%HandleHurtMario()
	RTS


BounceMarioNormal:
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
	LDA #$FF					; set the stun timer
	STA $1540,X
	LDA #$09					; set the sprite status to carriable
	STA $14C8,X
	RTS


CarriableInteraction:
	LDA $140D					; if Mario is spinjumping...
	ORA $187A					; or on Yoshi...
	BEQ +
	LDA $7D						; and moving downwards...
	BMI +
	%SpinKillSprite()			; spinkill the sprite
	RTS
	+
	
	%CheckCarryItem()			; else, handle grabbing the item
	LDA $14C8,X					; if the item wasn't grabbed, bump it
	CMP #$0B
	BEQ +
	%HandleBumpItem()
	+
	
	RTS


HandleMarioContact_Explosion:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $1490					; if Mario has star power, return
	BNE .return
	JSR NormalInteraction_Explosion

.return
	RTS


NormalInteraction_Explosion:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy_Explosion
	BCC HitEnemy_Explosion
	
	LDA $140D					; if spinning or on Yoshi, branch to HitEnemy_Explosion
	ORA $187A
	BEQ HitEnemy_Explosion
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS


HitEnemy_Explosion:
	%HandleHurtMario()
	RTS