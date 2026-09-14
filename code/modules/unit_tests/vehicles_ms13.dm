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
	TEST_ASSERT_EQUAL(length(front.vehicle.parts), 5, "Jeep did not assemble its engine and four wheels.")
	TEST_ASSERT(front.vehicle.has_motive_power(), "A complete, fueled jeep did not have motive power.")
	var/wheel_count = 0
	for(var/obj/structure/ms13_vehicle_part/running_gear/wheel/wheel in front.vehicle.parts)
		wheel_count++
		TEST_ASSERT(!wheel.density, "A vehicle wheel was dense and would prevent somebody standing over it.")
		TEST_ASSERT(wheel.exterior_image, "A vehicle wheel did not create its exterior-only image.")
		TEST_ASSERT_EQUAL(wheel.exterior_image.mouse_opacity, MOUSE_OPACITY_ICON, "A wheel image would intercept clicks outside its visible pixels.")
	TEST_ASSERT_EQUAL(wheel_count, 4, "Jeep did not assemble four independently damageable wheels.")
	TEST_ASSERT(front.vehicle.engine?.reagents?.has_reagent(/datum/reagent/fuel), "Jeep engine did not start with reagent fuel.")

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
	TEST_ASSERT(istype(front.vehicle, /datum/ms13_ground_vehicle/jeep), "Jeep did not instantiate its own handling configuration.")
	TEST_ASSERT_EQUAL(length(front.vehicle.speed_delays), 4, "Jeep did not receive its configured four speed bands.")

	var/turf/expected_front_dest = get_step(front, EAST)
	var/turf/expected_back_dest = get_step(back, EAST)
	TEST_ASSERT(expected_front_dest && !expected_front_dest.density, "No clear tile east of the front frame for this test.")
	TEST_ASSERT(expected_back_dest && !expected_back_dest.density, "No clear tile east of the back frame for this test.")

	var/fuel_before_move = front.vehicle.engine.reagents.get_reagent_amount(/datum/reagent/fuel)
	var/result = front.vehicle.do_move(EAST)
	TEST_ASSERT(result, "do_move() reported failure on a clear path.")
	TEST_ASSERT_EQUAL(get_turf(front), expected_front_dest, "Front frame did not move to the expected tile.")
	TEST_ASSERT_EQUAL(get_turf(back), expected_back_dest, "Back frame did not move to the expected tile.")
	TEST_ASSERT_EQUAL(get_turf(driver), expected_front_dest, "Driver was not carried along with the vehicle.")
	TEST_ASSERT(front.vehicle.engine.reagents.get_reagent_amount(/datum/reagent/fuel) < fuel_before_move, "A powered movement step consumed no engine fuel.")

	// Rotation: turn 90 degrees and confirm the back frame, its walls, and the driver all land where
	// expected, and that the walls' own facings turned with them, not just their positions.
	var/original_dir = front.vehicle.dir
	var/new_facing = turn(original_dir, 90)
	var/turf/expected_back_after_turn = front.vehicle.get_relative_turf(-1, 0, new_facing)
	TEST_ASSERT(expected_back_after_turn && !expected_back_after_turn.density, "No clear tile to test rotation into.")
	var/list/expected_wall_dirs = list()
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front.vehicle.walls)
		var/relative_dir = wall.dir == original_dir ? 0 : wall.dir == turn(original_dir, 90) ? 90 : 270
		expected_wall_dirs[wall] = turn(new_facing, relative_dir)

	front.vehicle.next_move_time = 0
	var/rotate_result = front.vehicle.do_rotate(new_facing)
	TEST_ASSERT(rotate_result, "do_rotate() reported failure on a clear path.")
	TEST_ASSERT_EQUAL(front.vehicle.dir, new_facing, "Vehicle's tracked dir did not update after rotating.")
	TEST_ASSERT_EQUAL(get_turf(back), expected_back_after_turn, "Back frame did not land in the expected spot after rotating.")
	TEST_ASSERT_EQUAL(get_turf(driver), get_turf(front), "Driver should stay on the (non-moving) pivot tile after a turn.")

	var/all_walls_match = TRUE
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front.vehicle.walls)
		if(wall.dir != expected_wall_dirs[wall])
			all_walls_match = FALSE
	TEST_ASSERT(all_walls_match, "At least one wall swapped its left/right side when the jeep turned.")

	// Now block the path and confirm the vehicle correctly refuses to move through a real obstacle,
	// rather than phasing through it.
	front.vehicle.next_move_time = 0
	var/turf/before_block = get_turf(front)
	new /obj/structure/table(get_step(front, new_facing))
	var/blocked_result = front.vehicle.do_move(new_facing)
	TEST_ASSERT(!blocked_result, "do_move() reported success while a dense obstacle blocked the path.")
	TEST_ASSERT_EQUAL(get_turf(front), before_block, "Vehicle moved despite a blocked path.")

/// Confirms acceleration/braking state comes from the concrete vehicle config and that a moving
/// vehicle lightly damages and pushes a loose mob instead of treating it as an immovable wall.
/datum/unit_test/ms13_ground_vehicle_momentum
	name = "VEHICLES: Momentum And Light Ramming"

/datum/unit_test/ms13_ground_vehicle_momentum/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	var/datum/ms13_ground_vehicle/jeep/vehicle = front.vehicle
	TEST_ASSERT(vehicle, "Jeep did not build a configured controller for the momentum test.")

	var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent)
	driver.forceMove(get_turf(front))
	var/obj/structure/chair/ms13_vehicle_seat/driver_seat
	for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(front))
		if(seat.is_driver_seat)
			driver_seat = seat
	TEST_ASSERT(driver_seat, "No driver seat found for the momentum test.")
	driver_seat.user_buckle_mob(driver, driver)

	// Exercise throttle state without leaving a live timer behind: the first input performs one
	// immediate low-speed step, then later held inputs climb the configured bands.
	vehicle.apply_throttle(vehicle.dir)
	TEST_ASSERT_EQUAL(vehicle.speed, 1, "Vehicle did not start in its first speed band.")
	TEST_ASSERT(vehicle.moving, "Vehicle did not enter its self-driven movement loop.")
	TEST_ASSERT(vehicle.engine.soundloop?.is_active(), "The engine running loop did not start with the vehicle.")
	TEST_ASSERT(vehicle.running_gear_soundloop?.is_active(), "The wheel movement loop did not start with the vehicle.")
	vehicle.next_acceleration_time = 0
	vehicle.apply_throttle(vehicle.travel_dir)
	TEST_ASSERT_EQUAL(vehicle.speed, 2, "Held throttle did not advance to the next configured speed band.")
	vehicle.apply_throttle(turn(vehicle.travel_dir, 180))
	TEST_ASSERT_EQUAL(vehicle.speed, 1, "Opposite input did not brake the vehicle by one speed band.")
	vehicle.stop_motion()
	TEST_ASSERT(!vehicle.engine.soundloop?.is_active(), "The engine running loop continued after the vehicle stopped.")
	TEST_ASSERT(!vehicle.running_gear_soundloop?.is_active(), "The wheel movement loop continued after the vehicle stopped.")

	var/turf/ram_turf = get_step(front, vehicle.dir)
	var/turf/push_turf = get_step(ram_turf, vehicle.dir)
	TEST_ASSERT(ram_turf && push_turf && !ram_turf.density && !push_turf.density, "No clear straight path for the ramming test.")
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	victim.forceMove(ram_turf)
	var/brute_before = victim.getBruteLoss()
	vehicle.speed = 2
	vehicle.next_move_time = 0
	var/ram_result = vehicle.do_move(vehicle.dir)
	TEST_ASSERT(ram_result, "Vehicle failed to enter a mob's tile when the mob could be pushed clear.")
	TEST_ASSERT_EQUAL(get_turf(victim), push_turf, "Rammed mob was not pushed one tile ahead of the vehicle.")
	TEST_ASSERT(victim.getBruteLoss() > brute_before, "Rammed mob took no brute damage.")
	vehicle.stop_motion()

	// Momentum belongs to the vehicle, so losing the driver prevents new input but does not cancel
	// an already-moving vehicle's next coast step.
	vehicle.driver = null
	vehicle.speed = 1
	vehicle.travel_dir = vehicle.dir
	vehicle.last_throttle_time = world.time
	vehicle.moving = TRUE
	vehicle.movement_generation++
	var/turf/driverless_destination = get_step(front, vehicle.travel_dir)
	vehicle.movement_tick(vehicle.movement_generation)
	TEST_ASSERT_EQUAL(get_turf(front), driverless_destination, "Vehicle stopped immediately when its driver was lost despite having momentum.")
	vehicle.stop_motion()

/// Confirms the boxier armored truck assembles its full 2x2 footprint, masks sight across solid hull,
/// leaves every interior frame visible, and toggles its rear door's movement/vision boundary.
/datum/unit_test/ms13_ground_vehicle_armored_truck
	name = "VEHICLES: Armored Truck Has Solid Walls And A Working Door"

/datum/unit_test/ms13_ground_vehicle_armored_truck/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/armored_truck_front_left/front_left = new(spot)
	TEST_ASSERT(front_left.vehicle, "Armored truck front-left tile did not build a vehicle controller.")
	TEST_ASSERT_EQUAL(length(front_left.vehicle.frames), 4, "Armored truck did not assemble all 4 frame tiles.")
	TEST_ASSERT_EQUAL(length(front_left.vehicle.walls), 8, "Armored truck did not assemble all 8 expected wall segments.")
	TEST_ASSERT_EQUAL(length(front_left.vehicle.parts), 5, "Armored truck did not assemble its engine and four wheels.")
	TEST_ASSERT(front_left.vehicle.has_motive_power(), "A complete, fueled truck did not have motive power.")
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in front_left.vehicle.frames)
		TEST_ASSERT(frame.roof, "An armored truck frame did not create its opaque roof image.")
		TEST_ASSERT_EQUAL(frame.roof.loc, frame, "A truck roof image was not attached to its frame.")
		TEST_ASSERT(frame.roof.layer > MOB_LAYER, "A truck roof image would render below its occupants.")
		TEST_ASSERT_EQUAL(frame.roof.mouse_opacity, MOUSE_OPACITY_TRANSPARENT, "A truck roof image would intercept clicks meant for its doors or hull.")
		TEST_ASSERT(frame.roof.icon_state != "roof_steel", "An armored truck frame still has the featureless placeholder roof.")

	var/solid_count = 0
	var/door_count = 0
	var/obj/structure/window/ms13_vehicle_wall/solid/door/door
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front_left.vehicle.walls)
		if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid/door))
			door_count++
			door = wall
		else if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid))
			solid_count++
	TEST_ASSERT_EQUAL(door_count, 1, "Armored truck should have exactly one door.")
	TEST_ASSERT_EQUAL(solid_count, 5, "Armored truck should have 5 solid (non-door, non-windshield) hull panels.")
	TEST_ASSERT(door, "Could not find the truck's rear door.")
	for(var/obj/structure/window/ms13_vehicle_wall/solid/solid_wall in front_left.vehicle.walls)
		TEST_ASSERT(solid_wall.layer > solid_wall.parent_frame.roof.layer, "A solid hull panel would be hidden below the exterior roof.")
		TEST_ASSERT(!solid_wall.opacity, "A solid hull panel made its entire interior frame tile opaque.")
		TEST_ASSERT(solid_wall.blocks_vision, "A closed solid hull panel did not mark its boundary as vision-blocking.")
		TEST_ASSERT(front_left.vehicle.blocks_sight_from(get_turf(solid_wall.parent_frame), get_step(solid_wall, solid_wall.dir)), "A solid hull boundary did not mask the exterior turf beyond it.")
	for(var/obj/structure/ms13_vehicle_frame/source_frame as anything in front_left.vehicle.frames)
		for(var/obj/structure/ms13_vehicle_frame/target_frame as anything in front_left.vehicle.frames)
			TEST_ASSERT(!front_left.vehicle.blocks_sight_from(get_turf(source_frame), get_turf(target_frame)), "Sight masking blacked out a turf inside the vehicle.")
	for(var/obj/structure/window/ms13_vehicle_wall/window in front_left.vehicle.walls)
		if(!istype(window, /obj/structure/window/ms13_vehicle_wall/solid))
			TEST_ASSERT(!front_left.vehicle.blocks_sight_from(get_turf(window.parent_frame), get_step(window, window.dir)), "A windshield port incorrectly masked the exterior beyond it.")

	TEST_ASSERT(door.density, "Door should start closed (dense).")
	TEST_ASSERT(door.blocks_vision, "Door should start closed (vision-blocking).")
	door.open()
	TEST_ASSERT(!door.density, "Door did not lose density after opening.")
	TEST_ASSERT(!door.blocks_vision, "Door still blocked vision after opening.")
	TEST_ASSERT(!front_left.vehicle.blocks_sight_from(get_turf(door.parent_frame), get_step(door, door.dir)), "The open door still masked the exterior beyond it.")
	door.close()
	TEST_ASSERT(door.density, "Door did not regain density after closing.")
	TEST_ASSERT(door.blocks_vision, "Door did not block vision after closing.")
	TEST_ASSERT(front_left.vehicle.blocks_sight_from(get_turf(door.parent_frame), get_step(door, door.dir)), "The closed door did not mask the exterior beyond it.")

	// Rotation on a 2-wide vehicle: every frame and wall should land exactly where its own
	// forward/right offset says it should, same check the (already-passing) jeep test does, just
	// generalized to all 4 frames/8 walls instead of assuming a 1-wide, 2-long shape.
	var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent)
	driver.forceMove(get_turf(front_left))

	var/obj/structure/chair/ms13_vehicle_seat/driver_seat
	for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(front_left))
		if(seat.is_driver_seat)
			driver_seat = seat
	TEST_ASSERT(driver_seat, "No driver seat found on the truck's front-left tile.")
	driver_seat.user_buckle_mob(driver, driver)
	TEST_ASSERT_EQUAL(front_left.vehicle.driver, driver, "Buckling did not register as the truck's driver.")
	TEST_ASSERT(istype(front_left.vehicle, /datum/ms13_ground_vehicle/armored_truck), "Truck did not instantiate its own handling configuration.")
	TEST_ASSERT_EQUAL(length(front_left.vehicle.speed_delays), 3, "Truck did not receive its configured three speed bands.")

	var/obj/structure/window/ms13_vehicle_wall/shuttered/shutter
	for(var/obj/structure/window/ms13_vehicle_wall/shuttered/candidate in front_left.vehicle.walls)
		shutter = candidate
		break
	TEST_ASSERT(shutter, "Truck windshields did not receive shutter capability.")
	shutter.attack_hand(driver)
	TEST_ASSERT(shutter.shutters_closed && shutter.blocks_vision, "Closing a window shutter did not block its sight boundary.")
	TEST_ASSERT(front_left.vehicle.blocks_sight_from(get_turf(shutter.parent_frame), get_step(shutter, shutter.dir)), "Closed shutter did not mask the exterior beyond its window.")
	shutter.attack_hand(driver)
	TEST_ASSERT(!shutter.shutters_closed && !shutter.blocks_vision, "Opening a window shutter did not restore visibility.")

	var/original_dir = front_left.vehicle.dir
	var/new_facing = turn(original_dir, 90)

	var/list/expected_frame_dest = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in front_left.vehicle.frames)
		var/turf/dest = front_left.vehicle.get_relative_turf(frame.forward_offset, frame.right_offset, new_facing)
		TEST_ASSERT(dest && !dest.density, "No clear tile to rotate into for one of the truck's frames.")
		expected_frame_dest[frame] = dest
	var/list/expected_part_dest = list()
	for(var/obj/structure/ms13_vehicle_part/part as anything in front_left.vehicle.parts)
		expected_part_dest[part] = front_left.vehicle.get_relative_turf(part.forward_offset, part.right_offset, new_facing)

	front_left.vehicle.next_move_time = 0
	var/rotate_result = front_left.vehicle.do_rotate(new_facing)
	TEST_ASSERT(rotate_result, "do_rotate() reported failure on a clear path for the armored truck.")
	TEST_ASSERT_EQUAL(front_left.vehicle.dir, new_facing, "Truck's tracked dir did not update after rotating.")

	for(var/obj/structure/ms13_vehicle_frame/frame as anything in front_left.vehicle.frames)
		TEST_ASSERT_EQUAL(get_turf(frame), expected_frame_dest[frame], "A truck frame did not land where its own forward/right offset says it should after rotating.")
		TEST_ASSERT_EQUAL(frame.roof.dir, new_facing, "A truck roof did not rotate with its frame.")
	for(var/obj/structure/ms13_vehicle_part/part as anything in front_left.vehicle.parts)
		TEST_ASSERT_EQUAL(get_turf(part), expected_part_dest[part], "A truck component did not rotate with its configured frame offset.")

	var/all_walls_match = TRUE
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front_left.vehicle.walls)
		var/turf/expected_wall_turf = front_left.vehicle.get_relative_turf(wall.forward_offset, wall.right_offset, new_facing)
		if(get_turf(wall) != expected_wall_turf || wall.dir != turn(new_facing, wall.relative_turn))
			all_walls_match = FALSE
		if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid))
			var/obj/structure/window/ms13_vehicle_wall/solid/solid_wall = wall
			if(!front_left.vehicle.blocks_sight_from(get_turf(solid_wall.parent_frame), get_step(solid_wall, solid_wall.dir)))
				all_walls_match = FALSE
	TEST_ASSERT(all_walls_match, "At least one truck wall did not land at/facing the position its own offsets say it should after rotating.")

	var/obj/structure/ms13_vehicle_part/engine/engine = front_left.vehicle.engine
	var/fuel_before_emptying = engine.reagents.get_reagent_amount(/datum/reagent/fuel)
	engine.reagents.remove_reagent(/datum/reagent/fuel, fuel_before_emptying)
	TEST_ASSERT(!front_left.vehicle.has_motive_power(), "An empty engine still provided motive power.")
	TEST_ASSERT(!front_left.vehicle.apply_throttle(front_left.vehicle.dir), "An empty engine still allowed acceleration.")
	engine.reagents.add_reagent(/datum/reagent/fuel, fuel_before_emptying)
	TEST_ASSERT(front_left.vehicle.has_motive_power(), "Refueling did not restore motive power.")
	engine.take_damage(engine.max_integrity, BRUTE, BOMB, FALSE)
	TEST_ASSERT(!front_left.vehicle.has_motive_power(), "A broken engine still provided motive power.")
	front_left.vehicle.stop_motion()
	TEST_ASSERT(!front_left.vehicle.apply_throttle(front_left.vehicle.dir), "A broken engine still allowed acceleration.")

/// Confirms the Civ13 M113 assembles as a complete 3x4 carrier with a rear ramp, troop seats, and
/// four real track units which participate in the shared motive-power rules.
/datum/unit_test/ms13_ground_vehicle_m113
	name = "VEHICLES: M113 Assembles As A Tracked Personnel Carrier"

/datum/unit_test/ms13_ground_vehicle_m113/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 5, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/m113/front_left = new(spot)
	var/datum/ms13_ground_vehicle/m113/vehicle = front_left.vehicle
	TEST_ASSERT(vehicle, "M113 did not create its configured controller.")
	TEST_ASSERT_EQUAL(length(vehicle.frames), 12, "M113 did not assemble its full 3x4 frame footprint.")
	TEST_ASSERT_EQUAL(length(vehicle.walls), 14, "M113 did not assemble its complete outer hull.")
	TEST_ASSERT_EQUAL(length(vehicle.parts), 5, "M113 did not assemble one engine and four track units.")
	TEST_ASSERT_EQUAL(vehicle.running_gear_soundloop_type, /datum/looping_sound/ms13/vehicle_tracks, "M113 did not select tracked movement audio.")
	TEST_ASSERT(vehicle.has_motive_power(), "A complete, fueled M113 did not have motive power.")

	var/track_count = 0
	var/obj/structure/ms13_vehicle_part/running_gear/track/track_to_break
	for(var/obj/structure/ms13_vehicle_part/running_gear/track/track in vehicle.parts)
		track_count++
		if(!track_to_break)
			track_to_break = track
		TEST_ASSERT(!track.density, "An M113 track prevented somebody standing over and attacking it.")
		TEST_ASSERT(track.exterior_image, "An M113 track did not create an exterior-only clickable image.")
	TEST_ASSERT_EQUAL(track_count, 4, "M113 did not assemble four independently damageable track units.")
	TEST_ASSERT(istype(vehicle.engine, /obj/structure/ms13_vehicle_part/engine/m113), "M113 did not receive its Detroit diesel engine.")

	var/ramp_count = 0
	for(var/obj/structure/window/ms13_vehicle_wall/solid/door/m113/ramp in vehicle.walls)
		ramp_count++
	TEST_ASSERT_EQUAL(ramp_count, 1, "M113 should have exactly one rear ramp.")

	var/seat_count = 0
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		TEST_ASSERT(findtext(frame.icon_state, "m113_frame_steel_"), "An M113 frame did not use its Civ13 floor sprite.")
		TEST_ASSERT(findtext(frame.roof.icon_state, "m113_roof_steel_"), "An M113 frame did not use its matching Civ13 roof sprite.")
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
			seat_count++
	TEST_ASSERT_EQUAL(seat_count, 7, "M113 did not assemble its driver and six troop seats.")

	track_to_break.take_damage(track_to_break.max_integrity, BRUTE, BOMB, FALSE)
	TEST_ASSERT(!vehicle.has_motive_power(), "M113 still had motive power after losing one of its four required track units.")
