; bubble sprite that Mario and sprites can enter, and Mario can boost out of in any direction; if Mario or a sprite touches it while another sprite is inside, the bubble will burst
; the first extension byte sets the direction to move in after Mario enters the bubble (0 = right, 1 = left, 2 = up, 3 = down, FF = stationary)
; the second extension byte sets the shot type:
;	0 = infinite shots
;	1 = pops after one shot
;	2 = pops soon after Mario enters, (or after one shot)
; the third extension byte sets the ID of the sprite to spawn inside the bubble (#$FF if no sprite)

;	$C2,X		=	phase (0 = normal, 1 = Mario being sucked in, 2 = Mario centered inside the bubble, 3 = bubble popped)
;	$1504,X		=	sprite ID of the sprite contained inside the bubble
;	$151C,X		=	animation frame counter
;	$1528,X		=	index of the sprite currently being sucked inside the bubble (#$FF if no sprite was found)
;	$1534,X		=	sprite contact phase (0 = no contact with another sprite, 1 = sprite being sucked in, 2 = sprite centered inside the bubble)
;	$154C,X		=	timer to disable contact with Mario
;	$1564,X		=	timer to disable contact with other sprites
;	$157C,X		=	timer before the bubble pops (set when Mario enters it)
;	$1594,X		=	movement phase (0 = stationary, 1 = moving after Mario enters)
;	$1602,X		=	animation frame
;	$187B,X		=	index of the sprite being processed for interaction


!boostspeedcooldown		=	$10			; number of frames you can hold left/right after shooting out of a bubble left/right without losing left/right speed
!poptimerfull			=	$20			; number of frames Mario can be inside an auto-pop bubble before it pops


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
	LDA $7FAB58,X				; if the bubble is set to spawn with a sprite inside...
	BMI +
	STA $1504,X					; set the ID of the sprite inside the bubble
	
	LDA #$02					; set the sprite contact phase to 'sprite centered inside bubble'
	STA $1534,X
	+
	
	LDA #$06 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$06 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$14 : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$16 : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$06 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$06 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$14 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$16 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%RaiseSprite1Pixel()
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	INC $151C,X					; increment the animation frame counter
	
	LDA $C2,X					; if the bubble is not popping...
	CMP #$03
	BEQ .skippopping
	
	JSR HandleMovement
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)

.skippopping
	LDA $C2,X					; point to different routines based on the contact phase
	JSL $0086DF
		dw NormalPhase
		dw SuckPhase
		dw CenterPhase
		dw PoppedPhase

.return
	RTS


HandleMovement:
	LDA $1594,X					; if the movement phase is 1...
	BEQ .return
	
	LDA $7FAB40,X				; and the bubble is not stationary...
	BMI .return
	
	JSL $0086DF					; point to different routines based on the direction
		dw MoveRight
		dw MoveLeft
		dw MoveUp
		dw MoveDown

.return
	RTS

MoveRight:
	LDA $B6,X
	CMP #$30
	BCS +
	CLC : ADC #$02
	STA $B6,X
	+
	RTS

MoveLeft:
	LDA $B6,X
	BEQ .accelerate
	CMP #$D0
	BCC +
.accelerate
	CLC : ADC #$FE
	STA $B6,X
	+
	RTS

MoveUp:
	LDA $AA,X
	BEQ .accelerate
	CMP #$D0
	BCC +
.accelerate
	CLC : ADC #$FE
	STA $AA,X
	+
	RTS

MoveDown:
	LDA $AA,X
	CMP #$30
	BCS +
	CLC : ADC #$02
	STA $AA,X
	+
	RTS


NormalPhase:
	LDA $151C,X					; store the animation frame (4 animation frames of 8 frames each)
	AND #%00011000
	LSR #3
	STA $1602,X
	
	JSR HandleBlockInteraction
	JSR HandleSpriteContact
	JSR HandleMarioContact
	RTS


SuckSpeed:
	dw $FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFD,$FFFE,$FFFF
	dw $0000
	dw $0001,$0002,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003

SuckPhase:
	JSR HandleFastAnimation
	JSR HandleBlockInteraction
	
	LDA $B6,X					; set Mario's x speed equal to the bubble's x speed
	STA $7B
	LDA $AA,X					; set Mario's y speed equal to the bubble's y speed
	STA $7D
	
	STZ $04						; set the horizontal center check flag to 0
	
	LDA $14E0,X					; shift Mario's x position a number of pixels depending on his exact x position
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0020
	SEC : SBC $94
	SEP #$20
	ASL
	TAY
	REP #$20
	LDA $94
	CLC : ADC SuckSpeed,Y
	STA $94
	SEP #$20
	
	CPY #$2E					; if Mario's x is centered inside the bubble, or 1 pixel off on either side, set the horizontal center check flag
	BEQ +
	CPY #$30
	BEQ +
	CPY #$32
	BEQ +
	BRA .skipxcenterflag
	+
	
	INC $04

.skipxcenterflag
	LDA $14D4,X					; shift Mario's y position a number of pixels depending on his exact y position
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0012
	SEC : SBC $96
	SEP #$20
	ASL
	TAY
	REP #$20
	LDA $96
	CLC : ADC SuckSpeed,Y
	STA $96
	SEP #$20
	
	CPY #$2E					; if Mario's y is centered inside the bubble, or 1 pixel off on either side...
	BEQ +
	CPY #$30
	BEQ +
	CPY #$32
	BEQ +
	BRA .return
	+
	
	LDA $04						; and the horizontal center check flag is set...
	BEQ .return
	
	INC $C2,X					; increment the contact phase
	INC $1908					; set the Mario-inside-bubble flag
	
	LDA #!poptimerfull			; set the bubble's pop timer
	STA $157C,X
	
	LDA #$01					; set the movement phase to 1
	STA $1594,X

.return
	RTS


; directions:	[unused], right, left, [unused], down, down-right, down-left, [unused], up, up-right, up-left, [unused], [unused], [unused], [unused], [unused]
ShootXSpeed:
	db $00,$48,$B8,$00,$00,$40,$C0,$00,$00,$40,$C0,$00,$00,$00,$00,$00
ShootYSpeed:
	db $A8,$00,$00,$00,$40,$40,$40,$00,$A8,$B0,$B0,$00,$00,$00,$00,$00		; 46 = max falling speed, A8 = speed when jumping off an enemy

CenterPhase:
	JSR HandleFastAnimation
	JSR HandleBlockInteraction
	
	LDA $B6,X					; set Mario's x and y speeds equal to those of the bubble (will not have effect for his position inside the bubble)
	STA $7B
	LDA $AA,X
	STA $7D
	
	LDA $140D					; if Mario is not spinning...
	BNE +
	LDA #$01					; have Mario always face right (so his image doesn't get inverted when pressing left/right)
	STA $76
	LDA #$0F					; show Mario's 'looking into the camera' pose
	STA $13E0
	+
	
	LDA $14E0,X					; keep Mario's x centered inside the bubble
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008
	STA $94
	SEP #$20
	
	LDA $14D4,X					; keep Mario's y centered inside the bubble
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0006
	STA $96
	SEP #$20
	
	JSR HandleAutoPop
	
	LDA $16						; if B or A is pressed...
	ORA $18
	AND #%10000000
	BEQ .return
	
	LDA #$03					; play bounce sfx
	STA $1DF9
	
	JSR DrawContactGFX
	
	LDA #!boostspeedcooldown	; set x speed boost cooldown (handled by xspeedfixes.asm and decremented by gm14code.asm)
	STA $18A6
	
	LDA $15						; give Mario x and y speeds based on the dpad direction
	AND #%00001111
	TAY
	LDA ShootXSpeed,Y
	STA $7B
	LDA ShootYSpeed,Y
	STA $7D
	
	LDA $7B						; if being shot out leftward, make Mario face left immediately
	BPL +
	STZ $76
	+
	
	LDA $7FAB4C,X				; if the bubble type is 0 (infinite boosts)...
	BNE +
	LDA #$10					; briefly disable contact with Mario
	STA $154C,X
	LDA #$10					; briefly disable contact with other sprites (to prevent an item entering the bubble immediately after Mario releases it when shooting out)
	STA $1564,X
	STZ $C2,X					; set the contact phase back to 0
	STZ $1908					; clear the Mario-inside-bubble flag
	STZ $157C,X					; set the bubble's pop timer back to 0
	BRA .return
	+
	
	JSR PopBubble				; else (single boost), pop the bubble

.return
	RTS


HandleAutoPop:
	LDA $7FAB4C,X				; if the bubble type is 2 (automatic pop)...
	CMP #$02
	BNE .return
	
	LDA $157C,X					; if the bubble's pop timer is negative...
	BPL .skippop
	
	JSR DrawContactGFX			; draw a contact star
	JSR PopBubble				; pop the bubble
	
	LDA $1490					; if Mario does not have star power...
	BNE +
	JSL $00F5B7					; hurt Mario
	+
	
	LDA #$04					; set the animation frame timer to 4 (first frame of splash GFX)
	STA $151C,X
	
	BRA .return

.skippop
	DEC $157C,X					; else, decrement the pop timer

.return
	RTS


DrawContactGFX:
	LDA #$08					; display contact star in the center of the bubble
	STA $0E
	STA $0F
	%ContactGFX()
	RTS


PoppedPhase:
	LDA $151C,X					; if the animation timer is at 8, erase the bubble sprite
	CMP #$08
	BNE .return
	STZ $14C8,X

.return
	RTS


HandleFastAnimation:
	LDA $7FAB4C,X				; if the bubble type is 2 (pops soon after Mario enters)...
	CMP #$02
	BNE +
	LDA $151C,X					; store the animation frame (4 animation frames of 2 frames each)
	AND #%00000110
	LSR
	STA $1602,X
	BRA .return
	+
	
	LDA $151C,X					; else, store the animation frame (4 animation frames of 4 frames each)
	AND #%00001100
	LSR #2
	STA $1602,X
	BRA .return

.return
	RTS


BlockCheckOffsetX:
	dw $001A,$0005
BlockCheckOffsetY:
	dw $001B,$0006

HandleBlockInteraction:
	LDA $B6,X						; if the sprite is moving horizontally...
	BEQ .skiphoriz
	
	LDY #$00						; load an index based on the horizontal movement direction
	LDA $B6,X
	BPL +
	LDY #$02
	+
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC BlockCheckOffsetX,Y	; add the x offset based on the index
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0008				; add the y offset
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	%GetMap16Solid()				; if the Map16 tile is a solid...
	BNE +
	JMP PopBubble
	+

.skiphoriz
	LDA $AA,X						; if the sprite is moving vertically...
	BEQ .return
	
	LDY #$00						; load an index based on the vertical movement direction
	LDA $AA,X
	BPL +
	LDY #$02
	+
	
	LDA $14E0,X						; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008				; add the x offset
	STA $9A							; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X						; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC BlockCheckOffsetY,Y	; add the y offset based on the index
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	%GetMap16Solid()				; if the Map16 tile is a solid, pop the bubble
	BNE +
	JMP PopBubble
	+

.return	
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	LDA $1534,X					; if there is a sprite inside the bubble...
	BEQ +
	STZ $7B						; set Mario's x and y speeds to 0
	STZ $7D
	JSR PopBubble				; pop the bubble
	RTS
	+
	
	LDA #$0E					; else, play swim sfx
	STA $1DF9
	INC $C2,X					; set the phase to 'sucking Mario'
	RTS


HandleSpriteContact:
	LDA #$FF					; set the contact sprite slot to #$FF (no sprite)
	STA $187B,X
	
	JSR HandleSpriteInteraction	; if in contact with a sprite...
	
	LDA $1534,X					; point to different routines based on the sprite contact phase
	JSL $0086DF
		dw NoSpriteContact
		dw SuckSprite
		dw CenterSprite


NoSpriteContact:
	LDA #$FF					; set the sucked sprite ID to #$FF (no sprite)
	STA $1528,X
	
	LDA $187B,X					; if in contact with a sprite...
	BMI .return
	
	STA $1528,X					; store the sucked sprite ID
	TAY
	LDA $14C8,Y					; if the sucked sprite is in kicked status, give it carryable status
	CMP #$0A
	BNE +
	LDA #$09
	STA $14C8,Y
	+
	
	LDA #$0E					; play swim sfx
	STA $1DF9
	
	INC $1534,X					; increment the sprite contact phase

.return
	RTS


SuckSprite:
	LDA $187B,X					; if in contact with a sprite (not the one being sucked in)...
	BMI .handlesucksprite
	
	JSR PopBubble				; pop the bubble
	RTS

.handlesucksprite
	LDY $1528,X					; load the stored index of the sprite being sucked in
	
	LDA $B6,X					; set the contact sprite's x and y speeds equal to that of the bubble
	STA $B6,Y
	LDA $AA,X
	STA $AA,Y
	
	STZ $04						; set the horizontal center check flag to 0
	
	LDA $E4,Y					; store the indexed sprite's x position to scratch ram
	STA $00
	LDA $14E0,Y
	STA $01
	LDA $D8,Y					; store the indexed sprite's y position to scratch ram
	STA $02
	LDA $14D4,Y
	STA $03
	
	PHY
	
	LDA $14E0,X					; store the number of pixels for the indexed sprite's x to move (based on it's exact position inside the bubble) to scratch ram
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0020
	SEC : SBC $00
	SEP #$20
	ASL
	TAY
	REP #$20
	LDA SuckSpeed,Y
	STA $05
	SEP #$20
	
	CPY #$2E					; if the indexed sprite's x is centered inside the bubble, or 1 pixel off on either side, set the horizontal center check flag
	BEQ +
	CPY #$30
	BEQ +
	CPY #$32
	BEQ +
	BRA .skipxcenterflag
	+
	
	INC $04

.skipxcenterflag
	LDA $14D4,X					; store the number of pixels for the indexed sprite's y to move (based on it's exact position inside the bubble) to scratch ram
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0020
	SEC : SBC $02
	SEP #$20
	ASL
	TAY
	REP #$20
	LDA SuckSpeed,Y
	STA $07
	SEP #$20
	
	CPY #$2E					; if the indexed sprite's y is centered inside the bubble, or 1 pixel off on either side...
	BEQ +
	CPY #$30
	BEQ +
	CPY #$32
	BEQ +
	BRA .notcentered
	+
	
	LDA $04						; and the horizontal center check flag is set...
	BEQ .notcentered
	
	PLY
	
	PHX
	TYX
	LDA $7FAB9E,X				; store the contact sprite ID
	PLX
	STA $1504,X
	
	LDA #$00					; erase the contact sprite
	STA $14C8,Y
	INC $1534,X					; increment the sprite contact phase
	BRA .return

.notcentered
	PLY
	
	REP #$20					; shift the indexed sprite's x position depending on the value stored in scratch ram
	LDA $00
	CLC : ADC $05
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	REP #$20					; shift the indexed sprite's y position depending on the value stored in scratch ram
	LDA $02
	CLC : ADC $07
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y

.return
	RTS


CenterSprite:
	LDA #$FF					; set the sucked sprite ID to #$FF (no sprite)
	STA $1528,X
	
	LDA $187B,X					; if in contact with a sprite...
	BMI .return
	
	JSR PopBubble				; pop the bubble

.return
	RTS


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the item sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	TYA						; if the indexed sprite is being sucked inside the bubble, don't check for contact
	CMP $1528,X
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	CMP #$0B				; if the indexed sprite is in carried status, don't check for contact
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
	%CheckSpriteSpriteContact()			; if the sprite is in contact with the indexed sprite...
	BCC .return
	
	TYA									; store the contact sprite's slot
	STA $187B,X

.return
	RTS


PopBubble:
	LDA #$19					; play clap sfx
	STA $1DFC
	STZ $151C,X					; set the animation timer to 0
	
	LDA $C2,X					; if the contact phase is 2 (Mario inside bubble)...
	CMP #$02
	BNE +
	STZ $1908					; clear the Mario-inside-bubble flag
	+
	
	LDA #$03					; set the phase to 3 (bubble popped)
	STA $C2,X
	
	LDA $1534,X					; if there is a sprite inside the bubble...
	CMP #$02
	BNE .return
	
	LDA $1504,X					; spawn the sprite indexed by the ID
	%SpawnCustomSprite()
	
	LDA $14E0,X					; offset the spawned sprite's x from the bubble's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $14D4,X					; offset the spawned sprite's y from the bubble's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0008
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	
	LDA #$10					; temporarily disable contact with other sprites for the spawned sprite
	STA $1564,Y

.return
	RTS


OuterTileX:
	db $01,$00,$01,$02,		$0F,$10,$0F,$0E,	$01,$00,$01,$02,	$0F,$10,$0F,$0E
OuterTileY:
	db $01,$02,$01,$00,		$01,$02,$01,$00,	$0F,$0E,$0F,$10,	$0F,$0E,$0F,$10
OuterTileProp:
	db %00100001,%01100001,%10100001,%11100001
OuterTilePalette:
	db %00000100,%00000110,%00001110

ContactSpriteTileID:
	db $84,$8A,$08,$00,$A8,$00,$00,$00,$A2,$C4,$00,$E0,$00,$00,$46,$8C		; 0 = dino, 1 = mole, 2 = p-switch, 4 = taptap, 8 = shyguy, 9 = floppy fish, B = shloomba, E = throwblock, F = shell
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$24,$00,$00,$00		; 1C = mushroom
	db $00,$86,$A6,$00,$00,$68,$00,$00,$46,$00,$00,$00,$00,$00,$00,$00		; 21 = buster beetle, 22 = buzzy beetle, 24 = Yoshi, 25 = baby Yoshi, 28 = carry block
	db $00,$00,$00,$00,$C2,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 34 = ninji, 35 = spiny
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	db $46,$00,$00,$46,$63,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 60 = solid block, 63 = item block, 64 = switch block
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
ContactSpriteTileProp:
	db %00000000,%00000001,%00000110,%00000000,%00000001,%00000000,%00000000,%00000000,%00001001,%00000101,%00000000,%00000000,%00000000,%00000000,%00000110,%01001010
	db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00001000,%00000000,%00000000,%00000000
	db %00000000,%00000111,%00000111,%00000000,%00001011,%00001011,%00000000,%00000000,%00000010,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	db %00000000,%00000000,%00000000,%00000000,%00001101,%00001000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	db %00000100,%00000000,%00000000,%00000100,%00000111,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

Graphics:
	LDA $1602,X						; store the animation frame to scratch ram
	STA $02
	LDA $C2,X						; store the phase to scratch ram
	STA $03
	
	LDA $7FAB4C,X					; store the palette based on the bubble type to scratch ram
	TAY
	LDA OuterTilePalette,Y
	STA $04
	
	LDA #$04						; store the number of OAM tiles to draw to scratch ram
	STA $05
	
	%GetDrawInfo()					; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $C2,X						; if the bubble is popping, skip to only drawing the pop animation
	CMP #$03
	BNE +
	JMP PopGraphics
	+

; OUTER TILES GRAPHICS
	PHX
	LDX #$03						; load loop counter (4 bubble outer tiles)

.outertileloop
	PHX
	TXA								; change the index for x/y offsets: loop counter (= tile id) x4 + animation frame
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
	
	LDA #$EC						; tile ID
	STA $0302,Y
	
	LDA $04							; store tile YXPPCCCT properties based on the bubble type
	ORA OuterTileProp,X
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
	PLX

; GLIMMER TILE GRAPHICS
	LDA $03							; if Mario is centered inside the bubble, set the OAM index to 0 to draw the glimmer tile in front of Mario
	CMP #$02
	BNE +
	LDY #$00
	+
	
	LDA $00							; tile x position
	CLC : ADC #$08
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC #$08
	STA $0301,Y
	
	LDA #$EE						; tile ID
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

; CONTACT SPRITE TILE GRAPHICS
	LDA $1534,X						; if the bubble contains a sprite, draw its tile
	CMP #$02
	BNE .gfxendroutine
	
	LDA $1504,X						; if the sprite is a throwblock...
	CMP #$0E
	BEQ +
	CMP #$28						; or a carry block...
	BEQ +
	BRA .skipblockeyes
	+
	JSR DrawBlockEyes				; draw the eyes tile

.skipblockeyes
	LDA $00							; tile x position
	CLC : ADC #$08
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC #$08
	STA $0301,Y
	
	PHX
	LDA $1504,X						; store tile ID based on the contact sprite ID
	TAX
	LDA ContactSpriteTileID,X
	STA $0302,Y
	
	LDA ContactSpriteTileProp,X		; store tile YXPPCCCT properties based on the contact sprite ID
	ORA $64
	STA $0303,Y
	PLX
	
	PHY								; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	INC $05							; increase the number of OAM tiles to draw

; OAM END-ROUTINE
.gfxendroutine
	LDA $05							; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


DrawBlockEyes:
	LDA $00							; tile x position
	CLC : ADC #$08
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC #$08
	STA $0301,Y
	
	LDA #$45						; tile ID
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
	INC $05							; increase the number of OAM tiles to draw
	RTS


PopTilesX:
	db $01,$0F,$01,$0F
PopTilesY:
	db $01,$01,$0F,$0F
PopTilesID:
	db $00,$00,$00,$00,$64,$64,$66,$66

PopGraphics:
	LDA $151C,X						; store the animation frame timer to scratch ram
	STA $02
	CMP #$04						; don't show the pop water tiles for the first 4 frames of the animation
	BCC .return
	
	LDX #$03						; load loop counter (4 bubble outer tiles)

.poptilesloop
	LDA $00							; tile x position
	CLC : ADC PopTilesX,X
	STA $0300,Y
	
	LDA $01							; tile y position
	CLC : ADC PopTilesY,X
	STA $0301,Y
	
	PHX
	LDA $02							; tile ID based on the animation frame
	TAX
	LDA PopTilesID,X
	STA $0302,Y
	PLX
	
	LDA #%00010010					; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	INY #4							; increment OAM index
	DEX								; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .poptilesloop
	
	LDA #$03						; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3

.return
	RTS