#ifdef UNIT_TESTS
// Regression cases from the Mammoth gameplay runtime log (2026-09-20).
/datum/unit_test/ms13_runtime_regressions/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent, ground)
	var/atom/movable/screen/click_catcher/screen_target = allocate(/atom/movable/screen/click_catcher)
	if(in_view_range(null, screen_target) || in_view_range(human, screen_target))
		Fail("A screen object without a world location was considered a world target.")
	var/obj/item/bodypart/arm/left/arm = allocate(/obj/item/bodypart/arm/left, ground)
	arm.bodypart_flags |= BP_BROKEN_BONES
	if(arm.update_interaction_speed() <= 1)
		Fail("Detached broken arms lost their local interaction modifier.")
	var/obj/item/knife/ms13/combat/knife = allocate(/obj/item/knife/ms13/combat, ground)
	human.put_in_hands(knife)
	var/mob/living/simple_animal/hostile/expired = allocate(/mob/living/simple_animal/hostile, ground)
	qdel(expired)
	expired.GainPatience()
	if(expired.lose_patience_timer_id)
		Fail("A deleted attacker scheduled another patience timer.")
	// Missing mapper objects must not transfer their edits onto the next valid turf.
	var/datum/parsed_map/map = new
	map.grid_models = list("aaa" = "/obj/nonexistent_runtime_test{\n\tid_tag = 1\n\t},\n/turf/open/floor/plating{\n\tname = \"runtime test floor\"\n\t},\n/area/misc/start")
	var/list/cache = map.tgm_build_cache(FALSE)
	var/list/model = cache["aaa"]
	var/list/members = model[1]
	var/list/attributes = model[2]
	if(length(members) != 2 || length(attributes) != 2 || attributes[1]["id_tag"] || attributes[1]["name"] != "runtime test floor")
		Fail("Skipping an unknown TGM type misaligned the remaining map attributes.")
	qdel(map)
	var/datum/action/cooldown/mob_cooldown/charge/charge = new
	charge.check_flags |= AB_CHECK_CONSCIOUS
	charge.destroy_objects = FALSE
	charge.Grant(human)
	charge.do_charge(human, get_step(ground, NORTH), 0, 0)
	if(!charge.signal_procs[human]?[COMSIG_MOB_STATCHANGE])
		Fail("Finishing a charge removed the action's permanent status listener.")
	charge.do_charge(human, ground, 0, 0)
	qdel(charge)
	// Death callbacks can qdel a rammed mob before knockdown/pushing happens.
	var/obj/structure/ms13_vehicle_frame/jeep_front/jeep = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, locate(25, 25, ground.z))
	var/mob/living/simple_animal/ms13_runtime_victim/victim = allocate(/mob/living/simple_animal/ms13_runtime_victim, get_step(jeep, SOUTH))
	jeep.vehicle.ram_living(SOUTH, list())
	if(!QDELETED(victim))
		Fail("Ramming regression did not exercise the deleting death callback.")
	for(var/atom/movable/part as anything in (jeep.vehicle.get_all_parts() | jeep.vehicle.get_manifest()))
		qdel(part)
	for(var/pistol_type in list(/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm, /obj/item/gun/ballistic/automatic/pistol/ms13/m10mm/military, /obj/item/gun/ballistic/automatic/ms13/semi/marksman))
		var/obj/item/gun/ballistic/pistol = allocate(pistol_type, ground)
		if(pistol.show_bolt_icon || pistol.mag_display)
			Fail("MS pistols requested DD overlays instead of their complete sprite states.")
		pistol.update_appearance()

/mob/living/simple_animal/ms13_runtime_victim/apply_damage()
	qdel(src)
#endif
