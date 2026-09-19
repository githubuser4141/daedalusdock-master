/**
 * A boxier follow-up to the jeep: a 2x2 armored truck with solid hull plating down both sides and
 * across most of the back, a windshield up front, and one rear panel replaced with an actual door
 * (vehicle_walls.dm's /obj/structure/window/ms13_vehicle_wall/solid/door) so it can be entered/exited
 * without walking through the solid parts of the hull. Same hand-assembled-in-Initialize() pattern as
 * jeep.dm, just laid out on a 2-wide by 2-long footprint instead of 1x2.
 *
 * Pivot is the front-left tile; place this one object in the map editor and rotate it to set the
 * truck's facing, same as the jeep.
 */
/datum/ms13_ground_vehicle/armored_truck
	acceleration_delay = 1.2 SECONDS
	turn_delay = 5
	max_turn_speed = 1
	turn_speed_loss = 1
	ram_damage_base = 5
	ram_damage_per_speed = 5
	ram_knockdown_per_speed = 5
	running_gear_integrity = 110
	engine_integrity = 280
	fuel_per_tile = 0.12

/obj/structure/ms13_vehicle_frame/armored_truck_front_left
	name = "armored truck"
	desc = "A boxy, armor-plated transport truck."
	vehicle_controller_type = /datum/ms13_ground_vehicle/armored_truck

/obj/structure/ms13_vehicle_frame/armored_truck_front_left/Initialize(mapload)
	. = ..()
	roof.icon_state = "roof_steel_hatch_driver"
	vehicle = new vehicle_controller_type
	vehicle.pivot = src
	vehicle.dir = dir
	vehicle.frames += src

	var/turf/front_right_turf = vehicle.get_relative_turf(0, 1, dir)
	var/turf/back_left_turf = vehicle.get_relative_turf(-1, 0, dir)
	var/turf/back_right_turf = vehicle.get_relative_turf(-1, 1, dir)
	if(!front_right_turf || front_right_turf.density || !back_left_turf || back_left_turf.density || !back_right_turf || back_right_turf.density)
		// Not enough clear room to build the other three tiles - bail out as a plain, undrivable
		// frame tile rather than leaving a half-built truck with no driver seat.
		return

	var/obj/structure/ms13_vehicle_frame/front_right = new(front_right_turf)
	front_right.roof.icon_state = "roof_steel_hatch"
	front_right.vehicle = vehicle
	front_right.dir = dir
	front_right.forward_offset = 0
	front_right.right_offset = 1
	vehicle.frames += front_right

	var/obj/structure/ms13_vehicle_frame/back_left = new(back_left_turf)
	back_left.roof.icon_state = "roof_steel_exhaust"
	back_left.vehicle = vehicle
	back_left.dir = dir
	back_left.forward_offset = -1
	back_left.right_offset = 0
	vehicle.frames += back_left

	var/obj/structure/ms13_vehicle_frame/back_right = new(back_right_turf)
	back_right.roof.icon_state = "roof_steel_closedhatch"
	back_right.vehicle = vehicle
	back_right.dir = dir
	back_right.forward_offset = -1
	back_right.right_offset = 1
	vehicle.frames += back_right

	// Front: windshield across both front tiles - still see-through/driveable-by-sight, unlike the
	// solid hull everywhere else.
	spawn_wall(dir, "c_windshield", /obj/structure/window/ms13_vehicle_wall/shuttered)
	front_right.spawn_wall(dir, "c_windshield", /obj/structure/window/ms13_vehicle_wall/shuttered)

	// Sides: solid armor plating down both long edges - blocks sight in and out, per the solid
	// subtype's opacity.
	spawn_wall(turn(dir, 90), , /obj/structure/window/ms13_vehicle_wall/solid)
	back_left.spawn_wall(turn(dir, 90), , /obj/structure/window/ms13_vehicle_wall/solid)
	front_right.spawn_wall(turn(dir, -90), , /obj/structure/window/ms13_vehicle_wall/solid)
	back_right.spawn_wall(turn(dir, -90), , /obj/structure/window/ms13_vehicle_wall/solid)

	// Back: one solid panel plus one door - the entrance.
	back_left.spawn_wall(turn(dir, 180), , /obj/structure/window/ms13_vehicle_wall/solid)
	back_right.spawn_wall(turn(dir, 180), , /obj/structure/window/ms13_vehicle_wall/solid/door)

	var/obj/structure/chair/ms13_vehicle_seat/driver_seat = new(get_turf(src))
	driver_seat.parent_frame = src
	driver_seat.configure_driver_seat()
	driver_seat.icon_state = "driver_car"
	driver_seat.setDir(dir)

	var/obj/structure/chair/ms13_vehicle_seat/passenger_seat = new(front_right_turf)
	passenger_seat.parent_frame = front_right
	passenger_seat.icon_state = "commanders_seat"
	passenger_seat.setDir(dir)

	back_left.spawn_part(/obj/structure/ms13_vehicle_part/engine)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/gearbox/three_speed)
	back_right.spawn_part(/obj/structure/ms13_vehicle_part/fuel_tank/large)
	// The cargo box is sealed hull, so it needs its own light.
	back_right.spawn_part(/obj/structure/ms13_vehicle_part/interior_light)
	spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light)
	back_left.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/light, 180)
	spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/camera, 90)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/camera, -90)
	back_right.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/camera, 180)
	spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 90)
	back_left.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 90)
	front_right.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 270)
	back_right.spawn_part(/obj/structure/ms13_vehicle_part/running_gear/wheel, 270)
	// back_left/back_right are left as open floor - standing room/cargo space behind the driver,
	// reachable through the rear door.
