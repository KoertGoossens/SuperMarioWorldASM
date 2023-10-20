; mushroom

; $C2,X		=	movement flag (0 = moving, 1 = stationary)
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $157C,X	=	face direction
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)


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
	LDA $AA,X					; if the mushroom's y speed is not 0 (it was spawned from a block)...
	BNE +
	INC $C2,X					; set the mushroom to be stationary
	+
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA #$10					; set the x speed
	LDY $157C,X					; invert it based on the face direction
	BEQ +
	DEC
	EOR #$FF
	+
	STA $B6,X
	
	LDA $C2,X					; branch if the mushroom is moving
	BEQ .moving
	
	JSL $019138					; else, process interaction with blocks
	
	LDA $1588,X					; if the mushroom is not blocked on any side...
	BNE +
	STZ $C2,X					; start moving
	+
	
	BRA .skipmoving

.moving
	JSR HandleGravity
	JSL $019138					; process interaction with blocks
	
	LDA $13						; 1 out of every 4 frames, decrease the y speed (to make the mushroom fall slower than a normal sprite)
	AND #%00000011
	BEQ .skipmoving
	DEC $AA,X

.skipmoving
	LDA $15AC,X					; if set to not interact with blocks, skip block interaction
	BNE .skipblockinteraction
	
	LDA $1588,X					; if the sprite is touching a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()
	
	LDA $C2,X					; if the mushroom is moving...
	BNE +
	LDA $1588,X					; and touching the side of a block...
	AND #%00000011
	BEQ +	
	LDA $157C,X					; flip its face direction
	EOR #%00000001
	STA $157C,X
	+

.skipblockinteraction
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


HandleGravity:		%ApplyGravity() : RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $154C,X					; if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	LDA $19						; if Mario is not small, skip the power-up animation
	BNE .skipanimation
	
	LDA #$02					; set the Mario animation trigger to 'get mushroom'
	STA $71
	
	LDA #$2F					; set the power-up animation length
	STA $1496
	STA $9D						; lock animations

.skipanimation
	LDA #$0A					; play power-up sfx
	STA $1DF9
	
	STZ $14C8,X					; erase the sprite

.return
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	LDA #$24					; tile ID
	STA $0302,Y
	
	LDA #%00001000				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the calling sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	LDA $1686,Y				; if the indexed sprite doesn't interact with other sprites...
	AND #%00001000
	ORA $1564,X				; or the calling sprite has the 'disable contact with other sprites' timer set...
	ORA $1564,Y				; or the indexed sprite has the 'disable contact with other sprites' timer set...
	ORA $15D0,Y				; or the indexed sprite is on Yoshi's tongue...
	ORA $1632,X				; or the calling sprite isn't on the same 'layer' as the indexed sprite (i.e. behind net)...
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
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	RTS


Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS