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
	vehicle.set_ignition(TRUE)
	TEST_ASSERT(vehicle.start_engine(), "[vehicle_type] engine failed to start.")
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
	TEST_ASSERT_EQUAL(turret.exterior_image.icon_state, "[turret.turret_art]_turret0", "[vehicle_type] turret ring is not exterior-only.")
	TEST_ASSERT(ms13_icon_has_state(turret.turret_icon, "[turret.turret_art]_turret_roof0"), "[vehicle_type] turret top art does not exist.")

	var/seats = 0
	var/drivers = 0
	var/obj/structure/chair/ms13_vehicle_seat/gunner_seat
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		TEST_ASSERT(ms13_icon_has_state(frame.icon, frame.icon_state), "[vehicle_type] floor art [frame.icon_state] does not exist.")
		TEST_ASSERT(ms13_icon_has_state(frame.icon, frame.roof.icon_state), "[vehicle_type] roof art [frame.roof.icon_state] does not exist.")
		TEST_ASSERT(vehicle.is_light_sealed(frame), "[vehicle_type] tile [frame.icon_state] lets daylight in while closed up.")
		TEST_ASSERT(vehicle.is_weather_sealed(frame), "[vehicle_type] tile [frame.icon_state] lets the weather in while closed up.")
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
			seats++
			if(seat.is_driver_seat)
				drivers++
				TEST_ASSERT(length(seat.overlays) >= 3, "The driver's seat is missing its visible dashboard monitor.")
				TEST_ASSERT(seat.mouse_opacity != MOUSE_OPACITY_TRANSPARENT, "The dashboard is not clickable.")
			if(seat.operated_turret == turret)
				gunner_seat = seat
	TEST_ASSERT_EQUAL(seats, expected_seats, "[vehicle_type] has the wrong number of seats.")
	TEST_ASSERT_EQUAL(drivers, 1, "[vehicle_type] needs exactly one driver's seat.")
	TEST_ASSERT(gunner_seat, "[vehicle_type] turret is not linked to a gunner's seat.")
	TEST_ASSERT_EQUAL(turret.gunner_seat, gunner_seat, "[vehicle_type] gunner seat link is only one-way.")
	TEST_ASSERT(turret.ammo_type && turret.fire_sound, "[vehicle_type] turret is missing part of its weapon configuration.")
	TEST_ASSERT(turret.ammo > 0 && turret.ammo <= turret.max_ammo, "[vehicle_type] turret did not start with a valid ammunition load.")
	// Its racks come stocked with rounds its own gun takes.
	var/obj/item/ammo_casing/standard = turret.ammo_type
	var/stocked = 0
	for(var/obj/structure/ms13_vehicle_part/stowage/rack in vehicle.parts)
		for(var/obj/item/ammo_box/box in rack)
			stocked += box.ammo_count()
			TEST_ASSERT_EQUAL(box.caliber, initial(standard.caliber), "[vehicle_type] stows [box], which its gun can't fire.")
	TEST_ASSERT(stocked, "[vehicle_type] racks came empty.")

	// One representative live shot covers the shared controls and fire path used by every profile.
	if(istype(pivot, /obj/structure/ms13_vehicle_frame/civ96/btr80))
		var/mob/living/carbon/human/consistent/gunner = allocate(/mob/living/carbon/human/consistent)
		gunner.forceMove(get_turf(gunner_seat))
		gunner_seat.user_buckle_mob(gunner, gunner)
		TEST_ASSERT(gunner_seat.turret_control && gunner.is_holding(gunner_seat.turret_control), "Buckling into the gunner seat did not provide turret controls.")

		var/turf/target = get_turf(turret)
		for(var/i in 1 to 4)
			target = get_step(target, EAST)
		TEST_ASSERT(target && !vehicle.get_frame_at(target), "No exterior target turf was available for the turret test.")
		var/ammo_before = turret.ammo
		var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent)
		TEST_ASSERT(!turret.fire_at(target, bystander, null), "A mob outside the gunner seat could fire the turret.")
		TEST_ASSERT_EQUAL(turret.ammo, ammo_before, "An unauthorized turret attempt consumed ammunition.")
		vehicle.set_ignition(FALSE)
		TEST_ASSERT(!turret.fire_at(target, gunner, null), "An unpowered autocannon fired.")
		TEST_ASSERT_EQUAL(turret.ammo, ammo_before, "An unpowered turret attempt consumed ammunition.")
		vehicle.set_ignition(TRUE)
		var/battery_before = vehicle.battery.cell.charge
		TEST_ASSERT(turret.fire_at(target, gunner, null), "The buckled gunner could not fire the turret.")
		TEST_ASSERT_EQUAL(vehicle.battery.cell.charge, battery_before - turret.shot_power_cost, "Powered turret firing did not consume its electrical charge.")
		TEST_ASSERT_EQUAL(turret.ammo, ammo_before - 1, "Firing the turret did not consume one round.")
		gunner_seat.unbuckle_mob(gunner, TRUE)
		TEST_ASSERT(!gunner_seat.turret_control, "The turret controls remained after the gunner unbuckled.")

	// Any shell of the gun's caliber loads through the gunner's seat, and the last one loaded fires next.
	if(istype(pivot, /obj/structure/ms13_vehicle_frame/civ96/t34))
		var/mob/living/carbon/human/consistent/loader = allocate(/mob/living/carbon/human/consistent, get_turf(gunner_seat))
		turret.ammo = 0
		turret.loaded_rounds.Cut()
		gunner_seat.attackby(allocate(/obj/item/ammo_box/ms13/vehicle_shell/heavy), loader)
		TEST_ASSERT(!turret.ammo, "The 76mm gun took 122mm shells.")
		gunner_seat.attackby(allocate(/obj/item/ammo_box/ms13/vehicle_shell/he), loader)
		gunner_seat.attackby(allocate(/obj/item/ammo_box/ms13/vehicle_shell/canister), loader)
		TEST_ASSERT_EQUAL(turret.ammo, 8, "Shell crates did not load through the gunner's seat.")
		TEST_ASSERT_EQUAL(turret.selected_round, /obj/item/ammo_casing/ms13/vehicle_shell/canister, "The last shell loaded is not the one in the breech.")
		turret.cycle_round(loader)
		TEST_ASSERT_EQUAL(turret.selected_round, /obj/item/ammo_casing/ms13/vehicle_shell/he, "Switching shells did not reach the other kind loaded.")

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
		TEST_ASSERT(wall.exterior_image, "[vehicle_type] hull wall was not split into exterior and cabin art.")
		TEST_ASSERT(ms13_icon_has_state(wall.exterior_image.icon, wall.exterior_image.icon_state), "[vehicle_type] hull art [wall.exterior_image.icon_state] does not exist.")
		if(!isnull(wall.vision_range))
			TEST_ASSERT_EQUAL(wall.vision_range, 0, "[vehicle_type] vision port works from an adjacent tile instead of its own tile only.")
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
		// Against its own plate, sabot and the HEAT jet beat solid shot, and HE barely scratches it.
		var/solid_shot = initial(standard.projectile_type)
		var/list/margin = list()
		for(var/kind in list("", "/he", "/sabot"))
			var/obj/projectile/shell = allocate(text2path("[solid_shot][kind]"))
			margin[kind] = shell.get_penetration_power() - panel.get_bullet_stopping_power(shell)
		var/obj/projectile/bullet/cannonball/ms13_vehicle/heat = allocate(text2path("[solid_shot]/heat"))
		var/obj/projectile/jet = ms13_make_shaped_charge_jet(get_turf(heat), heat.jet_damage, heat.jet_penetration, heat.jet_range, heat.jet_fragments, null, heat.jet_hardness, heat.jet_mass)
		margin["/heat"] = jet.get_penetration_power() - panel.get_bullet_stopping_power(jet)
		qdel(jet)
		TEST_ASSERT(!heat.damage && !heat.can_overpenetrate(panel), "[vehicle_type] HEAT shell hits with more than its fuse.")
		TEST_ASSERT(margin["/sabot"] > margin[""] && margin["/heat"] > margin[""] && margin[""] > margin["/he"], "[vehicle_type] shell kinds don't rank sabot/HEAT over AP over HE against tank armor.")
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
