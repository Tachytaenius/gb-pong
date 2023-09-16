INCLUDE "include/hardware.inc"

SECTION "Video", ROM0

; Unsets LCDCF_ON in rLCDC
; destroys af
StopLCD::
	; if bit 7 (LCDCF_ON) is unset, cancel
	ldh a, [rLCDC]
	rlca
	ret nc
.waitVBlank ; Wait for VBlank specifically, no other period is safe
	ldh a, [rLY]
	cp SCRN_Y
	jr c, .waitVBlank
	ldh a, [rLCDC]
	res 7, a ; BG display
	ldh [rLCDC], a
	ret

; Sets LCDF_ON in rLCDC
; destroys af
StartLCD::
	ldh a, [rLCDC]
	or LCDCF_ON
	ldh [rLCDC], a
	ret
