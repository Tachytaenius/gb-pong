SECTION "Maths Routines", ROM0

MulBcByDeInDehlUnsigned::
	ld hl, 0
	ld a, 16
.loop
	add hl, hl
	rl e
	rl d
	jr nc, :+
	add hl, bc
	jr nc, :+
	inc de
:
	dec a
	jr nz, .loop
	ret

; Could be optimised, doesn't need to be
MulBcByDeInDehlSigned::
	; Get sign of output, push it, convert operands into their absolute values, perform unsigned multiplication, pop sign, negate product if it it should be negative
	ld a, b
	xor d ; Highest bit of a is now 1 if the output should be negative
	and 1 << 7
	push af
	; Absolute of bc
	ld a, b
	and 1 << 7
	jr z, .bcPositive
	; Negate bc
	; c
	ld a, c
	cpl
	add 1
	ld c, a
	; b
	ld a, b
	cpl
	adc 0
	ld b, a
.bcPositive
	; Absolute of de
	ld a, d
	and 1 << 7
	jr z, .dePositive
	; Negate de
	; e
	ld a, e
	cpl
	add 1
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
.dePositive
	call MulBcByDeInDehlUnsigned
	pop af
	ret z
	; Negate dehl
	; l
	ld a, l
	cpl
	add 1
	ld l, a
	; h
	ld a, h
	cpl
	adc 0
	ld h, a
	; e
	ld a, e
	cpl
	adc 0
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
	ret

; Could also be optimised, but no need
MulBcUnsignedByDeSignedInDehlSigned::
	; Convert de into absolute value and negate output if it was negative
	ld a, d
	and 1 << 7
	jp z, MulBcByDeInDehlUnsigned ; All positive
	; Negate de
	; e
	ld a, e
	cpl
	add 1
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
	; Do multiplication
	call MulBcByDeInDehlUnsigned
	; Negate dehl
	; l
	ld a, l
	cpl
	add 1
	ld l, a
	; h
	ld a, h
	cpl
	adc 0
	ld h, a
	; e
	ld a, e
	cpl
	adc 0
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
	ret

ModuloDeSignedWithBcUnsigned::
	; May break if bc is enormous?
	; If de is negative then add bc until it becomes nonnegative
	; If de is nonnegative then: if it is < bc, do nothing, else subtract bc until it is <
	ld a, d
	and 1 << 7
	jr z, .deNonNegative

.deNegativeLoop
	; Add bc to de
	ld a, e
	add c
	ld e, a
	ld a, d
	adc b
	ld d, a
	; Are we done?
	; ld a, d
	and 1 << 7
	jr nz, .deNegativeLoop
	ret

.deNonNegative
	; Are we already done?
	ld a, e
	sub c
	ld a, d
	sbc b
	ret c
.nonNegativeLoop
	; Subtract bc from de
	ld a, e
	sub c
	ld e, a
	ld a, d
	sbc b
	ld d, a
	; Don't compare
	; ld a, e
	; sub c
	; ld a, d
	; sbc b
	jr nc, .nonNegativeLoop
	; Instead of comparing every time and never going too far, just correct after the final subtraction
	ld a, e
	add c
	ld e, a
	ld a, d
	adc b
	ld d, a
	ret

PingPongDehl16q16SignedWithBc16q0Unsigned::
	; Get dehl % (2 * bc) in dehl, set dehl to 2 * bc - dehl if dehl is greater than bc (undoubled)
	; % is modulo, not remainder operator. modulo is such that -0.25 % 1 = 0.75
	; Double bc
	push bc ; Back it up first
	sla c
	rl b
	call ModuloDeSignedWithBcUnsigned
	; Compare dehl with undoubled bc (considering different types of fixeds)
	pop bc ; Undoubled bc
	ld a, e
	sub c
	ld a, d
	sbc b
	ret c
	; dehl > (or =) bc
	; Set dehl to bc (doubled) - dehl
	; Do this through negating dehl and adding bc
	ld a, l
	cpl
	add 1
	ld l, a
	ld a, h
	cpl
	adc 0
	ld h, a
	ld a, e
	cpl
	adc 0
	ld e, a
	ld a, d
	cpl
	adc 0
	ld d, a
	; Negation done, addition now
	; Double bc again first
	sla c
	rl b
	; Skip fractional component of dehl (hl) as bc hasn't got one
	ld a, e
	add c
	ld e, a
	ld a, d
	adc b
	ld d, a
	ret
