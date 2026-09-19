// Marker-only content. The shared hive has no dependency on its power, radio or hallucinations.
/datum/ms13_terrain_hivemind/necromorph/marker
	name = "necromorph Marker"
	core_type = /obj/structure/ms13_hivemind/core/marker
	core_icon = 'icons/obj/cult/structures.dmi'
	core_icon_state = "pylon"

/datum/ms13_terrain_hivemind/necromorph/marker/process(delta_time)
	var/obj/structure/ms13_hivemind/core/marker/marker = core
	if(marker?.is_suppressed())
		return
	return ..()

/datum/ms13_terrain_hivemind/necromorph/marker/spawn_unit(unit_type, turf/origin)
	var/obj/structure/ms13_hivemind/core/marker/marker = core
	if(marker?.is_suppressed())
		return FALSE
	return ..()

/datum/ms13_terrain_hivemind/necromorph/marker/spend(amount)
	var/obj/structure/ms13_hivemind/core/marker/marker = core
	if(marker?.is_suppressed())
		return FALSE
	return ..()

/datum/ms13_terrain_hivemind/necromorph/marker/advance_corpse_conversion(mob/living/corpse, datum/converter, delta_time, conversion_time, claim = TRUE)
	var/obj/structure/ms13_hivemind/core/marker/marker = core
	if(marker?.is_suppressed())
		return FALSE
	return ..()

/obj/structure/ms13_hivemind/core/marker
	name = "Marker"
	desc = "A humming alien monolith. Its branching veins resemble both flesh and electrical conductors."
	icon = 'icons/obj/cult/structures.dmi'
	icon_state = "pylon"
	max_integrity = 1500
	var/influence_radius = 30
	var/corpse_scan_cursor = 1
	/// Default unsafe; a live nearby suppression projector maintains containment.
	var/suppressed = FALSE
	var/containment_started_at
	var/containment_emp_arm_time = 5 MINUTES
	var/containment_emp_heavy_range = 45
	var/containment_emp_light_range = 90
	var/obj/machinery/power/ms13_marker_feed/power_feed
	var/obj/machinery/telecomms/allinone/ms13_marker_relay/radio_relay
	COOLDOWN_DECLARE(influence_cooldown)

/obj/structure/ms13_hivemind/core/marker/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		// A mapper-placed Marker starts a network, which creates its actual registered core.
		new /datum/ms13_terrain_hivemind/necromorph/marker(get_turf(src), 120)
		return INITIALIZE_HINT_QDEL
	name = "Marker"
	power_feed = new(get_turf(src), src)
	radio_relay = new(get_turf(src), src)
	COOLDOWN_START(src, influence_cooldown, 10 SECONDS)

/obj/structure/ms13_hivemind/core/marker/Destroy()
	QDEL_NULL(power_feed)
	QDEL_NULL(radio_relay)
	return ..()

/obj/structure/ms13_hivemind/core/marker/examine(mob/user)
	. = ..()
	. += span_notice("A cable node beneath it can draw 1 MW. It also carries public radio transmissions. Its influence extends [influence_radius] tiles on this floor.")
	. += span_notice((is_suppressed() ? "Its signal is suppressed. Power and public radio remain available." : "Its signal is uncontained. An operating Marker suppression projector within four tiles can contain it."))
	if(suppressed)
		. += span_warning("Containment feedback: [world.time - containment_started_at >= containment_emp_arm_time ? "charged — containment loss will release a massive EMP" : "building charge"].")

/obj/structure/ms13_hivemind/core/marker/proc/is_suppressed()
	var/contained = FALSE
	for(var/obj/machinery/power/ms13_marker_suppressor/projector in range(4, src))
		if(projector.enabled && projector.anchored && !(projector.machine_stat & BROKEN) && projector.field_expires > world.time)
			contained = TRUE
			break
	if(contained != suppressed)
		var/release_emp = suppressed && !isnull(containment_started_at) && world.time - containment_started_at >= containment_emp_arm_time
		suppressed = contained
		// Clear the previous charge before the EMP can cause any further containment changes.
		containment_started_at = contained ? world.time : null
		visible_message(span_warning((suppressed ? "[src]'s ominous hum subsides inside a containment field." : "[src]'s containment fails! Its ominous hum returns.")))
		if(release_emp)
			visible_message(span_userdanger("[src] discharges a massive electromagnetic pulse as its containment collapses!"))
			empulse(get_turf(src), containment_emp_heavy_range, containment_emp_light_range, TRUE)
	return suppressed

/obj/structure/ms13_hivemind/core/marker/attackby(obj/item/item, mob/living/user, params)
	if(istype(item, /obj/item/stack/cable_coil) && power_feed)
		return power_feed.attackby(item, user, params)
	return ..()

/obj/structure/ms13_hivemind/core/marker/process(delta_time)
	. = ..()
	if(!network?.active || is_suppressed() || !COOLDOWN_FINISHED(src, influence_cooldown))
		return
	COOLDOWN_START(src, influence_cooldown, 10 SECONDS)
	for(var/mob/living/carbon/human/human in GLOB.player_list)
		if(human.client && human.stat == CONSCIOUS && human.z == z && get_dist(src, human) <= influence_radius && prob(25))
			new /datum/hallucination/ms13_marker_attack(human)
	// Scan a rotating budget rather than every corpse for every Marker every tick.
	var/count = length(GLOB.dead_mob_list)
	for(var/index in 1 to min(count, 32))
		if(corpse_scan_cursor > length(GLOB.dead_mob_list))
			corpse_scan_cursor = 1
		if(!length(GLOB.dead_mob_list))
			break
		var/mob/living/corpse = GLOB.dead_mob_list[corpse_scan_cursor++]
		if(corpse.z != z || get_dist(src, corpse) > influence_radius || LAZYLEN(corpse.grabbed_by) || !network.is_convertible_corpse(corpse))
			continue
		if(network.get_corpse_claim(corpse) || length(network.units) >= network.max_units || network.resources < network.unit_cost)
			continue
		// Do not consume a corpse unless its tile is suitable for the newborn (no vehicles/dense blockers).
		if(!network.get_unit_spawn_turf(get_turf(corpse)))
			continue
		if(network.advance_corpse_conversion(corpse, src, 1, 1))
			network.resources -= network.unit_cost
			break // At most one remote rebirth per pulse.

// These hidden components stay on the Marker's turf so native cable/radio z-level checks work.
/obj/machinery/power/ms13_marker_feed
	name = "Marker power connection"
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	density = FALSE
	var/datum/weakref/marker_ref

/obj/machinery/power/ms13_marker_feed/Initialize(mapload, obj/structure/ms13_hivemind/core/marker/marker)
	. = ..()
	if(!marker)
		return INITIALIZE_HINT_QDEL
	marker_ref = WEAKREF(marker)
	connect_to_network()

/obj/machinery/power/ms13_marker_feed/process(delta_time)
	var/obj/structure/ms13_hivemind/core/marker/marker = marker_ref?.resolve()
	if(!marker?.network?.active)
		return PROCESS_KILL
	if(!powernet)
		connect_to_network()
	add_avail(1000000)

/obj/machinery/telecomms/allinone/ms13_marker_relay
	name = "Marker public relay"
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	density = FALSE
	intercept = TRUE
	var/datum/weakref/marker_ref
	COOLDOWN_DECLARE(spoof_cooldown)

/obj/machinery/telecomms/allinone/ms13_marker_relay/Initialize(mapload, obj/structure/ms13_hivemind/core/marker/marker)
	. = ..()
	if(!marker)
		return INITIALIZE_HINT_QDEL
	marker_ref = WEAKREF(marker)
	freq_listening = list(FREQ_COMMON)
	soundloop.stop()
	STOP_PROCESSING(SSmachines, src)

/obj/machinery/telecomms/allinone/ms13_marker_relay/receive_signal(datum/signal/subspace/signal)
	var/obj/structure/ms13_hivemind/core/marker/marker = marker_ref?.resolve()
	if(!marker?.network?.active || !istype(signal, /datum/signal/subspace/vocal) || signal.frequency != FREQ_COMMON || signal.data["ms13_marker_spoof"])
		return
	if(!signal.data["done"])
		..()
	if(!marker.is_suppressed() && COOLDOWN_FINISHED(src, spoof_cooldown) && prob(12))
		COOLDOWN_START(src, spoof_cooldown, 45 SECONDS)
		addtimer(CALLBACK(src, PROC_REF(spoof_public_message)), 2 SECONDS)

/obj/machinery/telecomms/allinone/ms13_marker_relay/proc/spoof_public_message()
	var/obj/structure/ms13_hivemind/core/marker/marker = marker_ref?.resolve()
	if(!marker?.network?.active || marker.is_suppressed())
		return FALSE
	var/list/identities = list()
	for(var/mob/living/carbon/human/human in GLOB.alive_mob_list)
		if(length(human.real_name))
			identities += human
	if(!length(identities))
		return FALSE
	var/mob/living/carbon/human/identity = pick(identities)
	var/atom/movable/virtualspeaker/voice = new(null, marker, null)
	voice.name = identity.real_name
	voice.job = "Unknown"
	var/message = pick("I'm still here. Please come back.", "Don't trust the person beside you.", "The signal is keeping us alive. Leave it on.", "I can hear them underneath the floor.", "Make us whole.")
	var/datum/signal/subspace/vocal/echo = new(src, FREQ_COMMON, voice, GET_LANGUAGE_DATUM(/datum/language/common), message, list(), list(), list(0))
	echo.data["compression"] = 0
	echo.data["ms13_marker_spoof"] = TRUE
	echo.mark_done()
	echo.broadcast()
	log_game("Marker at [AREACOORD(marker)] spoofed public radio identity [identity.real_name]: [message]")
	return TRUE

// Reuse native wired power accounting and field-generator art, not the SM's unrelated gas physics.
/obj/machinery/power/ms13_marker_suppressor
	name = "Marker suppression projector"
	desc = "A wired containment projector. When enabled, draws 50 kW to suppress nearby Markers within four tiles. Existing creatures are not pacified."
	icon = 'icons/obj/machines/field_generator.dmi'
	icon_state = "Field_Gen"
	density = TRUE
	max_integrity = 300
	var/enabled = FALSE
	var/field_expires = 0

/obj/machinery/power/ms13_marker_suppressor/Initialize(mapload)
	. = ..()
	connect_to_network()

/obj/machinery/power/ms13_marker_suppressor/Destroy()
	enabled = FALSE
	field_expires = 0
	refresh_marker_containment()
	return ..()

/obj/machinery/power/ms13_marker_suppressor/proc/refresh_marker_containment()
	for(var/obj/structure/ms13_hivemind/core/marker/marker in range(4, src))
		marker.is_suppressed()

/obj/machinery/power/ms13_marker_suppressor/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	enabled = !enabled
	field_expires = 0
	refresh_marker_containment()
	to_chat(user, span_notice("You [enabled ? "enable" : "disable"] [src]."))
	update_appearance()

/obj/machinery/power/ms13_marker_suppressor/process(delta_time)
	// Observe an expired field before renewing it: a gap must restart the arming period.
	if(field_expires && field_expires <= world.time)
		refresh_marker_containment()
	field_expires = 0
	if(enabled && anchored && !(machine_stat & BROKEN))
		if(!powernet)
			connect_to_network()
		if(surplus() >= 50000)
			add_load(50000)
			field_expires = world.time + 3 SECONDS
	refresh_marker_containment()
	update_appearance()

/obj/machinery/power/ms13_marker_suppressor/update_overlays()
	. = ..()
	if(enabled && field_expires > world.time)
		. += "+on"

/obj/machinery/power/ms13_marker_suppressor/examine(mob/user)
	. = ..()
	. += span_notice("[enabled ? "Enabled" : "Disabled"]. Containment field: [field_expires > world.time ? "active" : "offline"]. Requires a cable node and 50 kW of spare grid power.")

/datum/hallucination/ms13_marker_attack
	var/image/attacker
	var/client/viewer
	var/hits = 0

/datum/hallucination/ms13_marker_attack/New(mob/living/carbon/human/victim, forced = TRUE)
	. = ..()
	viewer = victim.client
	var/atom/anchor = get_step(victim, pick(GLOB.cardinals))
	for(var/mob/living/carbon/human/other in oview(4, victim))
		if(prob(50))
			anchor = other
			break
	attacker = image('mojave/icons/wip/terrain_hivemind/ds13_slasher.dmi', anchor, "preview", MOB_LAYER)
	attacker.override = ishuman(anchor)
	attacker.pixel_x = -8
	attacker.pixel_y = -8
	if(viewer)
		viewer.images += attacker
	feedback_details = "Marker-induced phantom attack; real combat/health unchanged."
	START_PROCESSING(SSobj, src)
	QDEL_IN(src, 8 SECONDS)

/datum/hallucination/ms13_marker_attack/process(delta_time)
	if(!target?.client || target.stat != CONSCIOUS || ++hits > 3)
		qdel(src)
		return PROCESS_KILL
	to_chat(target, span_userdanger("[ishuman(attacker.loc) ? attacker.loc.name : "Something"] slashes at you!"))
	target.playsound_local(get_turf(target), 'sound/weapons/slash.ogg', 40, TRUE)
	animate(attacker, pixel_x = 4, time = 2)
	animate(pixel_x = -8, time = 2)

/datum/hallucination/ms13_marker_attack/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(viewer)
		viewer.images -= attacker
	attacker = null
	viewer = null
	return ..()
