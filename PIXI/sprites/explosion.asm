; explosion sprite
;	- hurts Mario and kills many sprites
;	- can break nearby shatter blocks

; $1540,X	=	explosion timer
; $1570,X	=	animation frame counter


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
	LDA #$F8 : STA $7FB600,X : STA $7FB630,X		; sprite hitbox x offset for interaction with Mario and other sprites
	LDA #$FE : STA $7FB60C,X : STA $7FB63C,X		; sprite hitbox y offset for interaction with Mario and other sprites
	LDA #$21 : STA $7FB618,X : STA $7FB648,X		; sprite hitbox width for interaction with Mario and other sprites
	LDA #$1C : STA $7FB624,X : STA $7FB654,X		; sprite hitbox height for interaction with Mario and other sprites
	
	LDA #$30					; set the explosion timer (vanilla = #$40)
	STA $1540,X
	
	JSR CheckShatterBlocks		; check for shattering shatter blocks
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


; NORMAL STATUS
SpriteCode:
	LDA $9D						; if the game is frozen...
	BNE .gfx
	LDA $14C8,X					; or the sprite is dead, only draw graphics
	CMP #$08
	BNE .gfx
	
	LDA $1540,X					; if the explosion timer is at 0, erase the sprite
	BNE +
	STZ $14C8,X
	BRA .return
	+
	
	INC $1570,X					; increment the animation frame counter
	LDA $1570,X					; if the animation frame counter is now 12...
	CMP #$0C
	BCC +
	STZ $1570,X					; set it back to 0
	+
	
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.gfx
	JSR Graphics

.return
	RTS


ExplosionTileX:												; (sets of 5 tiles)		(left, bottom left, top, bottom right, right   -   left, top left, bottom, top right, right)
	db $FC,$FF,$04,$09,$0C,		$FC,$FF,$04,$09,$0C			; narrow spacing		-	narrow spacing flipped
	db $F8,$FD,$04,$0B,$10,		$F8,$FD,$04,$0B,$10			; medium spacing		-	medium spacing flipped
	db $F4,$FA,$04,$0E,$14,		$F4,$FA,$04,$0E,$14			; wide spacing			-	wide spacing flipped
ExplosionTileY:
	db $02,$0A,$FC,$0A,$02,		$06,$FE,$0C,$FE,$06
	db $01,$0D,$F8,$0D,$01,		$07,$FB,$10,$FB,$07
	db $00,$10,$F4,$10,$00,		$08,$F8,$14,$F8,$08


ExplosionTileCoorIndex:
	db $00,$00,$0F,$0F,$14,$14,$05,$05,$0A,$0A,$19,$19
TilePalette:
	db %00000101,%00000111,%00001001,%00001011

Graphics:	
	%GetDrawInfo()					; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	PHX
	
	LDA $1570,X						; load the animation frame index based on the animation frame counter
	TAX
	LDA ExplosionTileCoorIndex,X
	STA $02
	
	LDX #$04						; load loop counter (5 tiles)

.tileloop
	PHX
	TXA
	CLC : ADC $02
	TAX
	
	LDA $00							; tile x position based on the explosion tile coordinate index
	CLC : ADC ExplosionTileX,X
	STA $0300,Y
	
	LDA $01							; tile y position based on the explosion tile coordinate index
	CLC : ADC ExplosionTileY,X
	STA $0301,Y
	
	LDA #$BC						; tile ID
	STA $0302,Y
	
	LDA $13							; tile YXPPCCCT properties; store the palette based on the frame counter (different palette every 4 frames)
	AND #%00001100
	LSR #2
	TAX
	
	LDA TilePalette,X
	ORA $64
	STA $0303,Y
	
	PLX
	
	INY #4							; increment OAM index
	DEX								; decrement the loop counter and loop to draw another tile if the loop counter is still positive
	BPL .tileloop
	
	PLX
	LDA #$04						; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$00 = all 8x8 tiles)
	LDY #$00
	JSL $01B7B3
	RTS


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
	LDA $167A,Y					; if the indexed sprite is set to not die by an explosion, return
	AND #%00000010
	BNE .return
	
	LDA #$02					; set the indexed sprite's status to killed
	STA $14C8,Y
	LDA #$00					; give the indexed sprite 0 x speed
	STA $B6,Y
	LDA #$C0					; give the indexed sprite upward y speed
	STA $AA,Y

.return
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $1490					; if Mario has star power, return
	BNE .return
	
	LDA $154C,X					; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; if not spinning or on Yoshi, branch to HitEnemy
	ORA $187A
	BEQ HitEnemy
	
	LDA #$02					; play contact sfx
	STA $1DF9
	%BounceMario()				; spin-bounce off the sprite
	RTS


HitEnemy:		%HandleHurtMario() : RTS


ShatterCheckPointX:
	dw $FFF8,$0008,$0018,$FFF8,$0008,$0018,$FFF8,$0008,$0018
ShatterCheckPointY:
	dw $FFF8,$FFF8,$FFF8,$0008,$0008,$0008,$0018,$0018,$0018

CheckShatterBlocks:
	LDY #$10							; load [number of points to check for shatter blocks - 1] x2 as the index

.checkloop
	LDA $14E0,X							; load the sprite's x
	XBA
	LDA $E4,X
	REP #$20
	CLC : ADC ShatterCheckPointX,Y		; add the x offset based on the index
	STA $9A								; store it to the block interaction point x
	SEP #$20
	
	LDA $14D4,X							; load the sprite's y
	XBA
	LDA $D8,X
	REP #$20
	CLC : ADC ShatterCheckPointY,Y		; add the y offset based on the index
	STA $98								; store it to the block interaction point y
	SEP #$20
	
	PHX
	PHY
	JSR HandleShatterPoint
	PLY
	PLX
	
	DEY #2								; decrement the index twice
	BPL .checkloop						; if the index is still positive, loop to check another point
	RTS


HandleShatterPoint:
	STZ $1933					; if the Map16 tile is 292 (cracked block)...
	%GetMap16()
	REP #$20
	CMP #$0292
	BNE .return
	SEP #$20
	
	LDA #$02    				; generate non-solid tile
	STA $9C
	STZ $1933					; layer 1
	JSL $00BEB0
	
	PHB							; spawn shatter pieces
	LDA #$02
	PHA
	PLB
	LDA #$00
	JSL $028663
	PLB

.return
	SEP #$20
	RTS