INCLUDE "include/hardware.inc"
INCLUDE "include/constants.inc"

SECTION "Game Init", ROM0

GameInit::
	ld a, 1 ; If this changes, remove the UpdateSprites call below
	ld [wPaused], a

	xor a
	ld [wLeftScore], a
	ld [wRightScore], a

	; xor a
	ld [wServed], a
	ld [wServingFromWhoseLoss], a

	call ResetPositions

	; Load tileset
	ld bc, TilesetGraphics.end - TilesetGraphics
	ld hl, TilesetGraphics
	ld de, _VRAM
	call CopyBytes

	; Clear background
	ld bc, SCRN_VX_B * SCRN_Y_B ; Not SCRN_VY_B (for speed)
	ld hl, _SCRN0
	xor a
	call FillBytes

	call UpdateSprites ; Since we start paused

	ret

Serve::
	ldh a, [rDIV]
	ld [wRandState], a
	ld [wRandState + 1], a
	ld [wRandState + 2], a
	ld [wRandState + 3], a

	; The loser serves
	ld a, [wServingFromWhoseLoss]
	and a
	jr z, .randomBallXDirection
	ld a, [wServingFromWhoseLoss]
	cp SERVING_LOSS_LEFT
	jr nz, .rightLost
	; Left lost
	ld a, 1
	jr .setBallXDirection
.rightLost
	xor a
	jr .setBallXDirection
.randomBallXDirection
	; 0 to 1 in direction x
	call Rand
	and 1
.setBallXDirection
	ld [wBallXDirection], a
	; Random byte in fractional byte of vel y
	call Rand
	ld [wBallVelY], a
	; -1 to 0 in integer byte of vel y
	ld a, e
	and 1
	dec a
	ld [wBallVelY + 1], a
	; wBallVelY is now in [-1, 1) as 8.8 fixed point

	call ResetPositions

	ld a, 1
	ld [wServed], a

	ret

ResetPositions::
	xor a
	ld [wBallPos.x], a
	ld a, SCRN_X / 2
	ld [wBallPos.x + 1], a
	xor a
	ld [wBallPos.y], a
	ld a, SCRN_Y / 2
	ld [wBallPos.y + 1], a

	ld a, LOW(DEFAULT_PADDLE_POS)
	ld [wLeftPaddlePos], a
	ld [wRightPaddlePos], a
	ld a, HIGH(DEFAULT_PADDLE_POS)
	ld [wLeftPaddlePos + 1], a
	ld [wRightPaddlePos + 1], a

	ld a, LOW(DEFAULT_TARGET_POS)
	ld [wRightPaddleTargetPos], a
	ld a, HIGH(DEFAULT_TARGET_POS)
	ld [wRightPaddleTargetPos + 1], a

	ret
