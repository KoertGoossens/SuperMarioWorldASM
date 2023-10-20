; custom shell
; the extension byte sets the shell type:
;	00	=	vanilla green shell
;	01	=	infinite bounce shell
;	02	=	regrab shell
;	04	=	carryable disco shell
;	08	=	one-hit shell
; see customspriteinteraction.asm for specified behavior
; sprite-indexed addresses (on top of those of the vanilla green shell):
;	$1504,X		=	shell type


Palette:
	db $0A,$02,$04,$04,$00,$00,$00,$00,$0E			; green, silver, yellow, yellow, (disco), (disco), (disco), (disco), pink

print "INIT ",pc
	LDA #$09					; set sprite status as 'carryable'
	STA $14C8,X
	
	LDA $7FAB40,X				; store the shell type to a normal sprite-indexed address and set the palette based on the final two bits
	STA $1504,X
	AND #%00001011
	PHX
	TAX
	LDA.l Palette,X				; .l seems mandatory to load from a table in INIT?
	PLX
	STA $15F6,X
	
	LDA $1504,X					; if the shell type is disco, set the disco shell flag
	AND #%00000100
	BEQ +
	INC $187B,X
	+
	
	RTL