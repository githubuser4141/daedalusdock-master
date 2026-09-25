/**
 * Cars drawn with the UndeadPeople tileset's car parts (mojave/icons/udp_undead_people, CC BY-SA 3.0), laid out tile
 * for tile like CDDA's. Place the map-placeable type on the front-left tile; the rest lays itself out from tile_rows.
 *
 * Every tile is the car's floor, and its hull is thin panels on the outer edges, like every other vehicle here. CDDA
 * draws its bodywork a full tile wide, so that's each outer tile's roof: an image only outsiders see, drawn inward over
 * the car's own floor. From outside the car looks solid and exactly its size; from inside, every tile is plain cabin.
 *
 * These are civilian cars, glass and thin steel: the middle of the cabin has no roof art, the glass in the bodywork is
 * see-through from outside, and everyone aboard can see out all round.
 */
/obj/structure/ms13_vehicle_frame/udp_car
	name = "car"
	desc = "A pre-war car."
	icon = 'mojave/icons/udp_undead_people/udp_sedan.dmi'
	icon_state = "floor_cabin"
	segment_type = /obj/structure/ms13_vehicle_frame/udp_car
	roof_damaged_icon = null
	roof_damage_color = "#a88f8f"
	explosion_block = 0
	/// Tiles, front row first and left to right, as "floor state:roof state".
	var/list/tile_rows
	/// Walls by edge, "row,column:edge" = type (edge: front, back, left or right). Outer edges not listed get body.
	var/list/wall_types
	var/body_type = /obj/structure/window/ms13_vehicle_wall/udp_car
	/// Built tiles by "row,column", for furnish().
	var/list/tiles

/obj/structure/ms13_vehicle_frame/udp_car/Initialize(mapload)
	. = ..()
	roof.icon_state = "none"
	if(!length(tile_rows))
		return
	vehicle = new vehicle_controller_type
	vehicle.pivot = src
	vehicle.dir = dir
	vehicle.frames += src
	if(!build_body())
		return
	furnish()
	vehicle.update_interior_lighting()

/// Lays out every tile and its walls. FALSE if there isn't room.
/obj/structure/ms13_vehicle_frame/udp_car/proc/build_body()
	var/row_count = length(tile_rows)
	var/column_count = length(tile_rows[1])
	for(var/row in 1 to row_count)
		for(var/column in 1 to column_count)
			var/turf/destination = vehicle.get_relative_turf(1 - row, column - 1, dir)
			if(!destination || (destination.density && destination != loc))
				return FALSE

	tiles = list()
	for(var/row in 1 to row_count)
		for(var/column in 1 to column_count)
			var/list/art = splittext(tile_rows[row][column], ":")
			var/obj/structure/ms13_vehicle_frame/frame = src
			if(row == 1 && column == 1)
				icon_state = art[1]
				roof.icon_state = art[2]
			else
				frame = add_segment(1 - row, column - 1, art[1], art[2])
			tiles["[row],[column]"] = frame

	for(var/row in 1 to row_count)
		for(var/column in 1 to column_count)
			var/list/outer = list()
			if(row == 1)
				outer += "front"
			if(row == row_count)
				outer += "back"
			if(column == 1)
				outer += "left"
			if(column == column_count)
				outer += "right"
			for(var/edge in list("front", "back", "left", "right"))
				var/wall_type = wall_types?["[row],[column]:[edge]"] || ((edge in outer) ? body_type : null)
				if(wall_type)
					var/obj/structure/ms13_vehicle_frame/frame = tiles["[row],[column]"]
					frame.spawn_wall(edge_dir(edge), null, wall_type)
	return TRUE

/obj/structure/ms13_vehicle_frame/udp_car/proc/edge_dir(edge)
	switch(edge)
		if("front")
			return dir
		if("back")
			return turn(dir, 180)
		if("left")
			return turn(dir, 90)
	return turn(dir, -90)

/// Fits out the car once its body stands. tiles["row,column"] reaches a tile.
/obj/structure/ms13_vehicle_frame/udp_car/proc/furnish()
	return

/obj/structure/ms13_vehicle_frame/udp_car/proc/add_car_part(tile, part_type, relative_turn = 0)
	var/obj/structure/ms13_vehicle_frame/frame = tiles[tile]
	return frame.spawn_part(part_type, relative_turn)

/obj/structure/ms13_vehicle_frame/udp_car/proc/add_car_seat(tile, seat_name, seat_state)
	var/obj/structure/ms13_vehicle_frame/frame = tiles[tile]
	var/obj/structure/chair/ms13_vehicle_seat/seat = frame.add_seat(0, seat_name, seat_state)
	seat.icon = icon
	return seat

/datum/ms13_ground_vehicle/udp_sedan
	acceleration_delay = 0.6 SECONDS
	speed_multiplier = 1.8
	turn_delay = 3
	max_turn_speed = 2
	turn_speed_loss = 1
	ram_damage_base = 3
	ram_damage_per_speed = 4
	ram_knockdown_per_speed = 4
	running_gear_integrity = 70
	engine_integrity = 180
	fuel_per_tile = 0.08

/**
 * A four-door sedan, CDDA's layout:
 *
 *   fender      | hood          | fender        <- the engine, under a hood you can lift
 *   wheel       | windshield    | wheel
 *   door        | driver        | passenger
 *   door, seat  | back seat     | door, seat
 *   wheel       | rear window   | wheel
 *   fender      | trunk         | fender        <- the fuel tank, behind a trunk lid
 *
 * The cabin is the middle four rows, the dash and the parcel shelf glass you see over.
 */
/obj/structure/ms13_vehicle_frame/udp_car/sedan
	name = "sedan"
	desc = "A pre-war four-door sedan, its red paint gone dull."
	icon_state = "roof_nw"
	vehicle_controller_type = /datum/ms13_ground_vehicle/udp_sedan
	tile_rows = list(
		list("floor_hood:roof_nw", "floor_hood:roof_hood", "floor_hood:roof_ne"),
		list("floor_cabin:roof_wheel_left", "floor_cabin:roof_windshield_front", "floor_cabin:roof_wheel_right"),
		list("floor_cabin:roof_door_front_left", "floor_cabin:none", "floor_cabin:roof_door_front_right"),
		list("floor_cabin:roof_door_rear_left", "floor_cabin:none", "floor_cabin:roof_door_rear_right"),
		list("floor_cabin:roof_wheel_left", "floor_cabin:roof_windshield_rear", "floor_cabin:roof_wheel_right"),
		list("floor_trunk:roof_sw", "floor_trunk:roof_trunk", "floor_trunk:roof_se"),
	)
	wall_types = list(
		"1,2:front" = /obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/hood,
		"3,1:left" = /obj/structure/window/ms13_vehicle_wall/solid/door/udp_car,
		"4,1:left" = /obj/structure/window/ms13_vehicle_wall/solid/door/udp_car,
		"3,3:right" = /obj/structure/window/ms13_vehicle_wall/solid/door/udp_car,
		"4,3:right" = /obj/structure/window/ms13_vehicle_wall/solid/door/udp_car,
		"6,2:back" = /obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/trunk,
		"2,1:front" = /obj/structure/window/ms13_vehicle_wall/udp_car/dash,
		"2,2:front" = /obj/structure/window/ms13_vehicle_wall/udp_car/dash,
		"2,3:front" = /obj/structure/window/ms13_vehicle_wall/udp_car/dash,
		"5,1:back" = /obj/structure/window/ms13_vehicle_wall/udp_car/dash,
		"5,2:back" = /obj/structure/window/ms13_vehicle_wall/udp_car/dash,
		"5,3:back" = /obj/structure/window/ms13_vehicle_wall/udp_car/dash,
	)

/obj/structure/ms13_vehicle_frame/udp_car/sedan/furnish()
	var/obj/structure/chair/ms13_vehicle_seat/driver = add_car_seat("3,2", "driver's seat", "seat_front")
	driver.configure_driver_seat()
	add_car_part("3,2", /obj/structure/ms13_vehicle_part/interior_light/instrument)
	add_car_seat("3,3", "passenger seat", "seat_front")
	add_car_seat("4,2", "back seat", "seat_rear")
	add_car_seat("4,1", "back seat", "seat_front")
	add_car_seat("4,3", "back seat", "seat_front")
	add_car_part("1,2", /obj/structure/ms13_vehicle_part/engine)
	add_car_part("1,1", /obj/structure/ms13_vehicle_part/gearbox)
	add_car_part("6,1", /obj/structure/ms13_vehicle_part/fuel_tank)
	add_car_part("1,1", /obj/structure/ms13_vehicle_part/exterior_equipment/light)
	add_car_part("1,3", /obj/structure/ms13_vehicle_part/exterior_equipment/light)
	for(var/tile in list("2,1", "5,1"))
		add_car_part(tile, /obj/structure/ms13_vehicle_part/running_gear/wheel/udp_car, 90)
	for(var/tile in list("2,3", "5,3"))
		add_car_part(tile, /obj/structure/ms13_vehicle_part/running_gear/wheel/udp_car, -90)

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/udp_car)
	default_armor = list(BLUNT = 30, PUNCTURE = 20, SLASH = 25, LASER = 25, ENERGY = 15, BOMB = 10, BIO = 100, FIRE = 40, ACID = 25)

/// A car's bodywork: thin pressed steel you can see over, which stops little more than a pistol round.
/obj/structure/window/ms13_vehicle_wall/udp_car
	name = "car body"
	desc = "Thin pressed steel under dull red paint."
	icon = 'mojave/icons/udp_undead_people/udp_sedan.dmi'
	icon_state = "wall_body"
	interior_icon_state = "wall_body"
	broken_icon = null
	max_integrity = 120

/// Glass between the cabin and the hood or trunk: the dash, and the parcel shelf behind the back seat.
/obj/structure/window/ms13_vehicle_wall/udp_car/dash
	name = "dashboard"
	desc = "The dash, and the glass above it."
	icon_state = "wall_glass"
	interior_icon_state = "wall_glass"
	layer = ABOVE_MOB_LAYER
	exterior = FALSE

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car)
	default_armor = list(BLUNT = 30, PUNCTURE = 20, SLASH = 25, LASER = 25, ENERGY = 15, BOMB = 10, BIO = 100, FIRE = 40, ACID = 25)

/// A car door with its window wound up: shut, it's still seen through and lets the light in.
/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car
	name = "car door"
	desc = "A car door. Click to open or close it."
	icon = 'mojave/icons/udp_undead_people/udp_sedan.dmi'
	icon_state = "door_closed"
	open_icon_state = "door_open"
	interior_icon_state = "door_closed"
	broken_icon = null
	max_integrity = 120
	bullet_damage_ratio = 1

/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/blocks_sight()
	return FALSE

/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/blocks_light()
	return FALSE

/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/hood
	name = "hood"
	desc = "The hood over the engine. Click to lift or shut it."
	icon_state = "wall_body"
	interior_icon_state = "wall_body"

/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/trunk
	name = "trunk lid"
	desc = "The trunk lid. Click to open or shut it."
	icon_state = "wall_body"
	interior_icon_state = "wall_body"

/// The tyre off the car's own wheel art, drawn over it so there's something to shoot at.
/obj/structure/ms13_vehicle_part/running_gear/wheel/udp_car
	icon = 'mojave/icons/udp_undead_people/udp_sedan.dmi'
	stationary_icon_state = "wheel"
	moving_icon_state = "wheel"
	broken_icon_state = "wheel_broken"
	exterior_offset = 0

#ifdef UNIT_TESTS
/datum/unit_test/ms13_udp_sedan
	name = "VEHICLES: A UDP Sedan Builds Whole, Its Bodywork For Outsiders Only"

/datum/unit_test/ms13_udp_sedan/Run()
	// Out past the test room, which is too small for a car.
	var/turf/front_left = locate(run_loc_floor_top_right.x + 6, run_loc_floor_top_right.y + 12, run_loc_floor_top_right.z)
	var/obj/structure/ms13_vehicle_frame/udp_car/sedan/car = ms13_build_vehicle(/obj/structure/ms13_vehicle_frame/udp_car/sedan, front_left, NORTH)
	var/datum/ms13_ground_vehicle/vehicle = car.vehicle
	if(length(vehicle?.frames) != 18)
		Fail("A sedan built [length(vehicle?.frames)] tiles, not its 3 by 6.")
		return
	// 18 outer edges and the six panes of the dash and the parcel shelf.
	if(length(vehicle.walls) != 24)
		Fail("A sedan built [length(vehicle.walls)] walls, not 24.")
	if(!length(vehicle.engines) || !vehicle.gearbox || !length(vehicle.fuel_tanks) || !vehicle.has_running_gear())
		Fail("A sedan came without its engine, gearbox, fuel tank or wheels.")
	var/obj/structure/ms13_vehicle_frame/driving_tile = car.tiles["3,2"]
	var/obj/structure/ms13_vehicle_frame/door_tile = car.tiles["3,1"]
	var/obj/structure/chair/ms13_vehicle_seat/driver = locate() in get_turf(driving_tile)
	if(!driver?.is_driver_seat)
		Fail("A sedan's driver's seat isn't at the front of the cabin.")
	if(driving_tile.roof.icon_state != "none" || door_tile.roof.icon_state != "roof_door_front_left")
		Fail("A sedan's cabin had roof art, or its doors had none.")
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in vehicle.walls)
		if(wall.blocks_sight())
			Fail("[wall] on a sedan blocks sight: nothing on a civilian car should.")
			break
	var/obj/structure/window/ms13_vehicle_wall/solid/door/udp_car/door = locate() in get_turf(door_tile)
	door?.close()
	if(!door || !door.density || door.blocks_sight())
		Fail("A sedan's shut front door wasn't there, didn't shut, or couldn't be seen through.")
	// It drives, all of it together: a tile back.
	var/turf/was = get_turf(driving_tile)
	if(!vehicle.do_move(SOUTH, TRUE) || get_turf(driving_tile) != get_step(was, SOUTH) || get_turf(driver) != get_turf(driving_tile) || get_turf(door) != get_turf(door_tile))
		Fail("A sedan didn't drive, or left its seats or doors behind.")

	// A second engine, tank and battery: faster for the weight, but not twice as fast, and it burns twice the fuel.
	var/top = vehicle.gear_count()
	vehicle.set_ignition(TRUE)
	vehicle.start_engine()
	var/one_engine = vehicle.gear_delay(top)
	if(abs(one_engine - vehicle.gearbox.gear_delays[top] / vehicle.speed_multiplier) > 0.001)
		Fail("A sedan on its own engine didn't drive at its tuned speed.")
	vehicle.stop_engine()
	var/obj/structure/ms13_vehicle_part/engine/second = car.add_car_part("1,1", /obj/structure/ms13_vehicle_part/engine)
	car.add_car_part("6,3", /obj/structure/ms13_vehicle_part/fuel_tank)
	car.add_car_part("3,2", /obj/structure/ms13_vehicle_part/battery)
	if(length(vehicle.engines) != 2 || length(vehicle.fuel_tanks) != 2 || vehicle.charge_capacity() != 20000)
		Fail("A second engine, tank or battery didn't join the first.")
	var/charge = vehicle.stored_charge()
	if(!vehicle.start_engine() || vehicle.stored_charge() != charge - 2 * vehicle.starter_cost)
		Fail("Starting two engines didn't crank both.")
	var/two_engines = vehicle.gear_delay(top)
	if(two_engines >= one_engine || two_engines <= one_engine / 2)
		Fail("Two engines drove [one_engine / two_engines] times as fast as one, not faster but less than double.")
	var/fuel = vehicle.stored_fuel()
	vehicle.burn_fuel(1)
	if(abs(fuel - vehicle.stored_fuel() - 2) > 0.01)
		Fail("Two engines burnt [fuel - vehicle.stored_fuel()] a tile, not twice one's.")
	second.update_integrity(1)
	if(!vehicle.engine_running || vehicle.gear_delay(top) <= one_engine)
		Fail("With one of two engines broken, it stalled, or its dead weight didn't slow it.")
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames.Copy())
		qdel(frame)
#endif
