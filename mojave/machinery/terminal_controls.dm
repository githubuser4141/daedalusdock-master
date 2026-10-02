/obj/machinery/ms13/terminal/control
	name = "facility control terminal"
	remote_capability = TRUE
	active = TRUE

/obj/machinery/ms13/terminal
	var/list/workshop_queue = list()
	var/workshop_running = FALSE
	var/workshop_cancelled = FALSE
	var/datum/weakref/workshop_operator
	var/workshop_status = "Ready. Queue recipes, then start work."

/obj/machinery/ms13/terminal/proc/terminal_available(mob/user)
	return !QDELETED(user) && !broken && active && is_operational && (!password_needed || unlocked) && user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY)

/// Adjacent workbenches are local peripherals; no mapper IDs or permanent references are needed.
/obj/machinery/ms13/terminal/proc/workshop_benches()
	. = list()
	var/turf/ground = get_turf(src)
	if(!ground)
		return
	for(var/obj/structure/bench in range(1, ground))
		if(Adjacent(bench) && (istype(bench, /obj/structure/ms13/pa_jack) || bench.GetComponent(/datum/component/personal_crafting)))
			. += bench

/obj/machinery/ms13/terminal/proc/open_workbench(obj/structure/bench, mob/user)
	if(!terminal_available(user) || !(bench in workshop_benches()))
		return FALSE
	var/datum/component/personal_crafting/crafting = bench.GetComponent(/datum/component/personal_crafting)
	if(!crafting || crafting.work_terminal)
		return FALSE
	crafting.ui_interact(user)
	return TRUE

/// A shared terminal can be browsed by everyone, but only its operator can change an active queue.
/obj/machinery/ms13/terminal/proc/can_manage_workshop(mob/user)
	return terminal_available(user) && (!workshop_running || workshop_operator?.resolve() == user)

/obj/machinery/ms13/terminal/proc/queue_recipe(obj/structure/bench, datum/crafting_recipe/recipe, mob/user)
	if(!can_manage_workshop(user) || length(workshop_queue) >= 20 || !(bench in workshop_benches()) || !(recipe in GLOB.crafting_recipes))
		return FALSE
	var/datum/component/personal_crafting/crafting = bench.GetComponent(/datum/component/personal_crafting)
	if(!crafting?.knows_recipe(user, recipe))
		return FALSE
	workshop_queue += list(list("bench" = WEAKREF(bench), "recipe" = recipe))
	return TRUE

/obj/machinery/ms13/terminal/proc/start_workshop(mob/user)
	if(workshop_running || !length(workshop_queue) || !can_manage_workshop(user))
		return FALSE
	workshop_cancelled = FALSE
	workshop_running = TRUE
	workshop_operator = WEAKREF(user)
	INVOKE_ASYNC(src, PROC_REF(run_workshop), user)
	return TRUE

/obj/machinery/ms13/terminal/proc/stop_workshop(mob/user)
	if(!can_manage_workshop(user))
		return FALSE
	workshop_queue.Cut()
	workshop_cancelled = TRUE
	workshop_status = workshop_running ? "Stopping current work..." : "Queue cleared."
	return TRUE

/obj/machinery/ms13/terminal/proc/run_workshop(mob/user)
	while(length(workshop_queue) && !QDELETED(src) && !workshop_cancelled)
		var/list/job = workshop_queue[1]
		var/datum/weakref/bench_ref = job["bench"]
		var/obj/structure/bench = bench_ref.resolve()
		var/datum/crafting_recipe/recipe = job["recipe"]
		var/datum/component/personal_crafting/crafting = bench?.GetComponent(/datum/component/personal_crafting)
		if(!terminal_available(user) || !(bench in workshop_benches()) || !crafting || crafting.busy)
			workshop_status = "Paused: check terminal power, access, and the selected bench."
			break
		crafting.busy = TRUE
		crafting.work_terminal = WEAKREF(src)
		workshop_status = "Working: [recipe.name]. Remain at the terminal."
		if(user.client)
			ui_interact(user)
		var/result = crafting.construct_item(user, recipe)
		crafting.work_terminal = null
		crafting.busy = FALSE
		if(QDELETED(src))
			return
		if(istext(result))
			workshop_status = workshop_cancelled ? "Work stopped." : "Paused: [recipe.name][result] Check ingredients, tools and access, then start again."
			break
		var/atom/movable/product = result
		user.investigate_log("[key_name(user)] crafted [recipe] at [src]", INVESTIGATE_CRAFTING)
		recipe.on_craft_completion(user, product)
		workshop_queue.Cut(1, 2)
		workshop_status = "Completed: [recipe.name]."
	workshop_running = FALSE
	workshop_operator = null
	if(!QDELETED(user) && user.client && terminal_available(user))
		ui_interact(user)

/// Keep the workshop in the terminal's existing RobCo screen.
/obj/machinery/ms13/terminal/proc/workshop_html(mob/user)
	. = "[html_encode(workshop_status)]<br>Queue: [length(workshop_queue)]/20"
	. += "<br><a href='byond://?src=[REF(src)];choice=workshop_start'>\> Start / Resume</a>"
	. += " <a href='byond://?src=[REF(src)];choice=workshop_stop'>\> Stop / Clear</a><br>"
	for(var/index in 1 to length(workshop_queue))
		var/list/job = workshop_queue[index]
		var/datum/crafting_recipe/recipe = job["recipe"]
		. += "<br>[index]. [html_encode(recipe.name)]"
	. += "<hr><input type='text' placeholder='Search all connected recipes...' style='width:95%' oninput=\"var rows=document.querySelectorAll('.workshop-recipe');for(var i=0;i&lt;rows.length;i++){rows.item(i).style.display=rows.item(i).innerText.toLowerCase().indexOf(this.value.toLowerCase())&gt;=0?'':'none';}\"><br>"
	var/list/benches = workshop_benches()
	if(!length(benches))
		. += "No equipment connected. Place a workbench, chemistry set or power armor hoist beside this terminal."
	for(var/obj/structure/bench as anything in benches)
		if(istype(bench, /obj/structure/ms13/pa_jack))
			var/obj/structure/ms13/pa_jack/hoist = bench
			var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/armor = hoist.obj_connected
			. += "<hr><b>[html_encode(hoist.name)]</b><br>"
			if(armor)
				. += "[html_encode(armor.name)]: frame [armor.get_integrity_percentage()]%"
				. += "<br>Cell: [armor.cell ? "[round(armor.cell.percent())]%" : "Not installed"]"
				for(var/zone in armor.module_armor)
					var/obj/item/ms13/power_armor/part = armor.module_armor[zone]
					if(part)
						. += "<br>[html_encode(part.name)]: [part.get_integrity_percentage()]%"
			else
				. += "No armor mounted. Place an unoccupied frame on the hoist."
			. += "<br><a href='byond://?src=[REF(src)];choice=workshop_hoist;bench=[REF(bench)]'>\> [armor ? "Release armor" : "Mount armor"]</a>"
			continue
		var/datum/component/personal_crafting/crafting = bench.GetComponent(/datum/component/personal_crafting)
		. += "<hr><b>[html_encode(bench.name)]</b> <a href='byond://?src=[REF(src)];choice=workbench;bench=[REF(bench)]'>\> Open bench controls</a>"
		for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
			if(!recipe.name || !crafting.knows_recipe(user, recipe))
				continue
			var/list/details = crafting.build_recipe_data(recipe)
			. += "<div class='workshop-recipe'><hr><b>[html_encode(recipe.name)]</b> ([html_encode(bench.name)])"
			. += "<br>Requires: [html_encode(details["req_text"])]"
			if(details["tool_text"])
				. += "<br>Tools: [html_encode(details["tool_text"])]"
			if(details["catalyst_text"])
				. += "<br>Catalyst: [html_encode(details["catalyst_text"])]"
			. += "<br><a href='byond://?src=[REF(src)];choice=workshop_queue;bench=[REF(bench)];recipe=[REF(recipe)]'>\> Queue recipe</a></div>"

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
	var/list/conduits = list()
	for(var/obj/machinery/power/apc/ms13/conduit/conduit as anything in INSTANCES_OF(/obj/machinery/power/apc/ms13/conduit))
		if(conduit.id_tag != channel || !conduit.is_operational)
			continue
		conduits += conduit
		turn_on ||= !conduit.operating
	. = 0
	for(var/obj/machinery/power/apc/box as anything in boxes)
		if(box.operating != turn_on)
			box.toggle_breaker(user)
			.++
	for(var/obj/machinery/power/apc/ms13/conduit/conduit as anything in conduits)
		if(conduit.operating != turn_on)
			conduit.toggle_breaker(user)
			.++

// Keep the mapped path, but do not inherit APC area ownership or household fusebox processing.
DEFINE_INTERACTABLE(/obj/machinery/power/apc/ms13/conduit)
/obj/machinery/power/apc/ms13/conduit
	parent_type = /obj/machinery/power
	name = "remote power conduit"
	desc = "An inline cable switch. Place it over the wire to interrupt connections through this tile. Click to toggle, or use a remote switch or terminal with the same circuit ID. Alternate cable routes can still carry power."
	icon = 'icons/obj/apc.dmi'
	icon_state = "apc0"
	max_integrity = 200
	integrity_failure = 0.25
	var/operating = TRUE

/obj/machinery/power/apc/ms13/conduit/Initialize(mapload)
	. = ..()
	SET_TRACKING(__TYPE__)
	if(SSmachines.initialized)
		ms13_rebuild_cables_at(get_turf(src))
	update_appearance()

/obj/machinery/power/apc/ms13/conduit/Destroy()
	UNSET_TRACKING(__TYPE__)
	// QDELETED switches no longer block the still-present wire.
	ms13_rebuild_cables_at(get_turf(src))
	return ..()

/obj/machinery/power/apc/ms13/conduit/Moved(atom/old_loc, movement_dir, forced, list/old_locs)
	. = ..()
	if(initialized && old_loc != loc)
		ms13_rebuild_cables_at(get_turf(old_loc))
		ms13_rebuild_cables_at(get_turf(src))

/obj/machinery/power/apc/ms13/conduit/atom_break(damage_flag)
	. = ..()
	if(operating)
		toggle_breaker()

/obj/machinery/power/apc/ms13/conduit/proc/toggle_breaker(mob/user)
	operating = !operating
	ms13_rebuild_cables_at(get_turf(src))
	update_appearance()
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)

/obj/machinery/power/apc/ms13/conduit/update_overlays()
	. = ..()
	var/mutable_appearance/indicator = mutable_appearance(icon, "apco0")
	indicator.color = operating && is_operational ? COLOR_LIME : COLOR_RED
	. += indicator

/obj/machinery/power/apc/ms13/conduit/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/scrap_parts(drop_location(), 2)
	qdel(src)

/obj/machinery/power/apc/ms13/conduit/interact(mob/user)
	if(!is_operational || !can_interact(user) || !user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY))
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

/// Both ends of each cable connection must agree, including when new cables are laid later.
/proc/ms13_conduit_blocks(turf/site)
	for(var/obj/machinery/power/apc/ms13/conduit/conduit in site)
		if(!QDELETED(conduit) && !conduit.operating)
			return TRUE
	return FALSE

/obj/structure/cable/get_cable_connections(powernetless_only = FALSE, ignore_conduits = FALSE)
	. = ..(powernetless_only)
	for(var/turf/other_level as anything in ms13_stair_cable_turfs(get_turf(src)))
		for(var/obj/structure/cable/other in other_level)
			if(!powernetless_only || !other.powernet)
				. |= other
	if(ignore_conduits)
		return
	if(ms13_conduit_blocks(get_turf(src)))
		return list()
	var/list/connections = .
	for(var/obj/structure/cable/other as anything in connections.Copy())
		if(ms13_conduit_blocks(get_turf(other)))
			. -= other

/// Reuse the normal cable flood fill, once per affected connected component. No per-tick conduit work.
/proc/ms13_rebuild_cables_at(turf/site)
	if(!site || !SSmachines.initialized)
		return
	var/list/seeds = list()
	for(var/obj/structure/cable/cable in site)
		seeds |= cable
		seeds |= cable.get_cable_connections(ignore_conduits = TRUE)
	var/list/rebuilt = list()
	for(var/obj/structure/cable/cable as anything in seeds)
		if(cable.powernet in rebuilt)
			continue
		var/datum/powernet/line = new
		propagate_network(cable, line)
		rebuilt += line

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
