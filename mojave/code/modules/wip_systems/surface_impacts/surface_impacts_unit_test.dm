// One compact check covers the shared geometry and every configured content pool.
/datum/unit_test/ms13_surface_impacts
	name = "MOJAVE SUN: Surface Impact Configuration"

/datum/unit_test/ms13_surface_impacts/Run()
	var/concrete_variants = 0
	var/elite_variants = 0
	for(var/impact_type in subtypesof(/datum/ms13_surface_impact))
		var/datum/ms13_surface_impact/impact = new impact_type
		if(impact.abstract)
			qdel(impact)
			continue
		concrete_variants++
		elite_variants += impact.elite
		TEST_ASSERT(ispath(impact.floor_type, /turf/open), "[impact.name] has an invalid floor type.")
		TEST_ASSERT(length(impact.wall_types), "[impact.name] has no wall terrain pool.")
		for(var/wall_type in impact.wall_types)
			TEST_ASSERT(ispath(wall_type, /turf/closed), "[impact.name] has invalid wall terrain [wall_type].")
		for(var/mob_type in impact.mob_types)
			TEST_ASSERT(ispath(mob_type, /mob/living), "[impact.name] has invalid mob content [mob_type].")
		for(var/feature_type in impact.feature_types)
			TEST_ASSERT(ispath(feature_type, /atom/movable), "[impact.name] has invalid feature content [feature_type].")
		for(var/loot_type in impact.loot_types)
			TEST_ASSERT(ispath(loot_type, /obj/item), "[impact.name] has invalid loot content [loot_type].")
		TEST_ASSERT(impact.contains_offset(impact.radius, 0), "[impact.name] excludes its cardinal radius.")
		var/fits_standard = FALSE
		for(var/list/layout as anything in impact.layouts)
			fits_standard ||= impact.layout_fits(layout)
			for(var/list/cell as anything in impact.layout_cells(layout))
				TEST_ASSERT(findtext("#.+XMLF", cell[3]), "[impact.name] has a layout with an unknown symbol [cell[3]].")
			TEST_ASSERT_EQUAL(json_encode(impact.layout_cells(layout, 4)), json_encode(impact.layout_cells(layout)), "[impact.name]'s layouts don't turn round to where they started.")
		TEST_ASSERT(fits_standard, "[impact.name] has no layout that fits a standard impact.")
		TEST_ASSERT(!impact.contains_offset(impact.radius, 1), "[impact.name] generates a square instead of a circular footprint.")
		qdel(impact)

	TEST_ASSERT_EQUAL(concrete_variants, 10, "The prototype should expose five base themes and five elite variants.")
	TEST_ASSERT_EQUAL(elite_variants, 5, "Every base surface-impact theme should have an elite variant.")
	var/datum/ms13_surface_impact/natural/level_check = new
	var/surface = ms13_surface_z()
	TEST_ASSERT(level_check.is_impact_level(surface), "Impacts reject the surface.")
	if(surface != SSmapping.station_start)
		TEST_ASSERT(!level_check.is_impact_level(SSmapping.station_start), "Impacts accept the basement below the surface.")
	qdel(level_check)

	// A small raider fort, built out past the test room (too small for one) and put back after.
	var/datum/ms13_surface_impact/raider/fort = new
	fort.radius = 3
	var/turf/center = locate(run_loc_floor_top_right.x + 8, run_loc_floor_top_right.y + 8, run_loc_floor_top_right.z)
	fort.center_x = center.x
	fort.center_y = center.y
	fort.center_z = center.z
	var/list/footprint = fort.get_footprint(center)
	var/list/floors = list()
	for(var/turf/spot as anything in footprint)
		floors[spot] = spot.type
	var/list/spots = fort.build_structure(footprint.Copy())
	var/walls = 0
	for(var/turf/spot as anything in footprint)
		walls += spot.density
	var/doors = 0
	for(var/turf/spot as anything in footprint)
		doors += !!(locate(/obj/machinery/door) in spot)
	for(var/turf/spot as anything in floors)
		spot.ChangeTurf(floors[spot])
	qdel(fort)
	TEST_ASSERT(walls && doors, "A raider fort went up without walls or a door.")
	TEST_ASSERT(length(spots["M"]) && length(spots["L"]), "A raider fort asked for nowhere to put its raiders or loot.")

	var/turf/indicator_turf = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/obj/effect/temp_visual/ms13/target_indicator/indicator = new(indicator_turf)
	TEST_ASSERT(islist(indicator.smoothing_groups) && islist(indicator.canSmoothWith), "Impact indicators leave raw smoothing strings that make adjacent walls runtime.")
	qdel(indicator)
