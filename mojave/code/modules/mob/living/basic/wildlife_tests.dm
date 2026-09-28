#ifdef UNIT_TESTS
/obj/effect/spawner/ms13/wildlife_den/test_fixture
	population = 0
	patrol_radius = 4
	territory_radius = 1
	leash_radius = 6

/obj/effect/spawner/ms13/flora/single/test_fixture
	max_plants = 0
	require_soil = FALSE

/datum/unit_test/ms13_wildlife
	name = "MOJAVE SUN: Den Wildlife Decisions And Recovery"

/datum/unit_test/ms13_wildlife/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/far_corner = locate(origin.x + 4, origin.y + 4, origin.z)
	var/obj/effect/spawner/ms13/wildlife_den/den = allocate(/obj/effect/spawner/ms13/wildlife_den/test_fixture, origin)
	var/mob/living/basic/wolf = den.spawn_animal()
	allocated += wolf
	var/datum/ai_controller/basic_controller/ms13_wildlife/controller = wolf.ai_controller
	if(wolf.ms13_can_sleep || wolf.ms13_can_join_pack() || wolf.ms13_pack)
		Fail("Den wildlife can join the shared-target pack system and receive competing orders.")
	var/mob/living/basic/ordinary = allocate(/mob/living/basic/ms13/hostile_animal/wolf, far_corner)
	if(!ordinary.ms13_can_sleep || !ordinary.ms13_can_join_pack() || istype(ordinary.ai_controller, /datum/ai_controller/basic_controller/ms13_wildlife))
		Fail("Adding den wildlife changed ordinary animals' pack eligibility or controller.")
	qdel(ordinary)
	controller.set_ai_status(AI_STATUS_OFF)
	var/old_delay = wolf.movement_delay
	wolf.movement_delay = -0.5
	if(controller.get_movement_delay() < world.tick_lag)
		Fail("Negative animal slowdown schedules AI movement in the past.")
	wolf.movement_delay = old_delay
	wolf.forceMove(locate(origin.x + 3, origin.y + 3, origin.z))
	wolf.see_in_dark = 8
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, far_corner)
	if(controller.can_hunt(human))
		Fail("Den wildlife attacks an unprovoking human outside its territory.")
	wolf.attack_hand(human, list())
	if(controller.aggressor_ref?.resolve())
		Fail("Petting provokes wildlife.")
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, far_corner)
	shot.firer = human
	shot.damage = 5
	wolf.bullet_act(shot)
	if(controller.aggressor_ref?.resolve() != human || !controller.can_hunt(human))
		Fail("Actual bullet damage did not cause retaliation.")
	controller.aggressor_until = 0
	human.forceMove(get_step(origin, EAST))
	if(!controller.can_hunt(human))
		Fail("Wildlife does not defend its den territory.")
	human.forceMove(far_corner)
	den.noise_flee_chance = 100
	controller.noise_cooldown = 0
	playsound(human, 'mojave/sound/ms13weapons/10mm_fire_03.ogg', 50, FALSE)
	if(controller.frightened_until <= world.time)
		Fail("The real playsound path failed to startle wildlife away from its den.")
	controller.frightened_until = 0
	controller.noise_cooldown = 0
	den.noise_flee_chance = 0
	if(controller.hear_noise(far_corner, 20))
		Fail("A zero-fear hellpig-style profile fled from a sound.")
	den.noise_flee_chance = 100
	wolf.forceMove(origin)
	controller.noise_cooldown = 0
	if(controller.hear_noise(far_corner, 20))
		Fail("Wildlife fled a sound while defending its den.")
	wolf.health = wolf.maxHealth * 0.2
	wolf.ms13_hurt_at = world.time - 10 SECONDS
	var/before_health = wolf.health
	controller.next_decision = 0
	controller.ProcessBehaviorSelection(1)
	if(!controller.retreating || wolf.health <= before_health)
		Fail("An injured animal did not recover at home.")
	wolf.health = wolf.maxHealth
	controller.retreating = FALSE
	controller.start_job("patrol", far_corner)
	controller.progress_deadline = world.time - 1
	controller.next_decision = 0
	controller.ProcessBehaviorSelection(1)
	if(!controller.ignored(far_corner) || controller.job_target?.resolve() == far_corner)
		Fail("A stalled route was immediately selected again.")
	controller.clear_job()
	var/mob/living/basic/food = allocate(/mob/living/basic/ms13/hostile_animal/molerat, get_step(origin, NORTH))
	food.ai_controller?.set_ai_status(AI_STATUS_OFF)
	food.death()
	controller.begin_haul(food)
	controller.arrive()
	if(controller.job != "haul" || !wolf.is_grabbing(food))
		Fail("A real corpse grab did not transition into hauling.")
	controller.clear_job(TRUE)
	if(length(food.grabbed_by) || food.ms13_wildlife_claim?.resolve())
		Fail("A failed haul retained its corpse claim or grab.")
	controller.begin_haul(food)
	controller.arrive()
	controller.arrive()
	controller.eating_since = world.time - 6 SECONDS
	controller.arrive()
	if(!QDELETED(food) || controller.hungry_at <= world.time)
		Fail("Wildlife did not consume its delivered prey and become satiated.")
	var/mob/living/basic/other = allocate(/mob/living/basic/ms13/hostile_animal/molerat, get_step(origin, NORTH))
	other.ai_controller?.set_ai_status(AI_STATUS_OFF)
	other.death()
	controller.begin_haul(other)
	controller.arrive()
	wolf.death()
	if(other.ms13_wildlife_claim?.resolve() || length(other.grabbed_by) || (controller in GLOB.ms13_wildlife))
		Fail("Death left an animal holding food or registered as a sound listener.")
	den.population = 1
	var/count_before = length(den.members)
	den.process()
	if(length(den.members) != count_before)
		Fail("A den immediately replaced a dead animal instead of respecting its respawn delay.")
	den.next_spawn = 0
	den.process()
	for(var/mob/living/member as anything in den.members)
		allocated |= member
	if(length(den.members) != count_before + 1)
		Fail("An eligible den failed to replenish its population.")
	den.next_spawn = 0
	den.process()
	if(length(den.members) != count_before + 1)
		Fail("A den exceeded its living population limit.")
	qdel(den)
	for(var/mob/living/member as anything in allocated)
		var/datum/ai_controller/basic_controller/ms13_wildlife/orphan = member.ai_controller
		if(istype(orphan) && member.stat != DEAD)
			orphan.next_decision = 0
			orphan.ProcessBehaviorSelection(1)
			if(orphan.can_hunt(human) || orphan.den_ref?.resolve())
				Fail("Removing a den made its survivors hostile to uninvolved humans.")

/datum/unit_test/ms13_wildlife_route
	name = "MOJAVE SUN: Wildlife Live Haul Around An Obstacle"

/datum/unit_test/ms13_wildlife_route/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/obj/effect/spawner/ms13/wildlife_den/den = allocate(/obj/effect/spawner/ms13/wildlife_den/test_fixture, origin)
	var/mob/living/basic/wolf = den.spawn_animal()
	allocated += wolf
	var/datum/ai_controller/basic_controller/ms13_wildlife/controller = wolf.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	wolf.forceMove(locate(origin.x + 4, origin.y, origin.z))
	var/mob/living/basic/prey = allocate(/mob/living/basic/ms13/hostile_animal/molerat, locate(origin.x + 4, origin.y + 1, origin.z))
	prey.ai_controller?.set_ai_status(AI_STATUS_OFF)
	prey.adjustBruteLoss(prey.maxHealth - 1)
	var/obj/structure/closet/crate/barrier = allocate(/obj/structure/closet/crate, locate(origin.x + 2, origin.y, origin.z))
	barrier.resistance_flags |= INDESTRUCTIBLE
	var/before_integrity = barrier.get_integrity()
	controller.hungry_at = 0
	controller.start_job("hunt", prey)
	var/list/trace = list()
	for(var/tick in 1 to 22)
		controller.next_decision = 0
		controller.ProcessBehaviorSelection(1)
		controller.process(1)
		sleep(1 SECONDS)
		trace += "[tick]: [controller.job] wolf=[COORD(wolf)] food=[COORD(prey)] grab=[!!wolf.is_grabbing(prey)] moving=[controller.current_movement_target] health=[wolf.health] failures=[controller.consecutive_pathing_attempts]"
		if(QDELETED(prey))
			break
	if(!QDELETED(prey) || get_dist(wolf, den) > 2)
		Fail("Live hunting and hauling did not deliver prey around the obstacle: [jointext(trace, "; ")]")
	if(barrier.get_integrity() != before_integrity)
		Fail("Wildlife attacked a barrier instead of pathing around it.")

/datum/unit_test/ms13_wildlife_presets
	name = "MOJAVE SUN: Drought And Mammoth Predator Prey Dens"

/datum/unit_test/ms13_wildlife_presets/Run()
	var/list/presets = list(
		/obj/effect/spawner/ms13/wildlife_den/drought/predator/wolves,
		/obj/effect/spawner/ms13/wildlife_den/drought/predator/hellpig,
		/obj/effect/spawner/ms13/wildlife_den/drought/predator/golden_geckos,
		/obj/effect/spawner/ms13/wildlife_den/drought/prey/molerats,
		/obj/effect/spawner/ms13/wildlife_den/drought/prey/pigrats,
		/obj/effect/spawner/ms13/wildlife_den/drought/prey/radroaches,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/predator/wolves,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/predator/yaoguai,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/predator/ice_geckos,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/prey/boars,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/prey/molerats,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/prey/pigrats,
	)
	for(var/preset in presets)
		var/obj/effect/spawner/ms13/wildlife_den/den = allocate(preset, run_loc_floor_bottom_left)
		if(length(den.members) != den.population || den.population < 1)
			Fail("[preset] did not spawn its configured population.")
		for(var/mob/living/animal as anything in den.members.Copy())
			var/datum/ai_controller/basic_controller/ms13_wildlife/controller = animal.ai_controller
			if(!istype(controller) || controller.den_ref?.resolve() != den || animal.ms13_can_join_pack())
				Fail("[preset] did not attach independent den AI.")
			if(get_dist(animal, den) > 1 && !length(SSpathfinder.jps_pathfind_now(animal, den, max_steps = 6, mintargetdist = 1)))
				Fail("[preset] spawned an animal across an inaccessible wall.")
			qdel(animal)
		qdel(den)

/datum/unit_test/ms13_flora_ecology
	name = "MOJAVE SUN: Flora Placement Regrowth And Grazing"

/datum/unit_test/ms13_flora_ecology/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/obj/effect/spawner/ms13/flora/spawner = allocate(/obj/effect/spawner/ms13/flora/single/test_fixture, origin)
	spawner.max_plants = 1
	spawner.next_check = 0
	spawner.process()
	var/obj/structure/flora/ms13/forage/plant = locate() in origin
	if(!plant || length(spawner.plant_slots) != 1)
		Fail("A precise flora spawner did not plant its exact tile.")
		return
	allocated += plant
	var/items_before = length(origin.contents)
	if(!plant.ms13_graze() || !plant.harvested || length(origin.contents) != items_before)
		Fail("Grazing did not use forage regrowth without creating dropped harvest items.")
	if(plant.ms13_can_graze())
		Fail("An already grazed plant was immediately edible again.")
	plant.ms13_grazed_until = 0
	plant.regrow()
	if(!plant.ms13_can_graze())
		Fail("Regrown forage did not become edible again.")
	qdel(plant)
	spawner.next_check = 0
	spawner.process()
	if(locate(/obj/structure/flora) in origin)
		Fail("A destroyed plant regrew without waiting.")
	spawner.regrow_at[origin] = 0
	var/obj/structure/closet/crate/construction = allocate(/obj/structure/closet/crate, origin)
	spawner.next_check = 0
	spawner.process()
	if(locate(/obj/structure/flora) in origin)
		Fail("Flora regrew inside new construction.")
	qdel(construction)
	spawner.next_check = 0
	spawner.process()
	plant = locate() in origin
	if(!plant)
		Fail("A cleared planting slot never recovered after its obstruction was removed.")
	else
		allocated += plant
	spawner.require_soil = TRUE
	if(spawner.valid_tile(get_step(origin, EAST)))
		Fail("An ordinary indoor floor was accepted as natural soil.")
	var/turf/road_site = get_step(origin, EAST)
	var/old_type = road_site.type
	road_site = road_site.ChangeTurf(/turf/open/floor/plating/ms13/ground/road)
	if(ms13_flora_soil(road_site))
		Fail("Roads were accepted as flora soil.")
	road_site.ChangeTurf(old_type)
	var/obj/structure/flora/ms13/tree/tallpine/tree = allocate(/obj/structure/flora/ms13/tree/tallpine, get_step(origin, NORTH))
	if(!tree.ms13_graze() || QDELETED(tree) || tree.ms13_can_graze())
		Fail("Browsing a tree should consume foliage once without deleting the tree.")
	var/area/ms13/region = new
	allocated += region
	var/turf/area_tile = locate(origin.x + 4, origin.y + 4, origin.z)
	var/area/old_area = get_area(area_tile)
	area_tile.change_area(old_area, region)
	region.flora_spawner_type = /obj/effect/spawner/ms13/flora/single/test_fixture
	region.flora_population = 2
	region.LateInitialize()
	var/obj/effect/spawner/ms13/flora/area_spawner = region.ecology_spawner
	if(!area_spawner || !area_spawner.area_mode || area_spawner.max_plants != 2 || !(area_tile in area_spawner.candidates) || (origin in area_spawner.candidates))
		Fail("Area flora did not respect the containing area or its mapped population.")
	for(var/obj/structure/flora/area_plant in area_tile)
		allocated += area_plant
	area_tile.change_area(region, old_area)
	qdel(region)
	if(!QDELETED(area_spawner))
		Fail("Deleting an area retained its flora controller.")
#endif
