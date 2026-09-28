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
	var/obj/machinery/power/apc/ms13/conduit/box = allocate(/obj/machinery/power/apc/ms13/conduit, get_step(origin, EAST))
	var/area/powered_area = new
	allocated += powered_area
	box.area = powered_area
	box.id_tag = console.id
	box.set_machine_stat(NONE)
	var/datum/powernet/plant_line = new
	allocated += plant_line
	plant_line.ms13_voltage = MS13_VOLTAGE_HIGH
	plant_line.ms13_ripple = 1
	for(var/tick in 1 to 40)
		box.suffer_grid(plant_line)
	if((box.machine_stat & BROKEN) || box.surged)
		Fail("An industrial conduit inherited household fusebox burnout on plant voltage.")
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
	operator.forceMove(get_step(box, SOUTH))
	click_wrapper(operator, box)
	if(box.operating || powered_area.power_light || box.ui_status(operator) != UI_CLOSE)
		Fail("Clicking a conduit did not switch it off without an APC UI.")
	click_wrapper(operator, box)
	if(!box.operating || !powered_area.power_light || !powered_area.power_equip)
		Fail("Clicking an off conduit did not restore area power.")
	box.set_machine_stat(BROKEN)
	click_wrapper(operator, box)
	if(!box.operating)
		Fail("A click operated a broken conduit.")
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
