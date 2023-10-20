; cloud platform sprite, screenwraps both horizontally and vertically
; requires preventducking.asm (Asar patch)

!yspeedaccel	=	$03			; vertical speed acceleration when pressing up or down
!yspeedlimit	=	$30			; vertical speed limit for the platform


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
	LDA #$03 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario (1-tile falling platform = #$01)
	LDA #$00 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario (1-tile falling platform = #$00)
	LDA #$09 : STA $7FB618,X	; sprite hitbox width for interaction with Mario (1-tile falling platform = #$0D)
	LDA #$14 : STA $7FB624,X	; sprite hitbox height for interaction with Mario (1-tile falling platform = #$14)
	
	%RaiseSprite1Pixel()
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D								; return if the game is frozen
	BNE .return
	
	%SubOffScreen()						; call offscreen despawning routine
	JSR HandleMarioContact

.return
	RTS


HandleMarioContact:
	%CheckSpriteMarioContact()			; if Mario is not interacting with the sprite, branch
	BCC HandleOffPlatform
	
	%SemiSolidSprite_MarioContact()		; handle custom semi-solid block interaction for Mario
	BCC HandleOffPlatform				; branch based on whether Mario is standing on the platform
	BRA HandleOnPlatform
	RTS


HandleOffPlatform:
	STZ $18B7					; reset the 'on a cloud platform' flag
	JSR HandleScreenWrap
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	RTS


HandleOnPlatform:
	LDA #$01					; set the 'on a cloud platform' flag (checked by preventducking.asm to prevent ducking)
	STA $18B7
	
	LDA $94						; set the platform's x equal to Mario's x
	STA $E4,X
	LDA $95
	STA $14E0,X
	
	LDA $7B						; set the platform's x speed equal to Mario's x speed (the platform's x position is only updated from this when Mario is not on the platform)
	STA $B6,X
	
	LDA $15						; if holding up...
	AND #%00001000
	BEQ +
	LDA #!yspeedlimit			; store the negative speed limit into scratch ram
	EOR #$FF
	INC #2
	STA $00
	LDA $AA,X					; if the platform's y speed is not negative and below the speed limit...
	BPL ++
	CMP $00
	BCC .yspeedupdated
	++
	SEC : SBC #!yspeedaccel		; decrease the platform's y speed
	STA $AA,X
	BRA .yspeedupdated
	+
	
	LDA $15						; else, if holding down...
	AND #%00000100
	BEQ +
	LDA $AA,X					; if the platform's y speed is not positive and above the speed limit...
	BMI ++
	CMP #!yspeedlimit
	BCS .yspeedupdated
	++
	CLC : ADC #!yspeedaccel		; increase the platform's y speed
	STA $AA,X
	BRA .yspeedupdated
	+
	
	LDA $AA,X					; else (neutral d-pad), if the platform's y speed is not 0...
	BEQ .yspeedupdated
	BMI +						; and it's positive, decrease it
	SEC : SBC #!yspeedaccel
	STA $AA,X
	BRA .yspeedupdated
	+
	CLC : ADC #!yspeedaccel		; else (it's negative), increase it
	STA $AA,X

.yspeedupdated
	LDA $AA,X					; if the platform is moving upward...
	BPL +
	LDA $77						; and Mario is blocked by a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the platform's y speed to 0
	+
	
	JSL $01801A					; update y position (no gravity)
	
	LDA $14D4,X					; set Mario's y equal to the platform's y minus 31
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC #$001F
	STA $96
	SEP #$20
	
	RTS


HandleScreenWrap:
	LDA $E4,X					; store the x position to scratch ram
	STA $00
	LDA $14E0,X
	STA $01
	LDA $D8,X					; store the y position to scratch ram
	STA $02
	LDA $14D4,X
	STA $03
	
	REP #$20
	
	LDA $00						; if the cloud goes offscreen on the left...
	SEC : SBC $1A
	SBC #$FFF0
	BPL +
	LDA $00						; warp it to the right
	CLC : ADC #$0110
	BRA .storewarpx
	+
	
	LDA $00						; else, if the cloud goes offscreen on the right...
	SEC : SBC $1A
	SBC #$0100
	BMI +
	LDA $00						; warp it to the left
	SEC : SBC #$0110
	BRA .storewarpx
	+
	
	BRA .donewarpx

.storewarpx
	SEP #$20
	STA $E4,X
	XBA
	STA $14E0,X
	REP #$20

.donewarpx
	LDA $02						; if the cloud goes offscreen on the top...
	SEC : SBC $1C
	SBC #$FFF0
	BPL +
	LDA $02						; warp it to the bottom
	CLC : ADC #$00F0
	BRA .storewarpy
	+
	
	LDA $02						; else, if the cloud goes offscreen on the bottom...
	SEC : SBC $1C
	SBC #$00E0
	BMI +
	LDA $02						; warp it to the top
	SEC : SBC #$00F0
	BRA .storewarpy
	+
	
	SEP #$20
	BRA .return

.storewarpy
	SEP #$20
	STA $D8,X
	XBA
	STA $14D4,X

.return
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	LDA #$80					; tile ID
	STA $0302,Y
	
	LDA #%00001011				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS