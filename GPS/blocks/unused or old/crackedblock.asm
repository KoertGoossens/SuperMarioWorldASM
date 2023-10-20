; this block shatters when in contact with an explosion; insert as 130

db $37
JMP Return			; Mario touching the tile from below
JMP Return			; Mario touching the tile from above
JMP Return			; Mario touching the tile from the side
JMP Sprite			; sprite touching the tile from above or below
JMP Sprite			; sprite touching the tile from the side
JMP Return			; capespin touching the tile
JMP Return			; fire flower fireball touching the tile
JMP Return			; Mario touching the upper corners of the tile
JMP Return			; Mario's lower half is inside the block
JMP Return			; Mario's upper half is inside the block
JMP Return			; Mario is wallrunning on the side of the block
JMP Return			; Mario is wallrunning through the block

Sprite:
	LDA $E4,X
	STA $9A
	LDA $14E0,X
	STA $9B
	LDA $D8,X
	STA $98
	LDA $14D4,X
	STA $99
	
	PHX
    PHY
    LDA #$02    				; generate non-solid tile
    STA $9C
    JSL $00BEB0
	
    PHB							; spawn shatter pieces
    LDA #$02
    PHA
    PLB
    LDA #$00
    JSL $028663
    PLB
	
    PLY
	PLX
	
	
;	REP #$10					; change tile into non-solid tile (25)
;	LDX #$0025
;	%change_map16()
;	SEP #$10

Return:
	RTL