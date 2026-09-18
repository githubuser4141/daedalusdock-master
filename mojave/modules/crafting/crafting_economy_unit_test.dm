/datum/unit_test/ms13_crafting_economy/Run()
	var/turf/test_turf = run_loc_floor_bottom_left
	TEST_ASSERT_EQUAL(test_turf.atom_integrity, test_turf.max_integrity, "Open floors did not initialize their structural integrity.")
	var/obj/item/ms13/hammer/broken_tool = allocate(/obj/item/ms13/hammer, test_turf)
	broken_tool.deconstruct(FALSE)
	TEST_ASSERT(locate(/obj/item/stack/sheet/ms13/scrap_parts) in test_turf, "Destroying a manufactured MS item produced no reusable debris.")

	var/obj/item/ms13/component/cell/battery = allocate(/obj/item/ms13/component/cell, test_turf)
	TEST_ASSERT_EQUAL(battery.ms13_breakdown_result[/obj/item/stack/sheet/ms13/scrap_lead], 2, "Fission battery breakdown does not retain its lead yield.")
	TEST_ASSERT_EQUAL(battery.ms13_breakdown_result[/obj/item/stack/sheet/ms13/scrap_copper], 2, "Fission battery breakdown does not retain its copper yield.")

	var/obj/structure/table/ms13/crafting/workbench = allocate(/obj/structure/table/ms13/crafting/workbench, test_turf)
	TEST_ASSERT(!(workbench.resistance_flags & INDESTRUCTIBLE), "MS workbenches are still indestructible map fixtures.")

	var/obj/item/ms13/fluff/ruined_book/book = allocate(/obj/item/ms13/fluff/ruined_book, test_turf)
	var/obj/item/knife/ms13/knife = allocate(/obj/item/knife/ms13, test_turf)
	var/list/crafting_options = list()
	SEND_SIGNAL(book, "atom_craft_with", null, knife, crafting_options)
	TEST_ASSERT_EQUAL(length(crafting_options), 1, "The MS interaction-crafting element did not expose its attached recipe.")
