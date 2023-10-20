; boomerang, can be thrown into 8 directions with L/R and will fly back to Mario; it can drag other sprites

; $C2,X		=	phase (0 = inactive, 1 = flying out, 2 = flying back)
; $1504,X	=	x angle (low byte)
; $1528,X	=	speed
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation timer
; $157C,X	=	direction (0 = right, 1 = left, 2 = up, 3 = down, 4 = up-right, 5 = up-left, 6 = down-right, 7 = down-left)
; $1594,X	=	x angle (high byte)
; $1602,X	=	y angle (low byte)
; $160E,X	=	sprite slot of the sprite caught by the boomerang (#$FF = no sprite)
; $187B,X	=	y angle (high byte)

!speedinit			=	$51		; initial speed value when thrown
!speeddecel			=	$03		; speed deceleration value (flying out)
!speedaccel			=	$03		; speed acceleration value (flying back)
!speedlimit			=	$28		; speed limit (flying back)


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
;	LDA #$04 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
;	LDA #$04 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
;	LDA #$08 : STA $7FB618,X	; sprite hitbox width for interaction with Mario
;	LDA #$08 : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$02 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0B : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA #$FF					; set the boomerang to not carry a sprite
	STA $160E,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	LDA $9D						; return if the game is frozen
	BNE .drawgfx
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .drawgfx
	
	JSR HandleThrow
	JSR HandlePhase

.drawgfx
	JSR Graphics
	RTS


HandlePhase:
	LDA $C2,X					; point to different routines based on the phase
	JSL $0086DF
		dw Phase_Inactive
		dw Phase_FlyingOut
		dw Phase_FlyingBack


InputDirection:
	db $00,$00,$01,$00,$03,$06,$07,$06,$02,$04,$05,$04,$02,$04,$05,$04
ThrowXOffset:
	dw $0008,$FFF8,$0000,$0000,$0008,$FFF8,$0008,$FFF8
ThrowYOffset:
	dw $000C,$000C,$0000,$0018,$0000,$0000,$0018,$0018

Phase_Inactive:
	STZ $1570,X					; set the animation timer to 0
	RTS


FlyingOut_DirX:
	dw $FFF0,$0010,$0000,$0000,$FFF0,$0010,$FFF0,$0010
FlyingOut_DirY:
	dw $0000,$0000,$0010,$FFF0,$0010,$0010,$FFF0,$FFF0

Phase_FlyingOut:
	INC $1570,X					; increment the animation timer
	
	LDA $1528,X					; if the speed is 0
	BNE +
	INC $C2,X					; set the phase to 'flying back'
	RTS
	+
	
	LDA $157C,X					; load the angle x and y values based on the direction
	ASL
	TAY
	REP #$20
	LDA FlyingOut_DirX,Y
	STA $00
	LDA FlyingOut_DirY,Y
	STA $02
	SEP #$20
	
	LDA $1528,X					; load speed
	%GetSpeedAngle()
	
	LDA $00						; store the x speed
	STA $B6,X
	LDA $02						; store the y speed
	STA $AA,X
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	
	LDA $1528,X					; decrement the speed
	SEC : SBC #!speeddecel
	STA $1528,X
	
	JSR HandleSpriteInteraction
	JSR HandleContactSprite
	
;	LDA $14E0,X						; load the sprite's x
;	XBA
;	LDA $E4,X
;	REP #$20
;	CLC : ADC #$0008				; add the x offset
;	STA $9A							; store it to the block interaction point x
;	SEP #$20
;	
;	LDA $14D4,X						; load the sprite's y
;	XBA
;	LDA $D8,X
;	REP #$20
;	CLC : ADC #$0008				; add the y offset
;	STA $98							; store it to the block interaction point y
;	SEP #$20
;	
;	%GetMap16Solid()				; if the Map16 tile is a solid...
;	BNE .return
;	
;	STZ $1528,X						; set the speed to 0
;
;.return

	RTS


Phase_FlyingBack:
	INC $1570,X					; increment the animation timer
	
	LDA $1528,X					; if the speed is 0 (first frame of the phase)...
	BNE +
	
	LDA $14E0,X					; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC $94				; subtract Mario's x
	SEP #$20
	STA $1504,X					; store the result as the x angle
	XBA
	STA $1594,X
	
	LDA $14D4,X					; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $96				; subtract Mario's y
	SBC #$000C					; subtract 12 pixels
	SEP #$20
	STA $1602,X					; store the result as the y angle
	XBA
	STA $187B,X
	+
	
	LDA $1594,X					; load the x angle
	XBA
	LDA $1504,X
	REP #$20
	STA $00						; store the result to scratch ram
	SEP #$20
	
	LDA $187B,X					; load the y angle
	XBA
	LDA $1602,X
	REP #$20
	STA $02						; store the result to scratch ram
	SEP #$20
	
	LDA $1528,X					; load speed
	%GetSpeedAngle()
	
	LDA $00						; store the x speed
	STA $B6,X
	LDA $02						; store the y speed
	STA $AA,X
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	
	LDA $1528,X					; if the speed is below the limit...
	CMP #!speedlimit
	BCS +
	CLC : ADC #!speedaccel		; increment it
	STA $1528,X
	+
	
	JSR HandleSpriteInteraction
	JSR HandleContactSprite
	RTS


HandleThrow:
	LDA $18						; if pressing R...
	AND #%00010000
	BEQ .return
	
	LDA $C2,X					; if the boomerang is already out...
	BEQ +
	STZ $01						; spawn smoke at the boomerang's position
	STZ $02
	%SpawnSpriteSmoke()
	+
	
	LDA #$01					; set the phase to 'flying out'
	STA $C2,X
	
	LDA $15						; load the direction based on the dpad input
	AND #%00001111
	BNE +						; if not pressing any dpad direction, load the direction based on Mario's face direction instead
	LDA $76
	CLC : ADC #$02
	+
	TAY
	LDA InputDirection,Y
	STA $157C,X
	
	ASL							; load the direction as an index
	TAY
	
	REP #$20					; set the sprite's x to Mario's x + an offset based on the direction
	LDA $94
	CLC : ADC ThrowXOffset,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	REP #$20					; set the sprite's y to Mario's y + an offset based on the direction
	LDA $96
	CLC : ADC ThrowYOffset,Y
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA #!speedinit				; set the initial speed
	STA $1528,X
	
	LDA #$26					; play swooper sfx
	STA $1DFC
	
	LDA $160E,X					; if the boomerang is carrying a sprite...
	BMI .return
	
	TAY							; unload the contact sprite
	JSR UnloadContactSprite

.return
	RTS


HandleSpriteInteraction:
	LDA $160E,X				; branch if the boomerang is not carrying a sprite yet
	BPL .return
	
	LDY #$09				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the item sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	CMP #$0B				; if in carried status, don't check for contact
	BEQ .loopcontinue
	
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


SpriteContactType:
	db $01,$01,$01,$00,$01,$01,$01,$00,$01,$01,$01,$01,$00,$01,$02,$02		; 0 = dino, 1 = mole, 2 = p-switch, 4 = taptap, 5 = flying spiny, 6 = spring, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, E = throwblock, F = shell
	db $01,$00,$00,$01,$01,$01,$01,$00,$01,$01,$01,$00,$01,$01,$01,$00		; 10 = flying dino, 11 = flying coin, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1A = flying taptap, 1C = mushroom, 1D = tallguy, 1E = death skull
	db $00,$01,$00,$00,$01,$01,$01,$00,$01,$00,$00,$00,$00,$00,$00,$00		; 21 = buster beetle, 24 = Yoshi, 25 = baby Yoshi, 26 = chuckoomba, 28 = carry block
	db $00,$00,$01,$00,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 32 = parabeetle, 34 = ninji, 35 = spiny
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$01,$01,$00,$00,$00,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00		; 51 = thwimp, 52 = goldthwimp, 58 = parachute dino, 59 = parachute spiny, 5A = parachute shell
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$00,$00,$00		; 6A = walking block, 6B = walking cloud, 6C = walking p-switch
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

SpriteContact:
	PHY									; store the contact type to scratch ram based on the indexed sprite's ID
	PHX
	TYX
	LDA $7FAB9E,X
	PLX
	TAY
	LDA SpriteContactType,Y
	STA $0F
	PLY
	
	LDA $0F								; point to different routines based on the contact type
	JSL $0086DF
		dw .return
		dw DragSprite
		dw DragStunSprite

.return
	RTS


DragStunSprite:
	LDA #$09					; set the contact sprite's status to carriable
	STA $14C8,Y

DragSprite:
	TYA							; store the sprite slot of the contact sprite
	STA $160E,X
	
	LDA #$01					; disable block interaction for the contact sprite
	STA $15DC,Y
	
;	LDA #$02					; set the phase to 'flying back'
;	STA $C2,X
	
;	STZ $1528,X					; set the speed to 0

	RTS


HandleContactSprite:
	LDA $160E,X					; if the boomerang is carrying a sprite...
	BMI .return
	
	TAY
	
	LDA $14C8,Y					; if the carried sprite is not in an alive status, unload the contact sprite
	CMP #$08
	BCC UnloadContactSprite
	CMP #$0B					; else, if in carried status, unload the contact sprite
	BEQ UnloadContactSprite
	
	LDA $E4,X					; else, set the contact sprite's position equal to the boomerang's position
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	LDA #$00					; set the contact sprite's x and y speeds to 0
	STA $B6,Y
	STA $AA,Y

.return
	RTS


UnloadContactSprite:
	LDA #$00					; enable block interaction for the contact sprite
	STA $15DC,Y
	
	LDA #$FF					; set the boomerang to not carry a sprite
	STA $160E,X
	RTS


TileProp:
	db %00100001,%01100001,%11100001,%10100001

Graphics:
	LDA $C2,X					; if the boomerang is inactive, don't draw gfx
	BEQ .return
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$EC					; tile ID
	STA $0302,Y
	
	PHY
	LDA $1570,X					; store the animation frame into Y (4 animation frames of 4 frames each)
	LSR #2
	AND #%00000011
	TAY
	LDA TileProp,Y				; store tile YXPPCCCT properties based on the animation frame to OAM
	ORA #%00000100
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3

.return
	RTS