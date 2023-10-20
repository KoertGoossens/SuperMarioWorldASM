; milde that can jump into and be knocked out of shells like a koopa
; the extension byte sets the walking speed

; $C2,X		=	knocked flag (set when knocked out of a shell)
; $1540,X	=	timer to disable entering shells
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1594,X	=	stored x speed (set when knocked out of a shell)


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
	LDA $C2,X					; if the milde isn't spawned being knocked out of a shell...
	BNE +
	LDA $7FAB40,X				; set the x speed based on the extension byte
	STA $B6,X
	
	INC $157C,X					; make the sprite face left (base face direction if the sprite has no x speed)
	+
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$01 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0C : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$02 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$00 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0B : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0D : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; branch if the sprite is dead
	CMP #$08
	BNE .return
	
	LDA $C2,X					; if the knocked flag is set...
	BEQ .skipknocked
	
	LDA $B6,X					; if the x speed is 0...
	BNE +
	LDA $1594,X					; set the x speed to the stored x speed value
	STA $B6,X
	STZ $C2,X					; set the knocked flag to 0
	BRA .skipknocked
	+
	
	LDA $1588,X					; else, if the sprite is touching a solid tile below...
	AND #%00000100
	BEQ .skipknocked
	
	LDA $B6,X					; else, if the x speed is positive...
	BMI +
	DEC $B6,X					; decrement it
	BRA .skipknocked
	+
	INC $B6,X					; else (the x speed is negative), increment it

.skipknocked
	JSR HandleAnimation
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $B6,X					; invert the x speed
	EOR #$FF
	INC A
	STA $B6,X
	+
	
	LDA $C2,X					; if the knocked flag is not set...
	BNE +
	LDA $B6,X					; if the x speed is not 0...
	BEQ +
	STZ $157C,X					; set the face direction based on the x speed
	BPL +
	INC $157C,X
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()
	
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


HandleGravity:		%ApplyGravity() : RTS


HandleAnimation:
	LDA $B6,X					; if the x speed is 0...
	BNE +
	LDA #$1C					; set the animation frame counter to #$1C
	STA $1570,X
	RTS
	+
	
	LDA $C2,X					; else, if the knocked flag is set...
	BEQ +
	LDA $1570,X					; increment the animation frame counter by 4
	CLC : ADC #$04
	STA $1570,X
	BRA .animationstored
	+
	
	LDA $1588,X					; else, if the sprite is in the air...
	AND #%00000100
	BNE +
	STZ $1570,X					; set the animation frame counter to 0
	RTS
	+
	
	INC $1570,X					; else, increment the animation frame counter

.animationstored
	LDA $1570,X					; if the animation frame counter is at (or above) #$1C, set it back to 0
	CMP #$1C
	BCC +
	STZ $1570,X
	+
	
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
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; else if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BounceMarioNormal:
	LDA #$03					; play bounce sfx
	STA $1DF9
	
	%BounceMario()				; have Mario bounce up
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
	
	LDA $14C8,Y
	CMP #$08					; if the indexed sprite is also in normal status...
	BEQ DoBumpSprites			; turn both sprites around (for indexed sprites in item statuses, the indexed sprite should initiate the contact check)
	
	JSR CheckShell
	RTS


DoBumpSprites:			%BumpSprites() : RTS
Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS


CheckShell:
	LDA $1540,X					; if the milde's 'disable entering shells' timer is set...
	BNE .return
	
	PHX							; if the indexed sprite is a shell...
	TYX
	LDA $7FAB9E,X
	PLX
	CMP #$0F
	BNE .return
	
	LDA $14C8,Y					; and it's not in carried status...
	CMP #$0B
	BEQ .return
	
	LDA $187B,Y					; and the shell doesn't already have a sprite inside it...
	BNE .return
	
	LDA #$01					; set the 'sprite inside' flag for the shell
	STA $187B,Y
	
	LDA #$60					; set the shell's stun timer
	STA $1540,Y
	
	LDA $7FAB40,X				; store the milde's base x speed for the shell
	STA $1504,Y
	
	%SmokeKillSprite()

.return
	RTS


LegTile1X:
	db $03,$04,$05,$07,$07,$06,$01,$03
LegTile1Y:
	db $0B,$0B,$0B,$0B,$08,$09,$08,$0C
LegTile1ID:
	db $AB,$AB,$AB,$AB,$AA,$AA,$AA,$BA
LegTile1Prop:
	db %00100011,%00100011,%00100011,%00100011,%01100011,%01100011,%01100011,%01100011

LegTile2X:
	db $FF,$FA,$F9,$F5,$F8,$FB,$FF,$FD
LegTile2Y:
	db $08,$05,$07,$05,$0A,$0C,$0C,$0C
LegTile2ID:
	db $AA,$AB,$AB,$AA,$AB,$BA,$BA,$BA
LegTile2Prop:
	db %00100011,%11100011,%01100011,%01100011,%01100011,%00100011,%00100011,%00100011

BodyTileY:
	db $FD,$FD,$FD,$FE,$FF,$FE,$FD,$FE

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $157C,X					; store the face direction to scratch ram
	STA $04
	
	LDA $1570,X					; load the animation frame
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

; body tile
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC BodyTileY,X
	STA $0301,Y
	
	LDA #$A2					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; load tile YXPPCCCT properties
	
	PHY
	LDY $04						; flip x based on face direction
	BNE +
	EOR #%01000000
	+
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