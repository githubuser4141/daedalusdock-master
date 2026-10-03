/obj/machinery/ms13/terminal/ui_status(mob/user)
	return terminal_available(user) ? UI_INTERACTIVE : UI_CLOSE

/obj/machinery/ms13/terminal/proc/ensure_camera_views()
	if(!bodycam_viewer)
		bodycam_viewer = new(src)
	if(!camera_viewer)
		camera_viewer = new(src)
	bodycam_viewer.cam_screen.master_ref = WEAKREF(src)
	camera_viewer.cam_screen.master_ref = WEAKREF(src)
	camera_viewer.network = camera_network ? list(lowertext(camera_network)) : list()

/obj/machinery/ms13/terminal/proc/user_squad_action(mob/user)
	for(var/mob/living/carbon/human/ms13_squad/leader as anything in available_squad_units())
		var/datum/action/cooldown/ms13_squad_command/command = leader.command_action?.resolve()
		if(command?.owner == user && leader.can_command(user, src))
			return command

/obj/machinery/ms13/terminal/ui_close(mob/user)
	bodycam_viewer?.cam_screen.hide_from_client(user.client)
	camera_viewer?.cam_screen.hide_from_client(user.client)
	var/datum/action/cooldown/ms13_squad_command/command = user_squad_action(user)
	if(command?.terminal_ref?.resolve() == src && user.click_intercept == command)
		command.unset_click_ability(user)
	return ..()

/obj/machinery/ms13/terminal/ui_data(mob/user)
	var/list/data = list("mode" = mode, "system" = system, "workshopStatus" = workshop_status, "running" = workshop_running, "canManage" = can_manage_workshop(user))
	data["mainColor"] = main_color
	data["secondaryColor"] = secondary_color
	data["terminalTag"] = termtag
	data["terminalNumber"] = termnumber
	data["documents"] = list()
	for(var/slot in 1 to 5)
		if(vars["doc_title_[slot]"])
			data["documents"] += list(list("title" = vars["doc_title_[slot]"], "choice" = "doc_[slot]"))
	data["title"] = mode == 1 ? title : loaded_title
	data["content"] = mode == 1 ? note : loaded_content
	data["notekeeper"] = prog_notekeeper
	data["remote"] = remote_capability
	data["riggedTitle"] = rigged ? chosen_joker : null
	data["signals"] = list()
	if(remote_capability)
		var/list/choices = list("one", "two", "three", "four", "five", "six", "single")
		for(var/index in 1 to 7)
			var/label = index == 7 ? signal_title_single : vars["signal_title_[index]"]
			if(label && !(index == 7 && used))
				data["signals"] += list(list("title" = label, "choice" = "signal_[choices[index]]"))
	data["security"] = remote_capability && !!camera_network
	data["recruits"] = list()
	for(var/mob/living/carbon/human/ms13_squad/unit as anything in available_squad_units())
		data["recruits"] += list(list("ref" = REF(unit), "name" = unit.name, "squad" = unit.squad_id))
	var/datum/action/cooldown/ms13_squad_command/command = user_squad_action(user)
	if(command)
		data["command"] = command.ui_data(user)
		data["command"]["terminal"] = TRUE
	data["pods"] = list()
	for(var/obj/machinery/ms13/npc_cryopod/pod as anything in linked_cryopods())
		data["pods"] += list(list("ref" = REF(pod), "name" = pod.pod_id, "position" = "[pod.x], [pod.y], [pod.z]", "status" = pod.released ? "Empty" : (pod.is_operational ? pod.status : "Offline"), "ready" = !pod.released && pod.is_operational))
	data["queue"] = list()
	for(var/list/job as anything in workshop_queue)
		var/datum/crafting_recipe/recipe = job["recipe"]
		data["queue"] += recipe.name
	data["benches"] = list()
	if(mode == 4)
		for(var/obj/structure/bench as anything in workshop_benches())
			var/list/entry = list("ref" = REF(bench), "name" = bench.name, "recipes" = list())
			if(istype(bench, /obj/structure/ms13/pa_jack))
				var/obj/structure/ms13/pa_jack/hoist = bench
				entry["hoist"] = TRUE
				entry["mounted"] = !!hoist.obj_connected
				var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/armor = hoist.obj_connected
				entry["parts"] = list()
				if(armor)
					entry["armor"] = "[armor.name]: frame [armor.get_integrity_percentage()]%"
					entry["cell"] = armor.cell ? "[round(armor.cell.percent())]%" : "Not installed"
					for(var/zone in armor.module_armor)
						var/obj/item/ms13/power_armor/part = armor.module_armor[zone]
						if(part)
							entry["parts"] += "[part.name]: [part.get_integrity_percentage()]%"
			else
				var/datum/component/personal_crafting/crafting = bench.GetComponent(/datum/component/personal_crafting)
				for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
					if(recipe.name && crafting.knows_recipe(user, recipe))
						var/list/details = crafting.build_recipe_data(recipe)
						entry["recipes"] += list(list("ref" = REF(recipe), "name" = recipe.name, "materials" = details["req_text"], "tools" = details["tool_text"], "catalysts" = details["catalyst_text"]))
			data["benches"] += list(entry)
	if(mode == 7 || mode == 8)
		ensure_camera_views()
		var/obj/machinery/computer/security/viewer = mode == 7 ? bodycam_viewer : camera_viewer
		viewer.update_active_camera_screen()
		data["camera"] = viewer.ui_static_data() + viewer.ui_data()
		data["camera"]["online"] = !!viewer.active_camera?.can_use()
	return data

/// Native map clicks include the control name, which ClickOn() otherwise discards.
/client/Click(atom/object, atom/location, control, params)
	var/datum/action/cooldown/ms13_squad_command/command = mob?.click_intercept
	if(istype(command) && istext(control))
		var/list/control_path = splittext(control, ".")
		var/list/map_objects = screen_maps[control_path[length(control_path)]]
		for(var/atom/movable/screen/map_view/byondui/camera/map in map_objects)
			var/obj/machinery/ms13/terminal/terminal = map.master_ref?.resolve()
			if(istype(terminal))
				terminal.command_camera_click(mob, command, map, object, location, params)
				return
	return ..()

/obj/machinery/ms13/terminal/proc/command_camera_click(mob/user, datum/action/cooldown/ms13_squad_command/command, atom/movable/screen/map_view/byondui/camera/map, atom/object, atom/location, params)
	if(command.owner != user || user.click_intercept != command)
		return
	var/list/modifiers = params2list(params)
	command.unset_click_ability(user)
	if(modifiers[RIGHT_CLICK] || !camera_command_available(user, map))
		return
	var/atom/target = object
	if(istype(target, /atom/movable/screen) || !(get_turf(target) in map.vis_contents))
		target = (isturf(location) && (location in map.vis_contents)) ? location : map.ms13_clicked_turf(modifiers["screen-loc"])
	if(!target)
		return
	var/requested_order = command.pending_order
	var/datum/weakref/selected = command.selected_ref
	if(isturf(target) && (requested_order in list("Attack", "Destroy", "Breach", "Use", "Sit", "Follow", "Pick up")))
		var/list/candidates = list()
		if(ms13_demolition_target(target, TRUE) && (requested_order in list("Attack", "Destroy", "Breach")))
			candidates += target
		for(var/atom/movable/thing in target)
			if(thing.invisibility > user.see_invisible || !thing.mouse_opacity)
				continue
			switch(requested_order)
				if("Attack", "Destroy", "Breach")
					if(ms13_demolition_target(thing, requested_order != "Destroy") || (requested_order == "Attack" && isliving(thing)))
						candidates += thing
				if("Follow")
					if(isliving(thing))
						candidates += thing
				if("Pick up")
					if(isitem(thing) && !thing.anchored)
						candidates += thing
				if("Sit")
					if(istype(thing, /obj/structure/chair/ms13_vehicle_seat))
						candidates += thing
				if("Use")
					if(istype(thing, /obj/machinery/button) || istype(thing, /obj/machinery/door) || istype(thing, /obj/structure/mineral_door) || istype(thing, /obj/structure/window/ms13_vehicle_wall/solid/door))
						candidates += thing
		if(!length(candidates))
			to_chat(user, span_warning("No suitable [lowertext(requested_order)] target on that camera tile."))
			return
		target = length(candidates) == 1 ? candidates[1] : tgui_input_list(user, "Select the target on this tile", requested_order, candidates)
	if(QDELETED(command) || !target || command.pending_order != requested_order || command.selected_ref != selected || !camera_command_available(user, map))
		return
	// A door, wearer or camera may have moved while choosing a target.
	var/obj/machinery/computer/security/viewer = mode == 7 ? bodycam_viewer : camera_viewer
	viewer.last_camera_turf = null
	viewer.update_active_camera_screen()
	if(get_turf(target) in map.vis_contents)
		command.Activate(target, src)

/obj/machinery/ms13/terminal/proc/camera_command_available(mob/user, atom/movable/screen/map_view/byondui/camera/map)
	if(!user.client || !(user.client.weak_reference in map.viewing_clients) || !terminal_available(user) || !(mode in list(7, 8)))
		return FALSE
	var/obj/machinery/computer/security/viewer = mode == 7 ? bodycam_viewer : camera_viewer
	if(viewer?.cam_screen != map || !viewer.active_camera?.can_use())
		return FALSE
	var/list/cameras = viewer.get_available_cameras()
	return cameras[viewer.active_camera.c_tag] == viewer.active_camera && (mode != 8 || (remote_capability && camera_network))

/atom/movable/screen/map_view/byondui/camera/proc/ms13_clicked_turf(screen_position)
	if(!length(vis_contents) || !istext(screen_position))
		return null
	var/list/axes = splittext(screen_position, ",")
	if(length(axes) != 2)
		return null
	var/click_x = text2num(axes[1])
	var/click_y = text2num(axes[2])
	var/list/bounds = get_bbox_of_atoms(vis_contents)
	if(click_x < 1 || click_y < 1 || click_x > bounds[3] - bounds[1] + 1 || click_y > bounds[4] - bounds[2] + 1)
		return null
	var/turf/origin = vis_contents[1]
	var/turf/target = locate(bounds[1] + round(click_x) - 1, bounds[2] + round(click_y) - 1, origin.z)
	return (target in vis_contents) ? target : null

/obj/machinery/ms13/terminal/ui_act(action, list/params)
	if(..() || !terminal_available(usr))
		return
	if(action in list("command", "switch_camera", "page", "legacy"))
		playsound(src, pick('mojave/sound/ms13machines/terminals/ui_hacking_charenter_01.ogg', 'mojave/sound/ms13machines/terminals/ui_hacking_charenter_02.ogg', 'mojave/sound/ms13machines/terminals/ui_hacking_charenter_03.ogg'), 50, FALSE)
	if(action == "command")
		var/datum/action/cooldown/ms13_squad_command/command = user_squad_action(usr)
		if(!command)
			return
		command.terminal_ref = WEAKREF(src)
		var/key = params["command"]
		if(!(key in list("unit", "order", "fire_mode", "breach_mode", "release", "cancel", "coordinates")))
			return
		var/list/href = list()
		href[key] = params["value"] || "1"
		command.Topic(null, href)
		return TRUE
	if(action == "switch_camera" && (mode == 7 || (mode == 8 && remote_capability && camera_network)))
		ensure_camera_views()
		var/obj/machinery/computer/security/viewer = mode == 7 ? bodycam_viewer : camera_viewer
		var/list/cameras = viewer.get_available_cameras()
		viewer.active_camera = cameras[params["name"]]
		viewer.last_camera_turf = null
		viewer.update_active_camera_screen()
		return TRUE
	if(action == "page")
		var/page = text2num(params["mode"])
		if(!(page in list(0, 1, 3, 4, 5, 6, 7, 8)))
			return
		var/datum/action/cooldown/ms13_squad_command/command = user_squad_action(usr)
		if(command && usr.click_intercept == command)
			command.unset_click_ability(usr)
		mode = page
		return TRUE
	if(action == "legacy")
		var/choice = params["choice"]
		if(!(choice in list("Title", "Contents", "Save", "doc_1", "doc_2", "doc_3", "doc_4", "doc_5", "joker", "signal_one", "signal_two", "signal_three", "signal_four", "signal_five", "signal_six", "signal_single", "workshop_queue", "workshop_start", "workshop_stop", "workshop_hoist", "squad", "cryo_wake")))
			return
		Topic(null, params)
		return TRUE
