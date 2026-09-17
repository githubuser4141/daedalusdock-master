/**
 * Minimal ground vehicle controller - a real, multi-tile object formation that moves together one
 * tile at a time. No separate z-level, no possession, no turf-swapping: ported from Civ13's vehicle
 * system (github.com/Civ13/Civ13, code/modules/1713/machinery/modular_vehicles/, AGPLv3 - same
 * license as this codebase), stripped down to code-configured parts rather than in-game modular
 * crafting. See jeep.dm and armored_truck.dm for the concrete vehicle layouts.
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
 */
GLOBAL_LIST_EMPTY(ms13_vehicle_roofs)
GLOBAL_LIST_EMPTY(ms13_vehicle_exterior_part_images)

/datum/ms13_ground_vehicle
	var/list/obj/structure/ms13_vehicle_frame/frames = list()
	var/list/obj/structure/window/ms13_vehicle_wall/walls = list()
	var/list/obj/structure/ms13_vehicle_part/parts = list()
	var/obj/structure/ms13_vehicle_part/engine/engine
	var/obj/structure/ms13_vehicle_part/gearbox/gearbox
	var/obj/structure/ms13_vehicle_part/fuel_tank/fuel_tank
	var/datum/looping_sound/running_gear_soundloop
	var/running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_wheels
	var/mob/living/driver
	/// The frame rotation pivots around; never moves position during a turn.
	var/obj/structure/ms13_vehicle_frame/pivot
	/// The vehicle's current facing - kept in sync with pivot.dir, but tracked here too since a plain
	/// datum has no dir var of its own.
	var/dir = NORTH
	/// Handling values are overridden by each concrete controller subtype; the shared movement code
	/// never needs to know whether it is driving a jeep, truck, or a future vehicle. Gears and fuel
	/// capacity belong to the gearbox and fuel tank parts instead.
	var/acceleration_delay = 1 SECONDS
	var/coast_delay = 1.2 SECONDS
	var/turn_delay = 4
	var/max_turn_speed = 2
	var/turn_speed_loss = 1
	var/ram_damage_base = 4
	var/ram_damage_per_speed = 4
	var/ram_knockdown_per_speed = 5
	var/required_running_gear = 4
	var/running_gear_integrity = 80
	var/engine_integrity = 200
	var/fuel_per_tile = 0.1
	/// Brightness (0-1) a light-proof cabin tile keeps with every fixture off.
	var/interior_ambient_light = 0.03
	/// No roof to speak of: the weather gets in however closed up the sides are.
	var/open_top = FALSE
	var/rev_sound = 'sound/vehicles/carrev.ogg'
	var/ram_sound = 'sound/effects/bang.ogg'
	var/crash_sound = 'mojave/sound/ms13effects/impact/metal/metal_crunch_3.wav'
	var/rev_sound_volume = 35
	var/ram_sound_volume = 45
	var/crash_sound_volume = 55

	/// Current momentum state. Speed is the current gear (see gear_delay()), not tiles per tick.
	var/speed = 0
	var/travel_dir
	var/moving = FALSE
	var/last_throttle_time = 0
	var/next_acceleration_time = 0
	/// Invalidates a pending movement callback when motion stops and later restarts.
	var/movement_generation = 0
	var/next_move_time = 0
	/// Sideways drift while driving, CDDA-style: -1 left, 1 right, 0 straight. The chassis keeps its facing
	/// and sidesteps every drift_interval tiles. Steering once drifts; steering the same way again turns.
	var/drift = 0
	var/drift_interval = 3
	var/drift_progress = 0
	/// A held steering key only counts as a second press after this long.
	var/steer_delay = 0.8 SECONDS
	var/next_steer_time = 0

/// Gears the driver can currently select; zero without a working gearbox.
/datum/ms13_ground_vehicle/proc/gear_count()
	return gearbox?.available_gears() || 0

/// Move delay for a gear. Coasting with a wrecked gearbox falls back to a crawl.
/datum/ms13_ground_vehicle/proc/gear_delay(gear)
	var/list/delays = gearbox?.gear_delays
	if(!length(delays))
		return 10
	return delays[clamp(gear, 1, length(delays))]

/datum/ms13_ground_vehicle/proc/get_all_parts()
	. = list()
	. += frames
	. += walls
	. += parts

/// Shows this vehicle's roof to an outside viewer, or hides it from somebody aboard.
/datum/ms13_ground_vehicle/proc/set_roof_visible(client/viewer, visible)
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		if(!frame.roof)
			continue
		if(visible)
			viewer.images |= frame.roof
		else
			viewer.images -= frame.roof
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		if(!part.exterior_image)
			continue
		if(visible)
			viewer.images |= part.exterior_image
		else
			viewer.images -= part.exterior_image
	// Occupants see the cabin by its own light; outsiders see the roof by daylight.
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		if(!frame.interior_light)
			continue
		if(visible)
			viewer.images -= frame.interior_light
			viewer.images -= frame.interior_light_block
		else
			viewer.images |= frame.interior_light
			viewer.images |= frame.interior_light_block

/// Can outside light reach frame? False only when every exterior edge of it is closed light-proof hull.
/datum/ms13_ground_vehicle/proc/is_light_sealed(obj/structure/ms13_vehicle_frame/frame)
	return outer_edges_closed(frame, TRUE)

/// Is frame out of the weather - roofed, with every exterior edge covered by an intact, closed panel?
/datum/ms13_ground_vehicle/proc/is_weather_sealed(obj/structure/ms13_vehicle_frame/frame)
	return !open_top && outer_edges_closed(frame, FALSE)

/// Does every edge of frame that faces outside the vehicle have a panel closing it? light: whether that
/// panel has to be light-proof too, rather than just shut and intact.
/datum/ms13_ground_vehicle/proc/outer_edges_closed(obj/structure/ms13_vehicle_frame/frame, light)
	for(var/edge_dir in GLOB.cardinals)
		if(get_frame_at(get_step(frame, edge_dir)))
			continue
		var/sealed_edge = FALSE
		for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
			if(wall.parent_frame != frame || wall.dir != edge_dir)
				continue
			if(light ? wall.blocks_light() : (wall.density && !wall.hull_broken))
				sealed_edge = TRUE
				break
		if(!sealed_edge)
			return FALSE
	return TRUE

/// Is thing inside a closed-up vehicle, out of the weather? Used by particle weather (weather_datum.dm).
/proc/ms13_in_weather_sealed_vehicle(atom/thing)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(thing)
	return vehicle?.is_weather_sealed(vehicle.get_frame_at(get_turf(thing)))

/**
 * Lights the cabin for the people inside. A sealed tile ignores the lightmap outside and shows only
 * ambient plus fixture light; an open tile keeps outside light and gets fixture light added on top.
 */
/datum/ms13_ground_vehicle/proc/update_interior_lighting()
	var/list/lit_fixtures = list()
	for(var/obj/structure/ms13_vehicle_part/interior_light/fixture in parts)
		if(fixture.is_lit())
			lit_fixtures += fixture
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/red = 0
		var/green = 0
		var/blue = 0
		for(var/obj/structure/ms13_vehicle_part/interior_light/fixture as anything in lit_fixtures)
			var/list/added = fixture.light_at(frame)
			red += added[1]
			green += added[2]
			blue += added[3]
		if(is_light_sealed(frame))
			red += interior_ambient_light
			green += interior_ambient_light
			blue += interior_ambient_light
			frame.set_interior_light(TRUE, red, green, blue)
		else
			frame.set_interior_light(FALSE, red, green, blue)

/// Engines and the configured number of intact wheels/tracks provide motive power. Losing either prevents
/// new throttle, while the existing momentum loop remains free to coast to a stop.
/datum/ms13_ground_vehicle/proc/has_motive_power()
	if(!engine?.is_operational() || !gear_count())
		return FALSE
	var/working_running_gear = 0
	for(var/obj/structure/ms13_vehicle_part/running_gear/running_gear in parts)
		if(running_gear.is_operational())
			working_running_gear++
	return working_running_gear >= required_running_gear

/datum/ms13_ground_vehicle/proc/set_parts_moving(is_moving)
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		part.set_moving(is_moving)

/datum/ms13_ground_vehicle/proc/destroy_soundloops()
	QDEL_NULL(running_gear_soundloop)

/// Returns this vehicle's frame on turf_to_check, if it has one there.
/datum/ms13_ground_vehicle/proc/get_frame_at(turf/turf_to_check)
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		if(get_turf(frame) == turf_to_check)
			return frame

/// Does a sight ray from viewer_turf, leaving frame in exit_dir, hit a hull panel that won't let this viewer see
/// out? Solid panels always block; a porthole only lets through viewers within its vision_range.
/datum/ms13_ground_vehicle/proc/boundary_blocks_vision(obj/structure/ms13_vehicle_frame/frame, exit_dir, turf/viewer_turf)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		if(wall.parent_frame != frame || !(wall.dir & exit_dir))
			continue
		if(wall.blocks_sight())
			return TRUE
		if(!isnull(wall.vision_range) && get_dist(viewer_turf, get_turf(frame)) > wall.vision_range)
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
		if(current_frame && !next_frame && boundary_blocks_vision(current_frame, get_dir(current_turf, next_turf), source))
			return TRUE
		current_turf = next_turf
		current_frame = next_frame
	return FALSE

/// Door state changes need to refresh occupants even though nobody moved.
/datum/ms13_ground_vehicle/proc/update_interior_masks()
	update_interior_lighting()
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
/datum/ms13_ground_vehicle/proc/can_move(direction, ignore_living = FALSE)
	var/list/parts = get_all_parts() + get_manifest()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/turf/dest = get_step(frame, direction)
		if(!dest || dest.density)
			return FALSE
		for(var/atom/movable/blocker in dest)
			if(blocker in parts)
				continue
			if(ignore_living && isliving(blocker))
				continue
			if(blocker.density)
				return FALSE
	return TRUE

/// Is turf_to_check a safe place to push a bystander, without shoving them into the vehicle itself?
/datum/ms13_ground_vehicle/proc/can_push_living(mob/living/victim, turf/turf_to_check)
	if(!turf_to_check || turf_to_check.density || get_frame_at(turf_to_check))
		return FALSE
	for(var/atom/movable/blocker in turf_to_check)
		if(blocker != victim && blocker.density)
			return FALSE
	return TRUE

/// Lightly runs over loose living mobs on the new leading edge. A trapped victim is hurt but stops
/// the vehicle; one with a clear tile ahead is knocked down and pushed out of its path.
/datum/ms13_ground_vehicle/proc/ram_living(direction, list/manifest)
	var/list/victims = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/turf/destination = get_step(frame, direction)
		for(var/mob/living/victim in destination)
			if(!(victim in manifest))
				victims |= victim

	var/impact_speed = max(speed, 1)
	for(var/mob/living/victim as anything in victims)
		var/turf/push_turf = get_step(victim, direction)
		var/can_push = can_push_living(victim, push_turf)
		victim.visible_message(span_danger("[pivot] rams [victim]!"), span_userdanger("[pivot] rams into you!"))
		victim.apply_damage(ram_damage_base + ram_damage_per_speed * impact_speed, BRUTE, BODY_ZONE_CHEST)
		victim.Knockdown(ram_knockdown_per_speed * impact_speed)
		if(!can_push)
			return FALSE
		victim.forceMove(push_turf)
	if(length(victims))
		playsound(pivot, ram_sound, ram_sound_volume, TRUE)
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
/datum/ms13_ground_vehicle/proc/do_move(direction, bypass_cooldown = FALSE)
	if(!bypass_cooldown && world.time < next_move_time)
		return FALSE
	var/list/manifest = get_manifest()
	// First reject terrain/structures, then resolve mobs and finally make sure their old tiles cleared.
	if(!can_move(direction, TRUE) || !ram_living(direction, manifest) || !can_move(direction))
		return FALSE
	if(!bypass_cooldown)
		next_move_time = world.time + gear_delay(max(speed, 1))

	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		frame.forceMove(get_step(frame, direction))
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		wall.forceMove(get_step(wall, direction))
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		part.forceMove(get_step(part, direction))
	for(var/atom/movable/passenger as anything in manifest)
		passenger.forceMove(get_step(passenger, direction))
	engine?.consume_fuel(fuel_per_tile)
	alert_watchers()
	return TRUE

/// Starts at low speed, accelerates while the driver holds the travel direction, and uses the
/// opposite input as a brake before allowing a change between forward and reverse.
/datum/ms13_ground_vehicle/proc/apply_throttle(direction)
	if(!has_motive_power())
		return FALSE
	if(!speed)
		travel_dir = direction
		speed = 1
		last_throttle_time = world.time
		next_acceleration_time = world.time + acceleration_delay
		start_motion()
		return TRUE

	last_throttle_time = world.time
	if(direction != travel_dir)
		speed--
		next_acceleration_time = world.time + acceleration_delay
		if(!speed)
			stop_motion()
		return TRUE

	if(world.time >= next_acceleration_time && speed < gear_count())
		speed++
		next_acceleration_time = world.time + acceleration_delay
		playsound(pivot, rev_sound, rev_sound_volume, TRUE)
	return TRUE

/// Stopped, steering pivots in place. Moving, the first press starts a sideways drift and a second press the
/// same way commits to a full turn; steering the other way straightens out.
/datum/ms13_ground_vehicle/proc/apply_steering(new_dir)
	if(!speed)
		return full_turn(new_dir)
	if(world.time < next_steer_time)
		return FALSE
	next_steer_time = world.time + steer_delay
	var/side = new_dir == turn(dir, -90) ? 1 : -1
	if(drift != side)
		drift = drift ? 0 : side
		drift_progress = 0
		if(driver)
			pivot.balloon_alert(driver, drift ? "drifting [drift > 0 ? "right" : "left"]" : "straight")
		return TRUE
	if(!full_turn(new_dir))
		return FALSE
	drift = 0
	drift_progress = 0
	return TRUE

/// At speed, reversing preserves reversed travel through the turn; taking a corner also sheds configurable
/// momentum, and an over-speed turn input only brakes.
/datum/ms13_ground_vehicle/proc/full_turn(new_dir)
	if(speed > max_turn_speed)
		speed = max(1, speed - turn_speed_loss)
		last_throttle_time = world.time
		return FALSE
	var/reversing = speed && travel_dir == turn(dir, 180)
	if(!do_rotate(new_dir))
		return FALSE
	if(speed)
		travel_dir = reversing ? turn(new_dir, 180) : new_dir
		speed = max(1, speed - turn_speed_loss)
		last_throttle_time = world.time
	return TRUE

/datum/ms13_ground_vehicle/proc/handle_drive_input(direction)
	if(!(direction in list(NORTH, SOUTH, EAST, WEST)))
		return FALSE
	if(direction == dir || direction == turn(dir, 180))
		return apply_throttle(direction)
	return apply_steering(direction)

/datum/ms13_ground_vehicle/proc/start_motion()
	if(moving)
		return
	moving = TRUE
	movement_generation++
	set_parts_moving(TRUE)
	if(!running_gear_soundloop)
		running_gear_soundloop = new running_gear_soundloop_type(pivot)
	running_gear_soundloop.start()
	movement_tick(movement_generation)

/datum/ms13_ground_vehicle/proc/stop_motion()
	moving = FALSE
	speed = 0
	travel_dir = null
	drift = 0
	drift_progress = 0
	movement_generation++
	set_parts_moving(FALSE)
	running_gear_soundloop?.stop()

/// Self-schedules one tile at a time. Releasing the throttle coasts briefly, drops through the
/// configured speed bands, then stops; collisions cancel the remaining momentum immediately.
/datum/ms13_ground_vehicle/proc/movement_tick(generation)
	if(generation != movement_generation || !moving || !speed)
		return
	if(world.time >= last_throttle_time + coast_delay || speed > max(gear_count(), 1))
		speed--
		last_throttle_time = world.time
		if(!speed)
			stop_motion()
			return
	if(!do_move(travel_dir, TRUE))
		playsound(pivot, crash_sound, crash_sound_volume, TRUE)
		stop_motion()
		return
	if(drift && ++drift_progress >= drift_interval)
		drift_progress = 0
		// Scraping along something just straightens the vehicle out.
		if(!do_move(turn(dir, drift > 0 ? -90 : 90), TRUE))
			drift = 0
	addtimer(CALLBACK(src, PROC_REF(movement_tick), generation), gear_delay(speed))

/// Turns the whole vehicle in place to face new_dir, rotating every frame/wall's position around the
/// pivot and every wall's own facing to match, and carrying passengers to their frame's new tile.
/datum/ms13_ground_vehicle/proc/do_rotate(new_dir)
	if(!driver || world.time < next_move_time)
		return FALSE
	if(!can_rotate(new_dir))
		return FALSE
	next_move_time = world.time + turn_delay

	var/list/manifest = get_manifest()
	// dir2angle() increases clockwise, while turn() increases counter-clockwise.
	var/seat_turn = dir2angle(dir) - dir2angle(new_dir)

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
	var/list/part_dest = list()
	var/list/part_dir = list()
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		part_dest[part] = get_relative_turf(part.forward_offset, part.right_offset, new_dir)
		part_dir[part] = turn(new_dir, part.relative_turn)

	dir = new_dir

	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		frame.forceMove(frame_dest[frame])
		frame.setDir(new_dir)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		wall.forceMove(wall_dest[wall])
		wall.setDir(wall_dir[wall])
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		part.forceMove(part_dest[part])
		part.setDir(part_dir[part])
	for(var/atom/movable/passenger as anything in manifest)
		var/obj/structure/ms13_vehicle_frame/old_frame = manifest[passenger]
		passenger.forceMove(frame_dest[old_frame])
		if(istype(passenger, /obj/structure/chair/ms13_vehicle_seat))
			passenger.setDir(turn(passenger.dir, seat_turn))
	alert_watchers()
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
	/// Concrete frames select a controller subtype containing their handling/impact configuration.
	var/vehicle_controller_type = /datum/ms13_ground_vehicle
	/// Opaque top-down cover shown to outsiders and hidden from clients aboard this vehicle.
	var/image/roof
	var/roof_undamaged_icon
	var/roof_damaged_icon = 'mojave/icons/objects/vehicles_ground/vehicleparts_damaged.dmi'
	/// Used by roofs such as the M113 which have no matching damaged sheet in Civ13.
	var/roof_damage_color
	var/roof_hull_breached = FALSE
	/// Lighting-plane cover shown only to occupants: replaces or adds to outside light on this tile.
	var/image/interior_light
	/// Blanks the additive lighting plane here while the tile is sealed, so bright lamps outside can't bleed in.
	var/image/interior_light_block
	/// Position relative to the vehicle's pivot, in vehicle-local (forward, right) tiles - see
	/// get_relative_turf(). Zero for the pivot itself.
	var/forward_offset = 0
	var/right_offset = 0

/obj/structure/ms13_vehicle_frame/Initialize(mapload)
	. = ..()
	roof_undamaged_icon = icon
	roof = image(icon = icon, loc = src, icon_state = "roof_steel", layer = ABOVE_ALL_MOB_LAYER, dir = dir)
	roof.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	GLOB.ms13_vehicle_roofs |= roof
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images |= roof
	// Above area base lighting (LIGHTING_PRIMARY_LAYER), which is what lights Mojave's outdoors.
	interior_light = image('icons/effects/alphacolors.dmi', src, layer = LIGHTING_PRIMARY_LAYER + 5)
	interior_light.plane = LIGHTING_PLANE
	interior_light.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	interior_light.invisibility = INVISIBILITY_LIGHTING
	interior_light.alpha = 0
	interior_light_block = image('icons/effects/alphacolors.dmi', src, layer = LIGHTING_PRIMARY_LAYER + 5)
	interior_light_block.plane = LIGHTING_PLANE_ADDITIVE
	interior_light_block.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	interior_light_block.invisibility = INVISIBILITY_LIGHTING
	interior_light_block.color = "#000000"
	interior_light_block.alpha = 0

/// sealed: the tile shows exactly this light. Otherwise the light is added to whatever reaches it from outside.
/obj/structure/ms13_vehicle_frame/proc/set_interior_light(sealed, red, green, blue)
	var/light_color = rgb(min(red, 1) * 255, min(green, 1) * 255, min(blue, 1) * 255)
	if(sealed)
		interior_light.blend_mode = BLEND_OVERLAY
		interior_light.color = light_color
		interior_light.alpha = 255
		interior_light_block.alpha = 255
		return
	interior_light_block.alpha = 0
	if(red + green + blue <= 0)
		interior_light.alpha = 0
		return
	interior_light.blend_mode = BLEND_ADD
	interior_light.color = light_color
	interior_light.alpha = 255

/obj/structure/ms13_vehicle_frame/proc/update_roof_damage()
	if(!roof)
		return
	var/is_damaged = roof_hull_breached
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in vehicle?.walls)
		if(wall.parent_frame == src && wall.exterior && wall.get_integrity() < wall.max_integrity)
			is_damaged = TRUE
			break
	roof.icon = is_damaged && roof_damaged_icon ? roof_damaged_icon : roof_undamaged_icon
	roof.color = is_damaged && !roof_damaged_icon ? roof_damage_color : null

/obj/structure/ms13_vehicle_frame/Destroy()
	GLOB.ms13_vehicle_roofs -= roof
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images -= roof
		viewer.images -= interior_light
		viewer.images -= interior_light_block
	roof = null
	interior_light = null
	interior_light_block = null
	if(vehicle?.pivot == src)
		vehicle.destroy_soundloops()
	vehicle?.stop_motion()
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
	wall.finish_mount()
	vehicle.walls += wall
	vehicle.update_interior_lighting()
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
	var/list/mask_view = getviewsize(client.view)
	var/extended_view = "[mask_view[1] + 4]x[mask_view[2] + 4]"
	// ponytail: rebuilds the visible mask plus a two-tile margin; cache rays if vehicle sizes grow.
	for(var/turf/target in range(extended_view, src))
		if(!vehicle.blocks_sight_from(get_turf(src), target))
			continue
		var/image/mask = image(icon = 'icons/effects/alphacolors.dmi', loc = target, layer = ABOVE_ALL_MOB_LAYER)
		mask.color = "#000000"
		mask.plane = FULLSCREEN_PLANE
		mask.layer = FOV_EFFECTS_LAYER
		mask.appearance_flags = RESET_COLOR | RESET_TRANSFORM
		mask.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		ms13_vehicle_interior_masks += mask
	client.images += ms13_vehicle_interior_masks

/mob/Login()
	. = ..()
	if(!. || !client)
		return
	client.images |= GLOB.ms13_vehicle_roofs
	client.images |= GLOB.ms13_vehicle_exterior_part_images
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
