#ifdef UNIT_TESTS
/obj/effect/spawner/ms13/wildlife_den/test_fixture
	population = 0
	patrol_radius = 4
	territory_radius = 1
	leash_radius = 6

/obj/effect/spawner/ms13/wildlife_den/custom/test_robot
	animal_type = /mob/living/basic/ms13/robot/handy/gun
	population = 0

/obj/effect/spawner/ms13/wildlife_den/custom/test_omnivore
	animal_type = /mob/living/basic/ms13/hostile_animal/hellpig
	population = 0

/obj/effect/spawner/ms13/wildlife_den/test_scorpion
	parent_type = /obj/effect/spawner/ms13/wildlife_den/drought/prey/molerats
	animal_type = /mob/living/basic/ms13/hostile_animal/radscorpion
	population = 0

/datum/unit_test/ms13_wildlife_opportunities
	name = "MOJAVE SUN: Custom Den Traits And Food Opportunities"

/datum/unit_test/ms13_wildlife_opportunities/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/effect/spawner/ms13/wildlife_den/custom/den = allocate(/obj/effect/spawner/ms13/wildlife_den/custom/test_omnivore, origin)
	var/mob/living/basic/animal = den.spawn_animal()
	allocated += animal
	if(!animal.wildlife_eats_meat || !animal.wildlife_eats_plants || animal.wildlife_noise_flee_chance || animal.wildlife_size != 6)
		Fail("A custom den changed its hellpig species traits.")
	animal.forceMove(origin)
	animal.see_in_dark = 8
	var/datum/ai_controller/basic_controller/ms13_wildlife/controller = animal.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	controller.hungry_at = world.time
	// This species was never in the old hellpig prey whitelist.
	var/mob/living/basic/prey = allocate(/mob/living/basic/ms13/hostile_animal/giantant, locate(origin.x + 3, origin.y, origin.z))
	prey.ai_controller?.set_ai_status(AI_STATUS_OFF)
	if(!controller.is_prey(prey))
		Fail("Shared size and diet traits still require a per-species prey whitelist.")
	var/obj/effect/spawner/ms13/wildlife_den/prey_den = allocate(/obj/effect/spawner/ms13/wildlife_den/test_fixture, get_turf(prey))
	prey_den.animal_type = prey.type
	var/datum/ai_controller/basic_controller/ms13_wildlife/prey_controller = new(prey, prey_den)
	prey_controller.set_ai_status(AI_STATUS_OFF)
	// Changing the home point's selected species must not reclassify its existing residents.
	prey_den.animal_type = /mob/living/basic/ms13/robot/handy
	if(!controller.is_prey(prey))
		Fail("The den's species setting overrode the animal's actual species.")
	var/obj/structure/flora/ms13/forage/plant = allocate(/obj/structure/flora/ms13/forage, get_step(origin, NORTH))
	controller.next_decision = 0
	controller.ProcessBehaviorSelection(1)
	if(controller.job != "graze" || controller.job_target?.resolve() != plant)
		Fail("An omnivore always hunts before considering a safer, closer plant.")
	prey.death()
	prey.forceMove(get_step(origin, EAST))
	controller.next_decision = 0
	controller.ProcessBehaviorSelection(1)
	if(controller.job != "fetch" || controller.food_ref?.resolve() != prey)
		Fail("A newly available easy meal could not interrupt lower-value grazing.")
	controller.clear_job()
	qdel(animal)
	qdel(den)
	qdel(prey)
	qdel(plant)
	den = allocate(/obj/effect/spawner/ms13/wildlife_den/custom/test_robot, origin)
	animal = den.spawn_animal()
	allocated += animal
	if(animal.wildlife_eats_meat || animal.wildlife_eats_plants || animal.wildlife_noise_flee_chance || !animal.wildlife_hostile_to_people || !animal.wildlife_ranged)
		Fail("A custom robot den inherited animal food/fear traits or lost its gun.")
	controller = animal.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, locate(origin.x + 3, origin.y, origin.z))
	controller.start_job("hunt", target)
	if(!(locate(/datum/ai_behavior/basic_ranged_attack/ms13_wildlife) in controller.current_behaviors))
		Fail("A den Gutsy queued a melee-only hunt.")
	controller.aggressor_ref = null
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, get_turf(target))
	shot.firer = target
	shot.damage = 50
	animal.bullet_act(shot)
	if(controller.aggressor_ref?.resolve() != target)
		Fail("Non-animal den members do not react to actual damage.")
	var/mob/living/basic/ms13/hostile_animal/radscorpion/scorpion = allocate(/mob/living/basic/ms13/hostile_animal/radscorpion, get_step(target, NORTH))
	scorpion.ai_controller?.set_ai_status(AI_STATUS_OFF)
	scorpion.melee_attack(target)
	if(target.reagents.get_reagent_amount(/datum/reagent/toxin) <= 0)
		Fail("The basic-mob scorpion lost its successful-hit venom.")

/obj/effect/spawner/ms13/flora/single/test_fixture
	max_plants = 0
	require_soil = FALSE

/datum/unit_test/ms13_wildlife_species
	name = "MOJAVE SUN: Species Risk, Numbers And Cornered Defence"

/datum/unit_test/ms13_wildlife_species/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	// Even an old 'prey' preset must create a normal scorpion when its species is changed.
	var/obj/effect/spawner/ms13/wildlife_den/den = allocate(/obj/effect/spawner/ms13/wildlife_den/test_scorpion, origin)
	var/mob/living/basic/scorpion = den.spawn_animal()
	allocated += scorpion
	scorpion.forceMove(origin)
	scorpion.see_in_dark = 8
	var/datum/ai_controller/basic_controller/ms13_wildlife/controller = scorpion.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	controller.hungry_at = 0
	var/mob/living/basic/roach = allocate(/mob/living/basic/ms13/hostile_animal/radroach, get_step(origin, EAST))
	roach.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/mob/living/basic/hellpig = allocate(/mob/living/basic/ms13/hostile_animal/hellpig, get_step(origin, NORTH))
	hellpig.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/mob/living/simple_animal/hostile/ms13/robot/sentrybot/robot = allocate(/mob/living/simple_animal/hostile/ms13/robot/sentrybot, get_step(origin, WEST))
	robot.toggle_ai(AI_OFF)
	robot.mob_biotypes |= MOB_ORGANIC | MOB_BEAST
	if(!controller.is_prey(roach) || controller.is_prey(hellpig) || controller.is_prey(robot))
		Fail("Scorpion food selection ignored the species: roaches are food, healthy hellpigs and robots are not.")
	hellpig.health = 1
	if(controller.is_prey(hellpig))
		Fail("An injured hellpig looked harmless to a lone scorpion.")
	// Diet never prevents retaliation. An attacker can also cease being an unreachable target.
	controller.ignored_targets[REF(roach)] = world.time + 30 SECONDS
	controller.frightened_until = world.time + 12 SECONDS
	roach.melee_attack(scorpion)
	controller.ProcessBehaviorSelection(1)
	if(controller.job != "hunt" || controller.job_target?.resolve() != roach || controller.ignored(roach))
		Fail("Fresh damage failed to interrupt fear and stale target avoidance.")
	controller.clear_job()
	qdel(robot)
	qdel(hellpig)
	qdel(roach)
	qdel(scorpion)
	den.animal_type = /mob/living/basic/ms13/hostile_animal/radroach
	roach = den.spawn_animal()
	allocated += roach
	roach.forceMove(origin)
	roach.see_in_dark = 8
	controller = roach.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/basic/mantis = allocate(/mob/living/basic/ms13/hostile_animal/mantis, get_step(origin, EAST))
	mantis.ai_controller?.set_ai_status(AI_STATUS_OFF)
	if(controller.is_prey(mantis))
		Fail("A lone radroach willingly hunted a stronger animal.")
	var/list/allies = list()
	for(var/i in 1 to 11)
		var/mob/living/basic/ally = den.spawn_animal()
		allocated += ally
		allies += ally
		ally.forceMove(get_step(origin, NORTH))
		ally.see_in_dark = 8
		ally.ai_controller.set_ai_status(AI_STATUS_OFF)
	if(!controller.is_prey(mantis))
		Fail("Overwhelming local radroach numbers could not change a risky hunting decision.")
	for(var/mob/living/basic/ally as anything in allies)
		ally.stat = UNCONSCIOUS
	if(controller.is_prey(mantis))
		Fail("Incapacitated allies were counted as combat support.")
	for(var/mob/living/basic/ally as anything in allies)
		qdel(ally)
	// The escape must actually move, not finish immediately because its adjacent goal is 'close enough'.
	controller.provoke(mantis)
	controller.next_decision = 0
	controller.ProcessBehaviorSelection(1)
	if(controller.job != "escape")
		Fail("An outmatched radroach did not try to escape its attacker.")
	for(var/tick in 1 to 3)
		controller.process(1)
		sleep(1 SECONDS)
		if(get_turf(roach) != origin)
			break
	if(get_turf(roach) == origin || get_dist(roach, mantis) <= 1)
		Fail("The live escape finished without moving away from the attacker.")
	controller.clear_job()
	roach.forceMove(origin)
	for(var/direction in GLOB.alldirs)
		var/turf/tile = get_step(origin, direction)
		if(tile != get_turf(mantis))
			allocate(/obj/structure/closet/crate, tile)
	roach.health = roach.maxHealth * 0.2
	controller.next_decision = 0
	controller.ProcessBehaviorSelection(1)
	if(controller.job != "hunt" || controller.job_target?.resolve() != mantis)
		Fail("An injured, cornered animal sat healing at its den instead of defending itself.")
	var/before_health = mantis.health
	roach.melee_attack(mantis)
	if(mantis.health >= before_health)
		Fail("A cornered animal could not actually damage its attacker.")

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
	wolf.wildlife_noise_flee_chance = 100
	controller.noise_cooldown = 0
	playsound(human, 'mojave/sound/ms13weapons/10mm_fire_03.ogg', 50, FALSE)
	if(controller.frightened_until <= world.time)
		Fail("The real playsound path failed to startle wildlife away from its den.")
	controller.frightened_until = 0
	controller.noise_cooldown = 0
	wolf.wildlife_noise_flee_chance = 0
	if(controller.hear_noise(far_corner, 20))
		Fail("A zero-fear hellpig-style profile fled from a sound.")
	wolf.wildlife_noise_flee_chance = 100
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
	name = "MOJAVE SUN: Drought And Mammoth Species Dens"

/datum/unit_test/ms13_wildlife_presets/Run()
	var/list/presets = list(
		/obj/effect/spawner/ms13/wildlife_den/ants,
		/obj/effect/spawner/ms13/wildlife_den/scorpions,
		/obj/effect/spawner/ms13/wildlife_den/scorpions/bark,
		/obj/effect/spawner/ms13/wildlife_den/mantises,
		/obj/effect/spawner/ms13/wildlife_den/mirelurks,
		/obj/effect/spawner/ms13/wildlife_den/ghouls,
		/obj/effect/spawner/ms13/wildlife_den/ghouls/frozen,
		/obj/effect/spawner/ms13/wildlife_den/ghouls/glowing,
		/obj/effect/spawner/ms13/wildlife_den/robots,
		/obj/effect/spawner/ms13/wildlife_den/robots/saw,
		/obj/effect/spawner/ms13/wildlife_den/robots/gutsy,
		/obj/effect/spawner/ms13/wildlife_den/drought/random,
		/obj/effect/spawner/ms13/wildlife_den/mammoth/random,
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
		if(length(den.animal_pool) && !(den.animal_type in den.animal_pool))
			Fail("A random regional den selected a species outside its mapper pool.")
		for(var/mob/living/animal as anything in den.members.Copy())
			var/datum/ai_controller/basic_controller/ms13_wildlife/controller = animal.ai_controller
			if(!istype(controller) || controller.den_ref?.resolve() != den || animal.ms13_can_join_pack())
				Fail("[preset] did not attach independent den AI.")
			if(animal.type != den.animal_type)
				Fail("A random den selected a different species for each member.")
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
