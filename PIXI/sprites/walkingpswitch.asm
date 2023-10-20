; walking p-switch, cannot be carried
; the first extension byte sets the type:
;	bit 1+2:	0 = coin/block toggle; 1 = primary on/off toggle; 2 = secondary on/off toggle; 3 = shooter
;	bit 3:		clear = Mario falls down after pressing switch; set = Mario bounces off switch
;		valid types:	00	=	coin/block, fall down			(blue, P symbol)
;						01	=	primary on/off, fall down		(red, X symbol)
;						02	=	secondary on/off, fall down		(blue, X symbol)
;						03	=	shooter, fall down				(blue, shooter symbol)
;						04	=	coin/block, bounce off			(green, P symbol)
;						05	=	primary on/off, bounce off		(green, X symbol)
;						07	=	shooter, bounce off				(green, shooter symbol)
; the second extension byte sets the timer duration (for coin/block toggle)
; the third extension byte sets the walking speed

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter (p-switch)
; $157C,X	=	face direction
; $1602,X	=	animation frame counter (legs)
; $163E,X	=	erase timer


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


InitCode:
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$FF : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0C : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$FE : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0D : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%SubHorzPos()				; set the sprite to face Mario
	TYA
	STA $157C,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleAnimation
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleSpeed
	JSR HandleMarioContact
	JSR CheckSmokeKill

.return
	RTS


HandleGravity:
	%ApplyGravity()
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	RTS


HandleSpeed:
	LDA $15AC,X					; if set to interact with blocks...
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
	RTS


HandleAnimation:
	LDA $B6,X					; if the x speed is 0...
	BNE +
	LDA #$1C					; set the animation frame counter to #$1C
	STA $1602,X
	RTS
	+
	
	INC $1602,X					; else, increment the animation frame counter
	
	LDA $1602,X					; if the animation frame counter is at (or above) #$1C, set it back to 0
	CMP #$1C
	BCC +
	STZ $1602,X
	+
	
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
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
	LDA $7D						; if Mario is moving downward...
	BMI .return
	
	STZ $B6,X					; give the sprite 0 x speed
	
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
	
	LDA $7FAB40,X				; if bit 3 of the first extension byte is set...
	AND #%00000100
	BEQ +
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	RTS
	+
	
	%PutOnTopItem()				; else, set Mario on top of the p-switch (platform sprite)
	LDA #$0B					; play switch sfx (doesn't go together with bounce sfx)
	STA $1DF9

.return
	RTS


HandlePSwitchEffect:
	LDA $7FAB40,X				; branch based on the p-switch type
	AND #%00000011
	JSL $0086DF
		dw ToggleCoinBlock
		dw ToggleOnOffPrimary
		dw ToggleOnOffSecondary
		dw TriggerShooter

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


CheckSmokeKill:
	LDY $163E,X					; if the erase timer is at 1...
	CPY #$01
	BNE .return
	
	%SmokeKillSprite()			; kill the item with smoke

.return
	RTS


LegTile1X:
	db $03,$04,$05,$07,$07,$06,$01,$04
LegTile1Y:
	db $0B,$0B,$0B,$0B,$08,$09,$08,$0C
LegTile1ID:
	db $AB,$AB,$AB,$AB,$AA,$AA,$AA,$BA
LegTile1Prop:
	db %00100101,%00100101,%00100101,%00100101,%01100101,%01100101,%01100101,%01100101

LegTile2X:
	db $FF,$FA,$F9,$F5,$F8,$FB,$FF,$FC
LegTile2Y:
	db $08,$05,$07,$05,$0A,$0C,$0C,$0C
LegTile2ID:
	db $AA,$AB,$AB,$AA,$AB,$BA,$BA,$BA
LegTile2Prop:
	db %00100101,%11100101,%01100101,%01100101,%01100101,%00100101,%00100101,%00100101

BodyTileY:
	db $FC,$FC,$FC,$FD,$FE,$FD,$FC,$FD
BodyTileID:
	db $42,$0E,$0E,$26,$42,$0E,$0E,$26
BodyTileProp:
	db %00000110,%00001000,%00000110,%00000110,%00001010,%00001010,%00001010,%00001010

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $7FAB40,X				; store the p-switch type to scratch ram
	AND #%00000111
	STA $02
	
	LDA $163E,X					; store the erase timer to scratch ram
	STA $03
	
	LDA $157C,X					; store the face direction to scratch ram
	STA $04
	
	LDA $1602,X					; load the animation frame
	LSR #2
	TAX
	
; leg tile 1 (back leg)
	LDA LegTile1X,X				; load the x offset
	
	PHY							; invert the x offset based on the face direction
	LDY $04
	BNE +
	EOR #$FF
	INC A
	+
	PLY
	
	CLC : ADC #$04				; add 4 pixels
	CLC : ADC $00				; add the sprite's x position
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC LegTile1Y,X
	STA $0301,Y
	
	LDA LegTile1ID,X			; tile ID
	STA $0302,Y
	
	LDA LegTile1Prop,X			; load tile YXPPCCCT properties
	
	PHY
	LDY $04						; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	PLY
	
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 8x8 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$00
	STA $0460,Y
	PLY
	
	INY #4

; leg tile 2 (front leg)
	LDA LegTile2X,X				; load the x offset
	
	PHY							; invert the x offset based on the face direction
	LDY $04
	BNE +
	EOR #$FF
	INC A
	+
	PLY
	
	CLC : ADC #$04				; add 4 pixels
	CLC : ADC $00				; add the sprite's x position
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC LegTile2Y,X
	STA $0301,Y
	
	LDA LegTile2ID,X			; tile ID
	STA $0302,Y
	
	LDA LegTile2Prop,X			; load tile YXPPCCCT properties
	
	PHY
	LDY $04						; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	PLY
	
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 8x8 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$00
	STA $0460,Y
	PLY
	
	INY #4

; p-switch tile
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC BodyTileY,X
	STA $0301,Y
	
	LDA #$42					; tile ID
	STA $0302,Y
	
	PHY
	LDA #$44					; tile ID to load if the p-switch is pressed
	LDY $03
	BNE +
	LDY $02						; else (unpressed), load the tile ID based on the p-switch type
	LDA BodyTileID,Y
	+
	PLY
	STA $0302,Y
	
	PHY
	LDY $02						; load the tile YXPPCCCT properties based on the p-switch type
	LDA BodyTileProp,Y
	PLY
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	LDX $15E9					; restore the sprite slot into X
	
	LDA #$02					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS