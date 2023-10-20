; this routine handles sprite<>object clipping with standard clipping points for 1x1 tile-sized sprites; this requires the patch 'customspriteobjectclipping.asm'
; input:	$7FB660 through $7FB667

	LDA #$0E	:	STA $7FB660			; right clipping point x
	LDA #$02	:	STA $7FB661			; left clipping point x
	LDA #$08	:	STA $7FB662			; bottom clipping point x
	LDA #$08	:	STA $7FB663			; top clipping point x
	
	LDA #$08	:	STA $7FB664			; right clipping point y
	LDA #$08	:	STA $7FB665			; left clipping point y
	LDA #$10	:	STA $7FB666			; bottom clipping point y
	LDA #$02	:	STA $7FB667			; top clipping point y
	
	JSL $019138							; process interaction with blocks
	RTL