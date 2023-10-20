; routine to check whether a sprite is touching a solid layer 1 tile at specified x/y coordinates
;	input:		$98		=	block position y (16-bit)
;				$9A		=	block position x (16-bit)
	
	STZ $1933
	%GetMap16ActAs()
	REP #$20
	
	CMP #$0130				; if the Map16 tile's 'Act As' is 130, return as solid
	BEQ .returnsolid
	
	CMP #$0141				; if the Map16 tile's 'Act As' is 141...
	BNE +
	SEP #$20
	LDA $14AF				; and the on/off state is off, return as solid
	BEQ .returnsolid
	BRA .returnnonsolid		; if on, return as non-solid
	+
	
	CMP #$0142				; if the Map16 tile's 'Act As' is 142...
	BNE +
	SEP #$20
	LDA $14AF				; and the on/off state is on, return as solid
	BNE .returnsolid
	BRA .returnnonsolid		; if off, return as non-solid
	+
	
	CMP #$0143				; if the Map16 tile's 'Act As' is 143...
	BNE +
	SEP #$20
	LDA $7FC0FC				; and the secondary on/off state is off, return as solid
	BEQ .returnsolid
	BRA .returnnonsolid		; if on, return as non-solid
	+
	
	CMP #$0144				; if the Map16 tile's 'Act As' is 144...
	BNE +
	SEP #$20
	LDA $7FC0FC				; and the secondary on/off state is on, return as solid
	BNE .returnsolid
	BRA .returnnonsolid		; if off, return as non-solid
	+
	
	CMP #$0145				; if the Map16 tile's 'Act As' is 145...
	BNE +
	SEP #$20
	LDA $14AD				; and the p-switch timer is 0, return as solid
	BEQ .returnsolid
	BRA .returnnonsolid		; else, return as non-solid
	+
	
	CMP #$0146				; if the Map16 tile's 'Act As' is 146...
	BNE +
	SEP #$20
	LDA $14AD				; and the p-switch timer is not 0, return as solid
	BNE .returnsolid
	BRA .returnnonsolid		; else, return as non-solid
	+

.returnnonsolid
	SEP #$20
	LDA #$01
	RTL

.returnsolid
	SEP #$20
	LDA #$00
	RTL