/// Confirms the basic ground vehicle assembles correctly, actually carries its driver and back frame
/// along when driven, and correctly refuses to move through a real obstacle.
/datum/unit_test/ms13_ground_vehicle_basic
	name = "VEHICLES: Basic Ground Vehicle Moves As One Unit"

/datum/unit_test/ms13_ground_vehicle_basic/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	TEST_ASSERT(front.vehicle, "Jeep front tile did not build a vehicle controller.")
	TEST_ASSERT_EQUAL(length(front.vehicle.frames), 2, "Jeep did not assemble both frame tiles.")
	// Front tile: front/left/right (3). Back tile: left/right (2) - its rear stays open as the entrance.
	TEST_ASSERT_EQUAL(length(front.vehicle.walls), 5, "Jeep did not assemble all 5 expected wall segments.")

	var/obj/structure/ms13_vehicle_frame/back
	for(var/obj/structure/ms13_vehicle_frame/candidate as anything in front.vehicle.frames)
		if(candidate != front)
			back = candidate
	TEST_ASSERT(back, "Could not find the jeep's back frame tile.")

	var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent)
	driver.forceMove(get_turf(front))

	var/obj/structure/chair/ms13_vehicle_seat/driver_seat
	for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(front))
		if(seat.is_driver_seat)
			driver_seat = seat
	TEST_ASSERT(driver_seat, "No driver seat found on the jeep's front tile.")

	driver_seat.user_buckle_mob(driver, driver)
	TEST_ASSERT_EQUAL(front.vehicle.driver, driver, "Buckling into the driver seat did not register as the vehicle's driver.")

	var/turf/expected_front_dest = get_step(front, EAST)
	var/turf/expected_back_dest = get_step(back, EAST)
	TEST_ASSERT(expected_front_dest && !expected_front_dest.density, "No clear tile east of the front frame for this test.")
	TEST_ASSERT(expected_back_dest && !expected_back_dest.density, "No clear tile east of the back frame for this test.")

	var/result = front.vehicle.do_move(EAST)
	TEST_ASSERT(result, "do_move() reported failure on a clear path.")
	TEST_ASSERT_EQUAL(get_turf(front), expected_front_dest, "Front frame did not move to the expected tile.")
	TEST_ASSERT_EQUAL(get_turf(back), expected_back_dest, "Back frame did not move to the expected tile.")
	TEST_ASSERT_EQUAL(get_turf(driver), expected_front_dest, "Driver was not carried along with the vehicle.")

	// Rotation: turn 90 degrees and confirm the back frame, its walls, and the driver all land where
	// expected, and that the walls' own facings turned with them, not just their positions.
	var/original_dir = front.vehicle.dir
	var/new_facing = turn(original_dir, 90)
	var/turf/expected_back_after_turn = front.vehicle.get_relative_turf(-1, 0, new_facing)
	TEST_ASSERT(expected_back_after_turn && !expected_back_after_turn.density, "No clear tile to test rotation into.")

	front.vehicle.next_move_time = 0
	var/rotate_result = front.vehicle.do_rotate(new_facing)
	TEST_ASSERT(rotate_result, "do_rotate() reported failure on a clear path.")
	TEST_ASSERT_EQUAL(front.vehicle.dir, new_facing, "Vehicle's tracked dir did not update after rotating.")
	TEST_ASSERT_EQUAL(get_turf(back), expected_back_after_turn, "Back frame did not land in the expected spot after rotating.")
	TEST_ASSERT_EQUAL(get_turf(driver), get_turf(front), "Driver should stay on the (non-moving) pivot tile after a turn.")

	var/all_walls_match = TRUE
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front.vehicle.walls)
		if(wall.dir != turn(new_facing, wall.relative_turn))
			all_walls_match = FALSE
	TEST_ASSERT(all_walls_match, "At least one wall's facing did not rotate to match its relative_turn after turning.")

	// Now block the path and confirm the vehicle correctly refuses to move through a real obstacle,
	// rather than phasing through it.
	front.vehicle.next_move_time = 0
	var/turf/before_block = get_turf(front)
	new /obj/structure/table(get_step(front, new_facing))
	var/blocked_result = front.vehicle.do_move(new_facing)
	TEST_ASSERT(!blocked_result, "do_move() reported success while a dense obstacle blocked the path.")
	TEST_ASSERT_EQUAL(get_turf(front), before_block, "Vehicle moved despite a blocked path.")

/// Confirms the boxier armored truck assembles its full 2x2 footprint, that its solid hull panels
/// actually block sight (opacity), and that its rear door can be opened/closed to toggle passability.
/datum/unit_test/ms13_ground_vehicle_armored_truck
	name = "VEHICLES: Armored Truck Has Solid Walls And A Working Door"

/datum/unit_test/ms13_ground_vehicle_armored_truck/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/armored_truck_front_left/front_left = new(spot)
	TEST_ASSERT(front_left.vehicle, "Armored truck front-left tile did not build a vehicle controller.")
	TEST_ASSERT_EQUAL(length(front_left.vehicle.frames), 4, "Armored truck did not assemble all 4 frame tiles.")
	TEST_ASSERT_EQUAL(length(front_left.vehicle.walls), 8, "Armored truck did not assemble all 8 expected wall segments.")

	var/solid_count = 0
	var/door_count = 0
	var/obj/structure/window/ms13_vehicle_wall/solid/door/door
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front_left.vehicle.walls)
		if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid/door))
			door_count++
			door = wall
		else if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid))
			solid_count++
			TEST_ASSERT(wall.opacity, "A solid hull panel wasn't actually opaque.")
	TEST_ASSERT_EQUAL(door_count, 1, "Armored truck should have exactly one door.")
	TEST_ASSERT_EQUAL(solid_count, 5, "Armored truck should have 5 solid (non-door, non-windshield) hull panels.")
	TEST_ASSERT(door, "Could not find the truck's rear door.")

	TEST_ASSERT(door.density, "Door should start closed (dense).")
	TEST_ASSERT(door.opacity, "Door should start closed (opaque).")
	door.open()
	TEST_ASSERT(!door.density, "Door did not lose density after opening.")
	TEST_ASSERT(!door.opacity, "Door did not lose opacity after opening.")
	door.close()
	TEST_ASSERT(door.density, "Door did not regain density after closing.")
	TEST_ASSERT(door.opacity, "Door did not regain opacity after closing.")
