; disco shell with vanilla behavior

WallBumpSpeed:
	db $E0,$20

print "INIT ",pc
	LDA #$0A					; set sprite status as 'kicked' (like vanilla disco shells)
	STA $14C8,X
	INC $187B,X					; set disco shell flag (the interaction routine checks for this so Mario bounces off)
	RTL

print "KICKED ",pc
	PHB
	PHK
	PLB
	JSR KickedCode
	PLB
	RTL


KickedCode:
	JSR Graphics				; process graphics
	
	LDA $14C8,X					; return if not in an 'alive' status or animations are locked
	CMP #$08
	BCC .return
	LDA $9D
	BNE .return
	
	%SubHorzPos()				; compare the sprite's horizontal position to Mario's (output to Y) and store it to the sprite's face direction
	TYA
	STA $157C,X
	
	JSR PositionInteraction
	
	LDA $1588,X					; if touching a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; give the disco shell 0 y speed
	LDA $D8,X					; position the disco shell below the ceiling tile
	AND #%11110000
	ORA #%00001110
	STA $D8,X
	+
	
	LDA $B6,X					; load the sprite's x speed into A
	LDY $157C,X					; load the sprite's face direction into Y
	BNE .MoveLeft				; if facing left, go to .MoveLeft
	CMP #$20					; otherwise, if the x speed is below the max speed, increase the x speed by 2
	BPL .DontSetHorizSpeed
	INC $B6,X
	INC $B6,X
	BRA .DontSetHorizSpeed

.MoveLeft
	CMP #$E0					; if the x speed is above the min speed, decrease the x speed by 2
	BMI .DontSetHorizSpeed
	DEC $B6,X
	DEC $B6,X

.DontSetHorizSpeed
	LDA $1588,X					; if a solid tile is hit from the side...
	AND #%00000011
	BEQ .NoHorizWall
	PHA							; process interaction with the solid tile
	JSR BlockInteraction
	PLA
	DEC							; and set the shell's x speed (bumping off the solid tile) based on its direction
	TAY
	LDA WallBumpSpeed,Y
	STA $B6,X

.NoHorizWall
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
	ORA #%10000000				; apply y-flip
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
	JSL $01B7B3
	RTS


BlockInteraction:
	LDA #$01					; play the bonk sound effect
	STA $1DF9
	
	LDA $15A0,X					; if the shell's x position (left edge) is offscreen, don't process block interaction
	BNE .NoBlockHit
	
	LDA $E4,X					; if the shell's right edge is offscreen, don't process block interaction
	SEC : SBC $1A
	CLC : ADC #$14
	CMP #$1C
	BCC .NoBlockHit
	
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


YSpeedLimit:
	db $C0,$F0
GravIncr:
	db $03,$01

PositionInteraction:
	JSL $01801A					; update y position
	
	LDY #$00					; if the disco shell is in a liquid...
	LDA $164A,X
	BEQ +
	INY
	LDA $AA,X					; and it's moving upward...
	BMI +
	CMP #$18					; limit its y speed to 18
	BCS +
	LDA #$18
	STA $AA,X
	+
	
	LDA $AA,X					; apply upside-down gravity
	SEC : SBC GravIncr,Y
	STA $AA,X
	BPL +
	CMP YSpeedLimit,Y			; limit the upward y speed to 40 (air) or 10 (liquid)
	BCS +
	LDA YSpeedLimit,Y
	STA $AA,X
	+
	
	LDA $B6,X					;$01905D	|\ 
	PHA							;$01905F	||
	LDY $164A,X					;$019060	||
	BEQ +						;$019063	||
	ASL							;$019065	||
	ROR $B6,X					;$019066	||
	LDA $B6,X					;$019068	||
	PHA							;$01906A	|| If the sprite is in water, slow it down to 3/4s of its normal speed.
	STA $00						;$01906B	||
	ASL							;$01906D	||
	ROR $00						;$01906E	||
	PLA							;$019070	||
	CLC							;$019071	||
	ADC $00						;$019072	||
	STA $B6,X					;$019074	|/
	+
	
	JSL $018022					; update x position
	PLA							;$019079	|
	STA $B6,X					;$01907A	|
	
	JSL $019138					; process object interaction
	RTS