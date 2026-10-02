/datum/unit_test/ms13_raider_ranged/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/raider_type in typesof(/mob/living/basic/ms13/raider))
		if(raider_type == /mob/living/basic/ms13/raider/sulphite)
			continue
		var/mob/living/basic/ms13/raider/raider = allocate(raider_type, origin)
		var/datum/ai_controller/brain = raider.ai_controller
		brain.set_ai_status(AI_STATUS_OFF)
		var/mob/living/basic/target = allocate(/mob/living/basic, get_ranged_target_turf(origin, EAST, 4))
		target.maxHealth = 5000
		target.health = target.maxHealth
		var/deadline = world.time + 10 SECONDS
		// Exercise acquisition, planning and actual projectiles, without pre-seeding a target.
		while(world.time < deadline && target.health == target.maxHealth)
			if(brain.able_to_plan())
				brain.ProcessBehaviorSelection(0.2)
			brain.process(0.2)
			sleep(0.2 SECONDS)
		if(target.health == target.maxHealth || get_dist(raider, target) <= 1)
			return Fail("[raider_type] failed to acquire and damage an enemy from range.")
		if(!(locate(/obj/item/ammo_casing/ms13/c10mm) in get_turf(raider)))
			return Fail("[raider_type] dealt damage without firing its configured ammunition.")
		var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(brain.blackboard[BB_TARGETING_STRATEGY])
		target.faction = list("raider")
		if(strategy.can_attack(raider, target, 9))
			return Fail("[raider_type] treats its own faction as enemies.")
		qdel(target)
		// Losing a target must release the old plan and permit a fresh attack.
		target = allocate(/mob/living/basic, get_ranged_target_turf(origin, EAST, 4))
		target.maxHealth = 5000
		target.health = target.maxHealth
		deadline = world.time + 10 SECONDS
		while(world.time < deadline && target.health == target.maxHealth)
			if(brain.able_to_plan())
				brain.ProcessBehaviorSelection(0.2)
			brain.process(0.2)
			sleep(0.2 SECONDS)
		if(target.health == target.maxHealth || brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET] != target)
			return Fail("[raider_type] failed to resume ranged combat after losing its target.")
		qdel(raider)
		qdel(target)

/datum/unit_test/ms13_raider_brawler/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/basic/ms13/raider/sulphite/raider = allocate(/mob/living/basic/ms13/raider/sulphite, origin)
	var/datum/ai_controller/brain = raider.ai_controller
	brain.set_ai_status(AI_STATUS_OFF)
	var/mob/living/basic/target = allocate(/mob/living/basic, get_ranged_target_turf(origin, EAST, 4))
	target.maxHealth = 5000
	target.health = target.maxHealth
	raider.RangedAttack(target)
	sleep(1 SECONDS)
	if(target.health != target.maxHealth || (locate(/obj/item/ammo_casing) in origin))
		return Fail("The melee brawler inherited a gun attack.")
	var/deadline = world.time + 15 SECONDS
	while(world.time < deadline && target.health == target.maxHealth)
		if(brain.able_to_plan())
			brain.ProcessBehaviorSelection(0.2)
		brain.process(0.2)
		sleep(0.2 SECONDS)
	if(target.health == target.maxHealth || get_dist(raider, target) > 1)
		return Fail("The brawler failed to approach and strike its target in melee.")
