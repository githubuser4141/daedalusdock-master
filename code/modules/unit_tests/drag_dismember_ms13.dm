/// Dragging tears off only a broken, mangled arm or leg - never a merely broken one.
/datum/unit_test/drag_dismember/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/mangled = victim.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/broken = victim.get_bodypart(BODY_ZONE_R_ARM)
	mangled.break_bones(FALSE)
	broken.break_bones(FALSE)
	mangled.brute_dam = mangled.max_damage
	var/turf/start_turf = run_loc_floor_bottom_left
	var/turf/next_turf = get_step(start_turf, NORTH)

	// 8% a tile: 200 tiles all missing is about one in fifty million.
	for(var/i in 1 to 200)
		victim.drag_damage(next_turf, start_turf, NORTH)
		if(victim.get_bodypart(BODY_ZONE_L_ARM) != mangled)
			break
	TEST_ASSERT(victim.get_bodypart(BODY_ZONE_L_ARM) != mangled, "A broken, mangled arm never tore off while dragged.")
	TEST_ASSERT_EQUAL(victim.get_bodypart(BODY_ZONE_R_ARM), broken, "An arm that was only broken tore off while dragged.")
	TEST_ASSERT(victim.get_bodypart(BODY_ZONE_CHEST), "Dragging removed the chest.")
