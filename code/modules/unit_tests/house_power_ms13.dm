/// A walled-in room of indoor floor becomes a house with its own power, wired from its generator to its box.
/datum/unit_test/ms13_house_power/Run()
	var/list/room = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/area/old_area = get_area(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/electrician = allocate(/mob/living/carbon/human/consistent)
	var/list/old_types = list()
	for(var/turf/tile as anything in room)
		old_types[tile] = tile.type
		tile.ChangeTurf(/turf/open/floor/ms13/tile)
	SSatoms.map_loader_begin(REF(src))
	var/obj/machinery/light/ms13/test_light = new(run_loc_floor_bottom_left)
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(list(test_light))

	var/list/building = SSms13_house_power.find_building(run_loc_floor_bottom_left, list())
	TEST_ASSERT_EQUAL(length(building), length(room), "The room wasn't found as one building.")
	var/list/inside = list()
	for(var/turf/tile as anything in building)
		inside[tile] = TRUE
	TEST_ASSERT(SSms13_house_power.is_enclosed(inside), "A walled-in room didn't count as enclosed.")

	var/area/house = SSms13_house_power.power_building(building, "working")
	TEST_ASSERT(house.requires_power, "The house doesn't need power.")
	TEST_ASSERT_EQUAL(house.area_lighting, AREA_LIGHTING_DYNAMIC, "The generated house remained statically lit.")
	TEST_ASSERT_EQUAL(house.luminosity, 0, "The generated house remained fullbright.")
	TEST_ASSERT_EQUAL(get_area(run_loc_floor_bottom_left), house, "The room wasn't moved into the house area.")
	var/list/gear = find_gear(room)
	var/obj/machinery/ms13/fusion_generator/generator = gear[1]
	var/obj/machinery/power/apc/ms13/box = gear[2]
	TEST_ASSERT(generator && box, "A working house didn't get a generator and a utility box.")
	TEST_ASSERT_EQUAL(box.area, house, "The utility box doesn't run the house.")
	TEST_ASSERT_EQUAL(house.apc, box, "The utility box isn't registered as the house's area controller.")
	TEST_ASSERT(test_light in house.lights, "The house light remained registered to its old area.")
	TEST_ASSERT(house_is_live(generator, box), "A working generator didn't power its house.")
	box.process(2)
	TEST_ASSERT(house.power_light && test_light.on, "A powered utility box did not switch its house light on.")
	box.operating = FALSE
	box.update()
	TEST_ASSERT(!house.power_light && !test_light.on, "Turning off the utility box breaker did not switch its house light off.")
	box.operating = TRUE
	box.process(2)
	TEST_ASSERT(house.power_light && test_light.on, "Turning the utility box breaker back on did not restore its house light.")
	TEST_ASSERT_EQUAL(box.setsubsystem(2), APC_CHANNEL_ON, "The no-cell utility box rejected a manual channel-on setting.")
	var/list/ui_data = box.ui_data(electrician)
	TEST_ASSERT(ui_data["utilityBox"], "The utility box did not identify its no-cell UI variant.")

	// Snipped wiring leaves the house dark.
	QDEL_LIST(gear)
	qdel(test_light)
	clear_cables(room)
	SSms13_house_power.power_building(building, "working", 1, list("snip"))
	gear = find_gear(room)
	TEST_ASSERT(!house_is_live(gear[1], gear[2]), "A house got power through snipped wiring.")

	// Frayed wiring does too, until someone splices it.
	QDEL_LIST(gear)
	clear_cables(room)
	SSms13_house_power.power_building(building, "working", 1, list("fray"))
	gear = find_gear(room)
	TEST_ASSERT(!house_is_live(gear[1], gear[2]), "A house got power through frayed wiring.")
	var/obj/structure/ms13_frayed_cable/frayed
	for(var/turf/tile as anything in room)
		frayed ||= locate() in tile
	TEST_ASSERT(frayed, "No frayed cable was laid.")
	var/obj/item/stack/cable_coil/coil = allocate(/obj/item/stack/cable_coil)
	frayed.item_interaction(electrician, coil, list())
	TEST_ASSERT(house_is_live(gear[1], gear[2]), "Splicing the frayed cable didn't bring the power back.")

	// A box without a generator is infrastructure, not a source of free power.
	QDEL_LIST(gear)
	clear_cables(room)
	SSms13_house_power.power_building(building, "box_only")
	gear = find_gear(room)
	TEST_ASSERT(!gear[1] && gear[2], "A box-only house did not get exactly one utility box.")
	var/obj/machinery/power/apc/ms13/unpowered_box = gear[2]
	TEST_ASSERT(!unpowered_box.always_powered && !unpowered_box.has_incoming_power(), "A box-only house fabricated power without a generator.")

	QDEL_LIST(gear)
	clear_cables(room)
	for(var/turf/tile as anything in room)
		tile.change_area(get_area(tile), old_area)
		tile.ChangeTurf(old_types[tile])

/// list(generator, box) in room.
/datum/unit_test/ms13_house_power/proc/find_gear(list/room)
	var/obj/machinery/ms13/fusion_generator/generator
	var/obj/machinery/power/apc/ms13/box
	for(var/turf/tile as anything in room)
		generator ||= locate() in tile
		box ||= locate() in tile
	return list(generator, box)

/datum/unit_test/ms13_house_power/proc/clear_cables(list/room)
	for(var/turf/tile as anything in room)
		for(var/obj/structure/cable/wire in tile)
			qdel(wire)
		for(var/obj/structure/ms13_frayed_cable/frayed in tile)
			qdel(frayed)
		for(var/obj/structure/ms13/rug/rug in tile)
			qdel(rug)

/datum/unit_test/ms13_house_power/proc/house_is_live(obj/machinery/ms13/fusion_generator/generator, obj/machinery/power/apc/ms13/box)
	generator.condition = 100
	generator.fuel = generator.max_fuel
	generator.process(2)
	if(!generator.powernet || generator.powernet != box.terminal?.powernet)
		return FALSE
	generator.powernet.reset()
	return box.has_incoming_power()

/// A generator runs dry, takes a fusion core, and gives out when worn through.
/datum/unit_test/ms13_fusion_generator/Run()
	var/obj/machinery/ms13/fusion_generator/generator = allocate(/obj/machinery/ms13/fusion_generator)
	var/mob/living/carbon/human/consistent/mechanic = allocate(/mob/living/carbon/human/consistent)
	generator.fuel = 1
	generator.process(2)
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.generator_state, "off", "A generator kept running with no fuel.")

	var/obj/item/ms13/component/fusion/core = allocate(/obj/item/ms13/component/fusion)
	generator.item_interaction(mechanic, core, list())
	TEST_ASSERT(generator.fuel > 0, "A fusion core didn't refuel the generator.")
	TEST_ASSERT(QDELETED(core), "The fusion core wasn't used up.")

	generator.set_generator_state("on")
	generator.condition = 0
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.generator_state, "broken", "A worn-through generator kept running.")
