; golden thwimp that accelerates into one direction after being hit (by Mario's spin or by an item sprite) and stops when hitting a solid surface
; the extension byte sets the direction

; $C2,X		=	phase for golden thwimp (0 = idle, 1 = moving)
; $154C,X	=	timer to disable contact with Mario
; $1558,X	=	Z-tile timer
; $1564,X	=	timer to disable contact with other sprites
; $157C,X	=	direction (0 = right, 1 = left, 2 = up, 3 = down)


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
	LDA $7FAB40,X				; store the initial direction based on the extension byte
	STA $157C,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
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
	JSR HandleMovement
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleBlockInteraction
	JSR HandleSpriteInteraction
	JSR HandleMarioContact
	JSR HandleZZZ

.return
	RTS


BlockCheckOffsetX:
	dw $0010,$FFFF,$0008,$0008
BlockCheckOffsetY:
	dw $0008,$0008,$0011,$0000

HandleBlockInteraction:
	LDA $C2,X						; if the phase is 'idle', skip block interaction
	BEQ .return
	
	LDA $157C,X						; store the direction as an index
	ASL
	TAY
	
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
	CLC : ADC BlockCheckOffsetY,Y	; add the y offset
	STA $98							; store it to the block interaction point y
	SEP #$20
	
	%GetMap16Solid()				; if the Map16 tile is a solid...
	BNE .return
	
	STZ $C2,X						; set the phase back to 'idle'
	STZ $B6,X						; set the x speed back to 0
	STZ $AA,X						; set the y speed back to 0
	
	LDA $14E0,X						; align the sprite's x with the block
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0008
	AND #%1111111111110000
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	
	LDA $14D4,X						; align the sprite's y with the block
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC #$0008
	AND #%1111111111110000
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X
	
	LDA $157C,X						; invert the direction
	EOR #$01
	STA $157C,X

.return
	RTS


HandleMovement:
	LDA $C2,X						; if the phase is 'idle', skip movement
	BEQ .return
	
	LDA $157C,X						; point to different routines based on the direction
	JSL $0086DF
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
	CLC : ADC #$03
	STA $B6,X
	+
	RTS

MoveLeft:
	LDA $B6,X
	BEQ .accelerate
	CMP #$D0
	BCC +
.accelerate
	CLC : ADC #$FD
	STA $B6,X
	+
	RTS

MoveUp:
	LDA $AA,X
	BEQ .accelerate
	CMP #$D0
	BCC +
.accelerate
	CLC : ADC #$FD
	STA $AA,X
	+
	RTS

MoveDown:
	LDA $AA,X
	CMP #$30
	BCS +
	CLC : ADC #$03
	STA $AA,X
	+
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
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; if not spinjumping or riding Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	
	LDA #$01					; set the phase to moving
	STA $C2,X
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


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
	BEQ KickCarryableItem		; kick the item
	CMP #$0A					; if the indexed sprite is in kicked status...
	BEQ BumpKickedItem			; bump it off the thwimp as if the thwimp were solid
	RTS


ClashXSpeed:
	db $30,$D0

KickCarryableItem:
	LDA $E4,X					; store the thwimp's x to scratch RAM
	STA $00
	LDA $14E0,X
	STA $01
	
	LDA $E4,Y					; store the indexed sprite's x to scratch RAM
	STA $02
	LDA $14E0,Y
	STA $03
	
	PHY
	
	LDY #$00					; check which side of the thwimp the indexed sprite is on, and store it to Y
	REP #$20
	LDA $00
	SEC : SBC $02
	BPL +
	LDY #$01
	+
	SEP #$20
	
	LDA ClashXSpeed,Y			; set the indexed sprite's x speed depending on the direction towards the thwimp
	PLY
	EOR #$FF
	INC A
	STA $B6,Y
	
	LDA #$0A					; set the indexed sprite's status to kicked
	STA $14C8,Y
	
	LDA #$08					; disable contact with other sprites for 8 frames for the thwimp
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	
	LDA #$01					; set the phase to moving
	STA $C2,X
	RTS


BumpKickedItem:
	LDA $B6,Y					; invert the indexed sprite's x speed
	EOR #$FF
	INC A
	STA $B6,Y
	
	LDA #$08					; disable contact with other sprites for 8 frames for the thwimp
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	
	LDA #$01					; set the phase to moving
	STA $C2,X
	RTS


HandleZZZ:
	LDA $C2,X					; if the phase is 'moving', return
	BNE .return
	
	LDA $1558,X					; if the Z-tile timer is not at 0, return
	BNE .return
	
	LDA #$40					; set the Z-tile timer
	STA $1558,X
	
	LDA $15A0,X					; if the sprite is offscreen, return
	ORA $186C,X
	BNE .return
	
	LDY #$0B					; set the minor extended sprite slot index to B
	
.spriteslotloop
	LDA $17F0,Y					; if the minor extended sprite slot is unused, spawn a tile in it
	BEQ .spawntile
	
	DEY							; decrement the minor extended sprite slot
	BPL .spriteslotloop			; if still positive, check to see if it's used again
	
	DEC $185D
	BPL .skipfinalslot
	
	LDA #$0B
	STA $185D

.skipfinalslot
	LDY $185D

.spawntile
	LDA #$06					; set the minor extended sprite type to 'Z tile'
	STA $17F0,Y
	
	LDA $14E0,X					; offset the minor extended sprite's x from the calling sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC #$0006
	SEP #$20
	STA $1808,Y
	XBA
	STA $18EA,Y
	
	LDA $14D4,X					; offset the minor extended sprite's y from the calling sprite's y
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$0006
	SEP #$20
	STA $17FC,Y
	XBA
	STA $1814,Y
	
	LDA #$FA					; give the minor extended sprite upward y speed
	STA $182C,Y
	
	LDA #$7F					; set the duration to display the minor extended sprite
	STA $1850,Y

.return
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$A4					; tile ID
	STA $0302,Y
	
	LDA #%00100000
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS