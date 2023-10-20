; sprite that can warp other sprites to another instance of this sprite
; the first extension byte sets the x speed
; the second extension byte sets the y speed
; the third extension byte sets the polarity (0 or 1, for another warp sprite to check where to warp)

; $1564,X	=	timer to disable contact with other sprites


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
	LDA $7FAB40,X				; set the x speed based on the first extension byte
	STA $B6,X
	LDA $7FAB4C,X				; set the y speed based on the second extension byte
	STA $AA,X
	
	LDA #$06 : STA $7FB630,X	; sprite hitbox x offset for interaction with other sprites
	LDA #$06 : STA $7FB63C,X	; sprite hitbox y offset for interaction with other sprites
	LDA #$03 : STA $7FB648,X	; sprite hitbox width for interaction with other sprites
	LDA #$03 : STA $7FB654,X	; sprite hitbox height for interaction with other sprites
	
	%RaiseSprite1Pixel()
	
	LDA $7FAB58,X				; store the sprite slot to freeram; the freeram address depends on the third extension byte
	TAY
	TXA
	STA $1869,Y
	
	LDA #$08					; set the sprite status to normal and run the normal code
	STA $14C8,X
	BRA SpriteCode


SpriteCode:
	JSR Graphics
	
	LDA $9D						; return if the game is frozen
	BNE .return
	LDA $14C8,X					; branch if the sprite is dead
	CMP #$08
	BNE .return
	
	%SubOffScreen()				; call offscreen despawning routine
	JSL $018022					; update x position (no gravity)
	JSL $01801A					; update y position (no gravity)
	JSR HandleSpriteInteraction

.return
	RTS


HandleSpriteInteraction:
	LDY #$0B				; load highest sprite slot for loop

.loopstart
	STY $00					; if the index is the same as the item sprite ID, don't check for contact
	CPX $00
	BEQ .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in an alive status, don't check for contact
	CMP #$08
	BCC .loopcontinue
	
	LDA $14C8,Y				; if the indexed sprite is not in carried status, don't check for contact
	CMP #$0B
	BEQ .loopcontinue
	
	LDA $1686,Y				; if the indexed sprite doesn't interact with other sprites...
	AND #%00001000
	ORA $1564,X				; or the item sprite has the 'disable contact with other sprites' timer set...
	ORA $1564,Y				; or the indexed sprite has the 'disable contact with other sprites' timer set...
	ORA $15D0,Y				; or the indexed sprite is on Yoshi's tongue...
	ORA $1632,X				; or the item sprite isn't on the same 'layer' as the indexed sprite (i.e. behind net)...
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


SpriteContactType:
	db $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01		; 0 = dino, 1 = mole, 2 = p-switch, 3 = goomba, 4 = taptap, 5 = flying spiny, 6 = spring, 7 = bob-omb, 8 = shyguy, 9 = floppy fish, A = beezo, B = shloomba, C = bullet bill, D = milde, E = throwblock, F = shell
	db $01,$00,$01,$01,$01,$01,$01,$00,$01,$01,$01,$01,$01,$01,$00,$00		; 10 = flying dino, 11 = flying coin, 12 = flying buzzy beetle, 13 = flying throwblock, 14 = flying shell, 15 = flying bob-omb, 16 = flying goomba, 18 = flying shyguy, 19 = flying floppy fish, 1A = flying taptap, 1B = flying milde, 1C = mushroom, 1D = tallguy
	db $01,$01,$01,$00,$01,$01,$01,$00,$01,$00,$01,$01,$00,$00,$00,$00		; 20 = sparky, 21 = buster beetle, 22 = buzzy beetle, 24 = Yoshi, 25 = baby Yoshi, 26 = chuckoomba, 28 = carry block, 2A = magnet block, 2B = surfboard
	db $00,$00,$01,$01,$01,$01,$00,$01,$01,$00,$00,$00,$01,$01,$00,$00		; 32 = parabeetle, 33 = chomp, 34 = ninji, 35 = spiny, 37 = piranha plant, 38 = boost bubble, 39 = bouncingrock, 3C = vine koopa, 3D = fuzzy
	db $00,$01,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00		; 41 = shooter item, 48 = flame
	db $01,$01,$01,$01,$01,$01,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00		; 50 = bounce ball, 51 = thwimp, 52 = goldthwimp, 53 = boomerang, 54 = polarity block, 55 = arrow block, 58 = parachute dino, 59 = parachute spiny, 5A = parachute shell
	db $01,$01,$01,$01,$01,$01,$00,$00,$01,$00,$01,$01,$01,$00,$00,$00		; 60 = solid block, 61 = death block, 62 = throwblock block, 63 = item block, 64 = switch block, 65 = cloud, 66 = used block, 68 = eating block, 6A = walking block, 6B = walking cloud, 6C = walking p-switch
	db $01,$01,$01,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00		; 70 = big block, 71 = big death block, 72 = big throwblock block, 78 = sticky block

SpriteContact:
	PHX							; if the contact sprite is set to interact with the warp sprite...
	TYX
	LDA $7FAB9E,X
	PLX
	BEQ .return
	
	LDA #$10					; play warp sfx
	STA $1DF9
	
	PHX
	
	LDA $7FAB58,X				; load the third extension byte (polarity)
	EOR #$01					; invert it and store it as an index
	TAX
	LDA $1869,X					; load the sprite slot of the opposite-polarity warp sprite
	TAX
	
	LDA $E4,X					; copy the position of the opposite-polarity warp sprite to the indexed sprite
	STA $E4,Y
	LDA $14E0,X
	STA $14E0,Y
	LDA $D8,X
	STA $D8,Y
	LDA $14D4,X
	STA $14D4,Y
	
	LDA #$08					; briefly disable contact with other sprites for the opposite-polarity warp sprite
	STA $1564,X
	STZ $01
	STZ $02
	%SpawnSpriteGlitter()
	
	PLX
	
	LDA #$08					; briefly disable contact with other sprites for the warp sprite
	STA $1564,X
	%SpawnSpriteGlitter()

.return
	RTS


Graphics:
	%GetDrawInfo()				; outputs the sprite's OAM index into Y and the sprite's x and y coordinates relative to the screen border into $00 and $01
	
	LDA $00						; tile x position
	STA $0300,Y
	LDA $01						; tile y position
	STA $0301,Y
	
	LDA #$CE					; tile ID
	STA $0302,Y
	
	LDA #%00100001				; tile YXPPCCCT properties
	ORA $64
	STA $0303,Y
	
	LDA #$00					; OAM tiles end-routine (A = number of tiles to draw minus 1; Y = #$02 = all 16x16 tiles)
	LDY #$02
	JSL $01B7B3
	RTS