; based on bob-omb disassembly, requires spritestatus09replace.asm, spritestatus0Areplace.asm and spritestatus0Breplace.asm to be patched

print "INIT ",pc			; marks the init of sprite, runs once when initialized
	LDA.b #$FF					;$01855D	| Number of frames to wait before exploding.
	STA.w $1540,X				;$01855F	|
	
	JSR SubHorzPosBnk1			;$01857C	| Make sprite face Mario
	TYA							;$01857F	|
	STA.w $157C,X				;$018580	|
	
	RTL

SubHorzPosBnk1:					;-----------| Subroutine to check horizontal proximity of Mario to a sprite.
	LDY.b #$00					;$01AD30	|  Returns the side in Y (0 = right) and distance in $0F.
	LDA $D1						;$01AD32	|
	SEC							;$01AD34	|
	SBC $E4,X					;$01AD35	|
	STA $0F						;$01AD37	|
	LDA $D2						;$01AD39	|
	SBC.w $14E0,X				;$01AD3B	|
	BPL Return01AD41			;$01AD3E	|
	INY							;$01AD40	|
Return01AD41:					;			|
	RTS							;$01AD41	|


print "MAIN ",pc			; marks the main code that the sprite runs every frame
	PHB						; push data bank into stack to preserve it
	PHK						; push program bank into stack, too
	PLB						; pull back the last saved value from stack (program bank) into data bank
	JSR SpriteCode			; call main sprite code
	PLB						; pull back the original data bank
	RTL

SpriteCode:
		LDA $14C8,x
		CMP #$09
		BNE +
		JSR STATE09
		BRA ReturnSpriteCode

		+
		LDA $14C8,x
		CMP #$0A
		BNE +
		JSR STATE0A
		BRA ReturnSpriteCode

		+
		LDA $14C8,x
		CMP #$0B
		BNE ReturnSpriteCode
		JSR STATE0B

; main (sprite state 08)
	LDA.w $1534,X				;$018AE5	|\ If exploding, use the subroutine for that instead.
	BNE ExplodeBomb				;$018AE8	|/
	LDA.w $1540,X				;$018AEA	|\ If not exploding yet and hasn't finished counting down the stun timer, run the general sprite code.
	BNE Spr0to13Start			;$018AED	|/
	LDA.b #$09					;$018AEF	|\ Else, stop it and make it carryable when it's about to explode.
	STA.w $14C8,X				;$018AF1	|/  (relevant code at $019624)
	LDA.b #$40					;$018AF4	|\ Stun the Bob-omb and set immediately set to flash.
	STA.w $1540,X				;$018AF6	|/
	JSL $0190B2					;$018AF9	| Draw a 1-tile 16x16 sprite.

	ReturnSpriteCode:
		RTS


ExplodeBomb:					;-----------| Bob-omb explosion subroutine.
	PHB							;$018ADA	|
	LDA.b #$02					;$018ADB	|
	PHA							;$018ADD	|
	PLB							;$018ADE	|
	JSL $028086					;$018ADF	| Routine to handle the Bob-omb's explosion.
	PLB							;$018AE3	|
	RTS							;$018AE4	|

Spr0to13Start:					;-----------| Starting MAIN for: All normal Koopas, Yellow Winged Koopas, Bob-ombs, Goombas, Buzzy Beetles, and Spinies.
	LDA $9D						;$018AFC	|\ If the game is not frozen, branch to the MAIN.
	BEQ Spr0to13Main			;$018AFE	|/
CODE_018B00:					;			|
	JSL $01A7DC					;$018B00	| Process standard Mario-Sprite interaction.
CODE_018B03:					;			|
	JSL $018032					;$018B03	| Process interaction with other sprites.
	JSR Spr0to13Gfx				;$018B06	| Draw graphics.
	RTS							;$018B09	|

Spr0to13SpeedX:					;$0188EC	| X speeds for sprites 00-13. First two are when the "move fast" bit below is clear; second two are when set.
	db $08,$F8,$0C,$F4

Spr0to13Main:					;-----------| Shared routine for most sprites 0 to 13.
	JSR IsOnGround				;$018B0A	|\ Branch if the sprite is not on ground.
	BEQ CODE_018B2E				;$018B0D	|/
	LDA #$05
	LSR							;$018B14	||
	LDY.w $157C,X				;$018B15	||
	BCC CODE_018B1C				;$018B18	||
	INY							;$018B1A	||
	INY							;$018B1B	||
CODE_018B1C:					;			|| Set the sprite's X speed, depending on the type of slope it's standing on.
	LDA.w Spr0to13SpeedX,Y		;$018B1C	|| If the corresponding property bit is set, the sprite will move a bit faster.
	EOR.w $15B8,X				;$018B1F	||
	ASL							;$018B22	||
	LDA.w Spr0to13SpeedX,Y		;$018B23	||
	BCC CODE_018B2C				;$018B26	||
	CLC							;$018B28	||
	ADC.w $15B8,X				;$018B29	||
CODE_018B2C:					;			||
	STA $B6,X					;$018B2C	|/
CODE_018B2E:					;			|
	LDY.w $157C,X				;$018B2E	|\ 
	TYA							;$018B31	||
	INC A						;$018B32	||
	AND.w $1588,X				;$018B33	|| If the sprite walks into the side of a block, stop it.
	AND.b #$03					;$018B36	||
	BEQ CODE_018B3C				;$018B38	||
	STZ $B6,X					;$018B3A	|/
CODE_018B3C:					;			|
	JSR IsTouchingCeiling		;$018B3C	|\ 
	BEQ CODE_018B43				;$018B3F	|| If the sprite is touching a ceiling, zero its Y speed.
	STZ $AA,X					;$018B41	|/
CODE_018B43:					;```````````| Primary code for handling most sprites in 00-13.
	JSR SubOffscreen0Bnk1		;$018B43	| Erase if offscreen.
	JSL $01802A					;$018B46	| Update X/Y position, apply gravity, and process interaction with blocks.
	JSR SetAnimationFrame		;$018B49	| Handle 2-frame animation.
	JSR IsOnGround				;$018B4C	|\ If the sprite is not on the ground, branch.
	BEQ SpriteInAir				;$018B4F	|/
SpriteOnGround:					;			|
	JSR SetSomeYSpeed			;$018B51	| Set the sprite's ground Y speed (#$00 or #$18 depending on flat or slope).
	STZ.w $151C,X				;$018B54	| For sprites that stay on ledges: you're currently on a ledge.
	LDA #$05
	PHA							;$018B5C	|| Follow Mario if set to do so.
	AND.b #$04					;$018B5D	||  Don't turn if not time to or already facing Mario.
	BEQ DontFollowMario			;$018B5F	||
	LDA.w $1570,X				;$018B61	||
	AND.b #$7F					;$018B64	||| How often to poll for Mario's direction.
	BNE DontFollowMario			;$018B66	||
	LDA.w $157C,X				;$018B68	||
	PHA							;$018B6B	||
	JSR FaceMario				;$018B6C	||
	PLA							;$018B6F	||
	CMP.w $157C,X				;$018B70	||
	BEQ DontFollowMario			;$018B73	||
	LDA.b #$08					;$018B75	||\ Turn around.
	STA.w $15AC,X				;$018B77	|//
DontFollowMario:				;			|
	PLA							;$018B7A	|\ 
	AND.b #$08					;$018B7B	|| If the sprite is set to jump over shells (yellow Koopas), run the code for that.
	BEQ CODE_018B82				;$018B7D	||
;	JSR JumpOverShells			;$018B7F	|/
CODE_018B82:					;			|
	BRA CODE_018BB0				;$018B82	|

SetAnimationFrame:				;-----------| Subroutine to make 2-frame animations for sprites every 8 frames.
	INC.w $1570,X				;$01835F	|
	LDA.w $1570,X				;$018E62	|
	LSR							;$018E65	|
	LSR							;$018E66	|
	LSR							;$018E67	|
	AND.b #$01					;$018E68	|
	STA.w $1602,X				;$018E6A	|
	RTS							;$018E6D	|

SpriteOffScreen1:				;$01AC0D	| Low bytes of the vertical offscreen processing distances.
	db $40,$B0

SpriteOffScreen2:				;$01AC0F	| High bytes of the vertical offscreen processing distances.
	db $01,$FF

SpriteOffScreen3:				;$01AC11	| Low bytes of the horizontal offscreen processing distances.
	db $30,$C0,$A0,$C0,$A0,$F0,$60,$90

SpriteOffScreen4:				;$01AC19	| High bytes of the horizontal offscreen processing distances.
	db $01,$FF,$01,$FF,$01,$FF,$01,$FF

SubOffscreen0Bnk1:				;-----------| SubOffscreenX0 routine. Processes sprites offscreen from -$40 to +$30 ($0130,$FFC0).
	STZ $03						;$01AC30	|
CODE_01AC33:					;			|
	JSR IsSprOffScreen			;$91AC33	|\ Return if not offscreen.
	BEQ Return01ACA4			;$01AC36	|/
	LDA $5B						;$01AC38	|\ 
	AND.b #$01					;$01AC3A	|| Branch if in a vertical level.
	BNE OffscreenVertBnk1		;$01AC3C	|/
	LDA $D8,X					;$01AC3E	|\ 
	CLC							;$01AC40	||
	ADC.b #$50					;$01AC41	|| Erase the sprite if below the level.
	LDA.w $14D4,X				;$01AC43	||
	ADC.b #$00					;$01AC46	||
	CMP.b #$02					;$01AC48	||
	BPL OffScrEraseSprite		;$01AC4A	|/
	LDA.w $167A,X				;$01AC4C	|\ 
	AND.b #$04					;$01AC4F	|| Return if set to process offscreen.
	BNE Return01ACA4			;$01AC51	|/
	LDA $13						;$01AC53	|\ 
	AND.b #$01					;$01AC55	||
	ORA $03						;$01AC57	||
	STA $01						;$01AC59	||
	TAY							;$01AC5B	||
	LDA $1A						;$01AC5C	||
	CLC							;$01AC5E	||
	ADC.w SpriteOffScreen3,Y	;$01AC5F	||
	ROL $00						;$01AC62	||
	CMP $E4,X					;$01AC64	|| Check if within the horizontal bounds specified by the routine call. Alternates sides each frame.
	PHP							;$01AC66	||  If it is within the bounds (i.e. onscreen), return.
	LDA $1B						;$01AC67	||
	LSR $00						;$01AC69	||
	ADC.w SpriteOffScreen4,Y	;$01AC6B	||
	PLP							;$01AC6E	||
	SBC.w $14E0,X				;$01AC6F	||
	STA $00						;$01AC72	||
	LSR $01						;$01AC74	||
	BCC CODE_01AC7C				;$01AC76	||
	EOR.b #$80					;$01AC78	||
	STA $00						;$01AC7A	||
CODE_01AC7C:					;			||
	LDA $00						;$01AC7C	||
	BPL Return01ACA4			;$01AC7E	|/
OffScrEraseSprite:				;```````````| Subroutine to erase a sprite when offscreen.
	LDA.w $14C8,X				;$01AC8E	|\ 
	CMP.b #$08					;$01AC91	||
	BCC OffScrKillSprite		;$01AC93	||
	LDY.w $161A,X				;$01AC95	||
	CPY.b #$FF					;$01AC98	|| Erase the sprite.
	BEQ OffScrKillSprite		;$01AC9A	||  If it wasn't killed, set it to respawn.
	LDA.b #$00					;$01AC9C	||
	STA.w $1938,Y				;$01AC9E	||
OffScrKillSprite:				;			||
	STZ.w $14C8,X				;$01ACA1	|/
Return01ACA4:					;			|
	RTS							;$01ACA4	|

IsSprOffScreen:					;-----------| Subroutine to check if a sprite is offscreen, both horizontally and vertically.
	LDA.w $15A0,X				;$0180CB	|
	ORA.w $186C,X				;$0180CE	|
	RTS							;$0180D1	|

OffscreenVertBnk1:				;```````````| Offscreen routine for a vertical level.
	LDA.w $167A,X				;$01ACA5	|\ 
	AND.b #$04					;$01ACA8	|| Return if set to process offscreen.
	BNE Return01ACA4			;$01ACAA	|/
	LDA $13						;$01ACAC	|\ 
	LSR							;$01ACAE	|| Process every other frame.
	BCS Return01ACA4			;$01ACAF	|/
	LDA $E4,X					;$01ACB1	|\ 
	CMP.b #$00					;$01ACB3	||
	LDA.w $14E0,X				;$01ACB5	|| Erase the sprite if of either side of the level.
	SBC.b #$00					;$01ACB8	||
	CMP.b #$02					;$01ACBA	||
	BCS OffScrEraseSprite		;$01ACBC	|/
	LDA $13						;$01ACBE	|\ 
	LSR							;$01ACC0	||
	AND.b #$01					;$01ACC1	||
	STA $01						;$01ACC3	||
	TAY							;$01ACC5	||
	BEQ CODE_01ACD2				;$01ACC6	||
CODE_01ACD2:					;			||
	LDA $1C						;$01ACD2	|| Check if within the vertical bounds of the screen. Alternates sides each frame.
	CLC							;$01ACD4	||  If it is within the bounds (i.e. onscreen), return.
	ADC.w SpriteOffScreen1,Y	;$01ACD5	||
	ROL $00						;$01ACD8	|| Sprite 22 and sprite 24 (green net Koopas) will not despawn off the top of the screen.
	CMP $D8,X					;$01ACDA	||  (was probably intended to sprite 23 instead of 24)
	PHP							;$01ACDC	||
	LDA.w $1D					;$01ACDD	||
	LSR $00						;$01ACE0	||
	ADC.w SpriteOffScreen2,Y	;$01ACE2	||
	PLP							;$01ACE5	||
	SBC.w $14D4,X				;$01ACE6	||
	STA $00						;$01ACE9	||
	LDY $01						;$01ACEB	||
	BEQ CODE_01ACF3				;$01ACED	||
	EOR.b #$80					;$01ACEF	||
	STA $00						;$01ACF1	||
CODE_01ACF3:					;			||
	LDA $00						;$01ACF3	||
	BPL Return01ACA4			;$01ACF5	||
	BMI OffScrEraseSprite		;$01ACF7	|/

FaceMario:						;-----------| Subroutine to make a sprite face Mario.
	JSR SubHorzPosBnk1			;$01857C	|
	TYA							;$01857F	|
	STA.w $157C,X				;$018580	|
Return018583:					;			|
	RTS							;$018583	|

SpriteInAir:
	STZ.w $1570,X				;$018B90	|/
CODE_018BB0:					;			|
	LDA.w $1528,X				;$018BB0	|\ 
	BEQ CODE_018BBA				;$018BB3	||
	JSR CODE_018931				;$018BB5	|| If the sprite is not sliding, process standard interaction with Mario.
	BRA CODE_018BBD				;$018BB8	||  If the sprite is sliding, process the kick-kill interaction with Mario.
CODE_018BBA:					;			||
	JSL $01A7DC					;$018BBA	|/	>> Mario to sprite interaction
CODE_018BBD:					;			|
	JSL $018032					;$018BBD	|\ Process interaction with other sprites; turn around if it hits something.
	JSR FlipIfTouchingObj		;$018BC0	|/
Spr0to13Gfx:					;```````````| Routine to handle graphics for sprites 00-13.
	LDA.w $157C,X				;$018BC3	|
	PHA							;$018BC6	|
	LDY.w $15AC,X				;$018BC7	|\ 
	BEQ CODE_018BDE				;$018BCA	||
	LDA.b #$02					;$018BCC	||
	STA.w $1602,X				;$018BCE	||
	LDA.b #$00					;$018BD1	|| If the sprite's turn timer is non-zero, turn it around.
	CPY.b #$05					;$018BD3	|| The actual turn occurs on frame 3 of the animation.
	BCC CODE_018BD8				;$018BD5	||
	INC A						;$018BD7	||
CODE_018BD8:					;			||
	EOR.w $157C,X				;$018BD8	||
	STA.w $157C,X				;$018BDB	|/
CODE_018BDE:					;			|
	JSL $0190B2					;$018BE7	||	>> draw graphics
	PLA							;$018C13	|
	STA.w $157C,X				;$018C14	|
	RTS							;$018C17	|

CODE_018931:					;```````````| Handle interaction between Mario and a stunned Koopa.
	ASL.w $167A,X				;$01893C	|\ 
	SEC							;$01893F	||
	ROR.w $167A,X				;$018940	||
	JSL $01A7DC					;$018943	|| If not the blue Koopa and in contact with it, kick-kill it.
	BCC CODE_01894B				;$018946	||
	JSR CODE_01B12A				;$018948	||
CODE_01894B:					;			||
	ASL.w $167A,X				;$01894B	||
	LSR.w $167A,X				;$01894E	|/
Return018951:					;			|
	RTS							;$018951	|

CODE_01B12A:					;-----------| Subroutine to handle kicking stunned Koopas/out-of-water fish.
	LDA.b #$10					;$01B12A	| How long to show Mario's "kicked sprite" pose.
	STA.w $149A					;$01B12C	|
	LDA.b #$03					;$01B12F	|\ SFX for kicking the sprite.
	STA.w $1DF9					;$01B131	|/
	JSR SubHorzPosBnk1			;$01B134	|\ 
	LDA.w DATA_01B023,Y			;$01B137	|| Send the sprite flying away from Mario (does not apply to Koopas, which just drop straight down)
	STA $B6,X					;$01B13A	|/
	LDA.b #$E0					;$01B13C	| Speed to send the fish flying
	STA $AA,X					;$01B13E	|
	LDA.b #$02					;$01B140	|\ Kill the sprite.
	STA.w $14C8,X				;$01B142	|/
	STY $76						;$01B145	| Make Mario face the sprite he kicked.
	LDA.b #$01					;$01B147	| Number of points to give Mario for kicking a Koopa/Fish (200).
;	JSL GivePoints				;$01B149	|
	RTS							;$01B14D	|

FlipIfTouchingObj:				;-----------| Subroutine to turn a sprite around if it hits an object.
	LDA.w $157C,X				;$019089	|
	INC A						;$01908C	|
	AND.w $1588,X				;$01908D	|
	AND.b #$03					;$019090	|
	BEQ Return019097			;$019092	|
	JSR FlipSpriteDir			;$019094	|
Return019097:					;			|
	RTS							;$019097	|

FlipSpriteDir:					;-----------| Subroutine to change the direction of a sprite's movement.
	LDA.w $15AC,X				;$019098	|\ If it's already turning, return.
	BNE Return0190B1			;$01909B	|/
	LDA.b #$08					;$01909D	|\ Set the turning timer.
	STA.w $15AC,X				;$01909F	|/
CODE_0190A2:					;			|
	LDA $B6,X					;$0190A2	|\ 
	EOR.b #$FF					;$0190A4	||
	INC A						;$0190A6	||
	STA $B6,X					;$0190A7	|| Invert the sprite's speed.
	LDA.w $157C,X				;$0190A9	||
	EOR.b #$01					;$0190AC	||
	STA.w $157C,X				;$0190AE	|/
Return0190B1:					;			|
	RTS							;$0190B1	|


STATE09:							; state = 'stationary/carryable'
	HandleSprStunned:				;-----------| Routine to handle sprites in the stationary/carryable/stunned state (sprite status 9).
		BRA CODE_01956A				;$019540

	CODE_01956A:					;```````````| Routine for all stunned sprites except springboards and P-balloons.
		LDA $9D						;$01956A	|\ 
		BEQ CODE_019571				;$01956C	|| If sprites are locked, then skip object/sprite/Mario interaction and movement.
		JMP CODE_0195F5				;$01956E	|/

	CODE_019571:
		JSR CODE_019624				;$019571	| Handle stun timer related routines.
		JSL $01802A					;$019574	| Update X/Y position, apply gravity, and process interaction with blocks.
		JSR IsOnGround				;$019577	|\ 
		BEQ CODE_019598				;$01957A	|| If the sprite is on the ground, process ground interaction.
		JSR CODE_0197D5				;$01957C	||
	CODE_01958C:					;			||
		CMP.b #$2C					;$01958C	||\ 
		BNE CODE_019598				;$01958E	||| Initialize the Yoshi egg's hatching sequence when it hits the ground and return it to normal status.
		LDA.b #$F0					;$019590	||| Only applies to ? block eggs, and the speed doesn't actually affect anything.
		STA $AA,X					;$019592	|||
		JSL CODE_01F74C				;$019594	|//
	CODE_019598:					;			|
		JSR IsTouchingCeiling		;$019598	|\ 
		BEQ CODE_0195DB				;$01959B	|| If the sprite hits a ceiling, send it back downwards.
		LDA.b #$10					;$01959D	||
		STA $AA,X					;$01959F	||
		JSR IsTouchingObjSide		;$0195A1	||\ 
		BNE CODE_0195DB				;$0195A4	|||
		LDA $E4,X					;$0195A6	|||
		CLC							;$0195A8	|||
		ADC.b #$08					;$0195A9	|||
		STA $9A						;$0195AB	|||
		LDA.w $14E0,X				;$0195AD	|||
		ADC.b #$00					;$0195B0	|||
		STA $9B						;$0195B2	|||
		LDA $D8,X					;$0195B4	|||
		AND.b #$F0					;$0195B6	|||
		STA $98						;$0195B8	|||
		LDA.w $14D4,X				;$0195BA	||| If the sprite isn't also touching the side of a block, make it interact with the block.
		STA $99						;$0195BD	|||  i.e. this is the code that lets you actually hit a block with a carryable sprite.
		LDA.w $1588,X				;$0195BF	|||
		AND.b #$20					;$0195C2	||| Why it matters that the side isn't being touched, who knows.
		ASL							;$0195C4	|||
		ASL							;$0195C5	|||
		ASL							;$0195C6	|||
		ROL							;$0195C7	|||
		AND.b #$01					;$0195C8	|||
		STA.w $1933					;$0195CA	|||
		LDY.b #$00					;$0195CD	|||
		LDA.w $1868					;$0195CF	|||
		JSL $00F160					;$0195D2	|||
		LDA.b #$08					;$0195D6	|||
		STA.w $1FE2,X				;$0195D8	|//
	CODE_0195DB:					;			|
		JSR IsTouchingObjSide		;$0195DB	|\ 
		BEQ CODE_0195F2				;$0195DE	||
		JSR CODE_01999E				;$0195E6	||/

	CODE_0195F2:					;			|
		JSL $018032					;$018FC1	|	>> handle sprite <> sprite interaction
		JSL $01A7DC					;$018FC4	|	>> handle mario <> sprite interaction
	CODE_0195F5:					;			|
		JSR CODE_01A187				;$0195F5	| Draw graphics, and handle stunned sprite routines.
		JSR SubOffscreen0Bnk1		;$0195F8	| Process offscreen from -$40 to +$30.
		RTS	

	IsTouchingObjSide:				;-----------| Subroutine (JSR) to check if a sprite is touching the sides of a solid block.
		LDA.w $1588,X				;$018008	|
		AND.b #$03					;$01800B	|
		RTS							;$01800D	|

	IsOnGround:						;-----------| Subroutine (JSR) to check if a sprite is touching the top of a solid block.
		LDA.w $1588,X				;$01800E	|
		AND.b #$04					;$018011	|
		RTS							;$018013	|

	IsTouchingCeiling:				;-----------| Subroutine (JSR) to check if a sprite is touching the bottom of a solid block.
		LDA.w $1588,X				;$018014	|
		AND.b #$08					;$018017	|
		RTS							;$018019	|

	CODE_01999E:					;-----------| Subroutine for thrown sprites interacting with the sides of blocks.
		LDA.b #$01					;$01999E	|\ SFX for hitting a block with any sprite.
		STA.w $1DF9					;$0199A0	|/
		JSR CODE_0190A2				;$0199A3	| Invert the sprite's X speed.
		LDA.w $15A0,X				;$0199A6	|\ 
		BNE CODE_0199D2				;$0199A9	||
		LDA $E4,X					;$0199AB	||
		SEC							;$0199AD	||
		SBC $1A						;$0199AE	||
		CLC							;$0199B0	||
		ADC.b #$14					;$0199B1	||
		CMP.b #$1C					;$0199B3	||
		BCC CODE_0199D2				;$0199B5	||
		LDA.w $1588,X				;$0199B7	|| If it's far enough on-screen, make it actually interact with the block.
		AND.b #$40					;$0199BA	||  i.e. this is the code that lets you actually hit a block with a thrown sprite.
		ASL							;$0199BC	||
		ASL							;$0199BD	||
		ROL							;$0199BE	||
		AND.b #$01					;$0199BF	||
		STA.w $1933					;$0199C1	||
		LDY.b #$00					;$0199C4	||
		LDA.w $18A7					;$0199C6	||
		JSL $00F160					;$0199C9	||
		LDA.b #$05					;$0199CD	||
		STA.w $1FE2,X				;$0199CF	|/
	CODE_0199D2:					;			|
		RTS							;$0199DB	|

	DATA_0197AF:					;$0197AF	| Bounce speeds for carryable sprites when hitting the ground. Indexed by Y speed divided by 4.
		db $00,$00,$00,$F8,$F8,$F8,$F8,$F8
		db $F8,$F7,$F6,$F5,$F4,$F3,$F2,$E8
		db $E8,$E8,$E8,$00,$00,$00,$00,$FE		; Goombas in particular use the values starting at the $00s here.
		db $FC,$F8,$EC,$EC,$EC,$E8,$E4,$E0
		db $DC,$D8,$D4,$D0,$CC,$C8

	CODE_0197D5:					;-----------| Subroutine to make carryable sprites bounce when they hit the ground.
		LDA $B6,X					;$0197D5	|\ 
		PHP							;$0197D7	||
		BPL CODE_0197DD				;$0197D8	||
		JSR InvertAccum				;$0197DA	||
	CODE_0197DD:					;			||
		LSR							;$0197DD	|| Halve the sprite's X speed.
		PLP							;$0197DE	||
		BPL CODE_0197E4				;$0197DF	||
		JSR InvertAccum				;$0197E1	||
	CODE_0197E4:					;			||
		STA $B6,X					;$0197E4	|/
		LDA $AA,X					;$0197E6	|\ 
		PHA							;$0197E8	|| Set a normal ground Y speed.
		JSR SetSomeYSpeed			;$0197E9	|/
		PLA							;$0197EC	|
		LSR							;$0197ED	|
		LSR							;$0197EE	|
		TAY							;$0197EF	|
	CODE_0197FB:					;			|
		LDA.w DATA_0197AF,Y			;$0197FB	|\ 
		LDY.w $1588,X				;$0197FE	|| Get the Y speed to make the sprite bounce at when it hits the ground.
		BMI Return019805			;$019801	||
		STA $AA,X					;$019803	|/
	Return019805:					;			|
		RTS							;$019805	|

	InvertAccum:					;-----------| Subroutine (JSR) to invert the accumulator.
		EOR.b #$FF					;$01804A	|
		INC A						;$01804C	|
		RTS							;$01804D	|


STATE0A:							; state = 'kicked/thrown'
	CODE_01991B:
		JSR CODE_01AA0B				;$019922	||
		JMP CODE_01A187				;$019925	|/

	CODE_01AA0B:					;			||  If $C2 is non-zero or the sprite is coming from status 08, then also set the stun timer.
		LDA $C2,X					;$01AA0B	||
		BNE SetStunnedTimer			;$01AA0D	||
		STZ.w $1540,X				;$01AA0F	||
		BRA SetAsStunned			;$01AA12	|/

	SetStunnedTimer:
		LDA.b #$FF					;$01AA28	| How long to stun the bob-omb when kicked/hit.
	CODE_01AA2A:					;			|
		STA.w $1540,X				;$01AA2A	|
	SetAsStunned:					;			|
		LDA.b #$09					;$01AA2D	|\ Change to stationary/carryable status.
		STA.w $14C8,X				;$01AA2F	|/
		RTS							;$01AA32	|

	CODE_01A187:					;-----------| Routine to handle graphics for stunned sprites, as well as basic routines for some sprites.
		BRA StunBomb				;$01A1BA	||
		RTS							;$01A1CF	|

	StunBomb:						;-----------| Stunned Bob-omb GFX subroutine.
		JSL $0190B2					;$01A1EC	| Draw a 16x16 sprite.
		LDA.b #$CA					;$01A1EF	|\\ Tile used for the stunned Bob-omb.
		BRA CODE_01A222				;$01A1F1	|/

	CODE_01A222:					;			||
		LDY.w $15EA,X				;$01A222	||
		STA.w $0302,Y				;$01A225	|/
		RTS							;$01A228	|


STATE0B:							; state = 'carried'
		JSR CODE_019FE0				;$019F71	| Run specific sprite routines.
		LDA.w $13DD					;$019F74	|\ 
		BNE CODE_019F83				;$019F77	||
		LDA.w $1419					;$019F79	||
		BNE CODE_019F83				;$019F7C	|| If turning while sliding, going down a pipe, or otherwise facing the screen,
		LDA.w $1499					;$019F7E	||  center the item on Mario, and change OAM index to #00.
		BEQ CODE_019F86				;$019F81	||  (to make it go in front of Mario).
	CODE_019F83:					;			||
		STZ.w $15EA,X				;$019F83	|/
	CODE_019F86:					;			|
		LDA $64						;$019F86	|\ 
		PHA							;$019F88	||
		LDA.w $1419					;$019F89	|| If going down a pipe, send behind objects.
		BEQ CODE_019F92				;$019F8C	||
		LDA.b #$10					;$019F8E	||
		STA $64						;$019F90	|/
	CODE_019F92:					;			|
		JSR CODE_01A187				;$019F92	| Draw graphics and handle basic routines.
		PLA							;$019F95	|
		STA $64						;$019F96	|
		RTS							;$019F98	|

	CODE_019FE0:					;```````````| Actually carrying a sprite.
		JSR CODE_019140				;$019FE0	| Handle interaction with blocks.
		LDA $71						;$019FE3	|\ 
		CMP.b #$01					;$019FE5	||
		BCC CODE_019FF4				;$019FE7	||
		LDA.w $1419					;$019FE9	|| If Mario let go of it (not thrown), return to stationary status.
		BNE CODE_019FF4				;$019FEC	||
		LDA.b #$09					;$019FEE	||
		STA.w $14C8,X				;$019FF0	||
		RTS							;$019FF3	|/

	CODE_019FF4:
		LDA.w $14C8,X				;$019FF4	|\ 
		CMP.b #$08					;$019FF7	|| If the sprite returned to normal status (e.g. Goombas un-stunning), return.
		BEQ Return01A014			;$019FF9	|/
		LDA $9D						;$019FFB	|\ 
		BEQ CODE_01A002				;$019FFD	|| If the game is frozen, just handle offset from Mario.
		JMP CODE_01A0B1				;$019FFF	|/

	CODE_01A002:
		JSR CODE_019624				;$01A002	| Handle stun timer routines.
		JSL $018032					;$01A005	| Handle interaction with other sprites.
		LDA.w $1419					;$01A008	|\ 
		BNE CODE_01A011				;$01A00B	||
		BIT $15						;$01A00D	|| If X/Y are held or Mario is going down a pipe, offset the sprite from his position.
		BVC CODE_01A015				;$01A00F	||  Else, branch to let go of the sprite.
	CODE_01A011:					;			||
		JSR CODE_01A0B1				;$01A011	|/
	Return01A014:					;			|
		RTS							;$01A014	|

	CODE_01A015:					;```````````| Subroutine to handle letting go of a sprite.
		STZ.w $1626,X				;$01A015	|
		LDY.b #$00					;$01A018	|\\ Base Y speed to give sprites when kicking them.
		LDA $9E,X					;$01A01A	||
		CMP.b #$0F					;$01A01C	||
		BNE CODE_01A026				;$01A01E	|| Reset the sprite's Y speed.
		LDA $72						;$01A020	||  If kicking a Goomba on the ground, punt it slightly into the air.
		BNE CODE_01A026				;$01A022	||
		LDY.b #$EC					;$01A024	||| Base Y speed give Goombas when kicking them on the ground.
	CODE_01A026:					;			||
		STY $AA,X					;$01A026	|/
		LDA.b #$09					;$01A028	|\ Return to carryable status. 
		STA.w $14C8,X				;$01A02A	|/
		LDA $15						;$01A02D	|\ 
		AND.b #$08					;$01A02F	|| Branch if holding up.
		BNE CODE_01A068				;$01A031	|/
		LDA $9E,X					;$01A033	|\ 
		CMP.b #$15					;$01A035	||
		BCS CODE_01A041				;$01A037	||
		LDA $15						;$01A039	||
		AND.b #$04					;$01A03B	|| If not a Goomba or shell, don't kick by default.
		BEQ CODE_01A079				;$01A03D	|| If holding down, never kick.
		BRA CODE_01A047				;$01A03F	|| If holding left/right and not down, always kick.
	CODE_01A041:					;			||
		LDA $15						;$01A041	||
		AND.b #$03					;$01A043	||
		BNE CODE_01A079				;$01A045	|/


	CODE_01A047:					;```````````| Gently dropping a sprite (holding down, or release a non-shell/goomba sprite).
		LDY $76						;$01A047	|\ 
		LDA $D1						;$01A049	||
		CLC							;$01A04B	||
		ADC.w DATA_019F67,Y			;$01A04C	|| Fix offset from Mario (in case of turning).
		STA $E4,X					;$01A04F	||
		LDA $D2						;$01A051	||
		ADC.w DATA_019F69,Y			;$01A053	||
		STA.w $14E0,X				;$01A056	|/
		JSR SubHorzPosBnk1			;$01A059	|\ 
		LDA.w DATA_019F99,Y			;$01A05C	||
		CLC							;$01A05F	|| Set X speed.
		ADC $7B						;$01A060	||
		STA $B6,X					;$01A062	|/
		STZ $AA,X					;$01A064	|
		BRA CODE_01A0A6				;$01A066	|


	CODE_01A068:					;```````````| Kicking a sprite upwards (holding up).
		JSL DispContactSpr			;$01A068	|
		LDA.b #$90					;$01A06C	|\\ Y speed to give sprites kicked upwards.
		STA $AA,X					;$01A06E	|/
		LDA $7B						;$01A070	|\ 
		STA $B6,X					;$01A072	|| Give the sprite half Mario's speed.
		ASL							;$01A074	||
		ROR $B6,X					;$01A075	|/
		BRA CODE_01A0A6				;$01A077	|


	CODE_01A079:					;```````````| Kicking a sprite sideways (holding left/right, or releasing a shell/Goomba).
		JSL DispContactSpr			;$01A079	|
		LDA.w $1540,X				;$01A07D	|
		STA $C2,X					;$01A080	|
		LDA.b #$0A					;$01A082	|\ Set thrown status. 
		STA.w $14C8,X				;$01A084	|/
		LDY $76						;$01A087	|\ 
		LDA.w $187A					;$01A089	||
		BEQ CODE_01A090				;$01A08C	||
		INY							;$01A08E	||
		INY							;$01A08F	||
	CODE_01A090:					;			||
		LDA.w KickSpeedX,Y			;$01A090	||
		STA $B6,X					;$01A093	|| Set X speed to throw the sprite at; take base speed, and add half Mario's speed if moving in the same direction as him.
		EOR $7B						;$01A095	||  For whatever reason, if Mario is throwing the item while on Yoshi, the base speed will be faster.
		BMI CODE_01A0A6				;$01A097	||  (not that you can do that without a glitch...)
		LDA $7B						;$01A099	||
		STA $00						;$01A09B	||
		ASL $00						;$01A09D	||
		ROR							;$01A09F	||
		CLC							;$01A0A0	||
		ADC.w KickSpeedX,Y			;$01A0A1	||
		STA $B6,X					;$01A0A4	|/
	CODE_01A0A6:					;			|
		LDA.b #$10					;$01A0A6	|\\ Number of frames to disable contact with Mario for when kicking any carryable sprite.
		STA.w $154C,X				;$01A0A8	|/
		LDA.b #$0C					;$01A0AB	|\ Show Mario's kicking pose.
		STA.w $149A					;$01A0AD	|/
		RTS							;$01A0B0	|

	DATA_019F5B:					;$019F5B	| X low position offsets for sprites from Mario when carrying them.
		db $0B,$F5,$04,$FC,$04,$00				; Right, left, turning (< 1), turning (< 2, > 1), turning (> 2), centered.

	DATA_019F61:					;$019F61	| X high position offsets for sprites from Mario when carrying them.
		db $00,$FF,$00,$FF,$00,$00

	CODE_01A0B1:					;-----------| Subroutine to offset a carryable sprite from Mario's position.
		LDY.b #$00					;$01A0B1	|\ 
		LDA $76						;$01A0B3	|| Inefficiency ho!
		BNE CODE_01A0B8				;$01A0B5	|| (0 = right, 1 = left)
		INY							;$01A0B7	|/
	CODE_01A0B8:					;			|
		LDA.w $1499					;$01A0B8	|\ 
		BEQ CODE_01A0C4				;$01A0BB	||
		INY							;$01A0BD	||
		INY							;$01A0BE	|| Set Y = 2/3 or 3/4 when turning.
		CMP.b #$05					;$01A0BF	||
		BCC CODE_01A0C4				;$01A0C1	||
		INY							;$01A0C3	|/
	CODE_01A0C4:					;			|
		LDA.w $1419					;$01A0C4	|\ 
		BEQ CODE_01A0CD				;$01A0C7	||
		CMP.b #$02					;$01A0C9	||
		BEQ CODE_01A0D4				;$01A0CB	||
	CODE_01A0CD:					;			|| If turning while sliding, going down a vertical pipe, or climbing, set Y = 5.
		LDA.w $13DD					;$01A0CD	||
		ORA $74						;$01A0D0	||
		BEQ CODE_01A0D6				;$01A0D2	||
	CODE_01A0D4:					;			||
		LDY.b #$05					;$01A0D4	|/
	CODE_01A0D6:					;			|
		PHY							;$01A0D6	|
		LDY.b #$00					;$01A0D7	|\ 
		LDA.w $1471					;$01A0D9	||
		CMP.b #$03					;$01A0DC	||
		BEQ CODE_01A0E2				;$01A0DE	||
		LDY.b #$3D					;$01A0E0	||
	CODE_01A0E2:					;			||
		LDA.w $94,Y					;$01A0E2	|| Decide whether to use Mario's position on the next frame, 
		STA $00						;$01A0E5	||  or if on a revolving brown platform, current frame.
		LDA.w $95,Y					;$01A0E7	||
		STA $01						;$01A0EA	||
		LDA.w $96,Y					;$01A0EC	||
		STA $02						;$01A0EF	||
		LDA.w $97,Y					;$01A0F1	||
		STA $03						;$01A0F4	|/
		PLY							;$01A0F6	|
		LDA $00						;$01A0F7	|\ 
		CLC							;$01A0F9	||
		ADC.w DATA_019F5B,Y			;$01A0FA	||
		STA $E4,X					;$01A0FD	|| Offset horizontally from Mario.
		LDA $01						;$01A0FF	||
		ADC.w DATA_019F61,Y			;$01A101	||
		STA.w $14E0,X				;$01A104	|/
		LDA.b #$0D					;$01A107	|\\ Y offset when big.
		LDY $73						;$01A109	||
		BNE CODE_01A111				;$01A10B	||
		LDY $19						;$01A10D	|| Offset vertically from Mario.
		BNE CODE_01A113				;$01A10F	||
	CODE_01A111:					;			||
		LDA.b #$0F					;$01A111	||| Y offset when ducking or small.
	CODE_01A113:					;			||
		LDY.w $1498					;$01A113	||
		BEQ CODE_01A11A				;$01A116	||
		LDA.b #$0F					;$01A118	||| Y offset when picking up an item.
	CODE_01A11A:					;			||
		CLC							;$01A11A	||
		ADC $02						;$01A11B	||
		STA $D8,X					;$01A11D	||
		LDA $03						;$01A11F	||
		ADC.b #$00					;$01A121	||
		STA.w $14D4,X				;$01A123	|/
		LDA.b #$01					;$01A126	|\ 
		STA.w $148F					;$01A128	|| Set the flag for carrying an item.
		STA.w $1470					;$01A12B	|/
		RTS							;$01A12E	|


SetSomeYSpeed:					;-----------| Subroutine to set Y speed for a sprite when on the ground.
	LDA.w $1588,X				;$019A04	|\ 
	BMI CODE_019A10				;$019A07	||
	LDA.b #$00					;$019A09	|| 
	LDY.w $15B8,X				;$019A0B	|| If standing on a slope or Layer 2, give the sprite a Y speed of #$18.
	BEQ CODE_019A12				;$019A0E	|| Else, clear its Y speed.
CODE_019A10:					;			||
	LDA.b #$18					;$019A10	||
CODE_019A12:					;			||
	STA $AA,X					;$019A12	|/
	RTS							;$019A14	|


CODE_019624:					;-----------| Subroutine to handle routines relating to the stun timer for stunned sprites.
	LDA.w $1540,X				;$01962A	||\ 
	CMP.b #$01					;$01962D	||| If the Bob-omb's timer isn't 01, then branch becuase it's not set to explode.
	BNE CODE_01964E				;$01962F	||/
	LDA.b #$09					;$019631	||\ SFX for the Bob-omb explosion.
	STA.w $1DFC					;$019633	||/
	LDA.b #$01					;$019636	||\ Set the Bob-omb's exploding flag.
	STA.w $1534,X				;$019638	||/
	LDA.b #$40					;$01963B	|| How long the Bob-omb's explosion should last.
	STA.w $1540,X				;$01963D	||
	LDA.b #$08					;$019640	||\ Run the explosion in a normal status.
	STA.w $14C8,X				;$019642	||/
	LDA.w $1686,X				;$019645	||\ 
	AND.b #$F7					;$019648	||| Don't let Yoshi eat the explosion and don't let it turn into a coin after a goal post.
	STA.w $1686,X				;$01964A	||/
	RTS							;$01964D	|/

CODE_01964E:
	CMP.b #$40					;$01964E	|\ 
	BCS Return01965B			;$019650	||
	ASL							;$019652	|| If the Bob-omb's timer is less than #$40, then make it flash.
	AND.b #$0E					;$019653	|| Either way, return afterwards.
	EOR.w $15F6,X				;$019655	||
	STA.w $15F6,X				;$019658	|/
Return01965B:					;			|
	RTS							;$01965B	|