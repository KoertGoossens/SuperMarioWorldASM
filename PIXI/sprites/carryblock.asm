; carryable solid sprite (much like a vanilla key)
; jumpgrabs can be buffered by pressing B/A while holding Y/X

; $C2,X		=	stored x position (low byte)
; $1504,X	=	Mario interaction state (0 = neutral, 1 = standing on item)
; $151C,X	=	stored x position (high byte)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $1534,X	=	width (minus 16)
; $154C,X	=	timer to disable contact with Mario
; $1570,X	=	height (minus 16)
; $157C,X	=	face direction
; $1594,X	=	stored y position (low byte)
; $160E,X	=	stored y position (high byte)


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
	STZ $1534,X					; set the width (16 pixels)
	STZ $1570,X					; set the height (16 pixels)
	
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$0E : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$14 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	LDA #$FD : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites (vanilla flying item block = #$01)
	LDA #$FE : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites (vanilla flying item block = #$FE)
	LDA #$15 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites (vanilla flying item block = #$0D)
	LDA #$16 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites (vanilla flying item block = #$16)
	
	LDA #$09					; set the sprite status to carryable and run the carryable code
	STA $14C8,X
	BRA CarriableCode


; CARRIABLE STATUS
CarriableCode:
	LDA $9D						; if the game is frozen, only draw graphics
	BNE .gfx
	
	%SolidInteractionVals()
	%SubOffScreen()				; call offscreen despawning routine
	
	JSR HandleGravity
	%ProcessBlockInteraction()
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	
	JSR HandleBlockInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics
	RTS


HandleGravity:				%ApplyGravity() : RTS
HandleBlockInteraction:		%CheckBlockInteraction() : RTS


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

; ICON GRAPHICS
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$45					; tile ID
	STA $0302,Y
	
	LDA #%00100011				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y

; BLOCK GRAPHICS
	INY #4						; increment Y (the OAM index) by 4
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$46					; tilemap number (see Map8 in LM)
	STA $0302,Y
	
	LDA #%00000010				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$01					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS