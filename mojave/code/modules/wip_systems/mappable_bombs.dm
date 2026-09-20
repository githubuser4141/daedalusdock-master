/// WIP map-ready payloads: reuse grenade timers, logging, damage triggers and shrapnel.
/obj/item/grenade/ms13_bomb
	name = "medium demolition bomb"
	desc = "A portable explosive with an adjustable timer. Activate in hand to arm; use a screwdriver to cycle the delay. There is no disarm mechanism."
	icon_state = "syndicate"
	w_class = WEIGHT_CLASS_BULKY
	throw_range = 2
	det_time = 10 SECONDS
	ex_heavy = 1
	ex_light = 3
	/// Game-balance multiplier, not a physical explosive/material model.
	var/quality = 1
	/// Percentage variation rolled once on creation. Zero gives exact mapper-defined quality.
	var/quality_variation = 20
	var/jet_damage = 0
	var/jet_penetration = 150
	var/jet_range = 5
	var/jet_fragments = 4

/obj/item/grenade/ms13_bomb/Initialize(mapload)
	. = ..()
	var/variation = clamp(round(quality_variation), 0, 50)
	quality = clamp(quality * (1 + rand(-variation, variation) / 100), 0.5, 1.5)
	if(ex_dev > 0)
		ex_dev = max(1, round(ex_dev * quality))
	if(ex_heavy > 0)
		ex_heavy = max(1, round(ex_heavy * quality))
	if(ex_light > 0)
		ex_light = max(1, round(ex_light * quality))
	if(ex_flame > 0)
		ex_flame = max(1, round(ex_flame * quality))
	if(shrapnel_radius > 0)
		shrapnel_radius = max(1, round(shrapnel_radius * quality))
	jet_damage = max(0, round(jet_damage * quality))
	jet_penetration = max(0, round(jet_penetration * quality))

/obj/item/grenade/ms13_bomb/examine(mob/user)
	. = ..()
	. += span_notice("Build quality: [round(quality * 100)]%. [active ? "ARMED — keep clear!" : "Unarmed. Screwdriver settings: 5, 10, 30 or 60 seconds."]")
	if(jet_damage)
		. += span_notice("Its directional payload fires along its facing. Alt-click while unarmed to rotate it.")

/obj/item/grenade/ms13_bomb/AltClick(mob/user)
	if(!active && !dud_flags && user.canUseTopic(src, USE_CLOSE))
		setDir(turn(dir, 90))
		balloon_alert(user, "facing [dir2text(dir)]")

/obj/item/grenade/ms13_bomb/change_det_time(time)
	if(active || dud_flags)
		return FALSE
	if(!isnull(time))
		det_time = clamp(round(time), 5, 60) SECONDS
	else
		var/list/delays = list(5 SECONDS, 10 SECONDS, 30 SECONDS, 60 SECONDS)
		det_time = delays[(delays.Find(det_time) % length(delays)) + 1]
	return TRUE

/obj/item/grenade/ms13_bomb/multitool_act(mob/living/user, obj/item/tool)
	return screwdriver_act(user, tool)

/obj/item/grenade/ms13_bomb/arm_grenade(mob/user, delayoverride, msg = TRUE, volume = 60)
	if(active || dud_flags || QDELETED(src))
		return
	return ..()

/obj/item/grenade/ms13_bomb/detonate(mob/living/lanced_by)
	var/turf/origin = get_turf(src)
	var/firing_angle = dir2angle(dir)
	if(!origin || !..())
		return FALSE
	if(jet_damage)
		ms13_fire_shaped_charge_jet(origin, firing_angle, jet_damage, jet_penetration, jet_range, jet_fragments)
	update_mob()
	qdel(src)
	return TRUE

/obj/item/grenade/ms13_bomb/small
	name = "small demolition bomb"
	w_class = WEIGHT_CLASS_NORMAL
	ex_heavy = 0
	ex_light = 2

/obj/item/grenade/ms13_bomb/large
	name = "large demolition bomb"
	w_class = WEIGHT_CLASS_HUGE
	throw_range = 1
	ex_dev = 1
	ex_heavy = 3
	ex_light = 5

/obj/item/grenade/ms13_bomb/antipersonnel
	name = "fragmentation bomb"
	icon_state = "frag"
	ex_heavy = 0
	ex_light = 2
	shrapnel_type = /obj/projectile/bullet/shrapnel
	shrapnel_radius = 5

/obj/item/grenade/ms13_bomb/antiarmor
	name = "directional anti-armor bomb"
	color = "#a4c2a4"
	ex_heavy = 0
	ex_light = 1
	jet_damage = 60
	jet_penetration = 200

/// ponytail: blast-heavy game approximation; no fuel-cloud chemistry or enclosure simulation.
/obj/item/grenade/ms13_bomb/thermobaric
	name = "thermobaric bomb"
	color = "#d6b485"
	ex_heavy = 2
	ex_light = 5
	ex_flame = 1

/obj/item/grenade/ms13_bomb/incendiary
	name = "incendiary bomb"
	color = "#ed9569"
	ex_heavy = 0
	ex_light = 0
	ex_flame = 5

/obj/effect/spawner/random/ms13_bomb
	name = "random unarmed bomb"
	loot = list(
		/obj/item/grenade/ms13_bomb = 3,
		/obj/item/grenade/ms13_bomb/small = 4,
		/obj/item/grenade/ms13_bomb/large = 1,
		/obj/item/grenade/ms13_bomb/antipersonnel = 2,
		/obj/item/grenade/ms13_bomb/antiarmor = 1,
		/obj/item/grenade/ms13_bomb/thermobaric = 1,
		/obj/item/grenade/ms13_bomb/incendiary = 2,
	)

/// Uses real cable continuity, not matching IDs or a proximity zone. No grid power required.
/obj/machinery/power/ms13_bomb_mount
	name = "wired bomb mount"
	desc = "A wired explosive mount. A connected trigger starts the payload's timer. Cut its cable before activation to isolate it."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "syndicate"
	density = FALSE
	var/bomb_type = /obj/item/grenade/ms13_bomb
	var/obj/item/grenade/ms13_bomb/payload

/obj/machinery/power/ms13_bomb_mount/Initialize(mapload)
	. = ..()
	if(ispath(bomb_type, /obj/item/grenade/ms13_bomb))
		payload = new bomb_type(src)
		payload.setDir(dir)
	connect_to_network()

/obj/machinery/power/ms13_bomb_mount/Destroy()
	QDEL_NULL(payload)
	return ..()

/obj/machinery/power/ms13_bomb_mount/examine(mob/user)
	. = ..()
	if(!QDELETED(payload))
		. += "Payload: [payload.name]. [payload.active ? "ARMED" : "Waiting for wired trigger"]. Delay: [DisplayTimeText(payload.det_time)]."
	else
		. += "The mount is empty."

/obj/machinery/power/ms13_bomb_mount/screwdriver_act(mob/living/user, obj/item/tool)
	if(!QDELETED(payload))
		return payload.screwdriver_act(user, tool)

/obj/machinery/power/ms13_bomb_mount/proc/trigger_payload(mob/user)
	if(QDELETED(payload) || payload.active)
		return FALSE
	payload.setDir(dir)
	payload.arm_grenade(user)
	icon_state = "syndicate_active"
	return TRUE

/obj/machinery/power/ms13_bomb_trigger
	name = "wired bomb switch"
	desc = "A physical firing switch. Starts every bomb timer on its connected cable circuit; no external power required."
	icon = 'icons/obj/machines/buttons.dmi'
	icon_state = "doorctrl"
	density = FALSE

/obj/machinery/power/ms13_bomb_trigger/Initialize(mapload)
	. = ..()
	connect_to_network()

/obj/machinery/power/ms13_bomb_trigger/attack_hand(mob/living/user, list/modifiers)
	if(..() || !user.canUseTopic(src, USE_CLOSE))
		return
	add_fingerprint(user)
	balloon_alert(user, send_trigger(user) ? "trigger sent" : "no ready bombs connected")

/obj/machinery/power/ms13_bomb_trigger/proc/send_trigger(mob/user)
	if(machine_stat & BROKEN)
		return FALSE
	if(!connect_to_network())
		disconnect_from_network()
		return FALSE
	var/triggered = FALSE
	for(var/obj/machinery/power/ms13_bomb_mount/mount in powernet.nodes.Copy())
		if(QDELETED(mount) || (mount.machine_stat & BROKEN))
			continue
		if(!mount.connect_to_network())
			mount.disconnect_from_network()
			continue
		if(mount.powernet == powernet && mount.trigger_payload(user))
			triggered = TRUE
	return triggered

/obj/machinery/power/ms13_bomb_trigger/pressure_plate
	name = "wired pressure plate"
	desc = "A pressure plate connected to a firing circuit. Grounded living creatures stepping on it start the connected bomb timers."
	icon = 'icons/obj/items_and_weapons.dmi'
	icon_state = "uglymine"

/obj/machinery/power/ms13_bomb_trigger/pressure_plate/Initialize(mapload)
	. = ..()
	var/static/list/connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))
	AddElement(/datum/element/connect_loc, connections)

/obj/machinery/power/ms13_bomb_trigger/pressure_plate/proc/on_entered(datum/source, atom/movable/entrant)
	SIGNAL_HANDLER
	if(isliving(entrant) && !(entrant.movement_type & FLYING))
		send_trigger(entrant)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_mappable_bombs
	name = "BOMBS: Map Presets And Timer Guards"

/datum/unit_test/ms13_mappable_bombs/Run()
	for(var/bomb_type in typesof(/obj/item/grenade/ms13_bomb))
		var/obj/item/grenade/ms13_bomb/bomb = allocate(bomb_type)
		if(bomb.active || bomb.quality < 0.5 || bomb.quality > 1.5)
			Fail("[bomb_type] spawned armed or with invalid quality.")
		if(!(bomb.icon_state in icon_states(bomb.icon)) || !("[bomb.icon_state]_active" in icon_states(bomb.icon)))
			Fail("[bomb_type] lacks placeholder art.")
		if(!(bomb.ex_light || bomb.ex_flame || bomb.shrapnel_radius || bomb.jet_damage))
			Fail("[bomb_type] has no payload.")
		bomb.change_det_time(30)
		if(bomb.det_time != 30 SECONDS)
			Fail("[bomb_type] could not configure its timer.")
		bomb.active = TRUE
		if(bomb.change_det_time(5) || bomb.det_time != 30 SECONDS)
			Fail("[bomb_type] allowed changing an armed timer.")
	var/turf/start = run_loc_floor_bottom_left
	var/turf/middle = get_step(start, EAST)
	var/turf/end = get_step(middle, EAST)
	var/obj/structure/cable/first = allocate(/obj/structure/cable, start)
	first.set_directions(CABLE_EAST)
	var/obj/structure/cable/link = allocate(/obj/structure/cable, middle)
	link.set_directions(CABLE_EAST | CABLE_WEST)
	var/obj/structure/cable/last = allocate(/obj/structure/cable, end)
	last.set_directions(CABLE_WEST)
	var/obj/machinery/power/ms13_bomb_trigger/trigger = allocate(/obj/machinery/power/ms13_bomb_trigger, start)
	var/obj/machinery/power/ms13_bomb_mount/mount = allocate(/obj/machinery/power/ms13_bomb_mount, end)
	if(!trigger.powernet || trigger.powernet != mount.powernet)
		Fail("Bomb devices did not connect through native cables.")
	qdel(link)
	if(trigger.send_trigger() || mount.payload.active)
		Fail("A cut cable still transmitted a trigger.")
	link = allocate(/obj/structure/cable, middle)
	link.set_directions(CABLE_EAST | CABLE_WEST)
	if(!trigger.send_trigger() || !mount.payload.active)
		Fail("A repaired cable did not transmit a trigger.")
	if(trigger.send_trigger())
		Fail("A trigger re-armed an already armed bomb.")
#endif
