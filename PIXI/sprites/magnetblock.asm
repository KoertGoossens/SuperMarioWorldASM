; throwable magnet block; solid for Mario, can attach to surfaces
; don't use together with vanilla item sprites

; $1504,X	=	Mario interaction state (0 = neutral, 1 = standing on item, 2 = attached to side of item, 3 = hanging from below item)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $154C,X	=	timer to disable contact with Mario
; $157C,X	=	face direction
; $1594,X	=	block interaction state (0 = free, 1 = attached to wall, 2 = attached to ceiling)

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
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset
	LDA #$0D : STA $7FB618,X	; sprite hitbox width
	LDA #$14 : STA $7FB624,X	; sprite hitbox height
	
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
	
	LDA $1594,X					; if the sprite is attached to a surface...
	BEQ +
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	STZ $190F,X					; don't push the item out of walls (otherwise it will mess with the item sticking to walls)
	%ProcessBlockInteraction()
	BRA .positionupdated
	+
	
	LDA #%10000000				; else, push the item out of walls
	STA $190F,X
	
	JSR HandleGravity
	%ProcessBlockInteraction()
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X

.positionupdated
	JSR HandleBlockInteraction
	
	LDA $1594,X					; if the block is attached to a wall or ceiling, immediately allow interaction with Mario
	BEQ +
	STZ $154C,X
	+
	
	JSR HandleMarioContact
	JSR HandleBlockWall
	JSR HandleBlockCeiling

.gfx
	JSR Graphics
	RTS


HandleGravity:		%ApplyGravity() : RTS


HandleBlockWall:
	LDA $1504,X					; if the Mario interaction state is 2 (attached to side of item)...
	CMP #$02
	BNE .return
	
	STZ $7B						; set Mario's x and y speed to 0
	STZ $7D
	
	LDA #$01					; set the 'Mario carrying something' flag (to prevent being able to carry other items)
	STA $1470
	
	%SubHorzPos()				; set Mario's face direction based on which side of the item he's on
	TYA
	STA $76
	
	LDA #$29					; set Mario's pose
	STA $13E0
	
	LDA $16						; if pressing Y/X, grab the item
	AND #%01000000
	BNE .handlewallitemgrab
	
	LDA $16						; if pressing B...
	AND #%10000000
	BEQ +
	LDA #$B0					; set Mario's y speed (regular normal jumping y speed = #$B0)
	STA $7D
	BRA .handlewalljump
	+
	
	LDA $18						; else, if pressing A...
	AND #%10000000
	BEQ +
	LDA #$B6					; set Mario's y speed (regular spinjumping y speed = #$B6)
	STA $7D
	INC $140D					; set the spin flag
	BRA .handlewalljump
	+
	
	RTS

.handlewalljump
	LDA #$24					; set Mario's x speed based on his face direction (running speed = #$24)
	LDY $76
	BEQ +
	EOR #$FF
	INC A
	+
	STA $7B
	
	LDA $15						; if holding down, set Mario's y speed to 0
	AND #%00000100
	BEQ +
	STZ $7D
	+
	
	LDA $76						; invert Mario's face direction
	EOR #$01
	STA $76
	
	LDA #$02					; play hit sfx
	STA $1DF9
	
	JSL $01AB99					; display contact star at Mario's position
	
	LDA $15						; if not holding Y/X, skip grabbing the block
	AND #%01000000
	BEQ .handlewallrelease

.handlewallitemgrab
	STZ $1594,X					; set block interaction state back to 0
	LDA #$0B					; set the sprite status to 'carried'
	STA $14C8,X

.handlewallrelease
	STZ $1504,X					; set the Mario interaction state back to 0

.return
	RTS


HandleBlockCeiling:
	LDA $1504,X					; if the Mario interaction state is 3 (attached to bottom of item)...
	CMP #$03
	BNE .return
	
	LDA $16						; if pressing B/A...
	ORA $18
	AND #%10000000
	BEQ +
	
	LDA $15						; if holding Y/X, release the item
	AND #%01000000
	BNE .releaseitem
	BRA .dropmario				; else, only drop Mario
	+
	
	STZ $7B						; set Mario's x and y speed to 0
	STZ $7D
	
	LDA #$01					; set the 'Mario carrying something' flag (to prevent being able to carry other items)
	STA $1470
	
	LDA $140D					; if Mario is not spinning...
	BNE +
	LDA #$0B					; set Mario's pose
	STA $13E0
	+
	
	LDA $16						; if pressing Y/X...
	AND #%01000000
	BEQ .return

.releaseitem
	STZ $1594,X					; set block interaction state back to 0
	LDA #$0B					; set the sprite status to 'carried'
	STA $14C8,X

.dropmario
	STZ $1504,X					; set the Mario interaction state back to 0

.return
	RTS


HandleBlockInteraction:
	LDA $1588,X					; if the sprite is touching a ground, handle interaction with it
	AND #%00000100
	BEQ +
	JSR BlockGroundInteraction
	+
	
	LDA $1588,X					; else, if the item is touching a ceiling, handle interaction with it
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
	%BounceCarryableSprite()
	RTS


BlockSideInteraction:
	LDA $1594,X					; if the block interaction state is 0...
	BNE .return
	
	LDA $B6,X					; invert the sprite's x speed...
	EOR #$FF
	INC A
	STA $B6,X
	ASL							; and divide it by 4
	PHP
	ROR $B6,X
	PLP
	ROR $B6,X
	
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


BlockCeilingInteraction:
	LDA $1594,X					; if the block interaction state is 0...
	BNE .return
	
	LDA #$10					; give the item downward y speed
	STA $AA,X
	
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


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR HandleJumpGrabItem
	LDA $14C8,X					; if Mario just grabbed the item from a jumpgrab, don't handle normal interaction with Mario
	CMP #$0B
	BEQ .return
	
	LDA $E4,X					; store the sprite's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $14D4,X					; if Mario's y is at least 24 pixels above the sprite's y, set him on top of it
	XBA
	LDA $D8,X
	REP #$20
	STA $02						; also store the sprite's y to scratch RAM
	SEC : SBC $96
	SBC #$0018
	BMI .notontop
	SEP #$20
	JSR CheckSetOnTop

.return
	SEP #$20
	RTS

.notontop
	REP #$20
	
	LDA #$0000					; load a base value of 0 for ceiling checking
	LDY $73						; if ducking, load a base value of 8 instead
	BNE +
	LDY $19
	BNE ++
	+
	LDA #$0008
	++
	LDY $187A					; if on Yoshi, add 8
	BEQ +
	CLC : ADC #$0008
	+
	STA $04						; store the base value to scratch RAM
	
	LDA $02						; if Mario's y is less than [base value] pixels below the sprite's y, push him from the side
	SEC : SBC $96
	SBC $04
	BPL .mariopushside
	
	LDA $00						; else, if Mario is at least 9 pixels left of the sprite or more than 8 pixels right of it, push him from the side
	SEC : SBC $94
	SBC #$0009
	BPL .mariopushside
	CLC : ADC #$0011
	BMI .mariopushside
	
	SEP #$20
	LDA $7D						; return if Mario is not moving upward, otherwise make him bonk against the underside of the sprite
	BPL .return
	JSR MarioHitCeiling
	RTS

.mariopushside
	SEP #$20
	JSR MarioPushSide
	RTS


HandleJumpGrabItem:
	LDA $16						; if B or A was newly pressed...
	ORA $18
	AND #%10000000
	BEQ +
	
	LDA $1504,X					; and the sprite's Mario interaction state is 1 (Mario just jumped off it)...
	CMP #$01
	BNE +
	
	STZ $1504,X					; set the sprite's Mario interaction state to 0
	
	LDA $15						; if holding Y/X, check whether Mario should grab the item
	AND #%01000000
	BEQ +
	JSR CheckGrabItem
	+
	
	RTS


CheckGrabItem:
	LDA $1470					; and Mario is not carrying something...
	ORA $187A					; and is not on Yoshi...
	BNE .return
	
	LDA #$0B					; set the sprite status to 'carried'
	STA $14C8,X
	
	INC $1470					; set the 'carrying something' flag
	
	LDA #$08					; set the 'picking up an item' pose timer
	STA $1498
	
	STZ $1594,X					; set the block interaction state back to 0

.return
	RTS


CheckSetOnTop:
	LDA $AA,X					; if the sprite is moving down...
	BMI +
	LDA $7D						; return if Mario is moving up
	BMI .return
	BRA .checkxpos
	+
	SEC : SBC $7D				; else, return only if Mario is moving up faster than the sprite is (to prevent Mario from clipping through)
	BPL .return

.checkxpos
	REP #$20
	LDA $00						; if Mario is at least 12 pixels left of the sprite or more than 11 pixels right of it, drop him off the side; otherwise, set him on top of the sprite
	SEC : SBC $94				; (behavior like with a solid layer 1 tile)
	SBC #$000C
	BPL .return
	CLC : ADC #$0017
	BMI .return
	SEP #$20
	
	LDA $16						; if pressing Y/X, check whether Mario should grab the item
	AND #%01000000
	BEQ +
	JSR CheckGrabItem
	LDA $14C8,X					; if Mario just grabbed the item, skip setting Mario on top of it
	CMP #$0B
	BEQ .return
	+
	
	LDA #$01					; set the Mario interaction state to 'standing on the sprite'
	STA $1504,X
	
	LDA $AA,X					; give Mario the y speed of the sprite
	CMP #$10					; if it's below #$10, set it to #$10
	BPL +
	LDA #$10
	+				
	STA $7D
	
	LDA #$01					; set Mario as standing on a solid sprite
	STA $1471
	
	REP #$20
	LDA $02						; set Mario's y to be the sprite's y minus 31 pixels
	SEC : SBC #$001F
	LDY $187A					; subtract another 16 pixels if Mario is on Yoshi
	BEQ +
	SBC #$0010
	+
	STA $96
	SEP #$20
	
	LDA $1528,X					; store the 'number of pixels the sprite has moved' to scratch ram
	STA $03
	STZ $04						; add the high byte (set to #$00 or #$FF)
	BPL +
	LDA #$FF
	STA $04
	+
	
	REP #$20
	LDA $94						; move Mario along with the block when on top of it
	CLC : ADC $03
	STA $94

.return
	RTS


MarioPushSide:
	%SubHorzPos()				; check horizontal proximity of Mario to sprite and return side in Y (0 = right, 1 = left)
	
	LDA $1594,X					; if the block interaction state is 1 (attached to wall)...
	CMP #$01
	BNE .skipwallattach
	
	LDA $1470					; and Mario is not carrying something...
	ORA $187A					; and is not on Yoshi...
	BNE .skipwallattach
	
	LDA $7B						; and Mario's x speed is not 0...
	BEQ .skipwallattach
	
	CPY #$00					; and Mario is not moving left while the item is to the right of him...
	BEQ +
	LDA $7B
	BMI .skipwallattach
	+
	
	CPY #$01					; and Mario is not moving right while the item is to the left of him...
	BEQ +
	LDA $7B
	BPL .skipwallattach
	+
	
	LDA $14D4,X					; and Mario's y is not too high or too low compared to the item's y...
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $96
	CMP #$0016
	BCS .skipgrab
	CMP #$0006
	BCC .skipgrab
	SEP #$20
	
	LDA #$02					; set the Mario interaction state to 2 (attached to side of item)
	STA $1504,X
	STZ $140D					; unspin Mario

.skipwallattach
	SEP #$20
	
	LDA $1504,X					; if Mario is attached to the side of the item...
	CMP #$02
	BEQ +
	LDA $15						; and holding Y/X, check whether Mario should grab the item
	AND #%01000000
	BEQ +
	JSR CheckGrabItem
	LDA $14C8,X					; if Mario just grabbed the item, skip setting Mario on top of it
	CMP #$0B
	BEQ .return
	+

.skipgrab
	SEP #$20
	
	LDA $14E0,X					; take the sprite's x + x offset (based on Mario's relative x direction to the sprite) and store it to Mario's x position
	XBA
	LDA $E4,X
	REP #$20
	
	CPY #$00
	BNE +
	CLC : ADC #$000D			; (vanilla flying block = $000E)
	BRA .pushxoffsetloaded
	+
	CLC : ADC #$FFF2			; (vanilla flying block = $FFF1)

.pushxoffsetloaded
	STA $94
	SEP #$20
	
	CPY #$00					; if Mario is moving right while the sprite is to the left of him...
	BEQ +
	LDA $7B
	BPL .nullmarioxspeed
	BRA .return
	+
	
	LDA $7B						; or Mario is moving left while the sprite is to the right of him...
	BPL .return

.nullmarioxspeed
	STZ $7B						; set Mario's x speed to 0

.return
	RTS


MarioHitCeiling:
	REP #$20
	LDA $02						; set Mario's y to be equal to the sprite's y (same y position as when bonking against a solid layer 1 tile)
	STA $96
	SEP #$20
	
	LDA $1594,X					; if the block interaction state is 2 (attached to ceiling)...
	CMP #$02
	BNE .skipceilingattach
	
	LDA $1470					; and Mario is not carrying something...
	ORA $187A					; and is not on Yoshi...
	BNE .skipceilingattach
	
	LDA #$03					; set the Mario interaction state to 3 (attached to ceiling)
	STA $1504,X
	
	STZ $7D						; set Mario's y speed to 0
	BRA .return

.skipceilingattach
	LDA #$10					; give Mario downward y speed
	STA $7D

.return
	RTS


; KICKED STATUS
KickedCode:
	JSR Graphics
	LDA #$09					; set the sprite status to 'carriable'
	STA $14C8,X
	RTS


; CARRIED STATUS
CarriedCode:
	%OffsetCarryableItem()
	
	LDA $9D						; if the game is frozen, only handle graphics
	BNE .gfx
	
	LDA $1419					; if Mario is going down a pipe, or if holding Y/X, offset the sprite from Mario; else, release the item
	BNE .gfx
	LDA $15
	AND #%01000000
	BNE .gfx
	
	%ReleaseItem_Standard()

.gfx
	LDA $64						; handle OAM priority and draw graphics
	PHA
	%HandleOAMPriority()
	JSR Graphics
	PLA
	STA $64
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	LDA #$46					; tile ID
	STA $0302,Y
	
	LDA #%00000100				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS