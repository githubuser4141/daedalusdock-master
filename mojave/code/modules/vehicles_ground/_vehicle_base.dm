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
	/// Approximate loaded mass per floor tile; mapper/controller tuning, not a rigid-body simulation.
	var/mass_per_frame = 500
	var/being_pushed = FALSE
	/// Retain sub-band collision losses instead of granting fresh momentum for each fence post.
	var/impact_energy_reserve
	var/impact_speed_band = 0
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
	/// How fast this vehicle drives: every gear's move delay is divided by it. 1 drives the gearbox's own
	/// delays, 2 is twice as fast, 0.5 half as fast. Set it per vehicle; it needs no other tuning.
	var/speed_multiplier = 1.25
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
	/// Low-speed, input-only maneuvering instead of continuous momentum.
	var/brakes_mode = FALSE
	var/travel_dir
	var/moving = FALSE
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
	if(brakes_mode)
		// Braking mode is a fixed crawl, whatever the vehicle's top speed.
		return max(1 SECONDS, delays[1])
	return delays[clamp(gear, 1, length(delays))] / max(speed_multiplier, 0.1)

/datum/ms13_ground_vehicle/proc/get_all_parts()
	. = list()
	. += frames
	. += walls
	. += parts

/// Shows this vehicle's roof to an outside viewer, or hides it from somebody aboard.
/datum/ms13_ground_vehicle/proc/set_roof_visible(client/viewer, visible)
	if(viewer.mob in underneath)
		visible = TRUE
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
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		if(!wall.exterior_image)
			continue
		if(visible)
			viewer.images |= wall.exterior_image
		else
			viewer.images -= wall.exterior_image
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
/// new throttle, but does not cancel existing momentum.
/datum/ms13_ground_vehicle/proc/has_motive_power()
	if(!engine_running || !engine?.is_operational() || !gear_count())
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
/datum/ms13_ground_vehicle/proc/boundary_blocks_vision(obj/structure/ms13_vehicle_frame/frame, exit_dir, turf/viewer_turf, use_cameras = FALSE)
	if(use_cameras && camera_covers_edge(frame, exit_dir))
		return FALSE
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		if(wall.parent_frame != frame || !(wall.dir & exit_dir))
			continue
		if(wall.blocks_sight())
			return TRUE
		if(!isnull(wall.vision_range) && get_dist(viewer_turf, get_turf(frame)) > wall.vision_range)
			return TRUE
	return FALSE

/// True when the line from an interior turf to target first exits through solid hull.
/datum/ms13_ground_vehicle/proc/blocks_sight_from(turf/source, turf/target, use_cameras = FALSE)
	var/obj/structure/ms13_vehicle_frame/current_frame = get_frame_at(source)
	if(!current_frame || get_frame_at(target))
		return FALSE
	var/list/sight_line = get_line(source, target)
	var/turf/current_turf = source
	for(var/index in 2 to length(sight_line))
		var/turf/next_turf = sight_line[index]
		var/obj/structure/ms13_vehicle_frame/next_frame = get_frame_at(next_turf)
		if(current_frame && !next_frame && boundary_blocks_vision(current_frame, get_dir(current_turf, next_turf), source, use_cameras))
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
			if(isliving(blocker) && can_run_over(blocker))
				continue
			// Vehicle floors are non-dense, but another vehicle's footprint is never empty road.
			if(blocks_vehicle(blocker))
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
	var/rammed = FALSE
	for(var/mob/living/victim as anything in victims)
		if(QDELETED(victim) || can_run_over(victim))
			continue
		rammed = TRUE
		var/turf/push_turf = get_step(victim, direction)
		var/can_push = can_push_living(victim, push_turf)
		victim.visible_message(span_danger("[pivot] rams [victim]!"), span_userdanger("[pivot] rams into you!"))
		victim.apply_damage(ram_damage_base + ram_damage_per_speed * impact_speed, BRUTE, BODY_ZONE_CHEST)
		if(QDELETED(victim)) // Robots and other death effects can delete the victim immediately.
			continue
		victim.Knockdown(ram_knockdown_per_speed * impact_speed)
		if(!can_push)
			return FALSE
		victim.forceMove(push_turf)
	if(rammed)
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
			if(isliving(blocker) && can_run_over(blocker))
				continue
			if(blocks_vehicle(blocker))
				return FALSE
	return TRUE

/// Builds the manifest of everything currently standing on any frame tile that isn't part of the
/// vehicle itself, tagged with which frame it was on - shared by do_move() and do_rotate() so both
/// carry passengers along the same way.
/datum/ms13_ground_vehicle/proc/get_manifest()
	. = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/atom/movable/passenger in frame.loc)
			if(is_aboard(passenger))
				.[passenger] = frame

/// Each leading tile strikes with its own outward armor (or its exposed frame).
/// ponytail: mass times speed-band squared approximates kinetic energy, not full rigid-body physics.
/datum/ms13_ground_vehicle/proc/ram_obstacles(direction, list/manifest)
	var/list/impacted = list()
	var/list/pushed = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames.Copy())
		var/turf/destination = get_step(frame, direction)
		if(!destination)
			return FALSE
		var/list/obstacles = list()
		if(destination.density)
			obstacles += destination
		// Check structures as well as the turf, including windows stacked on low walls.
		for(var/atom/movable/obstacle in destination)
			if(blocks_vehicle(obstacle) && !isliving(obstacle) && !(obstacle in manifest) && !(obstacle in parts) && !(obstacle in walls) && !(obstacle in frames))
				obstacles += obstacle
		for(var/atom/obstacle as anything in obstacles)
			if(QDELETED(obstacle) || (obstacle in impacted))
				continue
			impacted += obstacle
			var/datum/ms13_ground_vehicle/struck = get_ms13_ground_vehicle_at(obstacle)
			if(struck && struck != src && !(struck in pushed))
				pushed += struck
				if(try_shove_vehicle(struck, direction))
					// Its entire formation moved; all cached obstacles on this tile are stale.
					break
			var/obj/contact = frame
			for(var/obj/structure/window/ms13_vehicle_wall/panel as anything in walls)
				if(panel.parent_frame == frame && panel.exterior && panel.density && panel.dir != turn(direction, 180))
					contact = panel
					// Side panels also have a leading edge, even after the front plating is gone.
					if(panel.dir == direction)
						break
			if(!damage_collision(obstacle, contact, direction) || QDELETED(frame))
				return FALSE
	return TRUE

/datum/ms13_ground_vehicle/proc/blocks_vehicle(atom/movable/obstacle)
	if(obstacle.density || istype(obstacle, /obj/structure/ms13_vehicle_frame))
		return TRUE
	if(istype(obstacle, /obj/structure/ms13_vehicle_part))
		var/obj/structure/ms13_vehicle_part/part = obstacle
		return !!part.vehicle
	return FALSE

/datum/ms13_ground_vehicle/proc/damage_collision(atom/obstacle, obj/contact, direction)
	if(QDELETED(contact))
		return !QDELETED(pivot)
	var/energy = collision_energy()
	var/contact_armor = clamp(contact.returnArmor().getRating(BLUNT), 0, 100)
	var/efficiency = 0.35 + 0.0065 * contact_armor
	var/impact = energy * efficiency
	var/resistance = clamp(obstacle.returnArmor().getRating(BLUNT), 0, 100)
	var/work = impact
	if(obstacle.uses_integrity && !(obstacle.resistance_flags & INDESTRUCTIBLE) && obstacle.get_integrity() > 0)
		var/integrity_before = obstacle.get_integrity()
		var/dealt = obstacle.take_damage(impact, BRUTE, BLUNT, TRUE, direction)
		// Don't spend a reinforced wall's worth of energy on a flimsy chair. Armor absorption counts.
		if(dealt > 0)
			work = min(impact, min(integrity_before, dealt) / max(0.05, 1 - resistance / 100))
	if(QDELETED(pivot))
		return FALSE
	var/self_damage = 0
	if(!QDELETED(contact))
		var/contact_integrity = contact.get_integrity()
		var/recoil = work * (1 - efficiency) * (0.5 + resistance / 100)
		self_damage = min(contact_integrity, contact.take_damage(recoil, BRUTE, BLUNT, FALSE, turn(direction, 180)) || 0)
	impact_energy_reserve = max(0, energy - work - 1.5 * self_damage)
	var/mass_factor = max(0.1, length(frames) * mass_per_frame / 1000)
	speed = min(speed, CEILING(sqrt(impact_energy_reserve / (50 * mass_factor)), 1))
	impact_speed_band = speed
	if(!speed)
		stop_motion()
		return FALSE
	return !QDELETED(pivot)

/// Driving/gear changes replenish the speed-band estimate; repeated impacts at one band share it.
/datum/ms13_ground_vehicle/proc/collision_energy()
	var/nominal = 50 * max(0.1, length(frames) * mass_per_frame / 1000) * speed ** 2
	if(isnull(impact_energy_reserve) || impact_speed_band != speed)
		impact_energy_reserve = nominal
		impact_speed_band = speed
	return min(nominal, impact_energy_reserve)

/// One physical tile of displacement, only into clear space. No recursive vehicle push chains.
/datum/ms13_ground_vehicle/proc/try_shove_vehicle(datum/ms13_ground_vehicle/struck, direction)
	if(being_pushed || struck.being_pushed || QDELETED(struck.pivot))
		return FALSE
	var/momentum = length(frames) * mass_per_frame * speed
	var/resistance = length(struck.frames) * struck.mass_per_frame * (struck.brakes_mode ? 2 : 1)
	if(momentum < resistance || !struck.can_move(direction))
		return FALSE
	struck.stop_motion()
	struck.being_pushed = TRUE
	var/moved = struck.do_move(direction, TRUE)
	struck.being_pushed = FALSE
	if(moved)
		speed = max(1, speed - 1)
	return moved

/// Moves every frame, every wall, and everyone/everything currently aboard one tile in direction.
/datum/ms13_ground_vehicle/proc/do_move(direction, bypass_cooldown = FALSE)
	if(!bypass_cooldown && world.time < next_move_time)
		return FALSE
	var/list/manifest = get_manifest()
	// Resolve solid impacts before pushing mobs. A surviving obstacle still stops the vehicle.
	if(speed && !ram_obstacles(direction, manifest))
		return FALSE
	if(!can_move(direction, TRUE) || !ram_living(direction, manifest) || !can_move(direction))
		return FALSE
	if(!bypass_cooldown)
		next_move_time = world.time + gear_delay(max(speed, 1))
	// Hull and riders glide each tile together, over the time until the next one; mismatched glides judder.
	var/glide = DELAY_TO_GLIDE_SIZE(gear_delay(max(speed, 1)))
	for(var/atom/movable/thing as anything in get_all_parts() | manifest)
		thing.set_glide_size(glide)

	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		frame.forceMove(get_step(frame, direction))
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls)
		wall.forceMove(get_step(wall, direction))
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		part.forceMove(get_step(part, direction))
	for(var/atom/movable/passenger as anything in manifest)
		// Earlier moves can merge/delete cargo stacks; impacts can destroy their supporting frame.
		if(QDELETED(passenger) || QDELETED(manifest[passenger]))
			continue
		passenger.forceMove(get_step(passenger, direction))
	update_underneath(manifest)
	if(!being_pushed)
		engine?.consume_fuel(fuel_per_tile)
	alert_watchers()
	crush_mines()
	return TRUE

/// Starts at low speed, accelerates while the driver holds the travel direction, and uses the
/// opposite input as a brake before allowing a change between forward and reverse.
/datum/ms13_ground_vehicle/proc/apply_throttle(direction)
	// Brakes are mechanical: no fuel, ignition, or intact drivetrain is needed to slow down.
	if(speed && direction != travel_dir)
		speed--
		next_acceleration_time = world.time + acceleration_delay
		if(!speed)
			stop_motion()
		return TRUE
	if(!has_motive_power())
		return FALSE
	if(brakes_mode)
		if(world.time < next_move_time)
			return FALSE
		speed = 1
		var/moved = do_move(direction)
		stop_motion()
		return moved
	if(!speed)
		travel_dir = direction
		speed = 1
		next_acceleration_time = world.time + acceleration_delay
		start_motion()
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
		return has_motive_power() && full_turn(new_dir)
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
		return FALSE
	var/reversing = speed && travel_dir == turn(dir, 180)
	if(!do_rotate(new_dir))
		return FALSE
	if(speed)
		travel_dir = reversing ? turn(new_dir, 180) : new_dir
		speed = max(1, speed - turn_speed_loss)
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
	impact_energy_reserve = null
	impact_speed_band = 0
	moving = FALSE
	speed = 0
	travel_dir = null
	drift = 0
	drift_progress = 0
	movement_generation++
	set_parts_moving(FALSE)
	running_gear_soundloop?.stop()

/// Self-schedules one tile at a time at the selected speed until explicitly slowed or blocked.
/datum/ms13_ground_vehicle/proc/movement_tick(generation)
	if(generation != movement_generation || !moving || !speed)
		return
	// Engine shutdown/fuel loss winds down momentum rather than coasting forever.
	if(!engine_running || !engine?.is_operational())
		speed--
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
	if(!can_operate_steering() || world.time < next_move_time)
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
		if(QDELETED(passenger))
			continue
		var/obj/structure/ms13_vehicle_frame/old_frame = manifest[passenger]
		passenger.forceMove(frame_dest[old_frame])
		if(istype(passenger, /obj/structure/chair/ms13_vehicle_seat))
			passenger.setDir(turn(passenger.dir, seat_turn))
	update_underneath(manifest)
	alert_watchers()
	crush_mines()
	return TRUE

/datum/ms13_ground_vehicle/proc/can_operate_steering()
	return !!driver

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
	/// The floor: blast power it strips before a blast from underneath reaches the cabin (vehicle_underside.dm).
	explosion_block = 1
	var/datum/ms13_ground_vehicle/vehicle
	/// Concrete frames select a controller subtype containing their handling/impact configuration.
	var/vehicle_controller_type = /datum/ms13_ground_vehicle
	/// Opaque top-down cover shown to outsiders and hidden from clients aboard this vehicle.
	var/image/roof
	var/roof_undamaged_icon
	var/roof_damaged_icon = 'mojave/icons/objects/vehicles_ground/vehicleparts_damaged.dmi'
	/// Used by roofs such as the M113 which have no matching damaged sheet in Civ13.
	var/roof_damage_color
	/// Paint over Civ13's grey hull art, applied to floor, roof, plating and turret.
	var/hull_color
	/// What add_segment() builds the rest of the footprint out of - a type that doesn't assemble itself again.
	var/segment_type = /obj/structure/ms13_vehicle_frame
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
	roof.color = hull_color
	color = hull_color
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
	roof.color = is_damaged && !roof_damaged_icon ? roof_damage_color : hull_color

/obj/structure/ms13_vehicle_frame/Destroy()
	// Tear down supported hardware while the frame and its lighting images are still valid.
	if(vehicle)
		vehicle.stop_motion()
		for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts.Copy())
			if(part.forward_offset == forward_offset && part.right_offset == right_offset)
				part.lose_support()
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(src))
			if(seat.parent_frame == src)
				seat.unbuckle_all_mobs(force = TRUE)
				qdel(seat)
		for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in vehicle.walls.Copy())
			if(wall.parent_frame == src)
				qdel(wall)
	// Power updates rebuild cabin lighting; do this before deleting this frame's lighting images.
	if(vehicle?.pivot == src)
		vehicle.set_ignition(FALSE)
	GLOB.ms13_vehicle_roofs -= roof
	for(var/client/viewer as anything in GLOB.clients)
		if(viewer.mob?.ms13_mask_anchor == src)
			viewer.mob.clear_ms13_vehicle_interior_mask()
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
	vehicle?.uncover_exposed()
	vehicle = null
	return ..()

/obj/structure/ms13_vehicle_frame/deconstruct(disassembled = TRUE, mob/user)
	if(!QDELETED(src) && !(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/scrap_steel(drop_location(), 10)
	return ..()

/obj/structure/ms13_vehicle_frame/setDir(new_dir)
	. = ..()
	if(roof)
		roof.dir = dir

/// Adds a frame tile at (forward, right) from this one, facing the same way (see get_relative_turf()).
/obj/structure/ms13_vehicle_frame/proc/add_segment(forward, right, floor_state, roof_state)
	var/turf/destination = vehicle.get_relative_turf(forward, right, dir)
	var/obj/structure/ms13_vehicle_frame/segment = new segment_type(destination)
	segment.vehicle = vehicle
	segment.forward_offset = forward
	segment.right_offset = right
	segment.icon_state = floor_state
	segment.roof.icon_state = roof_state
	segment.hull_color = hull_color
	segment.explosion_block = explosion_block
	segment.color = hull_color
	segment.roof.color = hull_color
	segment.setDir(dir)
	vehicle.frames += segment
	return segment

/// Mounts a named interior partition; relative_dir is the edge it closes, relative to the vehicle's facing.
/obj/structure/ms13_vehicle_frame/proc/add_bulkhead(relative_dir, wall_name, wall_type = /obj/structure/window/ms13_vehicle_wall/solid/interior)
	var/obj/structure/window/ms13_vehicle_wall/bulkhead = spawn_wall(turn(vehicle.dir, relative_dir), null, wall_type)
	bulkhead.name = wall_name
	return bulkhead

/// Adds a seat on this frame facing relative_dir (0 = forward).
/obj/structure/ms13_vehicle_frame/proc/add_seat(relative_dir, seat_name, seat_icon_state = "commanders_seat")
	var/obj/structure/chair/ms13_vehicle_seat/seat = new(get_turf(src))
	seat.parent_frame = src
	seat.name = seat_name
	seat.icon_state = seat_icon_state
	seat.setDir(turn(vehicle.dir, relative_dir))
	return seat

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
	/// The frame the cabin masks hang from. They glide along with it, so riding straight needs no rebuild.
	var/obj/structure/ms13_vehicle_frame/ms13_mask_anchor
	/// The vehicle's facing when the masks were drawn; turning redraws them.
	var/ms13_mask_dir
	/// The held turret control currently replacing this mob's cabin view with an exterior gunsight.
	var/obj/item/ms13_vehicle_turret_control/ms13_active_gunner_sight

/mob/proc/clear_ms13_vehicle_interior_mask()
	if(client && length(ms13_vehicle_interior_masks))
		client.images -= ms13_vehicle_interior_masks
	ms13_vehicle_interior_masks = null
	ms13_mask_anchor = null

/// Black out only exterior turfs whose ray from this occupant crosses closed solid hull.
/mob/proc/update_ms13_vehicle_interior_mask()
	clear_ms13_vehicle_interior_mask()
	if(!client || ms13_active_gunner_sight || ms13_vehicle_camera)
		return
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(src)
	if(!vehicle || (src in vehicle.underneath))
		return
	var/turf/here = get_turf(src)
	var/obj/structure/ms13_vehicle_frame/anchor = vehicle.get_frame_at(here)
	ms13_mask_anchor = anchor
	ms13_mask_dir = vehicle.dir
	ms13_vehicle_interior_masks = list()
	var/list/mask_view = getviewsize(client.view)
	var/extended_view = "[mask_view[1] + 4]x[mask_view[2] + 4]"
	// ponytail: rebuilds the visible mask plus a two-tile margin; cache rays if vehicle sizes grow.
	for(var/turf/target in range(extended_view, src))
		if(!vehicle.blocks_sight_from(here, target, vehicle.driver == src))
			continue
		var/image/mask = image(icon = 'icons/effects/alphacolors.dmi', loc = anchor, layer = FOV_EFFECTS_LAYER)
		mask.color = "#000000"
		mask.plane = FULLSCREEN_PLANE
		// Offsets from the frame, which carries its own art offset.
		mask.pixel_x = (target.x - anchor.x) * world.icon_size - anchor.pixel_x
		mask.pixel_y = (target.y - anchor.y) * world.icon_size - anchor.pixel_y
		mask.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
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
	ms13_active_gunner_sight?.set_sight(src, FALSE)
	set_ms13_vehicle_camera(null)
	clear_ms13_vehicle_interior_mask()
	return ..()

/mob/living/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(!client)
		return
	var/datum/ms13_ground_vehicle/old_vehicle = get_ms13_ground_vehicle_at(old_loc)
	var/datum/ms13_ground_vehicle/new_vehicle = get_ms13_ground_vehicle_at(src)
	if(ms13_active_gunner_sight && old_vehicle != new_vehicle)
		ms13_active_gunner_sight.set_sight(src, FALSE)
	if(old_vehicle != new_vehicle)
		old_vehicle?.set_roof_visible(client, TRUE)
		new_vehicle?.set_roof_visible(client, FALSE)
	// Carried along on the same frame, facing the same way: the masks moved with it.
	if(new_vehicle && new_vehicle == old_vehicle && ms13_mask_anchor && ms13_mask_dir == new_vehicle.dir && new_vehicle.get_frame_at(get_turf(src)) == ms13_mask_anchor)
		return
	update_ms13_vehicle_interior_mask()
