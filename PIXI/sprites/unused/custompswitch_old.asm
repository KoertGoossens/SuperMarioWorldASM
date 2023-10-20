; custom p-switch; see custompswitch.asm (Asar patches)
; this sprite requires the use of a custom palette to have the correct appearance
;
; extension byte variations to be used:						[color]				[symbol]
;	00	=	one-hit coin/block p-switch						blue				P					(= vanilla blue p-switch)
;	01	=	one-hit on/off p-switch							red					X
;	02	=	infinite-hit coin/block p-switch				yellow				P
;	03	=	infinite-hit on/off p-switch					yellow				X
;	05	=	one-hit shooter trigger p-switch				blue				bullet bill
;	07	=	infinite-hit shooter trigger p-switch			yellow				bullet bill
;	09	=	one-hit secondary on/off p-switch				blue				X


print "INIT ",pc
	PHB
	PHK
	PLB
	JSR InitCode
	PLB
	RTL


LoadPalette:
	db $08,$0A,$0C,$0C,$00,$08,$00,$0C,$00,$08,$00,$00,$00,$00,$00,$00

InitCode:
	LDA #$09					; set sprite status as 'carryable'
	STA $14C8,X
	
	LDA $7FAB40,X
	AND #%00001111
	TAY
	
	LDA LoadPalette,Y
	STA $15F6,X
	RTS