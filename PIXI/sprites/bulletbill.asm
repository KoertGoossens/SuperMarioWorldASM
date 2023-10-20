; bullet bill
; the extension byte sets the direction

; $1540,X	=	timer to draw behind foreground (set when spawned)
; $157C,X	=	direction:	0 = right		1 = left			2 = up			3 = down
;							4 = up-right	5 = down-right		6 = down-left	7 = up-left


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
	LDA #$10					; draw the bullet bill behind the foreground (e.g. a turret tile) for 16 frames
	STA $1540,X
	
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA $7FAB40,X				; set the direction based on the extension byte
	STA $157C,X
	
	%RaiseSprite1Pixel()
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


XSpeed:
	db $20,$E0,$00,$00,$18,$18,$E8,$E8
YSpeed:
	db $00,$00,$E0,$20,$E8,$18,$18,$E8

SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $157C,X					; store the x and y speeds based on the direction
	TAY
	LDA XSpeed,Y
	STA $B6,X
	LDA YSpeed,Y
	STA $AA,X
	
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleMarioContact

.return
	RTS


TileMap:
	db $A6,$A6,$A8,$A8,$AA,$AC,$AC,$AA
TileProp:
	db #%00000010,#%01000010,#%00000010,#%10000010,#%00000010,#%01000010,#%00000010,#%01000010

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $157C,X					; load the direction
	TAY
	LDA TileProp,Y				; store the tile properties (based on the direction) to scratch ram
	STA $02
	LDA TileMap,Y				; store the tile ID based on the direction
	PLY
	STA $0302,Y
	
	LDA $02						; load tile YXPPCCCT properties from scratch ram
	
	PHY
	LDY $14C8,X					; flip y if the sprite is dead
	CPY #$08
	BCS +
	EOR #%10000000
	+
	
	LDY $1540,X					; if the timer to draw the sprite behind the foreground is set...
	BEQ +
	ORA #%00010000				; draw the sprite behind the foreground
	BRA .oampriorityset
	+
	ORA $64						; else, load the standard sprite priority

.oampriorityset
	PLY
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()	; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	LDA $1490					; if Mario has star power, kill the sprite
	BNE StarKillSprite
	
	LDA $154C,X					; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR NormalInteraction

.return
	RTS


StarKillSprite:		%SlideStarKillSprite() : RTS


NormalInteraction:
	%CheckBounceMario()			; if Mario is not positioned to bounce off the sprite, branch to HitEnemy
	BCC HitEnemy
	
	LDA $140D					; else if not spinjumping...
	ORA $187A					; and not riding Yoshi...
	BEQ BounceMarioNormal		; bounce off the sprite
	
	%SpinKillSprite()			; else, spinkill it
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


BounceMarioNormal:
	%HandleBounceCounter()
	%BounceMario()				; have Mario bounce up
	
	LDA #$02					; set the sprite status to killed
	STA $14C8,X
	RTS