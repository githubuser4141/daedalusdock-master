/**
 * Minimal ground vehicle controller - a real, multi-tile object formation that moves together one
 * tile at a time. No separate z-level, no possession, no turf-swapping: ported from Civ13's vehicle
 * system (github.com/Civ13/Civ13, code/modules/1713/machinery/modular_vehicles/, AGPLv3 - same
 * license as this codebase), stripped down to just the core mechanic - no modular crafting, no
 * engine/fuel. See jeep.dm for the one concrete vehicle this currently assembles into.
 *
 * A vehicle is a set of frame tiles (the floor of each cell - see /obj/structure/ms13_vehicle_frame
 * below) plus directional walls sitting on those tiles (border objects, exactly like the game's
 * existing windows - see vehicle_walls.dm). Moving or turning the vehicle just forceMoves every
 * frame, every wall, and everything currently standing on any frame tile - the "vehicle" has no
 * existence beyond that set of ordinary map objects moving in lockstep, so shooting one of its walls
 * is exactly as real as shooting any other wall in the game. Each frame also carries a top-down roof
 * image which hides the cabin from outsiders and is removed from the view of clients aboard.
 *
 * Rotation pivots on one designated frame (pivot), which never itself changes position - every other
 * frame/wall records its position as a (forward, right) offset from the pivot in the vehicle's OWN
 * current facing, and turning just recomputes where those offsets land in the new facing.
 *
 * ponytail: no bystander collision handling beyond "is a dense obstacle in the way" - a loose mob
 * standing in the vehicle's path does not get pushed/run over like Civ13's own version does.
 */
GLOBAL_LIST_EMPTY(ms13_vehicle_roofs)

/datum/ms13_ground_vehicle
	var/list/obj/structure/ms13_vehicle_frame/frames = list()
	var/list/obj/structure/window/ms13_vehicle_wall/walls = list()
	var/mob/living/driver
	/// The frame rotation pivots around; never moves position during a turn.
	var/obj/structure/ms13_vehicle_frame/pivot
	/// The vehicle's current facing - kept in sync with pivot.dir, but tracked here too since a plain
	/// datum has no dir var of its own.
	var/dir = NORTH
	/// Deciseconds between tiles/turns - matches a brisk walking pace.
	var/move_delay = 4
	var/next_move_time = 0

/datum/ms13_ground_vehicle/proc/get_all_parts()
	. = list()
	. += frames
	. += walls

/// Shows this vehicle's roof to an outside viewer, or hides it from somebody aboard.
/datum/ms13_ground_vehicle/proc/set_roof_visible(client/viewer, visible)
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		if(!frame.roof)
			continue
		if(visible)
			viewer.images |= frame.roof
		else
			viewer.images -= frame.roof

/// Returns this vehicle's frame on turf_to_check, if it has one there.
/datum/ms13_ground_vehicle/proc/get_frame_at(turf/turf_to_check)
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		if(get_turf(frame) == turf_to_check)
			return frame

/// Does a sight ray leaving frame in exit_dir cross a closed solid hull panel?
/datum/ms13_ground_vehicle/proc/boundary_blocks_vision(obj/structure/ms13_vehicle_frame/frame, exit_dir)
	for(var/obj/structure/window/ms13_vehicle_wall/solid/wall in walls)
		if(wall.parent_frame == frame && wall.blocks_vision && (wall.dir & exit_dir))
			return TRUE
	return FALSE

/// True when the line from an interior turf to target first exits through solid hull.
/datum/ms13_ground_vehicle/proc/blocks_sight_from(turf/source, turf/target)
	var/obj/structure/ms13_vehicle_frame/current_frame = get_frame_at(source)
	if(!current_frame || get_frame_at(target))
		return FALSE
	var/list/sight_line = get_line(source, target)
	var/turf/current_turf = source
	for(var/index in 2 to length(sight_line))
		var/turf/next_turf = sight_line[index]
		var/obj/structure/ms13_vehicle_frame/next_frame = get_frame_at(next_turf)
		if(current_frame && !next_frame && boundary_blocks_vision(current_frame, get_dir(current_turf, next_turf)))
			return TRUE
		current_turf = next_turf
		current_frame = next_frame
	return FALSE

/// Door state changes need to refresh occupants even though nobody moved.
/datum/ms13_ground_vehicle/proc/update_interior_masks()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/mob/living/passenger in get_turf(frame))
			passenger.update_ms13_vehicle_interior_mask()

/// Returns the vehicle occupying location's turf, if any.
/proc/get_ms13_ground_vehicle_at(atom/location)
	var/turf/vehicle_turf = get_turf(location)
	if(!vehicle_turf)
		return
	var/obj/structure/ms13_vehicle_frame/frame = locate() in vehicle_turf
	return frame?.vehicle

/// Walks forward_offset tiles along facing_dir (negative = backward) then right_offset tiles
/// perpendicular to it (negative = left), starting from the pivot's current turf. Used to find where
/// every frame/wall belongs both when driving straight (facing_dir = dir) and when turning
/// (facing_dir = the new dir being turned to).
/datum/ms13_ground_vehicle/proc/get_relative_turf(forward_offset, right_offset, facing_dir)
	var/turf/current = get_turf(pivot)
	var/forward_dir = facing_dir
	var/backward_dir = turn(facing_dir, 180)
	var/right_dir = turn(facing_dir, -90)
	var/left_dir = turn(facing_dir, 90)

	var/steps = forward_offset
	while(steps > 0 && current)
		current = get_step(current, forward_dir)
		steps--
	while(steps < 0 && current)
		current = get_step(current, backward_dir)
		steps++

	steps = right_offset
	while(steps > 0 && current)
		current = get_step(current, right_dir)
		steps--
	while(steps < 0 && current)
		current = get_step(current, left_dir)
		steps++

	return current

/// Is every frame's next tile in this direction free of anything that isn't part of this same
/// vehicle - including its current passengers, who are expected to come along for the ride rather
/// than count as obstacles to their own vehicle (this matters most for rotation, below: the pivot's
/// own "destination" is its current tile, which its driver is standing on).
/datum/ms13_ground_vehicle/proc/can_move(direction)
	var/list/parts = get_all_parts() + get_manifest()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/turf/dest = get_step(frame, direction)
		if(!dest || dest.density)
			return FALSE
		for(var/atom/movable/blocker in dest)
			if(blocker in parts)
				continue
			if(blocker.density)
				return FALSE
	return TRUE

/// Would every frame have a clear tile to land on if the vehicle turned to face new_dir right now?
/datum/ms13_ground_vehicle/proc/can_rotate(new_dir)
	if(new_dir == dir)
		return FALSE
	var/list/parts = get_all_parts() + get_manifest()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/turf/dest = get_relative_turf(frame.forward_offset, frame.right_offset, new_dir)
		if(!dest || dest.density)
			return FALSE
		for(var/atom/movable/blocker in dest)
			if(blocker in parts)
				continue
			if(blocker.density)
				return FALSE
	return TRUE

/// Builds the manifest of everything currently standing on any frame tile that isn't part of the
/// vehicle itself, tagged with which frame it was on - shared by do_move() and do_rotate() so both
/// carry passengers along the same way.
/datum/ms13_ground_vehicle/proc/get_manifest()
	var/list/parts = get_all_parts()
	. = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/atom/movable/passenger in frame.loc)
			if(passenger in parts)
				continue
			.[passenger] = frame

/// Moves every frame, every wall, and everyone/everything currently aboard one tile in direction.
/datum/ms13_ground_vehicle/proc/do_move(direction)
	if(!driver || world.time < next_move_time)
		return FALSE
	if(!can_move(direction))
		return FALSE
	next_move_time = world.time + move_delay

	var/list/manifest = get_manifest()

	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		frame.forceMove(get_step(frame, direction))
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		wall.forceMove(get_step(wall, direction))
	for(var/atom/movable/passenger as anything in manifest)
		passenger.forceMove(get_step(passenger, direction))
	return TRUE

/// Turns the whole vehicle in place to face new_dir, rotating every frame/wall's position around the
/// pivot and every wall's own facing to match, and carrying passengers to their frame's new tile.
/datum/ms13_ground_vehicle/proc/do_rotate(new_dir)
	if(!driver || world.time < next_move_time)
		return FALSE
	if(!can_rotate(new_dir))
		return FALSE
	next_move_time = world.time + move_delay

	var/list/manifest = get_manifest()

	// Compute every destination before moving anything, so later lookups aren't thrown off by a
	// frame that's already relocated.
	var/list/frame_dest = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		frame_dest[frame] = get_relative_turf(frame.forward_offset, frame.right_offset, new_dir)
	var/list/wall_dest = list()
	var/list/wall_dir = list()
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		wall_dest[wall] = get_relative_turf(wall.forward_offset, wall.right_offset, new_dir)
		wall_dir[wall] = turn(new_dir, wall.relative_turn)

	dir = new_dir

	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		frame.forceMove(frame_dest[frame])
		frame.setDir(new_dir)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		wall.forceMove(wall_dest[wall])
		wall.setDir(wall_dir[wall])
	for(var/atom/movable/passenger as anything in manifest)
		var/obj/structure/ms13_vehicle_frame/old_frame = manifest[passenger]
		passenger.forceMove(frame_dest[old_frame])
	return TRUE

/// One cell of a vehicle's footprint - just a floor. Walls (vehicle_walls.dm) mounted on it, plus
/// whatever's standing on it, are what actually make it feel like part of a vehicle.
/obj/structure/ms13_vehicle_frame
	name = "vehicle frame"
	desc = "The floor of a ground vehicle."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "frame_steel"
	density = FALSE
	anchored = TRUE
	max_integrity = 200
	var/datum/ms13_ground_vehicle/vehicle
	/// Opaque top-down cover shown to outsiders and hidden from clients aboard this vehicle.
	var/image/roof
	/// Position relative to the vehicle's pivot, in vehicle-local (forward, right) tiles - see
	/// get_relative_turf(). Zero for the pivot itself.
	var/forward_offset = 0
	var/right_offset = 0

/obj/structure/ms13_vehicle_frame/Initialize(mapload)
	. = ..()
	roof = image(icon = icon, loc = src, icon_state = "roof_steel", layer = ABOVE_ALL_MOB_LAYER, dir = dir)
	roof.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	GLOB.ms13_vehicle_roofs |= roof
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images |= roof

/obj/structure/ms13_vehicle_frame/Destroy()
	GLOB.ms13_vehicle_roofs -= roof
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images -= roof
	roof = null
	vehicle?.frames -= src
	vehicle = null
	return ..()

/obj/structure/ms13_vehicle_frame/setDir(new_dir)
	. = ..()
	if(roof)
		roof.dir = dir

/// Shared assembly helper: mount one directional wall on frame, facing wall_dir (an absolute
/// direction - convert with turn(vehicle.dir, relative_turn) if building from a relative angle).
/// wall_type lets callers mount a solid/door variant instead of the default see-through one.
/obj/structure/ms13_vehicle_frame/proc/spawn_wall(wall_dir, icon_state_override, wall_type = /obj/structure/window/ms13_vehicle_wall)
	var/obj/structure/window/ms13_vehicle_wall/wall = new wall_type(get_turf(src), wall_dir)
	wall.parent_frame = src
	wall.forward_offset = forward_offset
	wall.right_offset = right_offset
	// dir2angle() increases clockwise, while turn() increases counter-clockwise.
	wall.relative_turn = (dir2angle(vehicle.dir) - dir2angle(wall_dir) + 360) % 360
	if(icon_state_override)
		wall.icon_state = icon_state_override
	vehicle.walls += wall
	return wall

/// Roofs are client images: outsiders see them, while somebody on a vehicle frame sees its cabin.
/mob
	var/list/ms13_vehicle_interior_masks

/mob/proc/clear_ms13_vehicle_interior_mask()
	if(client && length(ms13_vehicle_interior_masks))
		client.images -= ms13_vehicle_interior_masks
	ms13_vehicle_interior_masks = null

/// Black out only exterior turfs whose ray from this occupant crosses closed solid hull.
/mob/proc/update_ms13_vehicle_interior_mask()
	clear_ms13_vehicle_interior_mask()
	if(!client)
		return
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(src)
	if(!vehicle)
		return
	ms13_vehicle_interior_masks = list()
	// ponytail: rebuilds the small visible mask on movement; cache rays if vehicle sizes grow.
	for(var/turf/target in range(client.view, src))
		if(!vehicle.blocks_sight_from(get_turf(src), target))
			continue
		var/image/mask = image(icon = 'icons/effects/alphacolors.dmi', loc = target, layer = ABOVE_ALL_MOB_LAYER)
		mask.color = "#000000"
		mask.plane = ABOVE_GAME_PLANE
		mask.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		ms13_vehicle_interior_masks += mask
	client.images += ms13_vehicle_interior_masks

/mob/Login()
	. = ..()
	if(!. || !client)
		return
	client.images |= GLOB.ms13_vehicle_roofs
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(src)
	vehicle?.set_roof_visible(client, FALSE)
	update_ms13_vehicle_interior_mask()

/mob/Logout()
	clear_ms13_vehicle_interior_mask()
	return ..()

/mob/living/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(!client)
		return
	var/datum/ms13_ground_vehicle/old_vehicle = get_ms13_ground_vehicle_at(old_loc)
	var/datum/ms13_ground_vehicle/new_vehicle = get_ms13_ground_vehicle_at(src)
	if(old_vehicle != new_vehicle)
		old_vehicle?.set_roof_visible(client, TRUE)
		new_vehicle?.set_roof_visible(client, FALSE)
	update_ms13_vehicle_interior_mask()
