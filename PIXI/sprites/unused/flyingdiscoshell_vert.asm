; vertically flying disco shell (no gravity) with animated wings; it tracks Mario's vertical position

!MaxDownSpeed = $20
!MaxUpSpeed = $E0

WallBumpSpeed_Vert:
	db !MaxUpSpeed,!MaxDownSpeed

print "INIT ",pc
	LDA #$0A					; set sprite status as 'kicked' (like vanilla disco shells)
	STA $14C8,X
	INC $187B,X					; set disco shell flag (the interaction routine checks for this so Mario bounces off)
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR Code
	PLB
	RTL

Code:
	JSR Graphics				; process graphics
	
	LDA $14C8,X					; return if not in an 'alive' status or animations are locked
	CMP #$08
	BCC .return
	LDA $9D
	BNE .return
	
	LDY #$00					; compare the sprite's vertical position to Mario's and store it to $1534,X
	LDA $14D4,X
	XBA
	LDA $D8,X
	REP #$20
	SEC : SBC $96
	SBC #$0010
	BMI +
	INY
	+
	SEP #$20
	TYA
	STA $1534,X
	
	LDA $AA,X					; load the sprite's y speed into A
	LDY $1534,X					; load the sprite's vertical direction towards Mario into Y
	BNE .MoveUp					; if below Mario, go to .MoveUp
	CMP #!MaxDownSpeed			; otherwise, if the y speed is below the max speed, increase the y speed by 2
	BPL .DontSetVertSpeed
	INC $AA,X
	INC $AA,X
	BRA .DontSetVertSpeed

.MoveUp
	CMP #!MaxUpSpeed			; if the y speed is above the min speed, decrease the y speed by 2
	BMI .DontSetVertSpeed
	DEC $AA,X
	DEC $AA,X

.DontSetVertSpeed
	JSL $01801A					; update sprite's vertical position without applying gravity
	JSL $019138					; process interaction with blocks
	
	LDA $1588,X					; if a solid tile is hit from the top or bottom...
	AND #%00001100
	BEQ .NoVertWall
	PHA							; process interaction with the solid tile
	JSR BlockInteraction
	PLA
	LSR #2						; and set the shell's y speed (bumping off the solid tile) based on its direction
	DEC
	TAY
	LDA WallBumpSpeed_Vert,Y
	STA $AA,X

.NoVertWall
	LDA $13						; change palette every other frame
	AND #$01
	BNE .NoPaletteChange
	LDA $15F6,X
	INC #2
	AND #$CF
	STA $15F6,X

.NoPaletteChange
	JSL $01803A					; handle interaction with Mario and sprites

.return
	%SubOffScreen()				; call offscreen despawning routine
	RTS


Tilemap:
	db $8C,$8A,$8E,$8A
XFlip:
	db $00,$00,$00,$40			; only the last byte is flip for one of shell's frames
WingTiles:
	db $5D,$C6,$5D,$C6
XDisp:
	db $04,$00,$FC,$00
YDisp:
	db $F1,$00,$F0,$00
WingSize:
	db $00,$02,$00,$02
WingXDisp:
	db $FB,$F3,$0D,$0D
WingYDisp:
	db $FF,$F7,$FF,$F7
WingProps:
	db $76,$76,$36,$36

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $14C8,X					; set scratch ram that contains information on whether the sprite is dead (not in kicked status)
	EOR #$0A
	STA $03

; SHELL GRAPHICS
	LDA $00						; store the shell tile's x position to OAM
	STA $0300,Y
	
	LDA $01						; store the shell tile's y position to OAM
	STA $0301,Y
	
	PHY
	LDA $03						; if the sprite is dead, don't animate the shell
	BNE .NoShellAnimation
	LDA $14						; otherwise, load the frame counter

.NoShellAnimation
	LSR #2						; store the shell animation frame into Y (4 animation frames of 4 frames each)
	AND #$03
	TAY
	LDA XFlip,Y					; store x-flip based on the animation frame into scratch ram
	STA $02
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	LDA $02						; store the x-flip, the CFG parameters, and the priority to OAM
	ORA $15F6,X
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
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

.Loop
	INY #4						; increment Y (the OAM index) by 4
	
	PHX							; load the loop counter, multiply it by 2, add the animation frame (0 or 1), and store it to X
	TXA
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
	BPL .Loop
	
	LDX $15E9					; restore the sprite slot into X
	
	LDA #$02					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


BlockInteraction:
	LDA #$01					; play the bonk sound effect
	STA $1DF9
	
;	LDA $15A0,X					; if the shell's x position (left edge) is offscreen, don't process block interaction
;	BNE .NoBlockHit
	
;	LDA $E4,X					; if the shell's right edge is offscreen, don't process block interaction
;	SEC : SBC $1A
;	CLC : ADC #$14
;	CMP #$1C
;	BCC .NoBlockHit
	
	LDA $1588,X					; store the layer being processed (layer 1 or 2)
	AND #%01000000
	ASL #2
	ROL
	AND #$01
	STA $1933
	
	LDY #$00					; run the block code (input: Y = direction from which the block is hit; A = Map16 number)
	LDA $18A7
	JSL $00F160
	
	LDA #$05					; set timer to prevent being hit by a block's quake sprite
	STA $1FE2,X

.NoBlockHit
	RTS