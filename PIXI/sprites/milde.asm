; milde enemy; can be bounced high on from the top, and gives Mario and item sprites horizontal boosts on the side
; the extension byte sets the walking speed

; $C2,X		=	clashed flag (set when hit by a kicked item)
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $157C,X	=	face direction
; $1602,X	=	animation frame counter


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
	LDA $7FAB40,X				; set the x speed based on the extension byte
	STA $B6,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0D : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$FF : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0E : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	INC $157C,X					; make the sprite face left (base face direction if the sprite has no x speed)
	
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
	
	JSR HandleClash
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


HandleClash:
	LDA $C2,X					; if the clashed flag is set...
	BEQ .return
	
	LDA $1588,X					; else, if the sprite is touching a solid tile below...
	AND #%00000100
	BEQ .return
	
	LDA $7FAB40,X				; load the base x speed to scratch ram
	BMI +						; if positive...
	STA $00						; store the positive value to scratch ram
	EOR #$FF					; invert the value
	INC A
	STA $01						; store the negative value to scratch ram
	BRA .basespeedloaded
	+
	STA $01						; else, store the negative value to scratch ram
	EOR #$FF					; invert the value
	INC A
	STA $00						; store the positive value to scratch ram

.basespeedloaded
	LDA $B6,X					; if the x speed is positive...
	BMI .xspeednegative
	CMP $00						; and it is at or above the positive base x speed...
	BMI +
	BEQ +
	DEC $B6,X					; decrement it
	RTS
	+
	
	LDA $00						; else, set the x speed to the positive base x speed
	BRA .unclash

.xspeednegative
	CMP $01						; else (the x speed is negative), if it is below the negative base x speed...
	BPL +
	INC $B6,X					; increment it
	RTS
	+
	
	LDA $01						; else, set the x speed to the negative base x speed

.unclash
	STA $B6,X
	STZ $C2,X					; set the clashed flag to 0

.return
	RTS


HandleAnimation:
	LDA $B6,X					; if the x speed is 0...
	BNE +
	LDA #$1C					; set the animation frame counter to #$1C
	STA $1602,X
	RTS
	+
	
	LDA $C2,X					; else, if the clashed flag is set...
	BEQ +
	LDA $1602,X					; increment the animation frame counter by 4
	CLC : ADC #$04
	STA $1602,X
	BRA .animationstored
	+
	
	INC $1602,X					; else, increment the animation frame counter

.animationstored
	LDA $1602,X					; if the animation frame counter is at (or above) #$1C, set it back to 0
	CMP #$1C
	BCC +
	STZ $1602,X
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


ClashXSpeed:
	db $D3,$2D
ItemClashXSpeed:
	db $D0,$30

NormalInteraction:
	LDA #$08					; play boing sfx
	STA $1DFC
	
	LDA #$08					; set the 'disable contact with Mario' timer
	STA $154C,X
	
	JSL $01AB99					; display contact star below Mario
	
	%CheckBounceMario()			; if Mario is not positioned to bounce off the top of the sprite, bounce him off the side
	BCC BounceMarioSide
	BRA BounceMarioTop			; else, bounce him off the top
	RTS


BounceMarioTop:
	LDA #$B8					; give Mario #$B8 speed without B/A held, or #$A0 with B/A held
	BIT $15
	BPL +
	LDA #$A0
	+
	STA $7D
	RTS


BounceXSpeed:
	db $30,$D0

BounceMarioSide:
	%SubHorzPos()				; based on Mario's x compared to the sprite's x...
	LDA BounceXSpeed,Y			; bounce Mario sideways
	STA $7B
	
	LDA #$01					; set the clashed flag
	STA $C2,X
	
	%SubHorzPos()				; set the milde's x speed depending on the direction towards Mario
	LDA ClashXSpeed,Y
	STA $B6,X
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
	
	LDA $14C8,Y					; if the indexed sprite is in normal status...
	CMP #$08
	BEQ DoBumpSprites			; turn both sprites around
	CMP #$09					; if the indexed sprite is in carryable status...
	BEQ KickItem				; kick the item
	CMP #$0A					; if the indexed sprite is in kicked status...
	BEQ ClashMilde				; handle clashing it with the milde
	RTS


DoBumpSprites:			%BumpSprites() : RTS
Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS


KickItem:
	LDA $E4,X					; store the milde's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $E4,Y					; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	
	LDY #$00					; check which side of the milde the indexed sprite is on, and store it to Y
	REP #$20
	LDA $00
	SEC : SBC $02
	BMI +
	LDY #$01
	+
	SEP #$20
	
	LDA ItemClashXSpeed,Y		; set the indexed sprite's x speed depending on the direction towards the milde
	PLY
	EOR #$FF
	INC A
	STA $B6,Y
	
	LDA #$0A					; set the indexed sprite's status to kicked
	STA $14C8,Y
	
	LDA #$08					; disable contact with other sprites for 8 frames for the milde
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	RTS


ClashMilde:
	LDA $E4,X					; store the milde's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $E4,Y					; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	LDA $B6,Y					; store the indexed sprite's x speed to scratch RAM
	STA $04
	
	PHY
	
	LDY #$00					; check which side of the milde the indexed sprite is on, and store it to Y
	REP #$20
	LDA $00
	SEC : SBC $02
	BMI +
	LDY #$01
	+
	SEP #$20
	
	CPY #$00					; if the indexed sprite is to the left of the milde and is moving rightward, or vice-versa...
	BEQ +
	LDA $04
	BMI .skipbump
	BRA .bump
	+
	LDA $04
	BPL .skipbump

.bump
	LDA #$01					; set the clashed flag
	STA $C2,X
	
	LDA ClashXSpeed,Y			; set the milde's x speed depending on the direction towards the indexed sprite
	STA $B6,X

.skipbump
	STY $00						; store the relative direction to scratch ram
	PLY
	
	PHX
	LDA $B6,Y					; make the indexed sprite's x speed positive...
	BPL +
	EOR #$FF
	INC A
	+
	LDX $00						; then invert it based on the relative direction to the milde
	BEQ +
	EOR #$FF
	INC A
	+
	STA $B6,Y
	PLX
	
	LDA #$08					; disable contact with other sprites for 8 frames for the milde
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
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
	db $FD,$FD,$FD,$FE,$FF,$FE,$FD,$FE

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
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

; body tile
	LDA $00						; tile x position
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC BodyTileY,X
	STA $0301,Y
	
	LDA #$CE					; tile ID
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