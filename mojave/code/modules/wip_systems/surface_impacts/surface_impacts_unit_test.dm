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
		TEST_ASSERT(!impact.contains_offset(impact.radius, 1), "[impact.name] generates a square instead of a circular footprint.")
		qdel(impact)

	TEST_ASSERT_EQUAL(concrete_variants, 10, "The prototype should expose five base themes and five elite variants.")
	TEST_ASSERT_EQUAL(elite_variants, 5, "Every base surface-impact theme should have an elite variant.")
