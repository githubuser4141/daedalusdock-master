/**
 * S.P.E.C.I.A.L.: seven plain attributes, 1 to 10, for what a body and mind do outright. Strength hits, grapples
 * and carries harder, Perception sees further round, Endurance takes more punishment and keeps going, Agility moves
 * and works quicker, Intelligence builds faster. They're steady numbers, not rolls.
 *
 * The character sheet (code/modules/three_dsix) is the other half: its stats and skills are rolled on 3d6 for the
 * finer, chancier things. Each of its three stats leans on SPECIAL (/datum/rpg_stat/var/special_attributes), and Luck
 * bends every roll's odds of a critical.
 *
 * Every attribute starts at SPECIAL_BASELINE. Points are spent on them at character setup (special_preferences.dm);
 * species and other sources add modifiers on top. Nothing comes from jobs.
 */
/mob/living
	/// This character's own SPECIAL. Set it to a /datum/ms13_stats subtype in code to start them off different.
	/// Null reads as baseline.
	var/datum/ms13_stats/ms13_stats

/mob/living/Destroy()
	if(istype(ms13_stats))
		qdel(ms13_stats)
	ms13_stats = null
	return ..()

/datum/ms13_stats
	var/mob/living/owner
	// Each attribute before modifiers, named as its SPECIAL_* define. Character setup overwrites these for players.
	var/strength = SPECIAL_BASELINE
	var/perception = SPECIAL_BASELINE
	var/endurance = SPECIAL_BASELINE
	var/charisma = SPECIAL_BASELINE
	var/intelligence = SPECIAL_BASELINE
	var/agility = SPECIAL_BASELINE
	var/luck = SPECIAL_BASELINE
	/// Modifiers by source: source = list(attribute = amount).
	var/list/modifiers = list()
	var/list/perks = list()

/datum/ms13_stats/New(owner)
	src.owner = owner

/datum/ms13_stats/Destroy(force, ...)
	owner = null
	QDEL_LIST(perks)
	return ..()

/// The SPECIAL datum, made on first use from the type ms13_stats was set to, or from scratch if create is set.
/mob/living/proc/get_ms13_stats(create)
	if(ispath(ms13_stats) || (create && !ms13_stats))
		var/stats_type = ms13_stats || /datum/ms13_stats
		ms13_stats = new stats_type(src)
	return ms13_stats

/// The attribute as it stands: base, every modifier and the species', within SPECIAL_MINIMUM and SPECIAL_MAXIMUM.
/mob/living/proc/get_special(attribute)
	. = SPECIAL_BASELINE
	var/datum/ms13_stats/special = get_ms13_stats()
	if(special)
		. = special.vars[attribute]
		for(var/source in special.modifiers)
			. += special.modifiers[source][attribute]
	. += get_species_special(attribute)
	return clamp(., SPECIAL_MINIMUM, SPECIAL_MAXIMUM)

/mob/living/proc/get_species_special(attribute)
	return 0

/mob/living/carbon/human/get_species_special(attribute)
	return LAZYACCESS(dna?.species?.special_modifiers, attribute)

/// How far this attribute is off baseline, as a whole number of points.
/mob/living/proc/get_special_offset(attribute)
	return get_special(attribute) - SPECIAL_BASELINE

/mob/living/proc/set_special_base(attribute, value)
	var/datum/ms13_stats/special = get_ms13_stats(TRUE)
	special.vars[attribute] = clamp(value, SPECIAL_MINIMUM, SPECIAL_MAXIMUM)
	special_changed()

/// Adds amounts (attribute = amount) to the attributes from source, replacing what it added before. Null takes it off.
/mob/living/proc/set_special_modifier(source, list/amounts)
	var/datum/ms13_stats/special = get_ms13_stats(TRUE)
	if(amounts)
		special.modifiers[source] = amounts
	else
		special.modifiers -= source
	special_changed()

/// Brings everything the attributes steer in line with them.
/mob/living/proc/special_changed()
	update_fov()
	var/stamina_change = get_special_offset(SPECIAL_ENDURANCE) * SPECIAL_ENDURANCE_STAMINA
	if(stamina_change)
		stamina?.add_max_modifier("S.P.E.C.I.A.L.", stamina_change)
	else
		stamina?.remove_max_modifier("S.P.E.C.I.A.L.")
	var/action_change = -get_special_offset(SPECIAL_AGILITY) * SPECIAL_AGILITY_ACTION_SPEED
	if(action_change)
		add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/special_agility, slowdown = action_change)
	else
		remove_actionspeed_modifier(/datum/actionspeed_modifier/special_agility)
	var/move_change = -get_body_special_offset(SPECIAL_AGILITY) * SPECIAL_AGILITY_MOVE_SPEED
	if(move_change)
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/special_agility, slowdown = move_change)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/special_agility)
	update_equipment_speed_mods()

/mob/living/carbon/special_changed()
	..()
	for(var/obj/item/bodypart/limb in bodyparts)
		limb.update_toughness()
		if(limb.bodypart_flags & BP_IS_GRABBY_LIMB)
			limb.refresh_muscle_effects() // Unarmed damage.
	for(var/obj/item/organ/organ as anything in organs)
		organ.update_strength_density()

/// The attribute as the body puts it to work.
/mob/living/proc/get_body_special_offset(attribute)
	return get_special_offset(attribute)

/// Power armor is a vehicle: its frame's strength stands in for its wearer's, and their Agility doesn't reach through it.
/mob/living/carbon/human/get_body_special_offset(attribute)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = wear_suit
	if(!HAS_TRAIT(src, TRAIT_IN_POWERARMOUR) || !istype(frame))
		return ..()
	return attribute == SPECIAL_STRENGTH ? frame.strength - SPECIAL_BASELINE : 0

/// How fast the body runs: a big, strong one burns through food faster, and drugs hit it harder.
/mob/living/proc/get_metabolism_mult()
	return 1 + get_special_offset(SPECIAL_STRENGTH) * SPECIAL_STRENGTH_METABOLISM

/// How much a unit of this does in C, and how close to an overdose it counts. Food, drink and blood feed everyone alike.
/datum/reagent/proc/get_dose_mult(mob/living/carbon/C)
	if(istype(C) && (istype(src, /datum/reagent/ms13) || istype(src, /datum/reagent/medicine) || istype(src, /datum/reagent/drug)))
		return C.get_metabolism_mult()
	return 1

/// How heavily what you carry and drag weighs on you: under 1 for the strong.
/mob/living/proc/get_load_mult()
	return max(1 - get_body_special_offset(SPECIAL_STRENGTH) * SPECIAL_STRENGTH_LOAD, 0)

/// How far this mob's Strength outweighs other's, in steps of SPECIAL_STRENGTH_CONTEST_STEP. Negative if it's weaker.
/mob/living/proc/strength_edge(mob/living/other)
	return round((get_body_special_offset(SPECIAL_STRENGTH) - other.get_body_special_offset(SPECIAL_STRENGTH)) / SPECIAL_STRENGTH_CONTEST_STEP, 1)

/// A grab is strength against strength as well as size against size, whether holding on or breaking free.
/datum/grab/size_difference(mob/living/A, mob/living/B)
	return ..() + A.strength_edge(B)

/mob/living/update_pull_movespeed()
	..()
	var/datum/movespeed_modifier/dragging = has_movespeed_modifier(/datum/movespeed_modifier/grabbing)
	if(dragging?.slowdown > 0)
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/grabbing, slowdown = dragging.slowdown * get_load_mult())

/mob/living/Initialize(mapload)
	. = ..()
	special_changed()

/datum/actionspeed_modifier/special_agility
	variable = TRUE

/datum/movespeed_modifier/special_agility
	variable = TRUE
	blacklisted_movetypes = FLOATING

/// Strong backs carry everything lighter.
/mob/living/carbon/human/equipped_speed_mods()
	. = ..()
	var/lightened = 1 - get_load_mult()
	if(!lightened)
		return
	for(var/obj/item/worn in get_equipped_items(FALSE))
		if(!istype(worn, /obj/item/clothing/suit/space/hardsuit/ms13/power_armor)) // A power armor frame carries itself.
			. -= max(worn.slowdown, 0) * lightened
	for(var/obj/item/held in held_items)
		if(held.item_flags & SLOWS_WHILE_IN_HAND)
			. -= max(held.slowdown, 0) * lightened

/// How well the body rides out losing blood, from Endurance: fainting, brain damage and clotting. Barely off 1 near
/// average, strongly so at either end.
/mob/living/proc/get_endurance_resilience()
	var/offset = get_special_offset(SPECIAL_ENDURANCE) / SPECIAL_BASELINE
	return 1 + SPECIAL_ENDURANCE_RESILIENCE * offset * abs(offset)

/// Circulation (%) the heart gives out below. Only the hardiest and the frailest differ.
/mob/living/proc/get_heart_stop_circulation()
	var/endurance = get_special(SPECIAL_ENDURANCE)
	if(endurance >= SPECIAL_ENDURANCE_HARDY)
		return BLOOD_CIRC_SURVIVE - (endurance - SPECIAL_ENDURANCE_HARDY + 1) * SPECIAL_ENDURANCE_HEART_STEP
	if(endurance <= SPECIAL_ENDURANCE_FRAIL)
		return BLOOD_CIRC_SURVIVE + (SPECIAL_ENDURANCE_FRAIL - endurance + 1) * SPECIAL_ENDURANCE_HEART_STEP
	return BLOOD_CIRC_SURVIVE

/// Per-tick percent chance a stopped heart starts again by itself, given the blood to pump. Only a hardy one does.
/mob/living/proc/get_heart_restart_chance()
	var/endurance = get_special(SPECIAL_ENDURANCE)
	return endurance >= SPECIAL_ENDURANCE_HARDY ? (endurance - SPECIAL_ENDURANCE_HARDY + 1) * SPECIAL_ENDURANCE_HEART_RESTART : 0

/// Endurance takes the edge off pain.
/mob/living/carbon/getPain()
	return round(..() * (1 - get_special_offset(SPECIAL_ENDURANCE) * SPECIAL_ENDURANCE_PAIN), 1)

/obj/item/bodypart
	/// max_damage before its owner's Endurance.
	var/base_max_damage

/obj/item/bodypart/set_owner(new_owner)
	. = ..()
	update_toughness()

/// A living limb takes as much as its owner's Endurance lets it. Prosthetics and severed limbs don't.
/obj/item/bodypart/proc/update_toughness()
	base_max_damage ||= max_damage
	var/new_max = base_max_damage
	if(owner && IS_ORGANIC_LIMB(src))
		new_max = round(base_max_damage * (1 + owner.get_special_offset(SPECIAL_ENDURANCE) * SPECIAL_ENDURANCE_TOUGHNESS), 1)
	if(new_max != max_damage)
		max_damage = new_max
		update_damage()

/// Sharp eyes see further round.
/mob/living/carbon/human/get_native_fov()
	var/perception = get_special(SPECIAL_PERCEPTION)
	if(perception >= 8)
		return FOV_60_DEGREES
	if(perception <= 3)
		return FOV_120_DEGREES
	return ..()

/// How much quicker (under 1) or slower crafter builds, for their Intelligence.
/proc/special_crafting_mult(mob/living/crafter)
	return isliving(crafter) ? 1 - crafter.get_special_offset(SPECIAL_INTELLIGENCE) * SPECIAL_INTELLIGENCE_CRAFT_SPEED : 1

/datum/species
	/// SPECIAL a species is born with, on top of what's chosen: attribute = amount.
	var/list/special_modifiers
	/// Character sheet stats and skills it's better or worse at: stat or skill type = amount.
	var/list/rpg_modifiers

/datum/species/on_species_gain(mob/living/carbon/C, datum/species/old_species, pref_load)
	. = ..()
	C.special_changed()

/mob/living/proc/get_species_rpg_modifier(path)
	return 0

/mob/living/carbon/human/get_species_rpg_modifier(path)
	return LAZYACCESS(dna?.species?.rpg_modifiers, path)

// The character sheet leans on SPECIAL.

/datum/rpg_stat
	/// The SPECIAL attributes this stat rests on. Each point they average off baseline moves it one.
	var/list/special_attributes

/datum/rpg_stat/soma
	special_attributes = list(SPECIAL_STRENGTH, SPECIAL_ENDURANCE, SPECIAL_AGILITY)

/datum/rpg_stat/psyche
	special_attributes = list(SPECIAL_PERCEPTION, SPECIAL_INTELLIGENCE)

/datum/rpg_stat/pneuma
	special_attributes = list(SPECIAL_CHARISMA, SPECIAL_LUCK)

/datum/rpg_stat/get(mob/living/user, list/out_sources)
	. = ..()
	if(!istype(user))
		return
	if(length(special_attributes))
		var/total = 0
		for(var/attribute in special_attributes)
			total += user.get_special_offset(attribute)
		var/special_bonus = round(total / length(special_attributes), 1)
		if(special_bonus)
			. += special_bonus
			out_sources?["S.P.E.C.I.A.L."] = special_bonus
	var/species_bonus = user.get_species_rpg_modifier(type)
	if(species_bonus)
		. += species_bonus
		out_sources?["Species"] = species_bonus

/datum/rpg_skill/get(mob/living/user, list/out_sources)
	. = ..()
	var/species_bonus = istype(user) && user.get_species_rpg_modifier(type)
	if(species_bonus)
		. += species_bonus
		out_sources?["Species"] = species_bonus

/// Luck bends the odds of a critical either way.
/mob/living/stat_roll(requirement = STATS_BASELINE_VALUE, datum/rpg_skill/skill_path, modifier = 0, crit_fail_modifier = -10, mob/living/defender)
	var/datum/roll_result/result = ..()
	result.apply_luck(get_special_offset(SPECIAL_LUCK), crit_fail_modifier)
	return result

/// Each two points of luck off baseline move where a roll crits, one step either way.
/datum/roll_result/proc/apply_luck(luck, crit_fail_modifier = -10)
	var/shift = round(luck / 2, 1)
	if(!shift)
		return
	var/total = roll + modifier
	var/crit_success = min(requirement + 7, 17) - shift
	var/crit_fail = max(requirement + crit_fail_modifier, 4) - shift
	switch(outcome)
		if(SUCCESS)
			if(total >= crit_success)
				outcome = CRIT_SUCCESS
		if(CRIT_SUCCESS)
			if(total < crit_success)
				outcome = SUCCESS
		if(FAILURE)
			if(total <= crit_fail)
				outcome = CRIT_FAILURE
		if(CRIT_FAILURE)
			if(total > crit_fail)
				outcome = FAILURE

/// What each attribute is, for the character sheet and setup.
/proc/special_description(attribute)
	switch(attribute)
		if(SPECIAL_STRENGTH)
			return "Raw muscle. How hard you hit, grapple and shove, and how lightly you carry and drag a load."
		if(SPECIAL_PERCEPTION)
			return "Your senses. How much of what's around you, you take in."
		if(SPECIAL_ENDURANCE)
			return "Stamina and toughness. How much punishment and pain you take, and how long you keep going."
		if(SPECIAL_CHARISMA)
			return "Presence. How others take to you."
		if(SPECIAL_INTELLIGENCE)
			return "Wits and know-how. How quickly you put things together."
		if(SPECIAL_AGILITY)
			return "Coordination and speed. How quickly you move and get things done."
		if(SPECIAL_LUCK)
			return "Fortune. How often a gamble goes your way."

/mob/living/carbon/human/verb/check_special()
	set name = "S.P.E.C.I.A.L."
	set category = "IC"

	var/list/lines = list()
	for(var/attribute in SPECIAL_ATTRIBUTES)
		lines += "<b>[capitalize(attribute)]</b>: [get_special(attribute)] <i>[special_description(attribute)]</i>"
	to_chat(src, examine_block(jointext(lines, "\n")))

#ifdef UNIT_TESTS
/// SPECIAL starts at baseline, steers the body and the character sheet, takes species modifiers, and Luck bends crits.
/datum/unit_test/ms13_special
	name = "SPECIAL: Attributes Steer The Body And Lean Into The Character Sheet"

/datum/unit_test/ms13_special/Run()
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent)
	for(var/attribute in SPECIAL_ATTRIBUTES)
		if(person.get_special(attribute) != SPECIAL_BASELINE)
			Fail("[attribute] didn't start at baseline.")
	if(person.fov_view != FOV_90_DEGREES)
		Fail("An average person's blind spot wasn't 90 degrees.")

	person.set_special_base(SPECIAL_PERCEPTION, 9)
	if(person.fov_view != FOV_60_DEGREES)
		Fail("Sharp Perception didn't narrow the blind spot.")
	person.set_special_base(SPECIAL_PERCEPTION, 2)
	if(person.fov_view != FOV_120_DEGREES)
		Fail("Poor Perception didn't widen the blind spot.")

	var/soma_before = person.stats.get_stat_modifier(/datum/rpg_stat/soma)
	var/stamina_before = person.stamina.maximum
	var/obj/item/bodypart/chest = person.get_bodypart(BODY_ZONE_CHEST)
	chest.temporary_pain = 40
	var/pain_before = person.getPain()
	var/obj/item/clothing/suit/armor = allocate(/obj/item/clothing/suit)
	armor.slowdown = 1
	person.equip_to_slot_or_del(armor, ITEM_SLOT_OCLOTHING)
	for(var/attribute in list(SPECIAL_STRENGTH, SPECIAL_ENDURANCE, SPECIAL_AGILITY))
		person.set_special_base(attribute, 8)
	if(person.stats.get_stat_modifier(/datum/rpg_stat/soma) != soma_before + 3)
		Fail("Soma didn't rise with Strength, Endurance and Agility.")
	if(abs(person.equipped_speed_mods() - (1 - 3 * SPECIAL_STRENGTH_LOAD)) > 0.001)
		Fail("Strength didn't lighten worn armor.")
	var/datum/reagent/medicine/blood_remedy/drug = new
	var/datum/reagent/consumable/nutriment/food = new
	if(abs(drug.get_dose_mult(person) - (1 + 3 * SPECIAL_STRENGTH_METABOLISM)) > 0.001 || food.get_dose_mult(person) != 1)
		Fail("Strength didn't speed up drug metabolism, or it changed what food gives.")
	qdel(drug)
	qdel(food)
	var/mob/living/carbon/human/weakling = allocate(/mob/living/carbon/human/consistent)
	weakling.set_special_base(SPECIAL_STRENGTH, 2)
	if(person.strength_edge(weakling) != 2 || weakling.strength_edge(person) != -2)
		Fail("Strength didn't tell between two people.")
	if(person.stamina.maximum != stamina_before + 3 * SPECIAL_ENDURANCE_STAMINA)
		Fail("Endurance didn't raise maximum stamina.")
	if(chest.max_damage != round(chest.base_max_damage * (1 + 3 * SPECIAL_ENDURANCE_TOUGHNESS), 1))
		Fail("Endurance didn't toughen limbs.")
	if(person.getPain() != round(pain_before * (1 - 3 * SPECIAL_ENDURANCE_PAIN), 1))
		Fail("Endurance didn't dull pain.")
	// Endurance 8 is hardy: the heart holds out further and can restart. An average one can't.
	if(person.get_endurance_resilience() <= 1 || person.get_heart_stop_circulation() != BLOOD_CIRC_SURVIVE - SPECIAL_ENDURANCE_HEART_STEP || person.get_heart_restart_chance() != SPECIAL_ENDURANCE_HEART_RESTART || weakling.get_heart_stop_circulation() != BLOOD_CIRC_SURVIVE || weakling.get_heart_restart_chance())
		Fail("Endurance didn't steady a hardy heart, or changed an average one.")
	if(abs(person.cached_multiplicative_actions_slowdown - (1 - 3 * SPECIAL_AGILITY_ACTION_SPEED)) > 0.001)
		Fail("Agility didn't speed up timed actions.")
	var/datum/movespeed_modifier/agile = person.has_movespeed_modifier(/datum/movespeed_modifier/special_agility)
	if(!agile || abs(agile.slowdown + 3 * SPECIAL_AGILITY_MOVE_SPEED) > 0.001)
		Fail("Agility didn't speed up walking.")
	// A frail wearer takes the frame's strength, and none of their own Strength or Agility.
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor)
	weakling.set_special_base(SPECIAL_AGILITY, 9)
	weakling.equip_to_slot_if_possible(frame, ITEM_SLOT_OCLOTHING, TRUE, TRUE, bypass_equip_delay_self = TRUE)
	if(weakling.strength_edge(person) != round((frame.strength - 8) / SPECIAL_STRENGTH_CONTEST_STEP, 1) || weakling.equipped_speed_mods() != frame.slowdown || weakling.has_movespeed_modifier(/datum/movespeed_modifier/special_agility))
		Fail("A power armor frame didn't stand in for its wearer's Strength and Agility.")
	if(abs(weakling.get_melee_strength_mult() - ((1 - MS13_STAT_STRONG_MELEE_CONTRIBUTION) + MS13_STAT_STRONG_MELEE_CONTRIBUTION * frame.strength / SPECIAL_BASELINE)) > 0.001)
		Fail("A power armor frame didn't swing at its own strength.")
	chest.temporary_pain = 0
	person.special_changed()
	var/obj/item/bodypart/arm = person.get_bodypart(BODY_ZONE_R_ARM)
	if(arm.unarmed_damage_high != round(initial(arm.unarmed_damage_high) * person.get_melee_strength_mult(), 1) || person.get_melee_strength_mult() <= 1)
		Fail("Strength didn't reach unarmed damage.")
	var/obj/item/organ/muscle/muscle = locate() in arm.contained_organs
	var/obj/item/bodypart/weak_arm = weakling.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/organ/muscle/weak_muscle = locate() in weak_arm.contained_organs
	var/obj/projectile/bullet/ms13/a762/into_strong = allocate(/obj/projectile/bullet/ms13/a762)
	var/obj/projectile/bullet/ms13/a762/into_weak = allocate(/obj/projectile/bullet/ms13/a762)
	if(abs(muscle.maxHealth - MS13_MUSCLE_MAX_HEALTH * (1 + SPECIAL_STRENGTH_TISSUE_DENSITY * 0.36)) > 0.001 || muscle.get_bullet_soak_power(into_strong) <= muscle.get_bullet_stopping_power(into_strong) || weak_muscle.get_bullet_soak_power(into_weak) >= weak_muscle.get_bullet_stopping_power(into_weak))
		Fail("Strength didn't make muscle denser, or weakness lighter.")
	// The same round through nothing but muscle: the dense one soaks more of it.
	for(var/obj/item/organ/O in arm.contained_organs + weak_arm.contained_organs)
		O.bullet_hit_chance = istype(O, /obj/item/organ/muscle) ? 100 : 0
	if(person.get_bullet_transfer_fraction(into_strong, arm) <= weakling.get_bullet_transfer_fraction(into_weak, weak_arm))
		Fail("Dense muscle didn't soak more of a round than light muscle.")
	person.set_special_base(SPECIAL_INTELLIGENCE, 9)
	if(abs(special_crafting_mult(person) - (1 - 4 * SPECIAL_INTELLIGENCE_CRAFT_SPEED)) > 0.001)
		Fail("Intelligence didn't speed up crafting.")

	var/mob/living/carbon/human/brute = allocate(/mob/living/carbon/human/consistent/unit_test_brute)
	if(brute.get_special(SPECIAL_STRENGTH) != 8 || brute.get_special(SPECIAL_LUCK) != SPECIAL_BASELINE || brute.stamina.maximum != weakling.stamina.maximum + 3 * SPECIAL_ENDURANCE_STAMINA)
		Fail("SPECIAL set on a type in code didn't take.")

	var/fine_motor_before = person.stats.get_skill_modifier(/datum/rpg_skill/fine_motor)
	person.dna.species.special_modifiers = list(SPECIAL_STRENGTH = 2)
	person.dna.species.rpg_modifiers = list(/datum/rpg_skill/fine_motor = 2)
	if(person.get_special(SPECIAL_STRENGTH) != 10 || person.stats.get_skill_modifier(/datum/rpg_skill/fine_motor) != fine_motor_before + 2)
		Fail("A species' modifiers didn't apply to SPECIAL or the character sheet.")
	person.dna.species.special_modifiers = null
	person.dna.species.rpg_modifiers = null

	var/datum/roll_result/lucky = new
	lucky.roll = 15
	lucky.requirement = 10
	lucky.outcome = SUCCESS
	lucky.apply_luck(4)
	var/datum/roll_result/unlucky = new
	unlucky.roll = 5
	unlucky.requirement = 10
	unlucky.outcome = FAILURE
	unlucky.apply_luck(-4)
	if(lucky.outcome != CRIT_SUCCESS || unlucky.outcome != CRIT_FAILURE)
		Fail("Luck didn't widen the window a roll crits in.")

/datum/ms13_stats/unit_test_brute
	strength = 8
	endurance = 8

/mob/living/carbon/human/consistent/unit_test_brute
	ms13_stats = /datum/ms13_stats/unit_test_brute
#endif
