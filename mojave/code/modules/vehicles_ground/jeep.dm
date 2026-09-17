/**
 * The one concrete vehicle this basic pass ships with: a plain 1x2 jeep, front driver seat + back
 * passenger seat, a windshield up front and windows on both long sides, open at the back as the
 * entrance. Hand-assembled here in Initialize() rather than built from separate craftable parts -
 * place this single object in the map editor and rotate it to set which way the jeep initially faces;
 * the rest (back tile, walls, seats) spawns itself alongside it, and the whole thing can drive/turn
 * freely afterward.
 */
/datum/ms13_ground_vehicle/jeep
	acceleration_delay = 0.8 SECONDS
	coast_delay = 1 SECONDS
	turn_delay = 3
	max_turn_speed = 2
	turn_speed_loss = 1
	ram_damage_base = 3
	ram_damage_per_speed = 3
	ram_knockdown_per_speed = 4
	running_gear_integrity = 65
	open_top = TRUE
	engine_integrity = 160
	fuel_per_tile = 0.08

/obj/structure/ms13_vehicle_frame/jeep_front
	name = "jeep"
	desc = "A simple open-top jeep."
	vehicle_controller_type = /datum/ms13_ground_vehicle/jeep

/obj/structure/ms13_vehicle_frame/jeep_front/Initialize(mapload)
	. = ..()
	roof.icon_state = "roof_steel_hatch_driver"
	vehicle = new vehicle_controller_type
	vehicle.pivot = src
	vehicle.dir = dir
	vehicle.frames += src

	var/turf/front_turf = get_turf(src)
	var/turf/back_turf = get_step(front_turf, turn(dir, 180))
	if(!back_turf || back_turf.density)
		// Nowhere to put the back half - bail out as a plain, undrivable frame tile rather than
		// leaving a half-built vehicle with no driver seat behind.
		return

	var/obj/structure/ms13_vehicle_frame/back = new(back_turf)
	back.roof.icon_state = "roof_steel_exhaust"
	back.vehicle = vehicle
	back.dir = dir
	back.forward_offset = -1
	vehicle.frames += back

	spawn_wall(dir, "c_windshield", /obj/structure/window/ms13_vehicle_wall/shuttered) // front
	spawn_wall(turn(dir, 90), "c_window", /obj/structure/window/ms13_vehicle_wall/shuttered) // left
	spawn_wall(turn(dir, -90), "c_window", /obj/structure/window/ms13_vehicle_wall/shuttered) // right
	back.spawn_wall(turn(dir, 90), "c_window", /obj/structure/window/ms13_vehicle_wall/shuttered) // left
	back.spawn_wall(turn(dir, -90), "c_window", /obj/structure/window/ms13_vehicle_wall/shuttered) // right
	// back.spawn_wall(turn(dir, 180), ...) intentionally skipped - that's the entrance

	var/obj/structure/chair/ms13_vehicle_seat/driver_seat = new(front_turf)
	driver_seat.parent_frame = src
	driver_seat.is_driver_seat = TRUE
	driver_seat.icon_state = "driver_car"
	driver_seat.setDir(dir)

	var/obj/structure/chair/ms13_vehicle_seat/passenger_seat = new(back_turf)
	passenger_seat.parent_frame = back
	passenger_seat.icon_state = "commanders_seat"
	passenger_seat.setDir(dir)

	spawn_part(/obj/structure/ms13_vehicle_part/engine)
	spawn_part(/obj/structure/ms13_vehicle_part/gearbox)
	back.spawn_part(/obj/structure/ms13_vehicle_part/fuel_tank)
	spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 90)
	spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 270)
	back.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 90)
	back.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 270)
