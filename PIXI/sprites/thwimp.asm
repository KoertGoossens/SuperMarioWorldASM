; thwimp that moves linearly without gravity and changes direction when hitting a solid surface
; the first extension byte sets the initial x speed
; the second extension byte sets the initial y speed

; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites


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
	LDA $7FAB40,X				; set x speed based on the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set y speed based on the second extension byte
	STA $AA,X
	
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
	JSR HandleBlockInteraction
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


BlockCheckOffsetX:
	dw $0010,$FFFF
BlockCheckOffsetY:
	dw $0011,$0000

HandleBlockInteraction:
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
	
	LDA $B6,X						; invert the x speed
	EOR #$FF
	INC A
	STA $B6,X
	+
	
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
	
	%GetMap16Solid()				; if the Map16 tile is a solid...
	BNE +
	
	LDA $AA,X						; invert the y speed
	EOR #$FF
	INC A
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
	RTS


BumpKickedItem:
	LDA $B6,Y					; invert the indexed sprite's x speed
	EOR #$FF
	INC A
	STA $B6,Y
	
	LDA #$08					; disable contact with other sprites for 8 frames for the thwimp
	STA $1564,X
	
	JSL $01AB6F					; display 'hit' graphic at sprite's position
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$A4					; tile ID
	STA $0302,Y
	
	LDA #%00100010
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS