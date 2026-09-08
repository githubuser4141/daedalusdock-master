// AI EDIT: FLAGGED, NOT FIXED - this whole file predates DD's own smoothing_groups/canSmoothWith refactor. DD's
// S_TURF(num)/S_OBJ(num) (code/__DEFINES/icon_smoothing.dm) now produce STRINGS ("0," / "-1,"), with the leading
// "-" on S_OBJ specifically flagging obj-space groups so SETUP_SMOOTHING can auto-set SMOOTH_OBJ - but S_OBJ_FO/
// S_OBJ1 below still do raw integer arithmetic. Any smoothing_groups/canSmoothWith declaration that mixes one of
// DD's own groups (e.g. SMOOTH_GROUP_TURF_OPEN) with one of these MS13 groups in the same `+` expression fails to
// compile (string + number isn't a constant expression) - mojave/turfs/plating.dm has 5 such sites. Groups used
// MS13-only (no DD group mixed in) compile fine as a bare number but are silently broken at runtime instead:
// SETUP_SMOOTHING only touches smoothing_groups/canSmoothWith when istext() is true, so an all-MS13 numeric value
// just gets skipped, and that atom never smooths. A real fix means converting every SMOOTH_GROUP_MS13_* below to
// DD's string format AND deciding turf-space vs obj-space (the "-" prefix) per group to preserve SMOOTH_OBJ
// detection - getting that polarity wrong per-group causes wrong-but-compiling behavior, not a compile error, so
// it needs visual verification in-game rather than a blind mechanical rename. Left as-is.
#define S_OBJ_FO(num) (MAX_S_OBJ_1 + 1 + num)

#define S_OBJ1(num) (MAX_S_TURF + 1 + num) // Def

#define MAX_S_OBJ_1 S_OBJ1(71) //Always match this value with the one above it.

#define SMOOTH_GROUP_MS13_WALL S_OBJ_FO(0)				///obj/structure/table/ms13/low_wall, /turf/closed/wall/ms13
#define SMOOTH_GROUP_MS13_WALL_METAL S_OBJ_FO(1)		///obj/structure/table/ms13/low_wall/metal, /turf/closed/wall/ms13/metal
#define SMOOTH_GROUP_MS13_WALL_WOOD S_OBJ_FO(2)		///obj/structure/table/ms13/low_wall/wood, /turf/closed/wall/ms13/wood
#define SMOOTH_GROUP_MS13_WALL_SCRAP S_OBJ_FO(3)		///obj/structure/table/ms13/low_wall/scrap, /turf/closed/wall/ms13/scrap
#define SMOOTH_GROUP_MS13_WALL_ADOBE S_OBJ_FO(4)		///obj/structure/table/ms13/low_wall/adobe, /turf/closed/wall/ms13/adobe
#define SMOOTH_GROUP_MS13_WALL_BRICK S_OBJ_FO(5)		///obj/structure/table/ms13/low_wall/brick, /turf/closed/wall/ms13/brick
#define SMOOTH_GROUP_MS13_WALL_REINFORCED S_OBJ_FO(6)	///obj/structure/table/ms13/low_wall/reinforced, /turf/closed/wall/ms13
#define SMOOTH_GROUP_MS13_MINERALS S_OBJ_FO(8)			///turf/closed/mineral/random/ms13, /turf/closed/indestructible/rock/ms13
#define SMOOTH_GROUP_MS13_WINDOW S_OBJ_FO(9)			///obj/structure/window/fulltile/ms13/glass

#define SMOOTH_GROUP_MS13_DESERT S_OBJ_FO(10)			///turf/open/floor/plating/ground/desert
#define SMOOTH_GROUP_MS13_SNOW S_OBJ_FO(11)			///turf/open/floor/plating/ms13/ground/snow
#define SMOOTH_GROUP_MS13_ROAD S_OBJ_FO(12)			///turf/open/floor/plating/ground/road
#define SMOOTH_GROUP_MS13_SIDEWALK S_OBJ_FO(13)			///turf/open/floor/plating/ground/sidewalk
#define SMOOTH_GROUP_MS13_TILE S_OBJ_FO(14)			///turf/open/floor/wood/ms13, /turf/open/floor/ms13/
#define SMOOTH_GROUP_MS13_ICE S_OBJ_FO(15)			///turf/open/floor/plating/ms13/ground/ice
#define SMOOTH_GROUP_MS13_WATER S_OBJ_FO(16)		///turf/open/ms13/water

#define SMOOTH_GROUP_MS13_LOW_WALL S_OBJ_FO(17)			///obj/structure/table/ms13/low_wall
#define SMOOTH_GROUP_MS13_CARPET_RED S_OBJ_FO(18)			////turf/open/floor/wood/ms13/carpet/red
#define SMOOTH_GROUP_MS13_CARPET_BLUE S_OBJ_FO(19)			////turf/open/floor/wood/ms13/carpet/blue
#define SMOOTH_GROUP_MS13_CARPET_GREEN S_OBJ_FO(20)			////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_VIOLET S_OBJ_FO(21)			////turf/open/floor/wood/ms13/carpet/violet
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_RED S_OBJ_FO(22)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_BLUE S_OBJ_FO(23)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_GREEN S_OBJ_FO(24)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_VIOLET S_OBJ_FO(25)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_ROOF_NORMAL S_OBJ_FO(26)			////turf/open/floor/plating/roof
#define SMOOTH_GROUP_MS13_ROOF_SHEET S_OBJ_FO(27)			////turf/open/floor/plating/roof/sheet
#define SMOOTH_GROUP_MS13_ROOF_METAL S_OBJ_FO(28)			////turf/open/floor/plating/roof/metal
#define SMOOTH_GROUP_MS13_ROOF_WOOD S_OBJ_FO(29)			////turf/open/floor/plating/roof/wood
#define SMOOTH_GROUP_MS13_GLASS S_OBJ_FO(30)			///obj/structure/ms13/glassfloor

#define SMOOTH_GROUP_MS13_OPENSPACE S_OBJ_FO(31)			///turf/open/openspace/ms13

#define SMOOTH_GROUP_SOIL S_OBJ_FO(31)					///obj/machinery/hydroponics/ms13/soil
#define SMOOTH_GROUP_MS13_TABLE_METAL S_OBJ_FO(32)			///obj/structure/table/ms13
#define SMOOTH_GROUP_MS13_TABLE_WOOD S_OBJ_FO(33)			///obj/structure/table/ms13/wood
#define SMOOTH_GROUP_MS13_TABLE_SMALL S_OBJ_FO(34)			///obj/structure/table/ms13/metal/small
#define SMOOTH_GROUP_MS13_TABLE_PLAYER S_OBJ_FO(35) 	 	///obj/structure/table/ms13/metal/cobbled

#define SMOOTH_GROUP_MS13_SANDBAGS S_OBJ_FO(36) 	 	////obj/structure/ms13/sandbag
#define SMOOTH_GROUP_MS13_BONEPILE S_OBJ_FO(37) 	 	////obj/structure/ms13/bonepile

#define MAX_S_TURF_FO SMOOTH_GROUP_MS13_TABLE_PLAYER //Always match this value with the one above it.
