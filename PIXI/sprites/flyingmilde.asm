; flying milde enemy; can be bounced high on from the top, and gives Mario and item sprites horizontal boosts on the side

; $C2,X		=	clashed flag (set when hit by a kicked item)
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction


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
	LDA #$00					; set the base x speed to 0
	STA $7FAB40,X
	
;	LDA $7FAB40,X				; set x speed based on the value in the first extension byte
;	STA $B6,X
;	LDA $7FAB4C,X				; set y speed based on the value in the second extension byte
;	STA $AA,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%RaiseSprite1Pixel()
	
	INC $157C,X					; make the sprite face left (base face direction if the sprite has no x speed)
	
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
	
	INC $1570,X					; increment the animation frame counter
	JSR HandleClash
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $B6,X					; if the x speed is not 0...
	BEQ +
	STZ $157C,X					; set the face direction based on the x speed
	BPL +
	INC $157C,X
	+
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


HandleClash:
	LDA $C2,X					; if the clashed flag is set...
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
	LDA $14C8,Y					; if the indexed sprite is in carryable status...
	CMP #$09
	BEQ KickItem				; kick the item
	CMP #$0A					; if the indexed sprite is in kicked status...
	BEQ ClashMilde				; handle clashing it with the milde
	RTS


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
	BMI .skipbumptaptap
	BRA .bumptaptap
	+
	LDA $04
	BPL .skipbumptaptap

.bumptaptap
	LDA #$01					; set the clashed flag
	STA $C2,X
	
	LDA ClashXSpeed,Y			; set the milde's x speed depending on the direction towards the indexed sprite
	STA $B6,X

.skipbumptaptap
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


WingTiles:
	db $5D,$C6,$5D,$C6
WingSize:
	db $00,$02,$00,$02
WingXDisp:
	db $FB,$F3,$0D,$0D
WingYDisp:
	db $02,$FA,$02,$FA
WingProps:
	db $76,$76,$36,$36

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $1570,X					; store the wings animation frame into scratch ram (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	STA $02
	
	PHX
	LDA $157C,X					; store the face direction as an index
	TAX
	PLX

; body tile
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$CE					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; tile YXPPCCCT properties
	PHY
	
	LDY $157C,X					; flip x based on face direction
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

; wing tiles
	LDX #$01					; use X for the loop counter - X is set to #$01 since there are 2 wing tiles

.WingsLoop
	INY #4						; increment Y (the OAM index) by 4
	
	PHX							; load the loop counter, multiply it by 2, add the animation frame (0 or 1), and store it to X
	TXA
	ASL
	CLC : ADC $02
	TAX
	
	LDA $00						; offset the wing tile's x position from the sprite's x depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingXDisp,X
	STA $0300,Y
	
	LDA $01						; offset the wing tile's y position from the sprite's y depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingYDisp,X
	STA $0301,Y
	
	LDA WingTiles,X				; store tilemap number (see Map8 in LM) based on the wing tile and animation frame to OAM
	STA $0302,Y
	
	LDA $64						; store the priority and other properties to OAM
	ORA WingProps,X
	STA $0303,Y
	
	PHY							; set the tile size depending on the animation frame (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA WingSize,X
	STA $0460,Y
	PLY
	
	PLX
	
	DEX							; decrement the loop counter and loop to draw the second wing tile if the loop counter is still positive
	BPL .WingsLoop
	
	LDX $15E9					; restore the sprite slot into X
	
	LDA #$02					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS