; routine to have a solid throwblock block sprite check whether a throwblock should be spawned by Mario grabbing it

	PHB
	PHK
	PLB
	JSR DoCheckSpawn
	PLB
	RTL


DoCheckSpawn:
	LDA $1504,X					; if the block interaction flag is 1 (standing on top)...
	CMP #$01
	BNE ?+
	LDA $16						; if pressing Y or X, spawn a throwblock
	AND #%01000000
	BNE SpawnThrowblock
	RTS
	?+
	
	CMP #$03					; else, if the block interaction flag is 3 or 4 (touching from the side)...
	BCC .return
	SEC : SBC $76				; and Mario is facing the block...
	CMP #$03
	BNE .return
	
	LDA $16						; if pressing Y or X, spawn a throwblock
	AND #%01000000
	BNE SpawnThrowblock

.return
	RTS


SpawnThrowblock:
	LDA $1470					; if already holding something, or on Yoshi, return
	ORA $148F
	ORA $187A
	BNE .return
	
	LDA #$0E					; throwblock (PIXI list ID)
	%SpawnCustomSprite()
	
	LDA #$0B					; store the sprite status to set in init for the spawned throwblock as 'carried'
	STA $1594,Y
	
	LDA #$08					; set the grab animation frames
	STA $1498
	
	STZ $14C8,X					; erase the throwblock block

.return
	RTS