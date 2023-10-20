; flying lotus enemy that hurts Mario, but other sprites can bounce off of it; it can float in place, or move linearly based on the extension bytes
; the first extension byte sets the x speed
; the second extension byte sets the y speed

print "INIT ",pc
	INC $1570,X				; set the hitbox correction flag so the custom Yoshi sprite changes its hitbox when colliding with the lotus
	LDA $7FAB40,X			; set x speed based on the value in the first extension byte
	STA $B6,X
	LDA $7FAB4C,X			; set y speed based on the value in the second extension byte
	STA $AA,X
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL

print "MOUTH ",pc
	LDA #$25				; change the sprite ID to a non-flying bounce lotus (no need to reload sprite tables here)
	STA $7FAB9E,X
	RTL


SpriteCode:
	JSR Graphics
	
	LDA $9D					; return if the game is frozen
	BNE .return
	LDA $14C8,X				; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSL $018022				; update x position (no gravity)
	JSL $01801A				; update y position (no gravity)
	
	LDA $15D0,X				; if the lotus is on Yoshi's tongue, return
	BNE .return

; hurt Mario when in contact
	JSL $01A7DC				; process interaction with Mario; if in contact...
	BCC +
	LDA $187A				; and not on Yoshi (Yoshi will take care of damage-boosting in his own code)...
	BNE +
	JSL $00F5B7				; hurt Mario
	+

; bounce sprites up when they're in contact with the lotus
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	LDA $9E,Y				; if the indexed sprite is a custom Yoshi...
	CMP #$69
	BNE +
	LDA $C2,Y				; and the Yoshi is not being ridden...
	CMP #$01
	BEQ +
	LDA $163E,Y				; and the Yoshi is not set to not interact with other sprites...
	BNE +
	JSR SpriteContact		; check for contact with it
	+
	
	LDA $14C8,Y				; else, if the indexed sprite is in carryable or kicked state...
	CMP #$09
	BCC .loopcontinue
	CMP #$0B
	BCS .loopcontinue
	
	JSR SpriteContact		; check for contact with it

.loopcontinue				; else, check the next sprite
	DEY
	BPL .loopstart

.return
	RTS


SpriteContact:
	JSL $03B6E5				; get the lotus sprite's clipping values
	PHX
	TYX
	JSL $03B69F				; get the indexed sprite's clipping values
	PLX
	
	LDA $9E,Y				; if the indexed sprite is a custom Yoshi, subtract 8 pixels from the hitbox height
	CMP #$69
	BNE +
	LDA $07
	SEC : SBC #$08
	STA $07
	+
	
	JSL $03B72B				; if not in contact, return
	BCC .return
	
	LDA #$B0				; else, bounce the sprite up
	STA $AA,Y
	
	JSL $01AB6F				; display contact star at the lotus sprite's position
	
	LDA #$02				; play hit sfx
	STA $1DF9

.return
	RTS


LeavesTileXOffset:
	db $F8,$08
LeavesTileProp:
	db %00100001,%01100001
BulbTileProp:
	db %00101101,%00101001
WingTiles:
	db $5D,$C6,$5D,$C6
WingSize:
	db $00,$02,$00,$02
WingXDisp:
	db $FB,$F3,$0D,$0D
WingYDisp:
	db $02,$FA,$02,$FA
WingProps:
	db $76,$76,$36,$36

Graphics:
	%GetDrawInfo()					; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $14C8,X						; set scratch ram that contains information on whether the sprite is alive
	EOR #$08
	STA $03
	
	PHX

; LEAVES GRAPHICS
	LDX #$01						; load loop counter (2 leaves tiles)

.leavestileloop
	LDA $00							; tile x position
	CLC : ADC LeavesTileXOffset,X	; add the offset
	STA $0300,Y
	
	LDA $01							; tile y position
	STA $0301,Y
	
	LDA #$C0						; tile ID
	STA $0302,Y
	
	LDA LeavesTileProp,X			; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY								; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	INY #4							; increment OAM index
	
	DEX								; decrement the loop counter and loop to draw another leaves tile if the loop counter is still positive
	BPL .leavestileloop


; BULB GRAPHICS
	LDA $00							; tile x position
	STA $0300,Y
	
	LDA $01							; tile y position
	STA $0301,Y
	
	LDA #$C2						; tile ID
	STA $0302,Y
	
	LDA $14							; change tile ID every 4 frames
	AND #%00000100
	LSR #2
	TAX
	LDA BulbTileProp,X				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	PHY								; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY


; WINGS GRAPHICS
	LDA $03						; if the sprite is dead, don't animate the wings
	BNE .NoWingsAnimation
	LDA $14						; otherwise, load the frame counter

.NoWingsAnimation
	LSR #3						; store the wings animation frame into scratch ram (2 animation frames of 8 frames each)
	AND #$01
	STA $02
	
	LDX #$01					; use X for the loop counter - X is set to #$01 since there are 2 wing tiles

.WingsLoop
	INY #4						; increment Y (the OAM index) by 4
	
	PHX
	TXA							; load the loop counter, multiply it by 2, add the animation frame (0 or 1), and store it to X
	ASL
	CLC : ADC $02
	TAX
	
	LDA $00						; offset the wing tile's x position from the sprite's x depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingXDisp,X
	STA $0300,Y
	
	LDA $01						; offset the wing tile's y position from the sprite's y depending on the wing tile and animation frame, and store it to OAM
	CLC : ADC WingYDisp,X
	STA $0301,Y
	
	LDA WingTiles,X				; store tilemap number (see Map8 in LM) based on the wing tile and animation frame to OAM
	STA $0302,Y
	
	LDA $64						; store the priority and other properties to OAM
	ORA WingProps,X
	STA $0303,Y
	
	PHY							; set the tile size depending on the animation frame (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA WingSize,X
	STA $0460,Y
	PLY
	
	PLX
	
	DEX							; decrement the loop counter and loop to draw the second wing tile if the loop counter is still positive
	BPL .WingsLoop


; GRAPHICS END-ROUTINE
	PLX
	LDA #$04						; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS