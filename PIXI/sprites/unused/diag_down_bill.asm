print "INIT ",pc
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR SpriteCode
	PLB
	RTL

SpriteCode:
	LDA $9D					; load sprites/animations locked flag
	BNE .Return				; if set, return

	LDA $14C8,x				; load sprite status
	CMP #$08				; check if default/alive
	BNE .Return				; if not equal, return
	
	%SubOffScreen()				; call offscreen despawning routine
	STZ $00						; x offset of the sprite to spawn
	STZ $01						; y offset of the sprite to spawn
	LDA #$1C					; sprite index number
	CLC							; custom sprite

	%SpawnSprite()				; input:	A = sprite index number
								; 			C = normal/custom sprite (CLC = normal sprite; SEC = custom sprite)
								; 			$00 = x offset
								; 			$01 = y offset
								; 			$02 = x speed
								; 			$03 = y speed
								; output:	Y = index to spawned sprite (#$FF means no sprite spawned)
								;			C = if carry set, spawn failed; if carry clear = spawn successful

	LDA #$06					; set direction of bill sprite to down-left
	STA $C2,y
	STA $00
	JSR Smoke

	LDA #$09					; play shot sound
	STA $1DFC|!Base2

	STZ $14C8|!Base2,x			; kill mother sprite

.Return
	RTS
	
Smoke:
	LDY #$03                ; \ find a free slot to display effect
.loop
	LDA $17C0|!Base2,y      ;  |
	BEQ +                   ;  |
	DEY                     ;  |
	BPL .loop               ;  |
	RTS                     ; /  RETURN if no slots open

+	LDA #$01                ; \ set effect graphic to smoke graphic
	STA $17C0|!Base2,y      ; /
	LDA #$1B                ; \ set time to show smoke
	STA $17CC|!Base2,y      ; /

	LDA $178B|!Base2,x      ; \ 
	PHX                     ;  |
	LDX $00                 ;  | set smoke y position based on direction of shot
	CLC                     ;  |
	ADC .y_off,x            ;  |
	STA $17C4|!Base2,y      ; /
	PLX

	LDA $179B|!Base2,x      ; \ 
	PHX                     ;  |
	LDX $00                 ;  | set smoke x position based on direction of shot
	CLC                     ;  |
	ADC .x_off,x            ;  |
	STA $17C8|!Base2,y      ; /
	PLX
	RTS                    
						  
.y_off:	db $00,$00,$00,$00,$FA,$04,$04,$FA
.x_off:	db $00,$00,$00,$00,$04,$04,$FA,$FA
