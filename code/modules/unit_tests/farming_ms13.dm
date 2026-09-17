/datum/unit_test/ms13_crop_farming
	name = "MOJAVE SUN: Crop Farming Core Loop"

/datum/unit_test/ms13_crop_farming/Run()
	var/obj/machinery/ms13/agriculture/soil/tray = allocate(/obj/machinery/ms13/agriculture/soil)
	var/obj/item/seeds/ms13/tomato/seed = allocate(/obj/item/seeds/ms13/tomato)
	tray.set_seed(seed, FALSE)
	tray.age = 1
	tray.set_plant_health(seed.plant_datum.base_endurance - 5)
	var/old_health = tray.plant_health
	tray.lastcycle = world.time - tray.cycledelay - 1
	tray.process(1)

	TEST_ASSERT_EQUAL(tray.nitrolevel, tray.maxnutri - tray.nutridrain, "A nitrogen crop did not consume nitrogen.")
	TEST_ASSERT_EQUAL(tray.phoslevel, tray.maxnutri, "A nitrogen crop consumed phosphorus.")
	TEST_ASSERT_EQUAL(tray.potlevel, tray.maxnutri, "A nitrogen crop consumed potassium.")
	TEST_ASSERT(tray.plant_health > old_health, "A watered, fed crop did not recover health.")
	TEST_ASSERT_EQUAL(seed.plant_datum.base_harvest_yield, 2, "The imported MS harvest amount was not converted to yield.")

	var/obj/item/reagent_containers/glass/bucket/ms13/bucket = allocate(/obj/item/reagent_containers/glass/bucket/ms13)
	bucket.reagents.add_reagent(/datum/reagent/water, 20)
	tray.set_waterlevel(0)
	tray.set_toxic(40)
	TEST_ASSERT(tray.receive_reagents(bucket.reagents, 10), "The soil rejected ordinary water.")
	TEST_ASSERT_EQUAL(tray.waterlevel, 10, "One 10-unit pour did not add exactly 10 water to the soil.")
	TEST_ASSERT_EQUAL(bucket.reagents.total_volume, 10, "Water was consumed more than once during one pour.")
	TEST_ASSERT_EQUAL(tray.reagents.total_volume, 0, "Water incorrectly occupied the soil's fertilizer holder.")
	TEST_ASSERT(tray.toxic < 40, "Fresh water did not dilute soil toxicity.")

	var/expected_yield = seed.plant_datum.get_effective_stat(PLANT_STAT_YIELD)
	tray.set_plant_health(seed.plant_datum.base_health)
	tray.set_plant_status(HYDROTRAY_PLANT_HARVESTABLE)
	tray.harvest_plant(null)
	var/found_yield = 0
	for(var/obj/item/food/grown/ms13/tomato/tomato in tray.drop_location())
		found_yield++
	TEST_ASSERT_EQUAL(found_yield, expected_yield, "The MS tray did not produce its configured crop yield.")

/datum/unit_test/ms13_livestock_farming
	name = "MOJAVE SUN: Livestock Products Carry Husbandry State"

/datum/unit_test/ms13_livestock_farming/Run()
	var/mob/living/simple_animal/hostile/retaliate/ms13/brahmin/brahmin = allocate(/mob/living/simple_animal/hostile/retaliate/ms13/brahmin)
	var/datum/component/ms13_livestock/livestock = brahmin.GetComponent(/datum/component/ms13_livestock)
	TEST_ASSERT_NOTNULL(livestock, "Brahmin did not receive the livestock component.")

	livestock.domesticated = TRUE
	livestock.nutrition = 40
	livestock.care = 80
	livestock.stress = 0
	var/obj/item/food/meat/slab/ms13/animal/feed_meat = allocate(/obj/item/food/meat/slab/ms13/animal)
	livestock.apply_to_product(feed_meat)
	livestock.apply_feed(feed_meat)
	livestock.apply_feed(feed_meat)
	livestock.apply_feed(feed_meat)
	TEST_ASSERT_EQUAL(livestock.bse_stage, 1, "Meat feed did not begin latent BSE incubation.")
	TEST_ASSERT(livestock.is_prion_contaminated(), "Latent BSE did not contaminate the livestock animal's meat.")
	livestock.bse_progress = 175
	livestock.process_bse()
	TEST_ASSERT_EQUAL(livestock.bse_stage, 2, "Latent BSE did not progress to visible symptoms.")
	livestock.bse_progress = 415
	livestock.process_bse()
	TEST_ASSERT_EQUAL(livestock.bse_stage, 3, "Symptomatic BSE did not progress to wasting disease.")

	var/obj/item/food/meat/slab/ms13/carcass/large/brahmin/front/carcass = allocate(/obj/item/food/meat/slab/ms13/carcass/large/brahmin/front)
	livestock.apply_to_product(carcass)
	var/datum/component/ms13_livestock_product/product_state = carcass.GetComponent(/datum/component/ms13_livestock_product)
	TEST_ASSERT_NOTNULL(product_state, "A livestock carcass did not receive product state.")
	var/obj/item/food/meat/slab/ms13/animal/meat = allocate(/obj/item/food/meat/slab/ms13/animal)
	product_state.copy_to(meat)
	TEST_ASSERT(meat.quality > initial(meat.quality), "Animal condition did not improve meat quality.")
	TEST_ASSERT(meat.reagents.has_reagent(/datum/reagent/consumable/nutriment/protein/prions), "Contaminated livestock did not produce prion-bearing meat.")

	var/obj/item/reagent_containers/glass/bucket/ms13/bucket = allocate(/obj/item/reagent_containers/glass/bucket/ms13)
	var/mob/living/carbon/human/consistent/rancher = allocate(/mob/living/carbon/human/consistent)
	livestock.milk_units = 20
	TEST_ASSERT(livestock.milk_into(bucket, rancher), "A domesticated brahmin could not be milked into an MS bucket.")
	TEST_ASSERT(bucket.reagents.has_reagent(/datum/reagent/consumable/milk), "Milking did not put milk in the bucket.")
	TEST_ASSERT(!bucket.reagents.has_reagent(/datum/reagent/consumable/nutriment/protein/prions), "The meat-only prion mechanic contaminated milk.")

	var/mob/living/simple_animal/ms13/brahminyoung/calf = allocate(/mob/living/simple_animal/ms13/brahminyoung)
	var/datum/component/ms13_livestock/calf_livestock = calf.GetComponent(/datum/component/ms13_livestock)
	TEST_ASSERT_NOTNULL(calf_livestock, "Brahmin calves did not receive the livestock component.")
	calf_livestock.process_growth(60)
	TEST_ASSERT_EQUAL(calf_livestock.growth_progress, 0, "An underfed calf grew without sustenance.")
	var/obj/item/food/meat/slab/ms13/animal/growth_feed = allocate(/obj/item/food/meat/slab/ms13/animal)
	calf_livestock.apply_feed(growth_feed)
	TEST_ASSERT_EQUAL(calf_livestock.bse_stage, 0, "Unrelated meat incorrectly seeded cattle BSE.")
	calf_livestock.process_growth(60)
	TEST_ASSERT(calf_livestock.growth_progress > 0, "A fed calf did not begin growing.")
