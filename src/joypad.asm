INCLUDE "include/hardware.inc"
INCLUDE "include/constants.inc"

SECTION "Joypad Memory", HRAM

hJoypad::
.down::
	ds 1
.pressed::
	ds 1
.released::
	ds 1

SECTION "Update Joypad", ROM0

UpdateJoypad::
	; put currently held buttons in a
	ld a, P1F_4
	ldh [rP1], a
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	and $0F
	swap a
	ld b, a
	ld a, P1F_5
	ldh [rP1], a
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	and $0F
	or b
	cpl
	; backup currently held buttons in d
	ld c, a
	
	; put buttons not held last frame but held this frame at hJoypad.pressed
	ld b, a
	ldh a, [hJoypad.down] ; last frame's
	cpl
	and b
	ldh [hJoypad.pressed], a
	
	; put buttons held last frame but not held this frame at hJoypad.released
	ldh a, [hJoypad.down] ; last frame's
	ld b, a
	ld a, c
	cpl
	and b
	ldh [hJoypad.released], a
	
	ld a, c
	ldh [hJoypad.down], a
	ret
