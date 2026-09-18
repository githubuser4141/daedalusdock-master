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
		TEST_ASSERT(network.converter_icon && network.converter_icon_state, "[network.name] has no corpse-converter appearance.")
		TEST_ASSERT(length(network.unit_appearances) >= 5, "[network.name] must define scout, footsoldier, ranged, heavy, and infector appearances.")
		var/list/unique_appearances = list()
		for(var/role in network.unit_appearances)
			var/list/unit_appearance = network.unit_appearances[role]
			TEST_ASSERT(islist(unit_appearance) && unit_appearance["name"] && unit_appearance["icon"] && unit_appearance["state"], "[network.name] has an incomplete [role] appearance.")
			var/unit_icon = unit_appearance["icon"]
			var/unit_icon_state = unit_appearance["state"]
			TEST_ASSERT(unit_icon_state in icon_states(unit_icon), "[network.name] has an invalid [role] icon state.")
			unique_appearances["[unit_icon]|[unit_icon_state]"] = TRUE
		TEST_ASSERT_EQUAL(length(unique_appearances), length(network.unit_appearances), "[network.name] reuses a sprite between two unit roles.")
		TEST_ASSERT(ispath(network.core_type, /obj/structure/ms13_hivemind/core), "[network.name] has an invalid core type.")
		TEST_ASSERT(ispath(network.terrain_type, /obj/structure/ms13_hivemind/terrain), "[network.name] has an invalid terrain type.")
		TEST_ASSERT(ispath(network.converter_mob_type, /mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter), "[network.name] has an invalid converter unit type.")
		for(var/unit_type in network.mob_types + network.evolved_mob_types + network.elite_mob_types)
			TEST_ASSERT(ispath(unit_type, /mob/living/simple_animal/hostile/ms13/terrain_hivemind), "[network.name] has an invalid unit type.")
		if(network.terrain_smoothing_prefix)
			var/list/terrain_states = icon_states(network.terrain_icon)
			TEST_ASSERT("[network.terrain_smoothing_prefix]-0" in terrain_states, "[network.name] lacks its isolated smoothing state.")
			TEST_ASSERT("[network.terrain_smoothing_prefix]-255" in terrain_states, "[network.name] lacks its fully connected smoothing state.")
		if(istype(network, /datum/ms13_terrain_hivemind/eris))
			TEST_ASSERT_EQUAL(network.terrain_icon_state, "wires", "Machine-hive terrain is using a disconnected quarter-tile wire state.")
			TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide in network.evolved_mob_types, "The machine hive does not evolve its bomber unit.")
			TEST_ASSERT_EQUAL(network.unit_appearances["suicide"]["state"], "bomber", "The machine-hive bomber lacks its distinct sprite.")
		TEST_ASSERT(network.resource_per_tile > 0 && network.expansion_cost > 0 && network.special_cost > 0 && network.unit_cost > 0, "[network.name] has a broken resource economy.")
		TEST_ASSERT(network.structure_regeneration_rate > 0, "[network.name] does not regenerate damaged structures.")
		TEST_ASSERT(length(network.special_types) == 5, "[network.name] must expose walls, traps, turrets, unit generators, and corpse converters.")
		qdel(network)

	TEST_ASSERT_EQUAL(concrete_variants, 4, "The prototype should expose blob, flock, necromorph, and Eris variants.")

	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	TEST_ASSERT(isopenturf(origin) && !origin.density, "The unit-test area has no open turf for a live hivemind check.")
	var/datum/ms13_terrain_hivemind/blob/live_network = new(origin, 20)
	TEST_ASSERT(live_network.core && !QDELETED(live_network.core), "Starting a concrete network did not create its core.")
	var/obj/projectile/ms13_hivemind/friendly_shot = new
	friendly_shot.source_network = live_network
	TEST_ASSERT(live_network.core.CanAllowThrough(friendly_shot, NORTH), "A hive projectile cannot pass through its own core.")
	var/obj/projectile/ms13_hivemind/unaffiliated_shot = new
	TEST_ASSERT(!live_network.core.CanAllowThrough(unaffiliated_shot, NORTH), "A foreign projectile incorrectly passes through a hive core.")
	qdel(friendly_shot)
	qdel(unaffiliated_shot)
	TEST_ASSERT(length(live_network.territory), "Starting a concrete network did not claim any nearby terrain.")
	var/old_territory_size = length(live_network.territory)
	live_network.resources = live_network.expansion_cost
	TEST_ASSERT(live_network.try_expand(), "A funded network with frontier tiles could not expand.")
	TEST_ASSERT_EQUAL(length(live_network.territory), old_territory_size + 1, "Expansion did not add exactly one terrain tile.")
	TEST_ASSERT_EQUAL(live_network.resources, 0, "Expansion did not spend its configured resource cost.")
	live_network.evolved_unit_threshold = length(live_network.territory)
	live_network.elite_unit_threshold = length(live_network.territory)
	var/list/unlocked_types = live_network.get_available_unit_types()
	TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged in unlocked_types, "Growing territory did not unlock ranged units.")
	TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy in unlocked_types, "Growing territory did not unlock heavy units.")

	var/obj/structure/ms13_hivemind/terrain/claimed_growth = live_network.territory[1]
	var/turf/claimed_turf = get_turf(claimed_growth)
	var/obj/structure/ms13_hivemind/special/wall/test_wall = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier/test_unit = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout/test_scout = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged/test_ranged = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/test_heavy = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/test_worker = new(claimed_turf, live_network)
	TEST_ASSERT(test_wall in live_network.specials, "Special structures do not register with their network.")
	TEST_ASSERT(test_unit in live_network.units, "Spawned units do not register with their network.")
	TEST_ASSERT(test_scout.roam_range > test_unit.roam_range && test_scout.move_to_delay < test_unit.move_to_delay, "Scouts are not configured to range farther and move faster than footsoldiers.")
	TEST_ASSERT(test_unit.environment_smash & ENVIRONMENT_SMASH_STRUCTURES, "Standard hive units cannot break structures which contain their patrols.")
	TEST_ASSERT(test_ranged.ranged && test_ranged.projectiletype == live_network.ranged_projectile_type && test_ranged.minimum_distance > 1, "Ranged units are not configured to keep distance and use their theme projectile.")
	TEST_ASSERT((test_heavy.environment_smash & ENVIRONMENT_SMASH_WALLS) && test_heavy.obj_damage > test_unit.obj_damage, "Heavy units cannot breach walls more effectively than footsoldiers.")
	TEST_ASSERT_EQUAL(test_heavy.off_terrain_damage_multiplier, 0, "Heavy units still decay while ranging beyond hive terrain.")
	TEST_ASSERT(test_worker.off_terrain_damage_multiplier > 0 && test_worker.off_terrain_damage_multiplier < 1, "Corpse workers do not have reduced off-terrain decay.")
	TEST_ASSERT(test_worker.corpse_converter, "The dedicated converter unit did not initialize as a corpse worker.")
	TEST_ASSERT(!test_worker.force_opens_doors && test_unit.force_opens_doors, "Door forcing is not limited to combat-capable hive units.")
	var/mob/living/simple_animal/chicken/test_corpse = new(claimed_turf)
	test_corpse.set_stat(DEAD)
	test_unit.find_local_corpses()
	TEST_ASSERT_EQUAL(live_network.find_reported_corpse(test_worker), test_corpse, "A worker could not retrieve a corpse reported by another network member.")
	TEST_ASSERT(live_network.claim_corpse(test_corpse, test_worker), "A reported corpse could not be reserved by a worker.")
	test_worker.corpse_target_ref = WEAKREF(test_corpse)
	TEST_ASSERT(test_worker.has_adjacent_conversion_target(), "An infector does not recognize an adjacent claimed corpse as active work.")
	var/old_unit_count = length(live_network.units)
	TEST_ASSERT(live_network.advance_corpse_conversion(test_corpse, test_worker, 1, 1), "A fully progressed corpse was not converted.")
	TEST_ASSERT_EQUAL(length(live_network.units), old_unit_count + 1, "Corpse conversion did not create exactly one network unit.")
	var/mob/living/simple_animal/chicken/recycled_corpse = new(claimed_turf)
	recycled_corpse.set_stat(DEAD)
	live_network.max_units = length(live_network.units)
	live_network.resources = 0
	TEST_ASSERT(live_network.advance_corpse_conversion(recycled_corpse, test_worker, 1, 1), "A completed corpse stalled at the unit cap instead of being recycled.")
	TEST_ASSERT_EQUAL(live_network.resources, live_network.corpse_recycling_value, "A corpse recycled at the unit cap did not return resources.")
	var/turf/vehicle_turf
	for(var/obj/structure/ms13_hivemind/terrain/growth as anything in live_network.territory)
		if(get_turf(growth) != claimed_turf)
			vehicle_turf = get_turf(growth)
			break
	TEST_ASSERT(vehicle_turf, "The live network has no second turf for vehicle-aware spawning and targeting checks.")
	var/datum/ms13_ground_vehicle/test_vehicle = new
	var/obj/structure/ms13_vehicle_frame/test_frame = new(vehicle_turf)
	test_frame.vehicle = test_vehicle
	test_vehicle.frames += test_frame
	TEST_ASSERT(!live_network.can_spawn_unit_at(vehicle_turf), "Hive units can spawn inside a ground vehicle footprint.")
	var/obj/structure/window/ms13_vehicle_wall/solid/light_wall = new(vehicle_turf)
	light_wall.parent_frame = test_frame
	test_vehicle.walls += light_wall
	TEST_ASSERT(test_unit.is_vehicle_hull_target(light_wall), "A light vehicle hull is not a valid hive target.")
	var/obj/structure/window/ms13_vehicle_wall/solid/civ96/tank/tank_wall = new(vehicle_turf)
	tank_wall.parent_frame = test_frame
	test_vehicle.walls += tank_wall
	var/obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank/tank_door = new(vehicle_turf)
	tank_door.parent_frame = test_frame
	test_vehicle.walls += tank_door
	TEST_ASSERT(!test_unit.is_vehicle_hull_target(light_wall), "A hive unit still targets arbitrary plating on a tank-grade vehicle.")
	TEST_ASSERT(test_unit.is_vehicle_hull_target(tank_door), "A hive unit does not prioritize the hatch on a tank-grade vehicle.")
	qdel(tank_door)
	qdel(tank_wall)
	qdel(light_wall)
	qdel(test_frame)
	qdel(test_vehicle)
	qdel(test_wall)
	var/list/units_to_clean = live_network.units.Copy()
	var/list/growths_to_clean = live_network.territory.Copy()
	qdel(live_network)
	QDEL_LIST(units_to_clean)
	QDEL_LIST(growths_to_clean)

	var/datum/ms13_terrain_hivemind/necromorph/location_probe = new
	var/turf/hauling_origin
	for(var/turf/candidate in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		if(location_probe.can_claim(candidate))
			hauling_origin = candidate
			break
	qdel(location_probe)
	TEST_ASSERT(hauling_origin, "The unit-test area has no second claimable turf for corpse hauling.")
	var/datum/ms13_terrain_hivemind/necromorph/hauling_network = new(hauling_origin, 20)
	var/obj/structure/ms13_hivemind/terrain/hauling_growth = hauling_network.territory[1]
	var/turf/hauling_turf = get_turf(hauling_growth)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier/hauler = new(hauling_turf, hauling_network)
	var/mob/living/simple_animal/chicken/hauled_corpse = new(hauling_turf)
	hauled_corpse.set_stat(DEAD)
	TEST_ASSERT(hauler.handle_corpse_work(), "A necromorph hauler did not accept a nearby corpse task.")
	TEST_ASSERT(hauler.is_grabbing(hauled_corpse), "The hauler did not physically grab its corpse.")
	TEST_ASSERT_EQUAL(hauling_network.get_corpse_claim(hauled_corpse), hauler, "The hauling unit lost its corpse claim before delivery.")
	TEST_ASSERT(hauler.handle_corpse_work(), "A necromorph hauler did not deliver its grabbed corpse.")
	TEST_ASSERT_EQUAL(hauling_network.get_corpse_claim(hauled_corpse), hauling_network.core, "The hauler did not deliver its corpse claim to the nearest nest.")
	TEST_ASSERT(!hauler.is_grabbing(hauled_corpse), "The hauler did not release the corpse at its nest.")
	var/old_hauling_unit_count = length(hauling_network.units)
	var/old_hauling_capacity = hauling_network.max_resources
	hauling_network.process_structure_corpse(hauling_network.core, hauling_network.structure_conversion_time)
	TEST_ASSERT_EQUAL(length(hauling_network.units), old_hauling_unit_count + 1, "The nest did not convert its delivered corpse into a unit.")
	TEST_ASSERT_EQUAL(hauling_network.max_resources, old_hauling_capacity + hauling_network.corpse_capacity_value, "A delivered corpse did not expand the hive's resource capacity.")
	var/list/hauling_units_to_clean = hauling_network.units.Copy()
	var/list/hauling_growths_to_clean = hauling_network.territory.Copy()
	qdel(hauling_network)
	QDEL_LIST(hauling_units_to_clean)
	QDEL_LIST(hauling_growths_to_clean)
