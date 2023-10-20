; falling platform sprite
; the first extension byte sets the width
; the second extension byte sets the x speed

; $1528,X	=	how many pixels the sprite has moved horizontally per frame

!InitFallSpeed		=	#$02	; initial falling speed (vanilla = #$03)
!WaitTime			=	#$08	; number of frames to have the initial falling speed until accelerating (vanilla = #$18)
!FallAccel			=	#$03	; fall acceleration (vanilla = #$02)
!MaxFallSpeed		=	#$40	; max falling speed


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
	LDA #$01 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (vanilla flying item block = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (vanilla flying item block = #$FE)
	LDA #$14 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (vanilla flying item block = #$16)
	
	%RaiseSprite1Pixel()
	
	LDA $7FAB40,X				; set the sprite's hitbox width based on the first extension byte (#$0D + #$10 for each extra tile)
	ASL #4
	CLC : ADC #$0D
	STA $7FB618,X
	
	LDA $7FAB4C,X				; set the x speed based on the second extension byte
	STA $B6,X
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D								; return if the game is frozen
	BNE .return
	
	%SubOffScreen()						; call offscreen despawning routine
	JSL $018022							; update x position (no gravity)
	LDA $1491							; store the number of pixels the sprite has moved into $1528,X
	STA $1528,X
	
	LDA $AA,X							; if the platform isn't falling yet, don't update the y position
	BEQ .checkfalling
	
	LDA $1540,X							; if Mario just landed on the platform, don't accelerate it
	BNE .yspeedloaded
	
	LDA $AA,X							; if at or above max falling speed...
	CMP !MaxFallSpeed
	BMI +
	LDA !MaxFallSpeed					; cap the falling speed at max
	STA $AA,X
	BRA .yspeedloaded
	+
	CLC : ADC !FallAccel				; else, increase the platform's y speed
	STA $AA,X

.yspeedloaded
	JSL $01801A							; update y position (no gravity)

.checkfalling
	JSR HandleMarioContact

.return
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()			; if Mario is interacting with the sprite, handle interaction
	BCC .return
	
	%SemiSolidSprite_MarioContact()		; handle custom semi-solid block interaction with Mario
	BCC .return
	
	LDA $AA,X							; if the platform is not already falling, initiate falling
	BNE .return
	
	LDA !InitFallSpeed					; set initial y speed
	STA $AA,X
	
	LDA !WaitTime						; set timer to wait before accelerating
	STA $1540,X

.return
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	PHX
	LDA $7FAB40,X				; store the number of tiles to scratch ram
	STA $02
	TAX							; ...and load it as the loop counter

.tileloop
	TXA							; tile x offset = loop counter x16
	ASL #4
	CLC : ADC $00
	STA $0300,Y
	
	LDA $01						; tile y offset
	STA $0301,Y
	
	LDA $02						; if the number of tiles to draw is only 1, load tile CC
	BNE +
	LDA #$CC
	BRA .tileidloaded
	+
	CPX #$00					; if the loop counter is 0, load tile C8
	BNE +
	LDA #$C8
	BRA .tileidloaded
	+
	CPX $02						; else, if the loop counter is equal to the number of tiles to draw, load tile CA
	BNE +
	LDA #$CA
	BRA .tileidloaded
	+
	LDA #$C9					; else, load tile C9

.tileidloaded
	STA $0302,Y
	
	LDA #%00000010				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size of 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	INY #4						; increment Y (the OAM index) by 4
	DEX							; decrement the loop counter and draw another tile if the loop counter is still positive
	BPL .tileloop
	
	PLX
	LDA #$04					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS