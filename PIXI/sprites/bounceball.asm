; bounce ball (item sprite)
; don't use together with vanilla item sprites

; $C2,X		=	sprite contact type
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1602,X	=	animation frame
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


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleBlockInteraction
	JSR HandleAnimationFrame
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleGravity:		%ApplyGravity() : RTS


HandleBlockInteraction:
	LDA $1588,X					; if the sprite is touching a ground, handle interaction with it
	AND #%00000100
	BEQ +
	JSR BlockGroundInteraction
	+
	
	LDA $1588,X					; if the item is touching a ceiling, handle interaction with it
	AND #%00001000
	BEQ +
	JSR BlockCeilingInteraction
	BRA .return
	+
	
	LDA $1588,X					; else, if the item is touching a block from the side, handle interaction with it
	AND #%00000011
	BEQ .return
	JSR BlockSideInteraction

.return
	RTS


BlockGroundInteraction:
;	LDA $B6,X
;	PHP
;	BPL +
;	EOR #$FF
;	INC A
;	+
;	
;	CMP #$04
;	BCS +
;	STZ $B6,X
;	PLP
;	BRA .xspeedset
;	+
;	SEC : SBC #$04
;	
;	PLP
;	BPL +
;	EOR #$FF
;	INC A
;	+
;	STA $B6,X
;
;.xspeedset
	LDA $AA,X					; invert the sprite's y speed
	CMP #$20
	BCS +
	LDA #$20
	+
	
	EOR #$FF
	CLC : ADC #$05
	STA $AA,X
	RTS


BlockCeilingInteraction:
	LDA #$10					; else (touching a ceiling), give the item downward y speed
	STA $AA,X
	
	LDA $01						; if the sprite is set to not activate blocks, return
	CMP #$01
	BEQ .return
	
	LDA $E4,X					; store the item's x and y positions for block activation
	CLC : ADC #$08
	STA $9A
	LDA $14E0,X
	CLC : ADC #$00
	STA $9B
	LDA $D8,X
	AND #$F0
	STA $98
	LDA $14D4,X
	STA $99
	
	LDA $1588,X					; if the block is on layer 2, store this for block activation
	AND #%00100000
	ASL #3
	ROL
	AND #$01
	STA $1933
	
	LDY #$00					; load direction the block was hit from (bottom)
	LDA $1868					; load Map16 ID of block
	JSL $00F160					; handle block behavior after it's hit
	
	LDA #$08					; briefly disable water splashes and capespin/punch/etc. interaction for the item
	STA $1FE2,X

.return
	RTS


BlockSideInteraction:
	LDA $B6,X					; invert the sprite's x speed...
	EOR #$FF
	INC A
	STA $B6,X
	
	LDA #$01					; play bonk sfx
	STA $1DF9
	
	LDA $15A0,X					; if the sprite is horizontally offscreen, don't check for block activation
	BNE .return
	
	LDA $E4,X					; if the sprite is not far enough on-screen, don't check for block activation
	SEC : SBC $1A
	CLC : ADC #$14
	CMP #$1C
	BCC .return
	
	LDA $1588,X					; if the block is on layer 2, store this for block activation
	AND #%01000000
	ASL #2
	ROL
	AND #$01
	STA $1933
	
	LDY #$00					; load direction the block was hit from
	LDA $18A7					; load Map16 ID of block
	JSL $00F160					; handle block behavior after it's hit
	
	LDA #$05					; briefly disable water splashes and capespin/punch/etc. interaction for the item
	STA $1FE2,X

.return
	RTS


; KICKED STATUS
KickedCode:
	JSR HandleAnimationFrame
	JSR Graphics
	
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	STZ $AA,X					; set the item's y speed to 0
	JSR HandleSpriteInteraction
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, offset the sprite from Mario; else, release the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	
	%ReleaseItem_Standard()

.gfx
	JSR HandleAnimationFrame
	
	LDA $64						; handle OAM priority and draw graphics
	PHA
	%HandleOAMPriority()
	JSR Graphics
	PLA
	STA $64
	RTS


SideThrowItem:
	LDY #$00					; give the goomba 0 y speed when thrown in the air, or #$EC y speed when Mario is on the ground
	LDA $72
	BNE +
	LDY #$EC
	+
	STY $AA,X
	
	%ReleaseItem_Side()
	RTS


; GRAPHICS
Tilemap:
	db $C8,$CC,$CA,$CC,$C8,$CC,$CA,$CC
TileProp:
	db %00000101,%00000101,%00000101,%10000101,%10000101,%11000101,%01000101,%01000101

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY							; load tile ID based on the animation frame
	LDY $1602,X
	LDA Tilemap,Y
	PLY
	STA $0302,Y
	
	PHY							; load tile YXPPCCCT properties based on the animation frame
	LDY $1602,X
	LDA TileProp,Y
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
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR CarriableInteraction

.return
	RTS


CarriableInteraction:
	%CheckCarryItem()			; handle grabbing the item
	
	LDA $14C8,X					; if the item wasn't grabbed...
	CMP #$0B
	BEQ .return
	
	%CheckBounceMario()			; if Mario is not positioned to bounce off the top of the sprite, bounce him off the side
	BCC BounceMarioSide
	BRA BounceMarioTop			; else, bounce him off the top

.return
	RTS


BounceMarioTop:
	LDA #$03					; play bounce sfx
	STA $1DF9
	
	%BounceMario()				; have Mario bounce up
	
	LDA #$00					; bounce the sprite down at a speed depending on whether B/A is held
	BIT $15
	BPL +
	LDA #$40
	+
	STA $AA,X
	
	RTS


BounceSpeed_Mario:
	db $30,$D0
BounceSpeed_Ball:
	db $D0,$30

BounceMarioSide:
	LDA #$08					; play boing sfx
	STA $1DFC
	
	%SubHorzPos()				; based on Mario's x compared to the sprite's x...
	LDA BounceSpeed_Mario,Y		; bounce Mario sideways
	STA $7B
	LDA BounceSpeed_Ball,Y		; bounce the sprite sideways
	STA $B6,X
	
	JSL $01AB99					; display contact star
	
	LDA #$08					; set the 'disable contact with Mario' timer
	STA $154C,X
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
	%CheckSpriteSpriteContact()			; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


;	1 = solid sprite interaction
;	2 = shell

SpriteContactType:
	db $03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$02		; 0 = dino, E = throwblock, F = shell
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 35 = spiny
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $01,$01,$01,$01,$01,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = switch block, 68 = eating block
	db $01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 73 = big item block

SpriteContact:
	PHY									; branch based on the contact type
	PHX
	TYX
	LDA $7FAB9E,X
	PLX
	TAY
	LDA SpriteContactType,Y
	STA $C2,X
	PLY
	
	LDA $C2,X							; if the sprite contact type is 0, return
	BEQ .return
	CMP #$01							; if it's a solid block, branch
	BEQ Cnt_SolidSprite
	
	BRA BounceSprite					; else, bounce the sprite

.return
	RTS


Cnt_SolidSprite:
	LDA $14C8,X							; branch depending on the item sprite's status
	CMP #$09
	BEQ Cnt_SolidSprite_Carryable
	RTS


Cnt_SolidSprite_Carryable:
	%SolidSpriteInteraction_Carryable()
	RTS


BounceSpriteSpeed:
	db $D0,$30

BounceSprite:
	LDA $14C8,X							; if the bounce ball is in carried status...
	CMP #$0B
	BEQ BounceSpriteSide				; have sideways bounce interaction
	
	LDA $14C8,Y							; else, if the indexed sprite is in carried status...
	CMP #$0B
	BEQ BounceSpriteSide				; have sideways bounce interaction
	
	LDA.b #$02							; else, if the indexed sprite is less than 2 pixels above the bounce ball...
	STA $0F								; (2 pixels seems to be the maximum to make sure they don't clip through each other if the indexed sprite falls down at max speed and the bounce ball is uptossed)
	LDA $05
	SEC : SBC $0F
	ROL $00
	CMP $01
	PHP
	LSR $00
	LDA $0B
	SBC.b #$00
	PLP
	SBC $09
	BMI BounceSpriteSide				; have sideways bounce interaction
	
	BRA BounceSpriteTop					; else, bounce it off the top


BounceSpriteTop:
	LDA #$A8							; bounce the indexed sprite up
	STA $AA,Y
	JSL $01AB6F							; display contact star and play kick sfx
	STZ $AA,X							; set the bounce ball's y speed to 0
	RTS


BounceSpriteSide:
	LDA #$08							; play boing sfx
	STA $1DFC
	
	JSL $01AB72							; display contact star
	
	LDA $E4,X							; store the bounce ball's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $E4,Y							; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	LDY #$00							; check which side of the bounce ball the indexed sprite is on, and store it to scratch ram
	REP #$20
	LDA $02
	SEC : SBC $00
	BPL +
	LDY #$01
	+
	SEP #$20
	
	STY $0D								; store the indexed side to scratch ram
	LDA BounceSpriteSpeed,Y				; store the bounce x speed based on the indexed side to scratch ram
	STA $0E
	EOR #$FF							; also store the inverted value to scratch ram
	INC A
	STA $0F
	PLY
	
	LDA $14C8,X							; if the bounce ball is in carried status...
	CMP #$0B
	BNE +
	LDA $0E								; bounce Mario sideways
	STA $7B
	BRA .skipbounceball
	+
	
	LDA $0E								; else, bounce the bounce ball sideways
	STA $B6,X

.skipbounceball
	LDA $14C8,Y							; if the indexed sprite is in carried status...
	CMP #$0B
	BNE +
	LDA $0F								; bounce Mario sideways
	STA $7B
	RTS
	+
	
	LDA $C2,X							; else, if the sprite contact type is 2 (kickable sprite)...
	CMP #$02
	BNE +
	LDA #$0A							; set the indexed sprite's status to kicked
	STA $14C8,Y
	
	LDA $0F								; bounce the indexed sprite sideways
	STA $B6,Y
	RTS
	+
	
	CMP #$03							; else, if it's 3 (walking sprite)...
	BNE +
	LDA $0F								; bounce the indexed sprite sideways
	STA $B6,Y
	
	LDA #$D0							; give the indexed sprite some upward y speed
	STA $AA,Y
	RTS
	+
	
	RTS


HandleAnimationFrame:
	LDA $B6,X					; if the sprite is moving to the left...
	BPL +
	INC $1570,X					; increment the animation frame counter
	BRA .directionloaded
	+
	
	DEC $1570,X					; else, decrement the animation frame counter

.directionloaded
	LDA $1570,X					; store the animation frame (8 animation frames of 4 frames each)
	LSR #2
	AND #%00000111
	STA $1602,X
	RTS