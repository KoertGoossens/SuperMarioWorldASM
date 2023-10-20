; 2x2 tile block platform sprite that is solid for Mario and other sprites; Mario can hang on the sides and bottom, and can walljump off the sides

; $C2,X		=	stored x position (low byte)
; $1504,X	=	block interaction flag
; $151C,X	=	stored x position (high byte)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $1534,X	=	width (minus 16)
; $1558,X	=	activation timer
; $1570,X	=	height (minus 16)
; $157C,X	=	Mario interaction state (0 = neutral, 1 = standing on item, 2 = attached to side of item, 3 = hanging from below item)
; $1594,X	=	stored y position (low byte)
; $160E,X	=	stored y position (high byte)


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
	%RaiseSprite1Pixel()
	
	LDA #$10					; set the width (32 pixels)
	STA $1534,X
	LDA #$10					; set the height (32 pixels)
	STA $1570,X
	
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$1E : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$24 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	LDA #$FD : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites (vanilla flying item block = #$01)
	LDA #$FE : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites (vanilla flying item block = #$FE)
	LDA #$25 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites (vanilla flying item block = #$0D)
	LDA #$26 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites (vanilla flying item block = #$16)
	
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
	
	%SolidInteractionVals()
	%SubOffScreen()				; call offscreen despawning routine
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	
	JSR HandleMarioContact
	JSR HandleBlockWall
	JSR HandleBlockCeiling

.return
	RTS


HandleBlockWall:
	LDA $157C,X					; if the Mario interaction state is 2 (attached to side of block)...
	CMP #$02
	BNE .return
	
	STZ $7B						; set Mario's x and y speed to 0
	STZ $7D
	
	LDA #$01					; set the 'Mario carrying something' flag (to prevent being able to carry items)
	STA $1470
	
	%SubHorzPos()				; set Mario's face direction based on which side of the block he's on
	TYA
	STA $76
	
	LDA #$29					; set Mario's pose
	STA $13E0
	
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
	STZ $157C,X					; set the Mario interaction state back to 0

.return
	RTS


HandleBlockCeiling:
	LDA $157C,X					; if the Mario interaction state is 3 (attached to bottom of block)...
	CMP #$03
	BNE .return
	
	LDA $16						; if pressing B/A...
	ORA $18
	AND #%10000000
	BNE .dropmario				; drop Mario
	
	STZ $7B						; else, set Mario's x and y speed to 0
	STZ $7D
	
	LDA #$01					; set the 'Mario carrying something' flag (to prevent being able to carry items)
	STA $1470
	
	LDA $140D					; if Mario is not spinning...
	BNE +
	LDA #$0B					; set Mario's pose
	STA $13E0
	+

.return
	RTS

.dropmario
	STZ $157C,X					; set the Mario interaction state back to 0
	RTS


HandleMarioContact:
	STZ $1504,X					; set the block interaction flag to 0
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCS MarioContact
	RTS


CeilingOffset:					; small, big, small on Yoshi, big on Yoshi
	dw $0000,$0008,$FFFC,$0000

MarioContact:
	LDA $E4,X					; store the sprite's x to scratch ram
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $1534,X					; store the sprite's width to scratch ram
	STA $08
	STZ $09
	LDA $1570,X					; store the sprite's height to scratch ram
	STA $0A
	STZ $0B
	
	LDA #$18					; load a base y offset of 24 pixels to set Mario above the block sprite
	LDY $187A					; add another 10 pixels if Mario is on Yoshi
	BEQ +
	CLC : ADC #$10
	+
	STA $0E						; store the offset to scratch ram
	STZ $0F
	
	LDA $14D4,X					; if Mario's y is at least [offset] above the sprite's y, set him on top of it; otherwise, check for the ceiling
	XBA
	LDA $D8,X
	REP #$20
	STA $02						; also store the sprite's y to scratch ram
	SEC : SBC $96
	SBC $0E
	BMI .checkceiling
	SEP #$20
	
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
	LDA $00						; if Mario is at least 12 pixels left of the sprite or more than 12 pixels + [width offset] right of it, drop him off the side; otherwise, set him on top of the sprite
	SEC : SBC $94				; (behavior like with a solid layer 1 tile)
	SBC #$000C
	BPL .return
	CLC : ADC #$0018
	ADC $08
	BMI .return
	SEP #$20

; set Mario on top of the sprite
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
	STA $04
	STZ $05						; add the high byte (set to #$00 or #$FF)
	BPL +
	LDA #$FF
	STA $05
	+
	
	INC $1504,X					; set the block interaction flag to 1
	
	LDA $1662,X					; if $1662,X (tweaker byte) is set to #$3C...
	CMP #$3C
	BNE .return
	
	REP #$20
	LDA $94						; move Mario along with the block when on top of it
	CLC : ADC $04
	STA $94

.return
	SEP #$20
	RTS

.checkceiling
	SEP #$20
	LDY #$00					; load an index of 0
	
	LDA $19						; if Mario is big, increment the index
	BEQ +
	LDA $73
	BNE +
	INY
	+
	
	LDA $187A					; if Mario is on Yoshi, increment the index
	BEQ +
	INY #2
	+
	
	TYA							; multiply the index by 2
	ASL
	TAY
	
	REP #$20
	
	LDA $02						; load the block sprite's y
	SEC : SBC $96				; subtract Mario's y
	CLC : ADC $0A				; add the block sprite's height offset
	ADC CeilingOffset,Y			; add Mario's height offset
	BMI .return					; if negative (Mario is too low), don't interact with the block
	
	LDA $02						; load the block sprite's y
	SEC : SBC $0A				; subtract the block sprite's height offset
	SBC $96						; subtract Mario's y
	SBC #$0008
	BPL .pushfromside			; if positive (Mario is too high), push Mario from the side
	
	LDA $00						; else, if Mario is at least 9 pixels left of the sprite or more than 9 pixels [+ width offset] right of it, push him from the side
	SEC : SBC $94
	SBC #$0009
	BPL .pushfromside
	CLC : ADC #$0012
	ADC $08
	BMI .pushfromside
	
	SEP #$20
	LDA $7D						; return if Mario is not moving upward, otherwise make him bonk against the underside of the sprite
	BPL .return
	JSR MarioHitCeiling
	RTS

.pushfromside
	SEP #$20
	JSR MarioPushSide
	RTS


MarioPushSide:
	%SubHorzPos()				; check horizontal proximity of Mario to sprite and return side in Y (0 = right, 1 = left)
	
	LDA $1470					; if Mario is not carrying something...
	ORA $187A					; and is not on Yoshi...
	BNE .skipwallattach
	
	LDA $7B						; and Mario's x speed is not 0...
	BEQ .skipwallattach
	
	CPY #$00					; and Mario is not moving left while the block is to the right of him...
	BEQ +
	LDA $7B
	BMI .skipwallattach
	+
	
	CPY #$01					; and Mario is not moving right while the block is to the left of him...
	BEQ +
	LDA $7B
	BPL .skipwallattach
	+
	
	REP #$20
	LDA $02						; load the block sprite's y
	SEC : SBC $96				; subtract Mario's y
	CLC : ADC $0A				; add the block sprite's height offset
	CMP #$0026					; if Mario is not too high...
	BCS .skipwallattach
	CMP #$0006					; and not too low...
	BCC .skipwallattach
	SEP #$20
	
	LDA #$02					; set the Mario interaction state to 2 (attached to side of item)
	STA $157C,X
	STZ $140D					; unspin Mario

.skipwallattach
	SEP #$20
	
	LDA $14E0,X					; take the sprite's x + x offset (based on Mario's relative x direction to the sprite) and store it to Mario's x position
	XBA
	LDA $E4,X
	REP #$20
	
	CPY #$00
	BNE +
	CLC : ADC #$000E			; (vanilla flying block = $000E)
	ADC $08
	BRA .pushxoffsetloaded
	+
	CLC : ADC #$FFF2			; (vanilla flying block = $FFF1)

.pushxoffsetloaded
	STA $94
	SEP #$20
	
	TYA							; set the block interaction flag to 3 or 4, depending on the side of the block Mario is on
	CLC : ADC #$03
	STA $1504,X
	
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
	RTS

.return
	SEP #$20
	RTS


MarioHitCeiling:
	REP #$20
	LDA $02						; set Mario's y to be the sprite's y...
	CLC : ADC $0A				; + the block sprite's height offset
	ADC CeilingOffset,Y			; + Mario's height offset
	STA $96
	SEP #$20
	
	LDA $1470					; if Mario is not carrying something...
	ORA $187A					; and is not on Yoshi...
	BNE .skipceilingattach
	
	LDA #$03					; set the Mario interaction state to 3 (attached to ceiling)
	STA $157C,X
	
	STZ $7D						; set Mario's y speed to 0
	BRA .return

.skipceilingattach
	LDA #$10					; give Mario downward y speed
	STA $7D

.return
	RTS


TileX:
	db $00,$10,$00,$10
TileY:
	db $00,$00,$10,$10
TileMap:
	db $40,$41,$50,$51

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	LDX #$03					; use X for the loop counter (number of tiles - 1)

.tileloop
	LDA $00						; tile x position
	CLC : ADC TileX,X
	STA $0300,Y
	
	LDA $01						; tile y position
	CLC : ADC TileY,X
	STA $0301,Y
	
	LDA TileMap,X				; tile ID
	STA $0302,Y
	
	LDA #%00100101				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	INY #4						; increment the OAM index
	
	DEX							; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .tileloop
	
	LDX $15E9					; restore the sprite slot into X
	
	LDA #$03					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS