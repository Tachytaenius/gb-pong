SECTION "VBlank Flag", HRAM

hVBlankFlag::
	ds 1

SECTION "VBlank IRQ Vector", ROM0[$40]

VBlankVector::
	push af
	ld a, 1
	ldh [hVBlankFlag], a
	call hOAMDMA
	pop af
	reti
