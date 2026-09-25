// Bounded local routing between floors; ordinary horizontal travel still uses the existing JPS loop.
/datum/ms13_terrain_hivemind/New(turf/start, new_territory_limit)
	. = ..()
	evolved_mob_types |= list(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/climber, /mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	var/can_scale_roofs = FALSE
	var/turf/hive_z_waypoint
	var/turf/hive_z_landing
	var/atom/hive_z_connector
	var/hive_goal_z = 0
	var/hive_travelling = FALSE
	var/hive_group_moving = FALSE
	var/hive_z_failed_plans = 0
	COOLDOWN_DECLARE(hive_z_waypoint_cooldown)
	COOLDOWN_DECLARE(hive_z_search_cooldown)
	COOLDOWN_DECLARE(hive_vertical_sight_cooldown)

/// Unlike BYOND get_dist(), a mob on another floor must never count as adjacent (-1).
/proc/ms13_hive_distance(atom/first, atom/second)
	if(!first || !second || !first.z || first.z != second.z)
		return INFINITY
	return get_dist(first, second)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/get_move_group()
	. = ..()
	var/mob/living/host = corpse_target_ref?.resolve()
	if(host && is_grabbing(host))
		. |= host

// Native forceMove checks the grab before the second member reaches the destination.
// Defer those checks only during the synchronous group relocation, then validate normally.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/forceMoveWithGroup(destination, z_movement)
	hive_group_moving = TRUE
	. = ..()
	hive_group_moving = FALSE
	recheck_grabs()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/recheck_grabs(only_pulling = FALSE, only_pulled = FALSE, z_allowed = FALSE)
	if(hive_group_moving)
		return
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/handle_grabs_during_movement(turf/old_loc, direction)
	if(hive_group_moving)
		return
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_vertical_links(direction)
	var/list/links = list()
	for(var/obj/structure/ladder/ladder as anything in INSTANCES_OF(/obj/structure/ladder))
		if(ladder.z != z || get_dist(src, ladder) > 24 || ladder.obstructed || ladder.locked)
			continue
		var/obj/structure/ladder/other = direction == UP ? ladder.up : ladder.down
		if(other && !other.obstructed && !other.locked && other.z != z)
			links += list(list(get_turf(ladder), get_turf(other), ladder))
	for(var/obj/structure/stairs/stairs as anything in INSTANCES_OF(/obj/structure/stairs))
		if(!stairs.isTerminator())
			continue
		var/turf/top = get_step_multiz(stairs, stairs.dir | UP)
		if(!top)
			continue
		if(direction == UP && stairs.z == z && get_dist(src, stairs) <= 24)
			links += list(list(get_turf(stairs), top, stairs))
		else if(direction == DOWN && top.z == z && get_dist(src, top) <= 24)
			links += list(list(top, get_turf(stairs), stairs))
	// ponytail: local openings/roof edges only (7 tiles); no whole-map scan or arbitrary 3D A*.
	for(var/turf/open/ground in RANGE_TURFS(7, src))
		if(direction == DOWN && isopenspaceturf(ground))
			var/turf/below = GetBelow(ground)
			if(below && !isopenspaceturf(below) && can_z_move(DOWN, ground, ZMOVE_INCAPACITATED_CHECKS))
				links += list(list(ground, below, null))
		if(direction != UP || !can_scale_roofs)
			continue
		var/turf/above = GetAbove(ground)
		if(!isopenspaceturf(above) || !above.CanZPass(src, UP))
			continue
		for(var/side in GLOB.cardinals)
			var/turf/roof = get_step(above, side)
			if(isfloorturf(roof) && !isopenspaceturf(roof) && !roof.density && network.can_spawn_unit_at(roof))
				links += list(list(ground, roof, null))
	return links

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_navigate_vertical(atom/goal)
	if(!goal || !isturf(loc) || hive_travelling || incapacitated())
		return FALSE
	if(hive_goal_z != goal.z || hive_z_waypoint?.z != z || COOLDOWN_FINISHED(src, hive_z_waypoint_cooldown))
		hive_z_waypoint = null
	if(!hive_z_waypoint)
		if(!COOLDOWN_FINISHED(src, hive_z_search_cooldown))
			return FALSE
		COOLDOWN_START(src, hive_z_search_cooldown, 5 SECONDS)
		SSmove_manager.stop_looping(src)
		var/list/options = hive_vertical_links(goal.z > z ? UP : DOWN)
		// At most three horizontal path searches per planning attempt, even in ladder-heavy maps.
		for(var/attempt in 1 to 3)
			var/list/best
			var/best_distance = INFINITY
			for(var/list/option as anything in options)
				var/turf/entry = option[1]
				var/distance = get_dist(src, entry)
				if(distance < best_distance)
					best = option
					best_distance = distance
			if(!best)
				break
			options -= list(best)
			var/turf/entry = best[1]
			if(get_turf(src) != entry && !length(jps_path_to(src, entry, max_steps = 60, mintargetdist = 0)))
				continue
			hive_z_waypoint = entry
			hive_z_landing = best[2]
			hive_z_connector = best[3]
			hive_goal_z = goal.z
			COOLDOWN_START(src, hive_z_waypoint_cooldown, 15 SECONDS)
			hive_z_failed_plans = 0
			break
	if(!hive_z_waypoint)
		// Do not stare forever at inaccessible prey across floors.
		if(target == goal && ++hive_z_failed_plans >= 3)
			LoseTarget()
			COOLDOWN_START(src, hive_vertical_sight_cooldown, 30 SECONDS)
			hive_z_failed_plans = 0
		return FALSE
	if(get_turf(src) != hive_z_waypoint)
		Goto(hive_z_waypoint, move_to_delay, 0)
		return TRUE
	SSmove_manager.stop_looping(src)
	hive_travelling = TRUE
	var/turf/start = get_turf(src)
	var/obj/structure/ladder/ladder = hive_z_connector
	var/obj/structure/stairs/stairs = hive_z_connector
	if(do_after(src, 2 SECONDS, target = start) && hive_z_landing && network?.active && network.can_spawn_unit_at(hive_z_landing))
		if(istype(ladder))
			if(!QDELETED(ladder) && !ladder.locked && !ladder.obstructed && ((ladder.up && get_turf(ladder.up) == hive_z_landing && !ladder.up.obstructed && !ladder.up.locked) || (ladder.down && get_turf(ladder.down) == hive_z_landing && !ladder.down.obstructed && !ladder.down.locked)))
				if(!(SEND_SIGNAL(src, COMSIG_LADDER_TRAVEL, ladder, hive_z_landing.z > z ? ladder.up : ladder.down, hive_z_landing.z > z) & LADDER_TRAVEL_BLOCK))
					forceMoveWithGroup(hive_z_landing, ZMOVING_VERTICAL)
		else if(istype(stairs) && !QDELETED(stairs))
			var/turf/stair_opening = GetAbove(stairs)
			if(stair_opening?.CanZPass(src, UP, ZMOVE_STAIRS_FLAGS))
				forceMoveWithGroup(hive_z_landing, ZMOVING_VERTICAL)
		else if(hive_z_landing.z < z)
			if(can_z_move(DOWN, start, ZMOVE_INCAPACITATED_CHECKS))
				forceMoveWithGroup(hive_z_landing, ZMOVING_VERTICAL)
		else if(can_scale_roofs)
			var/turf/above = GetAbove(start)
			if(isopenspaceturf(above) && above.CanZPass(src, UP) && get_dist(above, hive_z_landing) <= 1)
				visible_message(span_warning("[src] scrambles up onto [hive_z_landing]!"))
				forceMoveWithGroup(hive_z_landing, ZMOVING_VERTICAL)
	hive_travelling = FALSE
	hive_z_waypoint = null
	hive_z_connector = null
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/handle_hive_vertical_action()
	if(hive_travelling)
		return TRUE
	if(target && target.z != z)
		var/mob/living/host = target
		if(istype(host) && network.is_convertible_corpse(host) && can_work_corpses() && network.claim_corpse(host, src))
			corpse_target_ref = WEAKREF(host)
			LoseTarget()
			return FALSE
		if(CanAttack(target))
			hive_navigate_vertical(target)
			return TRUE
		LoseTarget()
	if(!target && COOLDOWN_FINISHED(src, hive_vertical_sight_cooldown))
		COOLDOWN_START(src, hive_vertical_sight_cooldown, 3 SECONDS)
		// Roof climbers can notice exposed prey above, never through a solid ceiling.
		var/turf/above = GetAbove(src)
		if(can_scale_roofs && isopenspaceturf(above) && above.CanZPass(src, UP))
			for(var/mob/living/prey in view(5, above))
				if(CanAttack(prey))
					GiveTarget(prey)
					return TRUE
		// ponytail: inspect at most three visible openings per scan; avoid nested views over an entire roof.
		var/openings_examined = 0
		for(var/turf/open/openspace/hole in view(5, src))
			if(++openings_examined > 3)
				break
			var/turf/below = GetBelow(hole)
			if(!below || !hole.CanZPass(src, DOWN))
				continue
			for(var/mob/living/prey in view(3, below))
				if(CanAttack(prey))
					GiveTarget(prey)
					return TRUE
	// Return to the nest's floor when an expedition loses its target; do not idle on a foreign floor.
	if(!target && !corpse_target_ref && network.core?.z != z)
		return hive_navigate_vertical(network.core)
	return FALSE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/climber
	parent_type = /mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout
	can_scale_roofs = TRUE
	move_to_delay = 3
	off_terrain_damage_multiplier = 0

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/climber/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	name = "[name] climber"

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher
	parent_type = /mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier
	can_scale_roofs = TRUE
	off_terrain_damage_multiplier = 0
	/// Lying in wait. It leaves the nest with the rest first, so it doesn't lie in their way.
	var/hibernating = FALSE
	COOLDOWN_DECLARE(ambush_scan_cooldown)
	COOLDOWN_DECLARE(ambush_awake_cooldown)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	name = "[name] ambusher"
	COOLDOWN_START(src, ambush_awake_cooldown, 30 SECONDS)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher/handle_automated_action()
	if(AIStatus == AI_OFF || !network?.active || incapacitated())
		return FALSE
	if(target || health < maxHealth)
		hibernating = FALSE
		COOLDOWN_START(src, ambush_awake_cooldown, 30 SECONDS)
	if(!hibernating && !target && COOLDOWN_FINISHED(src, ambush_awake_cooldown) && good_ambush_spot())
		hibernating = TRUE
	if(!hibernating)
		return ..()
	SSmove_manager.stop_looping(src)
	if(COOLDOWN_FINISHED(src, ambush_scan_cooldown))
		COOLDOWN_START(src, ambush_scan_cooldown, 2 SECONDS)
		for(var/mob/living/prey in view(4, src))
			if(CanAttack(prey))
				GiveTarget(prey)
				hibernating = FALSE
				visible_message(span_warning("[src] suddenly stirs and lunges!"))
				break
	return TRUE

/// Somewhere to lie in wait: clear of the nest, and not in a doorway or a passage the rest of the hive needs.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher/proc/good_ambush_spot()
	var/turf/here = get_turf(src)
	if(!here || (network?.core && get_dist(here, network.core) <= 4) || (locate(/obj/machinery/door) in here))
		return FALSE
	var/open_sides = 0
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(here, direction)
		if(beside && !beside.is_blocked_turf(TRUE))
			open_sides++
	return open_sides >= 3

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ambusher/examine(mob/user)
	. = ..()
	if(hibernating)
		. += span_notice("It is unnaturally still.")
