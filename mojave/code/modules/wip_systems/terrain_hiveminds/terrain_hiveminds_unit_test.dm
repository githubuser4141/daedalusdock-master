// Shared movement/conversion regressions plus the hive themes and separate Marker content.

/obj/effect/ms13_marker_emp_test_probe
	var/pulses = 0
	var/last_severity

/obj/effect/ms13_marker_emp_test_probe/emp_act(severity)
	pulses++
	last_severity = severity

/datum/ai_controller/basic_controller/ms13/planner_test_probe
	var/plans = 0

/datum/ai_controller/basic_controller/ms13/planner_test_probe/ProcessBehaviorSelection(delta_time)
	plans++

/datum/unit_test/ms13_hive_combat
	name = "MOJAVE SUN: Hive Charges And NPC Explosion Damage"
	var/list/original_tiles = list()

/datum/unit_test/ms13_hive_combat/Destroy()
	// The shared test runner clears objects, but not turfs damaged by the live blast.
	for(var/list/tile in original_tiles)
		var/turf/current = locate(tile[1], tile[2], tile[3])
		current.ChangeTurf(tile[4], tile[5])
	return ..()

/datum/unit_test/ms13_hive_combat/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/turf/tile in RANGE_TURFS(4, origin))
		original_tiles += list(list(tile.x, tile.y, tile.z, tile.type, islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs))
	var/datum/ms13_terrain_hivemind/necromorph/network = new
	network.active = TRUE
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/charger = new(origin, network)
	var/mob/living/simple_animal/victim = allocate(/mob/living/simple_animal, locate(origin.x + 3, origin.y, origin.z))
	victim.maxHealth = 1000
	victim.health = 1000
	victim.set_density(TRUE)
	victim.toggle_ai(AI_OFF)
	charger.GiveTarget(victim)
	TEST_ASSERT(charger.try_hive_charge(), "An eligible brute never starts its special attack.")
	TEST_ASSERT(get_turf(charger) != origin, "A charging brute never moves.")
	TEST_ASSERT(victim.health < 1000, "A charge collides without hurting the hostile victim.")
	TEST_ASSERT(!length(charger.hive_charge.charging), "A completed charge leaves the mob movement-locked.")
	TEST_ASSERT(!charger.hive_charge.IsAvailable(), "A completed charge has no cooldown.")
	qdel(charger)
	victim.forceMove(origin)
	victim.health = 1000
	var/turf_tally = 0
	var/movable_tally = 0
	var/list/blast_tiles = list()
	blast_tiles[origin] = 2
	SSexplosions.perform_explosion(origin, blast_tiles, 2, 3, 0, &turf_tally, &movable_tally, null)
	TEST_ASSERT(victim.health < 1000, "Explosion processing skips non-simulated simple animals.")
	TEST_ASSERT(turf_tally == 1 && movable_tally >= 1, "Explosion processing did not visit its NPC tile.")
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide/necromorph/exploder = new(get_turf(victim), network)
	TEST_ASSERT(exploder.blast_heavy_range >= 1 && exploder.blast_light_range >= 3, "A necromorph exploder has only a cosmetic blast.")
	var/health_before_blast = victim.health
	exploder.AttackingTarget(victim)
	sleep(1 SECONDS)
	TEST_ASSERT(QDELETED(exploder) && victim.health < health_before_blast, "A necromorph exploder disappears without causing actual blast damage.")
	qdel(network)

/datum/unit_test/ms13_terrain_hiveminds
	name = "MOJAVE SUN: Terrain Hivemind Framework"

/datum/unit_test/ms13_terrain_hiveminds/Run()
	var/datum/move_loop/has_target/jps/deleted_route = new
	var/datum/callback/pending_route_callback = deleted_route.on_finish_callback
	qdel(deleted_route)
	TEST_ASSERT(!pending_route_callback.object, "A deleted JPS route is retained by its completion callback.")
	var/datum/move_loop/has_target/astar/deleted_astar_route = new
	var/datum/callback/pending_astar_callback = deleted_astar_route.on_finish_callback
	qdel(deleted_astar_route)
	TEST_ASSERT(!pending_astar_callback.object, "A deleted A* route is retained by its completion callback.")
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
			var/isolated_state = "[network.terrain_smoothing_prefix][network.terrain_smoothing_separator]0"
			var/connected_state = "[network.terrain_smoothing_prefix][network.terrain_smoothing_separator][network.terrain_smoothing_diagonals ? 255 : 15]"
			TEST_ASSERT(isolated_state in terrain_states, "[network.name] lacks its isolated smoothing state.")
			TEST_ASSERT(connected_state in terrain_states, "[network.name] lacks its fully connected smoothing state.")
		if(istype(network, /datum/ms13_terrain_hivemind/eris))
			TEST_ASSERT_EQUAL(network.terrain_icon_state, "wires", "Machine-hive terrain is using a disconnected quarter-tile wire state.")
			TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide in network.evolved_mob_types, "The machine hive does not evolve its bomber unit.")
			TEST_ASSERT_EQUAL(network.unit_appearances["suicide"]["state"], "bomber", "The machine-hive bomber lacks its distinct sprite.")
		if(istype(network, /datum/ms13_terrain_hivemind/necromorph))
			TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/siege in network.elite_mob_types, "Necromorph evolution does not unlock its tripod.")
			TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide/necromorph in network.elite_mob_types, "Necromorph evolution does not unlock its exploder.")
			TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/regenerator in network.elite_mob_types, "Necromorph evolution does not unlock its hunter.")
		if(istype(network, /datum/ms13_terrain_hivemind/xenomorph))
			TEST_ASSERT(network.converts_living_hosts && !network.converts_dead_hosts, "The xenomorph hive is not configured for living hosts.")
			TEST_ASSERT(network.captures_knocked_down_hosts, "The xenomorph hive still attacks knocked-down living hosts.")
			TEST_ASSERT(!network.converter_unit_enabled && !network.terrain_conversion_time, "Xenomorph hosts should incubate in nests rather than convert anywhere on weeds.")
			TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler in network.evolved_mob_types, "The xenomorph hive does not evolve its carrier unit.")
			TEST_ASSERT(/obj/structure/ms13_hivemind/special/xenomorph_egg in network.special_types, "The xenomorph hive cannot grow its one-use facehugger egg.")
			TEST_ASSERT(network.can_cross_low_walls && network.can_haul_over_low_walls, "Xenomorphs cannot vault low walls while hauling hosts.")
			TEST_ASSERT_EQUAL(network.mob_off_terrain_damage, 0, "Xenomorphs lose health away from friendly terrain.")
			TEST_ASSERT_EQUAL(network.mob_orphan_damage, 0, "Xenomorphs lose health after their core is destroyed.")
		TEST_ASSERT(network.resource_per_tile > 0 && network.expansion_cost > 0 && network.special_cost > 0 && network.unit_cost > 0, "[network.name] has a broken resource economy.")
		TEST_ASSERT(network.structure_regeneration_rate > 0, "[network.name] does not regenerate damaged structures.")
		TEST_ASSERT(length(network.special_types) == 5, "[network.name] must expose walls, traps, turrets, unit generators, and corpse converters.")
		qdel(network)

	TEST_ASSERT_EQUAL(concrete_variants, 6, "The prototype should expose the five hive themes plus the separate necromorph Marker.")

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
	TEST_ASSERT_EQUAL(test_unit.AIStatus, AI_ON, "A lone new hive unit starts asleep.")
	TEST_ASSERT(!test_unit.AIShouldSleep(list()), "An active hive waits for players when no combat target is present.")
	for(var/sleep_state in list(AI_IDLE, AI_Z_OFF))
		test_unit.toggle_ai(sleep_state)
		test_unit.consider_wakeup()
		TEST_ASSERT_EQUAL(test_unit.AIStatus, AI_ON, "A hive cannot wake from state [sleep_state] without a living player.")
	test_unit.toggle_ai(AI_OFF)
	test_unit.consider_wakeup()
	TEST_ASSERT_EQUAL(test_unit.AIStatus, AI_OFF, "Hive wakeup overrides an explicit AI shutdown.")
	test_unit.toggle_ai(AI_ON)
	var/mob/dead/observer/ghost_host = new(claimed_turf)
	TEST_ASSERT(!live_network.is_convertible_corpse(ghost_host), "A hive considers an observer a convertible corpse.")
	qdel(ghost_host)
	var/mob/living/simple_animal/hostile/ms13/wildlife = new(get_step(claimed_turf, SOUTH))
	wildlife.toggle_ai(AI_IDLE)
	wildlife.consider_wakeup()
	TEST_ASSERT_EQUAL(wildlife.AIStatus, AI_ON, "An idle MS NPC ignores a visible hive without a player present.")
	TEST_ASSERT(wildlife.CanAttack(test_unit), "An ordinary MS NPC cannot attack a hostile hive unit.")
	qdel(wildlife)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/recovering_converter = new(claimed_turf, live_network)
	for(var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/recovering_unit in list(test_unit, recovering_converter))
		recovering_unit.health = recovering_unit.maxHealth * 0.3
		TEST_ASSERT(recovering_unit.handle_terrain_recovery(TRUE), "A wounded hive unit does not begin recovery on friendly terrain.")
		recovering_unit.health = recovering_unit.maxHealth * 0.6
		TEST_ASSERT(recovering_unit.handle_terrain_recovery(TRUE), "A recovering hive unit leaves before healing to its exit threshold.")
		recovering_unit.health = recovering_unit.maxHealth * 0.8
		TEST_ASSERT(!recovering_unit.handle_terrain_recovery(TRUE) && !recovering_unit.terrain_recovering, "A healed hive unit does not resume activity.")
		recovering_unit.health = recovering_unit.maxHealth * 0.6
		TEST_ASSERT(!recovering_unit.handle_terrain_recovery(TRUE), "A moderately injured, non-recovering unit retreats too early.")
		recovering_unit.health = recovering_unit.maxHealth
	qdel(recovering_converter)
	var/list/initial_targets = test_unit.ListTargets()
	var/initial_target_count = length(initial_targets)
	initial_targets.Cut()
	TEST_ASSERT_EQUAL(length(test_unit.ListTargets()), initial_target_count, "A caller can corrupt the cached target list.")
	COOLDOWN_START(test_unit, roam_retry_cooldown, 5 SECONDS)
	TEST_ASSERT(test_unit.handle_roaming() && !test_unit.roam_target, "An idle unit starts another route during its failed-route backoff.")
	COOLDOWN_RESET(test_unit, roam_retry_cooldown)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout/test_scout = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged/test_ranged = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/test_heavy = new(claimed_turf, live_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/test_worker = new(claimed_turf, live_network)
	TEST_ASSERT(test_wall in live_network.specials, "Special structures do not register with their network.")
	TEST_ASSERT(!live_network.can_spawn_unit_at(claimed_turf), "Unit spawning ignores dense contents on a hive tile.")
	TEST_ASSERT(test_wall.CanAllowThrough(test_unit, NORTH), "A hive wall blocks a unit belonging to its own network.")
	var/obj/structure/low_wall/test_low_wall = new(claimed_turf)
	TEST_ASSERT(test_low_wall.CanAllowThrough(test_unit, NORTH), "Blob units cannot pass over a low wall.")
	TEST_ASSERT(test_unit in live_network.units, "Spawned units do not register with their network.")
	TEST_ASSERT(test_scout.roam_range > test_unit.roam_range && test_scout.move_to_delay < test_unit.move_to_delay, "Scouts are not configured to range farther and move faster than footsoldiers.")
	TEST_ASSERT(test_unit.environment_smash & ENVIRONMENT_SMASH_STRUCTURES, "Standard hive units cannot break structures which contain their patrols.")
	TEST_ASSERT(test_ranged.ranged && test_ranged.projectiletype == live_network.ranged_projectile_type && test_ranged.minimum_distance > 1, "Ranged units are not configured to keep distance and use their theme projectile.")
	TEST_ASSERT((test_heavy.environment_smash & ENVIRONMENT_SMASH_WALLS) && test_heavy.obj_damage > test_unit.obj_damage, "Heavy units cannot breach walls more effectively than footsoldiers.")
	TEST_ASSERT_EQUAL(test_heavy.off_terrain_damage_multiplier, 0, "Heavy units still decay while ranging beyond hive terrain.")
	TEST_ASSERT(test_worker.off_terrain_damage_multiplier > 0 && test_worker.off_terrain_damage_multiplier < 1, "Corpse workers do not have reduced off-terrain decay.")
	TEST_ASSERT(test_worker.corpse_converter, "The dedicated converter unit did not initialize as a corpse worker.")
	TEST_ASSERT(!test_worker.force_opens_doors && test_unit.force_opens_doors, "Door forcing is not limited to combat-capable hive units.")
	var/obj/machinery/door/unpowered/ms13/metal/pry_door = new(get_step(claimed_turf, NORTH))
	pry_door.locked = TRUE
	TEST_ASSERT(test_unit.begin_door_pry(pry_door), "A hive unit cannot begin prying a locked Mojave door.")
	test_unit.door_pry_started = world.time - 3 SECONDS
	TEST_ASSERT(test_unit.handle_door_pry() && !pry_door.density && !test_unit.prying_door_ref, "Prying does not open a locked Mojave door and release the unit.")
	qdel(pry_door)
	var/obj/machinery/door/airlock/blocked_door = new(get_step(claimed_turf, NORTH))
	blocked_door.locked = TRUE
	var/turf/bypass_site = get_step(blocked_door, EAST)
	var/old_bypass_type = bypass_site.type
	bypass_site = bypass_site.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(test_unit.begin_door_pry(blocked_door), "A hive unit cannot attempt a blocked airlock.")
	test_unit.door_pry_started = world.time - 9 SECONDS
	TEST_ASSERT(!test_unit.handle_door_pry(), "A failed pry never times out.")
	TEST_ASSERT(live_network.door_breach_requests[WEAKREF(blocked_door)], "A failed pry does not report a bypass to wall-breakers.")
	test_heavy.forceMove(get_step(bypass_site, SOUTH))
	TEST_ASSERT(test_heavy.handle_door_breach_requests(), "A nearby heavy ignores a reported blocked door.")
	TEST_ASSERT(!get_step(blocked_door, EAST).density && !length(live_network.door_breach_requests), "Opening a wall bypass does not clear the door request.")
	get_step(blocked_door, EAST).ChangeTurf(old_bypass_type)
	test_heavy.forceMove(claimed_turf)
	qdel(blocked_door)
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
	var/mob/living/simple_animal/chicken/stale_target_corpse = new(claimed_turf)
	stale_target_corpse.set_stat(DEAD)
	test_unit.GiveTarget(stale_target_corpse)
	TEST_ASSERT(test_unit.release_finished_target(), "A hive unit did not release a finished combat target for corpse work.")
	TEST_ASSERT(!test_unit.target, "A dead combat target remained assigned and stalled the hive AI.")
	qdel(stale_target_corpse)
	var/mob/living/simple_animal/chicken/failed_haul_corpse = new(claimed_turf)
	failed_haul_corpse.set_stat(DEAD)
	TEST_ASSERT(live_network.claim_corpse(failed_haul_corpse, test_unit), "The failed-haul test could not reserve its corpse.")
	test_unit.corpse_target_ref = WEAKREF(failed_haul_corpse)
	test_unit.clear_corpse_task(FALSE)
	TEST_ASSERT(!live_network.get_corpse_claim(failed_haul_corpse), "Abandoning a failed grab left its corpse permanently claimed.")
	qdel(failed_haul_corpse)
	var/mob/living/simple_animal/chicken/dead_worker_corpse = new(claimed_turf)
	dead_worker_corpse.set_stat(DEAD)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/doomed_worker = new(claimed_turf, live_network)
	TEST_ASSERT(live_network.claim_corpse(dead_worker_corpse, doomed_worker), "The dead-worker test could not reserve its corpse.")
	doomed_worker.corpse_target_ref = WEAKREF(dead_worker_corpse)
	doomed_worker.death()
	TEST_ASSERT(!live_network.get_corpse_claim(dead_worker_corpse), "A dead corpse worker left its assignment permanently claimed.")
	qdel(dead_worker_corpse)
	qdel(doomed_worker)
	var/obj/structure/ms13_hivemind/special/converter/doomed_converter = new(claimed_turf, live_network)
	var/mob/living/simple_animal/chicken/converter_corpse_one = new(claimed_turf)
	var/mob/living/simple_animal/chicken/converter_corpse_two = new(claimed_turf)
	converter_corpse_one.set_stat(DEAD)
	converter_corpse_two.set_stat(DEAD)
	TEST_ASSERT(live_network.claim_corpse(converter_corpse_one, doomed_converter) && live_network.claim_corpse(converter_corpse_two, doomed_converter), "The destroyed-converter test could not reserve both corpses.")
	qdel(doomed_converter)
	TEST_ASSERT(!live_network.get_corpse_claim(converter_corpse_one) && !live_network.get_corpse_claim(converter_corpse_two), "A destroyed converter left queued corpses permanently claimed.")
	qdel(converter_corpse_one)
	qdel(converter_corpse_two)
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
	qdel(test_low_wall)
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

	var/datum/ms13_terrain_hivemind/xenomorph/xeno_network = new(hauling_origin, 20)
	var/mob/dead/observer/xeno_ghost = new(hauling_origin)
	TEST_ASSERT(!xeno_network.is_convertible_corpse(xeno_ghost), "The living-host override accepts ghosts.")
	qdel(xeno_ghost)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/charger = new(hauling_origin, xeno_network)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout/pouncer = new(hauling_origin, xeno_network)
	TEST_ASSERT(charger.hive_charge && pouncer.hive_charge, "Crushers or runners have no special attack.")
	TEST_ASSERT(charger.hive_charge.charge_damage > pouncer.hive_charge.charge_damage, "Pounce and ram use identical damage.")
	var/friendly_health = pouncer.health
	charger.hive_charge.hit_target(charger, pouncer, 35)
	TEST_ASSERT_EQUAL(pouncer.health, friendly_health, "A charge damages an allied unit.")
	var/mob/living/simple_animal/chicken/charge_host = new(hauling_origin)
	charge_host.health = 5
	charger.hive_charge.hit_target(charger, charge_host, 35)
	TEST_ASSERT(charge_host.stat != DEAD && charge_host.health == 5 && charge_host.IsParalyzed(), "A xenomorph charge kills a capturable NPC.")
	charger.clear_corpse_task()
	qdel(charge_host)
	qdel(charger)
	qdel(pouncer)
	var/obj/structure/ms13_hivemind/terrain/xeno_growth = xeno_network.territory[1]
	var/turf/xeno_turf = get_turf(xeno_growth)
	// Use two unobstructed resin tiles; the first registered growth may contain the dense core.
	for(var/obj/structure/ms13_hivemind/terrain/candidate as anything in xeno_network.territory)
		var/turf/candidate_turf = get_turf(candidate)
		var/turf/north_turf = get_step(candidate_turf, NORTH)
		if(xeno_network.can_spawn_unit_at(candidate_turf) && xeno_network.is_territory(north_turf) && xeno_network.can_spawn_unit_at(north_turf))
			xeno_turf = candidate_turf
			break
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler/xeno_carrier = new(xeno_turf, xeno_network)
	// Path searches can yield: do not let the live AI deliver/nest this host between movement assertions.
	xeno_carrier.toggle_ai(AI_OFF)
	var/mob/living/simple_animal/chicken/living_host = new(xeno_turf)
	living_host.Paralyze(10 MINUTES, TRUE)
	TEST_ASSERT(xeno_network.is_convertible_corpse(living_host), "A disabled living host is not valid xenomorph feedstock.")
	TEST_ASSERT(!xeno_carrier.CanAttack(living_host), "A xenomorph carrier attacks a reservable living host instead of reporting it.")
	TEST_ASSERT(xeno_carrier.handle_corpse_work(), "A xenomorph carrier did not accept a living-host hauling task.")
	TEST_ASSERT(xeno_carrier.is_grabbing(living_host), "The xenomorph carrier did not physically grab its living host.")
	var/obj/structure/low_wall/xeno_low_wall = new(xeno_turf)
	TEST_ASSERT(xeno_low_wall.CanAllowThrough(living_host, NORTH), "A xenomorph carrier cannot drag its host over a low wall.")
	var/obj/structure/table/ms13/low_wall/metal/mojave_low_wall = new(get_step(xeno_turf, NORTH))
	var/datum/can_pass_info/carrier_pass = new(xeno_carrier)
	var/datum/can_pass_info/host_pass = new(living_host)
	TEST_ASSERT(mojave_low_wall.CanAllowThrough(xeno_carrier, NORTH) && mojave_low_wall.CanAllowThrough(living_host, NORTH), "Mojave table-derived low walls block carriers or their hosts.")
	TEST_ASSERT(mojave_low_wall.CanAStarPass(NORTH, carrier_pass) && mojave_low_wall.CanAStarPass(NORTH, host_pass), "Pathfinding disagrees with actual low-wall traversal.")
	var/old_wall_integrity = mojave_low_wall.atom_integrity
	xeno_carrier.DestroyObjectsInDirection(NORTH)
	TEST_ASSERT_EQUAL(mojave_low_wall.atom_integrity, old_wall_integrity, "A hive creature damages a traversable low wall.")
	var/list/low_wall_path = jps_path_to(xeno_carrier, mojave_low_wall, max_steps = 10, mintargetdist = 0)
	TEST_ASSERT(length(low_wall_path), "A carrier cannot plan a route over a Mojave low wall while hauling.")
	TEST_ASSERT(xeno_carrier.Move(get_turf(mojave_low_wall), NORTH), "A carrier cannot actually cross a Mojave low wall.")
	TEST_ASSERT(xeno_carrier.is_grabbing(living_host), "Crossing a low wall drops the captive host.")
	TEST_ASSERT(xeno_carrier.Move(xeno_turf, SOUTH), "A carrier cannot return from a Mojave low wall.")
	qdel(mojave_low_wall)
	var/obj/structure/table/ms13/wood/test_table = new(get_step(xeno_turf, NORTH))
	var/obj/structure/railing/ms13/solo/test_rail = new(get_turf(test_table))
	test_rail.setDir(SOUTH)
	TEST_ASSERT(test_table.CanAStarPass(NORTH, carrier_pass) && test_rail.CanAStarPass(SOUTH, carrier_pass), "Xenomorph pathfinding cannot cross tables and guard rails.")
	TEST_ASSERT(xeno_carrier.Move(get_turf(test_table), NORTH) && xeno_carrier.Move(xeno_turf, SOUTH), "A xenomorph cannot enter and leave a guarded table.")
	TEST_ASSERT(xeno_carrier.is_grabbing(living_host), "Crossing a guarded table loses the host.")
	qdel(test_table)
	qdel(test_rail)
	qdel(carrier_pass)
	qdel(host_pass)
	TEST_ASSERT(xeno_carrier.handle_corpse_work(), "The xenomorph carrier did not deliver its living host to a nest.")
	var/obj/structure/ms13_hivemind/xenomorph_nest/xeno_nest = locate() in get_turf(living_host)
	TEST_ASSERT(xeno_nest, "Delivering a living host on resin did not form a nest around it.")
	TEST_ASSERT_EQUAL(xeno_network.get_corpse_claim(living_host), xeno_nest, "The delivered living host was not reserved by its resin nest.")
	var/old_xeno_unit_count = length(xeno_network.units)
	xeno_nest.process(xeno_network.structure_conversion_time)
	TEST_ASSERT(QDELETED(living_host), "A simple NPC host was not gibbed on chestburst.")
	TEST_ASSERT(!xeno_network.is_convertible_corpse(living_host), "A xenomorph nest can incubate the same dead host twice.")
	TEST_ASSERT_EQUAL(length(xeno_network.units), old_xeno_unit_count + 1, "A completed living-host incubation did not birth one xenomorph.")
	qdel(xeno_low_wall)
	var/mob/living/simple_animal/chicken/capture_host = new(xeno_turf)
	capture_host.health = 5
	TEST_ASSERT(xeno_carrier.try_capture_npc(capture_host), "Xenomorphs fail to subdue a wounded NPC.")
	TEST_ASSERT(capture_host.IsParalyzed() && capture_host.stat != DEAD && capture_host.health == 5, "Capturing an NPC killed or damaged it instead of restraining it.")
	TEST_ASSERT_EQUAL(xeno_network.get_corpse_claim(capture_host), xeno_carrier, "Capturing an NPC did not reserve it for its carrier.")
	TEST_ASSERT_EQUAL(xeno_carrier.corpse_target_ref?.resolve(), capture_host, "Capturing an NPC did not assign the hauling task.")
	xeno_carrier.clear_corpse_task()
	qdel(capture_host)
	var/mob/living/basic/ms13/ghoul/nested_ghoul = new(xeno_turf)
	var/datum/ai_controller/ghoul_controller = nested_ghoul.ai_controller
	var/datum/move_loop/has_target/dist_bound/immobile_route = new(null, null, nested_ghoul, extra_info = ghoul_controller)
	immobile_route.target = get_step(xeno_turf, NORTH)
	ADD_TRAIT(nested_ghoul, TRAIT_IMMOBILIZED, "hive_test")
	TEST_ASSERT(ghoul_controller.ai_movement.pre_move(immobile_route) & MOVELOOP_SKIP_STEP, "Table-vaulting AI ignores immobilization.")
	REMOVE_TRAIT(nested_ghoul, TRAIT_IMMOBILIZED, "hive_test")
	qdel(immobile_route)
	var/obj/structure/ms13_hivemind/xenomorph_nest/ghoul_nest = new(xeno_turf, xeno_network, nested_ghoul)
	nested_ghoul.SetParalyzed(0, TRUE)
	TEST_ASSERT(HAS_TRAIT(nested_ghoul, TRAIT_IMMOBILIZED) && !nested_ghoul.ai_controller.able_to_run(), "Resin lets basic NPCs act after the short stun expires.")
	TEST_ASSERT(xeno_network.is_convertible_corpse(nested_ghoul), "A restrained nest host becomes ineligible when its stun expires.")
	qdel(ghoul_nest)
	TEST_ASSERT(!HAS_TRAIT(nested_ghoul, TRAIT_IMMOBILIZED) && !HAS_TRAIT(nested_ghoul, TRAIT_INCAPACITATED), "Destroying resin leaves its host permanently restrained.")
	var/datum/ai_controller/basic_controller/ms13/planner_test_probe/planner_probe = new(nested_ghoul)
	var/list/saved_planner_run = SSai_controllers.currentrun
	SSai_controllers.currentrun = list(planner_probe)
	SSai_controllers.fire(TRUE)
	TEST_ASSERT_EQUAL(planner_probe.plans, 1, "Resumed AI planning did not process its pending controller.")
	TEST_ASSERT(!length(SSai_controllers.currentrun), "Resumed AI planning did not consume the pending work list.")
	SSai_controllers.currentrun = saved_planner_run
	qdel(planner_probe)
	var/mob/living/simple_animal/chicken/ignored_corpse = new(xeno_turf)
	ignored_corpse.death()
	for(var/controller_type in list(/datum/ai_controller/basic_controller/ms13/ghoul, /datum/ai_controller/basic_controller/ms13/hostile_animal, /datum/ai_controller/basic_controller/ms13/raider, /datum/ai_controller/basic_controller/ms13/robot, /datum/ai_controller/basic_controller/ms13/robot/gunner))
		var/datum/ai_controller/test_controller = new controller_type(nested_ghoul)
		TEST_ASSERT_EQUAL(test_controller.blackboard[BB_TARGET_MINIMUM_STAT], DEAD, "[controller_type] no longer allows low-priority corpse attacks.")
		test_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, ignored_corpse)
		test_controller.ProcessBehaviorSelection(1)
		var/mob/living/chosen_threat = test_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		TEST_ASSERT(istype(chosen_threat) && chosen_threat.stat != DEAD, "[controller_type] stays on a corpse instead of a nearby living hive enemy.")
		qdel(test_controller)
	var/datum/ai_controller/basic_controller/ms13/robot/gunner/gunner_probe = new(nested_ghoul)
	var/datum/ai_planning_subtree/ms13_take_cover/cover_planner = SSai_controllers.ai_subtrees[/datum/ai_planning_subtree/ms13_take_cover]
	gunner_probe.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, ignored_corpse)
	cover_planner.SelectBehaviors(gunner_probe, 1)
	TEST_ASSERT(!gunner_probe.blackboard["ms13_next_cover_attempt"], "The gunner searches for cover from a corpse.")
	var/datum/ai_planning_subtree/ms13_combat_awareness/awareness = SSai_controllers.ai_subtrees[/datum/ai_planning_subtree/ms13_combat_awareness]
	gunner_probe.set_blackboard_key("ms13_last_known_turf", xeno_turf)
	gunner_probe.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, locate(xeno_turf.x > 12 ? xeno_turf.x - 12 : xeno_turf.x + 12, xeno_turf.y, xeno_turf.z))
	awareness.SelectBehaviors(gunner_probe, 1)
	TEST_ASSERT(!gunner_probe.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The gunner retains an unseen target and blocks new acquisition.")
	TEST_ASSERT_EQUAL(gunner_probe.blackboard["ms13_last_known_turf"], xeno_turf, "Losing sight erased the gunner's suppression memory.")
	qdel(gunner_probe)
	qdel(ignored_corpse)
	qdel(nested_ghoul)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout/helper_runner = new(xeno_turf, xeno_network)
	TEST_ASSERT(helper_runner.can_work_corpses(), "Idle runners cannot assist a hauling hive.")
	qdel(helper_runner)
	var/mob/living/simple_animal/chicken/implanted_host = new(xeno_turf)
	implanted_host.ms13_hive_implanted = TRUE
	var/datum/ms13_hive_incubation/incubation = new(implanted_host, xeno_network)
	TEST_ASSERT(xeno_network.is_convertible_corpse(implanted_host), "An implanted, awake host is ignored by the hive.")
	incubation.process(90)
	TEST_ASSERT(QDELETED(implanted_host), "Facehugger incubation does not gib its simple NPC host outside a nest.")
	TEST_ASSERT(!xeno_network.is_convertible_corpse(implanted_host), "A completed facehugger host can be reused.")
	// The corner fixture has few spawn tiles; previous births must not occupy all of them.
	for(var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/previous_birth as anything in xeno_network.units.Copy())
		if(previous_birth != xeno_carrier)
			qdel(previous_birth)
	TEST_ASSERT(xeno_network.get_unit_spawn_turf(get_turf(xeno_network.core)), "The core-spawn test has no free spawn tile.")
	var/units_before_core_spawn = length(xeno_network.units)
	xeno_network.resources = xeno_network.unit_cost
	// Earlier movement checks yield; the live subsystem may already have ticked the core.
	COOLDOWN_RESET(xeno_network, core_spawn_cooldown)
	xeno_network.process(0)
	TEST_ASSERT_EQUAL(length(xeno_network.units), units_before_core_spawn + 1, "A funded core cannot spawn units without a separate generator.")
	TEST_ASSERT_EQUAL(xeno_network.resources, 0, "Core spawning did not spend its resource cost.")
	var/list/xeno_units_to_clean = xeno_network.units.Copy()
	var/list/xeno_growths_to_clean = xeno_network.territory.Copy()
	var/old_carrier_health = xeno_carrier.health
	qdel(xeno_network)
	xeno_carrier.process(1)
	TEST_ASSERT_EQUAL(xeno_carrier.health, old_carrier_health, "A xenomorph loses health after its core is destroyed.")
	QDEL_LIST(xeno_units_to_clean)
	QDEL_LIST(xeno_growths_to_clean)

	// Marker suppression must gate every birth path without switching off its generator/relay.
	var/datum/ms13_terrain_hivemind/necromorph/marker/marker_network = new(origin, 20)
	var/obj/structure/ms13_hivemind/core/marker/marker = marker_network.core
	var/obj/effect/ms13_marker_emp_test_probe/emp_probe = new(origin)
	TEST_ASSERT(marker && marker.power_feed && marker.radio_relay, "The Marker did not create its power and public-radio components.")
	TEST_ASSERT(!marker.is_suppressed(), "The Marker starts suppressed without a powered projector.")
	TEST_ASSERT(FREQ_COMMON in marker.radio_relay.freq_listening, "The Marker does not relay the public channel.")
	var/obj/machinery/power/ms13_marker_suppressor/projector = new(get_step(origin, WEST))
	var/datum/powernet/marker_grid = new
	marker_grid.add_machine(projector)
	marker_grid.add_machine(marker.power_feed)
	marker.power_feed.process(1)
	var/unsuppressed_marker_output = marker_grid.newavail
	TEST_ASSERT(unsuppressed_marker_output > 0, "The Marker did not produce power before containment.")
	marker_grid.newavail = 0
	projector.enabled = TRUE
	projector.process(1)
	TEST_ASSERT(!marker.is_suppressed(), "An unpowered projector suppresses the Marker.")
	marker_grid.avail = 100000
	projector.process(1)
	TEST_ASSERT_EQUAL(marker_grid.load, 50000, "Containment did not charge the grid 50 kW.")
	TEST_ASSERT(marker.is_suppressed(), "A powered nearby projector does not suppress the Marker.")
	marker.power_feed.process(1)
	TEST_ASSERT_EQUAL(marker_grid.newavail, unsuppressed_marker_output, "Suppression changed Marker power production.")
	marker_network.resources = 100
	var/initial_growth_count = length(marker_network.territory)
	marker_network.process(30)
	TEST_ASSERT_EQUAL(length(marker_network.units), 0, "A suppressed core generated hostiles.")
	TEST_ASSERT_EQUAL(length(marker_network.territory), initial_growth_count, "A suppressed Marker still spreads.")
	TEST_ASSERT(!marker_network.spend(1), "Suppressed remote spawners can still spend resources.")
	TEST_ASSERT(!marker_network.spawn_unit(/mob/living/simple_animal/hostile/ms13/terrain_hivemind, get_step(origin, EAST)), "Suppression does not gate direct births.")
	TEST_ASSERT(!marker.radio_relay.spoof_public_message(), "A suppressed Marker still spoofs radio speech.")
	var/turf/remote_turf = get_step(get_step(get_step(origin, EAST), EAST), EAST)
	var/mob/living/simple_animal/chicken/remote_corpse = new(remote_turf)
	remote_corpse.death()
	TEST_ASSERT(!marker_network.is_territory(remote_turf), "The remote-rebirth fixture is on biomass.")
	TEST_ASSERT(!marker_network.advance_corpse_conversion(remote_corpse, marker, 1, 1), "Suppression allows corpse conversion.")
	marker_grid.avail = 0
	projector.process(1)
	TEST_ASSERT(!marker.is_suppressed(), "Containment persists after power failure.")
	TEST_ASSERT_EQUAL(emp_probe.pulses, 0, "Brief containment generated an EMP.")
	TEST_ASSERT(isnull(marker.containment_started_at), "A short failure retained accumulated containment time.")
	for(var/cycle in 1 to 3)
		marker_grid.avail = 100000
		marker_grid.load = 0
		projector.process(1)
		TEST_ASSERT_EQUAL(marker.containment_started_at, world.time, "Recontainment does not start a fresh arming period.")
		marker_grid.avail = 0
		projector.process(1)
	TEST_ASSERT_EQUAL(emp_probe.pulses, 0, "Rapid containment cycling generated an EMP.")
	marker_grid.avail = 100000
	marker_grid.load = 0
	projector.process(1)
	marker.containment_started_at = world.time - marker.containment_emp_arm_time
	marker_grid.avail = 0
	projector.process(1)
	TEST_ASSERT_EQUAL(emp_probe.pulses, 1, "Sustained containment failure did not emit exactly one EMP.")
	TEST_ASSERT_EQUAL(emp_probe.last_severity, EMP_HEAVY, "The central containment EMP is not heavy strength.")
	marker.is_suppressed()
	marker.is_suppressed()
	TEST_ASSERT_EQUAL(emp_probe.pulses, 1, "Repeated containment checks retrigger the same EMP.")
	marker_grid.avail = 100000
	marker_grid.load = 0
	projector.process(1)
	marker_grid.avail = 0
	projector.process(1)
	TEST_ASSERT_EQUAL(emp_probe.pulses, 1, "An EMP can be retriggered without another full arming period.")
	qdel(emp_probe)
	COOLDOWN_RESET(marker, influence_cooldown)
	marker.corpse_scan_cursor = GLOB.dead_mob_list.Find(remote_corpse)
	marker.process(1)
	TEST_ASSERT(QDELETED(remote_corpse) && length(marker_network.units) == 1, "An uncontained Marker did not remotely resurrect a corpse away from biomass.")
	TEST_ASSERT(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/climber in marker_network.evolved_mob_types, "Evolution does not unlock the roof climber.")
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher/ambusher = new(remote_turf, marker_network)
	TEST_ASSERT(ambusher.hibernating && ambusher.can_scale_roofs, "The ambusher does not start dormant with climbing capability.")
	ambusher.toggle_ai(AI_OFF)
	var/mob/living/simple_animal/chicken/travel_host = new(remote_turf)
	travel_host.Paralyze(10 MINUTES, TRUE)
	TEST_ASSERT(ambusher.try_make_grab(travel_host), "The vertical hauling fixture could not grab its host.")
	ambusher.corpse_target_ref = WEAKREF(travel_host)
	var/turf/landing = get_step(origin, NORTH)
	ambusher.forceMoveWithGroup(landing, ZMOVING_VERTICAL)
	TEST_ASSERT(get_turf(travel_host) == landing && ambusher.is_grabbing(travel_host), "Group relocation loses the dragged host while moving its carrier first.")
	qdel(travel_host)
	TEST_ASSERT_EQUAL(ms13_hive_distance(origin, remote_turf), 3, "Same-floor hive distances changed.")
	TEST_ASSERT_EQUAL(ms13_hive_distance(origin, null), INFINITY, "Missing targets count as adjacent.")
	var/turf/other_floor = locate(origin.x, origin.y, origin.z == 1 ? 2 : 1)
	if(other_floor)
		TEST_ASSERT_EQUAL(ms13_hive_distance(origin, other_floor), INFINITY, "Targets on other floors count as adjacent.")
	var/list/marker_units = marker_network.units.Copy()
	var/list/marker_growths = marker_network.territory.Copy()
	var/obj/machinery/power/ms13_marker_feed/old_feed = marker.power_feed
	var/obj/machinery/telecomms/allinone/ms13_marker_relay/old_relay = marker.radio_relay
	qdel(marker_network)
	TEST_ASSERT(QDELETED(old_feed) && QDELETED(old_relay), "Destroying a Marker leaves live power/radio components.")
	QDEL_LIST(marker_units)
	QDEL_LIST(marker_growths)
	qdel(projector)
