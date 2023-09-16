SECTION "Memory Manipulation", ROM0

; Taken from pokecrystal

; Fills memory with the same value
; param a: Value to fill
; param hl: Address to start filling at
; param bc: Number of bytes to fill
; destroys af bc hl 
FillBytes::
	inc b ; we bail the moment b hits 0, so include the last run
	inc c ; same thing; include last byte
	jr .HandleLoop
.PutByte:
	ld [hl+], a
.HandleLoop:
	dec c
	jr nz, .PutByte
	dec b
	jr nz, .PutByte
	ret

; Copies memory from one location to another
; param hl: Source address
; param bc: Number of bytes to copy
; param de: Destination address
; destroys af hl bc de
CopyBytes::
	inc b ; we bail the moment b hits 0, so include the last run
	inc c ; same thing; include last byte
	jr .HandleLoop
.CopyByte:
	ld a, [hl+]
	ld [de], a
	inc de
.HandleLoop:
	dec c
	jr nz, .CopyByte
	dec b
	jr nz, .CopyByte
	ret
