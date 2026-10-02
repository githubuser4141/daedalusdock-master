// A* handles directional barriers that JPS can miss. Stairs connect ordinary 2D routes.
/datum/ai_movement/astar/ms13_squad
	use_diagonals = FALSE
	max_path_length = 60

/datum/ai_controller/ms13_squad/proc/approach_stairs(atom/target)
	var/mob/living/carbon/human/ms13_squad/unit = pawn
	if(unit.buckled)
		stop_travel()
		return FALSE
	var/ascending = target.z > unit.z
	var/turf/entry
	if(!QDELETED(route_stairs))
		entry = ascending ? get_turf(route_stairs) : get_step_multiz(route_stairs, route_stairs.dir | UP)
	if(entry?.z != unit.z)
		route_stairs = null
	if(!route_stairs)
		if(world.time < next_stair_search)
			return FALSE
		next_stair_search = world.time + 3 SECONDS
		var/list/options = list()
		for(var/obj/structure/stairs/stairs as anything in INSTANCES_OF(/obj/structure/stairs))
			if(!stairs.isTerminator())
				continue
			var/turf/top = get_step_multiz(stairs, stairs.dir | UP)
			entry = ascending ? get_turf(stairs) : top
			if(!top || entry.z != unit.z || get_dist(unit, entry) > 30)
				continue
			options[stairs] = get_dist(unit, entry)
		// ponytail: try three nearby stairs per search; a connector graph can replace this for large maps.
		for(var/attempt in 1 to 3)
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
			if(QDELETED(unit) || unit.order_serial != serial)
				return FALSE
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
