; parabeetle that can fly horizontally; when Mario stands on it, it can move vertically
; the first extension byte sets the direction
; the second extension byte sets the x speed

; $C2,X		=	stored x position (low byte)
; $1504,X	=	'standing on sprite' flag
; $151C,X	=	stored x position (high byte)
; $1528,X	=	how many pixels the sprite has moved horizontally per frame
; $1534,X	=	width (minus 16)
; $154C,X	=	timer to disable contact with Mario
; $1570,X	=	height (minus 16)
; $157C,X	=	face direction
; $1594,X	=	stored y position (low byte)
; $160E,X	=	stored y position (high byte)
; $1626,X	=	animation frame counter

!MaxDownSpeed			= #$30			; y speed to give the parabeetle when Mario lands on it
!MaxUpSpeed				= #$E0			; maximum upward speed when Mario is on the parabeetle
!UpwardAccel			= #$02			; upward acceleration value when Mario is on the parabeetle
!NeutralYSpeedDecel		= #$02			; y speed deceleration value when Mario is not on the parabeetle


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
	
	STZ $1534,X					; set the width (16 pixels)
	STZ $1570,X					; set the height (16 pixels)
	
	LDA $7FAB40,X				; set direction based on the value in the first extension byte
	STA $157C,X
	
	LDA #$03 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$0A : STA $7FB618,X	; sprite hitbox width for interaction with Mario (vanilla flying item block = #$0D)
	LDA #$0D : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$FE : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0C : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
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
	
	LDA $E4,X					; store the sprite's coordinates (checked for interaction with other sprites)
	STA $C2,X
	LDA $14E0,X
	STA $151C,X
	LDA $D8,X
	STA $1594,X
	LDA $14D4,X
	STA $160E,X
	
	INC $1626,X					; increment the animation frame counter
	
	LDA $1504,X					; if the 'standing on sprite' flag is set...
	BEQ +
	INC $1626,X					; increment the animation frame counter again (animation twice as fast)
	
	LDA $AA,X					; if the y speed is below the maximum...
	BPL ++
	CMP !MaxUpSpeed
	BCC .yspeedset
	++
	SEC : SBC !UpwardAccel		; decrease it by a specified amount
	STA $AA,X
	BRA .yspeedset
	+
	
	LDA $AA,X					; else (Mario is not on the parabeetle), increase or decrease the y speed towards 0
	BEQ .yspeedset
	BPL +
	CLC : ADC !NeutralYSpeedDecel
	BRA .decelyspeed
	+
	SEC : SBC !NeutralYSpeedDecel

.decelyspeed
	STA $AA,X

.yspeedset
	%SubOffScreen()				; call offscreen despawning routine
	
	LDA $7FAB4C,X
	LDY $157C,X
	BEQ +
	EOR #$FF
	INC A
	+
	STA $B6,X
	
	JSL $018022					; update x position (no gravity)
	LDA $1491					; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	JSL $01801A					; update y position (no gravity)
	
	JSR HandleMarioContact

.return
	RTS


HandleMarioContact:
	STZ $1504,X							; clear the 'standing on sprite' flag
	
	%CheckSpriteMarioContact()			; if Mario is not interacting with the sprite, return
	BCC .return
	
	%SemiSolidSprite_MarioContact()		; handle custom semi-solid block interaction with Mario
	BCC +								; if standing on the sprite...
	LDA $154C,X							; if the sprite does not have the 'disable contact with Mario' timer set yet...
	BNE ++
	LDA !MaxDownSpeed					; give the sprite downward speed
	STA $AA,X
	STA $7D								; give Mario the same downward speed
	++
	
	LDA #$04							; disable interaction with Mario for 4 frames (to prevent getting hit right as you jump off)
	STA $154C,X
	
	LDA #$01							; set the 'standing on sprite' flag
	STA $1504,X
	RTS
	+
	
	LDA $1490							; if Mario has star power, kill the sprite
	BEQ +
	%SlideStarKillSprite()
	RTS
	+
	
	LDA $154C,X							; else, if the sprite has the 'disable contact with Mario' timer set, don't interact
	BNE .return
	
	JSR HitEnemy						; else, interact with the sprite

.return
	RTS


HitEnemy:	%HandleSlideHurt() : RTS


TileMap:
	db $80,$82

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY
	LDA $1626,X					; store tile ID based on the animation frame (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	TAY
	LDA TileMap,Y
	PLY
	STA $0302,Y
	
	LDA #%00101001				; tile YXPPCCCT properties
	PHY
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	LDY $14C8,X					; flip y if the sprite is dead
	CPY #$08
	BCS +
	EOR #%10000000
	+
	
	PLY
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS


HandleYSpeed:
	LDA $AA,X					; if the y speed is below the maximum...
	BPL ++
	CMP !MaxUpSpeed
	BCC .return
	++
	SEC : SBC !UpwardAccel		; decrease it by a specified amount
	STA $AA,X
	BRA .return
	+
	
	LDA $AA,X					; else (Mario is not on the parabeetle), increase or decrease the y speed towards 0
	BEQ .return
	BPL +
	CLC : ADC !NeutralYSpeedDecel
	BRA .decelyspeed
	+
	SEC : SBC !NeutralYSpeedDecel

.decelyspeed
	STA $AA,X

.return
	RTS