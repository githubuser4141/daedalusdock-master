#ifdef UNIT_TESTS
/datum/unit_test/ms13_rail_vehicles/Run()
	var/test_z = run_loc_floor_bottom_left.z
	for(var/turf/ground in block(locate(10, 10, test_z), locate(55, 55, test_z)))
		ground.ChangeTurf(/turf/open/floor/plating)
		for(var/obj/obstacle in ground)
			qdel(obstacle)
	var/list/base_impact = measure_impact(500, 1, 20, test_z)
	var/list/heavy_impact = measure_impact(1000, 1, 20, test_z)
	var/list/fast_impact = measure_impact(500, 2, 20, test_z)
	var/list/armored_impact = measure_impact(500, 1, 80, test_z)
	if(abs(heavy_impact[1] - 2 * base_impact[1]) > 0.1 || abs(fast_impact[1] - 4 * base_impact[1]) > 0.1)
		Fail("Collision damage did not scale linearly with mass and quadratically with speed.")
	if(armored_impact[1] <= base_impact[1] || armored_impact[2] >= base_impact[2])
		Fail("Contact armor did not improve damage delivery and reduce self-damage.")
	check_mounts(test_z)
	// Shoving moves the whole struck vehicle, including loose cargo. A blocked shove cannot recurse.
	var/obj/structure/ms13_vehicle_frame/jeep_front/rammer = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, locate(20, 20, test_z))
	var/obj/structure/ms13_vehicle_frame/jeep_front/victim = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, locate(20, 18, test_z))
	var/obj/item/cargo = allocate(/obj/item, get_turf(victim))
	rammer.vehicle.speed = 2
	if(!rammer.vehicle.do_move(SOUTH, TRUE) || victim.y != 17 || cargo.y != 17 || rammer.y != 19)
		Fail("Vehicle collision failed to shove an intact formation and its cargo.")
	var/obj/structure/blocker = allocate(/obj/structure, locate(20, 16, test_z))
	blocker.density = TRUE
	if(rammer.vehicle.try_shove_vehicle(victim.vehicle, SOUTH) || victim.y != 17)
		Fail("Vehicle shoved through a blocked destination.")
	qdel(blocker)
	victim.vehicle.mass_per_frame = 100000
	if(rammer.vehicle.try_shove_vehicle(victim.vehicle, SOUTH))
		Fail("A light vehicle shoved an excessively heavy vehicle.")
	clear_vehicle(rammer.vehicle)
	clear_vehicle(victim.vehicle)
	check_corridors(test_z)
	// Side plating still takes the impact when an in-path obstacle hits a missing front panel.
	rammer = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, locate(20, 20, test_z))
	for(var/obj/structure/window/ms13_vehicle_wall/panel as anything in rammer.vehicle.walls.Copy())
		if(panel.dir == SOUTH)
			qdel(panel)
	var/turf/house_wall = locate(20, 19, test_z)
	house_wall = house_wall.ChangeTurf(/turf/closed/wall)
	if(rammer.vehicle.can_move(SOUTH))
		Fail("Vehicle ignored an in-path house wall.")
	var/integrity_before = house_wall.get_integrity()
	var/frame_before = rammer.get_integrity()
	rammer.vehicle.speed = 1
	rammer.vehicle.ram_obstacles(SOUTH, rammer.vehicle.get_manifest())
	if(house_wall.get_integrity() >= integrity_before)
		Fail("Side hull collision did not damage the house wall.")
	if(rammer.get_integrity() != frame_before)
		Fail("Missing front plating bypassed the remaining side armor.")
	house_wall.ChangeTurf(/turf/open/floor/plating)
	var/obj/structure/table/ms13/low_wall/brick/low_wall = allocate(/obj/structure/table/ms13/low_wall/brick, locate(20, 19, test_z))
	var/obj/structure/window/fulltile/ms13/glass/window = allocate(/obj/structure/window/fulltile/ms13/glass, get_turf(low_wall))
	var/low_before = low_wall.get_integrity()
	var/window_before = window.get_integrity()
	rammer.vehicle.stop_motion()
	rammer.vehicle.speed = 1
	rammer.vehicle.do_move(SOUTH, TRUE)
	if(!QDELETED(low_wall) && low_wall.get_integrity() >= low_before)
		Fail("Vehicle failed to damage an in-path low wall.")
	if(!QDELETED(window) && window.get_integrity() >= window_before)
		Fail("Vehicle failed to damage a window stacked on a low wall.")
	if(!QDELETED(low_wall) && low_wall.density && rammer.y != 20)
		Fail("Vehicle clipped through a surviving low wall.")
	qdel(low_wall)
	qdel(window)
	clear_vehicle(rammer.vehicle)
	// A real loop of guide rails, with room for the rigid car to sweep around its pivot.
	var/list/route = list()
	for(var/x in 26 to 35)
		route += locate(x, 35, test_z)
	for(var/y = 34, y >= 25, y--)
		route += locate(35, y, test_z)
	for(var/x = 34, x >= 25, x--)
		route += locate(x, 25, test_z)
	for(var/y in 26 to 35)
		route += locate(25, y, test_z)
	route += locate(26, 35, test_z)
	for(var/turf/rail_tile as anything in route)
		if(!(locate(/obj/structure/ms13_rail) in rail_tile))
			allocate(/obj/structure/ms13_rail, rail_tile)
	var/obj/structure/ms13_vehicle_frame/tram/tram = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(25, 35, test_z))
	var/datum/ms13_ground_vehicle/rail/train = tram.vehicle
	if(length(train.frames) != tram.car_length * tram.car_width)
		Fail("Tram footprint does not match its car size.")
	var/obj/structure/chair/ms13_vehicle_seat/driver_seat = locate() in get_turf(tram)
	var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent, get_turf(tram))
	driver_seat.user_buckle_mob(driver, driver)
	for(var/direction in GLOB.cardinals)
		driver_seat.setDir(direction)
		if(driver_seat.layer >= MOB_LAYER)
			Fail("Driver's seat was drawn over its driver.")
		for(var/mutable_appearance/monitor as anything in driver_seat.update_overlays())
			if(monitor.layer >= MOB_LAYER)
				Fail("Dashboard overlay was drawn over its driver.")
	driver_seat.setDir(train.dir)
	cargo = allocate(/obj/item, get_turf(tram))
	var/list/parents = train.find_rail_routes()
	if(!parents[locate(35, 25, test_z)] || length(parents) != 40)
		Fail("Rail search did not find the complete connected loop.")
	train.set_ignition(TRUE)
	train.start_engine()
	var/fuel_before = train.fuel_tank.reagents.total_volume
	train.rail_route = route.Copy()
	train.moving = TRUE
	train.speed = 3
	var/list/headings = list()
	for(var/tick in 1 to 90)
		train.next_move_time = 0
		train.next_acceleration_time = 0
		train.movement_tick(train.movement_generation)
		headings |= train.dir
		if(!train.moving)
			break
	if(train.moving || train.speed || get_turf(tram) != locate(26, 35, test_z) || cargo.loc != tram.loc || length(headings) != 4 || driver.buckled != driver_seat || driver.loc != tram.loc)
		Fail("Autopilot failed a full E/S/W/N/E loop, cargo transport, or its final stop.")
	if(train.fuel_tank.reagents.total_volume >= fuel_before)
		Fail("Rail movement did not consume normal vehicle fuel.")
	if(train.handle_drive_input(train.dir) || train.moving)
		Fail("Train accepted manual driving.")
	// A stop behind the car is reached tail-first, not by turning the car round.
	var/heading = train.dir
	var/obj/structure/ms13_vehicle_frame/bogie = train.rail_frame()
	var/turf/behind = get_step(bogie, turn(heading, 180))
	train.rail_route = list(behind)
	train.moving = TRUE
	train.speed = 1
	for(var/tick in 1 to 5)
		train.next_move_time = 0
		train.movement_tick(train.movement_generation)
		if(!train.moving)
			break
	if(train.dir != heading || get_turf(bogie) != behind)
		Fail("Train turned round instead of backing up.")
	train.stop_motion()
	if(train.do_move(NORTH, TRUE))
		Fail("Train drove off its guide rail.")
	var/obj/structure/ms13_rail/removed = locate() in get_step(tram, EAST)
	qdel(removed)
	if(train.do_move(EAST, TRUE))
		Fail("Train ignored destroyed rails.")
	clear_vehicle(train)
	// Someone standing on the ground it is being built over rides in it rather than blocking the build.
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, locate(40, 40, test_z))
	var/obj/structure/ms13_vehicle_frame/tram/train/large = allocate(/obj/structure/ms13_vehicle_frame/tram/train, locate(40, 40, test_z))
	if(QDELETED(large) || !large.vehicle)
		Fail("A train refused to assemble around a bystander.")
	if(length(large.vehicle.frames) != 18)
		Fail("Train is not 3x6.")
	if(bystander.loc != get_turf(large))
		Fail("Assembling a train moved a bystander.")
	clear_vehicle(large.vehicle)
	qdel(bystander)
	// The guide rail can run under the middle of a car, not just under its front-left corner.
	var/obj/structure/ms13_vehicle_frame/tram/offset_car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(41, 51, test_z))
	var/datum/ms13_ground_vehicle/rail/offset_vehicle = offset_car.vehicle
	var/obj/structure/ms13_vehicle_frame/middle
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in offset_vehicle.frames)
		if(frame.forward_offset == -FLOOR((offset_car.car_length - 1) / 2, 1) && frame.right_offset == 1)
			middle = frame
	for(var/travelled in -1 to 3)
		var/turf/rail_tile = locate(middle.x, middle.y - travelled, test_z)
		if(!ms13_rail_at(rail_tile))
			allocate(/obj/structure/ms13_rail, rail_tile)
	if(offset_vehicle.rail_frame() != middle)
		Fail("The car did not ride the rail line running under its middle.")
	if(!length(offset_vehicle.find_rail_routes()))
		Fail("A car riding the line off its pivot found no route along it.")
	if(!offset_vehicle.do_move(offset_vehicle.dir, TRUE))
		Fail("A car riding the line off its pivot refused to follow it.")
	if(offset_vehicle.do_move(turn(offset_vehicle.dir, 90), TRUE))
		Fail("A car drove off the rail line sideways.")
	clear_vehicle(offset_vehicle)
	check_route_terminal(test_z)
	check_smooth_running(test_z)
	check_equipment(test_z)
	check_crossings()
	check_electric()
	check_service()

/// A line down x with stops at y = 12, 27 and 40, on a fresh level.
/datum/unit_test/ms13_rail_vehicles/proc/lay_service_line(x, z)
	for(var/y in 12 to 40)
		allocate((y in list(12, 27, 40)) ? /obj/structure/ms13_rail/station : /obj/structure/ms13_rail, locate(x, y, z))

/// Automatic service calls at every stop in turn; a call button brings an idle car; a car on service catching up with a
/// standing one gets it to move on and waits for it; and a car at top speed coasts.
/datum/unit_test/ms13_rail_vehicles/proc/check_service()
	var/datum/space_level/level = SSmapping.add_new_zlevel("Rail service test", list())
	var/z = level.z_value
	for(var/turf/ground in block(locate(10, 5, z), locate(45, 50, z)))
		ground.ChangeTurf(/turf/open/floor/plating)
	lay_service_line(20, z)
	var/turf/south = locate(20, 12, z)
	var/turf/middle = locate(20, 27, z)
	var/turf/north = locate(20, 40, z)
	// Standing with its bogie at y = 33: the middle stop is nearest, then the north one, then the south one.
	var/obj/structure/ms13_vehicle_frame/tram/car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(20, 31, z))
	var/datum/ms13_ground_vehicle/rail/line = car.vehicle
	var/list/doors = line.power_doors()
	var/obj/structure/window/ms13_vehicle_wall/solid/door/door = doors[1]
	line.set_automated(TRUE)
	var/list/called = list()
	for(var/leg in 1 to 4)
		line.run_next_leg()
		if(!line.pending_destination)
			Fail("A car on service did not warn before setting off.")
			break
		line.finish_departure()
		if(door.opened)
			Fail("A car on service set off with its doors open.")
		var/turf/stop = get_turf(line.service_stop)
		if(!run_to_stand(line, stop))
			Fail("A car on service did not reach its stop.")
			break
		called += "[stop.y]"
		if(!door.opened || !line.service_timer)
			Fail("A car on service did not open its doors and wait at the stop.")
	if(jointext(called, ",") != "[middle.y],[north.y],[south.y],[middle.y]")
		Fail("A car on service called at [jointext(called, ",")], not the nearest stop it hadn't each time, then over again.")
	line.set_automated(FALSE)
	// A call button by the north stop brings the idle car there.
	var/obj/structure/ms13_rail_call_button/button = allocate(/obj/structure/ms13_rail_call_button, locate(22, 40, z))
	var/mob/living/carbon/human/consistent/passenger = allocate(/mob/living/carbon/human/consistent, locate(23, 40, z))
	button.attack_hand(passenger)
	if(line.pending_destination != north)
		Fail("A call button did not call the idle car to its stop.")
	line.finish_departure()
	if(!run_to_stand(line, north))
		Fail("A called car did not come to the stop.")
	// At top speed the drive stops pulling and the car coasts, then pulls again once it has slowed.
	line.speed_multiplier = 1
	line.depart_for(south)
	var/top = line.gear_velocity(line.gear_count())
	line.velocity = top
	line.next_move_time = 0
	line.movement_tick(line.movement_generation)
	if(line.thrusting)
		Fail("A car at top speed kept pulling instead of coasting.")
	var/coasting = line.velocity
	line.next_move_time = 0
	line.movement_tick(line.movement_generation)
	if(line.velocity >= coasting)
		Fail("A coasting car did not slow.")
	line.velocity = top * 0.8
	line.next_move_time = 0
	line.movement_tick(line.movement_generation)
	if(!line.thrusting)
		Fail("A car well below top speed did not pull again.")
	clear_vehicle(line)

	// Two cars on one line: one standing at the middle stop, one on service coming from the north.
	lay_service_line(35, z)
	var/turf/second_middle = locate(35, 27, z)
	var/obj/structure/ms13_vehicle_frame/tram/standing_car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(35, 25, z))
	var/obj/structure/ms13_vehicle_frame/tram/service_car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(35, 38, z))
	var/datum/ms13_ground_vehicle/rail/standing = standing_car.vehicle
	var/datum/ms13_ground_vehicle/rail/service = service_car.vehicle
	service.set_automated(TRUE)
	service.run_next_leg()
	service.finish_departure()
	var/asked = FALSE
	for(var/tick in 1 to 200)
		if(standing.pending_destination)
			asked = TRUE
			standing.finish_departure()
		if(service.moving)
			service.next_move_time = 0
			service.movement_tick(service.movement_generation)
		if(standing.moving)
			standing.next_move_time = 0
			standing.movement_tick(standing.movement_generation)
		if(!service.moving)
			break
	if(!asked)
		Fail("A car on service did not ask a standing car ahead to move on.")
	if(service.moving || get_turf(service.rail_frame()) != second_middle)
		Fail("A car on service gave up behind a car that moved on, instead of reaching its stop.")
	if(get_turf(standing.rail_frame()) == second_middle || service.held_up)
		Fail("The standing car did not move on, or the car behind is still holding.")
	service.set_automated(FALSE)
	clear_vehicle(service)
	clear_vehicle(standing)

	// A train riding the line under its middle takes a T junction's corner when its front gets there, landing on the new
	// line: walls past the corner and beside the junction, where swinging about its middle would take it, don't stop it.
	for(var/y in 38 to 49)
		allocate(/obj/structure/ms13_rail, locate(29, y, z))
	for(var/x in 24 to 32)
		allocate(/obj/structure/ms13_rail, locate(x, 38, z))
	for(var/turf/beside as anything in list(locate(29, 36, z), locate(28, 35, z), locate(32, 40, z), locate(31, 36, z)))
		var/obj/structure/wall_stand_in = allocate(/obj/structure, beside)
		wall_stand_in.density = TRUE
	var/obj/structure/ms13_vehicle_frame/tram/train/long_car = allocate(/obj/structure/ms13_vehicle_frame/tram/train, locate(30, 44, z))
	var/datum/ms13_ground_vehicle/rail/turner = long_car.vehicle
	var/turf/corner_end = locate(24, 38, z)
	turner.depart_for(corner_end)
	if(!run_to_stand(turner, corner_end) || turner.dir != WEST)
		Fail("A train riding the line under its middle came off it, or stuck, at a T junction's corner.")
	clear_vehicle(turner)

/// Runs line to stop, one tile at a time. TRUE if it came to a stand on the stop.
/datum/unit_test/ms13_rail_vehicles/proc/run_to_stand(datum/ms13_ground_vehicle/rail/line, turf/stop)
	for(var/tick in 1 to 120)
		if(!line.moving)
			break
		line.next_move_time = 0
		line.movement_tick(line.movement_generation)
	return !line.moving && get_turf(line.rail_frame()) == stop

/// An electric car runs off a rail feeder's powernet and brakes to a stop when the power goes. A blast door slides
/// open and shut along its own hidden rail at the press of a door button, shoving whoever is in its way.
/datum/unit_test/ms13_rail_vehicles/proc/check_electric()
	var/datum/space_level/level = SSmapping.add_new_zlevel("Electric rail test", list())
	var/z = level.z_value
	for(var/turf/ground in block(locate(10, 10, z), locate(45, 45, z)))
		ground.ChangeTurf(/turf/open/floor/plating)
	for(var/y in 13 to 40)
		allocate(/obj/structure/ms13_rail, locate(20, y, z))
	var/turf/stop = locate(20, 12, z)
	allocate(/obj/structure/ms13_rail/station, stop)
	var/obj/machinery/power/ms13_rail_feeder/feeder = allocate(/obj/machinery/power/ms13_rail_feeder, locate(20, 40, z))
	var/datum/powernet/net = new
	net.add_machine(feeder)
	var/obj/structure/ms13_vehicle_frame/tram/electric/car = allocate(/obj/structure/ms13_vehicle_frame/tram/electric, locate(20, 38, z))
	var/datum/ms13_ground_vehicle/rail/electric/line = car.vehicle
	if(line.engine || line.battery || line.fuel_tank || !istype(line.gearbox, /obj/structure/ms13_vehicle_part/gearbox/traction) || line.gear_count() != 1)
		Fail("An electric car came with an engine, battery or tank, or more than one speed.")
	if(!(feeder in line.feeders))
		Fail("An electric car didn't find the feeder on its line.")
	if(line.depart_for(stop))
		Fail("An electric car set off on a dead line.")
	// The line going live switches the car on by itself: ignition, lights and motor. Going dead, it goes dark.
	line.ignition = FALSE
	line.engine_running = FALSE
	line.exterior_lights_on = FALSE
	net.newavail = 1000000
	net.reset()
	if(!line.ignition || !line.engine_running || !line.exterior_lights_on || !line.has_electrical_power())
		Fail("An electric car did not switch itself on when its line went live.")
	net.load = net.avail
	if(!line.has_standby_power() || !line.has_electrical_power())
		Fail("An electric car went dark on a live line with no power to spare.")
	net.load = 0
	net.newavail = 0
	net.reset()
	if(line.has_electrical_power())
		Fail("An electric car kept its power when its line went dead.")
	net.avail = 1000000
	if(!line.depart_for(stop))
		Fail("An electric car would not set off on a live line.")
		clear_vehicle(line)
		return
	line.movement_tick(line.movement_generation)
	if(net.load < line.traction_draw)
		Fail("An electric car moved without drawing its load from the line.")
	if(!run_to_stand(line, stop))
		Fail("An electric car did not run to its stop on a live line.")
	// Heading back, the power goes: it brakes to a stop short of where it was going.
	var/turf/start = locate(20, 38, z)
	line.depart_for(start)
	for(var/tick in 1 to 6)
		line.next_move_time = 0
		line.movement_tick(line.movement_generation)
	net.avail = 0
	net.load = 0
	line.power_cycle = -1
	if(run_to_stand(line, start) || line.moving)
		Fail("An electric car kept going to its stop after the power went.")
	clear_vehicle(line)

	// A blast door, shut across x = 31, y = 30 to 32, slides north until its middle stands at y = 34.
	for(var/y in 31 to 34)
		allocate(/obj/structure/ms13_rail/hidden, locate(31, y, z))
	var/obj/machinery/power/ms13_rail_feeder/door_feeder = allocate(/obj/machinery/power/ms13_rail_feeder, locate(31, 34, z))
	net.add_machine(door_feeder)
	net.avail = 1000000
	var/obj/structure/ms13_vehicle_frame/tram/blast_door/door = allocate(/obj/structure/ms13_vehicle_frame/tram/blast_door, locate(31, 30, z))
	door.id = "ms13_test_blast_door"
	var/datum/ms13_ground_vehicle/rail/electric/blast_door/drive = door.vehicle
	if(length(drive.frames) != 3 || length(drive.walls) || length(drive.parts) != 1 || drive.battery)
		Fail("The blast door isn't just three frames and its motor.")
	for(var/obj/structure/ms13_vehicle_frame/slab as anything in drive.frames)
		if(!slab.density)
			Fail("A blast door frame can be walked through.")
	var/turf/shut = get_turf(drive.rail_frame())
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, locate(31, 33, z))
	var/obj/item/assembly/control/button = allocate(/obj/item/assembly/control, locate(35, 30, z))
	button.id = door.id
	button.activate()
	if(!run_to_stand(drive, locate(31, 34, z)))
		Fail("A door button did not slide the blast door open to the far end of its rail.")
	if(drive.get_frame_at(get_turf(bystander)) || bystander.stat == DEAD)
		Fail("The blast door did not shove a bystander out of its way.")
	door.toggle()
	if(!run_to_stand(drive, shut))
		Fail("The blast door did not slide shut again.")
	clear_vehicle(drive)

	// Frames blown off a running car, its pivot and the one on the rail among them, aren't held by the wreck left.
	var/obj/structure/ms13_vehicle_frame/tram/train/electric/train = new(locate(20, 38, z))
	var/datum/ms13_ground_vehicle/rail/electric/wreck = train.vehicle
	wreck.depart_for(stop)
	for(var/tick in 1 to 3)
		wreck.next_move_time = 0
		wreck.movement_tick(wreck.movement_generation)
	var/obj/structure/ms13_vehicle_frame/bogie = wreck.rail_frame()
	qdel(bogie)
	qdel(train)
	// Only this proc's own variable and the garbage queue should still hold them.
	if(refcount(bogie) > 2 || refcount(train) > 2)
		Fail("A wreck held on to its destroyed frames: [refcount(bogie) - 2] refs to the bogie, [refcount(train) - 2] to the pivot.")
	clear_vehicle(wreck)

/// Power doors the driver works, latches worked by hand from inside only, a battery bank, a welding torch that burns
/// the battery and winds back past its hose, and a smoke generator that burns fuel into a screen outside.
/datum/unit_test/ms13_rail_vehicles/proc/check_equipment(test_z)
	var/obj/structure/ms13_vehicle_frame/tram/car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(48, 30, test_z))
	var/datum/ms13_ground_vehicle/rail/line = car.vehicle
	if(!istype(line.battery?.cell, /obj/item/stock_parts/cell/ms13_vehicle/storage))
		Fail("A rail car was not built with a storage battery bank.")
	var/list/doors = line.power_doors()
	if(length(doors) != 2)
		Fail("A rail car does not have its two power doors.")
		clear_vehicle(line)
		return
	line.set_ignition(TRUE)
	var/obj/structure/window/ms13_vehicle_wall/solid/door/door = doors[1]
	var/mob/living/carbon/human/consistent/outsider = allocate(/mob/living/carbon/human/consistent, get_step(door, door.dir))
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent, get_turf(door))
	line.work_power_doors("lock")
	door.attack_hand(outsider)
	if(door.opened || !door.locked)
		Fail("A locked power door opened by hand.")
	door.attack_hand_secondary(outsider)
	if(!door.locked)
		Fail("A door was unlocked from outside the vehicle.")
	door.attack_hand_secondary(rider)
	if(door.locked)
		Fail("Right-clicking a door from inside did not unlock it.")
	line.work_power_doors("open")
	for(var/obj/structure/window/ms13_vehicle_wall/solid/door/power_door as anything in doors)
		if(!power_door.opened || power_door.locked)
			Fail("The driver's controls did not open every power door.")
	line.set_ignition(FALSE)
	if(line.work_power_doors("close") || !door.opened)
		Fail("The power doors worked with the ignition off.")
	line.set_ignition(TRUE)
	// Breaking a locked power door throws it open, and it stays jammed open until repaired.
	line.work_power_doors("lock")
	door.update_integrity(door.max_integrity * 0.2)
	if(!door.hull_broken || !door.opened || door.locked)
		Fail("A broken power door did not spring open, unlocked.")
	line.work_power_doors("close")
	if(!door.opened)
		Fail("A broken power door closed.")
	door.update_integrity(door.max_integrity)
	door.atom_fix()
	line.work_power_doors("close")
	if(door.opened)
		Fail("A repaired power door would not close.")
	var/obj/structure/ms13_vehicle_part/welding_rig/rig = allocate(/obj/structure/ms13_vehicle_part/welding_rig, get_turf(car))
	if(rig.vehicle != line || !(rig in line.parts))
		Fail("A welding set placed in a car did not fit itself to it.")
	var/mob/living/carbon/human/consistent/welder = allocate(/mob/living/carbon/human/consistent, get_turf(car))
	rig.attack_hand(welder)
	var/obj/item/weldingtool/ms13/vehicle/torch = rig.torch
	if(!welder.is_holding(torch) || !torch.get_fuel())
		Fail("Taking the welding torch did not put a battery-fed torch in hand.")
	torch.switched_on(welder)
	var/charge = line.battery.cell.charge
	if(!torch.use(2) || line.battery.cell.charge != charge - 2 * torch.charge_per_fuel)
		Fail("The welding torch did not burn the battery's charge.")
	welder.forceMove(locate(car.x + rig.hose_length + 2, car.y, test_z))
	if(torch.loc != rig || torch.welding)
		Fail("The welding torch was carried past its hose's reach.")
	var/obj/structure/ms13_vehicle_part/smoke_generator/smoke = allocate(/obj/structure/ms13_vehicle_part/smoke_generator, get_turf(car))
	line.start_engine()
	var/fuel = line.fuel_tank.reagents.total_volume
	if(!smoke.discharge() || line.fuel_tank.reagents.total_volume > fuel - smoke.fuel_cost || !(locate(/obj/effect/particle_effect/fluid/smoke) in get_step(smoke, smoke.dir)))
		Fail("The smoke generator did not burn fuel into a screen outside the hull.")
	if(smoke.discharge())
		Fail("The smoke generator laid a second screen straight away.")
	clear_vehicle(line)

/// Sends the car to stop and runs it there. TRUE if it came to a stand on the stop.
/datum/unit_test/ms13_rail_vehicles/proc/run_line(datum/ms13_ground_vehicle/rail/line, obj/structure/ms13_rail/stop)
	if(!line.depart_for(get_turf(stop)))
		return FALSE
	for(var/tick in 1 to 120)
		if(!line.moving)
			break
		line.next_move_time = 0
		line.movement_tick(line.movement_generation)
	return !line.moving && get_turf(line.rail_frame()) == get_turf(stop)

/// A line up an incline to the level above, and one over a region's edge: the car runs each both ways, whole and
/// with its load, and a blocked far end keeps it where it is.
/datum/unit_test/ms13_rail_vehicles/proc/check_crossings()
	var/datum/space_level/lower_level = SSmapping.add_new_zlevel("Rail incline lower", list(ZTRAIT_UP = 1))
	var/datum/space_level/upper_level = SSmapping.add_new_zlevel("Rail incline upper", list(ZTRAIT_DOWN = -1))
	var/lower = lower_level.z_value
	var/upper = upper_level.z_value
	if(!GetAbove(locate(20, 20, lower)) || GetAbove(locate(20, 20, lower)) != locate(20, 20, upper))
		Fail("Could not stack two test levels.")
		return
	for(var/level in list(lower, upper))
		for(var/turf/ground in block(locate(15, 5, level), locate(45, 50, level)))
			ground.ChangeTurf(/turf/open/floor/plating)
	// The lower line climbs to y = 31, and the upper one runs on from y = 32.
	var/obj/structure/ms13_rail/low_stop = allocate(/obj/structure/ms13_rail/station, locate(20, 14, lower))
	for(var/y in 15 to 30)
		allocate(/obj/structure/ms13_rail, locate(20, y, lower))
	var/obj/structure/ms13_rail/ramp/incline = allocate(/obj/structure/ms13_rail/ramp, locate(20, 31, lower))
	incline.setDir(NORTH)
	incline = allocate(/obj/structure/ms13_rail/ramp, locate(20, 31, upper))
	incline.setDir(SOUTH)
	for(var/y in 32 to 43)
		allocate(/obj/structure/ms13_rail, locate(20, y, upper))
	var/obj/structure/ms13_rail/high_stop = allocate(/obj/structure/ms13_rail/station, locate(20, 44, upper))
	var/obj/structure/ms13_vehicle_frame/tram/car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(20, 20, lower))
	var/datum/ms13_ground_vehicle/rail/line = car.vehicle
	var/obj/item/cargo = allocate(/obj/item, get_turf(car))
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent, get_step(car, NORTH))
	var/obj/structure/blocker = allocate(/obj/structure, locate(20, 34, upper))
	blocker.density = TRUE
	run_line(line, high_stop)
	for(var/atom/movable/aboard as anything in line.get_all_parts() | line.get_manifest())
		if(aboard.z != lower)
			Fail("The car came out through something blocking the far end of the incline.")
			break
	qdel(blocker)
	if(!run_line(line, high_stop) || car.z != upper || cargo.z != upper || rider.z != upper || get_ms13_ground_vehicle_at(rider) != line)
		Fail("The car did not climb the incline to the upper stop with its passenger and cargo.")
	for(var/atom/movable/part as anything in line.get_all_parts())
		if(part.z != car.z)
			Fail("The car was split between levels.")
			break
	var/obj/structure/ms13_vehicle_part/rail_terminal/terminal = locate() in line.parts
	var/list/board = terminal.ui_static_data()
	var/list/below
	for(var/list/listed as anything in board["stops"])
		if(listed["ref"] == REF(low_stop))
			below = listed
	if(!below || below["level"] != -1 || below["x"] != low_stop.x || below["y"] != low_stop.y || length(board["links"]) != 1)
		Fail("The route board did not draw the lower line a level down, in place, joined at the incline.")
	if(!run_line(line, low_stop) || car.z != lower || cargo.z != lower || rider.z != lower)
		Fail("The car did not run back down the incline to the lower stop.")
	clear_vehicle(line)
	// Over a region's north edge: the lower line runs onto its crossing line and the region beyond picks up on its own.
	var/list/saved_links = SSmapping.ms13_surface_links
	var/list/saved_bounds = SSmapping.ms13_surface_bounds
	SSmapping.ms13_surface_links = list()
	SSmapping.ms13_surface_bounds = list(10, 10, 50, 50)
	SSmapping.ms13_link_surface_region(lower, upper, NORTH)
	var/obj/structure/ms13_rail/home = allocate(/obj/structure/ms13_rail/station, locate(40, 24, lower))
	for(var/y in 25 to 43)
		allocate(/obj/structure/ms13_rail, locate(40, y, lower))
	for(var/y in 17 to 29)
		allocate(/obj/structure/ms13_rail, locate(40, y, upper))
	var/obj/structure/ms13_rail/away = allocate(/obj/structure/ms13_rail/station, locate(40, 30, upper))
	car = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(40, 28, lower))
	line = car.vehicle
	terminal = locate() in line.parts
	board = terminal.ui_static_data()
	var/list/beyond
	for(var/list/listed as anything in board["stops"])
		if(listed["ref"] == REF(away))
			beyond = listed
	if(!beyond || beyond["level"] != 0 || beyond["x"] != 40 || beyond["y"] <= 43)
		Fail("The route board did not draw the region beyond straight on past its edge.")
	if(!run_line(line, away) || car.z != upper)
		Fail("The car did not cross the region's edge to the stop beyond.")
	if(!run_line(line, home) || car.z != lower)
		Fail("The car did not cross back over the region's edge.")
	clear_vehicle(line)
	SSmapping.ms13_surface_links = saved_links
	SSmapping.ms13_surface_bounds = saved_bounds

/// Boarding through the sides, a lit cabin, and a route terminal that lists stops by area and sends the car.
/datum/unit_test/ms13_rail_vehicles/proc/check_route_terminal(test_z)
	var/obj/structure/ms13_vehicle_frame/tram/commuter = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(15, 45, test_z))
	var/datum/ms13_ground_vehicle/rail/line = commuter.vehicle
	var/doors = 0
	for(var/obj/structure/window/ms13_vehicle_wall/solid/door/door in line.walls)
		if(!door.exterior)
			continue
		doors++
		if(door.dir == line.dir || door.dir == turn(line.dir, 180))
			Fail("A tram door opens off an end of the car.")
	var/seats = 0
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in line.frames)
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
			seats++
	var/lamps = 0
	for(var/obj/structure/ms13_vehicle_part/interior_light/lamp in line.parts)
		lamps++
	if(doors != 2 || seats >= length(line.frames) || lamps < 2)
		Fail("Tram lacks a door each side, fewer seats than tiles, or several cabin lamps.")
	for(var/y in 40 to 45)
		allocate(/obj/structure/ms13_rail, locate(15, y, test_z))
	var/obj/structure/ms13_rail/stop = allocate(/obj/structure/ms13_rail/station, locate(15, 40, test_z))
	var/obj/structure/ms13_vehicle_part/rail_terminal/terminal = locate() in line.parts
	// The front row is a cabin: the terminal can't be reached from the seats behind it.
	var/mob/living/carbon/human/consistent/passenger = allocate(/mob/living/carbon/human/consistent, get_step(terminal, turn(line.dir, 180)))
	var/mob/living/carbon/human/consistent/motorman = allocate(/mob/living/carbon/human/consistent, get_turf(commuter))
	if(terminal.IsReachableBy(passenger) || !terminal.IsReachableBy(motorman))
		Fail("The driver's cabin did not close the route terminal off from the passengers.")
	var/list/board = terminal?.ui_static_data()
	var/list/listed = board?["stops"]
	if(length(listed) != 1 || listed[1]["name"] != stop.stop_name() || length(board["rails"]) != 6)
		Fail("Route terminal did not list the line and its stop by area.")
	if(!line.depart_for(get_turf(stop)) || line.rail_route[length(line.rail_route)] != get_turf(stop))
		Fail("The car did not set off for the chosen stop.")
	if(terminal?.ui_data()["destination"] != REF(stop))
		Fail("Route terminal did not show where the car is heading.")
	// A terminal spawned onto a car fits itself to it; one standing alone says so rather than failing.
	var/obj/structure/ms13_vehicle_part/rail_terminal/spare = allocate(/obj/structure/ms13_vehicle_part/rail_terminal, get_turf(commuter))
	if(spare.vehicle != line || !(spare in line.parts))
		Fail("A route terminal placed on a car did not fit itself to it.")
	var/obj/structure/ms13_vehicle_part/rail_terminal/loose = allocate(/obj/structure/ms13_vehicle_part/rail_terminal, locate(50, 20, test_z))
	var/list/loose_board = loose.ui_static_data()
	if(loose_board["fitted"] || !islist(loose_board["rails"]) || !islist(loose_board["stops"]))
		Fail("A loose route terminal sent no usable board.")
	clear_vehicle(line)

/// A long straight run: the car gathers speed gradually, brakes ahead of its stop, and an emergency stop still
/// brakes along the line rather than stopping dead.
/datum/unit_test/ms13_rail_vehicles/proc/check_smooth_running(test_z)
	for(var/y in 15 to 45)
		allocate(/obj/structure/ms13_rail, locate(12, y, test_z))
	var/obj/structure/ms13_rail/stop = allocate(/obj/structure/ms13_rail/station, locate(12, 15, test_z))
	var/obj/structure/ms13_vehicle_frame/tram/runner = allocate(/obj/structure/ms13_vehicle_frame/tram, locate(12, 45, test_z))
	var/datum/ms13_ground_vehicle/rail/line = runner.vehicle
	if(!line.depart_for(get_turf(stop)))
		Fail("The car would not set off on a straight run.")
		clear_vehicle(line)
		return
	var/list/speeds = list(line.velocity)
	for(var/tick in 1 to 60)
		if(!line.moving)
			break
		line.next_move_time = 0
		line.movement_tick(line.movement_generation)
		if(line.moving)
			speeds += line.velocity
	var/top = max(speeds)
	if(line.moving || get_turf(line.rail_frame()) != get_turf(stop))
		Fail("The car did not run in to its stop.")
	if(length(speeds) < 5 || speeds[1] >= speeds[4] || speeds[1] > top / 2)
		Fail("The car did not gather speed gradually.")
	if(speeds[length(speeds)] >= top)
		Fail("The car did not brake before its stop.")
	line.depart_for(locate(12, 45, test_z))
	for(var/tick in 1 to 6)
		line.next_move_time = 0
		line.movement_tick(line.movement_generation)
	line.apply_brakes()
	if(!line.moving || !line.halting)
		Fail("The emergency stop halted the car dead instead of braking.")
	for(var/tick in 1 to 30)
		if(!line.moving)
			break
		line.next_move_time = 0
		line.movement_tick(line.movement_generation)
	if(line.moving || line.halting || get_turf(line.rail_frame()) == locate(12, 45, test_z))
		Fail("The emergency stop did not bring the car to a standstill short of its destination.")
	clear_vehicle(line)

/datum/unit_test/ms13_rail_vehicles/proc/clear_vehicle(datum/ms13_ground_vehicle/vehicle)
	vehicle.stop_motion()
	for(var/atom/movable/component as anything in (vehicle.get_all_parts() | vehicle.get_manifest()))
		qdel(component)

/datum/unit_test/ms13_rail_vehicles/proc/check_mounts(test_z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/jeep = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, locate(20, 20, test_z))
	var/datum/ms13_ground_vehicle/vehicle = jeep.vehicle
	var/obj/structure/ms13_vehicle_part/engine/engine = vehicle.engine
	if(engine.density || !vehicle.blocks_vehicle(engine))
		Fail("Walk-over engine did not block vehicle collisions independently of mob density.")
	var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/front_camera = jeep.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/camera)
	var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/side_camera = jeep.spawn_part(/obj/structure/ms13_vehicle_part/exterior_equipment/camera, 90)
	var/obj/structure/window/ms13_vehicle_wall/front_panel
	var/obj/structure/window/ms13_vehicle_wall/side_panel
	for(var/obj/structure/window/ms13_vehicle_wall/panel as anything in vehicle.walls)
		if(panel.parent_frame != jeep)
			continue
		if(panel.dir == jeep.dir)
			front_panel = panel
		if(panel.dir == turn(jeep.dir, 90))
			side_panel = panel
	front_panel.update_integrity(1)
	if(!QDELETED(front_camera) || QDELETED(side_camera))
		Fail("Breaking a hull panel failed to drop only accessories mounted on that edge.")
	qdel(side_panel)
	if(!QDELETED(side_camera))
		Fail("Deleting a mounting wall left a live exterior camera.")
	var/obj/item/cargo = allocate(/obj/item, get_turf(jeep))
	var/obj/structure/chair/ms13_vehicle_seat/seat = locate() in get_turf(jeep)
	var/mob/living/carbon/human/consistent/driver = allocate(/mob/living/carbon/human/consistent, get_turf(jeep))
	seat.user_buckle_mob(driver, driver)
	var/turf/wreck = get_turf(jeep)
	jeep.deconstruct(FALSE)
	if(!QDELETED(engine) || vehicle.engine || !QDELETED(seat) || driver.buckled || cargo.loc != wreck || driver.loc != wreck)
		Fail("Destroyed frame retained supported hardware or lost its occupants/cargo.")
	for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts)
		if(get_turf(part) == wreck)
			Fail("Destroyed frame left an attached component in the controller.")
	if(!(locate(/obj/item/stack/sheet/ms13/scrap_steel) in wreck))
		Fail("Lost frame/hardware left no steel scrap.")
	clear_vehicle(vehicle)
	qdel(driver)
	qdel(cargo)

/// Mouths at both ends reproduce the old outboard-tip bug; already-parallel walls alone do not.
/datum/unit_test/ms13_rail_vehicles/proc/check_corridors(test_z)
	for(var/direction in GLOB.cardinals)
		var/obj/structure/ms13_vehicle_frame/m113/front_left/carrier = allocate(/obj/structure/ms13_vehicle_frame/m113/front_left, locate(30, 30, test_z))
		var/datum/ms13_ground_vehicle/vehicle = carrier.vehicle
		vehicle.driver = allocate(/mob/living/carbon/human/consistent, get_turf(carrier))
		if(direction != vehicle.dir && !vehicle.do_rotate(direction))
			Fail("Unable to orient corridor test vehicle.")
		var/list/borders = list()
		for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
			for(var/travel in list(direction, turn(direction, 180)))
				var/turf/next = get_step(frame, travel)
				if(vehicle.get_frame_at(next))
					continue
				for(var/side in list(turn(direction, 90), turn(direction, -90)))
					if(vehicle.get_frame_at(get_step(frame, side)))
						continue
					var/turf/border = get_step(next, side)
					border = border.ChangeTurf(/turf/closed/wall)
					borders[border] = border.get_integrity()
		vehicle.speed = 1
		for(var/travel in list(direction, turn(direction, 180), turn(direction, 180), direction))
			if(!vehicle.do_move(travel, TRUE))
				Fail("Three-wide M113 could not enter/reverse through an exact-width corridor ([direction]/[travel]).")
		for(var/turf/border as anything in borders)
			if(border.get_integrity() != borders[border])
				Fail("Vehicle damaged a wall outside its swept footprint.")
			border.ChangeTurf(/turf/open/floor/plating)
		clear_vehicle(vehicle)

/datum/unit_test/ms13_rail_vehicles/proc/measure_impact(mass, band, armor, test_z)
	var/obj/structure/ms13_vehicle_frame/frame = allocate(/obj/structure/ms13_vehicle_frame, locate(15, 15, test_z))
	var/datum/ms13_ground_vehicle/vehicle = new
	frame.vehicle = vehicle
	vehicle.pivot = frame
	vehicle.frames += frame
	vehicle.mass_per_frame = mass
	vehicle.speed = band
	frame.setArmor(getArmor(armor))
	var/obj/structure/obstacle = allocate(/obj/structure, locate(15, 14, test_z))
	obstacle.modify_max_integrity(100000)
	obstacle.setArmor(getArmor(0))
	var/integrity_before = obstacle.get_integrity()
	var/frame_before = frame.get_integrity()
	var/energy_before = vehicle.collision_energy()
	vehicle.damage_collision(obstacle, frame, SOUTH)
	. = list(integrity_before - obstacle.get_integrity(), frame_before - frame.get_integrity())
	if(vehicle.speed && vehicle.collision_energy() >= energy_before)
		Fail("A collision did not spend retained impact energy.")
	var/retained = vehicle.collision_energy()
	vehicle.damage_collision(obstacle, frame, SOUTH)
	if(vehicle.speed && vehicle.collision_energy() >= retained)
		Fail("Repeated collisions regenerated momentum without acceleration.")
	clear_vehicle(vehicle)
	qdel(obstacle)
#endif
