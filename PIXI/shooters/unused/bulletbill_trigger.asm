; this shooter sprite will shoot a bullet bill when a shooter switch is hit
; the extension byte's 4th bit determines the bullet bill type (0 = vanilla, 1 = explosive)
; the extension byte's final 2 bits determine the direction (0 = right, 1 = left, 2 = up, 3 = down)
;
; code by Katun24

print "INIT ",pc
	RTL

print "MAIN ",pc
	PHB
	PHK
	PLB
	JSR MainCode
	PLB
	RTL


MainCode:
	LDA $17A3,X					; return if horizontally offscreen 3 tiles or more
	XBA
	LDA $179B,X
	REP #$20
	SEC : SBC $1A
	SBC #$FFC0
	BMI .return
	CMP #$0170
	BPL .return
	SEP #$20
	
	LDA $7C						; if the shooter cooldown timer is not 8 (first frame), return
	CMP #$08
	BNE .return
	
	JSR ShootBulletBill
	%SpawnShooterSmoke_Custom()

.return
	SEP #$20
	RTS


ShootBulletBill:
	LDA #$1C					; find an available sprite slot for the bullet bill to spawn in and return if no sprite slot was available
	%SpawnSprite_Custom()		;	input:		A = sprite ID
	TYA							;	output:		Y = sprite slot (#$FF if no free sprite slots)
	BMI .return
	
	LDA #$09					; play the shot sfx
	STA $1DFC
	
	LDA #$08					; set bullet bill's sprite status to normal
	STA $14C8,Y
	
	LDA $7FAC00,X				; if the shooter is set to spawn the red custom bullet bill, set the property byte to mark this
	AND #%00010000
	BEQ +
	LDA #$08
	STA $166E,Y
	+
	
	LDA $179B,X					; position the bullet bill at the same x as the shooter
	STA $E4,Y
	LDA $17A3,X
	STA $14E0,Y
	
	LDA $178B,X					; position the bullet bill 1 pixel above the shooter
	SEC : SBC #$01
	STA $D8,Y
	LDA $1793,X
	STA $14D4,Y
	
	LDA $7FAC00,X				; set the bullet bill's face direction to the one specified by the first extension byte and store it to scratch RAM
	AND #%00000011
	STA $C2,Y
	STA $00
	RTS