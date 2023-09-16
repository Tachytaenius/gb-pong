SECTION "Header", ROM0[$100]
	di
	jp Init

	ds $150 - @, 0
