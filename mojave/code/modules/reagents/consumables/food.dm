/datum/reagent/consumable/nutriment/protein/prions
	name = "Prions"
	description = "Malformed proteins. Eating this won't do you any good."
	color = "#ff93e2"
	brute_heal = 0

/datum/reagent/consumable/nutriment/protein/prions/on_mob_metabolize(mob/living/carbon/M, class)
	if(class != CHEM_BLOOD)
		return
	. = ..()
	addtimer(CALLBACK(src, .proc/mrelectrickillthisguy, M), rand(5,10) MINUTES)

/datum/reagent/consumable/nutriment/protein/prions/proc/mrelectrickillthisguy(mob/living/carbon/M) // Delay the kuru... it's funnier this way prolly
	// ForceContractDisease doesn't exist in DD - infection goes through the pathogen instance itself
	new /datum/pathogen/kuru().force_infect(M)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_food_recovery
	name = "FOOD: Eating And Digesting Clears Hunger"

/datum/unit_test/ms13_food_recovery/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/stomach/belly = user.getorganslot(ORGAN_SLOT_STOMACH)
	user.set_nutrition(100)
	belly.handle_hunger(user, 0, 1)
	if(!(user.has_movespeed_modifier(/datum/movespeed_modifier/hunger)))
		Fail("Starving test subject did not have hunger slowdown.")
	var/obj/item/food/ms13/prewar/canned/porknbeans/meal = allocate(/obj/item/food/ms13/prewar/canned/porknbeans, user)
	meal.open_can(user)
	var/datum/component/edible/edible = meal.GetComponent(/datum/component/edible)
	edible.eat_time = 0
	for(var/bite in 1 to 5)
		meal.melee_attack_chain(user, user)
	if(!(belly.reagents.total_volume > 20))
		Fail("Eating the meal failed to transfer its food to the stomach.")
	var/fullness = user.get_fullness()
	if(!(fullness > NUTRITION_LEVEL_FED))
		Fail("The meal had insufficient expected nutrition.")
	var/food_volume = belly.reagents.total_volume
	belly.organ_flags |= ORGAN_DEAD
	user.handle_chemicals()
	if((belly.reagents.total_volume) != (food_volume))
		Fail("A dead stomach still digested food.")
	belly.organ_flags &= ~ORGAN_DEAD
	for(var/tick in 1 to 160)
		user.handle_chemicals()
		belly.handle_hunger(user, 0, tick)
		if(!belly.reagents.total_volume)
			break
	if((belly.reagents.total_volume) != (0))
		Fail("Digestion did not resume after restoring the stomach.")
	if(!(user.nutrition > NUTRITION_LEVEL_HUNGRY))
		Fail("Eating a whole meal left nutrition at [user.nutrition].")
	if(!(user.nutrition <= fullness))
		Fail("Digestion produced more nutrition than the food contained.")
	if(!(!user.has_movespeed_modifier(/datum/movespeed_modifier/hunger)))
		Fail("Hunger slowdown persisted after eating.")
	if(!(!user.alerts[ALERT_NUTRITION]))
		Fail("Hunger alert persisted after eating.")
#endif
