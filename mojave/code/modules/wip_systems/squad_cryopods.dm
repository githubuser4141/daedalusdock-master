#ifndef MS13_SQUAD_CRYOPODS_INCLUDED
#define MS13_SQUAD_CRYOPODS_INCLUDED

/// Single occupant, created on release. Set mob_type and squad_id in the mapper.
/obj/machinery/ms13/npc_cryopod
	name = "NPC cryopod"
	desc = "A sealed cryogenic sleeper. Its occupant can be awakened locally or from a linked terminal."
	icon = 'icons/obj/machines/sleeper.dmi'
	icon_state = "sleeper"
	density = TRUE
	anchored = TRUE
	idle_power_usage = 50
	interaction_flags_machine = INTERACT_MACHINE_ALLOW_SILICON | INTERACT_MACHINE_OFFLINE
	var/network_id = ""
	var/pod_id = ""
	var/mob/living/mob_type = /mob/living/carbon/human/ms13_squad
	var/squad_id = ""
	var/released = FALSE
	var/status = "Ready"

/obj/machinery/ms13/npc_cryopod/Initialize(mapload)
	. = ..()
	SET_TRACKING(__TYPE__)
	if(!pod_id)
		pod_id = "[x]-[y]-[z]"

/obj/machinery/ms13/npc_cryopod/Destroy()
	UNSET_TRACKING(__TYPE__)
	return ..()

/obj/machinery/ms13/npc_cryopod/examine(mob/user)
	. = ..()
	. += span_notice("Pod [html_encode(pod_id)]. [released ? "Empty" : (is_operational ? status : "Offline - needs power")]. The exit is on its [dir2text(dir)] side. Click with an empty hand to release its occupant.")

/obj/machinery/ms13/npc_cryopod/interact(mob/user)
	wake_occupant(user)
	return TRUE

/obj/machinery/ms13/npc_cryopod/proc/wake_occupant(mob/living/user, obj/machinery/ms13/terminal/terminal)
	if(terminal)
		if(!terminal.terminal_available(user) || !(src in terminal.linked_cryopods()))
			return FALSE
	else if(!user?.canUseTopic(src, USE_CLOSE|USE_DEXTERITY))
		return FALSE
	if(released)
		to_chat(user, span_notice("[src] is empty."))
		return FALSE
	if(!is_operational)
		to_chat(user, span_warning("[src] is offline. Check its power and condition."))
		return FALSE
	if(!allowed(user))
		to_chat(user, span_warning("[src] denies your access."))
		return FALSE
	if(!ispath(mob_type, /mob/living))
		status = "Invalid occupant type"
		to_chat(user, span_warning("[src] has an invalid occupant configuration."))
		return FALSE
	var/turf/exit = get_step(src, dir)
	if(!isopenturf(exit) || exit.is_blocked_turf())
		status = "Exit blocked"
		to_chat(user, span_warning("Clear the tile [dir2text(dir)] of [src] before opening it."))
		return FALSE
	// Reserve before construction so a second terminal cannot release the same occupant.
	released = TRUE
	var/mob/living/occupant = new mob_type(exit)
	if(QDELETED(occupant))
		released = FALSE
		status = "Release failed"
		return FALSE
	if(istype(occupant, /mob/living/carbon/human/ms13_squad))
		var/mob/living/carbon/human/ms13_squad/recruit = occupant
		recruit.squad_id = squad_id
	status = "Empty"
	playsound(src, 'sound/machines/door_open.ogg', 40, TRUE)
	visible_message(span_notice("[src] opens, releasing [occupant]."))
	return TRUE

/obj/machinery/ms13/terminal
	/// Matches pod network_id, independently of the NPC squad ID.
	var/cryo_network = ""

/obj/machinery/ms13/terminal/proc/linked_cryopods()
	. = list()
	var/turf/ground = get_turf(src)
	for(var/obj/machinery/ms13/npc_cryopod/pod as anything in INSTANCES_OF(/obj/machinery/ms13/npc_cryopod))
		if(pod.network_id ? (cryo_network && pod.network_id == cryo_network) : (ground && pod.z == ground.z && get_dist(ground, pod) <= 7))
			. += pod

/obj/machinery/ms13/terminal/proc/wake_cryopods(mob/living/user, obj/machinery/ms13/npc_cryopod/selected)
	if(!terminal_available(user))
		return 0
	var/list/pods = linked_cryopods()
	if(selected)
		if(!(selected in pods))
			return 0
		pods = list(selected)
	. = 0
	for(var/obj/machinery/ms13/npc_cryopod/pod as anything in pods)
		. += !!pod.wake_occupant(user, src)

/obj/machinery/ms13/terminal/proc/open_cryopods(mob/living/user)
	if(!terminal_available(user))
		return
	mode = 6
	ui_interact(user)

/obj/machinery/ms13/terminal/Topic(href, list/href_list)
	if(!(href_list["choice"] in list("cryopods", "cryo_wake")))
		return ..()
	if(!terminal_available(usr))
		return TRUE
	if(href_list["choice"] == "cryo_wake")
		var/obj/machinery/ms13/npc_cryopod/pod
		if(href_list["pod"] != "all")
			pod = locate(href_list["pod"]) in linked_cryopods()
			if(!pod)
				return TRUE
		var/released_count = wake_cryopods(usr, pod)
		to_chat(usr, span_notice("Released [released_count] occupant(s). Check power and exits for pods still waiting."))
	open_cryopods(usr)
	return TRUE

#endif
