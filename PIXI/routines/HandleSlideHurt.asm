; routine to check whether Mario should slidekill a sprite or get hit by it

	PHB
	PHK
	PLB
	JSR DoHandleSlideKillSprite
	PLB
	RTL


DoHandleSlideKillSprite:
	LDA $13ED					; if sliding...
	BEQ ?+
	
	LDA #$03					; play kick sfx
	STA $1DF9
	
	LDA #$08					; set the 'disable contact with Mario' timer
	STA $154C,X
	
	JSR DoSlideKill				; kill the sprite
	BRA .doreturn
	?+
	
	JSR DoHurtMario				; else, handle hurting Mario

.doreturn
	RTS


DoSlideKill:		%SlideStarKillSprite() : RTS
DoHurtMario:		%HandleHurtMario() : RTS