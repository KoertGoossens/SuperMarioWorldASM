; custom adult Yoshi sprite
; this requires an edit at $0180C3 to work (preventing $187A from being set to 0 when no vanilla Yoshis are present)
; the extension byte determines whether the Yoshi is vanilla-style (0) or has more custom features (1 or 2); a value of 2 automatically mounts Mario on top of Yoshi

; properties of custom Yoshi compared to vanilla Yoshi:
;	- can be drop-dismounted while airborne by pressing A while holding down
;	- runs away on surfaces when dismounted
;	- Mario dies when taking damage on Yoshi, instead of Yoshi running away
;	- interacts with other sprites when off Mario (can bounce off sprites, or get killed)
;	- tongue can be controlled remotely with R, and Y/X is disabled for it
;	- tongues most sprites, but never swallows any
;	- custom behavior given to sprites after spitting them

; significant changes to both Yoshi types:
;	- don't change unmounted Yoshi's face direction based on his x speed
;	- faster turn-around
;	- lower tongue cooldown after spitting
;	- never swallows sprites after waiting
;	- don't set Mario's x speed to 0 when mounting Yoshi
;	- don't disable contact with other sprites when mounting Yoshi
;	- don't do small hops when not ridden

; sprite-indexed addresses specific to Yoshi:
;	$C2,X		=	state (0 = normal, 1 = ridden by Mario, 2 = running after damage)
;	$1504,X		=	stored animation frame (set equal to $1602,X prior to updating $1602,X - the Yoshi gfx routine then uses the old animation frame $1504,X while Mario uses the updated $1602,X since Mario's gfx lags behind a frame)
;	$151C,X		=	Yoshi's tongue length
;	$1528,X		=	animation frame counter (replaces $18AD to make it sprite-indexed)
;	$1534,X		=	squatting timer (replaces $18AF to make it sprite-indexed)
;	$1540,X		=	transform cooldown timer
;	$154C,X		=	mount cooldown timer (for custom drop-dismounts)
;	$1558,X		=	tongue delay timer (time to wait before retracting tongue when it's at max length, and time to wait before sticking tongue out after spitting something)
;	$1564,X		=	swallow animation timer
;	$1570,X		=	animation frame timer
;	$157C,X		=	face direction (0 = right, 1 = left)
;	$1594,X		=	mouth phase (0 = neutral, 1 = extending tongue, 2 = retracting tongue, 3 = spitting)
;	$15AC,X		=	timer for turning around (set to #$10 at the start of a turn)
;	$1602,X		=	animation frame (	0/1/2 = walking, 2 = falling, 3 = turning, 4 = crouching, 5 = jumping, 6 = tongue out (high)
;										7 = tongue out (low), 8/9 = entering horizontal pipe, A/B/C = growing)
;	$160E,X		=	sprite slot of sprite on Yoshi's tongue or in his mouth (#$FF = no sprite)
;	$1626,X		=	tongue extension timer (replaces $18AE to make it sprite-indexed)
;	$163E,X		=	timer to disable contact with other sprites
;	$187B,X		=	swallow delay timer (replaces $18AC to make it sprite-indexed), also used to check whether Yoshi has a sprite in his mouth

; other Yoshi-related addresses:
;	$14A3		=	Yoshi's punch animation timer
;	$1879		=	(freeram address) sprite slot of the Yoshi that's about to stick out its tongue (set when Mario punches him)
;	$187A		=	'on Yoshi' flag (0 = not on Yoshi, 1 = on Yoshi, 2 = on Yoshi and turning around)
;	$18DA		=	sprite slot of a ridden Yoshi
;	$18DC		=	'ducking with Yoshi' flag


!AllowDropDismount				=	#$00		; set to 1 to allow drop-dismounts
!DropDismountYoshiYSpeed		=	#$C0		; y speed to give Yoshi after drop-dismounting
!DropDismountMarioYSpeed		=	#$10		; y speed to give Mario after drop-dismounting
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
	
	LDA #$05 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites (when loose)
	LDA #$0B : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites (when loose)
	LDA #$05 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites (when loose)
	LDA #$14 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites (when loose)
	
	DEC $160E,X					; initialize the sprite slot in Yoshi's mouth to null (#$FF)
	
	LDA $7FAB40,X				; if Yoshi is set to be mounted upon spawn, do so
	CMP #$02
	BNE +
	JSR SetMountYoshi_NoResetY
	+
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


GroundXSpeedLoose:
	db $24,$DC

SpriteCode:
	LDA $9D						; if the game is frozen, only draw the graphics
	BNE .dographics
	LDA $14C8,X					; if the sprite is dead, only draw the graphics
	CMP #$08
	BNE .dographics
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $C2,X					; if the Yoshi is being ridden, handle that
	CMP #$01
	BEQ +
	JSR HandleRidingYoshi
	BRA .dographics
	+

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
	JSR HandleShrink
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


HandleGravity:		%ApplyGravity() : RTS


HandleShrink:
	LDA $7FAB40,X				; if Yoshi is set to shrink when pressing L...
	BEQ .return
	
	LDA $18						; and L is pressed...
	AND #%00100000
	BEQ .return
	
	LDA $1540,X					; and the transform cooldown timer is not set...
	BNE .return
	
	STZ $01						; spawn smoke 1 tile below the Yoshi
	LDA #$10
	STA $02
	%SpawnSpriteSmoke()
	
	LDA #$25					; baby Yoshi (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA $E4,X					; set the baby Yoshi's x equal to the adult Yoshi's x
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	
	LDA $14D4,X					; set the baby Yoshi's y 16 pixels below the adult Yoshi's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0010
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA #$04					; set the baby Yoshi's transform cooldown timer to 4 frames
	STA $1540,Y
	
	LDA $C2,X					; if the adult Yoshi is being ridden...
	CMP #$01
	BNE +
	LDA $15						; and Y/X is held...
	AND #%01000000
	BEQ +
	LDA #$0B					; set the baby Yoshi's sprite status to 'carried'
	STA $14C8,Y
	+
	
	LDA #$02					; set the baby Yoshi's type to 2 (swap with L/R)
	PHX
	TYX
	STA $7FAB40,X
	PLX
	
	STZ $187A					; set the 'riding Yoshi' flag to 0
	STZ $14C8,X					; erase the adult Yoshi
	STZ $188B					; set Mario's image offset to 0
	
	LDA $151C,X					; if the adult Yoshi had his tongue out...
	BEQ .return
	LDA $160E,X					; and he had a sprite on his tongue...
	BMI .return
	
	PHX
	TAX
	STZ $01						; spawn smoke at the same x/y as the tongued sprite
	STZ $02
	%SpawnSpriteSmoke()
	
	STZ $14C8,X					; erase the tongued sprite
	PLX

.return
	RTS


HandleRidingYoshi:
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	
	LDA $1588,X					; if touching a solid tile on the side...
	AND #%00000011
	BEQ +
	JSR BonkYoshiWall
	+
	
	%HandleFloor()
	
	LDA $1588,X					; (custom) if Yoshi is touching the ceiling...
	AND #%00001000
	BEQ +
	LDA #$10					; give it some downward speed (#$10 = downward speed carryable items get from hitting the ceiling after an uptoss)
	STA $AA,X
	+
	
	JSR HandleSpriteInteraction
	
	LDA $1588,X					; if Yoshi is on the ground (incl. solid sprites)...
	AND #%00000100
	BEQ +
	LDA $C2,X					; and Yoshi is not damage-running...
	CMP #$02
	BCS +
	
	LDA $7FAB40,X				; if the Yoshi is vanilla-style...
	BNE ++
	STZ $B6,X					; set his x speed to 0
	BRA +
	++
	
	LDA $B6,X					; else (custom Yoshi), if his x speed is not 0...
	BEQ +
	LDA $157C,X					; set the x speed based on the face direction
	TAY
	LDA GroundXSpeedLoose,Y
	STA $B6,X
	+
	
	JSR HandleMarioContact
	RTS


StoreAnimationFrame:
	LDA $1602,X					; store the current animation frame
	STA $1504,X
	
	LDY #$00					; load default animation frame (= 0)

; check killed
	LDA $14C8,X					; if Yoshi was killed...
	CMP #$02
	BNE +
	LDA #$30					; load p-speed for the walking animation
	BRA .walkingspeedloaded
	+

; check loose Yoshi
	LDA $C2,X					; if Yoshi is loose...
	BNE +
	
	LDA $151C,X					; if Yoshi's tongue is out...
	BEQ +
	LDA $1588,X					; and he is on the ground...
	AND #%00000100
	BEQ +
	LDA #$07					; load animation frame 7
	STA $1602,X
	RTS
	+
	
	LDA $B6,X					; else (Yoshi is not loose), if his x speed is not 0 (custom Yoshi only)...
	BEQ +
	LDA $1588,X					; and he is on the ground...
	AND #%00000100
	BEQ +
	
	LDA $B6,X					; load Yoshi's x speed
	BPL ++						; if negative, make the value positive
	EOR #$FF
	INC A
	++
	LSR #4						; handle the running animation based on the speed value
	TAY
	JSR HandleWalkAnimation
	TYA							; store animation frame
	STA $1602,X
	RTS
	+

; check damage-running
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
	
	LDA $14C8,X					; if Yoshi was killed...
	ORA $C2,X					; or Yoshi is damage-running, skip checking for other animation frames
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
	db %01101011,%00101011,%01101111,%00101111,%01101111,%00101111

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
	LDA $14C8,X					; store Yoshi's sprite status to scratch ram
	STA $09
	LDA $B6,X					; store Yoshi's x speed to scratch ram
	STA $0A
	
	LDA $7FAB40,X				; load Yoshi's type
	ASL
	CLC : ADC $02				; add Yoshi's face direction
	STA $0B						; store it to scratch ram
	
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
	LDA $09						; if Yoshi was killed...
	CMP #$02
	BNE +
	LDA $04						; and he does not have his tongue out...
	BNE +
	LDA #$0C					; load the 'damage' head tile
	BRA .headtileloaded
	+
	
	LDA $03						; if Yoshi is in normal state...
	ORA $08						; and doesn't have a sprite in his mouth...
	ORA $0A						; and his x speed is 0...
	BNE +
	CPX #$06					; and the animation frame is below 6 (e.g. tongue is out)
	BCS +
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
	LDY $0B
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
	LDY $0B
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
	LDY $0B
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
	CPY $15E9					; if the sprite is Yoshi himself, skip
	BEQ .loopcontinue
	LDA $14C8,Y					; if the sprite is not in an alive status, skip
	CMP #$08
	BCC .loopcontinue
	LDA $1564,Y					; if the sprite has the 'disable contact with other sprites' timer set...
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
	%CheckSpriteSpriteContact()			; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContactType:
	db $01,$01,$0A,$00,$02,$02,$00,$00,$01,$0C,$01,$01,$01,$01,$05,$03		; 0 = dino, 1 = mole, 2 = p-switch, 4 = taptap, 5 = flying spiny, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $01,$00,$01,$06,$04,$00,$00,$00,$01,$0C,$02,$01,$00,$01,$00,$00		; 10 = flying dino, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 18 = flying shyguy, 19 = flying floppy fish, 1A = flying taptap, 1B = flying milde, 1D = tallguy
	db $02,$01,$01,$00,$00,$00,$02,$00,$07,$00,$00,$00,$00,$00,$00,$00		; 20 = sparky, 21 = buster beetle, 22 = buzzy beetle, 26 = chuckoomba, 28 = carry block
	db $00,$00,$0B,$02,$01,$02,$00,$02,$00,$02,$00,$00,$01,$02,$00,$00		; 32 = parabeetle, 33 = chomp, 34 = ninji, 35 = spiny, 37 = piranha plant, 39 = bouncing rock, 3C = vine koopa, 3D = fuzzy
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$02,$02,$00,$07,$07,$00,$00,$08,$09,$04,$00,$00,$00,$00,$00		; 51 = thwimp, 52 = golden thwimp, 54 = polarity block, 55 = arrow block, 58 = parachute dino, 59 = parachute spiny, 5A = parachute shell
	db $07,$07,$07,$07,$07,$00,$07,$00,$07,$00,$07,$00,$0A,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = switch block, 66 = used block, 68 = eating block, 6A = walking block, 6C = walking p-switch
	db $07,$07,$07,$00,$00,$00,$00,$00,$07,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 78 = sticky block

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
	
	LDA $7FAB40,X						; if it's a vanilla-style Yoshi...
	BNE +
	LDA $0F								; only handle contact with solid sprites
	CMP #$07
	BEQ SpriteContact_Solid_Direct
	BRA .return
	+
	
	JSR CheckTopContact					; routine to check Yoshi's hitbox y compared to the sprite's hitbox y (run it before the pointer routine, since it uses the same scratch ram addresses)
	STA $0E								; store the result to scratch ram
	
	LDA $0F								; point to different routines based on the contact type
	JSL $0086DF
		dw .return
		dw SpriteContact_KillTop_Direct
		dw SpriteContact_BounceTop_Direct
		dw SpriteContact_Shell_Direct
		dw SpriteContact_FlyingShell_Direct
		dw SpriteContact_Throwblock_Direct
		dw SpriteContact_FlyingThrowblock_Direct
		dw SpriteContact_Solid_Direct
		dw SpriteContact_ParachuteDino_Direct
		dw SpriteContact_ParachuteSpiny_Direct
		dw SpriteContact_PSwitch_Direct
		dw SpriteContact_Parabeetle_Direct
		dw SpriteContact_FloppyFish_Direct

.return
	RTS


SpriteContact_KillTop_Direct:			JSR SpriteContact_KillTop			: RTS
SpriteContact_BounceTop_Direct:			JSR SpriteContact_BounceTop			: RTS
SpriteContact_Shell_Direct:				JSR SpriteContact_Shell				: RTS
SpriteContact_FlyingShell_Direct:		JSR SpriteContact_FlyingShell		: RTS
SpriteContact_Throwblock_Direct:		JSR SpriteContact_Throwblock		: RTS
SpriteContact_FlyingThrowblock_Direct:	JSR SpriteContact_FlyingThrowblock	: RTS
SpriteContact_Solid_Direct:				JSR SpriteContact_Solid				: RTS
SpriteContact_ParachuteDino_Direct:		JSR SpriteContact_ParachuteDino		: RTS
SpriteContact_ParachuteSpiny_Direct:	JSR SpriteContact_ParachuteSpiny	: RTS
SpriteContact_PSwitch_Direct:			JSR SpriteContact_PSwitch			: RTS
SpriteContact_Parabeetle_Direct:		JSR SpriteContact_Parabeetle		: RTS
SpriteContact_FloppyFish_Direct:		JSR SpriteContact_FloppyFish		: RTS


SpriteContact_KillTop:
	LDA $0E								; if Yoshi is not high enough...
	BMI KillYoshi						; kill Yoshi
	
	LDA #$03							; else, play kick sfx
	STA $1DF9
	
	LDA #$02							; set the indexed sprite's status to killed
	STA $14C8,Y
	
	JMP BounceYoshiUp					; bounce Yoshi off the top


SpriteContact_BounceTop:
	LDA $0E								; if Yoshi is not high enough...
	BMI KillYoshi						; kill Yoshi
	
	LDA #$02							; else, play hit sfx
	STA $1DF9
	
	JMP BounceYoshiUp					; bounce Yoshi off the top


SpriteContact_Shell:
	LDA $14C8,Y							; if the indexed sprite is in carryable status, bump it
	CMP #$09
	BNE +
	JMP BumpItem
	+
	CMP #$0A							; else, if it's in kicked status...
	BNE .return
	
	LDA $0E								; if Yoshi is not high enough...
	BMI KillYoshi						; kill Yoshi
	
	PHX									; else, point to different routines based on the shell type (set by the shell's extension byte)
	TYX
	LDA $7FAB40,X
	AND #%00000011
	PLX
	JSL $0086DF
		dw ShellContact_Stun
		dw ShellContact_SmokeKill
		dw ShellContact_Infinite
		dw ShellContact_Stun

.return
	RTS


KillYoshiXSpeed:
	db $18,$E8

KillYoshi:
	LDA #$13							; play Yoshi damage sfx
	STA $1DFC
	
	LDA #$02							; set Yoshi's sprite status to killed
	STA $14C8,X
	
	JSL $01AB72							; display contact gfx
	
	LDA #$D0							; give Yoshi upward y speed
	STA $AA,X
	
	LDA $E4,X							; store Yoshi's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	LDA $E4,Y							; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	LDY #$00							; check which side of the indexed sprite Yoshi is on, and index it
	REP #$20
	LDA $00
	SEC : SBC $02
	BPL +
	LDY #$01
	+
	SEP #$20
	
	TYA									; determine Yoshi's face direction based on the indexed side
	STA $157C,X
	
	LDA KillYoshiXSpeed,Y				; give Yoshi x speed based on the indexed side
	STA $B6,X
	PLY
	RTS


ShellContact_Stun:
	LDA #$09							; set the indexed sprite's status to carryable
	STA $14C8,Y
	LDA #$03							; play kick sfx
	STA $1DF9
	JMP BounceYoshiUp					; bounce Yoshi off the top

ShellContact_SmokeKill:
	LDA #$04							; set the shell's sprite status to 'erased in smoke'
	STA $14C8,Y
	LDA #$1F							; set the shell's death frame counter
	STA $1540,Y
	LDA #$08							; play smokekill sfx
	STA $1DF9
	JMP BounceYoshiUp					; bounce Yoshi off the top

ShellContact_Infinite:
	LDA #$03							; play kick sfx
	STA $1DF9
	JMP BounceYoshiUp					; bounce Yoshi off the top


SpriteContact_FlyingShell:
	PHX
	TYX
	LDA #$0F							; change the PIXI list ID to a regular shell
	STA $7FAB9E,X
	
	LDA $7FAB58,X						; transfer the shell type (different extension byte)
	STA $7FAB40,X
	PLX
	
	JMP BumpItem


SpriteContact_Throwblock:
	LDA $14C8,Y							; if the indexed sprite is in carryable status, bump it
	CMP #$09
	BNE +
	JMP BumpItem
	+
	CMP #$0A							; else, if it's in kicked status...
	BNE .return
	
	LDA $0E								; if Yoshi is high enough...
	BMI .return
	
	LDA #$02							; play contact sfx
	STA $1DF9
	JMP BounceYoshiUp					; bounce Yoshi off the top

.return
	RTS


SpriteContact_FlyingThrowblock:
	PHX
	TYX
	LDA #$0E							; change the PIXI list ID to a regular throwblock
	STA $7FAB9E,X
	PLX
	
	JMP BumpItem


SpriteContact_Solid:
	LDA $14D4,X					; temporarily move Yoshi 16 pixels up, since only the bottom half of Yoshi should interact with block sprites
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0010
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	JSR HandleSolidSprite
	
	LDA $14D4,X					; move Yoshi 16 pixels back down
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0010
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	RTS


HandleSolidSprite:
	%SolidSprite_SetupInteract()
	
	LDA $08						; branch if the 'touching from above' flag is set
	BNE SolidSprite_SetTop
	
	LDA $0A						; branch if the 'touching from the side' flag is set
	BNE SolidSprite_BonkSide
	RTS


SolidSprite_SetTop:
	LDA $AA,X					; don't interact if the calling sprite is moving up
	BMI .return
	
	STZ $AA,X					; set the calling sprite's y speed to 0
	%SolidSprite_DragSprite()	; drag the calling sprite horizontally along the block sprite
	
	REP #$20					; set the calling sprite's y to be the block sprite's y minus 15 pixels
	LDA $06
	SEC : SBC #$000F
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	SEP #$20
	
	LDA $1588,X					; set Yoshi's 'on the ground' flag
	ORA #%00000100
	STA $1588,X

.return
	RTS


SolidSprite_BonkSide:
	%SolidSprite_PushFromSide()
	JSR BonkYoshiWall
	RTS


SpriteContact_ParachuteDino:
	PHX
	TYX
	LDA #$00							; change the PIXI list ID to a regular dino
	STA $7FAB9E,X
	STA $7FAB40,X						; set the extension bytes to 0
	STA $7FAB4C,X
	STA $7FAB58,X
	INC $157C,X							; have the dino face left
	PLX
	
	JMP SpriteContact_KillTop


SpriteContact_ParachuteSpiny:
	PHX
	TYX
	LDA #$51							; change the PIXI list ID to a regular thwimp
	STA $7FAB9E,X
	PLX
	
	JMP SpriteContact_BounceTop


SpriteContact_PSwitch:
	LDA $163E,Y							; if the p-switch is not already pressed...
	BNE .return
	
	LDA $0E								; and Yoshi is high enough...
	BMI .return
	
	LDA $1686,Y							; disable Yoshi tonguing the p-switch
	ORA #%00000001
	STA $1686,Y
	
	LDA #$20							; set the p-switch's erase timer
	STA $163E,Y
	
	LDA #$20							; set the layer 1 shake timer
	STA $1887
	
	PHX
	TYX
	
	JSR HandlePSwitchEffect
	
	LDA $7FAB40,X						; if bit 3 of the p-switch's first extension byte is set...
	PLX
	AND #%00000100
	BEQ +
	LDA #$03							; play bounce sfx
	STA $1DF9
	JMP BounceYoshiUp					; bounce Yoshi upward
	+
	
	STZ $AA,X							; else, give Yoshi 0 y speed
	
	LDA #$0B							; play switch sfx
	STA $1DF9

.return
	RTS


HandlePSwitchEffect:
	LDA $7FAB40,X						; branch based on the p-switch type
	AND #%00000011
	JSL $0086DF
		dw ToggleCoinBlock
		dw ToggleOnOffPrimary
		dw ToggleOnOffSecondary
		dw TriggerShooter

ToggleCoinBlock:
	LDA $7FAB4C,X						; set the coin/block activation timer to the value specified by the second extension byte x4
	STA $14AD
	RTS

ToggleOnOffPrimary:
	LDA $14AF 							; else, toggle the primary on/off state
	EOR #$01
	STA $14AF
	RTS

ToggleOnOffSecondary:
	LDA $7FC0FC 						; toggle the secondary on/off state
	EOR #$01
	STA $7FC0FC
	RTS

TriggerShooter:
	LDA #$08							; set the shooter cooldown timer to 8 frames (which will fire a shot)
	STA $7C
	RTS
	RTS


SpriteContact_Parabeetle:
	LDA $0E								; preserve the scratch ram value
	PHA
	
	LDA $14D4,X							; temporarily move Yoshi 16 pixels up, since only the bottom half of Yoshi should interact with block sprites
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0010
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	JSR SemiSolidSprite_SetupInteract
	
	LDA $08								; branch if the 'touching from above' flag is set
	BEQ +
	JSR SolidSprite_SetTop
	+
	
	LDA $14D4,X							; move Yoshi 16 pixels back down
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0010
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	PLA									; if Yoshi is not high enough...
	BPL +
	JSR KillYoshi						; kill Yoshi
	+
	RTS


KillFishXSpeed:
	db $F0,$10

SpriteContact_FloppyFish:
	LDA #$03					; play kick sfx
	STA $1DF9
	
	LDA $E4,X					; store Yoshi's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	LDA $E4,Y					; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	LDY #$00					; give the indexed sprite x speed based on the horizontal position towards Yoshi
	REP #$20
	LDA $00
	SEC : SBC $02
	BPL +
	LDY #$01
	+
	SEP #$20
	LDA KillFishXSpeed,Y
	PLY
	STA $B6,Y
	
	LDA #$E0					; give the indexed sprite upward y speed
	STA $AA,Y
	
	LDA #$02					; set the indexed sprite status to killed
	STA $14C8,Y
	RTS


SemiSolidSprite_SetupInteract:
	STX $00						; if the block sprite's sprite slot is higher than the calling sprite's sprite slot...
	CPY $00
	BPL +
	LDA $E4,Y					; store the block sprite's x (current frame) to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	LDA $D8,Y					; store the block sprite's y (current frame) to scratch RAM
	STA $06
	LDA $14D4,Y
	STA $07
	
	BRA .blockposloaded
	+
	
	LDA $C2,Y					; else, store the block sprite's x (previous frame) to scratch RAM
	STA $02
	LDA $151C,Y
	STA $03
	
	LDA $1594,Y					; store the block sprite's y (previous frame) to scratch RAM
	STA $06
	LDA $160E,Y
	STA $07

.blockposloaded
	LDA $E4,X					; store the calling sprite's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $D8,X					; store the calling sprite's y to scratch RAM
	STA $04
	LDA $14D4,X
	STA $05
	
	LDA $1534,Y					; store the block sprite's width to scratch RAM
	STA $0C
	STZ $0D
	
	LDA $1570,Y					; store the block sprite's height to scratch RAM
	STA $0E
	STZ $0F

; set the blocked flags to 0
	STZ $08						; touching the block sprite from below

; check for top interaction
	REP #$20
	
	LDA $02						; if the calling sprite is too far left or right of the block sprite, don't check for interaction
	SEC : SBC $00
	SBC #$0008
	BPL .return
	CLC : ADC #$0010
	ADC $0C
	BMI .return
	
	LDA $06						; if the calling sprite is too far above or below of the block sprite, don't check for interaction
	SEC : SBC $04
	BMI .return
	SBC #$0010
	BPL .return
	
	INC $08						; set the 'touching from above' flag

.return
	SEP #$20
	RTS


BumpSpeedX:
	db $D2,$2E

BumpItem:
	LDA #$03							; play kick sfx
	STA $1DF9
	
	LDA #$08							; disable Yoshi contact with other sprites for 8 frames
	STA $163E,X
	
	LDA #$0A							; set the indexed sprite's status to 'kicked'
	STA $14C8,Y
	
	LDA $E4,X							; store Yoshi's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	LDA $E4,Y							; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	LDY #$00							; give the indexed sprite x speed based on the horizontal position towards Yoshi
	REP #$20
	LDA $00
	SEC : SBC $02
	BPL +
	LDY #$01
	+
	SEP #$20
	LDA BumpSpeedX,Y
	PLY
	STA $B6,Y
	RTS


BounceYoshiUp:
	LDA #$B0							; give Yoshi upward speed
	STA $AA,X
	
	%ContactGFX_YSprite()				; display contact gfx
	
	LDA #$08							; disable contact with other sprites for 8 frames
	STA $163E,X
	RTS


CheckTopContact:
	LDA.b #$0C							; check whether Yoshi is less than 12 pixels above the indexed sprite
	STA $0D
	LDA $01
	SEC : SBC $0D
	ROL $00
	CMP $05
	PHP
	LSR $00
	LDA $09
	SBC.b #$00
	PLP
	SBC $0B
	RTS


DismountXSpeed:
	db $10,$F0

DismountYoshi:
	LDA $1686,X							; enable this Yoshi to be tongued by another Yoshi
	AND #%11111110
	STA $1686,X
	
	LDA $7B								; give Yoshi Mario's x speed
	STA $B6,X
	
	LDY $72								; if Yoshi is on the ground...
	BNE +
	%SubHorzPos()						; give Mario x speed (based on Mario's x position compared to Yoshi's)
	LDA DismountXSpeed,Y
	STA $7B
	
	LDA #$C0							; give Mario y speed
	BRA .storedismountyspeed
	+
	
	LDA !AllowDropDismount				; else, if drop-dismounts are allowed...
	BEQ +
	LDA $7FAB40,X						; and the Yoshi is custom...
	BEQ +
	LDA $15								; and holding down...
	AND #%00000100
	BEQ +
	LDA #$10							; set the mount cooldown
	STA $154C,X
	LDA #$10							; show Mario's kicking pose for 16 frames
	STA $149A
	LDA !DropDismountMarioYSpeed		; give Mario y speed
	BRA .storedismountyspeed
	+
	
	LDA #$A0							; else, give Mario y speed

.storedismountyspeed
	STA $7D								; store Mario's y speed
	
	STZ $C2,X							; set Yoshi's state to normal
	STZ $187A							; set the 'riding Yoshi' flag to 0
	
	LDA $154C,X							; (custom) if the mount cooldown is not set, set Yoshi's y speed to 0
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
	%SetMarioAboveYoshi()
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
	
	LDA #$0C					; set Yoshi's squatting timer to 12 frames
	STA $1534,X
	
	STZ $B6,X					; set Yoshi's x speed to 0

SetMountYoshi:
	STZ $7D						; set Mario's y speed to 0

SetMountYoshi_NoResetY:
	LDA $14D4,X					; set Mario's y 16 pixels above Yoshi's y
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0010
	STA $96
	STA $D3
	SEP #$20
	
	LDA #$01					; set Yoshi's state to being ridden
	STA $C2,X
	
	LDA $1686,X					; disable this Yoshi from being tongued by another Yoshi
	ORA #%00000001
	STA $1686,X
	
	STX $18DA					; store Yoshi's sprite slot
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
	BEQ +
	LDY $160E,X					; else, load the sprite slot of the sprite in Yoshi's mouth
	
	LDA $14C8,X					; if Yoshi is dead...
	CMP #$08
	BEQ +
	LDA #$00
	STA $14C8,Y					; erase the sprite in Yoshi's mouth
	+
	
	LDA $1626,X					; if the tongue extension timer is 0, check for sticking out the tongue
	BEQ CheckExtendTongue
	DEC $1626,X					; else, decrement the tongue extension timer
	BNE .return					; if 0 (first frame)...
	INC $1594,X					; set Yoshi's mouth phase to 1 (extending tongue)
	STZ $151C,X					; set Yoshi's tongue length to 0
	LDA #$FF					; set the sprite slot on Yoshi's mouth to FF (= no sprite)
	STA $160E,X
	STZ $1564,X					; set the swallow animation timer to 0

.return
	RTS


CheckExtendTongue:
	LDA $9D						; if the game is frozen, return
	BNE .return
	LDA $14C8,X					; if the sprite is dead, return
	CMP #$08
	BNE .return
	
;	CPX $18DA					; if the Yoshi is not the most recently mounted one...
;	BNE .return
	
	LDA $7FAB40,X				; if the Yoshi is vanilla-style...
	BNE +
	LDA $C2,X					; if Yoshi is ridden...
	CMP #$01
	BNE .return
	LDA $16						; and X or Y is pressed...
	AND #%01000000
	BEQ .return
	BRA .dohandlemouth			; handle Yoshi's mouth
	+
	
	LDA $18						; else (custom Yoshi) if R is pressed...
	AND #%00010000
	BEQ .return

.dohandlemouth
	LDA $187B,X					; if Yoshi has a sprite in his mouth, extend his tongue
	BEQ InitExtendTongue
	JSR SpitSprite				; else, spit it out
	
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

SpriteSpitType:
	db $02,$02,$01,$03,$02,$00,$01,$03,$02,$02,$02,$02,$05,$02,$01,$01		; 0 = dino, 1 = mole, 2 = p-switch, 3 = goomba, 4 = taptap, 6 = spring, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00		; 1D = tallguy
	db $00,$02,$01,$00,$04,$03,$02,$00,$01,$00,$01,$01,$00,$00,$00,$00		; 21 = buster beetle, 22 = buzzy beetle, 24 = Yoshi, 25 = baby Yoshi, 26 = chuckoomba, 28 = carry block, 2A = magnet block, 2B = surfboard
	db $00,$00,$05,$02,$02,$02,$00,$02,$00,$02,$00,$02,$02,$00,$00,$00		; 32 = parabeetle, 33 = chomp, 34 = ninji, 35 = spiny, 37 = piranha plant, 39 = bouncing rock, 3C = vine koopa, 3D = fuzzy
	db $00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 41 = shooter item
	db $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 50 = bounce ball
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00		; 6C = walking p-switch
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

SpitSprite:
	LDA #$20							; play spit sfx
	STA $1DF9
	
	STZ $187B,X							; set Yoshi's mouth as empty
	LDY $160E,X							; load the spit sprite's sprite slot into Y
	
	LDA !CooldownAfterSpit				; set timer to prevent Yoshi from sticking out his tongue
	STA $1558,X
	LDA #$03							; set Yoshi's mouth phase to 3 (spitting)
	STA $1594,X
	LDA #$FF							; set the sprite slot in Yoshi's mouth to FF (no sprite)
	STA $160E,X
	
	LDA #$00							; clear the 'sprite is on Yoshi's tongue' flag for the spit sprite
	STA $15D0,Y
	STA $AA,Y							; give the spit sprite 0 y speed
	
	PHX									; store the indexed sprite's ID to scratch ram
	TYX
	LDA $7FAB9E,X
	STA $00
	PLX
	
	PHY									; set the spit sprite's x position based on Yoshi's face direction
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
	
	PHY									; set the spit sprite's y position based on the ducking flag (in vanilla SMW, it's always the same y)
	LDY $18DC
	BEQ +
	INY
	+
	LDA $14D4,X
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC SpitSpriteYOffset,Y
	
	LDY $00								; if the spit sprite is another Yoshi, position it 16 pixels higher
	CPY #$24
	BNE +
	SEC : SBC #$0010
	+
	
	SEP #$20
	PLY
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	PHY									; store the contact type to scratch ram based on the indexed sprite's ID
	LDY $00
	LDA SpriteSpitType,Y
	STA $0F
	PLY
	
	LDA $0F								; point to different routines based on the contact type
	JSL $0086DF
		dw SpitSprite_Item				; 0 = item (default for safety)
		dw SpitSprite_Item
		dw SpitSprite_Normal
		dw SpitSprite_Item_SameDir
		dw SpitSprite_Normal_SameDir
		dw SpitSprite_Normal_FixedSpeed


SpitSprite_Item_SameDir:
	LDA $157C,X							; give the spit sprite the same face direction as Yoshi
	STA $157C,Y

SpitSprite_Item:
	JSR SetSpitSpriteSpeed
	
	LDA $0E								; if holding down, give the spit sprite carryable status
	BEQ +
	LDA #$09
	BRA ++
	+
	LDA #$0A							; else, give it kicked status
	++
	STA $14C8,Y
	RTS


SpitSprite_Normal_SameDir:
	LDA $157C,X							; give the spit sprite the same face direction as Yoshi
	STA $157C,Y

SpitSprite_Normal:
	JSR SetSpitSpriteSpeed
	LDA #$08							; give the spit sprite normal status
	STA $14C8,Y
	RTS


SpitSprite_Normal_FixedSpeed:
	LDA $157C,X							; set the bullet bill's direction based on Yoshi's face direction
	STA $157C,Y
	
	LDA #$08							; give the spit sprite normal status
	STA $14C8,Y
	RTS


SetSpitSpriteSpeed:
	STZ $0E								; set the down-spit scratch ram value to 0
	LDA $15								; if holding down...
	AND #%00000100
	BEQ +
	LDA $C2,X							; and Mario is riding Yoshi...
	CMP #$01
	BNE +
	LDA $72								; and Mario (on Yoshi) is not airborne...
	BNE +
	INC $0E								; set the down-spit scratch ram value to 1
	+
	
	LDA $C2,X							; if Mario is riding Yoshi...
	CMP #$01
	BNE +
	LDA $7B								; store Mario's x speed to scratch ram
	BRA ++
	+
	LDA $B6,X							; else, store Yoshi's x speed to scratch ram
	++
	STA $0D
	
	PHX									; load Yoshi's face direction as an index
	LDA $157C,X
	TAX
	
	LDA $0E								; if holding down, give the spit sprite Yoshi's x speed + an offset based on Yoshi's face direction
	BEQ +
	LDA $0D
	CLC : ADC SpitSpriteXSpeedDown,X
	STA $B6,Y
	BRA .return
	+
	
	LDA SpitSpriteXSpeedNormal,X		; else, give the spit sprite x speed based on Yoshi's face direction
	STA $B6,Y
	EOR $0D								; if the spit sprite is now moving in the same direction as Mario, add half of Mario's x speed
	BMI .return
	LDA $0D
	STA $01
	ASL $01
	ROR
	CLC : ADC SpitSpriteXSpeedNormal,X
	STA $B6,Y

.return
	PLX
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
	BMI .return
	
	JSR HandleMouthSprite

.return
	RTS


SpriteMouthType:
	db $02,$02,$01,$02,$02,$02,$01,$02,$02,$02,$02,$02,$02,$02,$02,$01		; 0 = dino, 1 = mole, 2 = p-switch, 3 = goomba, 4 = taptap, 5 = flying spiny, 6 = spring, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $02,$02,$01,$02,$01,$02,$02,$00,$02,$02,$02,$02,$03,$02,$00,$00		; 10 = flying dino, 11 = flying coin, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1A = flying taptap, 1B = flying milde, 1C = mushroom, 1D = tallguy
	db $00,$02,$01,$00,$01,$01,$02,$00,$01,$00,$01,$01,$00,$00,$00,$00		; 21 = buster beetle, 22 = buzzy beetle, 24 = Yoshi, 25 = baby Yoshi, 26 = chuckoomba, 28 = carry block, 2A = magnet block, 2B = surfboard
	db $00,$00,$02,$02,$02,$02,$00,$02,$00,$02,$00,$00,$02,$02,$00,$00		; 32 = parabeetle, 33 = chomp, 34 = ninji, 35 = spiny, 37 = piranha plant, 39 = bouncing rock, 3C = vine koopa, 3D = fuzzy
	db $00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 41 = shooter item
	db $01,$01,$00,$00,$00,$00,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00		; 50 = bounce ball, 51 = thwimp, 58 = parachute dino, 59 = parachute spiny, 5A = parachute shell
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00		; 6C = walking p-switch
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

HandleMouthSprite:
	PHY									; store the contact type to scratch ram based on the indexed sprite's ID
	PHX
	TYX
	LDA $7FAB9E,X
	PLX
	TAY
	LDA SpriteMouthType,Y
	STA $0F
	PLY
	
	LDA $0F								; point to different routines based on the contact type
	JSL $0086DF
		dw HandleSpriteMouth_Swallow	; 0 = swallow (default for safety)
		dw HandleSpriteMouth_Stay
		dw HandleSpriteMouth_Swallow
		dw HandleSpriteMouth_PowerUp

.return
	RTS


SpriteMouthChangeType:
	db $FF,$FF,$FF,$FF,$FF,$35,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF		; 5 = flying spiny
	db $00,$FF,$22,$0E,$0F,$07,$03,$FF,$08,$09,$FF,$0D,$FF,$FF,$FF,$FF		; 10 = flying dino, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1B = flying milde
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$51,$0F,$FF,$FF,$FF,$FF,$FF		; 58 = parachute dino, 59 = parachute spiny, 5A = parachute shell
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$02,$FF,$FF,$FF		; 6C = walking p-switch
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

HandleSpriteMouth_Stay:
	LDA #$07						; change the sprite status to 'in Yoshi's mouth'
	STA $14C8,Y
	LDA #$FF						; set Yoshi's swallow timer (only used to check whether Yoshi has a sprite in his mouth, the timer doesn't decrement)
	STA $187B,X
	
	PHY								; load the sprite ID
	PHX
	TYX
	LDA $7FAB9E,X
	TAY
	LDA SpriteMouthChangeType,Y		; if the sprite is set to change sprite ID, do so
	BMI +
	STA $7FAB9E,X
	+
	PLX
	PLY
	RTS


HandleSpriteMouth_Swallow:
	LDA $7FAB40,X				; if the Yoshi is custom, have the sprite stay inside his mouth
	BNE HandleSpriteMouth_Stay
	
	JSR HandleSwallowSprite
	LDA #$06					; play swallow sfx
	STA $1DF9
	RTS


HandleSpriteMouth_PowerUp:
	LDA $7FAB40,X				; if the Yoshi is custom, have the sprite stay inside his mouth
	BNE HandleSpriteMouth_Stay
	
	JSR HandleSwallowSprite
	LDA #$0A					; play power-up sfx
	STA $1DF9
	LDA #$02					; put Mario in the 'get mushroom' animation state
	STA $71
	LDA #$2F					; set power-up animation timer
	STA $1496
	INC $9D						; set 'lock animations' flag
	RTS


HandleSwallowSprite:
	LDA #$00					; erase the sprite
	STA $14C8,Y
	LDA #$1B					; set Yoshi's swallow animation timer to 30 frames
	STA $1564,X
	LDA #$FF					; clear the sprite slot on Yoshi's tongue
	STA $160E,X
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
	BPL +
	JSR CheckTongueSprite
	RTS
	+

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
	
	PHX							; store the indexed sprite's ID to scratch ram
	TYX
	LDA $7FAB9E,X
	STA $0F
	PLX
	
	LDA #$00
	XBA
	LDA $00						; load the tongue tip tile y minus 4 or 8 pixels (specified above)
	CLC : ADC $0E
	REP #$20
	CLC : ADC $06				; add Yoshi's y position
	
	PHX							; if the tongued sprite is another Yoshi, set it 16 pixels higher
	LDX $0F
	CPX #$24
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
	
	LDA $0F						; if the sprite is another Yoshi, make it face the same direction as the tonguing Yoshi
	CMP #$24
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
	LDA $1686,Y					; if the sprite cannot be tongued ('Inedible' in CFG Editor), skip
	AND #%00000001
	BNE .loopcontinue
	
	PHY
	JSR TryTongueSprite
	PLY
	LDA $1558,X					; if the sprite was tongued, don't check other sprites
	BNE .return

.loopcontinue
	DEY
	BPL .loopstart

.return
	RTS


TryTongueSprite:
	PHX
	TYX
	%GetSpriteHitbox_Sprite()	; store the calling sprite's hitbox parameters to scratch ram
	PLX
	%CheckContact()				; check if the two sprites are in contact, return if not
	BCC .return
	
	TYA							; else, store the sprite slot of the tongued sprite
	STA $160E,X
	LDA #$02					; change the mouth phase to 2 (retracting tongue)
	STA $1594,X
	LDA #$0A					; disable tonguing something for 10 frames
	STA $1558,X

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


BonkYoshiWall:
	LDA $B6,X					; invert Yoshi's x speed...
	EOR #$FF
	INC A
	STA $B6,X
	LDA $157C,X					; and flip Yoshi's face direction
	EOR #$01
	STA $157C,X
	RTS