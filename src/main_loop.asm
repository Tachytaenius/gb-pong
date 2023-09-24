INCLUDE "include/constants.inc"

SECTION "Main Loop Variables", WRAM0

wPaused:: ; boolean
	ds 1

wServed:: ; boolean
	ds 1

wServingFromWhoseLoss:: ; enum
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

wRightPaddlePos:: ; 8.8 unsigned
	ds 2

wRightPaddleTargetPos:: ; 8.8 unsigned
	ds 2

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
	; Randomise ball velocity with rDIV-set seed if we are unpausing for the first time
	ld a, [wServed]
	and a
	jr nz, :+
	call Serve ; wServed is set at the end of this routine
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
	call .predictBallPos ; TODO: Do this on a timer, and fudge it

	; Set hl to paddle pos
	ld a, [wRightPaddlePos]
	ld l, a
	ld a, [wRightPaddlePos + 1]
	ld h, a
	; Set de to paddle target pos
	ld a, [wRightPaddleTargetPos]
	ld e, a
	ld a, [wRightPaddleTargetPos + 1]
	ld d, a
	; Go upwards with -speed if hl + half paddle (paddle middle) > de (target pos), else go downwards
	; I feel it's likely that this comparison is badly-written
	ld bc, PADDLE_HEIGHT_HALF
	push hl
	add hl, bc
	ld a, l
	sub e
	ld a, h
	sbc d
	pop hl
	jr nc, .upwards

	; Downwards (add to hl)
	ld bc, PADDLE_SPEED
	add hl, bc
	; Check if hl + PADDLE_HEIGHT_HALF > (or =) target pos and set paddle pos to target pos - PADDLE_HEIGHT_HALF if it is
	; The following implementation is surely bad
	ld bc, PADDLE_HEIGHT_HALF
	push hl
	add hl, bc
	; push de ; Won't get used again
	ld a, e
	cpl
	add 1
	ld e, a
	ld a, d
	cpl
	adc 0
	ld d, a
	add hl, de ; Sub target pos to compare it with hl
	; pop de
	pop hl
	call c, .putPaddleOnTargetInHl
	; Check if hl is > (or =) game height and set paddle pos to LOWEST_PADDLE_POS if so
	ld a, l
	sub LOW(LOWEST_PADDLE_POS)
	ld a, h
	sbc HIGH(LOWEST_PADDLE_POS)
	jr c, :+
	; hl too big
	ld hl, LOWEST_PADDLE_POS
:
	; Done! Set right paddle pos to hl
	ld a, l
	ld [wRightPaddlePos], a
	ld a, h
	ld [wRightPaddlePos + 1], a
	ret

.upwards ; Sub from hl
	ld bc, -PADDLE_SPEED
	add hl, bc
	; If we underflowed from the subtraction, set hl to 0
	jr c, :+
	ld hl, 0
:
	; Is hl + PADDLE_HEIGHT_HALF < target pos? If it is, set paddle pos to target pos - PADDLE_HEIGHT HALF
	; The following implementation is surely bad
	ld bc, PADDLE_HEIGHT_HALF
	push hl
	add hl, bc
	; push de ; Won't get used again
	ld a, e
	cpl
	add 1
	ld e, a
	ld a, d
	cpl
	adc 0
	ld d, a
	add hl, de ; Sub pre-push de to compare it with hl
	; pop de
	pop hl
	call nc, .putPaddleOnTargetInHl
	; No need to check if hl is bigger than LOWEST_PADDLE_POS
	; Done! Set right paddle pos to hl
	ld a, l
	ld [wRightPaddlePos], a
	ld a, h
	ld [wRightPaddlePos + 1], a
	ret

.putPaddleOnTargetInHl
	ld a, [wRightPaddleTargetPos]
	sub LOW(PADDLE_HEIGHT_HALF)
	ld l, a
	ld a, [wRightPaddleTargetPos + 1]
	sub HIGH(PADDLE_HEIGHT_HALF)
	ld h, a
	ret nc
	; Underflowed
	ld hl, 0
	ret

.predictBallPos
	; Return if ball not moving in the right direction
	ld a, [wBallXDirection]
	and a
	ret z

	; timeRemaining = (gameWidth - ballPos.x) / ballVel.x
	; Put gameWidth - ballPos.x in hl
	ld hl, SCRN_X << 8
	ld a, [wBallPos.x]
	cpl
	ld e, a
	ld a, [wBallPos.x + 1]
	cpl
	ld d, a
	inc de
	add hl, de
	; hl: gameWidth - ballPos.x
	; Put hl / ballVel.x in dehl
	ld c, l
	ld b, h
	ld de, BALL_SPEED_X_RECIPROCAL ; Only here if ball direction is right (vel is positive)
	call MulBcByDeInDehlUnsigned
	; dehl: timeRemaining (as unsigned 16.16 fixed point)
	
	; projectedYPos = ballPos.y + ballVel.y * timeRemaining
	; eh (from dehl (timeRemaining)) --> bc
	; Though dehl is not a huge number (00??????), the resultant 8.8 bc may still be interpreted as negative
	; So we need to use a special multiplication routine that will treat bc as unsigned
	ld c, h
	ld b, e
	; ballVel.y in de (treated as signed)
	ld a, [wBallVelY]
	ld e, a
	ld a, [wBallVelY + 1]
	ld d, a
	call MulBcUnsignedByDeSignedInDehlSigned
	; dehl: ballVel.y * timeRemaining (as signed 16.16 fixed point)
	; Add ballPos.y to that
	; Skip l (de.hl + 8.8)
	; h
	ld a, [wBallPos.y]
	add h
	ld h, a
	; e
	ld a, [wBallPos.y + 1]
	adc e
	ld e, a
	; Don't skip d in case it carries
	ld a, 0 ; No byte of pos y higher than the 2nd in memory, so use zero. Don't use xor as it changes carry
	adc d
	ld d, a
	; dehl: projectedYPos (as signed 16.16 fixed point)

	; projectedYPosBounced = pingPong(projectedYPos, gameHeight)
	ld bc, SCRN_Y
	call PingPongDehl16q16SignedWithBc16q0Unsigned
	; dehl: projectedYPosBounced

	; We're done! Store middle bytes of dehl, discarding the rest
	ld a, h
	ld [wRightPaddleTargetPos], a
	ld a, e
	ld [wRightPaddleTargetPos + 1], a
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
	jp nc, .y

	; Did we hit the left paddle?
	; Get ball y - paddle top in hl
	; Put paddle top in hl and deref hl
	ld hl, wLeftPaddlePos
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	; Perform subtraction and put result in hl
	ld a, [wBallPos.y]
	sub l
	ld l, a
	ld a, [wBallPos.y + 1]
	sbc h
	ld h, a
	; hl is now ballPos.y - leftPaddlePos
	; Check its magnitude against paddle height (if negative, which is also a miss, it will be greater than)
	ld bc, PADDLE_HEIGHT_NEGATIVE - 1 ; We are checking if hl <= PADDLE_HEIGHT with nc
	push hl ; Used again if paddle is hit
	add hl, bc
	pop hl
	jr nc, .hitPaddleLeft

	; Missed paddle
	ld a, SERVING_LOSS_LEFT
	ld [wServingFromWhoseLoss], a
	ld a, [wRightScore]
	inc a
	; Don't increment over max value
	jr nz, :+
	ld a, $FF
:
	ld [wRightScore], a
	jp Serve

.hitPaddleLeft
	; hl, which is where the ball y is on the paddle, can be used to get new ballVelY
	; First we subtract paddle height half
	ld bc, PADDLE_HEIGHT_HALF_NEGATIVE
	add hl, bc
	; Now we divide it by paddle height half (so it is from -1 to 1) and multiply by max ball velocity y magnitude in one multiplication
	ld c, l
	ld b, h
	ld de, BALL_VELOCITY_Y_CALC_MULTIPLIER
	call MulBcByDeInDehlSigned
	; dehl: desired y velocity as 16.16 fixed point
	; We only want the middle two bytes
	ld a, h
	ld [wBallVelY], a
	ld a, e
	ld [wBallVelY + 1], a
	; Done with ball vel y
	; Change ball x direction
	ld a, 1
	ld [wBallXDirection], a
	; We shouldn't actually be below zero, so set pos x to zero
	; This may help with keeping the maths in ball pos prediction in order
	xor a
	ld [wBallPos.x], a
	ld [wBallPos.x + 1], a
	jr .y

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
	jr c, .y ; a is less than

	; Did we hit the right paddle?
	; Get ball y - paddle top in hl
	; Put paddle top in hl and deref hl
	ld hl, wRightPaddlePos
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	; Perform subtraction and put result in hl
	ld a, [wBallPos.y]
	sub l
	ld l, a
	ld a, [wBallPos.y + 1]
	sbc h
	ld h, a
	; hl is now ballPos.y - rightPaddlePos
	; Check its magnitude against paddle height (if negative, which is also a miss, it will be greater than)
	ld bc, PADDLE_HEIGHT_NEGATIVE - 1 ; We are checking if hl <= PADDLE_HEIGHT with nc
	push hl ; Used again if paddle is hit
	add hl, bc
	pop hl
	jr nc, .hitPaddleRight

	; Missed paddle
	ld a, SERVING_LOSS_RIGHT
	ld [wServingFromWhoseLoss], a
	ld a, [wLeftScore]
	inc a
	; Don't increment over max value
	jr nz, :+
	ld a, $FF
:
	ld [wLeftScore], a
	jp Serve

.hitPaddleRight
	; hl, which is where the ball y is on the paddle, can be used to get new ballVelY
	; First we subtract paddle height half
	ld bc, PADDLE_HEIGHT_HALF_NEGATIVE
	add hl, bc
	; Now we divide it by paddle height half (so it is from -1 to 1) and multiply by max ball velocity y magnitude in one multiplication
	ld c, l
	ld b, h
	ld de, BALL_VELOCITY_Y_CALC_MULTIPLIER
	call MulBcByDeInDehlSigned
	; dehl: desired y velocity as 16.16 fixed point
	; We only want the middle two bytes
	ld a, h
	ld [wBallVelY], a
	ld a, e
	ld [wBallVelY + 1], a
	; Done with ball vel y
	; Change ball direction
	xor a
	ld [wBallXDirection], a
	; We shouldn't actually be above game width, so set pos x to it
	; This may help with keeping the maths in ball pos prediction in order
	ld [wBallPos.x], a
	ld a, SCRN_X
	ld [wBallPos.x + 1], a

.y
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
	call .invertYVelocity
	; We shouldn't actually be above game height, so set pos y to it
	; This may help with keeping the maths in ball pos prediction in order
	xor a
	ld [wBallPos.y], a
	ld a, SCRN_Y
	ld [wBallPos.y + 1], a
	ret

.negative
	call .addVelYToPosY
	; Check if we went under 0 and invert y vel if so
	; Carry is preserved from previous addition
	ret c
	call .invertYVelocity
	; We shouldn't actually be below game height, so set pos y to zero
	; This helps with keeping the maths in ball pos prediction in order
	xor a
	ld [wBallPos.y], a
	ld [wBallPos.y + 1], a
	ret

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
