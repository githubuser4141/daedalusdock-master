/proc/get_step_multiz(ref, dir)
	if(dir & UP)
		dir &= ~UP
		return get_step(GetAbove(ref), dir)
	if(dir & DOWN)
		dir &= ~DOWN
		return get_step(GetBelow(ref), dir)
	return get_step(ref, dir)

/proc/get_dir_multiz(turf/us, turf/them)
	us = get_turf(us)
	them = get_turf(them)
	if(!us || !them)
		return NONE
	if(us.z == them.z)
		return get_dir(us, them)

	var/turf/T = GetAbove(us)
	var/dir = NONE
	if(T && (T.z == them.z))
		dir = UP
	else
		T = GetBelow(us)
		if(T && (T.z == them.z))
			dir = DOWN
		else
			return get_dir(us, them)
	return (dir | get_dir(us, them))

/// Tile distance across connected floors; unrelated map regions are never in range.
/proc/get_dist_multiz(atom/source, atom/target)
	var/turf/start = get_turf(source)
	var/turf/end = get_turf(target)
	if(!start || !end || !SSmapping.are_same_zstack(start.z, end.z))
		return INFINITY
	return max(abs(start.x - end.x), abs(start.y - end.y)) + abs(start.z - end.z) * MULTIZ_LEVEL_DISTANCE

///Checks if 2 levels are in the same Z-stack.
/datum/controller/subsystem/mapping/proc/are_same_zstack(zA, zB, include_lateral)
	if (zA <= 0 || zB <= 0 || zA > world.maxz || zB > world.maxz)
		return FALSE
	if (zA == zB)
		return TRUE

	return zB in get_zstack(zA, include_lateral)

///Get a list of Z levels that are in zA's Z-stack.
/datum/controller/subsystem/mapping/proc/get_zstack(zA, include_lateral)
	if(isturf(zA))
		zA = zA:z
	if(!isnum(zA) || zA < 1 || zA > world.maxz)
		return list()

	// Walk the few floors directly: cached answers went stale when maps added or linked levels.
	. = list(zA)
	// Traverse up and down to get the multiz stack.
	for(var/level = zA, HasAbove(level), level++)
		. |= level+1
	for(var/level = zA, HasBelow(level), level--)
		. |= level-1

	if(!include_lateral)
		return .

	// Check stack for any laterally connected neighbors.
	for(var/i = 1, i <= length(.), i++)
		var/datum/space_level/checking = z_list[.[i]]
		for(var/neighbor_key in checking?.neigbours)
			var/datum/space_level/neighbor = checking.neigbours[neighbor_key]
			. |= neighbor.z_value

