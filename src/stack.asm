DEF STACK_SIZE EQU $80 ; In words, not bytes

SECTION "Stack", WRAM0

wStack::
	ds STACK_SIZE * 2 - 1
.bottom::
	ds 1
