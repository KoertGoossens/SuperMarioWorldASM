; this block behaves like a vanilla throwblock, but with two changed features:
;	- it spawns a custom throwblock sprite instead of a vanilla one
;	- when spinning, you can always grab the block from the side by pressing into the direction of the block, regardless of Mario's face direction (which is unpredictable during a spin)
; insert as 130

db $37
JMP Return			; Mario touching the tile from below
JMP MarioTop		; Mario touching the tile from above
JMP MarioSide		; Mario touching the tile from the side
JMP Return			; sprite touching the tile from above or below
JMP Return			; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP MarioTop		; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP MarioSide		; Mario is wallrunning on the side of the block
JMP MarioSide		; Mario is wallrunning through the block


MarioSide:
	LDA $16						; if pressing Y or X...
	AND #%01000000
	BEQ Return
	
	LDA $140D					; if spinning, check for spawning a throwblock
	BNE CheckSpawn
	
	LDA $76						; else if Mario is facing the block, check for spawning a throwblock
	CMP $93
	BNE CheckSpawn
	
	RTL


MarioTop:
	LDA $16						; if pressing Y or X, check for spawning a throwblock
	AND #%01000000
	BNE CheckSpawn
	
	RTL


Return:
	RTL


CheckSpawn:
	LDA $1470					; if already holding something, or on Yoshi, return
	ORA $148F
	ORA $187A
	BNE Return
	
	LDA #$0E					; spawn a throwblock
	%SpawnCustomSprite()
	
	LDA #$0B					; store the sprite status to set in init as 'carried'
	STA $1594,Y
	
	LDA #$08					; set the 'grabbing item pose' timer
	STA $1498
	
	LDA #$01					; set the 'carrying an item' flag
	STA $148F
	
	REP #$10					; change tile into non-solid tile (25)
	LDX #$0025
	%change_map16()
	SEP #$10
	
	RTL


print "This is a throwblock that spawns a custom throwblock sprite."