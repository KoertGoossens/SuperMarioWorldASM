; custom p-switch
; the first extension byte sets the type:
;	bit 1+2:	0 = coin/block toggle; 1 = primary on/off toggle; 2 = secondary on/off toggle; 3 = shooter
;	bit 3:		gravity toggle
;	bit 4:		clear = Mario falls down after pressing switch; set = Mario bounces off switch
;		valid types:	00	=	coin/block, fall down			(blue, P symbol)
;						01	=	primary on/off, fall down		(red, X symbol)
;						02	=	secondary on/off, fall down		(blue, X symbol)
;						03	=	shooter, fall down				(blue, shooter symbol)
;						04	=	gravity toggle, fall down		(red, arrows symbol)
;						08	=	coin/block, bounce off			(green, P symbol)
;						09	=	primary on/off, bounce off		(green, X symbol)
;						0B	=	shooter, bounce off				(green, shooter symbol)
;						0C	=	gravity toggle, bounce off		(green, arrows symbol)

; the second extension byte sets the timer duration (for coin/block toggle)

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)
; $163E,X	=	erase timer
; $1FE2,X	=	disable quake interaction timer


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
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleSpriteInteraction
	JSR HandleBlockInteraction
	JSR HandleMarioContact
	JSR CheckSmokeKill

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	%CheckCarryItem()			; check whether Mario should grab the item, and return if the item was grabbed
	LDA $14C8,X
	CMP #$0B
	BEQ .return
	
	LDA $163E,X					; return if already pressed
	BNE .return
	
	JSR TouchSolidItem

.return
	RTS


TouchSolidItem:
	LDA $D8,X					; based on Mario's y relative to the item's y...
	SEC : SBC $D3
	CLC : ADC #$08
	CMP #$20
	BCC MarioTouchSide			; push him sideways...
	BPL MarioTouchTop			; handle touching the item on the top...
	LDA #$10					; or give Mario downward y speed
	STA $7D
	RTS


MarioTouchSide:		%PushSideItem() : RTS


MarioTouchTop:
	REP #$20					; disable pressing B and A for one frame (to prevent p-switch jumps)
	LDA #$8080
	TSB $0DAA
	TSB $0DAC
	SEP #$20
	
	LDA $1686,X					; disable Yoshi tonguing the p-switch
	ORA #%00000001
	STA $1686,X
	
	LDA #$20					; set the erase timer
	STA $163E,X
	
	LDA #$20					; set the layer 1 shake timer
	STA $1887
	
	JSR HandlePSwitchEffect
	
	LDA $7FAB40,X				; if bit 4 of the first extension byte is set...
	AND #%00001000
	BEQ +
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	RTS
	+
	
	%PutOnTopItem()				; else, set Mario on top of the p-switch (platform sprite)
	LDA #$0B					; play switch sfx (doesn't go together with bounce sfx)
	STA $1DF9
	RTS


HandlePSwitchEffect:
	LDA $7FAB40,X				; branch based on the p-switch type
	AND #%00000111
	JSL $0086DF
		dw ToggleCoinBlock
		dw ToggleOnOffPrimary
		dw ToggleOnOffSecondary
		dw TriggerShooter
		dw TriggerGravity
		dw TriggerGravity
		dw TriggerGravity
		dw TriggerGravity

ToggleCoinBlock:
	LDA $7FAB4C,X				; set the coin/block activation timer to the value specified by the second extension byte x4
	STA $14AD
	RTS

ToggleOnOffPrimary:
	LDA $14AF 					; else, toggle the primary on/off state
	EOR #$01
	STA $14AF
	RTS

ToggleOnOffSecondary:
	LDA $7FC0FC 				; toggle the secondary on/off state
	EOR #$01
	STA $7FC0FC
	RTS

TriggerShooter:
	LDA #$08					; set the shooter cooldown timer to 8 frames (which will fire a shot)
	STA $7C
	RTS

TriggerGravity:
	LDA $1879 					; else, toggle gravity
	EOR #$01
	STA $1879
	RTS


; KICKED STATUS
KickedCode:
	JSR Graphics
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	JSR CheckSmokeKill
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	LDA $1419					; if Mario is not going down a pipe, and not holding Y/X, release the item
	BNE .checksmokekill
	LDA $15
	AND #%01000000
	BNE .checksmokekill
	
	JSR ReleaseItem

.checksmokekill
	JSR CheckSmokeKill

.gfx
	LDA $64						; handle OAM priority and draw graphics
	PHA
	%HandleOAMPriority()
	JSR Graphics
	PLA
	STA $64
	RTS


ReleaseItem:	%ReleaseItem_Standard() : RTS


TileID:
	db $42,$0E,$0E,$26,$40,$40,$40,$40,$42,$0E,$0E,$26,$40,$40,$40,$40
TileProp:
	db %00000110,%00001000,%00000110,%00000110,%00000110,%00001000,%00000110,%00000110,%00001010,%00001010,%00001010,%00001010,%00001010,%00001010,%00001010,%00001010

Graphics:
	LDA $7FAB40,X				; store the p-switch type to scratch ram
	STA $02
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA #$44					; tile ID to load if the p-switch is pressed
	LDY $163E,X
	BNE +
	LDY $02						; else (unpressed), load the tile ID based on the p-switch type
	LDA TileID,Y
	+
	PLY
	STA $0302,Y
	
	PHY
	LDY $02						; load the tile YXPPCCCT properties based on the p-switch type
	LDA TileProp,Y
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


CheckSmokeKill:
	LDY $163E,X					; if the erase timer is at 1...
	CPY #$01
	BNE .return
	
;	LDA $7FAB40,X				; if bit 5 of the first extension byte is set...
;	AND #%00010000
;	BEQ +
;	STZ $163E,X					; set the erase timer back to 0 and return
;	RTS
;	+
	
	%SmokeKillSprite()			; kill the item with smoke

.return
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
	RTS


Cnt_SolidSprite:
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


Cnt_SolidSprite_Carryable:
	%SolidSpriteInteraction_Carryable()
	RTS