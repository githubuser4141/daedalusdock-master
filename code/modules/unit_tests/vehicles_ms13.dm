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
	TEST_ASSERT_EQUAL(length(front.vehicle.parts), 9, "Jeep did not assemble its drivetrain, battery, headlight and wheels.")
	front.vehicle.set_ignition(TRUE)
	TEST_ASSERT(front.vehicle.start_engine(), "Jeep engine failed to start.")
	TEST_ASSERT(front.vehicle.has_motive_power(), "A complete, fueled jeep did not have motive power.")
	var/wheel_count = 0
	for(var/obj/structure/ms13_vehicle_part/running_gear/wheel/wheel in front.vehicle.parts)
		wheel_count++
		TEST_ASSERT(!wheel.density, "A vehicle wheel was dense and would prevent somebody standing over it.")
		TEST_ASSERT(wheel.exterior_image, "A vehicle wheel did not create its exterior-only image.")
		TEST_ASSERT_EQUAL(wheel.exterior_image.mouse_opacity, MOUSE_OPACITY_ICON, "A wheel image would intercept clicks outside its visible pixels.")
		TEST_ASSERT_EQUAL(wheel.exterior_image.pixel_x, wheel.dir == EAST ? 12 : wheel.dir == WEST ? -12 : 0, "A wheel was not offset horizontally toward its outside edge.")
		TEST_ASSERT_EQUAL(wheel.exterior_image.pixel_y, wheel.dir == NORTH ? 12 : wheel.dir == SOUTH ? -12 : 0, "A wheel was not offset vertically toward its outside edge.")
	TEST_ASSERT_EQUAL(wheel_count, 4, "Jeep did not assemble four independently damageable wheels.")
	TEST_ASSERT(front.vehicle.fuel_tank?.has_fuel(), "Jeep fuel tank did not start with reagent fuel.")
	TEST_ASSERT(!front.vehicle.is_weather_sealed(front), "The open-top jeep kept the weather out.")
	TEST_ASSERT(!front.vehicle.engine.reagents, "The engine still carries its own fuel instead of drawing from the tank.")

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
	TEST_ASSERT_EQUAL(front.vehicle.gear_count(), 4, "Jeep gearbox did not provide four gears.")

	var/turf/expected_front_dest = get_step(front, EAST)
	var/turf/expected_back_dest = get_step(back, EAST)
	TEST_ASSERT(expected_front_dest && !expected_front_dest.density, "No clear tile east of the front frame for this test.")
	TEST_ASSERT(expected_back_dest && !expected_back_dest.density, "No clear tile east of the back frame for this test.")

	var/fuel_before_move = front.vehicle.fuel_tank.reagents.get_reagent_amount(/datum/reagent/fuel)
	var/result = front.vehicle.do_move(EAST)
	TEST_ASSERT(result, "do_move() reported failure on a clear path.")
	TEST_ASSERT_EQUAL(get_turf(front), expected_front_dest, "Front frame did not move to the expected tile.")
	TEST_ASSERT_EQUAL(get_turf(back), expected_back_dest, "Back frame did not move to the expected tile.")
	TEST_ASSERT_EQUAL(get_turf(driver), expected_front_dest, "Driver was not carried along with the vehicle.")
	TEST_ASSERT(front.vehicle.fuel_tank.reagents.get_reagent_amount(/datum/reagent/fuel) < fuel_before_move, "A powered movement step drew no fuel from the tank.")

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
	// The first throttle input already moves one tile, so start high enough to ram and coast after it.
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	var/datum/ms13_ground_vehicle/jeep/vehicle = front.vehicle
	TEST_ASSERT(vehicle, "Jeep did not build a configured controller for the momentum test.")
	vehicle.set_ignition(TRUE)
	TEST_ASSERT(vehicle.start_engine(), "Jeep engine failed to start.")

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
	TEST_ASSERT(vehicle.engine.soundloop?.is_active(), "Stopping the wheels also stopped the idling engine.")
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
	// Clear the rammed mob out of the lane; the test room is too short to push it another tile.
	victim.forceMove(locate(run_loc_floor_top_right.x, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))

	// Momentum belongs to the vehicle, so losing the driver prevents new input but does not cancel
	// an already-moving vehicle's next coast step.
	vehicle.driver = null
	vehicle.speed = 1
	vehicle.travel_dir = vehicle.dir
	vehicle.moving = TRUE
	vehicle.movement_generation++
	var/turf/driverless_destination = get_step(front, vehicle.travel_dir)
	vehicle.movement_tick(vehicle.movement_generation)
	TEST_ASSERT_EQUAL(get_turf(front), driverless_destination, "Vehicle stopped immediately when its driver was lost despite having momentum.")
	vehicle.set_ignition(FALSE)
	TEST_ASSERT(vehicle.apply_throttle(turn(vehicle.travel_dir, 180)), "Mechanical braking failed with the ignition off.")
	TEST_ASSERT_EQUAL(vehicle.speed, 0, "Braking did not stop an unpowered vehicle.")
	vehicle.stop_motion()

/datum/unit_test/ms13_vehicle_electrical
	name = "VEHICLES: Battery, Ignition, Lights And Driver Cameras"

/datum/unit_test/ms13_vehicle_electrical/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/armored_truck_front_left/front = new(spot)
	var/datum/ms13_ground_vehicle/vehicle = front.vehicle
	TEST_ASSERT(vehicle.battery && !vehicle.battery.density, "Vehicle battery is missing or not walk-overable.")
	TEST_ASSERT(!vehicle.has_motive_power() && !vehicle.start_engine(), "Engine started without ignition.")
	var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera = locate() in vehicle.parts
	var/obj/structure/ms13_vehicle_part/exterior_equipment/light/light = locate() in vehicle.parts
	var/obj/structure/ms13_vehicle_part/interior_light/dome = locate() in vehicle.parts
	TEST_ASSERT(camera && light && dome, "Truck did not fit electrical accessories.")
	for(var/obj/structure/ms13_vehicle_part/exterior_equipment/equipment in vehicle.parts)
		TEST_ASSERT(ms13_icon_has_state(equipment.equipment_icon, equipment.on_state), "Missing powered accessory art.")
		TEST_ASSERT(ms13_icon_has_state(equipment.equipment_icon, equipment.off_state), "Missing unpowered accessory art.")
	TEST_ASSERT(!camera.is_enabled() && !dome.is_lit(), "Equipment works with ignition off.")
	vehicle.set_ignition(TRUE)
	var/charge_before = vehicle.battery.cell.charge
	TEST_ASSERT(vehicle.start_engine(), "Fueled engine with charged battery failed to start.")
	TEST_ASSERT_EQUAL(vehicle.battery.cell.charge, charge_before - vehicle.starter_cost, "Starter did not consume its charge.")
	vehicle.start_engine()
	TEST_ASSERT_EQUAL(vehicle.battery.cell.charge, charge_before - vehicle.starter_cost, "Starting an already running engine consumed charge twice.")
	var/fuel_before = vehicle.fuel_tank.reagents.get_reagent_amount(/datum/reagent/fuel)
	vehicle.process_power(2)
	TEST_ASSERT(vehicle.battery.cell.charge > charge_before - vehicle.starter_cost, "Running engine did not recharge battery.")
	TEST_ASSERT(vehicle.fuel_tank.reagents.get_reagent_amount(/datum/reagent/fuel) < fuel_before, "Idling engine consumed no fuel.")
	vehicle.stop_engine()
	TEST_ASSERT(!vehicle.has_motive_power() && camera.is_enabled(), "Stopping the engine also disabled battery equipment.")
	charge_before = vehicle.battery.cell.charge
	vehicle.process_power(2)
	TEST_ASSERT(vehicle.battery.cell.charge < charge_before, "Powered equipment did not drain battery.")
	vehicle.exterior_lights_on = TRUE
	vehicle.update_electrical()
	TEST_ASSERT(light.is_enabled() && light.light_outer_range > 0 && light.light_power == 1, "Exterior lighting switch did not illuminate lamps.")
	var/turf/camera_turf = get_turf(camera)
	var/turf/outside = get_step(camera, camera.dir)
	TEST_ASSERT(vehicle.blocks_sight_from(camera_turf, outside), "Camera created a physical window for passengers/NPCs.")
	TEST_ASSERT(!vehicle.blocks_sight_from(camera_turf, outside, TRUE), "Camera did not reveal its hull edge to the driver.")
	vehicle.cameras_on = FALSE
	TEST_ASSERT(vehicle.blocks_sight_from(camera_turf, outside, TRUE), "Switched-off camera still revealed the outside.")
	vehicle.cameras_on = TRUE
	camera.update_integrity(camera.max_integrity * 0.1)
	TEST_ASSERT(vehicle.blocks_sight_from(camera_turf, outside, TRUE), "Broken camera still revealed the outside.")
	camera.repair_damage(camera.max_integrity)
	TEST_ASSERT(!vehicle.blocks_sight_from(camera_turf, outside, TRUE), "Repaired camera did not recover its view.")
	vehicle.battery.cell.charge = 1
	vehicle.process_power(2)
	TEST_ASSERT(!vehicle.has_electrical_power() && !dome.is_lit() && !light.light_outer_range, "Drained battery left lighting powered.")
	TEST_ASSERT(vehicle.blocks_sight_from(camera_turf, outside, TRUE), "Empty battery left camera vision active.")
	TEST_ASSERT(!vehicle.start_engine(), "Empty battery started engine.")
	vehicle.battery.cell.give(1000)
	vehicle.update_electrical()
	TEST_ASSERT(vehicle.start_engine(), "Charged battery did not restore starting.")
	vehicle.battery.update_integrity(vehicle.battery.max_integrity * 0.1)
	TEST_ASSERT(!vehicle.engine_running && !vehicle.has_electrical_power(), "Broken battery left the electrical system powered.")

/datum/unit_test/ms13_vehicle_obstacle_impact
	name = "VEHICLES: Ramming Damages Obstacles And Contact Armor"

/datum/unit_test/ms13_vehicle_obstacle_impact/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	var/datum/ms13_ground_vehicle/vehicle = front.vehicle
	var/obj/structure/window/ms13_vehicle_wall/contact
	for(var/obj/structure/window/ms13_vehicle_wall/panel as anything in vehicle.walls)
		if(panel.parent_frame == front && panel.dir == vehicle.dir)
			contact = panel
	TEST_ASSERT(contact, "No frontal armor for impact test.")
	var/turf/ahead = get_step(front, vehicle.dir)
	var/obj/structure/table/light_obstacle = new(ahead)
	var/integrity_before = contact.get_integrity()
	vehicle.speed = 3
	TEST_ASSERT(vehicle.ram_obstacles(vehicle.dir, vehicle.get_manifest()), "Impact resolution failed on a light obstacle.")
	TEST_ASSERT(QDELETED(light_obstacle), "Fast vehicle could not smash a light table.")
	TEST_ASSERT(contact.get_integrity() < integrity_before, "Impact did not damage the contacting panel.")
	var/obj/structure/table/reinforced_obstacle = new(ahead)
	reinforced_obstacle.modify_max_integrity(5000)
	integrity_before = reinforced_obstacle.get_integrity()
	TEST_ASSERT(!vehicle.do_move(vehicle.dir, TRUE), "Vehicle phased through a surviving reinforced obstacle.")
	TEST_ASSERT(reinforced_obstacle.get_integrity() < integrity_before, "Surviving obstacle took no collision damage.")
	TEST_ASSERT_EQUAL(get_turf(front), spot, "Vehicle moved into an uncleared obstacle.")
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
	TEST_ASSERT_EQUAL(length(front_left.vehicle.parts), 15, "Armored truck did not assemble its drivetrain, battery, lighting, cameras and wheels.")
	front_left.vehicle.set_ignition(TRUE)
	TEST_ASSERT(front_left.vehicle.start_engine(), "Truck engine failed to start.")
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
	var/obj/structure/window/ms13_vehicle_wall/solid/damage_test_wall
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in front_left.vehicle.walls)
		if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid/door))
			door_count++
			door = wall
		else if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid))
			solid_count++
			damage_test_wall ||= wall
	TEST_ASSERT_EQUAL(door_count, 1, "Armored truck should have exactly one door.")
	TEST_ASSERT_EQUAL(solid_count, 5, "Armored truck should have 5 solid (non-door, non-windshield) hull panels.")
	TEST_ASSERT(door, "Could not find the truck's rear door.")
	var/image/damage_test_roof = damage_test_wall.parent_frame.roof
	damage_test_wall.take_damage(10, BRUTE, BLUNT, FALSE)
	TEST_ASSERT_EQUAL(damage_test_roof.icon, 'mojave/icons/objects/vehicles_ground/vehicleparts_damaged.dmi', "Damaging a hull segment did not switch its frame roof to damaged artwork.")
	damage_test_wall.repair_damage(damage_test_wall.max_integrity)
	TEST_ASSERT_EQUAL(damage_test_roof.icon, 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi', "Repairing all damage did not restore the frame's normal roof artwork.")
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
	TEST_ASSERT_EQUAL(front_left.vehicle.gear_count(), 3, "Truck gearbox did not provide three gears.")

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

	// Windshield tiles keep outside light; the boxed-in rear tiles are lit only by the cabin light.
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in front_left.vehicle.frames)
		var/sealed = front_left.vehicle.is_light_sealed(frame)
		TEST_ASSERT_EQUAL(sealed, frame.forward_offset < 0, "Truck frame at [frame.forward_offset],[frame.right_offset] had the wrong light sealing.")
		if(sealed)
			TEST_ASSERT_EQUAL(frame.interior_light.alpha, 255, "A sealed truck tile did not cover the outside lightmap.")
			TEST_ASSERT_EQUAL(frame.interior_light.blend_mode, BLEND_OVERLAY, "A sealed truck tile blended outside light in.")
			TEST_ASSERT_EQUAL(frame.interior_light_block.alpha, 255, "A sealed truck tile let additive outside light through.")
	door.open()
	TEST_ASSERT(!front_left.vehicle.is_light_sealed(door.parent_frame), "An open door still sealed its tile against outside light.")
	TEST_ASSERT(!front_left.vehicle.is_weather_sealed(door.parent_frame), "An open door still kept the weather out.")
	door.close()
	TEST_ASSERT(front_left.vehicle.is_light_sealed(door.parent_frame), "Closing the door did not seal its tile again.")

	// Everyone in the closed-up truck is out of the weather, windshield or not.
	var/datum/particle_weather/dust_storm/storm = new
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in front_left.vehicle.frames)
		TEST_ASSERT(front_left.vehicle.is_weather_sealed(frame), "A closed truck tile at [frame.forward_offset],[frame.right_offset] let the weather in.")
	rider.forceMove(get_turf(door.parent_frame))
	TEST_ASSERT(!storm.can_weather_effect(rider), "Weather reached a rider inside a closed truck.")
	// Someone standing behind the truck can't see the rider until the rear door opens.
	var/mob/living/carbon/human/consistent/onlooker = allocate(/mob/living/carbon/human/consistent)
	onlooker.forceMove(get_step(door, door.dir))
	TEST_ASSERT(ms13_hidden_in_vehicle(rider, onlooker), "A rider in a closed truck was visible from outside.")
	TEST_ASSERT(!ms13_hidden_in_vehicle(onlooker, rider), "The hull hid someone outside the truck from a rider.")
	door.open()
	TEST_ASSERT(storm.can_weather_effect(rider), "Weather did not reach a rider through an open door.")
	TEST_ASSERT(!ms13_hidden_in_vehicle(rider, onlooker), "A rider stayed hidden behind an open door.")
	door.close()
	onlooker.forceMove(run_loc_floor_bottom_left)
	rider.forceMove(run_loc_floor_top_right)
	qdel(storm)

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
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in front_left.vehicle.frames)
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
			TEST_ASSERT_EQUAL(seat.dir, new_facing, "A forward-facing truck seat did not turn with the vehicle.")

	var/obj/structure/ms13_vehicle_part/engine/engine = front_left.vehicle.engine
	var/obj/structure/ms13_vehicle_part/fuel_tank/tank = front_left.vehicle.fuel_tank
	var/fuel_before_emptying = tank.reagents.get_reagent_amount(/datum/reagent/fuel)
	tank.reagents.remove_reagent(/datum/reagent/fuel, fuel_before_emptying)
	TEST_ASSERT(!front_left.vehicle.has_motive_power(), "An empty fuel tank still provided motive power.")
	TEST_ASSERT(!front_left.vehicle.apply_throttle(front_left.vehicle.dir), "An empty fuel tank still allowed acceleration.")
	tank.reagents.add_reagent(/datum/reagent/fuel, fuel_before_emptying)
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
	// Spawned facing south, the hull runs north and west of its pivot, so the corner fits all 3x4 tiles.
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/m113/front_left/front_left = new(spot)
	var/datum/ms13_ground_vehicle/m113/vehicle = front_left.vehicle
	TEST_ASSERT(vehicle, "M113 did not create its configured controller.")
	TEST_ASSERT_EQUAL(length(vehicle.frames), 12, "M113 did not assemble its full 3x4 frame footprint.")
	var/exterior_walls = 0
	var/interior_walls = 0
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in vehicle.walls)
		if(wall.exterior)
			exterior_walls++
		else
			interior_walls++
			TEST_ASSERT(wall.layer < front_left.roof.layer, "An M113 bulkhead would show through the roof.")
	TEST_ASSERT_EQUAL(exterior_walls, 14, "M113 did not assemble its complete outer hull.")
	TEST_ASSERT_EQUAL(interior_walls, 6, "M113 did not assemble its bulkheads and access panels.")
	TEST_ASSERT_EQUAL(length(vehicle.parts), 16, "M113 did not assemble its powerpack, battery, lighting, cameras and tracks.")
	vehicle.set_ignition(TRUE)
	TEST_ASSERT(vehicle.start_engine(), "M113 engine failed to start.")
	TEST_ASSERT(istype(vehicle.gearbox, /obj/structure/ms13_vehicle_part/gearbox/m113), "M113 did not receive its transmission.")
	TEST_ASSERT(istype(vehicle.fuel_tank, /obj/structure/ms13_vehicle_part/fuel_tank/m113), "M113 did not receive its fuel cell.")
	TEST_ASSERT(vehicle.gearbox.density && vehicle.fuel_tank.density && vehicle.engine.density, "M113 powerpack or fuel cell could be walked through.")
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
	TEST_ASSERT_EQUAL(seat_count, 6, "M113 did not assemble its driver, commander and four troop seats.")

	// Fully enclosed: every tile shows only cabin light until the ramp opens.
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		TEST_ASSERT(vehicle.is_light_sealed(frame), "M113 tile [frame.forward_offset],[frame.right_offset] let outside light in.")
	var/list/lit_colors = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		lit_colors[frame] = frame.interior_light.color
	for(var/obj/structure/ms13_vehicle_part/interior_light/fixture in vehicle.parts)
		fixture.on = FALSE
	vehicle.update_interior_lighting()
	var/darker = FALSE
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		if(frame.interior_light.color != lit_colors[frame])
			darker = TRUE
	TEST_ASSERT(darker, "Switching off the cabin lights did not change the cabin lighting.")
	var/obj/structure/window/ms13_vehicle_wall/solid/door/m113/ramp_door
	for(var/obj/structure/window/ms13_vehicle_wall/solid/door/m113/candidate in vehicle.walls)
		ramp_door = candidate
	ramp_door.open()
	TEST_ASSERT(!vehicle.is_light_sealed(ramp_door.parent_frame), "Lowering the ramp did not let daylight onto the ramp tile.")
	ramp_door.close()

	// Vision ports only let you see out with your face to them.
	var/obj/structure/window/ms13_vehicle_wall/m113/port
	var/obj/structure/ms13_vehicle_frame/rear_centre
	for(var/obj/structure/window/ms13_vehicle_wall/m113/candidate in vehicle.walls)
		if(candidate.parent_frame.right_offset == 1)
			port = candidate
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		if(frame.forward_offset == -3 && frame.right_offset == 1)
			rear_centre = frame
	var/turf/beyond_port = get_step(port, port.dir)
	TEST_ASSERT(!vehicle.blocks_sight_from(get_turf(port.parent_frame), beyond_port), "A vision port blocked sight for someone standing at it.")
	TEST_ASSERT(vehicle.blocks_sight_from(get_turf(rear_centre), beyond_port), "A vision port let someone at the back of the cabin see out.")

	// Holing a hull panel strips most of its armor and opens it up, without destroying it.
	var/obj/structure/window/ms13_vehicle_wall/solid/m113/side_panel
	for(var/obj/structure/window/ms13_vehicle_wall/solid/m113/candidate in vehicle.walls)
		if(candidate.parent_frame.forward_offset == -1)
			side_panel = candidate
			break
	var/datum/armor/panel_armor = side_panel.returnArmor()
	var/intact_puncture = panel_armor.getRating(PUNCTURE)
	side_panel.update_integrity(side_panel.max_integrity * 0.2)
	TEST_ASSERT(!QDELETED(side_panel) && side_panel.hull_broken, "A badly damaged hull panel did not break.")
	panel_armor = side_panel.returnArmor()
	TEST_ASSERT(panel_armor.getRating(PUNCTURE) < intact_puncture * 0.5, "A broken hull panel kept most of its armor.")
	TEST_ASSERT(!side_panel.blocks_sight(), "A holed hull panel still blocked sight.")
	TEST_ASSERT(!vehicle.is_light_sealed(side_panel.parent_frame), "A holed hull panel still kept daylight out.")
	side_panel.repair_damage(side_panel.max_integrity)
	TEST_ASSERT(!side_panel.hull_broken, "Repairing a hull panel did not close it up.")
	panel_armor = side_panel.returnArmor()
	TEST_ASSERT_EQUAL(panel_armor.getRating(PUNCTURE), intact_puncture, "A repaired hull panel did not get its armor back.")

	// A worn transmission loses top gear; a wrecked one stops the carrier.
	TEST_ASSERT_EQUAL(vehicle.gear_count(), 3, "M113 transmission did not provide three gears.")
	vehicle.gearbox.take_damage(vehicle.gearbox.max_integrity * 0.5, BRUTE, BOMB, FALSE)
	TEST_ASSERT_EQUAL(vehicle.gear_count(), 2, "A worn transmission kept its top gear.")
	vehicle.gearbox.repair_damage(vehicle.gearbox.max_integrity)

	var/obj/structure/window/ms13_vehicle_wall/solid/m113/damage_test_wall
	for(var/obj/structure/window/ms13_vehicle_wall/solid/m113/candidate in vehicle.walls)
		damage_test_wall = candidate
		break
	damage_test_wall.take_damage(10, BRUTE, BOMB, FALSE)
	TEST_ASSERT_EQUAL(damage_test_wall.parent_frame.roof.color, "#8f7676", "Damaging M113 hull did not apply its fallback damaged-roof appearance.")

	track_to_break.take_damage(track_to_break.max_integrity, BRUTE, BOMB, FALSE)
	TEST_ASSERT(!vehicle.has_motive_power(), "M113 still had motive power after losing one of its four required track units.")

/// Steering while moving drifts first and only turns on a second press the same way.
/datum/unit_test/ms13_ground_vehicle_drift
	name = "VEHICLES: Steering Drifts Before It Turns"

/datum/unit_test/ms13_ground_vehicle_drift/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	var/datum/ms13_ground_vehicle/jeep/vehicle = front.vehicle
	var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent)
	driver.forceMove(get_turf(front))
	for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(front))
		if(seat.is_driver_seat)
			seat.user_buckle_mob(driver, driver)
	TEST_ASSERT_EQUAL(vehicle.driver, driver, "No driver for the drift test.")

	var/facing = vehicle.dir
	var/right = turn(facing, -90)
	vehicle.speed = 1
	vehicle.travel_dir = facing
	vehicle.apply_steering(right)
	TEST_ASSERT_EQUAL(vehicle.drift, 1, "Steering right while moving did not start a drift.")
	TEST_ASSERT_EQUAL(vehicle.dir, facing, "The first steering press turned the chassis.")
	vehicle.next_steer_time = 0
	vehicle.apply_steering(turn(facing, 90))
	TEST_ASSERT_EQUAL(vehicle.drift, 0, "Steering the other way did not straighten out.")

	// Drifting sidesteps as the vehicle drives forward.
	vehicle.next_steer_time = 0
	vehicle.apply_steering(right)
	vehicle.drift_interval = 1
	vehicle.moving = TRUE
	vehicle.movement_generation++
	var/turf/expected = get_step(get_step(front, facing), right)
	vehicle.movement_tick(vehicle.movement_generation)
	TEST_ASSERT_EQUAL(get_turf(front), expected, "A drifting vehicle did not sidestep while driving.")
	TEST_ASSERT_EQUAL(vehicle.dir, facing, "Drifting turned the chassis.")
	vehicle.stop_motion()

	// A second press the same way commits to the full turn.
	vehicle.speed = 1
	vehicle.travel_dir = facing
	vehicle.drift = 1
	vehicle.next_steer_time = 0
	vehicle.next_move_time = 0
	vehicle.apply_steering(right)
	TEST_ASSERT_EQUAL(vehicle.dir, right, "Steering the same way twice did not turn the vehicle.")
	TEST_ASSERT_EQUAL(vehicle.drift, 0, "The drift was not cleared by a full turn.")
	vehicle.stop_motion()

/// What a vehicle drives over stays on the ground under it, and a blast from below has to get through the floor.
/datum/unit_test/ms13_vehicle_underside
	name = "VEHICLES: The Floor Separates The Cabin From The Ground"

/datum/unit_test/ms13_vehicle_underside/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	var/datum/ms13_ground_vehicle/vehicle = front.vehicle
	var/obj/structure/ms13_vehicle_frame/back
	for(var/obj/structure/ms13_vehicle_frame/candidate as anything in vehicle.frames)
		if(candidate != front)
			back = candidate

	var/turf/ahead = get_step(front, EAST)
	var/obj/item/wrench/debris = allocate(/obj/item/wrench)
	debris.forceMove(ahead)
	var/obj/item/crowbar/cargo = allocate(/obj/item/crowbar)
	cargo.forceMove(get_turf(front))
	TEST_ASSERT(vehicle.do_move(EAST, TRUE), "The jeep couldn't drive over a dropped wrench.")
	TEST_ASSERT_EQUAL(debris.invisibility, INVISIBILITY_ABSTRACT, "A wrench the jeep drove onto showed up in the cabin.")
	TEST_ASSERT_EQUAL(get_turf(cargo), get_turf(front), "Cargo in the cabin was left behind.")
	TEST_ASSERT(vehicle.do_move(EAST, TRUE), "The jeep couldn't drive on.")
	TEST_ASSERT_EQUAL(get_turf(debris), ahead, "The jeep carried off a wrench it drove over.")
	TEST_ASSERT_EQUAL(debris.invisibility, 0, "A wrench stayed hidden after the jeep drove off it.")

	// A mine the floor is far too thick for: it goes off under the jeep, but nobody inside is hurt.
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	rider.forceMove(get_turf(front))
	front.explosion_block = 10
	var/obj/effect/mine/ms13/explosive/mine = new(get_step(front, WEST))
	mine.armed = TRUE
	TEST_ASSERT(vehicle.do_move(WEST, TRUE), "The jeep couldn't drive back.")
	UNTIL(!SSexplosions.is_exploding())
	TEST_ASSERT(QDELETED(mine), "Driving over an armed mine didn't set it off.")
	TEST_ASSERT_EQUAL(rider.getorganslot(ORGAN_SLOT_LUNGS)?.damage, 0, "A mine hurt a rider through a floor far thicker than its blast.")

	// A grenade going off in the cabin has no floor in the way.
	var/mob/living/carbon/human/consistent/passenger = allocate(/mob/living/carbon/human/consistent)
	passenger.forceMove(get_turf(back))
	var/obj/item/crowbar/bomb = allocate(/obj/item/crowbar)
	bomb.forceMove(get_turf(back))
	TEST_ASSERT_EQUAL(ms13_exploding_cabin(bomb), vehicle, "Something lying in the cabin didn't count as inside it.")
	explosion(bomb, 0, 1, 2)
	UNTIL(!SSexplosions.is_exploding())
	TEST_ASSERT(passenger.getorganslot(ORGAN_SLOT_LUNGS)?.damage > 0, "A blast inside the cabin was blocked by the floor.")
