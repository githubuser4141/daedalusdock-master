/// Every Civ13 96x96 vehicle (soviet_vehicles.dm) assembles whole, drives, and only uses art that exists.
/datum/unit_test/ms13_civ96_vehicle
	abstract_type = /datum/unit_test/ms13_civ96_vehicle
	var/vehicle_type
	var/rows
	var/columns
	var/expected_seats
	var/tank_armor = FALSE

/datum/unit_test/ms13_civ96_vehicle/Run()
	// Spawned facing south, the hull runs north and west of its pivot.
	var/turf/spot = locate(run_loc_floor_bottom_left.x + columns - 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/civ96/pivot = new vehicle_type(spot)
	var/datum/ms13_ground_vehicle/vehicle = pivot.vehicle
	TEST_ASSERT(vehicle, "[vehicle_type] did not create its controller.")
	TEST_ASSERT_EQUAL(length(vehicle.frames), rows * columns, "[vehicle_type] did not lay out its whole footprint.")
	TEST_ASSERT(vehicle.engine && vehicle.gearbox && vehicle.fuel_tank, "[vehicle_type] is missing part of its drivetrain.")
	TEST_ASSERT(vehicle.has_motive_power(), "A complete [vehicle_type] could not drive.")

	var/gear_count = 0
	var/obj/structure/ms13_vehicle_part/turret/turret
	for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts)
		if(istype(part, /obj/structure/ms13_vehicle_part/running_gear/civ96))
			var/obj/structure/ms13_vehicle_part/running_gear/civ96/gear = part
			gear_count++
			TEST_ASSERT(ms13_icon_has_state(gear.icon, gear.stationary_icon_state), "[vehicle_type] running gear art [gear.stationary_icon_state] does not exist.")
			TEST_ASSERT(ms13_icon_has_state(gear.icon, gear.moving_icon_state), "[vehicle_type] running gear art [gear.moving_icon_state] does not exist.")
		if(istype(part, /obj/structure/ms13_vehicle_part/turret))
			turret = part
	TEST_ASSERT_EQUAL(gear_count, 4, "[vehicle_type] did not get four running gear units.")
	TEST_ASSERT(turret, "[vehicle_type] has no turret.")
	TEST_ASSERT(ms13_icon_has_state(turret.turret_icon, "[turret.turret_art]_turret0"), "[vehicle_type] turret ring art does not exist.")
	TEST_ASSERT(ms13_icon_has_state(turret.turret_icon, turret.exterior_image.icon_state), "[vehicle_type] turret top art does not exist.")

	var/seats = 0
	var/drivers = 0
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		TEST_ASSERT(ms13_icon_has_state(frame.icon, frame.icon_state), "[vehicle_type] floor art [frame.icon_state] does not exist.")
		TEST_ASSERT(ms13_icon_has_state(frame.icon, frame.roof.icon_state), "[vehicle_type] roof art [frame.roof.icon_state] does not exist.")
		TEST_ASSERT(vehicle.is_light_sealed(frame), "[vehicle_type] tile [frame.icon_state] lets daylight in while closed up.")
		TEST_ASSERT(vehicle.is_weather_sealed(frame), "[vehicle_type] tile [frame.icon_state] lets the weather in while closed up.")
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
			seats++
			if(seat.is_driver_seat)
				drivers++
	TEST_ASSERT_EQUAL(seats, expected_seats, "[vehicle_type] has the wrong number of seats.")
	TEST_ASSERT_EQUAL(drivers, 1, "[vehicle_type] needs exactly one driver's seat.")

	var/obj/projectile/bullet/ms13/a50MG/heavy = allocate(/obj/projectile/bullet/ms13/a50MG)
	var/list/every_round = list()
	if(tank_armor)
		for(var/obj/item/ammo_casing/casing_type as anything in subtypesof(/obj/item/ammo_casing))
			var/round_type = initial(casing_type.projectile_type)
			if(ispath(round_type, /obj/projectile/bullet/ms13) && !every_round[round_type])
				every_round[round_type] = allocate(round_type)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in vehicle.walls)
		if(!wall.exterior)
			continue
		TEST_ASSERT(ms13_icon_has_state(wall.icon, wall.icon_state), "[vehicle_type] hull art [wall.icon_state] does not exist.")
		if(tank_armor)
			for(var/round_type in every_round)
				var/obj/projectile/bullet/round = every_round[round_type]
				// 10 is MS13_BULLET_OVERPEN_MIN_REMAINING; mojave defines aren't visible from code/.
				if(round.can_overpenetrate(wall))
					TEST_ASSERT(round.damage * (1 - wall.get_bullet_transfer_fraction(round)) < 10, "[round_type] got through [vehicle_type] [wall].")
		else if(istype(wall, /obj/structure/window/ms13_vehicle_wall/solid))
			TEST_ASSERT(wall.get_bullet_transfer_fraction(heavy) < 1, "A .50 BMG could not get through [vehicle_type] [wall].")

	if(tank_armor)
		var/obj/structure/window/ms13_vehicle_wall/solid/panel = locate(/obj/structure/window/ms13_vehicle_wall/solid/civ96/tank) in vehicle.walls
		TEST_ASSERT(panel.get_bullet_damage_share(heavy, 1) > 0, "[vehicle_type] armor can't be worn down by a .50 BMG at all.")
		panel.update_integrity(panel.max_integrity * 0.2)
		TEST_ASSERT(panel.get_bullet_transfer_fraction(heavy) < 1, "A .50 BMG could not get through a holed [vehicle_type] panel.")
		panel.repair_damage(panel.max_integrity)
		TEST_ASSERT_EQUAL(panel.get_bullet_transfer_fraction(heavy), 1, "A repaired [vehicle_type] panel still let a .50 BMG through.")

/datum/unit_test/ms13_civ96_vehicle/btr80
	name = "VEHICLES: BTR-80 Assembles"
	vehicle_type = /obj/structure/ms13_vehicle_frame/civ96/btr80
	rows = 4
	columns = 2
	expected_seats = 6

/datum/unit_test/ms13_civ96_vehicle/mtlb
	name = "VEHICLES: MT-LB Assembles"
	vehicle_type = /obj/structure/ms13_vehicle_frame/civ96/mtlb
	rows = 4
	columns = 2
	expected_seats = 5

/datum/unit_test/ms13_civ96_vehicle/bmd2
	name = "VEHICLES: BMD-2 Assembles"
	vehicle_type = /obj/structure/ms13_vehicle_frame/civ96/bmd2
	rows = 3
	columns = 2
	expected_seats = 5

/datum/unit_test/ms13_civ96_vehicle/t34
	name = "VEHICLES: T-34 Assembles"
	vehicle_type = /obj/structure/ms13_vehicle_frame/civ96/t34
	rows = 4
	columns = 3
	expected_seats = 4
	tank_armor = TRUE

/datum/unit_test/ms13_civ96_vehicle/is3
	name = "VEHICLES: IS-3 Assembles"
	vehicle_type = /obj/structure/ms13_vehicle_frame/civ96/is3
	rows = 5
	columns = 3
	expected_seats = 4
	tank_armor = TRUE
