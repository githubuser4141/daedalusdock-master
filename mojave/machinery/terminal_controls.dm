/obj/machinery/ms13/terminal/control
	name = "facility control terminal"
	remote_capability = TRUE
	active = TRUE

/obj/machinery/ms13/terminal/proc/terminal_available(mob/user)
	return !QDELETED(user) && !broken && active && is_operational && (!password_needed || unlocked) && user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY)

/obj/machinery/ms13/terminal/power_change()
	. = ..()
	FXtoggle()

/// Only mapped buttons are accepted; a forged href cannot supply an arbitrary circuit ID.
/obj/machinery/ms13/terminal/proc/activate_link(choice, mob/user)
	if(!remote_capability || !terminal_available(user))
		return FALSE
	var/list/channels = list("signal_one" = signal_id_1, "signal_two" = signal_id_2, "signal_three" = signal_id_3, "signal_four" = signal_id_4, "signal_five" = signal_id_5, "signal_six" = signal_id_6, "signal_single" = signal_id_single)
	if(!(choice in channels) || (choice == "signal_single" && used))
		return FALSE
	id = channels[choice]
	var/changed = transmit_signal(user)
	if(changed && choice == "signal_single")
		used = TRUE
	to_chat(user, changed ? span_notice("Control signal sent to [changed] linked device\s.") : span_warning("No available devices answered this circuit. Check its ID, power and locks."))
	return changed

/// Preserve the old poddoor IDs and use id_tag for powered doors and utility boxes.
/obj/machinery/ms13/terminal/proc/transmit_signal(mob/user)
	if(!remote_capability || !id || id == "null")
		return 0
	. = ms13_switch_power(id, user)
	var/list/doors = list()
	var/opening = FALSE
	for(var/obj/machinery/door/door as anything in INSTANCES_OF(/obj/machinery/door))
		var/linked = door.id_tag == id
		if(istype(door, /obj/machinery/door/poddoor))
			var/obj/machinery/door/poddoor/shutter = door
			linked ||= shutter.id == id
		if(!linked || door.operating || !door.is_operational)
			continue
		if(istype(door, /obj/machinery/door/unpowered))
			if(!istype(door, /obj/machinery/door/unpowered/ms13))
				continue
			var/obj/machinery/door/unpowered/ms13/motor_door = door
			if(!motor_door.motorised || motor_door.bolted || !motor_door.motor_powered())
				continue
		doors += door
		opening ||= door.density
	for(var/obj/machinery/door/door as anything in doors)
		if(door.density != opening)
			continue
		if(istype(door, /obj/machinery/door/unpowered/ms13))
			var/obj/machinery/door/unpowered/ms13/motor_door = door
			. += !!motor_door.run_motor()
			continue
		INVOKE_ASYNC(door, opening ? TYPE_PROC_REF(/obj/machinery/door, open) : TYPE_PROC_REF(/obj/machinery/door, close))
		.++
	for(var/obj/structure/ms13_vehicle_frame/tram/blast_door/door as anything in GLOB.ms13_blast_doors)
		if(door.id == id && door.toggle())
			.++

/// Toggle all matching breakers together, using the APC's normal power propagation.
/proc/ms13_switch_power(channel, mob/user)
	if(!channel || channel == "null")
		return 0
	var/list/boxes = list()
	var/turn_on = FALSE
	for(var/obj/machinery/power/apc/box as anything in INSTANCES_OF(/obj/machinery/power/apc))
		if(box.id_tag != channel || !box.area || !box.is_operational || box.failure_timer)
			continue
		boxes += box
		turn_on ||= !box.operating
	. = 0
	for(var/obj/machinery/power/apc/box as anything in boxes)
		if(box.operating != turn_on)
			box.toggle_breaker(user)
			.++

// A conduit is the existing wired, cell-less utility box with an explicit mapper-facing purpose.
/obj/machinery/power/apc/ms13/conduit
	name = "remote power conduit"
	desc = "An industrial area power switch rated for plant voltage. Click to flip its breaker, or operate it remotely with a switch or terminal sharing its circuit ID."

// This is industrial switchgear, not the household fusebox that burns out on plant voltage.
/obj/machinery/power/apc/ms13/conduit/suffer_grid(datum/powernet/line)
	return FALSE

/obj/machinery/power/apc/ms13/conduit/interact(mob/user)
	if(!can_interact(user) || !can_use(user) || (machine_stat & MAINT) || failure_timer)
		return
	add_fingerprint(user)
	toggle_breaker(user)
	to_chat(user, span_notice("You switch [src] [operating ? "on" : "off"]."))
	return TRUE

/obj/machinery/power/apc/ms13/conduit/ui_interact(mob/user, datum/tgui/ui)
	return

/obj/machinery/power/apc/ms13/conduit/ui_status(mob/user)
	return UI_CLOSE

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/power/apc/ms13/conduit, APC_PIXEL_OFFSET)

/obj/item/assembly/control/ms13_power
	name = "power breaker controller"
	desc = "Controls utility boxes sharing its circuit ID."

/obj/item/assembly/control/ms13_power/activate()
	if(cooldown)
		return
	cooldown = TRUE
	. = ms13_switch_power(id, usr)
	addtimer(VARSET_CALLBACK(src, cooldown, FALSE), 1 SECONDS)

/obj/machinery/button/ms13_power
	name = "remote power switch"
	desc = "A manual remote breaker switch. It works even when this room is dark."
	use_power = NO_POWER_USE
	device_type = /obj/item/assembly/control/ms13_power

MAPPING_DIRECTIONAL_HELPERS_ROBUST_INVERSE_DIR(/obj/machinery/button/ms13_power, 28, -20, 21, -21)

/// Use the existing camera UI, including its map rendering and disconnect cleanup.
/obj/machinery/ms13/terminal/proc/open_cameras(mob/user)
	if(!remote_capability || !camera_network || !terminal_available(user))
		return FALSE
	if(!camera_viewer)
		camera_viewer = new(src)
	camera_viewer.network = list(lowertext(camera_network))
	camera_viewer.ui_interact(user)
	return TRUE

/obj/machinery/computer/security/ms13_terminal_viewer
	name = "terminal security cameras"
	use_power = NO_POWER_USE
	circuit = null

/obj/machinery/computer/security/ms13_terminal_viewer/ui_status(mob/user)
	var/obj/machinery/ms13/terminal/host = loc
	return istype(host) && host.remote_capability && host.camera_network && host.terminal_available(user) ? UI_INTERACTIVE : UI_CLOSE

/obj/machinery/computer/security/ms13_terminal_viewer/get_available_cameras()
	. = list()
	var/turf/host_turf = get_turf(src)
	for(var/obj/machinery/camera/camera as anything in GLOB.cameranet.cameras)
		if(!islist(camera.network) || !length(camera.network & network))
			continue
		if((is_away_level(host_turf.z) || is_away_level(camera.z)) && host_turf.z != camera.z)
			continue
		.[camera.c_tag] = camera

#ifdef UNIT_TESTS
#include "terminal_controls_unit_test.dm"
#endif
