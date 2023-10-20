; lotus enemy that hurts Mario, but other sprites can bounce off of it
;
; $154C,X	=	'disable player contact' timer
; $1570,X	=	hitbox correction flag


print "INIT ",pc
	INC $1570,X				; set the hitbox correction flag so the custom Yoshi sprite changes its hitbox when colliding with the lotus
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL


SpriteCode:
	JSR Graphics
	
	LDA $9D					; return if the game is frozen
	BNE .return
	LDA $14C8,X				; return if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSL $01802A				; update x and y position with gravity, and process interaction with blocks
	
	LDA $15D0,X				; if the lotus is on Yoshi's tongue, return
	BNE .return
	
	LDA $1588,X				; if the lotus is on the ground, handle ground interaction
	AND #%00000100
	BEQ +
	JSR HandleGround
	+
	
	LDA $1588,X				; if the lotus is touching a solid tile on the side...
	AND #%00000011
	BEQ +
	LDA $B6,X				; invert its x speed and divide it by 4
	EOR #$FF
	INC A
	STA $B6,X
	ASL
	PHP
	ROR $B6,X
	PLP
	ROR $B6,X
	LDA #$01				; play hit sfx
	STA $1DF9
	+

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

Graphics:
	%GetDrawInfo()					; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
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

; GRAPHICS END-ROUTINE
	PLX
	LDA #$02						; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


BounceYSpeed:
	db $00,$00,$00,$F8,$F8,$F8,$F8,$F8
	db $F8,$F7,$F6,$F5,$F4,$F3,$F2,$E8
	db $E8,$E8,$E8,$00,$00,$00,$00,$FE
	db $FC,$F8,$EC,$EC,$EC,$E8,$E4,$E0
	db $DC,$D8,$D4,$D0,$CC,$C8

HandleGround:
	LDA $B6,X					; halve the sprite's x speed
	PHP
	BPL +
	EOR #$FF
	INC A
	+
	LSR
	PLP
	BPL +
	EOR #$FF
	INC A
	+
	STA $B6,X
	
	LDA $AA,X					; give the sprite y speed
	LSR #2
	TAY
	LDA $9E,X
	LDA BounceYSpeed,Y
	LDY $1588,X
	BMI .return
	STA $AA,X

.return
	RTS