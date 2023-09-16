INCLUDE "include/constants.inc"

SECTION "Main Loop Variables", WRAM0

wPaused:: ; boolean
	ds 1

wLeftScore:: ; 8 unsigned
	ds 1
wRightScore:: ; 8 unsigned
	ds 1

wBallPos:: ; 8.8 unsigned
.x::
	ds 2
.y::
	ds 2
wBallXDirection:: ; 0 left 1 right
	ds 1
wBallVelY:: ; 8.8 signed
	ds 2

wLeftPaddlePos:: ; 8.8 unsigned
	ds 2
wLeftPaddleHeight:: ; 8 unsigned
	ds 1

wRightPaddlePos:: ; 8.8 unsigned
	ds 2
wRightPaddleHeight:: ; 8 unsigned
	ds 1

SECTION "Main Loop", ROM0

MainLoop::
	; Wait for VBlank
	halt
	nop
	ldh a, [hVBlankFlag]
	and a
	jr z, MainLoop
	xor a
	ldh [hVBlankFlag], a

	call UpdateJoypad

	ld a, [hJoypad.pressed]
	and JOY_START_MASK
	jr z, :+
	; Toggle pause
	ld a, [wPaused]
	xor 1
	ld [wPaused], a
:

	ld a, [wPaused]
	and a
	jr nz, MainLoop

	; Update
	call HandleLeftPaddleMovement
	call HandleRightPaddleMovement
	call HandleBallMovement

	; Draw
	call UpdateSprites

	jr MainLoop

HandleLeftPaddleMovement:
	ldh a, [hJoypad.down]
	and JOY_UP_MASK
	jr z, .doneWithUp
	; Subtract PADDLE_SPEED and set to 0 on underflow
	ld a, [wLeftPaddlePos]
	ld l, a
	ld a, [wLeftPaddlePos + 1]
	ld h, a
	ld de, -PADDLE_SPEED
	add hl, de
	jr c, :+
	ld hl, 0
:
	ld a, l
	ld [wLeftPaddlePos], a
	ld a, h
	ld [wLeftPaddlePos + 1], a
.doneWithUp
	ldh a, [hJoypad.down]
	and JOY_DOWN_MASK
	ret z
	; Add PADDLE_SPEED and set to LOWEST_PADDLE_POS if pos is greater than LOWEST_PADDLE_POS
	; Note that we don't check overflow because we won't be using any extreme values
	ld a, [wLeftPaddlePos]
	ld l, a
	ld a, [wLeftPaddlePos + 1]
	ld h, a
	ld de, PADDLE_SPEED
	add hl, de
	; Now check size
	ld a, l
	sub LOW(LOWEST_PADDLE_POS)
	ld a, h
	sbc HIGH(LOWEST_PADDLE_POS)
	jr c, :+
	; hl too big
	ld hl, LOWEST_PADDLE_POS
:
	ld a, l
	ld [wLeftPaddlePos], a
	ld a, h
	ld [wLeftPaddlePos + 1], a
	ret

HandleRightPaddleMovement:
	ret

HandleBallMovement:
	; x
	ld a, [wBallXDirection]
	and a
	jr nz, .right
	; Left
	; Low
	ld a, [wBallPos.x]
	sub LOW(BALL_SPEED_X)
	ld [wBallPos.x], a
	; High
	ld a, [wBallPos.x + 1]
	sbc HIGH(BALL_SPEED_X)
	ld [wBallPos.x + 1], a
	; Did we go below 0?
	jr nc, .doneX
	; TODO: Hit a paddle?
	; For now we just assume we did and don't do the y vel change
	ld a, 1
	ld [wBallXDirection], a
	jr .doneX
.right
	; Low
	ld a, [wBallPos.x]
	add LOW(BALL_SPEED_X)
	ld [wBallPos.x], a
	; High
	ld a, [wBallPos.x + 1]
	adc HIGH(BALL_SPEED_X)
	ld [wBallPos.x + 1], a
	; Did we go above screen width?
	; Not checking overflow, the values won't be extreme enough
	cp SCRN_X
	jr c, .doneX ; a is less than
	; TODO: Hit a paddle?
	; For now we just assume we did and don't do the y vel change
	xor a
	ld [wBallXDirection], a
.doneX

	; y
	ld a, [wBallVelY + 1]
	and 1 << 7 ; Check sign
	jr nz, .negative
	; Vel is positive
	call .addVelYToPosY
	; Check if pos went over screen height
	; Ball pos y high byte is in a
	cp SCRN_Y
	ret c ; Return if not over height
	jp .invertYVelocity
.negative
	call .addVelYToPosY
	; Check if we went under 0 and invert y vel if so
	; Carry is preserved from previous addition
	ret c
	; Fallthrough
.invertYVelocity
	ld a, [wBallVelY]
	cpl
	add 1 ; inc a doesn't set carry
	ld [wBallVelY], a
	ld a, [wBallVelY + 1]
	cpl
	adc 0
	ld [wBallVelY + 1], a
	ret

.addVelYToPosY
	; Low
	ld a, [wBallVelY]
	ld b, a
	ld a, [wBallPos.y]
	add b
	ld [wBallPos.y], a
	; High
	ld a, [wBallVelY + 1]
	ld b, a
	ld a, [wBallPos.y + 1]
	adc b
	ld [wBallPos.y + 1], a
	ret

UpdateSprites::
	ld hl, wShadowOAM

	; Left paddle
FOR I, 4
	ld a, [wLeftPaddlePos + 1]
	add I * 8 + OAM_Y_OFS
	ld [hl+], a
	ld a, OAM_X_OFS
	ld [hl+], a
	ld a, TILE_LEFT_PADDLE_0 + I
	ld [hl+], a
	inc hl
ENDR

	; Right paddle
FOR I, 4
	ld a, [wRightPaddlePos + 1]
	add OAM_Y_OFS + I * 8
	ld [hl+], a
	ld a, SCRN_X - 8 + OAM_X_OFS
	ld [hl+], a
	ld a, TILE_RIGHT_PADDLE_0 + I
	ld [hl+], a
	inc hl
ENDR

	; Ball
	ld a, [wBallPos.y + 1]
	add OAM_Y_OFS - 4
	ld [hl+], a ; y
	ld a, [wBallPos.x + 1]
	add OAM_X_OFS - 4
	ld [hl+], a ; x
	ld a, TILE_BALL ; TEMP
	ld [hl+], a ; tile
	inc hl ; skip flags

	ret
