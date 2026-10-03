#ifndef MS13_SQUAD_NAVIGATION_INCLUDED
#define MS13_SQUAD_NAVIGATION_INCLUDED

// A* handles directional barriers that JPS can miss. Stairs connect ordinary 2D routes.
/datum/ai_movement/astar/ms13_squad
	use_diagonals = FALSE
	max_path_length = 60

/// Pick an accessible working tile; a dense target cannot itself be a walking destination.
/datum/ai_controller/ms13_squad/proc/interaction_position(atom/target)
	var/turf/cached = current_movement_target
	if(istype(cached) && !cached.density && cached.Adjacent(target, target, pawn))
		return cached
	var/turf/closest
	var/best_length = 61
	for(var/turf/tile as anything in RANGE_TURFS(1, target))
		if(tile.density || !tile.Adjacent(target, target, pawn))
			continue
		var/list/path = SSpathfinder.astar_pathfind_now(pawn, tile, max_steps = best_length, mintargetdist = 0, access = get_access(), use_diagonals = FALSE)
		if(length(path) && length(path) < best_length)
			closest = tile
			best_length = length(path)
	return closest

/// Validate both ends before walking to a staircase, including cached routes.
/datum/ai_controller/ms13_squad/proc/stair_entry(obj/structure/stairs/stairs, ascending)
	if(QDELETED(stairs) || !stairs.isTerminator())
		return null
	var/turf/bottom = get_turf(stairs)
	var/turf/top = get_step_multiz(stairs, stairs.dir | UP)
	var/turf/entry = ascending ? bottom : top
	var/turf/exit = ascending ? top : bottom
	var/turf/opening = GetAbove(stairs)
	if(entry?.z != pawn.z || !exit || !opening?.CanZPass(pawn, ascending ? UP : DOWN, ZMOVE_STAIRS_FLAGS) || exit.is_blocked_turf(exclude_mobs = TRUE, source_atom = pawn))
		return null
	if(!ascending && !bottom.CanZPass(pawn, DOWN, ZMOVE_STAIRS_FLAGS))
		return null
	return entry

/datum/ai_controller/ms13_squad/proc/approach_stairs(atom/target)
	var/mob/living/carbon/human/ms13_squad/unit = pawn
	if(unit.buckled)
		stop_travel()
		return FALSE
	var/ascending = target.z > unit.z
	var/turf/entry = stair_entry(route_stairs, ascending)
	if(!entry)
		stop_travel()
		route_stairs = null
	if(!route_stairs)
		if(world.time < next_stair_search)
			return FALSE
		next_stair_search = world.time + 3 SECONDS
		var/list/options = list()
		for(var/obj/structure/stairs/stairs as anything in INSTANCES_OF(/obj/structure/stairs))
			entry = stair_entry(stairs, ascending)
			if(!entry || get_dist(unit, entry) > 30)
				continue
			options[stairs] = get_dist(unit, entry)
		// ponytail: nearest-first scanning suits nearby stairs; use a connector graph for large networks.
		while(length(options))
			var/obj/structure/stairs/best
			for(var/obj/structure/stairs/stairs as anything in options)
				if(!best || options[stairs] < options[best])
					best = stairs
			if(!best)
				break
			options -= best
			entry = ascending ? get_turf(best) : get_step_multiz(best, best.dir | UP)
			var/serial = unit.order_serial
			var/list/path = astar_path_to(unit, entry, max_steps = 60, mintargetdist = 0, access = get_access(), use_diagonals = FALSE)
			if(QDELETED(unit) || QDELETED(target) || unit.order_serial != serial)
				return FALSE
			if(entry != stair_entry(best, ascending))
				continue
			if(get_turf(unit) == entry || length(path))
				route_stairs = best
				break
	if(!route_stairs)
		stop_travel()
		unit.order_status = "No reachable stairs; retrying"
		return FALSE
	entry = ascending ? get_turf(route_stairs) : get_step_multiz(route_stairs, route_stairs.dir | UP)
	unit.order_status = "Taking stairs"
	if(!approach(entry, 0))
		return FALSE
	var/turf/opening = GetAbove(route_stairs)
	if(ascending)
		route_stairs.stair_ascend(unit)
	else if(opening?.CanZPass(unit, DOWN, ZMOVE_STAIRS_FLAGS))
		// Enter the real stair opening; normal falling/stair interception performs descent.
		if(unit.Move(opening, get_dir(unit, opening)) && get_turf(unit) == opening && !unit.has_gravity(opening))
			zstep(unit, DOWN, ZMOVE_STAIRS_FLAGS)
	route_stairs = null
	return FALSE

#endif
