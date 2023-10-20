Tilemap:
	db $A6,$A4,$A6,$A8
TileProperties:
	db $42,$02,$03,$83,$03,$43,$03,$43
Frames:
	db $00,$00,$01,$01,$02,$03,$03,$02
XSpeed:
	db $20,$E0,$00,$00,$18,$18,$E8,$E8
YSpeed:
	db $00,$00,$E0,$20,$E8,$18,$18,$E8

print "INIT ",pc
	LDA #$07				; direction = up-left
	STA $C2,x
	LDA #$10				; set the "behind screen" timer
	STA $1540,x
	LDA #$09				; play shot sound
	STA $1DFC|!Base2
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR BulletBillMain
	PLB
	RTL

BulletBillMain:
	LDA #$01
	STA $157C,x

	LDA $9D					; load sprites/animations locked flag
	BNE Skip1				; if set, return

	LDA $14C8,x				; load sprite status
	CMP #$08				; check if default/alive
	BNE Skip1				; if not equal, return
	
	%SubOffScreen()				; call offscreen despawning routine
	
	LDY $C2,x	;
	LDA TileProperties,y	; set the tile properties for the GFX routine
	STA $15F6,x	; depending on the sprite state
	LDA Frames,y	; set the frame
	STA $1602,x	; depending on the sprite state
	LDA XSpeed,y	;
	STA $B6,x		; set the X speed
	LDA YSpeed,y	;
	STA $AA,x	; set the Y speed

	JSL $018022	; update sprite X position without gravity
	JSL $01801A	; update sprite Y position without gravity
	JSL $019138	; interact with objects
	JSL $01803A	; interact with the player and with other sprites

Skip1:
	LDA $D8,x	; sprite Y position
	SEC		;
	SBC $1C		; minus vertical screen boundary
	CMP #$F0		; if the sprite has gone too far offscreen...
	BCC NoErase	;
	STZ $14C8,x

NoErase:
	LDA $1540,x	; if the behind-screen timer is set...
	BEQ BulletBillGFX	; put the sprite behind the foreground

	LDA $64		;
	PHA		; preserve the current priority settings
	LDA #$10		;
	STA $64		; and set the priority lower

	JSR BulletBillGFX	; draw the sprite

	PLA		;
	STA $64		; restore the old priority settings

	RTS

BulletBillGFX:
	%GetDrawInfo()

	LDA $157C,x	;
	STA $02		;

	LDA $1602,x	;
	TAX		;
	LDA Tilemap,x	; set the sprite tilemap
	STA $0302,y	;

	LDX $15E9	;
	LDA $00		;
	STA $0300,y	; no X displacement
	LDA $01		;
	STA $0301,y	; no Y displacement

	LDA $157C,x	;
	LSR		; if the sprite is facing right...
	LDA $15F6,x	;
	BCS NoXFlip	; X-flip it
	EOR #$40		;
	NoXFlip:		;
	ORA $64		;
	STA $0303,y	;

	TYA		;
	LSR #2		;
	TAY		;

	LDA #$02		;
	ORA $15A0,x	;
	STA $0460,y	; set the tile size

	PHK		;
	PER $0006	;
	PEA $8020	;
	JML $81A3DF	; set up some stuff in OAM

	RTS