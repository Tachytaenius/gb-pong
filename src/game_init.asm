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
	ld [wBallPos.x], a
	ld a, SCRN_X / 2
	ld [wBallPos.x + 1], a
	xor a
	ld [wBallPos.y], a
	ld a, SCRN_Y / 2
	ld [wBallPos.y + 1], a

	xor a
	ld [wBallXDirection], a
	ld a, LOW(BALL_INITIAL_VELOCITY_Y)
	ld [wBallVelY], a
	ld a, HIGH(BALL_INITIAL_VELOCITY_Y)
	ld [wBallVelY + 1], a

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
