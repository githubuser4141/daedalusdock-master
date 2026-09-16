/**
 * Civ13's 3x4 M113 footprint and sprites, assembled on the shared Mojave vehicle controller. Place
 * the front-left frame in the map editor; the remaining hull, rear ramp, seats, engine, and four
 * independently damageable track units are created around it.
 */


/datum/ms13_ground_vehicle/m113
	speed_delays = list(12, 9, 7)
	acceleration_delay = 1.8 SECONDS
	coast_delay = 2 SECONDS
	turn_delay = 7
	max_turn_speed = 1
	turn_speed_loss = 1
	ram_damage_base = 8
	ram_damage_per_speed = 7
	ram_knockdown_per_speed = 7
	required_running_gear = 4
	running_gear_integrity = 180
	engine_integrity = 400
	fuel_capacity = 240
	fuel_per_tile = 0.2
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks


TYPEINFO_DEF(/obj/structure/ms13_vehicle_part/engine/m113)
	default_armor = list(BLUNT = 35, PUNCTURE = 80, SLASH = 35, LASER = 80, ENERGY = 50, BOMB = 0, BIO = 100,  FIRE = 25, ACID = 25)
/obj/structure/ms13_vehicle_part/engine/m113
	name = "Detroit 6V53T diesel engine"
	desc = "The compact two-stroke diesel engine used to propel an M113 armored personnel carrier."
	density = TRUE
	max_integrity = 300

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/m113)
	default_armor = list(BLUNT = 50, PUNCTURE = 70, SLASH = 50, LASER = 35, ENERGY = 50, BOMB = 15, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/window/ms13_vehicle_wall/m113
	name = "M113 vision port"
	desc = "A thick vision block set into the carrier's frontal armor."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	max_integrity = 400

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/m113)
	default_armor = list(BLUNT = 50, PUNCTURE = 70, SLASH = 50, LASER = 75, ENERGY = 50, BOMB = 25, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/window/ms13_vehicle_wall/solid/m113
	name = "M113 hull plating"
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	max_integrity = 1000

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/door/m113)
	default_armor = list(BLUNT = 50, PUNCTURE = 70, SLASH = 50, LASER = 75, ENERGY = 50, BOMB = 25, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/window/ms13_vehicle_wall/solid/door/m113
	name = "M113 rear ramp"
	desc = "The carrier's heavy rear access ramp. Click to open or close it."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	icon_state = "m113_back_frame"
	open_icon_state = "none"
	max_integrity = 700

TYPEINFO_DEF(/obj/structure/ms13_vehicle_frame/m113)
	default_armor = list(BLUNT = 75, PUNCTURE = 75, SLASH = 75, LASER = 75, ENERGY = 50, BOMB = 25, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/ms13_vehicle_frame/m113
	name = "M113 armored personnel carrier"
	desc = "A tracked armored personnel carrier with room for a driver and infantry squad."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	icon_state = "m113_frame_steel_front_left"
	max_integrity = 450
	vehicle_controller_type = /datum/ms13_ground_vehicle/m113
	roof_damaged_icon = null
	roof_damage_color = "#8f7676"

/obj/structure/ms13_vehicle_frame/m113/proc/add_segment(forward, right, floor_state, roof_state)
	var/turf/destination = vehicle.get_relative_turf(forward, right, dir)
	var/obj/structure/ms13_vehicle_frame/m113/segment = new(destination)
	segment.vehicle = vehicle
	segment.forward_offset = forward
	segment.right_offset = right
	segment.icon_state = floor_state
	segment.roof.icon_state = roof_state
	segment.setDir(dir)
	vehicle.frames += segment
	return segment

/// The only map-placeable M113 object; children use the parent segment type to avoid reassembly.
/obj/structure/ms13_vehicle_frame/m113/front_left

/obj/structure/ms13_vehicle_frame/m113/front_left/Initialize(mapload)
	. = ..()
	vehicle = new vehicle_controller_type
	vehicle.pivot = src
	vehicle.dir = dir
	vehicle.frames += src
	icon_state = "m113_frame_steel_front_left"
	roof.icon_state = "m113_roof_steel_front_left"

	for(var/forward in list(0, -1, -2, -3))
		for(var/right in list(0, 1, 2))
			if(!forward && !right)
				continue
			var/turf/destination = vehicle.get_relative_turf(forward, right, dir)
			if(!destination || destination.density)
				return

	var/obj/structure/ms13_vehicle_frame/m113/front_middle = add_segment(0, 1, "m113_frame_steel_front_middle", "m113_roof_steel_front_middle")
	var/obj/structure/ms13_vehicle_frame/m113/front_right = add_segment(0, 2, "m113_frame_steel_front_right", "m113_roof_steel_front_right")
	var/obj/structure/ms13_vehicle_frame/m113/middle_front_left = add_segment(-1, 0, "m113_frame_steel_middle_front_left", "m113_roof_steel_middle_front_left")
	add_segment(-1, 1, "m113_frame_steel_middle_front", "m113_roof_steel_middle_front")
	var/obj/structure/ms13_vehicle_frame/m113/middle_front_right = add_segment(-1, 2, "m113_frame_steel_middle_front_right", "m113_roof_steel_middle_front_right")
	var/obj/structure/ms13_vehicle_frame/m113/middle_back_left = add_segment(-2, 0, "m113_frame_steel_middle_back_left", "m113_roof_steel_middle_back_left")
	add_segment(-2, 1, "m113_frame_steel_middle_back", "m113_roof_steel_middle_back")
	var/obj/structure/ms13_vehicle_frame/m113/middle_back_right = add_segment(-2, 2, "m113_frame_steel_middle_back_right", "m113_roof_steel_middle_back_right")
	var/obj/structure/ms13_vehicle_frame/m113/back_left = add_segment(-3, 0, "m113_frame_steel_back_left", "m113_roof_steel_back_left")
	var/obj/structure/ms13_vehicle_frame/m113/back = add_segment(-3, 1, "m113_frame_steel_back", "m113_roof_steel_back")
	var/obj/structure/ms13_vehicle_frame/m113/back_right = add_segment(-3, 2, "m113_frame_steel_back_right", "m113_roof_steel_back_right")

	// Three frontal vision blocks; the rest of the hull is opaque, with one working rear ramp.
	spawn_wall(dir, "m113_front_left_frame", /obj/structure/window/ms13_vehicle_wall/m113)
	front_middle.spawn_wall(dir, "m113_front_middle_frame", /obj/structure/window/ms13_vehicle_wall/m113)
	front_right.spawn_wall(dir, "m113_front_right_frame", /obj/structure/window/ms13_vehicle_wall/m113)

	spawn_wall(turn(dir, 90), "none", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	middle_front_left.spawn_wall(turn(dir, 90), "m113_middle_front_left_frame", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	middle_back_left.spawn_wall(turn(dir, 90), "m113_middle_back_left_frame", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	back_left.spawn_wall(turn(dir, 90), "none", /obj/structure/window/ms13_vehicle_wall/solid/m113)

	front_right.spawn_wall(turn(dir, -90), "none", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	middle_front_right.spawn_wall(turn(dir, -90), "m113_middle_front_right_frame", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	middle_back_right.spawn_wall(turn(dir, -90), "m113_middle_back_right_frame", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	back_right.spawn_wall(turn(dir, -90), "none", /obj/structure/window/ms13_vehicle_wall/solid/m113)

	back_left.spawn_wall(turn(dir, 180), "m113_back_left_frame", /obj/structure/window/ms13_vehicle_wall/solid/m113)
	back.spawn_wall(turn(dir, 180), , /obj/structure/window/ms13_vehicle_wall/solid/door/m113)
	back_right.spawn_wall(turn(dir, 180), "m113_back_right_frame", /obj/structure/window/ms13_vehicle_wall/solid/m113)

	var/obj/structure/chair/ms13_vehicle_seat/driver_seat = new(get_turf(src))
	driver_seat.parent_frame = src
	driver_seat.is_driver_seat = TRUE
	driver_seat.icon_state = "driver_car"
	driver_seat.setDir(dir)

	for(var/obj/structure/ms13_vehicle_frame/seat_frame in list(middle_front_left, middle_front_right, middle_back_left, middle_back_right, back_left, back_right))
		var/obj/structure/chair/ms13_vehicle_seat/passenger_seat = new(get_turf(seat_frame))
		passenger_seat.parent_frame = seat_frame
		passenger_seat.icon_state = "commanders_seat"
		passenger_seat.setDir(dir)

	front_right.spawn_part(/obj/structure/ms13_vehicle_part/engine/m113)
	spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track/right)
	back_left.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track/right, 180)
	back_right.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track, 180)
