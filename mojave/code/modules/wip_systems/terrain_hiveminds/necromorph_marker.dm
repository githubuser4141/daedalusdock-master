// Marker-only content. The shared hive has no dependency on its power, radio or hallucinations.
/// The Marker leaves someone be this long between getting into their head.
#define MS13_MARKER_HAUNT_COOLDOWN (45 SECONDS)
/// Uncontained, the chance a second that its power drops out for a moment, and how far it wobbles meanwhile: the grid's
/// ripple, kept under what pops bulbs (power/apc_ms13.dm).
#define MS13_MARKER_DROPOUT_CHANCE 5
#define MS13_MARKER_RIPPLE 0.3

/datum/ms13_terrain_hivemind/necromorph/marker
	name = "necromorph Marker"
	core_type = /obj/structure/ms13_hivemind/core/marker
	core_icon = 'mojave/icons/wip/terrain_hivemind/marker_giant.dmi'
	core_icon_state = "marker_giant_active_anim"
	// Its necromorphs are the dead, remade: one grown from nothing needs half its full reach of growth, ten times what
	// remaking a corpse costs, and nineteen remade corpses for every one.
	thin_air_min_territory = 60
	thin_air_unit_cost = 200
	thin_air_share = 0.05

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
	if(marker?.is_suppressed() || !can_reanimate_at(corpse))
		return FALSE
	return ..()

/// Pause every conversion route without consuming resources or discarding accumulated progress.
/datum/ms13_terrain_hivemind/necromorph/marker/proc/can_reanimate_at(mob/living/corpse)
	var/turf/site = get_turf(corpse)
	if(QDELETED(corpse) || !site)
		return FALSE
	if(is_territory(site))
		return TRUE
	var/datum/time_of_day/sky = SSoutdoor_effects.current_step_datum
	if(istype(sky, /datum/time_of_day/sunrise) || istype(sky, /datum/time_of_day/daytime) || istype(sky, /datum/time_of_day/sunset))
		if(site.outdoor_effect?.state == SKY_VISIBLE || site.outdoor_effect?.state == SKY_VISIBLE_BORDER)
			return FALSE
		// Sun spilling under a roof counts too; electric lamps and moonlight do not.
		for(var/datum/lighting_corner/corner as anything in list(site.lighting_corner_NE, site.lighting_corner_SE, site.lighting_corner_SW, site.lighting_corner_NW))
			if(corner?.sunFalloff > 0)
				return FALSE
	// Include the actual projections visible through open space on higher floors.
	for(var/atom/movable/visible_body as anything in (list(corpse) + corpse.get_associated_mimics()))
		for(var/mob/living/carbon/human/witness as anything in GLOB.human_list)
			if(QDELETED(witness) || witness.stat != CONSCIOUS || witness.z != visible_body.z || !witness.in_fov(visible_body))
				continue
			if(visible_body in view(witness.client ? witness.client.view : world.view, witness))
				return FALSE
	return TRUE

/obj/structure/ms13_hivemind/core/marker
	name = "Marker"
	desc = "A humming alien monolith. Its branching veins resemble both flesh and electrical conductors."
	icon = 'mojave/icons/wip/terrain_hivemind/marker_giant.dmi'
	icon_state = "marker_giant_dormant"
	// Three tiles wide and six tall: centred on its tile, standing on it, over those around it like a tree.
	pixel_x = -32
	layer = 4.9
	plane = ABOVE_GAME_PLANE
	max_integrity = 1500
	var/influence_radius = 45
	/// Electrical light radius; each connected floor costs five tiles. Zero disables the effect.
	var/light_flicker_radius = 75
	/// How far it reaches for the dead across connected floors, and how many it remakes a pulse.
	var/corpse_reach = 45
	var/corpses_per_pulse = 3
	/// Default unsafe; a live nearby suppression projector maintains containment.
	var/suppressed = FALSE
	var/containment_started_at
	var/containment_emp_arm_time = 5 MINUTES
	var/containment_emp_heavy_range = 45
	var/containment_emp_light_range = 90
	var/obj/machinery/power/ms13_marker_feed/power_feed
	var/obj/machinery/telecomms/allinone/ms13_marker_relay/radio_relay
	/// Its hum, on repeat while it's uncontained.
	var/datum/looping_sound/ms13_marker_hum/hum
	COOLDOWN_DECLARE(influence_cooldown)

/obj/structure/ms13_hivemind/core/marker/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		// A mapper-placed Marker starts a network, which creates its actual registered core.
		var/datum/ms13_terrain_hivemind/necromorph/marker/hive = new(get_turf(src), 120)
		var/obj/structure/ms13_hivemind/core/marker/registered_core = hive.core
		registered_core.influence_radius = influence_radius
		registered_core.light_flicker_radius = light_flicker_radius
		registered_core.corpse_reach = corpse_reach
		registered_core.corpses_per_pulse = corpses_per_pulse
		registered_core.containment_emp_arm_time = containment_emp_arm_time
		registered_core.containment_emp_heavy_range = containment_emp_heavy_range
		registered_core.containment_emp_light_range = containment_emp_light_range
		return INITIALIZE_HINT_QDEL
	name = "Marker"
	power_feed = new(get_turf(src), src)
	radio_relay = new(get_turf(src), src)
	hum = new(src, TRUE)
	COOLDOWN_START(src, influence_cooldown, 10 SECONDS)

/obj/structure/ms13_hivemind/core/marker/Destroy()
	QDEL_NULL(power_feed)
	QDEL_NULL(radio_relay)
	QDEL_NULL(hum)
	return ..()

/obj/structure/ms13_hivemind/core/marker/examine(mob/user)
	. = ..()
	. += span_notice("Each line of cable run under its base draws 1 MW. It also carries public radio transmissions. Its influence extends [influence_radius] tiles, with each connected floor counting as five tiles.")
	. += span_notice((is_suppressed() ? "Its signal is suppressed. Power and public radio remain available, and its power runs steady." : "Its signal is uncontained, and its power flickers. An operating Marker suppression projector within four tiles can contain it."))
	if(suppressed)
		var/seconds_remaining = CEILING(max(0, containment_emp_arm_time - (world.time - containment_started_at)) / (1 SECONDS), 1)
		. += span_warning("Containment feedback: [seconds_remaining ? "charging — [seconds_remaining] seconds of uninterrupted containment remain before an EMP can discharge" : "charged — containment loss will release a massive EMP"].")

/obj/structure/ms13_hivemind/core/marker/proc/is_suppressed()
	var/contained = FALSE
	for(var/obj/machinery/power/ms13_marker_suppressor/projector in range(4, src))
		if(projector.enabled && projector.anchored && !(projector.machine_stat & BROKEN) && projector.field_expires > world.time)
			contained = TRUE
			break
	if(contained != suppressed)
		var/release_emp = suppressed && !isnull(containment_started_at) && world.time - containment_started_at >= containment_emp_arm_time
		suppressed = contained
		update_appearance(UPDATE_ICON_STATE)
		if(suppressed)
			hum?.stop()
		else
			hum?.start()
		// Clear the previous charge before the EMP can cause any further containment changes.
		containment_started_at = contained ? world.time : null
		visible_message(span_warning((suppressed ? "[src]'s ominous hum subsides inside a containment field." : "[src]'s containment fails! Its ominous hum returns.")))
		if(release_emp)
			visible_message(span_userdanger("[src] discharges a massive electromagnetic pulse as its containment collapses!"))
			release_containment_pulse()
		else if(!suppressed)
			visible_message(span_notice("[src]'s containment feedback dissipates before fully charging. No electromagnetic pulse is released."))
	return suppressed

/// A charged release hits each connected floor once, after its stored charge has been cleared.
/obj/structure/ms13_hivemind/core/marker/proc/release_containment_pulse()
	var/turf/site = get_turf(src)
	if(!site)
		return
	for(var/mob/living/carbon/human/human as anything in GLOB.human_list)
		if(human.stat == DEAD || get_dist_multiz(src, human) > influence_radius)
			continue
		to_chat(human, span_userdanger("An impossible pressure tears through your head and throws you to the ground!"))
		human.Knockdown(3 SECONDS)
		human.blind_eyes(2.5) // Normal recovery is half a point per second: five seconds.
		COOLDOWN_START(human, ms13_marker_haunt, MS13_MARKER_HAUNT_COOLDOWN)
		new /datum/hallucination/ms13_marker(human, TRUE, 1, TRUE)
	for(var/level in SSmapping.get_zstack(site.z))
		var/vertical_cost = abs(level - site.z) * MULTIZ_LEVEL_DISTANCE
		var/light_range = max(containment_emp_heavy_range, containment_emp_light_range) - vertical_cost
		if(light_range >= 0)
			empulse(locate(site.x, site.y, level), containment_emp_heavy_range - vertical_cost, light_range, level == site.z)
		CHECK_TICK

/// The Marker's hum. Its sound goes in mid_sounds, and mid_length is how long that sound runs (deciseconds), so each
/// play starts as the last ends.
/datum/looping_sound/ms13_marker_hum
	mid_sounds = list('mojave/sound/wip/necromorphs/marker_hum2.ogg' = 1)
	mid_length = 9.311 SECONDS
	// Never loud, but carrying: a slow fade out to 17 + extra_range tiles, heard through walls with each one halving it
	// (ms13_wall_muffle()), so it's still there a few rooms off, dimly.
	volume = 32
	extra_range = 60 // just enough to reach the BoS base
	falloff_distance = 3
	falloff_exponent = 2

/// Dormant while contained, pulsing while loose.
/obj/structure/ms13_hivemind/core/marker/update_icon_state()
	icon_state = suppressed ? "marker_giant_dormant" : "marker_giant_active_anim"
	return ..()

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
		if(!human.client || human.stat != CONSCIOUS || !COOLDOWN_FINISHED(human, ms13_marker_haunt))
			continue
		var/distance = get_dist_multiz(src, human)
		if(influence_radius <= 0 || distance > influence_radius)
			continue
		// The nearer, the more often and the worse: 10% a pulse at the edge of its reach, up to 40% beside it.
		var/closeness = 1 - distance / influence_radius
		if(prob(10 + 30 * closeness))
			COOLDOWN_START(human, ms13_marker_haunt, MS13_MARKER_HAUNT_COOLDOWN)
			new /datum/hallucination/ms13_marker(human, TRUE, closeness)
	disturb_lights()
	// Every corpse in reach, each pulse: cheap position checks first.
	// ponytail: walks the whole dead_mob_list every 10 seconds; a spatial lookup if that list ever runs to thousands.
	var/remade = 0
	for(var/mob/living/corpse in GLOB.dead_mob_list)
		// dead_mob_list also contains observers; the typed loop skips them.
		if(get_dist_multiz(src, corpse) > corpse_reach)
			continue
		if(!network.is_convertible_corpse(corpse))
			continue
		if(length(network.units) >= network.max_units)
			break
		var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/remains = corpse
		var/reviving = istype(remains) && remains.revivable_hive_corpse
		if(!reviving && (LAZYLEN(corpse.grabbed_by) || network.get_corpse_claim(corpse)))
			continue
		// Player-held bodies stay put. A hive worker carrying an intact unit need not tend it first.
		var/held_by_person = FALSE
		for(var/obj/item/hand_item/grab/grab as anything in corpse.grabbed_by)
			var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler = grab.assailant
			if(!istype(hauler) || hauler.network != network)
				held_by_person = TRUE
		if(held_by_person)
			continue
		// Existing bodies stand up where they fell; only new births need a free spawn tile.
		if(!reviving && !network.get_unit_spawn_turf(get_turf(corpse)))
			continue
		var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/worker = network.get_corpse_claim(corpse)
		if(network.advance_corpse_conversion(corpse, src, 10, 20, claim = FALSE))
			if(reviving && istype(worker))
				worker.clear_corpse_task()
			if(++remade >= corpses_per_pulse)
				break

#include "marker_lighting.dm"

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
	var/list/lines = lines()
	if(marker.is_suppressed())
		for(var/datum/powernet/line as anything in lines)
			line.newavail += 1000000
		return
	// Uncontained, it stutters: now and then nothing for a moment, and a wobbling supply meanwhile.
	if(prob(MS13_MARKER_DROPOUT_CHANCE * delta_time))
		return
	var/supply = 1000000 * (1 + MS13_MARKER_RIPPLE * (rand() * 2 - 1))
	for(var/datum/powernet/line as anything in lines)
		line.newavail += supply
		line.ms13_new_ripple = max(line.ms13_new_ripple, MS13_MARKER_RIPPLE)

/// Its own line, and every line run under the Marker's base (its tile and one either side), knotted there or not.
/obj/machinery/power/ms13_marker_feed/proc/lines()
	. = list()
	if(powernet)
		. += powernet
	for(var/dx in -1 to 1)
		for(var/obj/structure/cable/wire in locate(x + dx, y, z))
			if(wire.powernet)
				. |= wire.powernet

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

/mob/living/carbon/human
	COOLDOWN_DECLARE(ms13_marker_haunt)

/**
 * Something only its victim sees or hears, and nothing that can hurt them. Far off, a whisper; nearer, voices and things
 * moving behind them, then glimpses of something watching; beside the Marker, now and then, something lunging out of
 * the dark that isn't there.
 */
/datum/hallucination/ms13_marker
	var/image/phantom
	var/client/viewer

/datum/hallucination/ms13_marker/New(mob/living/carbon/human/victim, forced = TRUE, closeness = 0, backlash = FALSE)
	. = ..()
	viewer = victim.client
	if(backlash)
		// Do not raise generic hallucination: its random pool includes cartoon monsters and fake deaths.
		feedback_details = "Marker containment backlash: intrusive voices and visual disorientation."
		whisper()
		voice()
		victim.blur_eyes(10)
		victim.apply_status_effect(/datum/status_effect/confusion, 15 SECONDS)
		shake_camera(victim, 3 SECONDS, 3)
		for(var/delay in list(4 SECONDS, 8 SECONDS, 12 SECONDS))
			addtimer(CALLBACK(src, PROC_REF(voice)), delay)
		QDEL_IN(src, 15 SECONDS)
		return
	var/list/kinds = list("whisper" = 4)
	if(closeness >= 0.25)
		kinds["voice"] = 2
		kinds["stalker"] = 2
	if(closeness >= 0.4)
		kinds["glimpse"] = 3
	if(closeness >= 0.75)
		kinds["lunge"] = 1
	var/kind = pick_weight(kinds)
	feedback_details = "Marker hallucination: [kind]."
	switch(kind)
		if("whisper")
			whisper()
		if("voice")
			voice()
		if("stalker")
			stalker()
		if("glimpse")
			glimpse()
		if("lunge")
			lunge()
	QDEL_IN(src, 3 SECONDS)

/datum/hallucination/ms13_marker/Destroy()
	if(viewer)
		viewer.images -= phantom
	phantom = null
	viewer = null
	return ..()

/datum/hallucination/ms13_marker/proc/whisper()
	var/static/list/lines = list("Make us whole.", "Bring us home.", "Don't be afraid.", "You're almost there.", "We're here. We've always been here.", "Let go.", "There's nothing to fear. Not anymore.", "Come closer.")
	to_chat(target, span_hear("<i>...[pick(lines)]...</i>"))

/// A voice, just behind them.
/datum/hallucination/ms13_marker/proc/voice()
	var/static/list/voices = list('sound/hallucinations/behind_you1.ogg', 'sound/hallucinations/behind_you2.ogg', 'sound/hallucinations/turn_around1.ogg', 'sound/hallucinations/turn_around2.ogg', 'sound/hallucinations/i_see_you1.ogg', 'sound/hallucinations/im_here1.ogg', 'sound/hallucinations/over_here2.ogg')
	target.playsound_local(get_step(target, turn(target.dir, 180)), pick(voices), 20, FALSE)

/// Something moving a few steps behind them.
/datum/hallucination/ms13_marker/proc/stalker()
	var/static/list/noises = list('mojave/sound/wip/necromorphs/slasher_shout_1.ogg', 'mojave/sound/wip/necromorphs/lurker_shout_1.ogg', 'mojave/sound/wip/necromorphs/infector_shout_1.ogg')
	var/turf/behind = get_ranged_target_turf(target, turn(target.dir, 180), rand(3, 5))
	target.playsound_local(behind, pick(noises), 25, TRUE)

/// Something watching from a few tiles off, gone as soon as it's seen.
/datum/hallucination/ms13_marker/proc/glimpse()
	var/list/spots = list()
	for(var/turf/open/spot in view(7, target))
		if(get_dist(spot, target) >= 4 && !spot.density)
			spots += spot
	if(!length(spots) || !viewer)
		return whisper()
	var/static/list/watchers = list('mojave/icons/wip/terrain_hivemind/ds13_slasher.dmi', 'mojave/icons/wip/terrain_hivemind/ds13_infector.dmi', 'mojave/icons/wip/terrain_hivemind/ds13_exploder.dmi')
	phantom = image(pick(watchers), pick(spots), "preview", MOB_LAYER)
	phantom.pixel_x = -8
	phantom.alpha = 0
	viewer.images += phantom
	animate(phantom, alpha = 190, time = 0.3 SECONDS)
	animate(time = 0.6 SECONDS)
	animate(alpha = 0, time = 0.4 SECONDS)

/// Something lunging at them from right beside them, and nothing there.
/datum/hallucination/ms13_marker/proc/lunge()
	var/turf/from = get_step(target, pick(GLOB.alldirs))
	if(!from || !viewer)
		return whisper()
	phantom = image('mojave/icons/wip/terrain_hivemind/ds13_slasher.dmi', from, "preview", ABOVE_MOB_LAYER)
	phantom.pixel_x = -8
	viewer.images += phantom
	target.playsound_local(from, 'mojave/sound/wip/necromorphs/slasher_attack_1.ogg', 40, TRUE)
	to_chat(target, span_danger("Something lunges at you out of the dark!"))
	animate(phantom, pixel_x = (target.x - from.x) * 20 - 8, pixel_y = (target.y - from.y) * 20, time = 0.2 SECONDS)
	animate(alpha = 0, time = 0.2 SECONDS)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(to_chat), target, span_notice("...There's nothing there.")), 1.5 SECONDS)

#undef MS13_MARKER_HAUNT_COOLDOWN
#undef MS13_MARKER_DROPOUT_CHANCE
#undef MS13_MARKER_RIPPLE

#ifdef UNIT_TESTS
/datum/unit_test/ms13_marker_reanimation
	name = "MOJAVE SUN: Marker Reanimation Respects Sight And Sunlight"
	var/datum/time_of_day/old_sky
	var/atom/movable/outdoor_effect/sky_effect
	var/old_sky_state
	var/created_sky_effect = FALSE

/datum/unit_test/ms13_marker_reanimation/Destroy()
	SSoutdoor_effects.current_step_datum = old_sky
	if(created_sky_effect)
		qdel(sky_effect, force = TRUE)
	else if(sky_effect)
		sky_effect.state = old_sky_state
	return ..()

/datum/unit_test/ms13_marker_reanimation/Run()
	old_sky = SSoutdoor_effects.current_step_datum
	var/turf/site = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	sky_effect = site.outdoor_effect
	if(!sky_effect)
		sky_effect = new(site)
		created_sky_effect = TRUE
	old_sky_state = sky_effect.state
	sky_effect.state = SKY_BLOCKED
	SSoutdoor_effects.current_step_datum = locate(/datum/time_of_day/midnight) in SSoutdoor_effects.time_cycle_steps
	var/datum/ms13_terrain_hivemind/necromorph/marker/network = new
	allocated += network
	network.active = TRUE
	network.resources = 500
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier/corpse = allocate(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier, site, network)
	corpse.death()
	corpse.hive_reanimate_after = 0
	var/mob/living/carbon/human/consistent/witness = allocate(/mob/living/carbon/human/consistent, locate(site.x + 3, site.y, site.z))
	witness.see_in_dark = 8 // Test facing and occlusion without depending on the test room's light processing.
	witness.update_fov()
	witness.setDir(WEST)
	if(corpse.stat != DEAD || !witness.in_fov(corpse) || !(corpse in view(world.view, witness)))
		Fail("The observation fixture is not a visible dead body: state [corpse.stat], facing [witness.in_fov(corpse)], view [corpse in view(world.view, witness)].")
		return
	if(!(!network.advance_corpse_conversion(corpse, network, 1, 1) && corpse.stat == DEAD))
		Fail("The Marker revives a corpse in a person's field of view.")
	if(!(network.resources == 500 && !length(network.corpse_claims)))
		Fail("A blocked revival spends resources or reserves the body.")
	witness.setDir(EAST)
	if(!(network.can_reanimate_at(corpse)))
		Fail("Looking away does not release the revival restriction.")
	network.advance_corpse_conversion(corpse, network, 1, 2)
	witness.setDir(WEST)
	if(!(!network.advance_corpse_conversion(corpse, network, 1, 2) && network.corpse_conversion_progress[WEAKREF(corpse)] == 0.5))
		Fail("Looking back does not pause partially completed revival.")
	var/obj/structure/closet/crate/occluder = allocate(/obj/structure/closet/crate, get_step(site, EAST))
	occluder.set_opacity(TRUE)
	if(!(network.can_reanimate_at(corpse)))
		Fail("A person sees through an opaque obstruction when blocking revival.")
	qdel(occluder)
	ADD_TRAIT(witness, TRAIT_BLIND, REF(src))
	if(!(network.can_reanimate_at(corpse)))
		Fail("A blind person blocks revival.")
	REMOVE_TRAIT(witness, TRAIT_BLIND, REF(src))
	// A visible open-space projection must count even when the actual body is on another floor.
	corpse.forceMove(locate(site.x, site.y, site.z - 1))
	var/atom/movable/openspace/mimic/projection = allocate(/atom/movable/openspace/mimic, site)
	projection.appearance = corpse.appearance
	projection.associated_atom = corpse
	corpse.bound_overlay = projection
	if(network.can_reanimate_at(corpse))
		Fail("Watching a corpse's open-space projection from another floor permits revival.")
	qdel(projection)
	if(!network.can_reanimate_at(corpse))
		Fail("A person on another floor blocks a body that has no visible projection.")
	corpse.forceMove(site)
	witness.setDir(EAST)
	if(!(network.advance_corpse_conversion(corpse, network, 1, 2) && corpse.stat == CONSCIOUS))
		Fail("Paused revival does not resume when unobserved.")
	corpse.death()
	corpse.forceMove(site)
	corpse.hive_reanimate_after = 0
	sky_effect.state = SKY_VISIBLE
	SSoutdoor_effects.current_step_datum = locate(/datum/time_of_day/daytime) in SSoutdoor_effects.time_cycle_steps
	var/resources_before = network.resources
	if(network.can_reanimate_at(corpse))
		Fail("Sunlight fixture permits revival: sky [SSoutdoor_effects.current_step_datum?.type], effect [site.outdoor_effect?.state] (saved [sky_effect.state], same [site.outdoor_effect == sky_effect]), body [corpse.x],[corpse.y],[corpse.z] / site [site.x],[site.y],[site.z], owned [network.is_territory(get_turf(corpse))].")
	if(!(!network.advance_corpse_conversion(corpse, network, 1, 1) && network.resources == resources_before))
		Fail("Direct sunlight permits revival or consumes resources.")
	SSoutdoor_effects.current_step_datum = locate(/datum/time_of_day/midnight) in SSoutdoor_effects.time_cycle_steps
	if(!(network.can_reanimate_at(corpse)))
		Fail("An outdoor corpse stays blocked after night falls.")
	SSoutdoor_effects.current_step_datum = locate(/datum/time_of_day/daytime) in SSoutdoor_effects.time_cycle_steps
	sky_effect.state = SKY_BLOCKED
	if(!(network.can_reanimate_at(corpse)))
		Fail("Sheltered ground is treated as direct sunlight.")
	sky_effect.state = SKY_VISIBLE
	witness.setDir(WEST)
	allocate(/obj/structure/ms13_hivemind/terrain, site, network)
	if(!(network.advance_corpse_conversion(corpse, network, 1, 1) && corpse.stat == CONSCIOUS))
		Fail("Owned hivemind mass does not override both sunlight and observation.")
	// The actual pulse must revive a reserved body with only the cheaper repair budget.
	var/obj/structure/ms13_hivemind/core/marker/marker = allocate(/obj/structure/ms13_hivemind/core/marker, get_step(site, SOUTH), network)
	network.core = marker
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler/worker = allocate(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler, get_step(site, NORTH), network)
	worker.toggle_ai(AI_OFF)
	corpse.death()
	corpse.hive_reanimate_after = 0
	network.claim_corpse(corpse, worker)
	worker.corpse_target_ref = WEAKREF(corpse)
	worker.try_make_grab(corpse)
	// A dense object sharing the body must not be treated as a failed newborn spawn.
	allocate(/obj/structure/closet/crate, site)
	network.resources = network.get_unit_revival_cost(corpse.type)
	COOLDOWN_RESET(marker, influence_cooldown)
	marker.process(1)
	if(corpse.stat != DEAD)
		Fail("Marker skipped the visible transformation stage.")
	COOLDOWN_RESET(marker, influence_cooldown)
	marker.process(1)
	if(corpse.stat != CONSCIOUS || network.resources != 0 || worker.corpse_target_ref || length(corpse.grabbed_by) || network.get_corpse_claim(corpse))
		Fail("The Marker could not automatically revive and release a claimed body on its reduced budget.")
#endif
