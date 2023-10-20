; throwable shooter that can shoot out other sprites with L/R
; the extension byte sets the sprite ID of the sprite to shoot

; $154C,X	=	timer to disable contact with Mario
; $1558,X	=	shot cooldown timer
; $1564,X	=	timer to disable contact with other sprites
; $157C,X	=	direction (0 = right, 1 = left, 2 = up, 3 = down)


print "INIT ",pc
	PHB
	PHK
	PLB
	JSR InitCode
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
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset
	LDA #$0C : STA $7FB618,X	; sprite hitbox width
	LDA #$0A : STA $7FB624,X	; sprite hitbox height
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA #$09					; set the sprite status to carryable and run the carryable code
	STA $14C8,X
	BRA CarriableCode


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleShoot
	JSR HandleGravity
	%ProcessBlockInteraction()
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
	JSR Graphics
	JSR HandleShoot
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	JSR HandleShoot
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, offset the sprite from Mario; else, release the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	
	JSR ReleaseItem

.gfx
	LDA $76						; set the sprite's direction opposite to Mario's face direction
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
	%ReleaseItem_Standard()
	RTS


HandleShoot:
	LDA $18						; if pressing L or R...
	AND #%00110000
	BEQ .return
	
	LDA $1558,X					; and the shot cooldown timer is not set...
	BNE .return
	
	LDA #$0C					; bullet bill (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA $E4,X					; give the spawned sprite the same x position as the shooter item
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	
	LDA $14D4,X					; position the spawned sprite 1 pixel below the shooter item
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0001
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA $157C,X					; set the bullet bill's direction equal to the shooter item's direction
	PHX
	TYX
	STA $7FAB40,X
	PLX
	
	LDA #$08
	STA $154C,Y
	
	JSR SpawnSmoke
	
	LDA #$09					; play the shot sfx
	STA $1DFC
	
	LDA #$10					; set the shot cooldown timer
	STA $1558,X

.return
	RTS


SmokeXOffset:
	db $0C,$F4,$00,$00
SmokeYOffset:
	db $00,$00,$F4,$0C

SpawnSmoke:
	LDY $157C,X					; draw smoke with an x/y offset based on the shooter item's direction
	LDA SmokeXOffset,Y
	STA $01
	LDA SmokeYOffset,Y
	STA $02
	
	%SpawnSpriteSmoke()
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$EC					; tile ID
	STA $0302,Y
	
	PHY
	LDA #%00000001				; tile YXPPCCCT properties
	LDY $157C,X					; flip x based on face direction
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


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR CarriableInteraction

.return
	RTS


CarriableInteraction:
	%CheckCarryItem()			; handle grabbing the item
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
	RTS


Cnt_SolidSprite:
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


Cnt_SolidSprite_Carryable:
	%SolidSpriteInteraction_Carryable()
	RTS