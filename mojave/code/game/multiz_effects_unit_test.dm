/mob/living/carbon/human/consistent/ms13_multiz_listener
	var/local_sounds = 0
	var/distant_sounds = 0

/mob/living/carbon/human/consistent/ms13_multiz_listener/playsound_local(turf/turf_source, soundin, vol, vary, frequency, falloff_exponent, channel, pressure_affected, sound/sound_to_use, max_distance, falloff_distance, distance_multiplier, use_reverb, wait)
	local_sounds++
	return TRUE

/mob/living/carbon/human/consistent/ms13_multiz_listener/hear_distant_sound(turf/turf_source, soundin, far_sound, vol, remoteness, vary)
	distant_sounds++

/mob/living/carbon/human/consistent/ms13_multiz_listener/Destroy()
	SSmobs.clients_by_zlevel[z] -= src
	return ..()

/datum/unit_test/ms13_multiz_effects
	name = "MS13 multiz: sound, Marker backlash, lights and utility breaker recovery"

/datum/unit_test/ms13_multiz_effects/Run()
	var/datum/space_level/lower = SSmapping.add_new_zlevel("Effect lower", list(ZTRAIT_UP = 1))
	SSmapping.get_zstack(lower.z_value) // A lookup before the upper floors exist must not poison later queries.
	var/datum/space_level/middle = SSmapping.add_new_zlevel("Effect middle", list(ZTRAIT_DOWN = -1, ZTRAIT_UP = 1))
	var/datum/space_level/upper = SSmapping.add_new_zlevel("Effect upper", list(ZTRAIT_DOWN = -1))
	SSzcopy.calculate_zstack_limits()
	var/turf/bottom = locate(20, 20, lower.z_value)
	var/turf/above = locate(20, 20, middle.z_value)
	var/turf/top = locate(20, 20, upper.z_value)
	bottom = bottom.ChangeTurf(/turf/open/floor/plating)
	above = above.ChangeTurf(/turf/open/floor/plating)
	top = top.ChangeTurf(/turf/open/floor/plating)
	var/turf/unrelated = locate(20, 20, run_loc_floor_bottom_left.z)
	if(get_dist_multiz(bottom, above) != 5 || get_dist_multiz(top, bottom) != 10 || get_dist_multiz(bottom, get_step(top, EAST)) != 11 || get_dist_multiz(bottom, unrelated) != INFINITY)
		Fail("Connected-floor distances do not charge five tiles each or reject unrelated floors.")
	if(length(SSmapping.get_zstack(top)) != 3 || length(SSmapping.get_zstack(bottom, TRUE)) != 3)
		Fail("Z-stack discovery did not traverse both directions after adding floors.")
	var/mob/living/carbon/human/consistent/ms13_multiz_listener/near = allocate(/mob/living/carbon/human/consistent/ms13_multiz_listener, above)
	var/mob/living/carbon/human/consistent/ms13_multiz_listener/far = allocate(/mob/living/carbon/human/consistent/ms13_multiz_listener, top)
	var/mob/living/carbon/human/consistent/ms13_multiz_listener/outside = allocate(/mob/living/carbon/human/consistent/ms13_multiz_listener, unrelated)
	for(var/mob/living/carbon/human/consistent/ms13_multiz_listener/listener in list(near, far, outside))
		SSmobs.clients_by_zlevel[listener.z] |= listener
	playsound(bottom, 'sound/machines/click.ogg', 60, FALSE, -10, pressure_affected = FALSE)
	if(near.local_sounds != 1 || far.local_sounds || outside.local_sounds)
		Fail("Local sound did not spend its range crossing floors.")
	playsound(bottom, 'sound/machines/click.ogg', 60, FALSE, pressure_affected = FALSE)
	if(near.local_sounds != 2 || far.local_sounds != 1 || outside.local_sounds)
		Fail("Ordinary sound did not reach two floors away or leaked into another region.")
	playsound_distant(bottom, 'sound/machines/click.ogg', 40, 40, near_vol = 40, near_max = 4)
	sleep(0.3 SECONDS)
	if(near.distant_sounds != 1 || far.distant_sounds != 1 || outside.distant_sounds)
		Fail("Distant sound did not use the same connected-floor listener selection.")
	var/sound/vertical = make_distant_sound(bottom, top, 'sound/machines/click.ogg', 40, 0.5, FALSE, TRUE)
	if(vertical.y != -10 || vertical.falloff != 11)
		Fail("Distant sound did not preserve its vertical direction and weighted distance.")
	var/datum/ms13_terrain_hivemind/necromorph/marker/hive = new(bottom, 0)
	allocated += hive
	hive.territory_limit = 0
	var/obj/structure/ms13_hivemind/core/marker/marker = hive.core
	marker.influence_radius = 12
	marker.light_flicker_radius = 12
	marker.containment_emp_heavy_range = 7
	marker.containment_emp_light_range = 12
	var/obj/machinery/light/ms13/lamp = allocate(/obj/machinery/light/ms13, top)
	lamp.switchcount = -1
	lamp.on = TRUE
	lamp.update(FALSE, TRUE, FALSE)
	marker.disturb_lights()
	var/datum/component/ms13_light_flicker/flicker = lamp.GetComponent(/datum/component/ms13_light_flicker)
	if(!flicker || !length(flicker.markers))
		Fail("A light two floors above the Marker did not gain its influence at startup.")
	else
		flicker.stop_flicker()
		flicker.next_flicker_at = world.time
		flicker.process(1)
		if(!flicker.flicker_steps || lamp.light_power >= lamp.bulb_power * 0.8)
			Fail("An influenced light no longer performs occasional visible brightness dips.")
		lamp.light?.update_corners()
		if(!lamp.light || abs(lamp.light.light_power - lamp.bulb_power * 0.15) > 0.001)
			Fail("Flicker changed the fixture variable without updating the rendered light source.")
		for(var/image/glow as anything in lamp.overlays)
			if(glow.alpha > 39)
				Fail("The fixture's glowing sprite remained bright during a flicker dip.")
		sleep(0.6 SECONDS)
		if(flicker.flicker_steps || abs(lamp.light_power - lamp.bulb_power * 0.8) > 0.001)
			Fail("The occasional cross-floor flicker failed to settle.")
	var/obj/machinery/power/apc/ms13/box = allocate(/obj/machinery/power/apc/ms13, above)
	var/area/powered = new
	allocated += powered
	box.area = powered
	box.always_powered = TRUE
	box.operating = TRUE
	box.lighting = APC_CHANNEL_ON
	box.equipment = APC_CHANNEL_OFF
	box.environ = APC_CHANNEL_ON
	box.update()
	var/obj/effect/ms13_marker_emp_test_probe/near_probe = allocate(/obj/effect/ms13_marker_emp_test_probe, above)
	var/obj/effect/ms13_marker_emp_test_probe/far_probe = allocate(/obj/effect/ms13_marker_emp_test_probe, top)
	var/obj/effect/ms13_marker_emp_test_probe/outside_probe = allocate(/obj/effect/ms13_marker_emp_test_probe, unrelated)
	marker.suppressed = TRUE
	marker.containment_started_at = world.time - marker.containment_emp_arm_time
	marker.is_suppressed()
	marker.is_suppressed()
	if(near_probe.pulses != 1 || near_probe.last_severity != EMP_HEAVY || far_probe.pulses != 1 || far_probe.last_severity != EMP_LIGHT || outside_probe.pulses)
		Fail("The charged EMP did not attenuate across floors, escaped its region or fired twice.")
	if(!near.IsKnockdown() || !far.IsKnockdown() || far.eye_blind < 2 || !far.eye_blurry || !far.has_status_effect(/datum/status_effect/confusion) || far.hallucination || outside.IsKnockdown())
		Fail("Backlash did not immediately knock down, blind and disorient nearby humans without generic hallucinations.")
	if(box.operating || powered.power_light || box.lighting != APC_CHANNEL_ON || box.equipment != APC_CHANNEL_OFF || box.shorted)
		Fail("EMP did not trip the utility breaker while preserving settings and avoiding shorts.")
	box.reset(APC_RESET_EMP)
	if(box.operating || box.equipment != APC_CHANNEL_OFF)
		Fail("An old EMP timer restarted or reconfigured the physical breaker.")
	box.toggle_breaker()
	box.process(1)
	if(!powered.power_light || powered.power_equip || !powered.power_environ)
		Fail("One manual breaker toggle did not restore the pre-EMP channels.")
	if(!flicker?.flicker_steps)
		Fail("The cross-floor EMP did not start a finite flicker on a powered light.")
	sleep(3.4 SECONDS)
	if(flicker?.flicker_steps || lamp.status != LIGHT_OK || lamp.switchcount != 0)
		Fail("EMP flicker did not finish without repeated bulb wear.")
	far.handle_traits(5, 1)
	if(far.eye_blind)
		Fail("Backlash blindness did not recover after five seconds of normal living updates.")
	marker.light_flicker_radius = 9
	flicker?.process(1)
	if(lamp.GetComponent(/datum/component/ms13_light_flicker))
		Fail("Reducing the radius below the two-floor cost left its dimming attached.")

/datum/unit_test/ms13_cell_emp
	name = "MS13 cells: reduced EMP drain, charge floor and shielding"

/datum/unit_test/ms13_cell_emp/Run()
	for(var/cell_type in subtypesof(/obj/item/stock_parts/cell/ms13))
		var/obj/item/stock_parts/cell/cell = allocate(cell_type)
		cell.charge = cell.maxcharge
		cell.emp_act(EMP_HEAVY)
		if(cell.charge != cell.maxcharge - 50)
			Fail("[cell_type] lost more than 50 charge to a heavy EMP.")
		cell.emp_act(EMP_LIGHT)
		if(cell.charge != cell.maxcharge - 75)
			Fail("[cell_type] lost more than 25 charge to a light EMP.")
		cell.charge = 10
		cell.emp_act(EMP_HEAVY)
		if(cell.charge != 0)
			Fail("EMP drain left a negative charge.")
		cell.charge = cell.maxcharge
		cell.AddElement(/datum/element/empprotection, EMP_PROTECT_SELF)
		cell.emp_act(EMP_HEAVY)
		if(cell.charge != cell.maxcharge)
			Fail("Reduced drain bypassed EMP shielding.")
	var/obj/item/stock_parts/cell/ordinary = allocate(/obj/item/stock_parts/cell)
	ordinary.charge = 2000
	ordinary.emp_act(EMP_HEAVY)
	if(ordinary.charge != 1000)
		Fail("The MS13 balance adjustment changed ordinary cells.")
