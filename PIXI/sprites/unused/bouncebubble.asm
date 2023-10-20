; bubble sprite that Mario and sprites can bounce off of in 4 directions
; the first extension byte sets the x speed
; the second extension byte sets the y speed
; the third extension byte sets the type (0 = normal, 1 = death)
;
; relevant sprite-indexed addresses:
;	$C2,X		=	phase (0 = normal, 1 = popped)
;	$151C,X		=	animation timer
;	$154C,X		=	timer to temporarily disable contact with Mario (set when Mario bounces off the bubble)
;	$1558,X		=	timer to temporarily make the animation faster (set when Mario or a sprite bounces off the bubble)


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
	LDA $7FAB40,X				; set x speed based on the value in the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set y speed based on the value in the second extension byte
	STA $AA,X
	
	%RaiseSprite1Pixel()
	
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
	INC $151C,X					; increment the animation timer
	
	LDA $C2,X					; if the bubble is popping, don't update its position
	BNE +
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	+
	
	LDA $C2,X					; point to different routines based on the phase
	JSL $0086DF
		dw BubbleNormal
		dw BubblePopped

.return
	RTS


OuterTileX:
	db $F9,$F8,$F9,$FA,		$07,$08,$07,$06,	$F9,$F8,$F9,$FA,	$07,$08,$07,$06
OuterTileY:
	db $F9,$FA,$F9,$F8,		$F9,$FA,$F9,$F8,	$07,$06,$07,$08,	$07,$06,$07,$08
OuterTileProp:
	db %00100001,%01100001,%10100001,%11100001
PopTilesX:
	db $F9,$07,$F9,$07
PopTilesY:
	db $F9,$F9,$07,$07
PopTilesID:
	db $00,$00,$00,$00,$64,$64,$66,$66

Graphics:
	LDA $1558,X						; if the animation speed-up timer is set...
	BEQ +
	LDA $151C,X						; store the animation frame to scratch ram (changing every 2 frames)
	AND #%00000110
	LSR
	STA $02
	BRA .animationratestored
	+
	
	LDA $151C,X						; else, store the animation frame to scratch ram (changing every 8 frames)
	AND #%00011000
	LSR #3
	STA $02

.animationratestored
	LDA $151C,X						; store the animation timer to scratch ram
	STA $04
	LDA $7FAB58,X					; store the bubble type to scratch ram
	STA $05

.skipbubblecounter
	%GetDrawInfo()					; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	PHX
	
	LDA $C2,X						; if the bubble is popping, skip to only drawing the pop animation
	BEQ +
	JMP .popanimation
	+


; OUTER TILES GRAPHICS
	LDX #$03						; load loop counter (4 bubble outer tiles)

.outertileloop
	PHX
	
	TXA								; change the index for x/y offsets: loop counter (tile id) x4 + animation frame
	ASL #2
	CLC : ADC $02
	TAX
	
	LDA $00							; tile x position
	CLC : ADC OuterTileX,X
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC OuterTileY,X
	STA $0301,Y
	
	PLX
	
	LDA #$A0						; tile ID
	STA $0302,Y
	
	LDA OuterTileProp,X				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY								; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	INY #4							; increment OAM index
	DEX								; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .outertileloop


; GLIMMER TILE GRAPHICS
	LDA $00							; tile x position
	STA $0300,Y
	
	LDA $01							; tile y position
	STA $0301,Y
	
	LDA #$99						; tile ID
	STA $0302,Y
	
	LDA #%00000011					; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY								; set the tile size to 8x8 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$00
	STA $0460,Y
	PLY
	
	INY #4							; increment OAM index


; DEATH SKULL TILE GRAPHICS
	LDA $05							; if not a death skull bubble, don't draw the death skull
	BEQ GFXEndRoutine
	
	LDA $00							; tile x position
	STA $0300,Y
	
	LDA $01							; tile y position
	STA $0301,Y
	
	LDA #$86						; tile ID
	STA $0302,Y
	
	LDA #%00000001					; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY								; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	INY #4							; increment OAM index
	BRA GFXEndRoutine


; POP WATER GRAPHICS
.popanimation
	LDA $04							; don't show the pop water tiles for the first 4 frames of the animation
	CMP #$04
	BCS +
	JMP GFXEndRoutine
	+
	
	LDX #$03						; load loop counter (4 bubble outer tiles)

.poptilesloop
	LDA $00							; tile x position
	CLC : ADC PopTilesX,X
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC PopTilesY,X
	STA $0301,Y
	
	PHX
	LDA $04							; tile id based on the animation frame
	TAX
	LDA PopTilesID,X
	STA $0302,Y
	PLX
	
	LDA #%00010010					; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY								; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	INY #4							; increment OAM index
	DEX								; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .poptilesloop


; GRAPHICS END-ROUTINE
GFXEndRoutine:
	PLX
	LDA #$06						; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


BubbleNormal:
	JSR CheckSolid
	JSR CheckSpriteContact
	JSR CheckMarioContact
	RTS


CheckSpriteContact:
	LDY #$0B					; load highest sprite slot for loop

.loopstart
	LDA $14C8,Y					; if the sprite is not in an alive status, skip
	CMP #$08
	BCC .loopcontinue
	CPY $15E9					; if the sprite is the bubble itself, skip
	BEQ .loopcontinue
	LDA $1564,Y					; if the sprite is set to not interact with other sprites, skip
	BNE .loopcontinue
	LDA $14C8,Y					; if the sprite is in carried status, skip
	CMP #$0B
	BEQ .loopcontinue
	
	JSR SpriteContact			; check for contact with it

.loopcontinue
	DEY
	BPL .loopstart

.return
	RTS


SpriteContact:
	LDA $14E0,X					; store the clipping x point to scratch ram
	XBA
	LDA $E4,X
	REP #$20
	SEC : SBC #$0003
	SEP #$20
	STA $00
	XBA
	STA $08
	
	LDA $14D4,X					; store the clipping y point to scratch ram
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0002
	SEP #$20
	STA $01
	XBA
	STA $09
	
	LDA #$16					; store the clipping width to scratch ram
	STA $02
	LDA #$18					; store the clipping height to scratch ram
	STA $03
	
	PHX
	TYX
	JSL $03B69F					; get the indexed sprite's clipping values
	PLX
	
	JSL $03B72B					; if not in contact, return
	BCC .return
	
	JSR BounceSprite

.return
	RTS


BounceSpriteXSpeed:
	db $40,$C0

BounceSprite:
	LDA #$08					; play boing sfx
	STA $1DFC
	
	LDA #$18					; speed up the bubble animation for 24 frames
	STA $1558,X
	
	LDA #$04					; briefly disable contact with other sprites for the contact sprite
	STA $1564,Y
	
	LDA $D8,Y					; store the contact sprite's y to scratch ram
	STA $00
	LDA $14D4,Y
	STA $01
	
	LDA $14D4,X					; take the bubble's y position
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $00				; subtract the contact sprite's y position
	CLC : ADC #$000B			; if the contact sprite's y is low enough, bounce it downward
	BMI .bouncespritebottom
	SEC : SBC #$0017			; else, if the contact sprite's y is high enough, bounce it upward
	BPL .bouncespritetop
	SEP #$20

.bouncespriteside
	LDA $E4,Y					; store the contact sprite's x to scratch ram
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY							; store an index based on whether the contact sprite is left or right of the bubble
	LDY #$00
	LDA $14E0,X
	XBA
	LDA $E4,X
	REP #$20
	CMP $02
	BMI +
	INY
	+
	SEP #$20
	LDA BounceSpriteXSpeed,Y	; bounce the contact sprite sideways based on its x relative to the bubble's x
	PLY
	STA $B6,Y
	BRA .return

.bouncespritetop
	SEP #$20
	LDA $AA,Y					; if the contact sprite is moving up, bounce it sideways
	BMI .bouncespriteside
	LDA #$A8					; else, bounce the contact sprite upward (A8 = Mario's y speed when jumping off an enemy, A0 = Mario's y speed when jumping off a noteblock)
	STA $AA,Y
	BRA .return

.bouncespritebottom
	SEP #$20
	LDA $AA,Y					; if the contact sprite is moving down, bounce it sideways
	DEC
	BPL .bouncespriteside
	LDA #$40					; bounce the contact sprite downward (46 = max falling speed for Mario)
	STA $AA,Y

.return
	RTS


BounceMarioXSpeed:
	db $40,$C0

CheckMarioContact:
	LDA $154C,X					; if the 'disable player contact' timer is set, don't check for contact
	BNE .return
	
	LDA #$FD : STA $7FA000		; set hitbox x
	LDA #$FE : STA $7FA001		; set hitbox y
	LDA #$16 : STA $7FA002		; set hitbox width
	LDA #$18 : STA $7FA003		; set hitbox height
	
	JSL $01A7DC					; check for interaction with Mario; if in contact...
	BCC .return
	
	LDA $7FAB58,X				; if it's a death skull bubble, kill Mario and return
	BEQ +
	JSL $00F606
	BRA .return
	+
	
	LDA #$08					; else, play boing sfx
	STA $1DFC
	
	LDA #$18					; speed up the bubble animation for 24 frames
	STA $1558,X
	
	LDA #$04					; disable player contact for 4 frames
	STA $154C,X
	
	LDA $14D4,X					; take the bubble's y position
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $96				; subtract Mario's y position
	SBC #$0003					; if Mario's y is low enough, bounce him downward
	BMI .bouncemariobottom
	SBC #$001B					; else, if Mario's y is high enough, bounce him upward
	BPL .bouncemariotop
	SEP #$20

.bouncemarioside
	%SubHorzPos()				; else, bounce Mario sideways based on his x relative to the bubble's x
	LDA BounceMarioXSpeed,Y
	STA $7B
	BRA .return

.bouncemariotop
	SEP #$20
	LDA $7D						; if Mario is moving up, bounce him sideways
	BMI .bouncemarioside
	LDA #$A8					; else, bounce Mario upward (A8 = speed when jumping off an enemy, A0 = speed when jumping off a noteblock)
	STA $7D
	BRA .return

.bouncemariobottom
	SEP #$20
	LDA $7D						; if Mario is moving down, bounce him sideways
	BPL .bouncemarioside
	LDA #$40					; bounce Mario downward (46 = max falling speed)
	STA $7D

.return
	RTS


CheckSolid:
	JSL $019138					; process interaction with blocks
	LDA $1588,X					; if touching a block, pop the bubble
	AND #%00001111
	BEQ .return
	JSR PopBubble

.return
	RTS


PopBubble:
	LDA #$19					; play clap sfx
	STA $1DFC
	STZ $151C,X					; set the animation timer to 0
	INC $C2,X					; set the contact phase to 1 (bubble popped)
	RTS


BubblePopped:
	LDA $151C,X					; if the animation timer is at 8, erase the bubble sprite
	CMP #$08
	BNE .return
	STZ $14C8,X

.return
	RTS