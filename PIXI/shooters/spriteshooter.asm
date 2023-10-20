; this shooter sprite will shoot other sprites
; the first extension byte sets the type:
;	+80		=	only shoot when a shooter switch is hit (00), or shoot periodically (80)
;	+40		=	only shoot if the on/off state is on
;	+20		=	only shoot if the on/off state is off
;	+00-03	=	direction (0 = right, 1 = left, 2 = up, 3 = down)
; the second extension byte holds the number of frames to wait between each shot (if the shots are periodical)
; the third extension byte holds the sprite ID


print "INIT ",pc
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR MainCode
	PLB
	RTL


SpriteType:
	db $03,$03,$02,$02,$03,$03,$02,$02,$03,$03,$03,$02,$01,$03,$02,$02		; 0 = dino, 1 = mole, 2 = p-switch, 3 = goomba, 4 = taptap, 5 = flying spiny, 6 = spring, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $03,$00,$03,$03,$03,$03,$03,$00,$03,$03,$03,$03,$03,$00,$00,$00		; 10 = flying dino, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1A = flying taptap, 1B = flying milde, 1C = mushroom
	db $00,$03,$03,$00,$03,$02,$03,$00,$02,$00,$02,$02,$00,$00,$00,$00		; 21 = buster beetle, 22 = buzzy beetle, 24 = Yoshi, 25 = baby Yoshi, 26 = chuckoomba, 28 = carry block, 2A = magnet block, 2B = surfboard
	db $00,$00,$00,$03,$03,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 33 = chomp, 34 = ninji, 35 = spiny
	db $00,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; 41 = shooter item
	db $02,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00		; 50 = bounce ball
	db $03,$03,$03,$03,$03,$03,$00,$00,$00,$00,$03,$03,$00,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = switch block, 65 = cloud, 6A = walking block, 6B = walking cloud
	db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

MainCode:
	LDA $17A3,X						; return if horizontally offscreen 3 tiles or more
	XBA
	LDA $179B,X
	REP #$20
	SEC : SBC $1A
	SBC #$FFC0
	BMI .return
	CMP #$0170
	BPL .return
	SEP #$20
	
	LDA $7FAC00,X					; if the shooter is set to only shoot when a shooter switch is hit...
	AND #%10000000
	BNE +
	LDA $7C							; if the shooter cooldown timer is 8 (first frame), shoot the item; otherwise return
	CMP #$08
	BEQ .shoot
	BRA .return
	+
	
	LDA $7FAC00,X					; else (no shooter switch trigger) if the shooter is set to only shoot when the on/off state is on, return if it's off
	AND #%01000000
	BEQ +
	LDA $14AF
	BEQ +
	STZ $17AB,X
	BRA .return
	+
	
	LDA $7FAC00,X					; else, if the shooter is set to only shoot when the on/off state is off, return if it's on
	AND #%00100000
	BEQ +
	LDA $14AF
	BNE +
	STZ $17AB,X
	BRA .return
	+
	
	LDA $17AB,X						; else, if the shooter timer (decrements every 2 frames) is 0, shoot a sprite
	BNE .return
	
	LDA $7FAC08,X					; set the shooter timer back to the value specified by the second extension byte
	STA $17AB,X

.shoot
	LDA $7FAC00,X					; spawn smoke based on the spawned sprite's face direction
	AND #%00000011
	STA $00
	JSR SpawnShooterSmoke
	
	LDA #$09						; play the shot sfx
	STA $1DFC
	
	LDA $7FAC10,X					; spawn the sprite with the ID based on the third extension byte
	%SpawnCustomSprite()
	
	PHY								; store the sprite type to scratch ram based on the third extension byte
	LDA $7FAC10,X
	TAY
	LDA SpriteType,Y
	STA $0F
	PLY
	
	LDA $0F							; point to different routines based on the sprite type
	JSL $0086DF
		dw .return
		dw BulletBill
		dw ItemSprite
		dw WalkingSprite
	
.return
	SEP #$20
	RTS


BulletBill:
	LDA $179B,X					; position the bullet bill at the same x as the shooter
	STA $E4,Y
	LDA $17A3,X
	STA $14E0,Y
	
	LDA $178B,X					; position the bullet bill at the same y as the shooter
	STA $D8,Y
	LDA $1793,X
	STA $14D4,Y
	
	LDA $7FAC00,X				; store the bullet bill's direction based on the extension byte
	AND #%00000011
	PHX
	TYX
	STA $7FAB40,X
	PLX
	RTS


ItemXSpeed:
	db $30,$D0,$00,$00
ItemYSpeed:
	db $00,$00,$B0,$50

ItemSprite:
	JSR OffsetPosition
	
	PHX
	LDA $7FAC00,X				; set the item's x and y speeds based on the direction
	AND #%00000011
	TAX
	LDA ItemXSpeed,X
	STA $B6,Y
	LDA ItemYSpeed,X
	STA $AA,Y
	PLX
	
	LDA #$0A					; store the item sprite's status to set in init as 'kicked'
	STA $1594,Y
	RTS


WalkingXSpeed:
	db $30,$D0,$00,$00

WalkingSprite:
	JSR OffsetPosition
	
	PHX
	LDA $7FAC00,X				; set the spawned sprite's x speed based on the direction
	AND #%00000011
	TAX
	LDA WalkingXSpeed,X
	PHY
	TYX
	STA $7FAB40,X
	PLY
	PLX
	RTS


XOffset:
	dw $000C,$FFF4,$0000,$0000
YOffset:
	dw $FFFF,$FFFF,$FFF4,$000A

OffsetPosition:
	PHX
	LDA $7FAC00,X				; store the x and y spawn offsets based on the direction to scratch RAM
	AND #%00000011
	ASL
	TAX
	REP #$20
	LDA XOffset,X
	STA $00
	LDA YOffset,X
	STA $02
	SEP #$20
	PLX
	
	LDA $17A3,X					; offset the item's x from the shooter's x based on the direction
	XBA
	LDA $179B,X
	REP #$20
	CLC : ADC $00
	SEP #$20
	STA $E4,Y
	XBA
	STA $14E0,Y
	
	LDA $1793,X					; offset the item's y from the shooter's y based on the direction
	XBA
	LDA $178B,X
	REP #$20
	CLC : ADC $02
	SEP #$20
	STA $D8,Y
	XBA
	STA $14D4,Y
	RTS


SmokeXOffset:
	db $0C,$F4,$00,$00,$0C,$0C,$F4,$F4
SmokeYOffset:
	db $00,$00,$F4,$0C,$F4,$0C,$0C,$F4

SpawnShooterSmoke:
	LDA $17A3,X					; return if horizontally offscreen (don't generate smoke)
	XBA
	LDA $179B,X
	REP #$20
	SEC : SBC $1A
	CMP #$00F0
	SEP #$20
	BCS .return
	
	LDY $00						; store the x and y offsets of the smoke into scratch RAM, based on the direction of the shooter
	LDA SmokeXOffset,Y
	STA $01
	LDA SmokeYOffset,Y
	STA $02
	
	LDY #$03					; find a free slot (4 slots available for smoke)

.loop
	LDA $17C0,Y
	BEQ +
	DEY
	BPL .loop
	RTL
	+
	
	LDA #$01					; set effect type (1 = smoke)
	STA $17C0,Y
	
	LDA #$1B					; set timer to show smoke
	STA $17CC,Y
	
	LDA $179B,X					; store the shooter sprite's x (low byte) + offset into the smoke's x (low byte)
	CLC : ADC $01
	STA $17C8,Y
	
	LDA $178B,X					; store the shooter sprite's y (low byte) + offset into the smoke's y (low byte)
	CLC : ADC $02
	STA $17C4,Y

.return
	RTS