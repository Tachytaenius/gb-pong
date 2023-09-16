MACRO define_tile
	DEF \1 RB
	EXPORT \1
	INCBIN STRCAT("res/tiles/", \2, ".2bpp")
ENDM

MACRO define_tiles
FOR I, \3
	DEF SYMBOL_NAME EQUS STRCAT(\1, "_", STRFMT("%u", I))
	DEF {SYMBOL_NAME} RB
	EXPORT {SYMBOL_NAME}
	PURGE SYMBOL_NAME
ENDR
	INCBIN STRCAT("res/tiles/", \2, ".2bpp")
ENDM

SECTION "Tileset Graphics", ROM0

TilesetGraphics::
	RSRESET
	define_tile TILE_EMPTY, "empty"
	define_tiles "TILE_LEFT_PADDLE", "left_paddle", 4
	define_tiles "TILE_RIGHT_PADDLE", "right_paddle", 4
	define_tile TILE_BALL, "ball"
.end::

DEF NUM_TILES RB 0
