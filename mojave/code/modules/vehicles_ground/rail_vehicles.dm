/// Visible, destructible guide rails. Cable art, not electrical cables: these never join a powernet.
/obj/structure/ms13_rail
	name = "rail"
	desc = "A ground-vehicle guide rail. Adjacent cardinal rails connect automatically."
	icon = 'icons/obj/power_cond/cable.dmi'
	icon_state = "0"
	color = "#999999"
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	density = FALSE
	anchored = TRUE
	max_integrity = 200
	var/is_station = FALSE

/obj/structure/ms13_rail/station
	name = "rail stop"
	desc = "A stopping point for automated trains. Route boards name it after the area it sits in."
	color = "#ffcc33"
	is_station = TRUE

/// What route boards call this stop: the area it was mapped into.
/obj/structure/ms13_rail/proc/stop_name()
	var/area/stop_area = get_area(src)
	return stop_area.name

/obj/structure/ms13_rail/Initialize(mapload)
	. = ..()
	refresh_connections()

/obj/structure/ms13_rail/proc/refresh_connections()
	update_appearance(UPDATE_OVERLAYS)
	for(var/direction in GLOB.cardinals)
		var/obj/structure/ms13_rail/neighbor = locate() in get_step(src, direction)
		neighbor?.update_appearance(UPDATE_OVERLAYS)

/obj/structure/ms13_rail/update_overlays()
	. = ..()
	for(var/direction in GLOB.cardinals)
		var/obj/structure/ms13_rail/neighbor = locate() in get_step(src, direction)
		if(neighbor && !QDELETED(neighbor))
			. += mutable_appearance(icon, "[direction]")

/obj/structure/ms13_rail/Destroy()
	refresh_connections()
	return ..()

/datum/ms13_ground_vehicle/rail
	mass_per_frame = 1200
	max_turn_speed = 1
	fuel_per_tile = 0.1
	acceleration_delay = 0.5 SECONDS
	var/list/rail_route
	/// Speed bands shed per movement tick; stopping distance is computed using the same rule.
	var/braking_power = 1
	/// The frame riding the guide rail. The line can run under any part of the hull, not just the pivot.
	var/obj/structure/ms13_vehicle_frame/rail_bogie

/proc/ms13_rail_at(turf/location)
	return location ? (locate(/obj/structure/ms13_rail) in location) : null

/**
 * The frame currently on the guide rail: the one it was already riding while that still holds, otherwise the
 * one nearest the middle of the hull. Null when nothing of the vehicle is over a rail at all.
 */
/datum/ms13_ground_vehicle/rail/proc/rail_frame()
	if(rail_bogie && !QDELETED(rail_bogie) && (rail_bogie in frames) && ms13_rail_at(get_turf(rail_bogie)))
		return rail_bogie
	rail_bogie = null
	var/min_forward = INFINITY
	var/max_forward = -INFINITY
	var/min_right = INFINITY
	var/max_right = -INFINITY
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		min_forward = min(min_forward, frame.forward_offset)
		max_forward = max(max_forward, frame.forward_offset)
		min_right = min(min_right, frame.right_offset)
		max_right = max(max_right, frame.right_offset)
	var/best_score
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		if(!ms13_rail_at(get_turf(frame)))
			continue
		var/score = abs(frame.forward_offset - (min_forward + max_forward) / 2) + abs(frame.right_offset - (min_right + max_right) / 2)
		if(isnull(best_score) || score < best_score)
			best_score = score
			rail_bogie = frame
	return rail_bogie

/datum/ms13_ground_vehicle/rail/can_operate_steering()
	return length(rail_route) || ..()

/// Conservatively reserve the turning apron, not just the final footprint: a long car must not
/// rotate through a house merely because its final orientation happens to be clear.
/datum/ms13_ground_vehicle/rail/can_rotate(new_dir)
	if(!..())
		return FALSE
	var/min_x = pivot.x
	var/max_x = pivot.x
	var/min_y = pivot.y
	var/max_y = pivot.y
	var/turn_radius = 0
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		var/turf/destination = get_relative_turf(frame.forward_offset, frame.right_offset, new_dir)
		min_x = min(min_x, frame.x, destination.x)
		max_x = max(max_x, frame.x, destination.x)
		min_y = min(min_y, frame.y, destination.y)
		max_y = max(max_y, frame.y, destination.y)
		turn_radius = max(turn_radius, abs(frame.forward_offset), abs(frame.right_offset))
	if(new_dir == turn(dir, 180))
		min_x = pivot.x - turn_radius
		max_x = pivot.x + turn_radius
		min_y = pivot.y - turn_radius
		max_y = pivot.y + turn_radius
	if(min_x < 1 || min_y < 1 || max_x > world.maxx || max_y > world.maxy)
		return FALSE
	var/list/aboard = get_all_parts() | get_manifest()
	for(var/turf/ground in block(locate(min_x, min_y, pivot.z), locate(max_x, max_y, pivot.z)))
		if(ground.density)
			return FALSE
		for(var/atom/movable/blocker in ground)
			if(!(blocker in aboard) && blocks_vehicle(blocker))
				return FALSE
	return TRUE

/datum/ms13_ground_vehicle/rail/stop_motion()
	rail_route = null
	return ..()

/// Rail cars are never driven by hand; they only run routes picked at the controls.
/datum/ms13_ground_vehicle/rail/handle_drive_input(direction)
	return FALSE

/datum/ms13_ground_vehicle/rail/do_move(direction, bypass_cooldown = FALSE)
	var/obj/structure/ms13_vehicle_frame/bogie = rail_frame()
	if(!bogie || !ms13_rail_at(get_step(bogie, direction)))
		return FALSE
	// Region transfer relocates the whole hull further than one rail tile; not a supported rail link yet.
	if(SSmapping.ms13_surface_links["[pivot.z]"])
		for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
			if(SSmapping.ms13_surface_edge(get_step(frame, direction)))
				return FALSE
	. = ..()
	if(. && length(rail_route))
		if(get_turf(rail_frame()) == rail_route[1])
			rail_route.Cut(1, 2)
		else
			stop_motion()

/// One bounded breadth-first search when selecting a destination, never a world scan each tick.
/datum/ms13_ground_vehicle/rail/proc/find_rail_routes()
	var/obj/structure/ms13_vehicle_frame/bogie = rail_frame()
	var/list/parents = list()
	if(!bogie)
		return parents
	var/turf/start = get_turf(bogie)
	var/list/queue = list(start)
	parents[start] = start
	// ponytail: 4096 connected tiles per trip; use incremental pathfinding for larger rail networks.
	for(var/index = 1, index <= length(queue) && index <= 4096, index++)
		var/turf/current = queue[index]
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(current, direction)
			if(!neighbor || parents[neighbor] || !(locate(/obj/structure/ms13_rail) in neighbor))
				continue
			parents[neighbor] = current
			queue += neighbor
	return parents

/// Every stop on the line this car rides, given the parents from find_rail_routes().
/datum/ms13_ground_vehicle/rail/proc/find_stops(list/parents)
	. = list()
	for(var/turf/location as anything in parents)
		for(var/obj/structure/ms13_rail/rail in location)
			if(rail.is_station)
				. += rail

/datum/ms13_ground_vehicle/rail/proc/choose_destination(mob/living/user, obj/structure/chair/ms13_vehicle_seat/seat)
	var/list/stops = list()
	for(var/obj/structure/ms13_rail/stop as anything in find_stops(find_rail_routes()))
		if(get_turf(stop) != get_turf(rail_frame()))
			stops["[stop.stop_name()] ([stop.x], [stop.y])"] = get_turf(stop)
	if(!length(stops))
		to_chat(user, span_warning("No connected rail stops found."))
		return
	var/choice = input(user, "Select a connected stop. Clear space is needed around corners.", "Rail destination") as null|anything in stops
	if(!choice || !seat.can_use_controls(user) || seat.parent_frame.vehicle != src)
		return
	depart_for(stops[choice], user)

/// Starts the engine and runs the line to destination. FALSE, with user told why, when it can't go.
/datum/ms13_ground_vehicle/rail/proc/depart_for(turf/destination, mob/user)
	// Searched afresh: the car may have moved since the stop was picked.
	var/list/parents = find_rail_routes()
	if(!parents[destination] || destination == get_turf(rail_frame()))
		return FALSE
	stop_motion()
	set_ignition(TRUE)
	if(!start_engine(user))
		return FALSE
	if(!has_motive_power())
		if(user)
			to_chat(user, span_warning("The drive won't engage. Check the wheels and gearbox."))
		return FALSE
	rail_route = list()
	while(destination != get_turf(rail_frame()))
		rail_route.Insert(1, destination)
		destination = parents[destination]
	brakes_mode = FALSE
	speed = 1
	travel_dir = dir
	start_motion()
	return TRUE

/datum/ms13_ground_vehicle/rail/proc/stopping_distance()
	return CEILING(speed / max(1, braking_power), 1)

/datum/ms13_ground_vehicle/rail/movement_tick(generation)
	if(!rail_route)
		return ..()
	if(generation != movement_generation || !moving || !speed)
		return
	if(!length(rail_route) || !has_motive_power())
		stop_motion()
		return
	var/obj/structure/ms13_vehicle_frame/bogie = rail_frame()
	if(!bogie)
		stop_motion()
		return
	var/turf/next = rail_route[1]
	if(get_dist(bogie, next) != 1 || next.z != bogie.z)
		stop_motion()
		return
	var/direction = get_dir(bogie, next)
	if(direction == dir || direction == turn(dir, 180))
		// Either end can lead: backing up needs no turn.
		travel_dir = direction
	else
		if(speed > max_turn_speed)
			speed = max(max_turn_speed, speed - max(1, braking_power))
		else if(world.time >= next_move_time)
			// Swing whichever end leads onto the new line.
			if(!full_turn(travel_dir == turn(dir, 180) ? turn(direction, 180) : direction))
				stop_motion()
				return
		addtimer(CALLBACK(src, PROC_REF(movement_tick), generation), gear_delay(speed))
		return
	// Brake before a corner or the final stop, using the same per-tile deceleration as movement.
	var/straight = 0
	var/turf/previous = get_turf(bogie)
	for(var/turf/rail_tile as anything in rail_route)
		if(get_dir(previous, rail_tile) != travel_dir)
			break
		straight++
		previous = rail_tile
		if(straight > gear_count() + 1)
			break
	if(straight <= stopping_distance())
		speed = max(1, speed - max(1, braking_power))
	else if(world.time >= next_acceleration_time)
		speed = min(gear_count(), speed + 1)
		next_acceleration_time = world.time + acceleration_delay
	. = ..()
	if(rail_route && !length(rail_route))
		stop_motion()

/// Rigid, ordinary vehicle formations; the front-left pivot follows the guide rail.
/obj/structure/ms13_vehicle_frame/tram
	name = "small tram"
	vehicle_controller_type = /datum/ms13_ground_vehicle/rail
	var/car_length = 4
	var/car_width = 2

/obj/structure/ms13_vehicle_frame/tram/train
	name = "short train"
	car_length = 6
	car_width = 3

/obj/structure/ms13_vehicle_frame/tram/Initialize(mapload)
	. = ..()
	vehicle = new vehicle_controller_type
	vehicle.pivot = src
	vehicle.dir = dir
	vehicle.frames += src
	// Validate the whole assembly before adding any components.
	for(var/back in 0 to car_length - 1)
		for(var/right in 0 to car_width - 1)
			var/turf/target = vehicle.get_relative_turf(-back, right, dir)
			if(!target || target.density)
				return INITIALIZE_HINT_QDEL
			for(var/atom/movable/blocker in target)
				if(blocker == src || ismob(blocker))
					continue
				if(vehicle.blocks_vehicle(blocker))
					return INITIALIZE_HINT_QDEL
	// Boarding is from the platform alongside: one door each side, and the row inside them kept clear.
	var/door_row = round(car_length / 2)
	var/lamp_column = round((car_width - 1) / 2)
	for(var/back in 0 to car_length - 1)
		for(var/right in 0 to car_width - 1)
			var/obj/structure/ms13_vehicle_frame/frame = (!back && !right) ? src : add_segment(-back, right, "frame_steel", "roof_steel")
			if(!back)
				frame.spawn_wall(dir, "c_windshield", /obj/structure/window/ms13_vehicle_wall/shuttered)
			if(back == car_length - 1)
				frame.spawn_wall(turn(dir, 180), , /obj/structure/window/ms13_vehicle_wall/solid)
				frame.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light, 180)
			var/side_type = back == door_row ? /obj/structure/window/ms13_vehicle_wall/solid/door : /obj/structure/window/ms13_vehicle_wall/shuttered
			var/side_art = back == door_row ? null : "c_window"
			if(!right)
				frame.spawn_wall(turn(dir, 90), side_art, side_type)
			if(right == car_width - 1)
				frame.spawn_wall(turn(dir, -90), side_art, side_type)
			if(!(back % 2) && right == lamp_column)
				frame.spawn_part(/obj/structure/ms13_vehicle_part/interior_light)
			if(frame == src)
				var/obj/structure/chair/ms13_vehicle_seat/driver_seat = frame.add_seat(0, "rail driver's seat")
				driver_seat.configure_driver_seat()
			else if(!back && right == car_width - 1)
				frame.spawn_part(/obj/structure/ms13_vehicle_part/rail_terminal, 180)
			else if(back != door_row)
				frame.add_seat(0, "rail passenger seat")
			if(!back || back == car_length - 1)
				if(!right)
					frame.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 90)
				if(right == car_width - 1)
					frame.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, -90)
	spawn_part(/obj/structure/ms13_vehicle_part/engine)
	spawn_part(/obj/structure/ms13_vehicle_part/gearbox/three_speed)
	spawn_part(/obj/structure/ms13_vehicle_part/fuel_tank/large)
	spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light)

/// The car's route board: a line map of the connected rails and their stops. Pick one and the car runs there.
/obj/structure/ms13_vehicle_part/rail_terminal
	name = "route terminal"
	desc = "A RobCo transit terminal showing the line and its stops. It runs off the car's battery."
	icon = 'mojave/icons/structure/terminals.dmi'
	icon_state = "terminal"
	pixel_y = 8
	layer = BELOW_OBJ_LAYER
	max_integrity = 100

/obj/structure/ms13_vehicle_part/rail_terminal/proc/is_powered()
	return is_operational() && vehicle?.battery?.is_operational() && vehicle.battery.cell?.charge > 0

/obj/structure/ms13_vehicle_part/rail_terminal/update_icon_state()
	icon_state = broken ? "terminal_ruined" : "terminal"
	return ..()

/obj/structure/ms13_vehicle_part/rail_terminal/update_overlays()
	. = ..()
	if(is_powered())
		. += mutable_appearance(icon, "terminal_screen")
		. += emissive_appearance(icon, "terminal_screen", alpha = 180)

/obj/structure/ms13_vehicle_part/rail_terminal/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	update_appearance()

/obj/structure/ms13_vehicle_part/rail_terminal/atom_fix()
	. = ..()
	broken = FALSE
	update_appearance()

/obj/structure/ms13_vehicle_part/rail_terminal/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	ui_interact(user)
	return TRUE

/obj/structure/ms13_vehicle_part/rail_terminal/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "RailTerminal", name)
		ui.open()

/// Worked from inside the car only, like the driver's controls.
/obj/structure/ms13_vehicle_part/rail_terminal/ui_status(mob/user, datum/ui_state/state)
	if(!isobserver(user) && (get_ms13_ground_vehicle_at(user) != vehicle || (user in vehicle?.underneath)))
		return UI_CLOSE
	return ..()

/obj/structure/ms13_vehicle_part/rail_terminal/ui_static_data(mob/user)
	var/datum/ms13_ground_vehicle/rail/train = vehicle
	if(!istype(train))
		return list()
	var/list/parents = train.find_rail_routes()
	var/list/rails = list()
	for(var/turf/location as anything in parents)
		rails += list(list(location.x, location.y))
	var/list/stops = list()
	for(var/obj/structure/ms13_rail/stop as anything in train.find_stops(parents))
		stops += list(list("ref" = REF(stop), "name" = stop.stop_name(), "x" = stop.x, "y" = stop.y))
	return list("rails" = rails, "stops" = stops)

/obj/structure/ms13_vehicle_part/rail_terminal/ui_data(mob/user)
	var/datum/ms13_ground_vehicle/rail/train = vehicle
	var/obj/structure/ms13_vehicle_frame/bogie = istype(train) ? train.rail_frame() : null
	var/area/location = get_area(bogie)
	var/obj/structure/ms13_rail/destination
	if(length(train?.rail_route))
		for(var/obj/structure/ms13_rail/rail in train.rail_route[length(train.rail_route)])
			if(rail.is_station)
				destination = rail
	return list(
		"powered" = is_powered(),
		"moving" = !!train?.moving,
		"train" = bogie ? list(bogie.x, bogie.y) : null,
		"location" = location?.name,
		"destination" = destination ? REF(destination) : null,
	)

/obj/structure/ms13_vehicle_part/rail_terminal/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/ms13_ground_vehicle/rail/train = vehicle
	if(!istype(train) || !is_powered())
		return
	switch(action)
		if("depart")
			var/obj/structure/ms13_rail/stop = locate(params["stop"])
			if(istype(stop) && stop.is_station)
				train.depart_for(get_turf(stop), usr)
			return TRUE
		if("halt")
			train.stop_motion()
			return TRUE
