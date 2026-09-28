/obj/machinery/light
	/// An EMP can cycle area power repeatedly; give bulbs a gentler recovery window.
	var/ms13_emp_bulb_protection_until = 0

/obj/machinery/light/emp_act(severity)
	ms13_emp_bulb_protection_until = world.time + 90 SECONDS
	return ..()

/// Only electrical handheld lights and fixtures are affected, not fire or unrelated glowing objects.
/obj/structure/ms13_hivemind/core/marker/proc/disturb_lights()
	if(light_flicker_radius <= 0)
		return
	for(var/atom/movable/nearby in range(light_flicker_radius, src))
		if(istype(nearby, /obj/machinery/light))
			nearby.AddComponent(/datum/component/ms13_light_flicker, src)
		else if(istype(nearby, /obj/item/flashlight) && !istype(nearby, /obj/item/flashlight/flare))
			nearby.AddComponent(/datum/component/ms13_light_flicker, src)
		else if(isliving(nearby))
			for(var/obj/item/flashlight/handheld in nearby.contents)
				if(!istype(handheld, /obj/item/flashlight/flare))
					handheld.AddComponent(/datum/component/ms13_light_flicker, src)

/// Start only when a fixture actually gains light, not on routine power/appearance refreshes.
/obj/machinery/light/turn_on(trigger, play_sound = TRUE)
	var/starting = !light_outer_range && !flickering && !constant_flickering
	. = ..()
	if(QDELETED(src) || !starting || !on || status != LIGHT_OK || !light_outer_range)
		return
	var/datum/component/ms13_light_flicker/effect = AddComponent(/datum/component/ms13_light_flicker)
	// Resolve influence now: the first APC startup can precede the Marker's periodic influence pulse.
	for(var/datum/ms13_terrain_hivemind/necromorph/marker/hive in GLOB.ms13_terrain_hiveminds)
		var/obj/structure/ms13_hivemind/core/marker/marker = hive.core
		if(hive.active && marker && marker.z == z && marker.light_flicker_radius > 0 && get_dist(marker, src) <= marker.light_flicker_radius && !marker.is_suppressed())
			AddComponent(/datum/component/ms13_light_flicker, marker)
	if(!QDELETED(effect))
		effect.start_flicker(TRUE)

/// Shared finite startup effect; only Marker-affected lights retain it for later occasional flickers.
/datum/component/ms13_light_flicker
	dupe_mode = COMPONENT_DUPE_UNIQUE_PASSARGS
	var/list/markers = list()
	var/base_power
	var/brightness_multiplier = 1
	var/changing_power = FALSE
	var/flicker_steps = 0
	var/flicker_timer
	/// Each light chooses its own quiet interval; an influence refresh does not restart it.
	var/next_flicker_at = 0

/datum/component/ms13_light_flicker/Initialize(obj/structure/ms13_hivemind/core/marker/marker)
	if(!istype(parent, /obj/machinery/light) && !istype(parent, /obj/item/flashlight))
		return COMPONENT_INCOMPATIBLE
	if(marker)
		markers |= WEAKREF(marker)
	var/atom/lamp = parent
	base_power = lamp.light_power
	next_flicker_at = world.time + rand(60, 180) SECONDS
	START_PROCESSING(SSobj, src)

/datum/component/ms13_light_flicker/InheritComponent(datum/component/other, i_am_original, obj/structure/ms13_hivemind/core/marker/marker)
	if(marker)
		markers |= WEAKREF(marker)
		apply_power()

/datum/component/ms13_light_flicker/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_SET_LIGHT_POWER, PROC_REF(power_changed))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_LIGHT_ON, PROC_REF(light_toggled))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_LIGHT_RANGE, PROC_REF(range_changed))
	apply_power()

/datum/component/ms13_light_flicker/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_SET_LIGHT_POWER, COMSIG_ATOM_UPDATE_LIGHT_ON, COMSIG_ATOM_UPDATE_LIGHT_RANGE))
	if(!QDELETED(parent))
		apply_power(1)

/datum/component/ms13_light_flicker/Destroy(force)
	STOP_PROCESSING(SSobj, src)
	if(flicker_timer)
		deltimer(flicker_timer)
	markers = null
	return ..()

/datum/component/ms13_light_flicker/proc/power_changed(atom/source, new_power)
	SIGNAL_HANDLER
	if(changing_power)
		return
	base_power = new_power
	apply_power()
	return COMPONENT_BLOCK_LIGHT_UPDATE

/datum/component/ms13_light_flicker/proc/apply_power(factor)
	var/atom/lamp = parent
	if(isnull(factor))
		factor = flicker_steps % 2 ? (length(markers) ? 0.15 : 0.4) : (length(markers) ? 0.8 : 1)
	brightness_multiplier = factor
	changing_power = TRUE
	lamp.set_light_power(base_power * factor)
	if(lamp.light_system == COMPLEX_LIGHT)
		lamp.update_light()
	changing_power = FALSE

/datum/component/ms13_light_flicker/proc/light_toggled(atom/lamp)
	SIGNAL_HANDLER
	if(!lamp.light_on)
		stop_flicker()
	else if(isitem(lamp))
		start_flicker(TRUE)

/datum/component/ms13_light_flicker/proc/range_changed(atom/lamp)
	SIGNAL_HANDLER
	if(!lamp.light_outer_range)
		stop_flicker()

/datum/component/ms13_light_flicker/proc/stop_flicker()
	if(flicker_timer)
		deltimer(flicker_timer)
		flicker_timer = null
	flicker_steps = 0
	apply_power()
	if(!length(markers))
		qdel(src)

/datum/component/ms13_light_flicker/process(delta_time)
	var/turf/site = get_turf(parent)
	var/had_marker = length(markers)
	for(var/datum/weakref/ref as anything in markers.Copy())
		var/obj/structure/ms13_hivemind/core/marker/marker = ref.resolve()
		if(!site || !marker?.network?.active || marker.suppressed || marker.z != site.z || marker.light_flicker_radius <= 0 || get_dist(marker, site) > marker.light_flicker_radius)
			markers -= ref
	if(!length(markers))
		if(had_marker || !flicker_steps)
			qdel(src)
		return
	if(world.time >= next_flicker_at)
		start_flicker()

/datum/component/ms13_light_flicker/proc/start_flicker(startup = FALSE)
	var/atom/lamp = parent
	if(flicker_steps || !lamp.light_on || !lamp.light_outer_range)
		return
	flicker_steps = startup ? (length(markers) ? 8 : 4) : 2
	flicker()

/datum/component/ms13_light_flicker/proc/flicker()
	flicker_timer = null
	if(!flicker_steps)
		return
	flicker_steps--
	apply_power()
	if(flicker_steps)
		flicker_timer = addtimer(CALLBACK(src, PROC_REF(flicker)), 0.4 SECONDS, TIMER_STOPPABLE)
	else
		next_flicker_at = world.time + rand(60, 180) SECONDS
		if(!length(markers))
			qdel(src)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_marker_lighting
	name = "MS13 lighting: APC startup, occasional Marker flickers and recovery"
	var/area/powered_area
	var/list/saved_channels

/datum/unit_test/ms13_marker_lighting/Destroy()
	. = ..() // APC deletion powers its area off too; restore after fixture cleanup.
	if(powered_area && saved_channels)
		powered_area.power_light = saved_channels[1]
		powered_area.power_equip = saved_channels[2]
		powered_area.power_environ = saved_channels[3]
		powered_area.power_change()

/datum/unit_test/ms13_marker_lighting/Run()
	var/turf/site = run_loc_floor_bottom_left
	var/area/test_area = get_area(site)
	powered_area = test_area
	saved_channels = list(test_area.power_light, test_area.power_equip, test_area.power_environ)
	var/obj/machinery/power/apc/ms13/conduit/box = allocate(/obj/machinery/power/apc/ms13/conduit, site)
	box.area = test_area
	box.always_powered = TRUE
	box.lighting = APC_CHANNEL_ON
	box.operating = FALSE
	box.update()
	var/obj/machinery/light/ms13/fixture = allocate(/obj/machinery/light/ms13, site)
	fixture.status = LIGHT_OK
	fixture.switchcount = -1 // First switch-on becomes zero: exclude random bulb failure from this regression.
	fixture.maploaded = TRUE
	box.operating = TRUE
	box.update()
	var/datum/component/ms13_light_flicker/effect = fixture.GetComponent(/datum/component/ms13_light_flicker)
	if(!effect || effect.flicker_steps != 3 || abs(fixture.light_power - fixture.bulb_power * 0.4) > 0.001)
		Fail("An APC powering a normal fixture did not start its brief flicker.")
	sleep(1.6 SECONDS)
	if(!QDELETED(effect) || fixture.light_power != fixture.bulb_power || fixture.switchcount != 0)
		Fail("Normal startup did not finish at full brightness without extra bulb wear.")
	SSatoms.map_loader_begin(REF(src))
	var/obj/structure/ms13_hivemind/core/marker/mapped_marker = new(site)
	mapped_marker.light_flicker_radius = 2
	mapped_marker.containment_emp_arm_time = 12 SECONDS
	mapped_marker.containment_emp_heavy_range = 3
	mapped_marker.containment_emp_light_range = 6
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(list(mapped_marker))
	var/obj/structure/ms13_hivemind/core/marker/marker = locate() in site
	var/datum/ms13_terrain_hivemind/necromorph/marker/hive = marker.network
	allocated += hive
	hive.resources = 0
	hive.territory_limit = 0
	if(marker == mapped_marker || marker.light_flicker_radius != 2 || marker.influence_radius != 30)
		Fail("A mapped lighting radius was lost during Marker creation or changed its other influence.")
	if(marker.containment_emp_arm_time != 12 SECONDS || marker.containment_emp_heavy_range != 3 || marker.containment_emp_light_range != 6)
		Fail("A mapped Marker lost its containment charge time or EMP ranges.")
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent, site)
	var/obj/item/flashlight/ms13/handheld = allocate(/obj/item/flashlight/ms13, holder)
	var/original_power = handheld.light_power
	handheld.on = TRUE
	handheld.update_brightness()
	marker.disturb_lights()
	effect = handheld.GetComponent(/datum/component/ms13_light_flicker)
	if(!effect || effect.flicker_steps || abs(handheld.light_power - original_power * 0.8) > 0.001)
		Fail("Marker influence did not dim an already-lit flashlight without restarting it.")
		return
	handheld.on = FALSE
	handheld.update_brightness()
	handheld.on = TRUE
	handheld.update_brightness()
	if(effect.flicker_steps != 7 || abs(handheld.light_power - original_power * 0.15) > 0.001)
		Fail("Turning on a Marker-affected flashlight did not give it the stronger startup flicker.")
	sleep(3.2 SECONDS)
	if(effect.flicker_steps || abs(handheld.light_power - original_power * 0.8) > 0.001 || effect.next_flicker_at < world.time + 58 SECONDS || effect.next_flicker_at > world.time + 180 SECONDS)
		Fail("The initial burst did not settle into steady dimming with a one-to-three-minute quiet interval.")
	var/next_flicker = effect.next_flicker_at
	marker.disturb_lights()
	for(var/tick in 1 to 100)
		effect.process(100)
	if(effect.flicker_steps || effect.next_flicker_at != next_flicker || abs(handheld.light_power - original_power * 0.8) > 0.001)
		Fail("Repeated influence or processing restarted the startup burst or flickered during the quiet interval.")
	handheld.set_light_power(2)
	if(handheld.light_power != 1.6)
		Fail("A brightness change escaped the temporary dimming.")
	effect.next_flicker_at = world.time
	effect.process(2)
	if(effect.flicker_steps != 1 || handheld.light_power != 0.3)
		Fail("A later flicker was not a single short dip.")
	sleep(0.6 SECONDS)
	if(effect.flicker_steps || handheld.light_power != 1.6 || effect.next_flicker_at < world.time + 58 SECONDS)
		Fail("The later flicker did not settle and schedule another quiet interval.")
	handheld.on = FALSE
	handheld.update_brightness()
	marker.suppressed = TRUE
	effect.process(1)
	if(!QDELETED(effect) || handheld.light_power != 2 || handheld.light_on)
		Fail("Suppression failed to restore brightness or turned an off light on.")
	marker.suppressed = FALSE
	marker.disturb_lights()
	effect = handheld.GetComponent(/datum/component/ms13_light_flicker)
	holder.forceMove(locate(site.x + 40, site.y, site.z))
	effect.process(1)
	if(!QDELETED(effect) || handheld.light_power != 2)
		Fail("A carried light stayed dim after leaving the Marker's range.")
	holder.forceMove(locate(site.x + 3, site.y, site.z))
	marker.disturb_lights()
	if(handheld.GetComponent(/datum/component/ms13_light_flicker))
		Fail("A light outside the custom radius still acquired Marker influence.")
	holder.forceMove(locate(site.x + 2, site.y, site.z))
	marker.disturb_lights()
	effect = handheld.GetComponent(/datum/component/ms13_light_flicker)
	if(!effect)
		Fail("A light at the custom radius boundary was excluded.")
		return
	marker.light_flicker_radius = 1
	effect.process(1)
	if(!QDELETED(effect) || handheld.light_power != 2)
		Fail("Shrinking the lighting radius did not restore a carried light.")
	box.operating = FALSE
	box.update()
	fixture.switchcount = -1
	fixture.maploaded = TRUE
	box.operating = TRUE
	box.update()
	original_power = fixture.bulb_power
	effect = fixture.GetComponent(/datum/component/ms13_light_flicker)
	if(!effect || effect.flicker_steps != 7 || abs(fixture.light_power - original_power * 0.15) > 0.001)
		Fail("The Marker did not strengthen a wall fixture's APC startup flicker.")
		return
	box.operating = FALSE
	box.update()
	sleep(0.6 SECONDS)
	if(fixture.on || fixture.light_outer_range || effect.flicker_steps || effect.flicker_timer)
		Fail("Cutting APC power did not cancel the startup flicker and keep the fixture off.")
	fixture.switchcount = -1
	fixture.maploaded = TRUE
	box.operating = TRUE
	box.update()
	sleep(3.2 SECONDS)
	fixture.update(FALSE, TRUE, FALSE)
	if(effect.flicker_steps || fixture.switchcount != 0 || abs(fixture.light_power - original_power * 0.8) > 0.001)
		Fail("Marker startup did not settle, or a routine refresh added spurious bulb wear.")
	fixture.emp_act(EMP_HEAVY)
	if(fixture.status != LIGHT_OK || fixture.ms13_emp_bulb_protection_until < world.time + 89 SECONDS)
		Fail("An EMP did not leave the bulb intact with its reduced-burnout recovery window.")
	marker.light_flicker_radius = 0
	effect.process(1)
	marker.disturb_lights()
	if(!QDELETED(effect) || fixture.GetComponent(/datum/component/ms13_light_flicker) || abs(fixture.light_power - original_power) > 0.001)
		Fail("Zero lighting radius did not disable dimming even on the Marker's own tile.")
	box.operating = FALSE
	box.update()
	fixture.switchcount = -1
	fixture.maploaded = TRUE
	box.operating = TRUE
	box.update()
	effect = fixture.GetComponent(/datum/component/ms13_light_flicker)
	if(!effect || length(effect.markers) || effect.flicker_steps != 3)
		Fail("A disabled Marker still strengthened APC startup.")
	sleep(1.6 SECONDS)
	marker.light_flicker_radius = 30
	marker.disturb_lights()
	effect = fixture.GetComponent(/datum/component/ms13_light_flicker)
	qdel(marker)
	effect.process(1)
	if(!QDELETED(effect) || abs(fixture.light_power - original_power) > 0.001)
		Fail("Destroying the Marker left the wall fixture dimmed.")
#endif
