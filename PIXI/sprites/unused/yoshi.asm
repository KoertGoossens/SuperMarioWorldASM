; custom adult Yoshi sprite
; this requires an edit at $0180C3 to work (preventing $187A from being set to 0 when no vanilla Yoshis are present)
; the extension byte determines whether the Yoshi is vanilla-style or has custom features

; sprite-indexed addresses specific to Yoshi:
;	$C2,X		=	state (0 = normal, 1 = ridden by Mario, 2 = running after damage)
;	$1504,X		=	stored animation frame (set equal to $1602,X prior to updating $1602,X - the Yoshi gfx routine then uses the old animation frame $1504,X while Mario uses the updated $1602,X since Mario's gfx lags behind a frame)
;	$151C,X		=	Yoshi's tongue length
;	$1528,X		=	animation frame counter (replaces $18AD to make it sprite-indexed)
;	$1534,X		=	squatting timer (replaces $18AF to make it sprite-indexed)
;	$154C,X		=	mount cooldown timer (for custom drop-dismounts)
;	$1558,X		=	tongue delay timer (time to wait before retracting tongue when it's at max length, and time to wait before sticking tongue out after spitting something)
;	$1564,X		=	swallow animation timer
;	$1570,X		=	animation frame timer
;	$157C,X		=	face direction (0 = right, 1 = left)
;	$1594,X		=	mouth phase (0 = neutral, 1 = extending tongue, 2 = retracting tongue, 3 = spitting)
;	$15AC,X		=	timer for turning around (set to #$10 at the start of a turn)
;	$1602,X		=	animation frame (	0/1/2 = walking, 2 = falling, 3 = turning, 4 = crouching, 5 = jumping, 6 = tongue out (high)
;										7 = tongue out (low), 8/9 = entering horizontal pipe, A/B/C = growing)
;	$160E,X		=	sprite slot of sprite on Yoshi's tongue or in his mouth (#$FF when no sprite)
;	$1626,X		=	tongue extension timer (replaces $18AE to make it sprite-indexed)
;	$163E,X		=	timer to disable contact with other sprites
;	$187B,X		=	swallow delay timer (replaces $18AC to make it sprite-indexed), also used to check whether Yoshi has a sprite in his mouth

; other Yoshi-related addresses:
;	$14A3		=	Yoshi's punch animation timer
;	$1879		=	(freeram address) sprite slot of the Yoshi that's about to stick out its tongue (set when Mario punches him)
;	$187A		=	'on Yoshi' flag (0 = not on Yoshi, 1 = on Yoshi, 2 = on Yoshi and turning around)
;	$18DC		=	'ducking with Yoshi' flag


!AllowAutoMount					=	#$00		; automatically mount a Yoshi when the level loads (if there is a spawned Yoshi) (vanilla = #$00)
!AllowDropDismount				=	#$01		; allow drop-dismounting Yoshi when pressing A while holding down in mid-air (vanilla = #$00)
!DropDismountYoshiYSpeed		=	#$C0		; y speed to give Yoshi after drop-dismounting
!DropDismountMarioYSpeed		=	#$10		; y speed to give Mario after drop-dismounting
!AllowMidairDownSpit			=	#$00		; allow spitting an item down in mid-air (vanilla = #$00)
!CooldownAfterSpit				=	#$04		; number of frames to prevent sticking out Yoshi's tongue after spitting (vanilla = #$10)

!NumTurnFrames					=	#$08		; total number of frames a turn-around takes (vanilla = #$10)
!NumMidTurnFrames				=	#$04		; set this to half of the above value


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
	LDA #$04 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$13 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$08 : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$08 : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$FF : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$03 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$11 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$08 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	DEC $160E,X					; initialize the sprite slot in Yoshi's mouth to null (#$FF)
	
	LDA !AllowAutoMount			; if auto-mounts are allowed...
	BEQ .return
	LDA $13C8					; and Mario is set to mount Yoshi automatically (set by level UberASM init)...
	CMP #$01
	BNE .return
	
	LDA $14D4,X					; set Mario's y 16 pixels above Yoshi's y
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0010
	STA $96
	STA $D3
	SEP #$20
	
	STZ $7B						; set Mario's x speed to 0
	STZ $7D						; set Mario's y speed to 0
	
	LDA #$01					; set Yoshi's state to being ridden
	STA $C2,X
	
	INC $13C8					; increase the auto-mount Yoshi flag to 2 (so no other Yoshi will mount Mario at the same time)

.return
	RTS


SpriteCode:
	LDA $13C8					; if the auto-mount flag is set to 2 (to spawn Mario on Yoshi)...
	CMP #$02
	BNE +
	STZ $72						; set Mario on the ground (to prevent Yoshi from drawing an airborne animation frame)
	INC $13C8					; set the auto-mount flag to 3
	+
	
	LDA $9D						; if the game is frozen, only draw the graphics
	BNE .dographics
	LDA $14C8,X					; if the sprite is dead, only draw the graphics
	CMP #$08
	BNE .dographics
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $C2,X					; if the Yoshi is being ridden, skip to .yoshiridden
	CMP #$01
	BEQ .yoshiridden

; not riding Yoshi
	JSL $01802A					; update x and y position with gravity, and process interaction with blocks
	
	LDA $1588,X					; if Yoshi is on the ground...
	AND #%00000100
	BEQ +
	LDA $C2,X					; and Yoshi is not damage-running...
	CMP #$02
	BCS +
	STZ $B6,X					; set his x speed to 0
	LDA #$F0					; set his y speed to F0 (idle bouncing)
	STA $AA,X
	+
	
;	LDA #$00					; update Yoshi's face direction based on his x speed
;	LDY $B6,X					; LEAVING THIS VANILLA FEATURE OUT WILL MAKE YOSHI NOT TURN AROUND WHEN DISMOUNTING WHILE GOING BACKWARDS IN THE AIR
;	BEQ ++
;	BPL +
;	INC A
;	+
;	STA $157C,X
;	++
	
	LDA $1588,X					; if touching a solid tile on the side...
	AND #%00000011
	BEQ +
	LDA $B6,X					; invert Yoshi's x speed...
	EOR #$FF
	INC A
	STA $B6,X
	LDA $157C,X					; and flip Yoshi's face direction
	EOR #$01
	STA $157C,X
	+
	
	LDA $1588,X					; (custom) if Yoshi is touching the ceiling...
	AND #%00001000
	BEQ +
	LDA #$10					; give it some downward speed (#$10 = downward speed carryable items get from hitting the ceiling after an uptoss)
	STA $AA,X
	+
	
	JSR HandleMarioContact
	BRA .dographics

.yoshiridden
	JSR HandleSpriteInteraction

; check for turn-around initiation
	LDA $15						; if left or right is pressed...
	AND #%00000011
	BEQ +
	DEC A
	CMP $157C,X					; and Yoshi is not already facing the pressed direction...
	BEQ +
	LDA $15AC,X					; and not already turning...
	ORA $151C,X					; and his tongue is not out...
	ORA $18DC					; and not ducking ('ducking with Yoshi' flag)
	BNE +
	LDA !NumTurnFrames			; set the turn-around timer to the specified value
	STA $15AC,X
	+

; check for dismounting
	LDA $18						; if A is pressed, dismount Yoshi
	AND #%10000000
	BEQ +
	JSR DismountYoshi
	+

.dographics
	JSR StoreAnimationFrame
	
	LDA $187A					; if not riding a Yoshi, set the y offset of Mario's image to 0 (this will be set to non-zero if Mario is riding Yoshi)
	BNE +
	STZ $188B
	+
	
	LDA $C2,X					; if Yoshi is being ridden...
	CMP #$01
	BNE .skipridden
	JSR OffsetMarioYoshi		; offset Yoshi's position from Mario's and offset Mario's image
	
	LDA #$01					; set 'riding Yoshi' flag to 1, or 2 if turning around (animation frame = 3)
	LDY $1602,X
	CPY #$03
	BNE +
	INC A
	+
	STA $187A
	
	LDA $157C,X					; face Mario in the same direction as Yoshi
	EOR #$01
	STA $76

.skipridden
	JSR HandleMouth
	JSR ChangeMarioPose
	
	LDA $1564,X					; if the swallow animation timer is set and the animation frame is 7, change it to 6
	BEQ +						; (non-vanilla work-around to prevent Yoshi's head from being offset wrongly)
	LDA $1504,X
	CMP #$07
	BNE +
	LDA #$06
	STA $1504,X
	+
	
	JSR Graphics
	
	LDY $15AC,X					; if the turn-around timer is at 8 (middle of the turn-around animation)...
	CPY !NumMidTurnFrames
	BNE +
	LDA $C2,X					; and Yoshi is not damage-running...
	CMP #$02
	BEQ +
	LDA $157C,X					; invert both Mario's and Yoshi's face direction (the values are actually opposite to each other)
	STA $76
	EOR #%00000001
	STA $157C,X
	+
	
	RTS


StoreAnimationFrame:
	LDA $1602,X					; store the current animation frame
	STA $1504,X
	
	LDY #$00					; load default animation frame (= 0)
	
	LDA $C2,X					; if Yoshi is damage-running...
	CMP #$02
	BNE +
	LDA #$30					; load p-speed for the walking animation
	BRA .walkingspeedloaded
	+
	CMP #$01					; else, if not riding Yoshi, skip to .checkidle
	BNE .checkidle
	STZ $18DC					; else (riding Yoshi), set 'ducking on Yoshi' flag to 0

; check walking
	LDA $7B						; take Mario's x speed
	BEQ .notwalking				; if it's 0, skip the walking animation check
	BPL .walkingspeedloaded		; else, make the value positive
	EOR #$FF
	INC A

.walkingspeedloaded
	LSR #4						; divide it by 16
	TAY
	JSR HandleWalkAnimation
	
	LDA $C2,X					; if Yoshi is damage-running, skip checking for other animation frames
	CMP #$02
	BEQ .storeframe

; check jumping
.notwalking
	LDA $72						; if airborne, load animation frame 2
	BEQ +
	LDY #$02
	LDA $7D						; if falling, load animation frame 5
	BPL +
	LDY #$05
	+

; check turning
	LDA $15AC,X					; if turning, load animation frame 3
	BEQ +
	LDY #$03
	+
	
	LDA $72						; if in the air, don't check for sticking out tongue or ducking
	BNE .storeframe

; check tongue
	LDA $151C,X					; if Yoshi's tongue is out, load animation frame 7
	BNE +
	LDA $14A3					; else, if the punch animation timer is not zero, but below #$0E, load animation frame 7
	BEQ .checksquatting			; (vanilla SMW doesn't check for the punch timer, but it is used here to get the animation to work on the right frames (head down as soon as the tongue is extended))
	CMP #$0B
	BCS .checksquatting
	+
	LDY #$07
	LDA $15						; if holding up, load animation frame 6
	AND #%00001000
	BEQ .storeframe
	LDY #$06
	BRA .storeframe

; check squatting
.checksquatting
	LDA $1534,X					; if Yoshi's squat timer is set...
	BEQ +
	DEC $1534,X					; decrement the squat timer...
	BRA .setduckanimation		; and set the ducking animation
	+

; check ducking
	LDA $15						; if holding down...
	AND #%00000100
	BEQ +
.setduckanimation
	LDY #$04					; load animation frame 4
	INC $18DC					; set 'ducking with Yoshi' flag
	+
	
	BRA .storeframe				; store the animation frame

; check idle
.checkidle
	LDA $151C,X					; (not on Yoshi) if Yoshi's tongue is not out, load animation frame 4
	BNE +
	LDY #$04
	+

; store animation frame
.storeframe
	TYA							; store animation frame
	STA $1602,X
	RTS


WalkFrames:
	db $02,$01,$00
WalkAnimLength:
	db $03,$02,$01,$00

HandleWalkAnimation:
	LDA $9D						; if the game is not frozen...
	BNE +
	DEC $1570,X					; decrement the animation frame timer
	BPL +						; if negative, set the animation frame timer to the value indexed by Mario's x speed...
	LDA WalkAnimLength,Y
	STA $1570,X
	DEC $1528,X					; and decrement the animation frame counter
	BPL +						; if negative, set the animation frame counter back to 2
	LDA #$02
	STA $1528,X
	+
	
	LDY $1528,X					; load the animation frame, indexed by the animation frame counter
	LDA WalkFrames,Y
	TAY
	RTS


; indexes are based on the animation frame:
;	0/1/2 = walking, 2 = falling, 3 = turning, 4 = crouching, 5 = jumping, 6 = tongue out (high), 7 = tongue out (low), 8/9 = entering horizontal pipe, A/B/C = growing)

HeadTileID:
	db $00,$00,$00,$0E,$00,$0C,$2A,$24,$00,$00,$00,$00,$00
HeadTileX:
	db $0A,$09,$0A,$06,$0A,$0A,$0A,$10,$0A,$0A,$00,$00,$0A		; facing right
	db $F6,$F7,$F6,$FA,$F6,$F6,$F6,$F0,$F6,$F6,$00,$00,$F6		; facing left
HeadTileY:
	db $00,$01,$02,$00,$04,$00,$00,$0C,$03,$03,$00,$00,$09

BodyTileID:
	db $02,$06,$0A,$20,$22,$28,$02,$26,$00,$00,$00,$00,$00
BodyTileY:
	db $10,$11,$11,$10,$14,$10,$10,$14,$13,$13,$10,$10,$14

TongueTileX:
	db $F5,$F5,$F5,$F5,$F5,$F5,$F5,$F0,$00,$00,$00,$00,$00		; facing left
	db $13,$13,$13,$13,$13,$13,$13,$18,$00,$00,$00,$00,$00		; facing right
TongueTileY:
	db $08,$08,$08,$08,$08,$08,$08,$13,$00,$00,$00,$00,$00

; throat tile indexes are based on the swallow animation timer (values at 5-6-7-8-9-A-B-C-D-E)
ThroatTileX:
	db $0C,$0C,$0C,$0C,$0C,$0C,$0D,$0D,$0D,$0D					; facing right, not ducking
	db $FC,$FC,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB					; facing left, ducking
	db $0C,$0C,$0C,$0C,$0C,$0C,$0D,$0D,$0D,$0D					; facing right, not ducking
	db $FC,$FC,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB					; facing left, ducking
ThroatTileY:
	db $0E,$0E,$0E,$0D,$0D,$0D,$0C,$0C,$0B,$0B					; facing right, not ducking
	db $0E,$0E,$0E,$0D,$0D,$0D,$0C,$0C,$0B,$0B					; facing left, ducking
	db $12,$12,$12,$11,$11,$11,$10,$10,$0F,$0F					; facing right, not ducking
	db $12,$12,$12,$11,$11,$11,$10,$10,$0F,$0F					; facing left, ducking

TileProp:														; YXPPCCCT
	db %01101011,%00101011

Graphics:
	LDA $1504,X					; if Yoshi's stored animation frame is 3 (turning around), set his OAM index to 0 to draw him in front of Mario
	CMP #$03
	BNE +
	STZ $15EA,X
	+
	
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $157C,X					; store Yoshi's face direction to scratch ram
	STA $02
	LDA $C2,X					; store Yoshi's state to scratch ram
	STA $03
	LDA $151C,X					; store Yoshi's tongue length to scratch ram
	STA $04
	LDA $1594,X					; store Yoshi's mouth phase to scratch ram
	STA $05
	LDA $1626,X					; store Yoshi's tongue extension timer to scratch ram
	STA $06
	LDA $1564,X					; store Yoshi's swallow animation timer to scratch ram
	STA $07
	LDA $187B,X					; store Yoshi's swallow delay timer to scratch ram
	STA $08
	
	PHX
	LDA $1504,X					; load Yoshi's stored animation frame into X
	TAX


; HEAD TILE
	INY #4						; increment OAM index (the throat tile should be drawn on top of the head tile, so the head tile must have a higher OAM index)

; head tile x position
	PHX							; preserve X (animation frame)
	
	LDA $02						; if the sprite is facing left, increase the frame index to #$0D
	BEQ +
	TXA
	CLC : ADC #$0D
	TAX
	+
	
	LDA $00						; tile x position
	CLC : ADC HeadTileX,X		; add x offset based on animation frame
	STA $0300,Y
	
	PLX

; head tile y position
	LDA $01						; tile y position
	CLC : ADC HeadTileY,X		; add y offset based on animation frame
	STA $0301,Y

; head tile id
	LDA $03						; if Yoshi is in normal state...
	BNE +
	LDA $08						; and doesn't have a sprite in his mouth...
	BNE +
	LDA $14						; load the 'mouth open' tile 16 out of every 64 frames...
	AND #%00110000
	BNE ++
	LDA #$2A
	BRA .headtileloaded
	+
	
	CMP #$02					; else, if Yoshi is damage-running...
	BNE ++
	LDA $04						; and Yoshi does not have his tongue out...
	BNE ++
	LDA $14						; show the 'damage' head tile every 16 frames
	AND #$10
	BEQ +++
	LDA #$0C
	BRA .headtileloaded
	++
	
	LDA $05						; else, if Yoshi's mouth phase is 3 (spitting), load the 'mouth open' tile
	CMP #$03
	BEQ ++
	LDA $04						; else, if Yoshi has his tongue out...
	BEQ +
	CPX #$07					; and the animation frame is not 7 (tongue out (low))...
	BEQ +
	++
	LDA #$2A					; load the 'mouth open' tile 
	BRA .headtileloaded
	+
	
	LDA $06						; else, if Yoshi's tongue extension timer is not 0, show the 'damage' head tile
	BEQ +++
	LDA #$0C
	BRA .headtileloaded
	+++
	
	LDA $08						; if Yoshi has a sprite in his mouth...
	BEQ +
	CPX #$07					; and the animation frame is not 7 (tongue out (low))
	BEQ +
	LDA #$04					; show the 'mouth full' head tile
	BRA .headtileloaded
	+
	
	LDA $07						; else, if not currently swallowing, load the head tile based on the animation frame
	BEQ .defaultheadtile
	CMP #$0F					; else, if the swallow animation timer is below 0F...
	BCS +
	LDA #$00					; and use head tile 80
	BRA .headtileloaded
	+
	LDA #$04					; else, use head tile 84
	BRA .headtileloaded

.defaultheadtile
	LDA HeadTileID,X			; else, load the tile id based on the animation frame
.headtileloaded
	STA $0302,Y

; head tile properties
	PHY							; tile properties (x-flip based on face direction)
	LDY $02
	LDA TileProp,Y
	PLY
	ORA $64
	STA $0303,Y

; head tile size
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY


; THROAT TILE
	DEY #4						; decrement OAM index (the throat tile should be drawn on top of the head tile, so the head tile must have a higher OAM index)
	
	LDA $07						; only draw the throat tile for 10 frames (when the swallow animation timer is at 5-6-7-8-9-A-B-C-D-E)
	CMP #$0F
	BCS .drawbodytile
	CMP #$05
	BCC .drawbodytile
	
	PHX							; preserve the animation frame in X
	
	SEC : SBC #$05				; decrease the value by #$05
	LDX $18DC					; if ducking on Yoshi, increase the value by #$14
	BEQ +
	CLC : ADC #$14
	+
	LDX $02						; increase the value by #$0A based on Yoshi's face direction
	BEQ +
	CLC : ADC #$0A
	+
	TAX							; store the loaded value as an index

; throat tile x position
	LDA $00						; tile x position
	CLC : ADC ThroatTileX,X
	STA $0300,Y

; throat tile y position
	LDA $01						; tile y position
	CLC : ADC ThroatTileY,X
	STA $0301,Y

; throat tile id
	LDA #$67					; tile id
	STA $0302,Y

; throat tile properties
	PHY							; tile properties (x-flip based on face direction)
	LDY $02
	LDA TileProp,Y
	PLY
	ORA $64
	STA $0303,Y

; throat tile size
	PHY							; set the tile size to 8x8 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$00
	STA $0460,Y
	PLY
	
	PLX


; BODY TILE
.drawbodytile
	INY #8						; increment OAM index twice (after head and throat tile)

; body tile x position
	LDA $00						; tile x position
	STA $0300,Y

; body tile y position
	LDA $01						; tile y position
	CLC : ADC BodyTileY,X		; add y offset based on animation frame
	STA $0301,Y

; body tile id
	LDA BodyTileID,X			; tile id based on animation frame
	STA $0302,Y

; body tile properties
	PHY							; tile properties (x-flip based on face direction)
	LDY $02
	LDA TileProp,Y
	PLY
	ORA $64
	STA $0303,Y

; body tile size
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY


; TONGUE TILES
	LDA $05						; if Yoshi's mouth phase is 0 (neutral mouth) or 3 (spitting), skip drawing the tongue tiles
	BEQ .gfxend
	CMP #$03
	BEQ .gfxend
	
	PHX
	LDA $02						; if the sprite is facing left, increase the animation frame index to #$0D
	BNE +
	TXA
	CLC : ADC #$0D
	TAX
	+
	LDA TongueTileX,X			; store the tongue x offset (based on the animation frame) to scratch ram
	STA $06
	PLX
	
	LDA TongueTileY,X			; store the tongue y offset (based on the animation frame) to scratch ram
	STA $07
	
	JSR TongueGFX


; GRAPHICS END-ROUTINE
.gfxend
	PLX
	LDA #$07					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


TongueTileXSub:
	db $00,$08,$10,$18,$20
TongueTileID:
	db $66,$76,$76,$76,$76

TongueGFX:
	LDX #$04					; load loop counter (5 tongue segments)

.tonguesegmentloop
	INY #4						; increment OAM index

; tongue segment tile x position
	PHY
	LDA $04						; load Yoshi's tongue length
	SEC : SBC TongueTileXSub,X	; subtract a number of pixels based on the segment counter
	BPL +
	LDA #$00
	BRA .tonguetileoffsetloaded
	+
	LDY $02						; invert it if facing left (don't add INC A after EOR #$FF here, or the tongue tile will be wrongly offset by 1 pixel)
	BEQ .tonguetileoffsetloaded
	EOR #$FF
.tonguetileoffsetloaded
	PLY
	CLC : ADC $00				; add the tile base x position
	ADC $06						; add x offset based on animation frame
	STA $0300,Y

; tongue segment tile y position
	LDA $01						; tile y position
	CLC : ADC $07				; add y offset based on animation frame
	STA $0301,Y

; tongue segment tile id
	LDA TongueTileID,X			; load tile id based on the segment counter
	STA $0302,Y

; tongue segment tile properties
	PHY							; tile properties (x-flip based on face direction)
	LDY $02
	LDA TileProp,Y
	PLY
	ORA $64
	STA $0303,Y

; tongue segment tile size
	PHY							; set the tile size to 8x8 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$00
	STA $0460,Y
	PLY
	
	DEX							; decrement the loop counter and loop to draw another tongue segment if the loop counter is still positive
	BPL .tonguesegmentloop
	RTS


HandleSpriteInteraction:
	LDA $163E,X					; return if sprite contact is disabled
	BNE .return
	
	LDY #$0B					; load highest sprite slot for loop
.loopstart
	STY $1695					; store the sprite slot
;	TYA							; if the sprite is on Yoshi's tongue, skip (unnecessary since $15D0,Y is already checked for?)
;	CMP $160E,X
;	BEQ .loopcontinue
	CPY $15E9					; if the sprite is Yoshi himself, skip
	BEQ .loopcontinue
	LDA $14C8,Y					; if the sprite is not in an alive status, skip
	CMP #$08
	BCC .loopcontinue
	LDA $14C8,Y					; if the sprite is in carryable status, skip
	CMP #$09
	BEQ .loopcontinue
	LDA $154C,Y					; if the sprite is set to temporarily not interact with Mario, skip
	BNE .loopcontinue
	LDA $167A,Y					; if the sprite is invincible to star/cape/fire/bouncing blocks...
	AND #%00000010
	ORA $15D0,Y					; or the sprite is on Yoshi's tongue
	ORA $1632,Y					; or the sprite is 'behind the scenery' (e.g. net koopas), skip
	BNE .loopcontinue
	
	JSR CheckSpriteContact

.loopcontinue
	LDY $1695					; decrement the sprite slot and restart the loop
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

	INC $61

;	LDA $9E,Y					; if the sprite is 9D (bubble), return
;	CMP #$9D
;	BEQ .return
;	
;	CMP #$15					; if the sprite is 15 or 16 (fish), handle interaction with it separate
;	BEQ YoshiFishCheck
;	CMP #$16
;	BEQ YoshiFishCheck
;	
;	CMP #$04					; else, if the sprite is a naked blue koopa...
;	BCS NotKickableCheck
;	CMP #$02
;	BEQ NotKickableCheck
;	
;	LDA $163E,Y					; and it's stunned (after being stomped out of a shell), kick-kill it; else, handle the sprite as non-kickable
;	BPL NotKickableCheck
;	JSR KickKillSprite

.return
	RTS


KickedSpriteXSpeed:
	db $F0,$10

KickKillSprite:
	PHY
	PHX
	TYX
;	LDA #$10					; show kicking pose (for Mario) for 16 frames
;	STA $149A
	LDA #$03					; play kick sfx
	STA $1DF9
	%SubHorzPos()				; give sprite x speed (direction based on horizontal direction towards Mario)
	LDA KickedSpriteXSpeed,Y
	STA $B6,X
	LDA #$E0					; give sprite y speed
	STA $AA,X
	LDA #$02					; kill the sprite
	STA $14C8,X
;	STY $76						; make Mario face the sprite
	PLX
	PLY
	RTS


YoshiFishCheck:
	LDA $164A,Y					; if the fish is not in water, kick-kill it; else, treat it as a non-kickable sprite
	BEQ KickKillSprite
NotKickableCheck:
	LDA $9E,Y					; if the sprite is BF (mega mole)...
	CMP #$BF
	BNE +
	LDA $96						; and it's too far to the right, return (to account for its 32x32 size)
	SEC : SBC $D8,Y
	CMP #$E8
	BMI .return
	+
	
	LDA $9E,Y					; if the sprite is 4D or 4E (monty moles)...
	CMP #$4E
	BEQ +
	CMP #$4D
	BNE .notmontymole
	+
	LDA $C2,Y					; and it's still in the ground, return
	CMP #$02
	BCC .return

.notmontymole
	LDA #$0D					; load #$0D for the lower body offset
	STA $00
	
	LDA $9E,Y					; if the sprite is custom...
	CMP #$36
	BNE +
	LDA $1570,Y					; if it's the bounce lotus (which has this flag set specifically for this purpose)...
	BEQ +
	LDA #$16					; load #$16 for the lower body offset
	STA $00
	+
	
	LDA $05						; if the sprite is below Yoshi's 'lower body', return (to reduce the risk of taking damage when jumping on/over a sprite)
	CLC : ADC $00
	CMP $01
	BMI .return
	
	LDA $14C8,Y					; if the sprite is in kicked status...
	CMP #$0A
	BNE +
	PHX
	TYX
	%SubHorzPos()				; and it's moving away from Yoshi, return (to prevent shells from hurting Yoshi immediately when spat out)
	STY $00
	LDA $B6,X
	PLX
	ASL
	ROL
	AND #$01
	CMP $00
	BNE .return
	+
	
	LDA $1490					; if Mario has star power, return
	BNE .return
	
	JSR DamageYoshi

.return
	RTS


YoshiDamageSpeed:
	db $E8,$18

DamageYoshi:
	STZ $187A					; set Mario off Yoshi
	
	LDA #$02					; put Yoshi in running state
	STA $C2,X
	
	LDA #$18					; disable contact with other sprites for 24 frames (vanilla = 16 frames)
	STA $163E,X
	
	LDA #$30					; make Mario invulnerable for 48 frames
	STA $1497
	
	LDA #$13					; Yoshi damage sfx
	STA $1DFC
	
	LDA #$C0					; set Mario's y speed
	STA $7D
	STZ $7B						; set Mario's x speed to 0
	
	LDA $157C,X					; set Yoshi's x speed based on his face direction (in vanilla SMW, this is based on Yoshi's horizontal direction to Mario)
	EOR #$01
	TAY
	LDA YoshiDamageSpeed,Y
	STA $B6,X
	
	STZ $1594,X					; set Yoshi's mouth phase to 0
	STZ $151C,X					; set Yoshi's tongue length to 0
	STZ $1626,X					; set Yoshi's tongue extension timer to 0
	
	JSR PutMarioAboveYoshi
	RTS


DismountXSpeed:
	db $10,$F0

DismountYoshi:
	LDA $7B						; give Yoshi Mario's x speed
	STA $B6,X
	
	LDY $72						; if Yoshi is on the ground...
	BNE +
	%SubHorzPos()				; give Mario x speed (based on Mario's x position compared to Yoshi's)
	LDA DismountXSpeed,Y
	STA $7B
	
	LDA #$C0					; give Mario y speed
	BRA .storedismountyspeed
	+
	
	LDA !AllowDropDismount				; (custom) else, if drop-dismounts are allowed...
	BEQ +
	LDA $15								; and holding down...
	AND #%00000100
	BEQ +
	LDA #$10							; set the mount cooldown
	STA $154C,X
	LDA !DropDismountMarioYSpeed		; give Mario y speed
	BRA .storedismountyspeed
	+
	
	LDA #$A0					; else, give Mario y speed

.storedismountyspeed
	STA $7D						; store Mario's y speed
	
	STZ $C2,X					; set Yoshi's state to normal
	STZ $187A					; set the 'riding Yoshi' flag to 0
	
	LDA $154C,X					; (custom) if the mount cooldown is not set, set Yoshi's y speed to 0
	BNE +
	STZ $AA,X
	BRA PutMarioAboveYoshi
	+

; drop-dismount
	LDA !DropDismountYoshiYSpeed		; otherwise, boost Yoshi upward
	STA $AA,X
	
	LDA $D8,X							; temporarily lower Yoshi's position 16 pixels to have the contact star display at the right position
	STA $00
	CLC : ADC #$10
	STA $D8,X
	JSL $01AB6F							; display contact star
	LDA $00
	STA $D8,X
	
	LDA #$02							; play hit sfx
	STA $1DF9

PutMarioAboveYoshi:
	LDA $14D4,X					; set Mario's y 4 pixels above Yoshi's y (so it actually makes him dismount slightly from below Yoshi's saddle)
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0004
	
	LDY $154C,X					; (custom) if the mount cooldown is set (drop-dismount), raise Mario another 4 pixels
	BEQ +
	SEC : SBC #$0004
	+
	
	STA $96
	STA $D3
	SEP #$20
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	LDA $7D						; return if Mario is not moving down
	BMI .return
	
	LDA $72						; return if Mario is not airborne...
	BEQ .return
	
	LDA $1470					; return if Mario is carrying something...
	ORA $187A					; or if already on a Yoshi...
	ORA $154C,X					; or if the mount cooldown is set (custom)
	ORA $15D0,X					; or if the Yoshi is being tongued
	BNE .return
	
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	JSR MountYoshi

.return
	RTS


MountYoshi:
	LDA #$1F					; play 'Yoshi mount' sfx
	STA $1DFC
	
;	LDA #$20					; disable contact with other sprites for 32 frames
;	STA $163E,X
	
	LDA #$0C					; set Yoshi's squatting timer to 12 frames
	STA $1534,X
	
	LDA $14D4,X					; set Mario's y 16 pixels above Yoshi's y
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0010
	STA $96
	STA $D3
	SEP #$20
	
;	STZ $7B						; set Mario's x speed to 0
	STZ $7D						; set Mario's y speed to 0
	
	LDA #$01					; set Yoshi's state to being ridden
	STA $C2,X
	RTS


YoshiPositionX:
	dw $0002,$FFFE
MarioOffsetY:
	db $06,$05,$05,$05,$0A,$05,$05,$0A,$0A,$0B

OffsetMarioYoshi:
	LDA $157C,X					; set Yoshi's x based on the face direction
	ASL
	TAY
	REP #$20
	LDA $D1
	CLC : ADC YoshiPositionX,Y
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	REP #$20					; set Yoshi's y 16 pixels below Mario's y
	LDA $D3
	CLC : ADC #$0010
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDY $1602,X					; shift Mario's image vertically based on Yoshi's animation frame
	LDA MarioOffsetY,Y
	STA $188B
	RTS


HandleMouth:
	LDA $14A3					; if the Yoshi punch timer is at #$0E (vanilla SMW = at #$10, but this has the same effect here)...
	CMP #$0E
	BNE +
	CPX $1879					; and the currently processed Yoshi is the one stored in $1879 (sprite slot set when Mario punches that Yoshi)
	BNE +
	LDA $1626,X					; and the tongue extension timer is 0...
	BNE +
	LDA #$06					; set the tongue extension timer to 6
	STA $1626,X
	+
	
	LDA $1594,X					; point to different routines based on the mouth phase
	JSL $0086DF
		dw NeutralMouth
		dw ExtendingTongue
		dw RetractingTongue
		dw Spitting


; MOUTH PHASE 0 - NEUTRAL MOUTH
NeutralMouth:
	LDA $187B,X					; if Yoshi does not have a sprite in his mouth, skip handling it
	BEQ .handleextendtongue
	
	LDY $160E,X					; else, load the sprite slot of the sprite in Yoshi's mouth
	
;	LDA $14						; only handle the swallow delay timer 1 out of every 4 frames
;	AND #$03
;	BNE .handleextendtongue
;	DEC $187B,X					; decrease the swallow delay timer
;	LDA $187B,X					; if it's at 0 now...
;	BNE .handleextendtongue
;	LDY $160E,X					; erase the sprite in Yoshi's mouth
;	LDA #$00
;	STA $14C8,Y
;	LDA #$FF					; set the sprite slot in Yoshi's mouth back to FF (no sprite)
;	STA $160E,X
;	LDA #$1B					; set the swallow animation timer
;	STA $1564,X
;	JMP SwallowSprite

.handleextendtongue
	LDA $1626,X					; if the tongue extension timer is 0, check for sticking out the tongue
	BEQ CheckExtendTongue
	DEC $1626,X					; else, decrement the tongue extension timer
	BNE +						; if 0 (first frame)...
	INC $1594,X					; set Yoshi's mouth phase to 1 (extending tongue)
	STZ $151C,X					; set Yoshi's tongue length to 0
	LDA #$FF					; set the sprite slot on Yoshi's mouth to FF (= no sprite)
	STA $160E,X
	STZ $1564,X					; set the swallow animation timer to 0
	+
	RTS


SwallowSprite:
	LDA #$06					; play swallow sfx
	STA $1DF9
	JSL $05B34A					; give a coin
	RTS


CheckExtendTongue:
	LDA $C2,X					; if Yoshi is ridden...
	CMP #$01
	BNE .return
	LDA $16						; and X or Y is pressed...
	AND #%01000000
	BEQ .return
	
	LDA $187B,X					; if Yoshi has a sprite in his mouth, spit it out
	BNE SpitSprite
	
	JMP InitExtendTongue		; else, extend the tongue
.return
	RTS


InitExtendTongue:
	LDA #$11					; set the Yoshi punch timer to 17 frames (vanilla = #$12, but it is decremented automatically on the same frame, so this has the same effect)
	STA $14A3
	STX $1879					; store the current sprite slot
	LDA #$21					; play tongue sfx
	STA $1DFC
	RTS


SpitSpriteXOffset:
	dw $0010,$FFF0
SpitSpriteYOffset:
	dw $0000,$0004

SpitSpriteXSpeedNormal:			; vanilla forward-spit base speeds are [$30,$D0], vanilla item forward-throw base speeds (without Yoshi) are [$2E,$D2]
	db $2E,$D2
SpitSpriteXSpeedDown:			; vanilla down-spit speeds are [$04,$FC], vanilla item drop speeds (without Yoshi) are [$10,$F0]
	db $10,$F0

SpriteToSpawn:
	db $00,$01,$02,$03,$04,$05,$06,$07		; all unused
	db $04,$04,$05,$05,$07,$00,$00,$0F		; 08, 09, 0A, 0B, 0C, unused, unused, unused
	db $0F,$0F,$0D							; 10, 3F, 40

SpitSprite:
	STZ $187B,X							; set Yoshi's mouth as empty
	LDY $160E,X							; load the spit sprite's sprite slot into Y
	
	PHY									; set spit sprite's x position based on Yoshi's face direction
	LDY $157C,X
	BEQ +
	INY
	+
	LDA $14E0,X
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC SpitSpriteXOffset,Y
	SEP #$20
	PLY
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $9E,Y							; store the spit sprite's sprite id to scratch ram
	STA $00
	
	PHY									; set spit sprite's y position based on the ducking flag (in vanilla SMW, it's always the same y)
	LDY $18DC
	BEQ +
	INY
	+
	LDA $14D4,X
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC SpitSpriteYOffset,Y
	
	LDY $00								; if the spit sprite is another (custom) Yoshi, position him 16 pixels higher
	CPY #$69
	BNE +
	SEC : SBC #$0010
	+
	
	SEP #$20
	PLY
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA #$00							; clear the 'sprite is on Yoshi's tongue' flag for the spit sprite
	STA $15D0,Y
	
	LDA $15								; load 'holding down' status into scratch ram
	AND #%00000100
	STA $03
	
	LDA $9E,Y							; if the spit sprite is another (custom) Yoshi, give it normal status
	CMP #$69
	BNE +
	LDA #$08
	BRA .spritestatusloaded
	+
	
	CMP #$36							; else, if the spit sprite is custom...
	BNE +
	LDA $1570,Y							; and it's the bounce lotus, give it normal status
	BEQ +
	LDA #$08
	BRA .spritestatusloaded
	+
	
	LDA !AllowMidairDownSpit			; else, if mid-air down-spits are not allowed, set the scratch ram value to 0 if airborne
	BNE +
	LDA $72
	BEQ +
	STZ $03
	+
	
	LDA $03								; if holding down, give the spit sprite carryable status, else give it kicked status
	BEQ +
	LDA #$09
	BRA .spritestatusloaded
	+
	
	LDA #$0A
.spritestatusloaded
	STA $14C8,Y
	
	LDA $157C,X							; give the spit sprite the same face direction as Yoshi
	STA $157C,Y
	
	PHX									; use the face direction as an index
	TAX
	
	LDA $03								; if holding down, give the spit sprite x speed based on Yoshi's face direction
	BEQ +
	LDA $7B
	CLC : ADC SpitSpriteXSpeedDown,X
	STA $B6,Y
	BRA .spritexspeedstored
	+
	
	LDA SpitSpriteXSpeedNormal,X		; else, give the spit sprite x speed based on Yoshi's face direction
	STA $B6,Y
	EOR $7B								; if the spit sprite is now moving in the same direction as Mario, add half of Mario's x speed
	BMI .spritexspeedstored
	LDA $7B
	STA $01
	ASL $01
	ROR
	CLC : ADC SpitSpriteXSpeedNormal,X
	STA $B6,Y

.spritexspeedstored
	PLX
	LDA #$00							; give the spit sprite 0 y speed
	STA $AA,Y
	LDA #$10							; (custom) disable contact with Mario and the custom Yoshi for 16 frames
	STA $154C,Y
	LDA !CooldownAfterSpit				; set timer to prevent Yoshi from sticking out his tongue
	STA $1558,X
	LDA #$03							; set Yoshi's mouth phase to 3 (spitting)
	STA $1594,X
	LDA #$FF							; set the sprite slot in Yoshi's mouth to FF (no sprite)
	STA $160E,X
	LDA #$20							; play spit sfx
	STA $1DF9
	RTS


; MOUTH PHASE 1 - EXTENDING TONGUE
ExtendingTongue:
	LDA $151C,X					; increase Yoshi's tongue length
	CLC : ADC #$03
	STA $151C,X
	CMP #$20					; if the tongue length has reached the maximum...
	BCC HandleTongue
	LDA #$08					; set the tongue delay timer (8 frames before actually retracting tongue)
	STA $1558,X
	INC $1594,X					; set Yoshi's mouth phase to 2 (retracting tongue)

HandleTongue:
	JSR TongueInteraction
	RTS


; MOUTH PHASE 2 - RETRACTING TONGUE
RetractingTongue:
	LDA $1558,X					; if the tongue delay timer is still set, don't retract the tongue yet and skip to handling the tongue
	BNE HandleTongue
	LDA $151C,X					; else, decrease Yoshi's tongue length
	SEC : SBC #$04
	BMI +						; if the tongue has not been fully retracted yet, handle the tongue
	STA $151C,X
	BRA HandleTongue
	+

; tongue fully retracted
	STZ $151C,X					; else, set the tongue length to 0
	STZ $1594,X					; and set Yoshi's mouth phase back to 0 (neutral mouth)
	
	LDY $160E,X					; if there is no sprite on Yoshi's tongue, don't handle it
	BMI .nomouthsprite
	
	LDA $1686,Y					; else, if the 'stay in Yoshi's mouth' flag is not set, eat the sprite
	AND #%00000010
	BEQ EatSprite
	
	LDA #$07					; else, change the sprite status to 'in Yoshi's mouth'
	STA $14C8,Y
	
	LDA #$FF					; set Yoshi's swallow timer
	STA $187B,X
	
	LDA $9E,Y					; if the sprite is a koopa, turn it into a shell
	CMP #$0D
	BCS .nomouthsprite
	PHX
	TAX
	LDA SpriteToSpawn,X
	STA $9E,Y
	PLX
.nomouthsprite
;	JMP HandleTongue			; handle the tongue (even though it has been fully retracted; vanilla SMW does this for some reason)
	RTS


EatSprite:
	LDA #$00					; erase the sprite
	STA $14C8,Y
	LDA #$1B					; set Yoshi's swallow animation timer to 30 frames
	STA $1564,X
	LDA #$FF					; clear the sprite slot on Yoshi's tongue
	STA $160E,X
	
;	LDA $9E,Y					; if the sprite is a bubble...
;	CMP #$9D
;	BNE +
;	LDA $C2,Y					; and it has a mushroom inside...
;	CMP #$03
;	BNE +
;	LDA #$74					; change the sprite ID to a mushroom
;	STA $9E,Y
;	LDA $167A,Y					; set the sprite to give a power-up when eaten
;	ORA #%01000000
;	STA $167A,Y
;	+
	
	LDA $167A,Y					; if the sprite is set to give a power-up when eaten...
	AND #%01000000
	BEQ +
	PHX							; handle tonguing the power-up (mushroom, flower, star, feather, 1-up)
	TYX
	JSR TonguePowerup
	PLX
;	JMP HandleTongue			; handle the tongue (even though it has been fully retracted; vanilla SMW does this for some reason)
	BRA .return
	+
	
	JSR SwallowSprite			; else, handle swallowing the sprite
;	JMP HandleTongue			; handle the tongue (even though it has been fully retracted; vanilla SMW does this for some reason)

.return
	RTS


TongueInteraction:
	LDY $1602,X					; load the animation frame as an index
	
	LDA TongueTileY,Y			; store the tongue tip tile y to scratch ram
	STA $0E
	
	LDA $157C,X					; if Yoshi's face direction is right, add #$0D to the index
	BNE +
	TYA
	CLC : ADC #$0D
	TAY
	+
	LDA TongueTileX,Y			; store the tongue tip tile x to scratch ram
	STA $0D

; store Yoshi's position into scratch ram
	LDA $E4,X					; store Yoshi's x position into scratch ram
	STA $04
	LDA $14E0,X
	STA $05
	
	LDA $D8,X					; store Yoshi's y position into scratch ram
	STA $06
	LDA $14D4,X
	STA $07

; load tongue interaction point x
	LDA $0D						; load the tongue tip tile x
	BMI +						; if positive (tonguing to the right)...
	CLC : ADC $151C,X			; add the tongue length
	BRA ++
	+
	LDA $151C,X					; else (tonguing to the left), load the tongue tip tile x minus the tongue length
	EOR #$FF
	INC A
	CLC : ADC $0D
	++
	BPL +
	XBA
	LDA #$FF
	BRA ++
	+
	XBA
	LDA #$00
	++
	XBA
	
	LDY $160E,X					; if there is no sprite on Yoshi's tongue, check for one
	BMI CheckTongueSprite

; set the sprite onto Yoshi's tongue horizontally
	REP #$20
	CLC : ADC $04				; add Yoshi's x position
	SEC : SBC #$0004			; subtract 4 pixels
	
	PHY
	LDY $157C,X					; if facing left, subtract another 2 pixels (non-vanilla tweak)
	BEQ +
	SEC : SBC #$0002
	+
	PLY
	
	SEP #$20
	
	STA $E4,Y					; change the sprite's x into the loaded value
	XBA
	STA $14E0,Y

; set the sprite onto Yoshi's tongue vertically
	LDA #$FC					; load #$FC into scratch ram
	STA $00
	
	LDA $1662,Y					; if the 'use shell as death frame' flag is set...
	AND #%01000000
	BNE +
	LDA $190F,Y					; and the 'death frame 2 tiles high' flag is not set...
	AND #$20
	BEQ +
	LDA #$F8					; load #$F8 into scratch ram
	STA $00
	+
	
	LDA #$00
	XBA
	LDA $00						; load the tongue tip tile y minus 4 or 8 pixels (specified above)
	CLC : ADC $0E
	REP #$20
	CLC : ADC $06				; add Yoshi's y position
	
	PHX							; if the tongued sprite is another Yoshi, set it 16 pixels higher
	LDX $9E,Y
	CPX #$69
	BNE +
	SEC : SBC #$0010
	+
	PLX
	
	SEP #$20
	
	STA $D8,Y					; change the sprite's y into the loaded value
	XBA
	STA $14D4,Y
	
	LDA #$00
	STA $AA,Y					; set the sprite's y speed to 0
	STA $B6,Y					; set the sprite's x speed to 0
	
	LDA $9E,Y					; if the sprite is another Yoshi, make it face the same direction as the tonguing Yoshi
	CMP #$69
	BNE +
	LDA $157C,X
	STA $157C,Y
	+
	
	INC A						; mark the sprite as being on Yoshi's tongue (to disable other interaction)
	STA $15D0,Y
	
	RTS


CheckTongueSprite:
; store tongue interaction x position
	REP #$20
	CLC : ADC $04				; add Yoshi's x position
	SEP #$20
	STA $00						; store the tongue interaction x position to scratch ram
	XBA
	STA $08

; set tongue interaction y position
	LDA #$00
	XBA
	LDA $0E						; load the tongue tip tile y
	REP #$20
	CLC : ADC #$0002			; add 2 pixels
	ADC $06						; add Yoshi's y position
	SEP #$20
	STA $01						; store the tongue interaction y position to scratch ram
	XBA
	STA $09

; set tongue interaction width
	LDA #$08
	STA $02

; set tongue interaction height
	LDA #$04
	STA $03

; check for a sprite on Yoshi's tongue
	LDY #$0B					; load highest sprite slot for loop
.loopstart
	CPY $15E9					; if the sprite is Yoshi himself, skip
	BEQ .loopcontinue
	LDA $160E,X					; if the sprite is already on Yoshi's tongue, skip
	BPL .loopcontinue
	LDA $14C8,Y					; if the sprite is not in an alive status, skip
	CMP #$08
	BCC .loopcontinue
	LDA $1632,Y					; if the sprite is 'behind the scenery' (e.g. net koopas), skip
	BNE .loopcontinue
	PHY
	JSR TryEatSprite
	PLY
.loopcontinue
	DEY
	BPL .loopstart
	RTS


TryEatSprite:
	PHX
	TYX
	JSL $03B69F					; get the sprite's clipping values
	PLX
	JSL $03B72B					; if the sprite is not in contact with Yoshi's tongue, return
	BCC .return
	LDA $1686,Y					; if the sprite is not tongueable, play the hit sfx and return
	LSR
	BCS .nottongueable
	TYA							; else, store the sprite slot of the tongued sprite
	STA $160E,X
	LDA #$02					; change the mouth phase to 2 (retracting tongue)
	STA $1594,X
	LDA #$0A					; disable tonguing something for 10 frames
	STA $1558,X
	BRA .return
.nottongueable
	LDA #$01					; play hit sfx
	STA $1DF9
.return
	RTS


; MOUTH PHASE 3 - SPITTING
Spitting:
	LDA $1558,X					; if the tongue delay timer has been fully decremented, return to mouth phase 0 (neutral)
	BNE .return
	STZ $1594,X

.return
	RTS


OnYoshiAnimations:
	db $20,$21,$27,$28			; normal, turning, punch (hand up), punch (hit Yoshi)

ChangeMarioPose:
	LDY $187A					; if not riding Yoshi, don't change Mario's animation frame (it is set elsewhere)
	BEQ .return
	LDA $9D						; if the animation lock flag is set, don't change Mario's animation frame
	BNE .return
	
	LDA $14A3					; if the Yoshi punch timer is set (starts at #$12 in vanilla SMW)...
	BEQ +
	LDY #$03					; load Mario's animation frame index 3
	CMP #$0C					; if the Yoshi punch timer is below #$0C
	BCS +
	LDY #$04					; load Mario's animation frame index 4
	+
	
	LDA OnYoshiAnimations-1,Y	; load Mario's animation frame based on the index minus 1 (the value in $187A or the punch values set before)
	
	DEY							; if the animation frame is #$20 (normal, not turning or punching)...
	BNE +
	LDY $73
	BEQ +						; ...and ducking, load #$1D as Mario's animation frame
	LDA #$1D
	+
	
	STA $13E0					; store Mario's animation frame

.return
	RTS


TonguePowerup:
	STZ $14C8,X					; erase the power-up sprite
	
	LDA $9E,X					; run different routines based on the power-up
	SEC : SBC #$74
	
	JSL $0086DF
		dw GiveMushroom
		dw GiveFlower
		dw GiveStar
		dw GiveCape
		dw Give1Up
	
	RTS

GiveMushroom:
	LDA #$02					; put Mario in the 'get mushroom' animation state
	STA $71
	LDA #$2F					; set power-up animation timer
	STA $1496
	INC $9D						; set 'lock animations' flag
	LDA #$0A					; play power-up sfx
	STA $1DF9
	RTS

GiveFlower:
	LDA #$04					; put Mario in the 'get flower' animation state
	STA $71
	LDA #$20					; set 'get flower' animation timer
	STA $149B
	INC $9D						; set 'lock animations' flag
	LDA #$03					; set the power-up status to flower
	STA $19
	LDA #$0A					; play power-up sfx
	STA $1DF9
	RTS

GiveStar:
	LDA #$FF					; set star power timer
	STA $1490
	LDA #$0A					; play power-up sfx
	STA $1DF9
	RTS

GiveCape:
	INC $9D						; set 'lock animations' flag
	LDA #$02					; set the power-up status to cape
	STA $19
	LDA #$0D					; play feather power-up sfx
	STA $1DF9
	JSL $01C5AE					; display smoke at Mario's position
	RTS

Give1Up:
	LDA #$08					; give Mario a 1up
	JSL $02ACE5
	RTS