/// Cable can be run across the ground, roads and indoor floors.
/datum/unit_test/ms13_cable_on_any_floor/Run()
	var/mob/living/carbon/human/consistent/electrician = ALLOCATE_BOTTOM_LEFT()
	var/obj/item/stack/cable_coil/coil = allocate(/obj/item/stack/cable_coil)
	electrician.put_in_hands(coil)
	var/turf/spot = get_step(run_loc_floor_bottom_left, EAST)
	var/original_type = spot.type
	for(var/floor_type in list(/turf/open/floor/plating/ms13/ground/desert, /turf/open/floor/plating/ms13/ground/road, /turf/open/floor/ms13/tile, /turf/open/floor/wood/ms13/common))
		spot = spot.ChangeTurf(floor_type)
		coil.place_turf(spot, electrician)
		var/obj/structure/cable/cable = locate() in spot
		TEST_ASSERT(cable, "Couldn't lay cable on [floor_type].")
		qdel(cable)
	spot.ChangeTurf(original_type)

/// A wired-look prop draws a cable out to a neighbouring cable that ends at its edge, and only then.
/datum/unit_test/ms13_wired_look/Run()
	var/turf/prop_spot = run_loc_floor_bottom_left
	var/turf/cable_spot = get_step(prop_spot, NORTH)
	var/prop_turf_type = prop_spot.type
	var/cable_turf_type = cable_spot.type
	prop_spot = prop_spot.ChangeTurf(/turf/open/floor/plating)
	cable_spot = cable_spot.ChangeTurf(/turf/open/floor/plating)
	var/obj/structure/ms13/pay_phone/phone = allocate(/obj/structure/ms13/pay_phone, prop_spot)
	var/obj/structure/cable/cable = new(cable_spot)

	cable.set_directions(CABLE_SOUTH)
	var/list/toward = list()
	SEND_SIGNAL(phone, COMSIG_ATOM_UPDATE_OVERLAYS, toward)
	cable.set_directions(CABLE_NORTH)
	var/list/away = list()
	SEND_SIGNAL(phone, COMSIG_ATOM_UPDATE_OVERLAYS, away)
	TEST_ASSERT_EQUAL(length(toward), length(away) + 1, "The payphone didn't draw exactly one wire to the cable ending at it.")

	qdel(cable)
	prop_spot.ChangeTurf(prop_turf_type)
	cable_spot.ChangeTurf(cable_turf_type)

/// A dead animal keeps its meat inside until it's cut open, and its body stays put.
/datum/unit_test/ms13_carcass_storage/Run()
	var/mob/living/carbon/human/consistent/hunter = ALLOCATE_BOTTOM_LEFT()
	var/mob/living/simple_animal/ms13/clucker/bird = ALLOCATE_BOTTOM_LEFT()
	bird.death()
	TEST_ASSERT(!QDELETED(bird), "The carcass was deleted on death.")
	TEST_ASSERT(!length(bird.butcher_results), "Butchering could still drop the carcass's meat on the floor.")
	var/datum/component/ms13_searchable/cavity = bird.GetComponent(/datum/component/ms13_searchable)
	TEST_ASSERT(cavity, "The carcass has nothing to cut open.")
	TEST_ASSERT_EQUAL(cavity.open_tool, TOOL_KNIFE, "The carcass isn't opened with a blade.")
	TEST_ASSERT(SEND_SIGNAL(bird, COMSIG_ATOM_ATTACK_HAND, hunter, list()) & COMPONENT_CANCEL_ATTACK_CHAIN, "An uncut carcass opened by hand.")

	cavity.searched = TRUE
	cavity.do_first_search()
	TEST_ASSERT(bird.atom_storage, "Cutting the carcass open gave it no storage.")
	TEST_ASSERT(locate(/obj/item/food/meat/slab/ms13/carcass/clucker) in bird, "The meat wasn't inside the opened carcass.")
	TEST_ASSERT(!(locate(/obj/item/food/meat/slab/ms13/carcass/clucker) in bird.loc), "The meat spilled onto the floor.")
