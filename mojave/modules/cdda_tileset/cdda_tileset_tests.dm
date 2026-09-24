#ifdef UNIT_TESTS
/datum/unit_test/cdda_tileset_icons
	name = "ICONS: CDDA Tileset Types Point At Real Icon States"

/datum/unit_test/cdda_tileset_icons/Run()
	for(var/root in list(/turf/open/floor/plating/ms13/ground, /turf/open/floor/ms13, /obj/structure/flora/ms13, /obj/structure/ms13, /obj/structure/mineral_door, /obj/structure/window/fulltile/ms13))
		for(var/atom/path as anything in subtypesof(root))
			if(findtext("[path]", "/cdda/") && !icon_exists(initial(path.icon), initial(path.icon_state)))
				TEST_FAIL("[path] has no icon state \"[initial(path.icon_state)]\" in [initial(path.icon)].")
	for(var/turf/closed/wall/ms13/wall as anything in subtypesof(/turf/closed/wall/ms13))
		if(!findtext("[wall]", "/cdda/"))
			continue
		for(var/junction in list(0, 15, 255))
			if(!icon_exists(initial(wall.icon), "[initial(wall.base_icon_state)]-[junction]"))
				TEST_FAIL("[wall] is missing smoothing state [junction].")
#endif
