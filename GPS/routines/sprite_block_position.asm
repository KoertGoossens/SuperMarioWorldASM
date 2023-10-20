; routine to store a sprite's block interaction points ($0A-$0D) to general block interaction points ($98-$9B)

LDA $0A
AND #%11110000
STA $9A
LDA $0B
STA $9B

LDA $0C
AND #%11110000
STA $98
LDA $0D
STA $99
RTL