#ifndef MS13_SQUAD_COMMANDS_INCLUDED
#define MS13_SQUAD_COMMANDS_INCLUDED

/mob/living/carbon/human/ms13_squad
	var/is_squad_leader = FALSE
	var/datum/weakref/commander
	var/datum/weakref/command_action

/mob/living/carbon/human/ms13_squad/leader
	name = "squad leader"
	is_squad_leader = TRUE

/mob/living/carbon/human/ms13_squad/Destroy()
	var/datum/action/action = command_action?.resolve()
	QDEL_NULL(action)
	commander = null
	command_action = null
	return ..()

/mob/living/carbon/human/ms13_squad/examine(mob/user)
	. = ..()
	. += span_notice("Alt-click to recruit or open command mode. An unassigned recruit joins your nearby squad, or becomes its leader if you have none nearby.")

/mob/living/carbon/human/ms13_squad/AltClick(mob/user)
	var/mob/living/carbon/human/ms13_squad/leader = recruit(user)
	leader?.open_commands(user)

/// Shared by field clicks and terminal recruitment. Explicit mapper squads stay separate.
/mob/living/carbon/human/ms13_squad/proc/recruit(mob/living/user, obj/machinery/ms13/terminal/terminal)
	if(!istype(user) || stat != CONSCIOUS || client || user.incapacitated())
		to_chat(user, span_warning("Only an available NPC can accept a living commander's orders."))
		return null
	if(terminal)
		if(!terminal.terminal_available(user) || !(src in terminal.available_squad_units()))
			return null
	else if(!Adjacent(user) || !IsReachableBy(user) || !user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY))
		to_chat(user, span_warning("Stand next to [src] to recruit them."))
		return null
	var/mob/living/carbon/human/ms13_squad/leader = squad_leader()
	if(!squad_id && !is_squad_leader)
		var/nearest = 8
		for(var/mob/living/carbon/human/ms13_squad/candidate as anything in GLOB.ms13_squad_units)
			if(!candidate.is_squad_leader || candidate.commander?.resolve() != user || candidate.stat != CONSCIOUS || candidate.client || candidate.z != z)
				continue
			if(terminal?.squad_id ? candidate.squad_id == terminal.squad_id : get_dist(src, candidate) < nearest)
				leader = candidate
				nearest = get_dist(src, candidate)
		if(terminal?.squad_id && !leader)
			to_chat(user, span_warning("Take command of this terminal's assigned squad before recruiting into it."))
			return null
		if(leader)
			squad_id = leader.squad_id
	if(!leader)
		leader = src
	if(leader.commander?.resolve() != user && !leader.claim_command(user, terminal))
		return null
	if(terminal && !terminal.squad_id)
		terminal.squad_id = leader.squad_id
	to_chat(user, span_notice("[src] reports to squad [html_encode(leader.squad_id)]."))
	return leader

/mob/living/carbon/human/ms13_squad/proc/claim_command(mob/living/user, obj/machinery/ms13/terminal/terminal)
	if(!istype(user) || stat != CONSCIOUS || client || user.incapacitated())
		return FALSE
	if(terminal)
		if(!terminal.terminal_available(user) || !(src in terminal.available_squad_units()))
			return FALSE
	else if(!Adjacent(user) || !IsReachableBy(user) || !user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY))
		to_chat(user, span_warning("Stand next to the squad leader to take command."))
		return
	var/mob/current = commander?.resolve()
	if(current && current != user && current.stat != DEAD)
		to_chat(user, span_warning("This squad already has a commander."))
		return FALSE
	var/list/former_leaders = list()
	if(squad_id)
		for(var/mob/living/carbon/human/ms13_squad/leader as anything in GLOB.ms13_squad_units)
			if(leader == src || leader.squad_id != squad_id || !leader.is_squad_leader)
				continue
			current = leader.commander?.resolve()
			if(leader.stat != DEAD || (current && current != user && current.stat != DEAD))
				to_chat(user, span_warning("This squad already has a leader or a living commander."))
				return FALSE
			former_leaders += leader
	// Keep ownership through a leader's death, and keep revived leaders subordinate.
	for(var/mob/living/carbon/human/ms13_squad/leader as anything in former_leaders)
		leader.is_squad_leader = FALSE
		leader.commander = null
		var/datum/action/action = leader.command_action?.resolve()
		QDEL_NULL(action)
		leader.command_action = null
	if(!squad_id)
		squad_id = "Squad [REF(src)]"
	is_squad_leader = TRUE
	commander = WEAKREF(user)
	return TRUE

/mob/living/carbon/human/ms13_squad/proc/members()
	var/list/units = list()
	if(!squad_id)
		return units
	for(var/mob/living/carbon/human/ms13_squad/unit as anything in GLOB.ms13_squad_units)
		if(unit.squad_id == squad_id && unit.stat != DEAD && !QDELETED(unit))
			units += unit
	return units

/// One authorization path for HUD orders, terminal orders, and their delayed prompts.
/mob/living/carbon/human/ms13_squad/proc/can_command(mob/living/user, obj/machinery/ms13/terminal/terminal)
	if(QDELETED(user) || commander?.resolve() != user || stat != CONSCIOUS || client || user.incapacitated() || !squad_id || squad_leader() != src)
		return FALSE
	if(terminal)
		var/turf/terminal_turf = get_turf(terminal)
		return !QDELETED(terminal) && (src in terminal.available_squad_units()) && terminal_turf?.z == z && terminal.Adjacent(user) && terminal.IsReachableBy(user) && terminal.terminal_available(user)
	return user.z == z && get_dist(user, src) <= 30

/mob/living/carbon/human/ms13_squad/proc/open_commands(mob/living/user, obj/machinery/ms13/terminal/terminal)
	if(!can_command(user, terminal))
		return
	var/datum/action/cooldown/ms13_squad_command/action = command_action?.resolve()
	if(!action || action.owner != user)
		QDEL_NULL(action)
		action = new(src)
		action.leader_ref = WEAKREF(src)
		action.Grant(user)
		command_action = WEAKREF(action)
	if(user.click_intercept == action)
		action.unset_click_ability(user)
	action.terminal_ref = terminal ? WEAKREF(terminal) : null
	action.show_panel()

/mob/living/carbon/human/ms13_squad/proc/issue_order(mob/living/user, new_order, atom/target, mob/living/carbon/human/ms13_squad/selected, obj/machinery/ms13/terminal/terminal)
	if(!can_command(user, terminal) || !(new_order in GLOB.ms13_squad_orders))
		return FALSE
	var/list/units = members()
	if(selected)
		if(!(selected in units))
			return FALSE
		units = list(selected)
	if(new_order != "Hold")
		if(QDELETED(target) || istype(target, /atom/movable/screen) || !get_turf(target) || target.z != z || get_dist(src, target) > 30)
			return FALSE
		if(!terminal && !(get_turf(target) in view(user.client?.view || world.view, user)))
			return FALSE
		switch(new_order)
			if("Attack")
				if(!isliving(target) || squad_friendly(target))
					return FALSE
			if("Follow")
				if(!isliving(target) || !squad_friendly(target))
					return FALSE
			if("Use")
				if(!istype(target, /obj/machinery/button) && !istype(target, /obj/machinery/door) && !istype(target, /obj/structure/mineral_door) && !istype(target, /obj/structure/window/ms13_vehicle_wall/solid/door))
					return FALSE
			if("Sit")
				if(!istype(target, /obj/structure/chair/ms13_vehicle_seat))
					return FALSE
			if("Break")
				if(!istype(target, /obj/structure))
					return FALSE
			if("Pick up")
				if(!isitem(target) || !isturf(target.loc))
					return FALSE
				var/obj/item/item = target
				if(item.anchored || item.item_flags & ABSTRACT)
					return FALSE
			else
				if(new_order != "Follow")
					target = get_turf(target)
	var/direction = new_order == "Fire direction" ? get_dir(src, target) : NONE
	if(new_order == "Fire direction" && !direction)
		return FALSE
	// Object work belongs to one recruit, so the squad never races to grab or toggle the same object.
	if(!selected && (new_order in list("Use", "Break", "Pick up", "Deliver", "Sit")))
		to_chat(user, span_warning("Select an individual recruit for object work."))
		return FALSE
	var/issued = FALSE
	for(var/mob/living/carbon/human/ms13_squad/unit as anything in units)
		if(unit.client || unit.stat != CONSCIOUS || unit.z != z || get_dist(src, unit) > 30)
			continue
		if(new_order == "Follow" && unit == target)
			continue
		unit.set_order(new_order, target, direction)
		issued = TRUE
	return issued

/mob/living/carbon/human/ms13_squad/proc/issue_fire_mode(mob/living/user, new_mode, mob/living/carbon/human/ms13_squad/selected, obj/machinery/ms13/terminal/terminal)
	if(!can_command(user, terminal) || !(new_mode in GLOB.ms13_squad_fire_modes))
		return FALSE
	var/list/units = members()
	if(selected)
		if(!(selected in units))
			return FALSE
		units = list(selected)
	var/issued = FALSE
	for(var/mob/living/carbon/human/ms13_squad/unit as anything in units)
		if(unit.client || unit.stat != CONSCIOUS || unit.z != z || get_dist(src, unit) > 30)
			continue
		unit.fire_mode = new_mode
		unit.reset_aim()
		issued = TRUE
	return issued

/datum/action/cooldown/ms13_squad_command
	name = "Squad command"
	desc = "Choose orders, then designate a target. Right-click cancels designation."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "bci_network"
	check_flags = AB_CHECK_CONSCIOUS
	click_to_activate = TRUE
	var/datum/weakref/leader_ref
	var/datum/weakref/terminal_ref
	var/datum/weakref/selected_ref
	var/pending_order = "Move"

/datum/action/cooldown/ms13_squad_command/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/carbon/human/ms13_squad/leader = leader_ref?.resolve()
	var/obj/machinery/ms13/terminal/terminal = terminal_ref?.resolve()
	if(terminal_ref && !terminal)
		return FALSE
	return leader?.can_command(owner, terminal)

/datum/action/cooldown/ms13_squad_command/Trigger(trigger_flags, atom/target)
	if(owner?.click_intercept == src)
		unset_click_ability(owner)
	// The HUD always opens field command, even after leaving a linked terminal.
	terminal_ref = null
	if(IsAvailable())
		show_panel()
	return TRUE

/datum/action/cooldown/ms13_squad_command/proc/show_panel()
	if(!IsAvailable())
		return
	var/obj/machinery/ms13/terminal/terminal = terminal_ref?.resolve()
	if(terminal)
		terminal.mode = 5
		terminal.ui_interact(owner)
		return
	ui_interact(owner)

/datum/action/cooldown/ms13_squad_command/ui_interact(mob/user, datum/tgui/ui)
	if(user != owner || !IsAvailable())
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MS13Squad", name)
		ui.open()

/datum/action/cooldown/ms13_squad_command/ui_status(mob/user)
	return user == owner && IsAvailable() ? UI_INTERACTIVE : UI_CLOSE

/datum/action/cooldown/ms13_squad_command/ui_data(mob/user)
	var/mob/living/carbon/human/ms13_squad/leader = leader_ref.resolve()
	var/mob/living/carbon/human/ms13_squad/selected = selected_ref?.resolve()
	var/list/roster = list()
	for(var/mob/living/carbon/human/ms13_squad/unit as anything in leader.members())
		roster += list(list("ref" = REF(unit), "name" = unit.name, "position" = "[unit.x], [unit.y], [unit.z]", "order" = unit.squad_order, "status" = unit.order_status, "fireMode" = unit.fire_mode, "ready" = unit.stat == CONSCIOUS && !unit.client))
	return list("squad" = leader.squad_id, "units" = roster, "selected" = selected ? REF(selected) : "all", "orders" = GLOB.ms13_squad_orders, "fireModes" = list("Careful", "Precise", "Rapid"), "pending" = pending_order, "designating" = owner.click_intercept == src, "terminal" = !!terminal_ref)

/datum/action/cooldown/ms13_squad_command/ui_act(action, list/params)
	if(..() || usr != owner || !IsAvailable())
		return
	if(action in list("unit", "order", "fire_mode", "release", "cancel", "coordinates"))
		var/list/command = list()
		command[action] = params["value"] || "1"
		Topic(null, command)
		return TRUE

/datum/action/cooldown/ms13_squad_command/ui_close(mob/user)
	if(user == owner && owner.click_intercept == src)
		unset_click_ability(owner)
	return ..()

/datum/action/cooldown/ms13_squad_command/InterceptClickOn(mob/living/invoker, params, atom/target)
	if(istype(target, /atom/movable/screen/movable/action_button))
		unset_click_ability(invoker)
		return FALSE
	var/list/modifiers = islist(params) ? params : params2list(params)
	var/available = IsAvailable()
	unset_click_ability(invoker)
	if(modifiers?[RIGHT_CLICK] || !available)
		return TRUE
	Activate(target)
	return TRUE

/datum/action/cooldown/ms13_squad_command/set_click_ability(mob/on_who)
	ranged_mousepointer = (pending_order in list("Attack", "Break", "Fire at area", "Fire direction")) ? 'icons/effects/mouse_pointers/weapon_pointer.dmi' : 'icons/effects/mouse_pointers/interact.dmi'
	. = ..()
	START_PROCESSING(SSfastprocess, src)

/datum/action/cooldown/ms13_squad_command/process()
	if(!owner || owner.click_intercept != src)
		STOP_PROCESSING(SSfastprocess, src)
		return
	if(!IsAvailable())
		unset_click_ability(owner)

/datum/action/cooldown/ms13_squad_command/Topic(href, list/href_list)
	if(usr != owner || !IsAvailable())
		return
	var/mob/living/carbon/human/ms13_squad/leader = leader_ref.resolve()
	if(href_list["cancel"] && owner.click_intercept == src)
		unset_click_ability(owner)
	if(href_list["unit"])
		var/mob/living/carbon/human/ms13_squad/unit = locate(href_list["unit"]) in leader.members()
		if(href_list["unit"] != "all" && !unit)
			return
		if(owner.click_intercept == src)
			unset_click_ability(owner)
		selected_ref = unit ? WEAKREF(unit) : null
	if(href_list["release"])
		leader.issue_order(owner, "Hold", null, null, terminal_ref?.resolve())
		leader.commander = null
		qdel(src)
		return
	if(href_list["fire_mode"])
		var/mob/living/carbon/human/ms13_squad/selected = selected_ref?.resolve()
		if(selected_ref && !selected)
			return
		var/success = leader.issue_fire_mode(owner, href_list["fire_mode"], selected, terminal_ref?.resolve())
		to_chat(owner, success ? span_notice("Fire mode updated.") : span_warning("Fire mode rejected."))
	if(href_list["order"] in GLOB.ms13_squad_orders)
		pending_order = href_list["order"]
		if((pending_order in list("Use", "Break", "Pick up", "Deliver", "Sit")) && !selected_ref?.resolve())
			to_chat(owner, span_warning("Select one recruit before choosing this order."))
			return
		if(pending_order == "Hold")
			unset_click_ability(owner)
			Activate(null)
		else
			var/datum/action/cooldown/previous = owner.click_intercept
			if(istype(previous) && previous != src)
				previous.unset_click_ability(owner)
			set_click_ability(owner)
			to_chat(owner, span_notice("[pending_order]: click a target. Right-click cancels."))
	if(href_list["coordinates"] && terminal_ref && (pending_order in list("Move", "Guard", "Patrol", "Fire at area", "Fire direction", "Deliver")))
		if(owner.click_intercept == src)
			unset_click_ability(owner)
		var/requested_order = pending_order
		var/datum/weakref/requested_unit = selected_ref
		var/target_x = tgui_input_number(owner, "Target X (same level as the terminal)", "Squad order", leader.x, world.maxx, 1)
		if(isnull(target_x) || !IsAvailable() || pending_order != requested_order || selected_ref != requested_unit)
			return
		var/target_y = tgui_input_number(owner, "Target Y", "Squad order", leader.y, world.maxy, 1)
		if(isnull(target_y) || !IsAvailable() || pending_order != requested_order || selected_ref != requested_unit)
			return
		Activate(locate(round(target_x), round(target_y), leader.z))
	show_panel()

/datum/action/cooldown/ms13_squad_command/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/human/ms13_squad/leader = leader_ref.resolve()
	var/mob/living/carbon/human/ms13_squad/unit = selected_ref?.resolve()
	if(selected_ref && !unit)
		return FALSE
	var/success = leader.issue_order(owner, pending_order, target, unit, terminal_ref?.resolve())
	to_chat(owner, success ? span_notice("Order acknowledged.") : span_warning("Order rejected. Check the target, range and selected unit."))
	return success

/obj/machinery/ms13/terminal
	/// Optional mapper link; blank terminals discover nearby squads.
	var/squad_id = ""

/obj/machinery/ms13/terminal/proc/available_squad_units()
	. = list()
	var/turf/ground = get_turf(src)
	if(!ground)
		return
	for(var/mob/living/carbon/human/ms13_squad/unit as anything in GLOB.ms13_squad_units)
		if(unit.client || unit.stat != CONSCIOUS || unit.z != ground.z)
			continue
		if((squad_id && unit.squad_id == squad_id) || ((!squad_id || !unit.squad_id) && get_dist(ground, unit) <= 7))
			. += unit

/obj/machinery/ms13/terminal/Topic(href, href_list)
	if(href_list["choice"] != "squad")
		return ..()
	if(!terminal_available(usr))
		return TRUE
	var/list/units = available_squad_units()
	if(href_list["recruit"])
		var/mob/living/carbon/human/ms13_squad/unit = locate(href_list["recruit"]) in units
		var/mob/living/carbon/human/ms13_squad/leader = unit?.recruit(usr, src)
		leader?.open_commands(usr, src)
		return TRUE
	mode = 5
	ui_interact(usr)
	return TRUE

#endif
