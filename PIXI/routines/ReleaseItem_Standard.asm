	%ReleaseItemMisc()
	
	LDA $15						; if holding up, upthrow the item
	AND #%00001000
	BEQ ++
	%ReleaseItem_Up()
	RTL
	++
	
	LDA $15						; else, if holding left of right, throw the item sideways
	AND #%00000011
	BEQ ++
	STZ $AA,X					; give the item 0 y speed
	%ReleaseItem_Side()
	RTL
	++
	
	%ReleaseItem_Down()			; else, drop it
	RTL