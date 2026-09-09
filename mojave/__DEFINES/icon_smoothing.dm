// AI EDIT: converted to DD's real string-based smoothing_groups format (S_TURF/S_OBJ, code/__DEFINES/icon_smoothing.dm)
// instead of the old integer-arithmetic S_OBJ_FO/S_OBJ1 macros. Turf-only content (ground types, carpets, roofs)
// uses S_TURF; furniture/wall/window content (including turf walls that need to visually connect to matching
// low-wall furniture) uses S_OBJ, continuing DD's own numbering (turf max 56, obj max 71).

#define SMOOTH_GROUP_MS13_WALL S_OBJ(72)				///obj/structure/table/ms13/low_wall, /turf/closed/wall/ms13
#define SMOOTH_GROUP_MS13_WALL_METAL S_OBJ(73)		///obj/structure/table/ms13/low_wall/metal, /turf/closed/wall/ms13/metal
#define SMOOTH_GROUP_MS13_WALL_WOOD S_OBJ(74)		///obj/structure/table/ms13/low_wall/wood, /turf/closed/wall/ms13/wood
#define SMOOTH_GROUP_MS13_WALL_SCRAP S_OBJ(75)		///obj/structure/table/ms13/low_wall/scrap, /turf/closed/wall/ms13/scrap
#define SMOOTH_GROUP_MS13_WALL_ADOBE S_OBJ(76)		///obj/structure/table/ms13/low_wall/adobe, /turf/closed/wall/ms13/adobe
#define SMOOTH_GROUP_MS13_WALL_BRICK S_OBJ(77)		///obj/structure/table/ms13/low_wall/brick, /turf/closed/wall/ms13/brick
#define SMOOTH_GROUP_MS13_WALL_REINFORCED S_OBJ(78)	///obj/structure/table/ms13/low_wall/reinforced, /turf/closed/wall/ms13
#define SMOOTH_GROUP_MS13_MINERALS S_OBJ(79)			///turf/closed/mineral/random/ms13, /turf/closed/indestructible/rock/ms13
#define SMOOTH_GROUP_MS13_WINDOW S_OBJ(80)			///obj/structure/window/fulltile/ms13/glass

#define SMOOTH_GROUP_MS13_DESERT S_TURF(57)			///turf/open/floor/plating/ground/desert
#define SMOOTH_GROUP_MS13_SNOW S_TURF(58)			///turf/open/floor/plating/ms13/ground/snow
#define SMOOTH_GROUP_MS13_ROAD S_TURF(59)			///turf/open/floor/plating/ground/road
#define SMOOTH_GROUP_MS13_SIDEWALK S_TURF(60)			///turf/open/floor/plating/ground/sidewalk
#define SMOOTH_GROUP_MS13_TILE S_TURF(61)			///turf/open/floor/wood/ms13, /turf/open/floor/ms13/
#define SMOOTH_GROUP_MS13_ICE S_TURF(62)			///turf/open/floor/plating/ms13/ground/ice
#define SMOOTH_GROUP_MS13_WATER S_TURF(63)		///turf/open/ms13/water

#define SMOOTH_GROUP_MS13_LOW_WALL S_OBJ(81)			///obj/structure/table/ms13/low_wall
#define SMOOTH_GROUP_MS13_CARPET_RED S_TURF(64)			////turf/open/floor/wood/ms13/carpet/red
#define SMOOTH_GROUP_MS13_CARPET_BLUE S_TURF(65)			////turf/open/floor/wood/ms13/carpet/blue
#define SMOOTH_GROUP_MS13_CARPET_GREEN S_TURF(66)			////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_VIOLET S_TURF(67)			////turf/open/floor/wood/ms13/carpet/violet
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_RED S_TURF(68)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_BLUE S_TURF(69)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_GREEN S_TURF(70)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_CARPET_SHAGGY_VIOLET S_TURF(71)		////turf/open/floor/wood/ms13/carpet/green
#define SMOOTH_GROUP_MS13_ROOF_NORMAL S_TURF(72)			////turf/open/floor/plating/roof
#define SMOOTH_GROUP_MS13_ROOF_SHEET S_TURF(73)			////turf/open/floor/plating/roof/sheet
#define SMOOTH_GROUP_MS13_ROOF_METAL S_TURF(74)			////turf/open/floor/plating/roof/metal
#define SMOOTH_GROUP_MS13_ROOF_WOOD S_TURF(75)			////turf/open/floor/plating/roof/wood
#define SMOOTH_GROUP_MS13_GLASS S_OBJ(82)			///obj/structure/ms13/glassfloor

#define SMOOTH_GROUP_MS13_OPENSPACE S_TURF(76)			///turf/open/openspace/ms13

#define SMOOTH_GROUP_SOIL S_OBJ(83)					///obj/machinery/hydroponics/ms13/soil
#define SMOOTH_GROUP_MS13_TABLE_METAL S_OBJ(84)			///obj/structure/table/ms13
#define SMOOTH_GROUP_MS13_TABLE_WOOD S_OBJ(85)			///obj/structure/table/ms13/wood
#define SMOOTH_GROUP_MS13_TABLE_SMALL S_OBJ(86)			///obj/structure/table/ms13/metal/small
#define SMOOTH_GROUP_MS13_TABLE_PLAYER S_OBJ(87) 	 	///obj/structure/table/ms13/metal/cobbled

#define SMOOTH_GROUP_MS13_SANDBAGS S_OBJ(88) 	 	////obj/structure/ms13/sandbag
#define SMOOTH_GROUP_MS13_BONEPILE S_OBJ(89) 	 	////obj/structure/ms13/bonepile
