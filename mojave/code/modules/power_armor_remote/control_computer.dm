GLOBAL_LIST_EMPTY(ms13_pa_receivers)
GLOBAL_LIST_EMPTY(ms13_pa_antennas)

/proc/ms13_find_pa_receiver(link_id)
	if(!link_id)
		return null
	for(var/obj/item/ms13/pa_module/remote_receiver/candidate as anything in GLOB.ms13_pa_receivers)
		if(candidate.link_id == link_id)
			return candidate
	return null

/proc/ms13_find_pa_antenna(link_id)
	if(!link_id)
		return null
	for(var/obj/machinery/ms13_pa_antenna/candidate as anything in GLOB.ms13_pa_antennas)
		if(candidate.link_id == link_id)
			return candidate
	return null

/**
 * Where an operator sits to start/hold a remote-piloting session. Paired to a specific suit's
 * receiver module by a plain shared link_id string, set by hand via VV - same "shared string tag"
 * pairing convention this session already used for master-key lock_group grouping
 * (mojave/code/modules/locks/obj_defines.dm), rather than building a full frequency/signaler system
 * for a first pass.
 */
/obj/machinery/computer/ms13_pa_control
	name = "power armor control terminal"
	desc = "Remotely operates a suit of power armor fitted with a matching receiver."
	icon_screen = "rdcomp"
	icon_keyboard = "rd_key"
	circuit = /obj/item/circuitboard/computer/ms13_pa_control
	var/link_id
	var/datum/ms13_remote_link/active_link

/obj/item/circuitboard/computer/ms13_pa_control
	build_path = /obj/machinery/computer/ms13_pa_control

/obj/machinery/computer/ms13_pa_control/Destroy()
	if(active_link)
		active_link.sever("the control terminal was destroyed")
	return ..()

/obj/machinery/computer/ms13_pa_control/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!ishuman(user) || !user.mind)
		return

	if(active_link)
		if(tgui_alert(user, "Disconnect from the linked power armor?", "Power Armor Control", list("Disconnect", "Cancel")) == "Disconnect" && active_link)
			active_link.sever("manually disconnected")
		return

	if(!link_id)
		to_chat(user, span_warning("[src] has no link ID configured."))
		return

	var/obj/item/ms13/pa_module/remote_receiver/target = ms13_find_pa_receiver(link_id)
	if(!target || QDELETED(target))
		to_chat(user, span_warning("No power armor responds to this terminal's link ID."))
		return
	if(target.active_link)
		to_chat(user, span_warning("That suit is already under remote control."))
		return

	var/obj/machinery/ms13_pa_antenna/antenna = ms13_find_pa_antenna(link_id)
	var/list/choices = list("Cable")
	if(antenna && target.part_pa?.frame && antenna.pa_in_range(target.part_pa.frame))
		choices += "Radio"

	var/choice = tgui_input_list(user, "Choose link method", "Power Armor Control", choices)
	if(!choice || active_link || QDELETED(target) || target.active_link || !user.mind)
		return
	if(!target.part_pa?.frame)
		to_chat(user, span_warning("That receiver isn't installed in a power armor suit."))
		return
	if(choice == "Radio" && !antenna.pa_in_range(target.part_pa.frame))
		to_chat(user, span_warning("The relay antenna lost the suit before the link could establish."))
		return

	var/mob/living/carbon/human/operator = user
	var/datum/ms13_remote_link/link = new(operator, target, src, choice == "Radio" ? MS13_PA_LINK_RADIO : MS13_PA_LINK_CABLE)
	active_link = link
	target.active_link = link
	if(choice == "Radio")
		link.antenna = antenna
		antenna.active_link = link
