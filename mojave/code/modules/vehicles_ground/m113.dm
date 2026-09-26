/**
 * Civ13's 3x4 M113 footprint and sprites, assembled on the shared Mojave vehicle controller. Place
 * the front-left frame in the map editor; the remaining hull, rear ramp, seats, powerpack, fuel cell,
 * lights, and four independently damageable track units are created around it.
 *
 * Cabin layout, front row first (L/C/R = left/centre/right, facing forward):
 *   driver       | transmission | engine        <- powerpack sealed off behind access panels
 *   commander    | aisle        | troop seat
 *   troop seat   | aisle        | troop seat    <- dome light over the aisle
 *   fuel cell    | aisle        | troop seat
 *                  rear ramp
 */


/datum/ms13_ground_vehicle/m113
	rated_engine = /obj/structure/ms13_vehicle_part/engine/m113
	battery_cell = /obj/item/stock_parts/cell/ms13_vehicle/truck
	alternator_type = /obj/structure/ms13_vehicle_part/alternator/truck
	acceleration_delay = 1.8 SECONDS
	speed_multiplier = 1.5
	turn_delay = 7
	max_turn_speed = 1
	turn_speed_loss = 1
	ram_damage_base = 8
	ram_damage_per_speed = 7
	ram_knockdown_per_speed = 7
	required_running_gear = 4
	running_gear_integrity = 180
	engine_integrity = 400
	fuel_per_tile = 0.2
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks


TYPEINFO_DEF(/obj/structure/ms13_vehicle_part/engine/m113)
	default_armor = list(BLUNT = 35, PUNCTURE = 80, SLASH = 35, LASER = 80, ENERGY = 50, BOMB = 0, BIO = 100,  FIRE = 25, ACID = 25)
/obj/structure/ms13_vehicle_part/engine/m113
	name = "Detroit 6V53T diesel engine"
	desc = "The compact two-stroke diesel engine used to propel an M113 armored personnel carrier."
	power = 205
	mass = 540
	density = TRUE
	max_integrity = 350
	icon_state = "engine_static"
	static_icon_state = "engine_static"
	running_icon_state = "engine_on"
	broken_icon_state = "engine_broken"

/obj/structure/ms13_vehicle_part/gearbox/m113
	name = "TX100 transmission"
	desc = "The M113's three-speed automatic transmission and steering differential."
	density = TRUE
	max_integrity = 200
	gear_delays = list(12, 9, 7)

/obj/structure/ms13_vehicle_part/fuel_tank/m113
	name = "M113 fuel cell"
	desc = "A boxy armored fuel cell bolted into the rear corner of the troop compartment."
	icon_state = "fueltank_incar"
	density = TRUE
	max_integrity = 180
	capacity = 240

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/m113)
	default_armor = list(BLUNT = 50, PUNCTURE = ARMOR_RIFLES, SLASH = 60, LASER = 35, ENERGY = 50, BOMB = 15, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/window/ms13_vehicle_wall/m113
	name = "M113 vision port"
	desc = "A thick vision block set into the carrier's frontal armor."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	max_integrity = 800
	// Periscope glass: you can see out only with your face to it, and it lets almost no light in.
	light_proof = TRUE
	vision_range = 0

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/m113)
	default_armor = list(BLUNT = 50, PUNCTURE = ARMOR_RIFLES, SLASH = 60, LASER = 75, ENERGY = 50, BOMB = 25, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/window/ms13_vehicle_wall/solid/m113
	name = "M113 hull plating"
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	max_integrity = 1500

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/door/m113)
	default_armor = list(BLUNT = 50, PUNCTURE = ARMOR_RIFLES, SLASH = 60, LASER = 75, ENERGY = 50, BOMB = 25, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/window/ms13_vehicle_wall/solid/door/m113
	name = "M113 rear ramp"
	desc = "The carrier's heavy rear access ramp, powered. Click to lower or raise it."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	icon_state = "m113_back_frame"
	open_icon_state = "m113_back_frame"
	max_integrity = 1000
	powered = TRUE
	/// How far the lowered ramp lies out past the hull, in pixels. Keeps it visible and clickable.
	var/lowered_offset = 20

/obj/structure/window/ms13_vehicle_wall/solid/door/m113/open(mob/user)
	. = ..()
	update_ramp_position()

/obj/structure/window/ms13_vehicle_wall/solid/door/m113/close(mob/user)
	. = ..()
	update_ramp_position()

/obj/structure/window/ms13_vehicle_wall/solid/door/m113/setDir(new_dir)
	. = ..()
	update_ramp_position()

/// A lowered ramp lies on the ground behind the carrier, under whoever walks across it.
/obj/structure/window/ms13_vehicle_wall/solid/door/m113/proc/update_ramp_position()
	var/offset = opened ? lowered_offset : 0
	pixel_x = dir == EAST ? offset : dir == WEST ? -offset : 0
	pixel_y = dir == NORTH ? offset : dir == SOUTH ? -offset : 0
	layer = opened ? LOW_OBJ_LAYER : initial(layer)

TYPEINFO_DEF(/obj/structure/ms13_vehicle_frame/m113)
	default_armor = list(BLUNT = 75, PUNCTURE = 75, SLASH = 75, LASER = 75, ENERGY = 50, BOMB = 25, BIO = 100,  FIRE = 50, ACID = 50)
/obj/structure/ms13_vehicle_frame/m113
	name = "M113 armored personnel carrier"
	desc = "A tracked armored personnel carrier with room for a driver and infantry squad."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	icon_state = "m113_frame_steel_front_left"
	max_integrity = 800
	explosion_block = 2
	vehicle_controller_type = /datum/ms13_ground_vehicle/m113
	roof_damaged_icon = null
	roof_damage_color = "#8f7676"
	segment_type = /obj/structure/ms13_vehicle_frame/m113

/// The only map-placeable M113 object; children use the parent segment type to avoid reassembly.
/obj/structure/ms13_vehicle_frame/m113/front_left
	/// Camera types on the front, left, right and rear hull; null leaves that side without one.
	var/front_camera
	var/left_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera
	var/right_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera
	var/rear_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera
	/// Add-on armor bolted over the whole outer hull, or null.
	var/addon_armor
	var/smoke_generator

/obj/structure/ms13_vehicle_frame/m113/front_left/night
	name = "M113 armored personnel carrier (night vision)"
	desc = "A tracked armored personnel carrier fitted for night work: night vision cameras front and sides, a wide-angle camera behind."
	front_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/night_vision
	left_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/night_vision
	right_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/night_vision
	rear_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/wide

/obj/structure/ms13_vehicle_frame/m113/front_left/a3
	name = "M113A3 armored personnel carrier"
	desc = "A modernised M113: ceramic add-on armor, a zoom camera up front, thermal cameras on both sides, a wide-angle camera behind and a smoke generator."
	smoke_generator = /obj/structure/ms13_vehicle_part/smoke_generator
	front_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/zoom
	left_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/thermal
	right_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/thermal
	rear_camera = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/wide
	addon_armor = /obj/item/ms13_vehicle_armor/ceramic

/obj/structure/ms13_vehicle_frame/m113/front_left/uparmored
	name = "M113 armored personnel carrier (appliqué armor)"
	desc = "An M113 with steel appliqué plate bolted over its hull."
	addon_armor = /obj/item/ms13_vehicle_armor

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

	var/obj/structure/ms13_vehicle_frame/front_middle = add_segment(0, 1, "m113_frame_steel_front_middle", "m113_roof_steel_front_middle")
	var/obj/structure/ms13_vehicle_frame/front_right = add_segment(0, 2, "m113_frame_steel_front_right", "m113_roof_steel_front_right")
	var/obj/structure/ms13_vehicle_frame/middle_front_left = add_segment(-1, 0, "m113_frame_steel_middle_front_left", "m113_roof_steel_middle_front_left")
	add_segment(-1, 1, "m113_frame_steel_middle_front", "m113_roof_steel_middle_front")
	var/obj/structure/ms13_vehicle_frame/middle_front_right = add_segment(-1, 2, "m113_frame_steel_middle_front_right", "m113_roof_steel_middle_front_right")
	var/obj/structure/ms13_vehicle_frame/middle_back_left = add_segment(-2, 0, "m113_frame_steel_middle_back_left", "m113_roof_steel_middle_back_left")
	var/obj/structure/ms13_vehicle_frame/middle_back = add_segment(-2, 1, "m113_frame_steel_middle_back", "m113_roof_steel_middle_back")
	var/obj/structure/ms13_vehicle_frame/middle_back_right = add_segment(-2, 2, "m113_frame_steel_middle_back_right", "m113_roof_steel_middle_back_right")
	var/obj/structure/ms13_vehicle_frame/back_left = add_segment(-3, 0, "m113_frame_steel_back_left", "m113_roof_steel_back_left")
	var/obj/structure/ms13_vehicle_frame/back = add_segment(-3, 1, "m113_frame_steel_back", "m113_roof_steel_back")
	var/obj/structure/ms13_vehicle_frame/back_right = add_segment(-3, 2, "m113_frame_steel_back_right", "m113_roof_steel_back_right")

	// Outer hull: three frontal vision blocks, solid sides and rear, one working rear ramp.
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

	// Powerpack: the driver sits beside the transmission, and both it and the engine are closed off
	// from the troop compartment behind bolted access panels.
	add_bulkhead(-90, "driver's bulkhead")
	front_middle.add_bulkhead(180, "transmission access panel", /obj/structure/window/ms13_vehicle_wall/solid/door/interior)
	front_right.add_bulkhead(180, "engine access panel", /obj/structure/window/ms13_vehicle_wall/solid/door/interior)
	front_middle.spawn_part(/obj/structure/ms13_vehicle_part/gearbox/m113)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/engine/m113)

	// Commander sits behind the driver, backed by a partition; troops face each other across the aisle.
	middle_front_left.add_bulkhead(180, "seat partition")
	var/obj/structure/chair/ms13_vehicle_seat/driver_seat = add_seat(0, "driver's seat", "driver_tank")
	driver_seat.configure_driver_seat()
	middle_front_left.add_seat(0, "commander's seat")
	middle_back_left.add_seat(-90, "troop seat")
	middle_front_right.add_seat(90, "troop seat")
	middle_back_right.add_seat(90, "troop seat")
	back_right.add_seat(90, "troop seat")

	// Fuel cell in the rear left corner, boxed in and filled from the aisle side.
	back_left.add_bulkhead(0, "fuel cell bulkhead")
	back_left.add_bulkhead(-90, "fuel cell access panel", /obj/structure/window/ms13_vehicle_wall/solid/door/interior)
	back_left.spawn_part(/obj/structure/ms13_vehicle_part/fuel_tank/m113)

	middle_back.spawn_part(/obj/structure/ms13_vehicle_part/interior_light)
	spawn_part(/obj/structure/ms13_vehicle_part/interior_light/instrument)
	spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light)
	back.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light, 180)
	if(front_camera)
		front_middle.spawn_part(front_camera)
	if(left_camera)
		spawn_part(left_camera, 90)
	if(right_camera)
		front_right.spawn_part(right_camera, -90)
	if(rear_camera)
		back.spawn_part(rear_camera, 180)
	if(addon_armor)
		vehicle.fit_addon_armor(addon_armor)
	if(smoke_generator)
		back_right.spawn_part(smoke_generator, 180)
	middle_back.spawn_part(/obj/structure/ms13_vehicle_part/welding_rig)

	spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track)
	back_left.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track, 180)
	back_right.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/track, 180)
