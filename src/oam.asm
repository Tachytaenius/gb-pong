INCLUDE "include/hardware.inc"

SECTION "OAM DMA Source", ROM0

OAMDMASource::
	ld a, HIGH(wShadowOAM)
	ldh [rDMA], a
	ld a, OAM_COUNT
:
	dec a
	jr nz, :-
	ret
.end::

SECTION "Shadow OAM", WRAM0, ALIGN[8]

wShadowOAM::
	ds sizeof_OAM_ATTRS * OAM_COUNT
.end::

SECTION "OAM DMA", HRAM

hOAMDMA::
	ds OAMDMASource.end - OAMDMASource
