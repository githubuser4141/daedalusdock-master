// One small test covers the four skins plus the shared controller's spawn and expansion path.
/datum/unit_test/ms13_terrain_hiveminds
	name = "MOJAVE SUN: Terrain Hivemind Framework"

/datum/unit_test/ms13_terrain_hiveminds/Run()
	var/concrete_variants = 0
	for(var/hive_type in subtypesof(/datum/ms13_terrain_hivemind))
		var/datum/ms13_terrain_hivemind/network = new hive_type
		if(network.abstract)
			qdel(network)
			continue
		concrete_variants++
		TEST_ASSERT(network.terrain_icon && network.terrain_icon_state, "[network.name] has no terrain appearance.")
		TEST_ASSERT(network.core_icon && network.core_icon_state, "[network.name] has no core appearance.")
		TEST_ASSERT(network.wall_icon && network.wall_icon_state, "[network.name] has no wall appearance.")
		TEST_ASSERT(network.trap_icon && network.trap_icon_state, "[network.name] has no trap appearance.")
		TEST_ASSERT(network.turret_icon && network.turret_icon_state, "[network.name] has no turret appearance.")
		TEST_ASSERT(network.spawner_icon && network.spawner_icon_state, "[network.name] has no generator appearance.")
		TEST_ASSERT(network.mob_icon && network.mob_icon_state, "[network.name] has no unit appearance.")
		TEST_ASSERT(ispath(network.core_type, /obj/structure/ms13_hivemind/core), "[network.name] has an invalid core type.")
		TEST_ASSERT(ispath(network.terrain_type, /obj/structure/ms13_hivemind/terrain), "[network.name] has an invalid terrain type.")
		TEST_ASSERT(ispath(network.mob_type, /mob/living/simple_animal/hostile/ms13/terrain_hivemind), "[network.name] has an invalid unit type.")
		TEST_ASSERT(network.resource_per_tile > 0 && network.expansion_cost > 0 && network.special_cost > 0 && network.unit_cost > 0, "[network.name] has a broken resource economy.")
		TEST_ASSERT(length(network.special_types) == 4, "[network.name] must expose walls, traps, turrets, and unit generators.")
		qdel(network)

	TEST_ASSERT_EQUAL(concrete_variants, 4, "The prototype should expose blob, flock, necromorph, and Eris variants.")

	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	TEST_ASSERT(isopenturf(origin) && !origin.density, "The unit-test area has no open turf for a live hivemind check.")
	var/datum/ms13_terrain_hivemind/blob/live_network = new(origin, 20)
	TEST_ASSERT(live_network.core && !QDELETED(live_network.core), "Starting a concrete network did not create its core.")
	TEST_ASSERT(length(live_network.territory), "Starting a concrete network did not claim any nearby terrain.")
	var/old_territory_size = length(live_network.territory)
	live_network.resources = live_network.expansion_cost
	TEST_ASSERT(live_network.try_expand(), "A funded network with frontier tiles could not expand.")
	TEST_ASSERT_EQUAL(length(live_network.territory), old_territory_size + 1, "Expansion did not add exactly one terrain tile.")
	TEST_ASSERT_EQUAL(live_network.resources, 0, "Expansion did not spend its configured resource cost.")

	var/obj/structure/ms13_hivemind/terrain/claimed_growth = live_network.territory[1]
	var/turf/claimed_turf = get_turf(claimed_growth)
	var/obj/structure/ms13_hivemind/special/wall/test_wall = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/test_unit = new(claimed_turf, live_network)
	TEST_ASSERT(test_wall in live_network.specials, "Special structures do not register with their network.")
	TEST_ASSERT(test_unit in live_network.units, "Spawned units do not register with their network.")
	qdel(test_wall)
	qdel(test_unit)
	var/list/growths_to_clean = live_network.territory.Copy()
	qdel(live_network)
	QDEL_LIST(growths_to_clean)
