/// Intercept only a real region crossing. Ordinary movement/ramming stays in the vehicle controller.
/datum/ms13_ground_vehicle/do_move(direction, bypass_cooldown = FALSE)
	if(!QDELETED(pivot) && SSmapping.ms13_surface_links["[pivot.z]"])
		var/result = cross_surface_region(direction, bypass_cooldown)
		if(!isnull(result))
			return result
	return ..()

/// Null means an ordinary step, FALSE a blocked border, TRUE one successful whole-hull crossing.
/datum/ms13_ground_vehicle/proc/cross_surface_region(direction, bypass_cooldown)
	var/list/bounds = SSmapping.ms13_surface_bounds
	var/crossing = FALSE
	var/list/hazards = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/turf/next = get_step(frame, direction)
		if(!next)
			return FALSE
		if((direction == NORTH && next.y >= bounds[4] - TRANSITIONEDGE) || (direction == SOUTH && next.y <= bounds[2] + TRANSITIONEDGE) || (direction == EAST && next.x >= bounds[3] - TRANSITIONEDGE) || (direction == WEST && next.x <= bounds[1] + TRANSITIONEDGE))
			crossing = TRUE
			for(var/obj/structure/ms13_dodgy_crossing/hazard in next)
				hazards |= hazard
	if(!crossing)
		return null
	if(!bypass_cooldown && world.time < next_move_time)
		return FALSE
	if(!can_move(direction))
		return FALSE
	var/destination_z = SSmapping.ms13_surface_links["[pivot.z]"]["[direction]"]
	if(!destination_z)
		return FALSE
	var/min_x = world.maxx
	var/min_y = world.maxy
	var/max_x = 1
	var/max_y = 1
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		min_x = min(min_x, frame.x)
		min_y = min(min_y, frame.y)
		max_x = max(max_x, frame.x)
		max_y = max(max_y, frame.y)
	var/offset_x = 0
	var/offset_y = 0
	switch(direction)
		if(NORTH)
			offset_y = bounds[2] + TRANSITIONEDGE + 1 - min_y
		if(SOUTH)
			offset_y = bounds[4] - TRANSITIONEDGE - 1 - max_y
		if(EAST)
			offset_x = bounds[1] + TRANSITIONEDGE + 1 - min_x
		if(WEST)
			offset_x = bounds[3] - TRANSITIONEDGE - 1 - max_x
	if(!translate_hull(offset_x, offset_y, destination_z, bypass_cooldown))
		return FALSE
	// Hazard damage happens after a completed crossing, never halfway through moving the hull.
	for(var/obj/structure/ms13_dodgy_crossing/hazard as anything in hazards)
		if(!QDELETED(pivot))
			hazard.damage_vehicle(src)
	return TRUE

/// Moves the whole hull, everyone aboard and their cargo by an offset onto destination_z in one go, or nothing at all.
/datum/ms13_ground_vehicle/proc/translate_hull(offset_x, offset_y, destination_z, bypass_cooldown)
	var/list/manifest = get_manifest()
	var/list/movers = get_all_parts() | manifest
	for(var/atom/movable/mover as anything in movers)
		if(!isturf(mover.loc) || mover.z != pivot.z)
			return FALSE
	// Preflight every destination before touching any component or passenger.
	var/list/destinations = list()
	var/list/sights = list()
	for(var/atom/movable/mover as anything in movers)
		var/turf/destination = locate(mover.x + offset_x, mover.y + offset_y, destination_z)
		if(!isopenturf(destination) || isspaceturf(destination) || isopenspaceturf(destination) || SSmapping.ms13_surface_edge(destination) || destination.is_blocked_turf() || istype(destination.loc, /area/shuttle) || get_ms13_ground_vehicle_at(destination))
			return FALSE
		if(SEND_SIGNAL(mover, COMSIG_MOVABLE_LATERAL_Z_MOVE) & COMPONENT_BLOCK_MOVEMENT)
			return FALSE
		destinations[mover] = destination
		if(isliving(mover))
			var/mob/living/rider = mover
			if(rider.ms13_active_gunner_sight)
				sights[rider] = rider.ms13_active_gunner_sight
	// No sleeps: all coordinates are snapshotted. Guard turf callbacks and preserve grabs/buckles.
	for(var/atom/movable/mover as anything in movers)
		mover.set_currently_z_moving(ZMOVING_LATERAL)
		mover.forcemove_should_maintain_grab = TRUE
	for(var/atom/movable/mover as anything in movers)
		if(!QDELETED(mover))
			mover.forceMove(destinations[mover])
	for(var/atom/movable/mover as anything in movers)
		if(!QDELETED(mover))
			mover.set_currently_z_moving(FALSE)
			mover.forcemove_should_maintain_grab = FALSE
	if(!bypass_cooldown)
		next_move_time = world.time + gear_delay(max(speed, 1))
	update_underneath(manifest)
	if(!being_pushed)
		burn_fuel(fuel_per_tile)
	update_interior_masks()
	for(var/mob/living/rider as anything in sights)
		var/obj/item/ms13_vehicle_turret_control/control = sights[rider]
		if(!QDELETED(rider) && !QDELETED(control))
			control.set_sight(rider, TRUE)
			control.update_sight()
	alert_watchers()
	crush_mines()
	return TRUE

/// WIP opt-in road hazard. Place on a crossing line, not an arbitrary remote zone.
/obj/structure/ms13_dodgy_crossing
	name = "unstable crossing"
	desc = "Buckled road plating over an unstable crossing. A heavy vehicle could lose components here."
	icon = 'icons/turf/floors.dmi'
	icon_state = "plating"
	color = "#ad754a"
	density = FALSE
	anchored = TRUE
	var/damage_chance = 35
	var/component_damage = 150
	var/components_hit = 2
	/// On a damaging crossing, chance of losing one non-pivot chassis tile and its fittings.
	var/sever_chance = 15

/obj/structure/ms13_dodgy_crossing/proc/damage_vehicle(datum/ms13_ground_vehicle/vehicle)
	if(QDELETED(vehicle.pivot) || !prob(clamp(damage_chance, 0, 100)))
		return
	vehicle.pivot.visible_message(span_danger("[vehicle.pivot] lurches violently over the unstable crossing!"))
	var/list/candidates = vehicle.parts.Copy()
	for(var/i in 1 to min(max(0, components_hit), length(candidates)))
		var/obj/structure/ms13_vehicle_part/part = pick_n_take(candidates)
		if(!QDELETED(part))
			part.take_damage(max(0, component_damage), BRUTE, BLUNT)
	if(QDELETED(vehicle.pivot) || !prob(clamp(sever_chance, 0, 100)))
		return
	// Tear off an outermost tile, never the pivot. Use normal deconstruction, not orphaned references.
	var/obj/structure/ms13_vehicle_frame/torn
	var/farthest = -1
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		if(frame == vehicle.pivot)
			continue
		var/distance = abs(frame.x - vehicle.pivot.x) + abs(frame.y - vehicle.pivot.y)
		if(distance > farthest)
			torn = frame
			farthest = distance
	if(!torn)
		return
	var/turf/wreck_turf = get_turf(torn)
	for(var/obj/structure/chair/ms13_vehicle_seat/seat in wreck_turf)
		seat.unbuckle_all_mobs(force = TRUE)
		seat.deconstruct(FALSE)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in LAZYCOPY(torn.mounted_walls))
		wall.deconstruct(FALSE)
	for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts.Copy())
		if(get_turf(part) == wreck_turf)
			part.deconstruct(FALSE)
	if(!QDELETED(torn))
		torn.deconstruct(FALSE)
	vehicle.update_interior_masks()

#ifdef UNIT_TESTS
/datum/unit_test/ms13_surface_regions/proc/check_surface_vehicles(center_z, neighbor_z)
	for(var/level in list(center_z, neighbor_z))
		for(var/turf/ground in block(locate(17, 17, level), locate(43, 43, level)))
			ground.ChangeTurf(/turf/open/floor/plating)
	for(var/direction in GLOB.cardinals)
		var/obj/structure/ms13_vehicle_frame/vehicle_pivot = allocate(/obj/structure/ms13_vehicle_frame/armored_truck_front_left, locate(30, 30, center_z))
		var/datum/ms13_ground_vehicle/vehicle = vehicle_pivot.vehicle
		var/obj/structure/chair/ms13_vehicle_seat/seat
		for(var/atom/movable/aboard as anything in vehicle.get_manifest())
			if(istype(aboard, /obj/structure/chair/ms13_vehicle_seat))
				var/obj/structure/chair/ms13_vehicle_seat/candidate = aboard
				if(candidate.is_driver_seat)
					seat = candidate
		var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent, get_turf(seat))
		seat.user_buckle_mob(driver, driver)
		var/obj/item/storage/box/cargo = allocate(/obj/item/storage/box, get_turf(seat))
		var/obj/item/nested_cargo = allocate(/obj/item, cargo)
		vehicle.set_ignition(TRUE)
		vehicle.start_engine()
		vehicle.speed = 3
		vehicle.travel_dir = direction
		vehicle.drift = 1
		var/heading = vehicle.dir
		var/battery_charge = vehicle.stored_charge()
		var/list/layout = list()
		for(var/atom/movable/part as anything in vehicle.get_all_parts())
			layout[part] = list(part.x - vehicle_pivot.x, part.y - vehicle_pivot.y, part.dir, part.get_integrity())
		for(var/step in 1 to 30)
			if(!vehicle.do_move(direction, TRUE) || vehicle_pivot.z == neighbor_z)
				break
		if(vehicle_pivot.z != neighbor_z || vehicle.speed != 3 || vehicle.travel_dir != direction || vehicle.dir != heading || vehicle.drift != 1 || !vehicle.engine_running || vehicle.stored_charge() != battery_charge)
			Fail("Whole-truck crossing lost motion/electrical state for direction [direction].")
		if(driver.buckled != seat || vehicle.driver != driver || driver.z != neighbor_z || cargo.z != neighbor_z || nested_cargo.loc != cargo)
			Fail("Whole-truck crossing lost a driver, buckle, or nested cargo.")
		for(var/atom/movable/part as anything in layout)
			var/list/original = layout[part]
			if(part.z != neighbor_z || part.x - vehicle_pivot.x != original[1] || part.y - vehicle_pivot.y != original[2] || part.dir != original[3] || part.get_integrity() != original[4])
				Fail("Whole-truck crossing changed a component/layout: [part].")
		// Clean up the formation, not just its pivot (the frame destructor deliberately leaves wrecks).
		for(var/atom/movable/part as anything in (vehicle.get_all_parts() | vehicle.get_manifest()))
			qdel(part)
	// A failed preflight must leave every tile on the source side and avoid spending fuel/moving cargo.
	var/obj/structure/ms13_vehicle_frame/jeep_front/jeep = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, locate(30, 41, center_z))
	var/datum/ms13_ground_vehicle/vehicle = jeep.vehicle
	var/obj/structure/blocker = allocate(/obj/structure, locate(30, 18, neighbor_z))
	blocker.density = TRUE
	if(vehicle.do_move(NORTH, TRUE) || jeep.z != center_z || jeep.y != 41)
		Fail("Blocked whole-vehicle crossing moved part of the vehicle.")
	for(var/atom/movable/part as anything in vehicle.get_all_parts())
		if(part.z != center_z)
			Fail("Blocked crossing split a vehicle across z-levels.")
	qdel(blocker)
	blocker = allocate(/obj/structure, locate(30, 43, center_z))
	blocker.density = TRUE
	if(vehicle.do_move(NORTH, TRUE) || jeep.z != center_z)
		Fail("Whole-vehicle crossing bypassed a blocked departure lane.")
	qdel(blocker)
	var/obj/structure/ms13_vehicle_frame/rear = vehicle.frames[2]
	var/obj/item/loose_cargo = allocate(/obj/item, get_turf(rear))
	var/obj/structure/ms13_dodgy_crossing/hazard = allocate(/obj/structure/ms13_dodgy_crossing, locate(30, 43, center_z))
	hazard.damage_chance = 100
	hazard.components_hit = 0
	hazard.sever_chance = 100
	vehicle.speed = 3
	if(!vehicle.do_move(NORTH, TRUE) || jeep.z != neighbor_z || !QDELETED(rear) || length(vehicle.frames) != 1 || vehicle.speed)
		Fail("Dodgy crossing did not destroy a real frame and stop the vehicle.")
	if(vehicle.get_frame_at(get_turf(loose_cargo)) || !(locate(/obj/item/stack/sheet/ms13/scrap_steel) in get_turf(loose_cargo)))
		Fail("Severed crossing did not leave cargo with real steel wreckage.")
	for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts)
		if(!vehicle.get_frame_at(get_turf(part)))
			Fail("Severed crossing left an orphaned live component.")
	for(var/atom/movable/part as anything in (vehicle.get_all_parts() | vehicle.get_manifest()))
		qdel(part)
#endif
