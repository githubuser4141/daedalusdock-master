/**
 * Electric rail cars, which take their power from the guide rail.
 *
 * The rail carries no power state of its own, and nothing here processes. A rail feeder on a rail tile, over a cable
 * knot, joins the rail line to that cable's powernet. An electric car finds the feeders on its line when it searches
 * its route, and while it moves it draws its traction load from a feeder's powernet, once a power cycle. Parked, it
 * costs nothing. Its lights, doors and route terminal run off the line too; it has no engine, fuel or battery.
 */

/// Puts power from a cable onto the rail line it sits on: the cable knotted under it, or on the tile beside it its wires
/// reach to. It only joins the two.
/obj/machinery/power/ms13_rail_feeder
	name = "rail feeder"
	desc = "A heavy junction box that puts power from the cable beneath it onto the guide rail."
	icon = 'icons/obj/power.dmi'
	icon_state = "term"
	layer = ABOVE_OPEN_TURF_LAYER
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	processing_flags = NONE

/obj/machinery/power/ms13_rail_feeder/Initialize(mapload)
	. = ..()
	// A cable beside it isn't found when round start builds the networks, so it looks once they're built.
	addtimer(CALLBACK(src, PROC_REF(connect_to_network)), 0)

/obj/machinery/power/ms13_rail_feeder/connect_to_network()
	var/datum/powernet/old_net = powernet
	var/turf/here = get_turf(src)
	var/obj/structure/cable/node = here?.get_cable_node()
	if(!node?.powernet)
		for(var/direction in list(dir) + GLOB.cardinals)
			var/turf/beside = get_step(src, direction)
			node = beside?.get_cable_node()
			if(node?.powernet)
				break
	if(!node?.powernet)
		return FALSE
	node.powernet.add_machine(src)
	if(powernet != old_net)
		SEND_SIGNAL(src, COMSIG_MS13_LINE_POWER_CHANGED, powernet.avail > 0)
	return TRUE

/obj/machinery/power/ms13_rail_feeder/disconnect_from_network()
	. = ..()
	SEND_SIGNAL(src, COMSIG_MS13_LINE_POWER_CHANGED, FALSE)

/obj/machinery/power/ms13_rail_feeder/examine(mob/user)
	. = ..()
	if(!ms13_rail_at(get_turf(src)))
		. += span_warning("It isn't on a rail, so it powers no line.")
	if(!powernet)
		. += span_warning("It isn't wired: it needs a cable knot on its own tile or the one beside it.")
	else if(powernet.avail > 0)
		. += span_notice("The line is live, with [display_power(surplus())] to spare.")
	else
		. += span_notice("The cable it's wired to is dead.")

/// A guide rail set into the floor: it works like any other, but can't be seen. It suits a door's track.
/obj/structure/ms13_rail/hidden
	invisibility = INVISIBILITY_ABSTRACT

/// An electric car's drive: a traction motor geared straight to the axles, one speed, run off the rail.
/obj/structure/ms13_vehicle_part/gearbox/traction
	name = "traction motor"
	desc = "An electric traction motor geared straight to the axles. It runs off power picked up from the guide rail."
	gear_delays = list(4)

/datum/ms13_ground_vehicle/rail/electric
	fuel_per_tile = 0
	thrust_sound = 'mojave/sound/ms13machines/generator_on.ogg'
	/// Watts the traction motor draws from the line while the car moves.
	var/traction_draw = 20000
	/// Feeders on the line, found with the route search.
	var/list/feeders = list()
	/// Whether it got its traction load this power cycle.
	var/drew_power = FALSE
	/// SSmachines.times_fired when it last drew it.
	var/power_cycle = -1
	/// The line was live when last heard from.
	var/line_live = FALSE

/datum/ms13_ground_vehicle/rail/electric/find_rail_routes()
	. = ..()
	for(var/obj/machinery/power/ms13_rail_feeder/old_feeder as anything in feeders)
		UnregisterSignal(old_feeder, list(COMSIG_MS13_LINE_POWER_CHANGED, COMSIG_PARENT_QDELETING))
	feeders = list()
	for(var/turf/location as anything in .)
		var/obj/machinery/power/ms13_rail_feeder/feeder = locate() in location
		if(feeder)
			// Picks up a cable laid or rewired since the networks were last built.
			feeder.connect_to_network()
			feeders += feeder
			RegisterSignal(feeder, COMSIG_MS13_LINE_POWER_CHANGED, PROC_REF(on_line_power_changed))
			RegisterSignal(feeder, COMSIG_PARENT_QDELETING, PROC_REF(on_feeder_deleted))

/datum/ms13_ground_vehicle/rail/electric/proc/on_feeder_deleted(obj/machinery/power/ms13_rail_feeder/feeder)
	SIGNAL_HANDLER
	feeders -= feeder

/// The line went live or dead. Live, the car switches itself on: ignition, lights and motor.
/datum/ms13_ground_vehicle/rail/electric/proc/on_line_power_changed(obj/machinery/power/ms13_rail_feeder/feeder, live)
	SIGNAL_HANDLER
	if(!line_power())
		if(line_live)
			line_live = FALSE
			// Said while the terminal still has the power to say it.
			update_electrical()
			playsound(pivot, 'mojave/sound/ms13machines/generator_off.ogg', 40, TRUE)
		return
	if(!line_live)
		line_live = TRUE
		INVOKE_ASYNC(src, PROC_REF(announce), "Line power on.")
	interior_lights_on = TRUE
	exterior_lights_on = TRUE
	engine_running = TRUE
	set_ignition(TRUE)

/// A feeder on the line whose powernet has at least draw watts to spare, if any.
/datum/ms13_ground_vehicle/rail/electric/proc/line_power(draw = 1)
	for(var/obj/machinery/power/ms13_rail_feeder/feeder as anything in feeders)
		if(!QDELETED(feeder) && feeder.surplus() >= draw)
			return feeder

/// Takes this power cycle's traction load off the line, once a cycle. FALSE if the line can't carry it.
/datum/ms13_ground_vehicle/rail/electric/proc/draw_traction()
	if(power_cycle == SSmachines.times_fired)
		return drew_power
	power_cycle = SSmachines.times_fired
	var/obj/machinery/power/ms13_rail_feeder/feeder = line_power(traction_draw)
	feeder?.add_load(traction_draw)
	if(drew_power != !!feeder)
		drew_power = !!feeder
		update_electrical()
	return drew_power

// ponytail: the lights, doors and terminal come off the line without adding to its load; only traction is metered.
/datum/ms13_ground_vehicle/rail/electric/has_power_to_go()
	return !!line_power(traction_draw)

/datum/ms13_ground_vehicle/rail/electric/has_electrical_power()
	return ignition && !!line_power()

/datum/ms13_ground_vehicle/rail/electric/has_standby_power()
	return !!line_power()

/datum/ms13_ground_vehicle/rail/electric/use_battery(amount)
	return has_electrical_power()

/datum/ms13_ground_vehicle/rail/electric/start_engine(mob/user)
	if(QDELETED(pivot))
		return FALSE
	if(!line_power(traction_draw))
		if(user)
			to_chat(user, span_warning(line_power() ? "There isn't enough power on the line: the motor needs [display_power(traction_draw)] to spare." : "There's no power on the line. Check the rail feeder is on the line and wired to a live cable."))
		return FALSE
	engine_running = TRUE
	return TRUE

/// The motor turns while engaged; losing the line's power brakes the car instead (movement_tick() below).
/datum/ms13_ground_vehicle/rail/electric/drive_turning()
	return engine_running

// It draws power only while the motor pulls. Out of power, it brakes to a stop along the line rather than stopping dead.
/datum/ms13_ground_vehicle/rail/electric/movement_tick(generation)
	if(rail_route && thrusting && !halting && generation == movement_generation && moving && !draw_traction())
		apply_brakes()
	return ..()

/obj/structure/ms13_vehicle_frame/tram/electric
	name = "small electric tram"
	vehicle_controller_type = /datum/ms13_ground_vehicle/rail/electric

/obj/structure/ms13_vehicle_frame/tram/train/electric
	name = "short electric train"
	vehicle_controller_type = /datum/ms13_ground_vehicle/rail/electric

GLOBAL_LIST_EMPTY(ms13_blast_doors)

TYPEINFO_DEF(/obj/structure/ms13_vehicle_frame/tram/blast_door)
	default_armor = list(BLUNT = 95, PUNCTURE = 900, SLASH = 100, LASER = 90, ENERGY = 70, BOMB = 70, BIO = 100, FIRE = 80, ACID = 80)

/**
 * A blast door: a dense steel slab on a guide rail, driven by a traction motor off a rail feeder. It slides to the far
 * end of its rail and back when a button with its id is pressed. It is three frames and a motor: no walls, seats,
 * lights or battery, so it costs nothing standing and a handful of moves a tile when it slides.
 *
 * Map it facing along its length, the way it slides, where it stands shut. Run rail (the hidden subtype suits it) under
 * its middle tile from there to where its middle stands open, with a rail feeder over a live cable on that line.
 */
/obj/structure/ms13_vehicle_frame/tram/blast_door
	name = "blast door"
	desc = "A massive armored slab that slides along a track set into the floor."
	icon_state = "frame_steel"
	density = TRUE
	max_integrity = 3000
	vehicle_controller_type = /datum/ms13_ground_vehicle/rail/electric/blast_door
	segment_type = /obj/structure/ms13_vehicle_frame/blast_door_slab
	car_length = 3
	car_width = 1
	/// Buttons with this id open and close it.
	var/id
	/// The end of its rail it last set off for.
	var/turf/heading

TYPEINFO_DEF(/obj/structure/ms13_vehicle_frame/blast_door_slab)
	default_armor = list(BLUNT = 95, PUNCTURE = 900, SLASH = 100, LASER = 90, ENERGY = 70, BOMB = 70, BIO = 100, FIRE = 80, ACID = 80)

/obj/structure/ms13_vehicle_frame/blast_door_slab
	name = "blast door"
	desc = "A massive armored slab that slides along a track set into the floor."
	density = TRUE
	max_integrity = 3000

/obj/structure/ms13_vehicle_frame/tram/blast_door/build_car()
	for(var/back in 1 to car_length - 1)
		add_segment(-back, 0, "frame_steel", "roof_steel")
	GLOB.ms13_blast_doors += src

/obj/structure/ms13_vehicle_frame/tram/blast_door/Destroy()
	GLOB.ms13_blast_doors -= src
	heading = null
	return ..()

/// Slides to the other end of its rail, or back the way it came if it stopped part-way.
/obj/structure/ms13_vehicle_frame/tram/blast_door/proc/toggle()
	var/datum/ms13_ground_vehicle/rail/electric/blast_door/drive = vehicle
	if(!istype(drive))
		return FALSE
	var/list/ends = drive.line_ends()
	if(length(ends) != 2)
		return FALSE
	var/turf/here = get_turf(drive.rail_frame())
	var/turf/destination
	if(here == ends[1] || here == ends[2])
		destination = here == ends[1] ? ends[2] : ends[1]
	else
		destination = heading == ends[1] ? ends[2] : ends[1]
	heading = destination
	return drive.depart_for(destination)

/datum/ms13_ground_vehicle/rail/electric/blast_door
	speed_multiplier = 1
	mass_per_frame = 20000
	required_running_gear = 0
	traction_draw = 5000
	time_to_top_speed = 1 SECONDS
	time_to_stop = 1 SECONDS
	braking_variance = 0
	// Shoves whoever is in the way rather than hurting them, and stops against someone it can't shove.
	ram_damage_base = 2
	ram_damage_per_speed = 0
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks
	thrust_sound = 'mojave/sound/ms13machines/doorblast_open.ogg'

/datum/ms13_ground_vehicle/rail/electric/blast_door/can_run_over(mob/living/victim)
	return FALSE

/// The two ends of a straight line, or more ends for a branching one.
/datum/ms13_ground_vehicle/rail/proc/line_ends()
	. = list()
	var/list/line = find_rail_routes()
	for(var/turf/location as anything in line)
		var/neighbours = 0
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(location, direction)
			if(next && line[next])
				neighbours++
		if(neighbours <= 1)
			. += location

// Door buttons slide blast doors with their id, as they open shutters.
/obj/item/assembly/control/activate()
	var/cooling = cooldown
	. = ..()
	if(cooling || !id)
		return
	for(var/obj/structure/ms13_vehicle_frame/tram/blast_door/door as anything in GLOB.ms13_blast_doors)
		if(door.id == id)
			door.toggle()
