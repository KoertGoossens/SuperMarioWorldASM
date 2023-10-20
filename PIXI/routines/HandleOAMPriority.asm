; handle OAM priority for carried sprites

	LDA $1419					; if Mario is going through a pipe...
	BNE +
	LDA $1499					; or facing the screen...
	ORA $1908					; or inside a boost bubble...
	BEQ .skipdrawinfront
	+
	
	LDA #$04
	STA $15EA,X					; set the sprite's OAM index to 4 (so it will show in front of Mario, but behind the glimmer tile of a boost bubble)

.skipdrawinfront
	LDA $1419					; if going down a pipe, send behind objects
	BEQ +
	LDA #%00010000
	STA $64
	+
	
	RTL