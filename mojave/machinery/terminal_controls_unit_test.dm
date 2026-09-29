/datum/unit_test/ms13_mechanical_doors
	name = "MS13 mechanical doors: timed manual opening and interruption"

/datum/unit_test/ms13_mechanical_doors/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(site, SOUTH))
	var/obj/machinery/door/airlock/ms13/door = allocate(/obj/machinery/door/airlock/ms13, site)
	door.set_machine_stat(NOPOWER)
	door.autoclose = FALSE
	if(!(door.manual_open_time >= 10 SECONDS))
		Fail("Manual opening is no longer slow by default.")
	door.manual_open_time = 1 SECONDS
	INVOKE_ASYNC(door, TYPE_PROC_REF(/atom, attack_hand), user)
	sleep(1)
	if(!(door.prying_so_hard && door.density))
		Fail("Opening bypassed the timed action or never started.")
	door.attack_hand(user)
	if(!((user.do_after_count()) == (1)))
		Fail("Repeated clicks stacked manual opening actions.")
	user.forceMove(get_step(user, EAST))
	sleep(2 SECONDS)
	if(!(door.density && !door.prying_so_hard))
		Fail("Moving did not cancel and release the manual opening action.")
	user.forceMove(get_step(site, SOUTH))
	INVOKE_ASYNC(door, TYPE_PROC_REF(/atom, attack_hand), user)
	sleep(1)
	door.set_machine_stat(NONE)
	sleep(2 SECONDS)
	if(!(door.density && !door.prying_so_hard))
		Fail("Restoring power did not cancel manual opening.")
	door.set_machine_stat(NOPOWER)
	for(var/lock_var in list("locked", "welded", "lock_locked"))
		door.vars[lock_var] = TRUE
		if(!(!door.can_manually_open(user)))
			Fail("Manual opening ignored [lock_var].")
		door.vars[lock_var] = FALSE
	door.seal = allocate(/obj/item/door_seal, door)
	if(!(!door.can_manually_open(user)))
		Fail("Manual opening ignored the door seal.")
	door.seal = null
	door.attack_hand(user)
	if(!(!door.density && !door.prying_so_hard))
		Fail("An uninterrupted manual opening did not open the powerless door.")

/datum/unit_test/ms13_conduit
	name = "MS13 conduit: cable isolation, branches, remote switches and teardown"

/datum/unit_test/ms13_conduit/Run()
	var/turf/site = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/area/room = get_area(site)
	var/obj/machinery/power/apc/original_apc = room.apc
	var/obj/structure/cable/west = allocate(/obj/structure/cable, get_step(site, WEST))
	west.set_directions(EAST)
	var/obj/structure/cable/branch = allocate(/obj/structure/cable, west.loc)
	branch.set_directions(NORTH)
	var/obj/structure/cable/branch_end = allocate(/obj/structure/cable, get_step(west, NORTH))
	branch_end.set_directions(SOUTH)
	var/obj/structure/cable/middle = allocate(/obj/structure/cable, site)
	middle.set_directions(EAST|WEST)
	var/obj/structure/cable/east = allocate(/obj/structure/cable, get_step(site, EAST))
	east.set_directions(WEST)
	var/obj/machinery/power/source = allocate(/obj/machinery/power, west.loc)
	source.connect_to_network()
	var/obj/machinery/power/load = allocate(/obj/machinery/power, east.loc)
	load.connect_to_network()
	var/obj/machinery/power/apc/ms13/conduit/conduit = allocate(/obj/machinery/power/apc/ms13/conduit, site)
	conduit.id_tag = "inline-conduit-test"
	if(!(!istype(conduit, /obj/machinery/power/apc) && room.apc == original_apc))
		Fail("The conduit still takes ownership of the area's APC.")
	if(!(west.powernet == east.powernet && source.powernet == load.powernet))
		Fail("An on conduit interrupted its cable.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(site, SOUTH))
	click_wrapper(user, conduit)
	if(!(!conduit.operating && conduit.ui_status(user) == UI_CLOSE))
		Fail("Clicking the conduit did not switch it without a UI.")
	if(!(west.powernet != east.powernet && west.powernet == branch_end.powernet && source.powernet == west.powernet && load.powernet == east.powernet))
		Fail("The switch failed to isolate only the downstream branch.")
	source.add_avail(1000000)
	source.powernet.reset()
	load.powernet.reset()
	if(!(source.avail() == 1000000 && !load.avail()))
		Fail("Power generation leaked across the off switch or failed upstream.")
	// Relaying native cable rebuilds must not accidentally reconnect an off conduit.
	east.merge_new_connections()
	if(!(west.powernet != east.powernet))
		Fail("Rebuilding a neighbouring wire bypassed the open switch.")
	if(!((ms13_switch_power(conduit.id_tag, user)) == (1)))
		Fail("Remote control did not find the reparented conduit.")
	if(!(conduit.operating && source.powernet == load.powernet))
		Fail("Remote on did not reconnect the cable and its machines.")
	conduit.toggle_breaker(user)
	// Moving the off conduit restores its old wire and interrupts the new one.
	conduit.forceMove(get_step(site, NORTH))
	if(!(west.powernet == east.powernet))
		Fail("Moving a conduit left its old tile electrically disconnected.")
	conduit.forceMove(site)
	if(!(west.powernet != east.powernet))
		Fail("Moving an off conduit onto a wire did not split it.")
	qdel(conduit)
	if(!(west.powernet == east.powernet && room.apc == original_apc))
		Fail("Removing the switch damaged the wire or area power ownership.")
	// A second route around the open contact legitimately supplies the other side.
	var/obj/structure/cable/nw = allocate(/obj/structure/cable, branch_end.loc)
	nw.set_directions(EAST)
	var/obj/structure/cable/north = allocate(/obj/structure/cable, get_step(site, NORTH))
	north.set_directions(EAST|WEST)
	var/obj/structure/cable/ne = allocate(/obj/structure/cable, get_step(east, NORTH))
	ne.set_directions(WEST|SOUTH)
	var/obj/structure/cable/join = allocate(/obj/structure/cable, east.loc)
	join.set_directions(NORTH)
	conduit = allocate(/obj/machinery/power/apc/ms13/conduit, site)
	conduit.toggle_breaker()
	if(!(west.powernet == east.powernet))
		Fail("An off switch incorrectly shut off a valid alternate cable route.")

/datum/unit_test/ms13_stair_cables
	name = "MS13 stair cables: both directions, map wiring, cuts and conduits"

/datum/unit_test/ms13_stair_cables/Run()
	var/datum/space_level/lower_level = SSmapping.add_new_zlevel("Cable stairs lower", list(ZTRAIT_UP = 1))
	var/datum/space_level/upper_level = SSmapping.add_new_zlevel("Cable stairs upper", list(ZTRAIT_DOWN = -1))
	SSzcopy.calculate_zstack_limits()
	var/turf/bottom = locate(20, 20, lower_level.z_value)
	var/turf/top = locate(20, 20, upper_level.z_value)
	bottom = bottom.ChangeTurf(/turf/open/floor/plating)
	top = top.ChangeTurf(/turf/open/openspace)
	var/turf/landing = get_step(top, NORTH)
	landing = landing.ChangeTurf(/turf/open/floor/plating)
	var/obj/structure/cable/low = allocate(/obj/structure/cable, bottom)
	var/obj/structure/cable/high = allocate(/obj/structure/cable, landing)
	if(low.powernet == high.powernet)
		Fail("Ordinary cables joined unrelated floors before stairs existed.")
	var/obj/structure/stairs/stairs = allocate(/obj/structure/stairs/north, bottom)
	if(!(high in low.get_cable_connections()) || !(low in high.get_cable_connections()) || low.powernet != high.powernet)
		Fail("Adding stairs did not connect both directions and merge the existing cable networks.")
	// The same-coordinate opening is also a valid mapped endpoint.
	var/obj/structure/cable/opening = allocate(/obj/structure/cable, top)
	if(low.powernet != opening.powernet)
		Fail("A cable directly above the stair did not join the stair's network.")
	qdel(opening)
	var/obj/machinery/power/apc/ms13/conduit/conduit = allocate(/obj/machinery/power/apc/ms13/conduit, bottom)
	conduit.toggle_breaker()
	if(low.powernet == high.powernet || (high in low.get_cable_connections()) || (low in high.get_cable_connections()))
		Fail("Stair cabling bypassed an off conduit.")
	conduit.toggle_breaker()
	if(low.powernet != high.powernet)
		Fail("The conduit did not reconnect the stair cable.")
	qdel(conduit)
	qdel(low)
	low = allocate(/obj/structure/cable, bottom)
	if(low.powernet != high.powernet)
		Fail("Replacing a cut cable did not reconnect it across the stairs.")
	stairs.setDir(SOUTH)
	if(low.powernet == high.powernet)
		Fail("Rotating stairs left their old landing electrically connected.")
	stairs.setDir(NORTH)
	if(low.powernet != high.powernet)
		Fail("Rotating stairs back did not restore their cable connection.")
	stairs.forceMove(get_step(bottom, EAST))
	if(low.powernet == high.powernet)
		Fail("Moving stairs left a phantom cable connection.")
	stairs.forceMove(bottom)
	if(low.powernet != high.powernet)
		Fail("Moving stairs back did not restore the cable connection.")
	qdel(stairs)
	if(low.powernet == high.powernet)
		Fail("Removing stairs left their former cable networks joined.")
	// Mapper helpers with no horizontal neighbours must still become visible, usable cable knots.
	qdel(low)
	qdel(high)
	stairs = allocate(/obj/structure/stairs/north, bottom)
	var/obj/structure/cable/smart_cable/smart_low = allocate(/obj/structure/cable/smart_cable, bottom)
	var/obj/structure/cable/smart_cable/smart_high = allocate(/obj/structure/cable/smart_cable, landing)
	if(!smart_low.has_become_cable || !smart_high.has_become_cable || smart_low.powernet != smart_high.powernet)
		Fail("Smart cables at isolated stair endpoints did not turn into connected cable knots.")
	qdel(stairs)
	qdel(smart_low)
	qdel(smart_high)
	// Existing vertical hubs still work when built mid-round and obey the same cable switch.
	var/obj/structure/cable/multiz/low_hub = allocate(/obj/structure/cable/multiz, bottom)
	var/obj/structure/cable/multiz/high_hub = allocate(/obj/structure/cable/multiz, top)
	if(low_hub.powernet != high_hub.powernet || !low_hub.powernet)
		Fail("New vertical hubs did not merge their networks.")
	conduit = allocate(/obj/machinery/power/apc/ms13/conduit, top)
	conduit.toggle_breaker()
	if(low_hub.powernet == high_hub.powernet)
		Fail("Vertical hubs bypassed an off conduit.")
	qdel(conduit)
	if(low_hub.powernet != high_hub.powernet)
		Fail("Removing the conduit did not restore the existing vertical hubs.")
	qdel(low_hub)
	qdel(high_hub)
	// Inspect the actual loaded map too, not only the synthetic two-floor circuit.
	var/mapped_links = 0
	for(var/obj/structure/stairs/mapped_stairs as anything in INSTANCES_OF(/obj/structure/stairs))
		var/turf/site = get_turf(mapped_stairs)
		if(ms13_conduit_blocks(site))
			continue
		for(var/obj/structure/cable/mapped_low in site)
			for(var/turf/other_level as anything in ms13_stair_cable_turfs(site))
				if(ms13_conduit_blocks(other_level))
					continue
				for(var/obj/structure/cable/mapped_high in other_level)
					mapped_links++
					if(!mapped_low.powernet || mapped_low.powernet != mapped_high.powernet)
						Fail("Mapped stair cables at [AREACOORD(site)] and [AREACOORD(other_level)] are on different networks.")
	if(SSmapping.config.map_name == "Drought" && !mapped_links)
		Fail("The Drought stair-cable placements were not exercised by the map check.")

/datum/unit_test/ms13_fixture_destruction
	name = "MS13 fixtures: attacks clear broken APCs and light housings"

/datum/unit_test/ms13_fixture_destruction/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/datum/ms13_terrain_hivemind/necromorph/network = new
	allocated += network
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier/unit = allocate(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier, get_step(site, SOUTH), network)
	unit.toggle_ai(AI_OFF)
	for(var/fixture_type in list(/obj/machinery/power/apc, /obj/machinery/power/apc/ms13, /obj/machinery/light/ms13, /obj/machinery/light/ms13/built, /obj/machinery/light/ms13/bulb, /obj/machinery/light/ms13/bulb/industrial, /obj/structure/light_construct, /obj/structure/light_construct/small))
		var/obj/fixture = allocate(fixture_type, site)
		if(istype(fixture, /obj/machinery/power/apc))
			var/obj/machinery/power/apc/box = fixture
			box.area = new /area
			allocated += box.area
			fixture.update_integrity(40)
			if(!((box.machine_stat & BROKEN) && !QDELETED(box)))
				Fail("An APC did not retain its repairable broken stage.")
		for(var/hit in 1 to 50)
			if(QDELETED(fixture))
				break
			if(!(unit.hive_attack_obstacle(fixture, last_resort = TRUE)))
				Fail("The hive failed to make damage progress against [fixture_type].")
		if(!(QDELETED(fixture)))
			Fail("Repeated necromorph attacks never destroyed [fixture_type].")
		if(!(!(locate(/obj/machinery/light) in site) && !(locate(/obj/structure/light_construct) in site)))
			Fail("Destroying [fixture_type] respawned another light housing.")
	var/obj/machinery/light/ms13/built/empty = allocate(/obj/machinery/light/ms13/built, site)
	empty.deconstruct(TRUE)
	if(!(QDELETED(empty) && (locate(/obj/item/wallframe/light_fixture/ms13) in site)))
		Fail("Dismantling an empty fixture did not produce a reusable wall frame.")

/datum/unit_test/ms13_terminal_controls
	name = "MS13 terminal: remote power, shutters, motors, blast doors and cameras"
	var/area/control_area
	var/old_requires_power

/datum/unit_test/ms13_terminal_controls/Destroy()
	. = ..()
	if(control_area)
		control_area.requires_power = old_requires_power
		control_area.power_change()

/datum/unit_test/ms13_terminal_controls/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	control_area = get_area(origin)
	old_requires_power = control_area.requires_power
	control_area.requires_power = FALSE // Other power tests may leave the shared room's channels off.
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent, get_step(origin, WEST))
	var/obj/machinery/ms13/terminal/control/console = allocate(/obj/machinery/ms13/terminal/control, origin)
	console.signal_id_1 = "terminal-test"
	console.signal_title_1 = "Test circuit"
	console.id = console.signal_id_1
	console.doc_title_2 = "Custom mapper instructions"
	console.doc_content_2 = "Keep this text."
	console.write_documents()
	if(console.doc_title_2 != "Custom mapper instructions" || console.doc_content_2 != "Keep this text.")
		Fail("Loading terminal documents discarded a custom mapper entry.")
	if(!console.terminal_available(operator))
		Fail("An adjacent operator cannot use the terminal: machine [console.machine_stat]/[console.is_operational], active [console.active], broken [console.broken], operator [operator.stat]/[operator.mobility_flags], reach [console.IsReachableBy(operator)], topic [operator.canUseTopic(console, USE_CLOSE|USE_DEXTERITY)].")
	console.password_needed = TRUE
	if(console.terminal_available(operator) || console.activate_link("signal_one", operator))
		Fail("A locked terminal accepts remote commands.")
	console.unlocked = TRUE
	console.set_machine_stat(NOPOWER)
	if(console.terminal_available(operator))
		Fail("A powerless terminal accepts commands.")
	console.set_machine_stat(NONE)
	var/obj/machinery/door/poddoor/shutters/ms13/horizontal/red/solo/shutter = allocate(/obj/machinery/door/poddoor/shutters/ms13/horizontal/red/solo, get_step(origin, EAST))
	shutter.id = console.id
	console.activate_link("signal_one", operator)
	sleep(2 SECONDS)
	if(shutter.density)
		Fail("The terminal did not open its linked shutter.")
	console.signal_id_single = console.id
	console.signal_title_single = "Single-use shutter command"
	if(console.used || !console.activate_link("signal_single", operator))
		Fail("The one-use command was unavailable before its first activation.")
	sleep(2 SECONDS)
	if(!shutter.density || !console.used || console.activate_link("signal_single", operator))
		Fail("The one-use command did not close the shutter exactly once.")
	qdel(shutter)
	var/obj/machinery/power/apc/ms13/box = allocate(/obj/machinery/power/apc/ms13, get_step(origin, EAST))
	var/area/powered_area = new
	allocated += powered_area
	box.area = powered_area
	box.id_tag = console.id
	box.set_machine_stat(NONE)
	box.operating = TRUE
	box.always_powered = TRUE
	box.lighting = APC_CHANNEL_ON
	box.equipment = APC_CHANNEL_ON
	box.environ = APC_CHANNEL_ON
	box.update()
	box.wires.on_pulse(WIRE_POWER1)
	box.wires.on_pulse(WIRE_POWER2)
	box.wires.on_cut(WIRE_POWER1, FALSE)
	box.wires.on_cut(WIRE_POWER2, FALSE)
	if(box.shorted)
		Fail("A utility box entered the inherited APC short-circuit state.")
	box.emp_act(EMP_HEAVY)
	if(box.shorted)
		Fail("An EMP short-circuited a utility box through its wiring.")
	box.operating = TRUE // EMP now trips the breaker; start the independent remote-toggle check powered.
	box.lighting = APC_CHANNEL_ON
	box.equipment = APC_CHANNEL_ON
	box.environ = APC_CHANNEL_ON
	box.update()
	console.activate_link("signal_one", operator)
	box.process(1) // Leave the breaker off through a real power-processing tick before restoring it.
	if(box.operating || powered_area.power_light || powered_area.power_equip || powered_area.power_environ)
		Fail("Remote power-off did not propagate to all area channels.")
	var/obj/machinery/button/ms13_power/power_switch = allocate(/obj/machinery/button/ms13_power, get_step(origin, NORTH))
	power_switch.id = box.id_tag
	power_switch.setup_device()
	power_switch.device.activate()
	if(!box.operating || !powered_area.power_light || !powered_area.power_equip)
		Fail("The separate remote power switch could not restore area power.")
	qdel(box)
	operator.forceMove(get_step(origin, WEST))
	var/obj/machinery/door/unpowered/ms13/metal/motor_door = allocate(/obj/machinery/door/unpowered/ms13/metal, get_step(origin, EAST))
	motor_door.id_tag = console.id
	motor_door.install_motor()
	var/obj/structure/cable/cable = allocate(/obj/structure/cable, motor_door.loc)
	cable.linked_dirs = NORTH
	var/datum/powernet/line = new
	allocated += line
	line.add_cable(cable)
	line.avail = 1000000
	console.activate_link("signal_one", operator)
	if(motor_door.density || !line.load)
		Fail("The terminal did not run the door's powered motor.")
	motor_door.bolted = TRUE
	console.activate_link("signal_one", operator)
	if(motor_door.density)
		Fail("A remote command ignored the motor's bolts.")
	motor_door.bolted = FALSE
	line.avail = 0
	console.activate_link("signal_one", operator)
	if(motor_door.density)
		Fail("A remote command moved an unpowered motor.")
	qdel(motor_door)
	console.camera_network = "terminal-test"
	var/obj/machinery/computer/security/ms13_terminal_viewer/viewer = allocate(/obj/machinery/computer/security/ms13_terminal_viewer, console)
	console.camera_viewer = viewer
	viewer.network = list(console.camera_network)
	var/obj/machinery/camera/camera = allocate(/obj/machinery/camera, get_step(origin, NORTH))
	camera.network = list(console.camera_network)
	camera.c_tag = "Test camera"
	if(viewer.get_available_cameras()[camera.c_tag] != camera || viewer.ui_status(operator) != UI_INTERACTIVE)
		Fail("The terminal camera viewer did not expose its linked network.")
	viewer.network = list("unrelated-network")
	if(length(viewer.get_available_cameras()))
		Fail("The terminal camera viewer exposes unrelated networks.")
	console.active = FALSE
	if(viewer.ui_status(operator) != UI_CLOSE)
		Fail("Turning off the terminal did not close camera access.")
	console.active = TRUE
	check_blast_door(console)
	qdel(console)
	if(!QDELETED(viewer))
		Fail("Destroying the terminal left its camera viewer alive.")

/datum/unit_test/ms13_terminal_controls/proc/check_blast_door(obj/machinery/ms13/terminal/console)
	var/test_z = run_loc_floor_bottom_left.z
	var/list/old_turfs = list()
	for(var/turf/site in block(locate(29, 29, test_z), locate(35, 42, test_z)))
		old_turfs[site] = site.type
		site.ChangeTurf(/turf/open/floor/plating)
	for(var/y in 32 to 37)
		allocate((y == 32 || y == 37) ? /obj/structure/ms13_rail/blast_door/stop : /obj/structure/ms13_rail/blast_door, locate(31, y, test_z))
	for(var/x in 29 to 33)
		allocate(/obj/structure/ms13_rail, locate(x, 33, test_z))
	var/obj/machinery/power/ms13_rail_feeder/feeder = allocate(/obj/machinery/power/ms13_rail_feeder, locate(33, 33, test_z))
	var/datum/powernet/line = new
	allocated += line
	line.add_machine(feeder)
	line.avail = 1000000
	var/obj/structure/ms13_vehicle_frame/tram/blast_door/door = allocate(/obj/structure/ms13_vehicle_frame/tram/blast_door, locate(31, 30, test_z))
	door.id = console.id
	var/datum/ms13_ground_vehicle/rail/electric/blast_door/drive = door.vehicle
	if(!console.transmit_signal())
		Fail("The terminal did not dispatch its linked vehicle blast door.")
	for(var/tick in 1 to 120)
		if(!drive.moving)
			break
		drive.next_move_time = 0
		drive.movement_tick(drive.movement_generation)
	if(drive.moving || get_turf(drive.rail_frame()) != locate(31, 37, test_z))
		Fail("The terminal-controlled blast door did not reach its open stop.")
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in drive.frames.Copy())
		qdel(frame)
	for(var/turf/site as anything in old_turfs)
		site.ChangeTurf(old_turfs[site])
