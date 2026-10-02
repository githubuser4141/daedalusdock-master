#ifdef UNIT_TESTS
#define VEHICLE_TERMINAL_ASSERT(condition, message) if(!(condition)) { return Fail(message); }

/datum/unit_test/ms13_vehicle_terminal/Run()
	var/turf/ground = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/obj/structure/ms13_vehicle_frame/frame = ms13_start_vehicle(ground, NORTH)
	allocated += frame
	var/datum/ms13_ground_vehicle/vehicle = frame.vehicle
	allocated += vehicle
	var/obj/structure/ms13_vehicle_part/battery/battery = frame.spawn_part(/obj/structure/ms13_vehicle_part/battery)
	var/obj/structure/ms13_vehicle_part/terminal/console = frame.spawn_part(/obj/structure/ms13_vehicle_part/terminal)
	var/obj/machinery/ms13/terminal/vehicle/terminal = console.terminal
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, ground)
	VEHICLE_TERMINAL_ASSERT(!terminal.terminal_available(user), "Vehicle terminal worked without ignition")
	vehicle.set_ignition(TRUE)
	VEHICLE_TERMINAL_ASSERT(terminal.terminal_available(user), "Powered mounted terminal was inaccessible")
	var/charge = vehicle.stored_charge()
	vehicle.process_power(1)
	VEHICLE_TERMINAL_ASSERT(vehicle.stored_charge() == charge - 1 - console.power_draw, "Terminal load did not reach the vehicle battery")
	var/obj/item/ms13/bodycam/camera = allocate(/obj/item/ms13/bodycam, ground)
	user.put_in_hands(camera)
	camera.melee_attack_chain(user, console, "")
	VEHICLE_TERMINAL_ASSERT(length(terminal.paired_bodycams) == 1, "Tapping the mounted terminal did not pair the bodycam")
	var/mob/living/carbon/human/ms13_squad/leader/leader = allocate(/mob/living/carbon/human/ms13_squad/leader, ground)
	leader.ai_controller.set_ai_status(AI_STATUS_OFF)
	leader.squad_id = "vehicle test"
	terminal.squad_id = leader.squad_id
	VEHICLE_TERMINAL_ASSERT(leader.claim_command(user) && leader.can_command(user, terminal), "Mounted terminal could not command its squad")
	var/obj/structure/bench = allocate(/obj/structure, get_step(ground, EAST))
	bench.AddComponent(/datum/component/personal_crafting)
	VEHICLE_TERMINAL_ASSERT(bench in terminal.workshop_benches(), "Mounted terminal lost adjacent workbench access")
	terminal.doc_content_1 = "Saved aboard"
	var/turf/destination = get_step(ground, NORTH)
	VEHICLE_TERMINAL_ASSERT(vehicle.translate_hull(0, 1, ground.z, TRUE), "Could not move the terminal's vehicle")
	VEHICLE_TERMINAL_ASSERT(get_turf(terminal) == destination && terminal.terminal_available(user), "Terminal or user did not follow the vehicle")
	battery.cell.charge = 0
	vehicle.update_electrical()
	VEHICLE_TERMINAL_ASSERT(!terminal.terminal_available(user), "Flat battery left terminal usable")
	battery.cell.charge = 1000
	vehicle.update_electrical()
	VEHICLE_TERMINAL_ASSERT(terminal.terminal_available(user), "Restoring battery did not recover terminal")
	console.atom_break()
	VEHICLE_TERMINAL_ASSERT(!terminal.terminal_available(user), "Broken mount left terminal usable")
	console.atom_fix()
	VEHICLE_TERMINAL_ASSERT(terminal.terminal_available(user), "Repair did not recover terminal")
	console.detach()
	var/obj/item/ms13_vehicle_part_kit/kit = allocate(/obj/item/ms13_vehicle_part_kit, destination, console)
	VEHICLE_TERMINAL_ASSERT(!terminal.terminal_available(user), "Detached terminal remained usable")
	console.fit_to(frame, NORTH)
	qdel(kit)
	VEHICLE_TERMINAL_ASSERT(terminal.terminal_available(user) && terminal.doc_content_1 == "Saved aboard" && length(terminal.paired_bodycams) == 1, "Refitting lost terminal state or power")
	qdel(frame)
	VEHICLE_TERMINAL_ASSERT(QDELETED(console) && QDELETED(terminal), "Destroyed frame left its terminal behind")

/datum/unit_test/ms13_squad_vehicle_seats/Run()
	var/turf/ground = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/frame = ms13_start_vehicle(ground, NORTH)
	allocated += frame
	var/datum/ms13_ground_vehicle/vehicle = frame.vehicle
	allocated += vehicle
	for(var/direction in list(NORTH, SOUTH, EAST))
		frame.spawn_wall(direction, null, /obj/structure/window/ms13_vehicle_wall/solid)
	var/obj/structure/window/ms13_vehicle_wall/solid/door/door = frame.spawn_wall(WEST, null, /obj/structure/window/ms13_vehicle_wall/solid/door)
	var/obj/structure/chair/ms13_vehicle_seat/seat = frame.add_seat(0, "test passenger seat")
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, get_ranged_target_turf(ground, WEST, 2))
	var/datum/ai_controller/ms13_squad/brain = unit.ai_controller
	brain.set_ai_status(AI_STATUS_OFF)
	door.locked = TRUE
	VEHICLE_TERMINAL_ASSERT(!length(SSpathfinder.jps_pathfind_now(unit, ground, 30, 0)), "Squad routed through locked vehicle hull")
	door.locked = FALSE
	unit.set_order("Sit", seat)
	var/deadline = world.time + 15 SECONDS
	while(world.time < deadline && unit.buckled != seat)
		brain.process(0.25)
		sleep(0.25 SECONDS)
	VEHICLE_TERMINAL_ASSERT(unit.buckled == seat && door.opened, "NPC failed to board through the closed door and buckle in: [unit.order_status]")
	seat.configure_driver_seat()
	unit.set_order("Hold", null)
	VEHICLE_TERMINAL_ASSERT(!brain.approach(get_step(ground, NORTH), 0), "Buckled NPC attempted to drive through its pathfinder")
	VEHICLE_TERMINAL_ASSERT(vehicle.translate_hull(0, 1, ground.z, TRUE), "Could not move vehicle with seated NPC")
	VEHICLE_TERMINAL_ASSERT(unit.buckled == seat && get_turf(unit) == get_turf(frame), "Vehicle movement lost its NPC passenger")
	door.close()
	var/turf/exit = get_ranged_target_turf(frame, WEST, 2)
	unit.set_order("Move", exit)
	VEHICLE_TERMINAL_ASSERT(!unit.buckled, "Movement order failed to release vehicle seat")
	deadline = world.time + 15 SECONDS
	while(world.time < deadline && get_ms13_ground_vehicle_at(unit) == vehicle)
		brain.process(0.25)
		sleep(0.25 SECONDS)
	VEHICLE_TERMINAL_ASSERT(get_ms13_ground_vehicle_at(unit) != vehicle && door.opened, "NPC could not reopen the door and disembark")
	var/mob/living/carbon/human/occupant = allocate(/mob/living/carbon/human, get_turf(seat))
	seat.user_buckle_mob(occupant, occupant)
	unit.set_order("Sit", seat)
	unit.act_on_order()
	VEHICLE_TERMINAL_ASSERT(unit.order_status == "Seat unavailable" && occupant.buckled == seat, "NPC took an occupied seat")

#undef VEHICLE_TERMINAL_ASSERT
#endif
