; custom spring
; unlike a vanilla spring, this sprite does despawn when offscreen
; the extension byte determines Mario's y speed when jumping off the spring

; $1540,X	=	spring animation timer
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $157C,X	=	face direction
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)
; $1602,X	=	animation frame (0 = normal, 1 = half pressed, 2 = fully pressed)


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

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


AnimationFrames:
	db $00,$01,$02,$02,$02,$01,$01,$00,$00
MarioYOffset:
	db $1E,$1B,$18,$18,$18,$1A,$1C,$1D,$1E

HandleMarioContact:
	LDA $1540,X					; if the animation timer is not set, check for whether Mario should start springing off
	BEQ TouchSolidItem
	
	LSR							; else, store the animation timer divided by 2 to an index
	TAY
	LDA $187A					; determine Mario's y offset from the spring based on the index, add 18 pixels if he's on Yoshi, and store it to scratch ram
	CMP #$01
	LDA MarioYOffset,Y
	BCC +
	CLC : ADC #$12
	+
	STA $00
	
	LDA AnimationFrames,Y		; set the animation frame based on the index
	STA $1602,X
	
	STZ $01						; offset Mario vertically from the spring
	LDA $14D4,X
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $00
	STA $96
	SEP #$20
	
	STZ $72						; set Mario's 'in the air flag' to 0
	STZ $7B						; set Mario's x speed to 0
	LDA #$02					; set Mario's 'standing on a solid sprite' flag to 2
	STA $1471
	
	LDA $1540,X					; if the animation frame is below 7...
	CMP #$07
	BCS .return
	
	STZ $1471					; set Mario's 'standing on a solid sprite' flag to 0
	LDY #$B0					; load Mario's y speed (set when not holding B or A)
	
	LDA $17						; if holding A...
	AND #%10000000
	BEQ +
	LDA #$01					; set the spin flag
	STA $140D
	BRA .mariojump				; skip the jump check
	+
	
	LDA $15						; if not holding B or A, skip setting Mario to jump
	AND #%10000000
	BEQ .storemarioyspeed

.mariojump
	LDA #$0B					; set Mario's 'in the air' flag to 'jumping up'
	STA $72
	
	LDA $7FAB40,X				; load y speed for Mario based on the extension byte (vanilla = #$80)...
	TAY
	STY $1406					; store it in an address that handles the camera going up

.storemarioyspeed
	STY $7D						; store Mario's y speed
	LDA #$08					; play boing sfx
	STA $1DFC

.return
	RTS


TouchSolidItem:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $D8,X					; based on Mario's y relative to the item's y...
	SEC : SBC $96
	CLC : ADC #$04
	CMP #$1C
	BCC MarioTouchSide			; push him sideways...
	BPL MarioTouchTop			; handle touching the item on the top...
	
	LDA $7D						; or, if Mario is moving downward, set his y speed to 0
	BPL .return
	STZ $7D

.return
	RTS


MarioTouchSide:
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	%CheckCarryItem()			; check whether Mario should grab the item, and return if the item was grabbed
	LDA $14C8,X
	CMP #$0B
	BEQ .return
	
	%PushSideItem()

.return
	RTS


MarioTouchTop:
	LDA $7D						; if Mario's y speed is downward...
	BMI .return
	LDA #$11					; set the spring animation timer to 17 frames
	STA $1540,X

.return
	RTS


; KICKED STATUS
KickedCode:
	JSR Graphics
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, offset the sprite from Mario; else, release the item
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
	%ReleaseItem_Standard()
	RTS


; GRAPHICS
TileX:
	db $00,$08,$00,$08
TileY:
	db $00,$00,$08,$08
AnimOffsetY:
	db $00,$04,$08
TileMap:
	db $28,$29,$38
TileProp:
	db %00000000,%01000000,%10000000,%11000000

Graphics:
	%GetDrawInfo()					; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	LDA $1602,X						; store the animation frame to scratch ram
	STA $04
	PHX
	LDX #$03						; load loop counter (4 tiles)

.tileloop
	LDA $00							; tile x position
	CLC : ADC TileX,X
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC TileY,X
	CPX #$02						; if the tile index is below 2 (top 2 8x8 tiles), add a y offset based on the animation frame
	BCS +
	PHX
	LDX $04
	CLC : ADC AnimOffsetY,X
	PLX
	+
	STA $0301,Y
	
	PHX
	LDX $04							; set the tile ID based on the stored animation frame
	LDA TileMap,X
	STA $0302,Y
	PLX
	
	LDA #%00001010					; tile YXPPCCCT properties
	ORA TileProp,X
	ORA $64
	STA $0303,Y
	
	INY #4							; increment OAM index
	DEX								; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .tileloop
	
	PLX
	LDA #$03						; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$00 = all 8x8 tiles)
	LDY #$00
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
	RTS


Cnt_SolidSprite:
	LDA $14C8,X					; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


Cnt_SolidSprite_Carryable:
	%SolidSpriteInteraction_Carryable()
	RTS