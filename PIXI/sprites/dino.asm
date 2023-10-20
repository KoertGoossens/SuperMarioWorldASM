; dino sprite that can wear a shell and can be jumped off to kill it, after which the shell can be grabbed
; the first extension byte sets the x speed
; the second extension byte sets the shellmet type:
;	- first 3 bits:				=	shell type
;	- bit 8:			+80		=	spawn with shell flag

; $151C,X	=	wearing shell flag
; $154C,X	=	timer to disable contact with Mario
; $1564,X	=	timer to disable contact with other sprites
; $1570,X	=	animation frame counter
; $157C,X	=	face direction
; $1594,X	=	shell type
; $15AC,X	=	timer to disable interaction with blocks (when spawned from a block)


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
	LDA #$02 : STA $7FB600,X	; sprite hitbox x offset for interaction with Mario
	LDA #$03 : STA $7FB60C,X	; sprite hitbox y offset for interaction with Mario
	LDA #$0C : STA $7FB618,X	; sprite hitbox width for interaction with Mario
	LDA #$0A : STA $7FB624,X	; sprite hitbox height for interaction with Mario
	
	LDA #$00 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$02 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$0F : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$0B : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	LDA $7FAB4C,X				; set shell wearing flag if the 1st bit in the second extension byte is set
	AND #%10000000
	BEQ +
	INC $151C,X
	+
	
	LDA $7FAB4C,X				; store the shell type to a normal sprite-indexed address
	AND #%00000111
	STA $1594,X
	
	LDA $151C,X					; if wearing a shell, make it so the sprite stays in Yoshi's mouth
	BEQ +
	LDA #%00000010
	STA $1686,X
	+
	
	%SubHorzPos()				; set the sprite to face Mario
	TYA
	STA $157C,X
	
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
	
	LDA $B6,X					; if the x speed is not 0...
	BEQ +
	INC $1570,X					; increment the animation frame counter
	+
	
	%SubOffScreen()				; call offscreen despawning routine
	JSR HandleSpeed
	JSR HandleGravity
	%ProcessBlockInteraction()
	JSR HandleSpriteInteraction
	JSR HandleMarioContact

.return
	RTS


HandleGravity:		%ApplyGravity() : RTS


HandleSpeed:
	LDA $15AC,X					; if set to interact with blocks...
	BNE .skipblockcheck
	
	LDA $1588,X					; if the sprite touches the side of a block...
	AND #%00000011
	BEQ +
	LDA $157C,X					; invert the face direction
	EOR #$01
	STA $157C,X
	+
	
	LDA $1588,X					; if the sprite touches a ceiling...
	AND #%00001000
	BEQ +
	STZ $AA,X					; set the y speed to 0
	+
	
	%HandleFloor()

.skipblockcheck
	LDA $7FAB40,X				; set the x speed based on the first extension byte
	PHY
	LDY $157C,X					; invert the x speed based on the face direction
	BEQ +
	EOR #$FF
	INC A
	+
	PLY
	STA $B6,X
	
	LDA $1588,X					; if the sprite is in the air...
	AND #%00000100
	BNE +
	STZ $1570,X					; set the animation frame counter to 0
	+
	
	RTS


Tilemap:
	db $84,$86
ShellTilePalette:
	db %00001010,%00001100,%00000010,%00000100

Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01

; dino tile
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	PHY	
	LDA $1570,X					; store the animation frame into Y (2 animation frames of 8 frames each)
	LSR #3
	AND #%00000001
	TAY
	LDA Tilemap,Y				; store tilemap number (see Map8 in LM) based on the animation frame to OAM
	PLY
	STA $0302,Y
	
	PHY
	LDA #%00100000				; tile YXPPCCCT properties
	
	LDY $157C,X					; flip x based on face direction
	BNE +
	EOR #%01000000
	+
	
	PLY
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

; shell tile
	LDA $151C,X					; if the sprite is not wearing a shell, don't draw it
	BEQ .noshellgfx
	
	INY #4
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	CLC : ADC #$FC
	STA $0301,Y
	
	LDA #$A0					; tile ID
	STA $0302,Y
	
	PHY
	
	LDA $1594,X					; if it's a disco shell...
	AND #%00000100
	BEQ .nodisco
	
	LDA $13						; cycle through the palettes every other frame
	AND #%00001110
	BRA .propertiesloaded

.nodisco
	LDA $1594,X					; else, have the shell type determine the palette
	AND #%00000011
	TAY
	LDA ShellTilePalette,Y		; tile YXPPCCCT properties
	
	LDY $157C,X					; flip x based on face direction
	BNE .propertiesloaded
	EOR #%01000000

.propertiesloaded
	PLY
	ORA #%00100000
	ORA $64
	STA $0303,Y
	
	PHY							; set the tile size to 16x16 (divide Y (the OAM index) by 4 to index it for $0460)
	TYA
	LSR #2
	TAY
	LDA #$02
	STA $0460,Y
	PLY

.noshellgfx
	LDX $15E9					; restore the sprite slot into X
	LDA #$01					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$FF = variable tile size)
	LDY #$FF
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
	
	JSR CheckTakeShell
	RTS


CheckTakeShell:
	LDA $151C,X					; if the dino is wearing a shell...
	BEQ .return
	LDA $15						; and the player is holding Y/X...
	AND #%01000000
	BEQ .return
	LDA $1470					; and not already carrying something...
	ORA $148F
	ORA $187A					; and not on Yoshi, spawn a shell for Mario to carry and set the bounced-off flag to 2
	BNE .return
	
	LDA #$0F					; shell (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA #$0B					; store the sprite status to set in init for the spawned shell as 'carried'
	STA $1594,Y
	
	LDA $1594,X					; store the dino's shell type to the spawned shell's shell type
	PHX
	TYX
	STA $7FAB40,X
	PLX
	
	LDA #$08					; set the grab animation frames
	STA $1498
	
	LDA #$08					; disable contact with other sprites for 8 frames (to prevent clashing with the shell you just grabbed)
	STA $1564,X
	
	STZ $151C,X					; set the shell-wearing flag back to 0

.return
	RTS


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the calling sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	LDA $1686,Y				; if the indexed sprite doesn't interact with other sprites...
	AND #%00001000
	ORA $1564,X				; or the calling sprite has the 'disable contact with other sprites' timer set...
	ORA $1564,Y				; or the indexed sprite has the 'disable contact with other sprites' timer set...
	ORA $15D0,Y				; or the indexed sprite is on Yoshi's tongue...
	ORA $1632,X				; or the calling sprite isn't on the same 'layer' as the indexed sprite (i.e. behind net)...
	EOR $1632,Y
	BNE .loopcontinue		; don't check for contact
	
	JSR CheckSpriteContact	; check for contact with the indexed sprite

.loopcontinue				; else, check the next sprite
	DEY
	BPL .loopstart

.return
	RTS


CheckSpriteContact:
	%CheckSpriteSpriteContact()				; if the sprite is in contact with the indexed sprite, handle interaction
	BCC .return
	JSR SpriteContact

.return
	RTS


SpriteContact:
	%CheckSolidSprite()			; branch if the indexed sprite is solid
	BNE Cnt_SolidSprite
	
	PHX							; if the indexed sprite is a shell...
	TYX
	LDA $7FAB9E,X
	PLX
	CMP #$0F
	BNE +
	LDA $14C8,Y					; and it's not in carried status...
	CMP #$0B
	BEQ +
	LDA $151C,X					; and the dino is not already wearing a shell...
	BEQ SetCarryShell			; set the shell on top of the dino
	+
	
	LDA $14C8,Y
	CMP #$08					; else, if the indexed sprite is also in normal status...
	BEQ DoBumpSprites			; turn both sprites around (for indexed sprites in item statuses, the indexed sprite should initiate the contact check)
	
	RTS


DoBumpSprites:			%BumpSprites() : RTS
Cnt_SolidSprite:		%SolidSpriteInteraction_Standard() : RTS


SetCarryShell:
	LDA #$02					; play contact sfx
	STA $1DF9
	
	INC $151C,X					; set the wearing shell flag
	
	PHX							; set the dino's shell type
	TYX
	LDA $7FAB40,X
	PLX
	STA $1594,X
	
	LDA #$00					; erase the shell sprite
	STA $14C8,Y
	RTS