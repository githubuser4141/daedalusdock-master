/**
 * Rail service: cars that run the line by themselves, call buttons at stops, and several cars sharing one line.
 *
 * None of it processes. Automatic service runs on timers: a car calls at the nearest stop it hasn't called at yet,
 * opens its power doors for a while, and moves on; once it has called at every stop it starts over. A car checks the
 * line ahead as it moves: sighting another car it slows to stop short of it, and an automatic car sounds its horn and
 * asks a standing one to move on to a stop further along. A car held up behind another waits, looking again once a
 * second, and carries on when the way clears.
 *
 * Cars say what they're doing through their route terminal: arriving, holding for a car ahead, setting off. Before
 * setting off on their own (on service, called, or asked to move) they ring, warn everyone clear of the doors, and
 * shut them a few seconds later.
 */

/// A car on automatic service asks a standing car this close ahead to move on.
#define MS13_RAIL_PING_RANGE 8
/// How often a car held up behind another looks again.
#define MS13_RAIL_WAIT_INTERVAL 1 SECONDS
/// How long a train door stays open after a car last asked, and how often it looks again while one's in the doorway.
#define MS13_TRAIN_DOOR_LINGER (2 SECONDS)

/// Rail cars, by their pivot, for call buttons to find.
GLOBAL_LIST_EMPTY(ms13_rail_cars)

/datum/ms13_ground_vehicle/rail
	/// Runs itself from stop to stop, calling at each on the line.
	var/automated = FALSE
	/// Stops called at since it last started over.
	var/list/called_at
	/// How long it stands at a stop with its doors open.
	var/dwell_time = 15 SECONDS
	var/service_timer
	/// The stop it's running to, or last called at.
	var/obj/structure/ms13_rail/service_stop
	/// Another car on the line ahead, from the last look.
	var/datum/ms13_ground_vehicle/car_ahead
	COOLDOWN_DECLARE(next_ping)
	/// The drive is pulling, rather than coasting at speed.
	var/thrusting = TRUE
	var/thrust_sound = 'sound/vehicles/carrev.ogg'
	/// Where it's about to set off for, after warning everyone clear of the doors.
	var/turf/pending_destination
	var/departure_timer
	/// Standing behind another car, waiting for it to move.
	var/held_up = FALSE

/// Says message through the car's route terminal, to those aboard and on the platform. A car without one stays quiet.
/datum/ms13_ground_vehicle/rail/proc/announce(message)
	var/obj/structure/ms13_vehicle_part/rail_terminal/speaker = locate() in parts
	if(speaker?.is_powered())
		speaker.say(message)

/// Rings, warns everyone clear of the doors, then shuts them and sets off a few seconds later.
/datum/ms13_ground_vehicle/rail/proc/warn_and_depart(obj/structure/ms13_rail/stop, reason)
	service_stop = stop
	pending_destination = get_turf(stop)
	playsound(pivot, 'mojave/sound/ms13machines/bell.ogg', 50, TRUE)
	announce("[reason ? "[reason] " : ""]Stand clear of the doors. Departing for [stop.stop_name()].")
	deltimer(departure_timer)
	departure_timer = addtimer(CALLBACK(src, PROC_REF(finish_departure)), 3 SECONDS, TIMER_STOPPABLE)

/datum/ms13_ground_vehicle/rail/proc/finish_departure()
	var/turf/destination = pending_destination
	pending_destination = null
	departure_timer = null
	if(!destination || moving || QDELETED(pivot))
		return FALSE
	work_power_doors("close")
	if(depart_for(destination))
		return TRUE
	if(automated)
		next_leg_in(10 SECONDS)
	return FALSE

/// Enough power to set off: always, for a car carrying its own fuel.
/datum/ms13_ground_vehicle/rail/proc/has_power_to_go()
	return TRUE

/datum/ms13_ground_vehicle/rail/proc/set_automated(on)
	automated = on
	called_at = null
	deltimer(service_timer)
	service_timer = null
	if(on)
		next_leg_in(0)

/datum/ms13_ground_vehicle/rail/proc/next_leg_in(delay)
	deltimer(service_timer)
	service_timer = addtimer(CALLBACK(src, PROC_REF(run_next_leg)), delay, TIMER_STOPPABLE)

/// Sets off for the nearest stop it hasn't called at yet. Once it has called at them all, it starts over.
/datum/ms13_ground_vehicle/rail/proc/run_next_leg()
	if(!automated || moving || QDELETED(pivot))
		return
	var/list/parents = find_rail_routes()
	var/turf/here = get_turf(rail_frame())
	var/obj/structure/ms13_rail/next = nearest_stop(parents, here, called_at)
	if(!next)
		called_at = list()
		for(var/obj/structure/ms13_rail/stop in here)
			if(stop.is_station)
				called_at += stop
		next = nearest_stop(parents, here, called_at)
	if(!next)
		next_leg_in(30 SECONDS)
		return
	warn_and_depart(next)

/// The stop fewest tiles along the line from here, leaving out those given.
/datum/ms13_ground_vehicle/rail/proc/nearest_stop(list/parents, turf/here, list/except)
	var/best_length = INFINITY
	for(var/obj/structure/ms13_rail/stop as anything in find_stops(parents))
		var/turf/stop_turf = get_turf(stop)
		if(stop_turf == here || (stop in except))
			continue
		var/length = route_length(parents, stop_turf)
		if(length < best_length)
			best_length = length
			. = stop

/// Tiles along the line from where the route search started to destination.
/datum/ms13_ground_vehicle/rail/proc/route_length(list/parents, turf/destination)
	. = 0
	while(parents[destination] && parents[destination] != destination)
		destination = parents[destination]
		.++

/// Arrived at the end of a route: names the stop. On service: a bell, doors open, and the next leg after a while.
/datum/ms13_ground_vehicle/rail/proc/arrived()
	var/obj/structure/ms13_rail/stop = locate(/obj/structure/ms13_rail/station) in get_turf(rail_frame())
	if(stop)
		announce("This is [stop.stop_name()].")
	if(!automated)
		return
	if(stop)
		LAZYOR(called_at, stop)
	playsound(pivot, 'mojave/sound/ms13machines/bell.ogg', 50, TRUE)
	work_power_doors("open")
	next_leg_in(dwell_time)

/// Another car sighted on the line ahead: how many clear tiles lie between them, or null for none in limit tiles.
/datum/ms13_ground_vehicle/rail/proc/gap_to_car_ahead(limit)
	car_ahead = null
	var/obj/structure/ms13_vehicle_frame/bogie = rail_frame()
	var/step_x = (travel_dir & EAST) ? 1 : (travel_dir & WEST) ? -1 : 0
	var/step_y = (travel_dir & NORTH) ? 1 : (travel_dir & SOUTH) ? -1 : 0
	// How far this car's own hull reaches ahead of the bogie.
	var/reach = 0
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		reach = max(reach, (frame.x - bogie.x) * step_x + (frame.y - bogie.y) * step_y)
	for(var/index in 1 to min(length(rail_route), limit + reach))
		var/datum/ms13_ground_vehicle/other = get_ms13_ground_vehicle_at(rail_route[index])
		if(other && other != src)
			car_ahead = other
			return index - reach - 1

/// Sounds the horn at the car ahead, and asks it to move on if it's standing.
/datum/ms13_ground_vehicle/rail/proc/ping_car_ahead()
	var/datum/ms13_ground_vehicle/rail/ahead = car_ahead
	if(!istype(ahead) || !COOLDOWN_FINISHED(src, next_ping))
		return
	COOLDOWN_START(src, next_ping, 10 SECONDS)
	playsound(pivot, 'mojave/sound/ms13machines/horn.ogg', 60, TRUE)
	ahead.make_way(src)

/// Another car is coming up behind: if standing, moves on to a stop further along, away from it, after a warning.
/datum/ms13_ground_vehicle/rail/proc/make_way(datum/ms13_ground_vehicle/rail/behind)
	if(moving || pending_destination || QDELETED(pivot) || !has_power_to_go())
		return FALSE
	var/list/parents = find_rail_routes()
	var/turf/here = get_turf(rail_frame())
	var/list/in_the_way = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in behind.frames)
		in_the_way[get_turf(frame)] = TRUE
	var/obj/structure/ms13_rail/best
	var/best_length = INFINITY
	for(var/obj/structure/ms13_rail/stop as anything in find_stops(parents))
		var/turf/step = get_turf(stop)
		if(step == here)
			continue
		var/length = 0
		var/clear = TRUE
		while(step != here)
			if(in_the_way[step])
				clear = FALSE
				break
			step = parents[step]
			length++
		if(clear && length < best_length)
			best_length = length
			best = stop
	if(!best)
		return FALSE
	warn_and_depart(best, "A car is coming up behind.")
	return TRUE

/datum/ms13_ground_vehicle/rail/proc/set_thrusting(on)
	if(thrusting == on)
		return
	thrusting = on
	if(on)
		playsound(pivot, thrust_sound, 40, TRUE)

/// Calls a car to the stop beside it: the nearest idle car on the line comes, unless one on service calls there anyway.
/obj/structure/ms13_rail_call_button
	name = "rail call button"
	desc = "Calls a car to this stop."
	icon = 'icons/obj/machines/buttons.dmi'
	icon_state = "doorctrl"
	anchored = TRUE
	density = FALSE
	/// A stop this close counts as its own.
	var/reach = 5

/obj/structure/ms13_rail_call_button/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	var/obj/structure/ms13_rail/stop = own_stop()
	if(!stop)
		balloon_alert(user, "no stop nearby!")
		return TRUE
	var/turf/stop_turf = get_turf(stop)
	var/datum/ms13_ground_vehicle/rail/closest
	var/closest_length = INFINITY
	for(var/obj/structure/ms13_vehicle_frame/tram/car as anything in GLOB.ms13_rail_cars)
		var/datum/ms13_ground_vehicle/rail/line = car.vehicle
		if(!istype(line))
			continue
		var/list/parents = line.find_rail_routes()
		if(!parents[stop_turf])
			continue
		if(line.automated)
			balloon_alert(user, "a car on service will call here")
			return TRUE
		if(get_turf(line.rail_frame()) == stop_turf)
			balloon_alert(user, "a car is here")
			return TRUE
		if(line.moving || line.pending_destination || !line.has_power_to_go())
			continue
		var/length = line.route_length(parents, stop_turf)
		if(length < closest_length)
			closest_length = length
			closest = line
	if(!closest)
		balloon_alert(user, "no car free on this line")
		return TRUE
	closest.warn_and_depart(stop, "Called to [stop.stop_name()].")
	balloon_alert(user, "car called")
	return TRUE

/// The nearest stop within reach.
/obj/structure/ms13_rail_call_button/proc/own_stop()
	var/best_distance = INFINITY
	for(var/obj/structure/ms13_rail/candidate in range(reach, src))
		if(candidate.is_station && get_dist(src, candidate) < best_distance)
			best_distance = get_dist(src, candidate)
			. = candidate

/obj/structure/ms13_vehicle_frame/tram/Destroy()
	GLOB.ms13_rail_cars -= src
	return ..()
