/datum/ai_behavior/find_potential_targets
	action_cooldown = 2 SECONDS
	var/vision_range = 9

/datum/ai_behavior/find_potential_targets/perform(delta_time, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	. = ..()
	var/list/potential_targets
	var/mob/living/living_mob = controller.pawn
	var/datum/targeting_strategy/targeting_strategy = GET_TARGETING_STRATEGY(controller.blackboard[targeting_strategy_key])

	if(!targeting_strategy)
		CRASH("No target datum was supplied in the blackboard for [controller.pawn]")

	potential_targets = hearers(vision_range, controller.pawn) - living_mob //Remove self, so we don't suicide

	potential_targets += visible_hostile_machines(living_mob, vision_range) // MOJAVE EDIT: was a range() scan

	if(!potential_targets.len)
		finish_action(controller, FALSE)
		return

	var/list/filtered_targets = list()

	for(var/atom/pot_target in potential_targets)
		// AI EDIT: vision_range was never passed here, so can_attack() -> can_see() compared distance
		// against a null length (DM coerces null to 0 in numeric comparisons), meaning every basic
		// mob could only ever "see" a target already standing on its own tile - it never actually
		// approached anything, only reacted once already hit/adjacent.
		if(targeting_strategy.can_attack(living_mob, pot_target, vision_range))//Can we attack it?
			filtered_targets += pot_target
			continue

	if(!filtered_targets.len)
		finish_action(controller, FALSE)
		return

	var/atom/target = pick(filtered_targets)
	controller.set_blackboard_key(target_key, target)

	var/atom/potential_hiding_location = targeting_strategy.find_hidden_mobs(living_mob, target)

	if(potential_hiding_location) //If they're hiding inside of something, we need to know so we can go for that instead initially.
		controller.set_blackboard_key(hiding_location_key, potential_hiding_location)

	finish_action(controller, TRUE)
