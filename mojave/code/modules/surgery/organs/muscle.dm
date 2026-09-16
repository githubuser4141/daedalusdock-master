// One damageable /obj/item/organ/muscle per arm/leg, alongside the vessel (vessel.dm). Performance (0-100,
// get_performance() below) drives limb function - see muscle_movement.dm for how that reaches melee damage,
// movement speed, standing, and grabbing. Performance has two inputs: the muscle's own damage (permanent
// until healed) and current local blood flow (vessel_local_blood.dm) - partial blood loss only costs
// performance, not damage; local_blood_volume hitting 0 outright already triggers real ischemic damage via
// the general starve_organs() mechanic, so sustained starvation costs real health too, through the system
// that already exists for that.
// Organ sprites are ported from CEV-Eris (icons/obj/surgery.dmi, AGPL-3.0) into
// mojave/icons/objects/organs/tissue_organs.dmi.

/obj/item/organ/muscle
	name = "muscle tissue"
	desc = "A bundle of muscle fibers. Best left where it is."
	icon = 'mojave/icons/objects/organs/tissue_organs.dmi'
	icon_state = "human_muscle"
	w_class = WEIGHT_CLASS_SMALL
	organ_flags = ORGAN_EDIBLE
	ms13_tissue = TRUE
	maxHealth = MS13_MUSCLE_MAX_HEALTH
	relative_size = MS13_MUSCLE_RELATIVE_SIZE
	low_threshold_passed = span_info("A dull ache settles into the muscle...")
	high_threshold_passed = span_warning("The muscle burns and spasms, weaker than it should be.")
	now_failing = span_userdanger("Something tears inside - the muscle gives out entirely!")
	now_fixed = span_info("The muscle finally stops aching.")
	high_threshold_cleared = span_info("The muscle stops burning.")
	/// Legs get movement/buckle effects, arms get melee scaling - see muscle_movement.dm.
	var/is_leg_muscle = FALSE
	/// Last get_performance() value pushed through refresh_muscle_effects(), so on_life() can skip the
	/// resync when nothing has changed. -1 rather than 0 so the first tick always syncs.
	var/last_synced_performance = -1

/obj/item/organ/muscle/l_arm
	name = "left arm muscle"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_MUSCLE_L_ARM

/obj/item/organ/muscle/r_arm
	name = "right arm muscle"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_MUSCLE_R_ARM

/obj/item/organ/muscle/l_leg
	name = "left leg muscle"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_MUSCLE_L_LEG
	is_leg_muscle = TRUE

/obj/item/organ/muscle/r_leg
	name = "right leg muscle"
	zone = BODY_ZONE_R_LEG
	slot = ORGAN_SLOT_MUSCLE_R_LEG
	is_leg_muscle = TRUE

/// Chest wall muscle - armor (natural_armor.dm) and myoglobin only, no movement/grip output (chest isn't a
/// grabby or movement limb, so refresh_muscle_effects() naturally skips those parts).
/obj/item/organ/muscle/chest
	name = "chest muscle"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_MUSCLE_CHEST

/// 0-100: own damage ratio times current local blood flow ratio. Always 0 once destroyed.
/obj/item/organ/muscle/proc/get_performance()
	if(organ_flags & ORGAN_DEAD)
		return 0
	var/damage_factor = 1 - (damage / maxHealth)
	var/blood_factor = 1
	if(ownerlimb)
		blood_factor = ownerlimb.local_blood_volume / ownerlimb.local_blood_volume_max
	return round(100 * damage_factor * blood_factor, 0.1)

/obj/item/organ/muscle/on_life(delta_time, times_fired)
	. = ..()
	if(!ownerlimb || !owner)
		return
	// Only re-sync when the number that drives those effects actually moved. This used to run every tick
	// for every muscle - five per human, each doing an update_disabled() and a whole-body movespeed
	// recalculation - against a value that changes rarely. on_life is documented as very hot.
	var/performance = get_performance()
	if(performance != last_synced_performance)
		last_synced_performance = performance
		ownerlimb.refresh_muscle_effects()
	if(is_leg_muscle)
		check_buckle(delta_time)
	if(damage > 0)
		add_myoglobin(MS13_MUSCLE_WASTE_PER_DAMAGE * damage * delta_time)
		ms13_medical_debug(owner, "Muscle [name] performance=[get_performance()] damage=[damage]/[maxHealth]")

/// A weak leg can buckle mid-stride - deliberately not DD's real TRAIT_FLOORED (a hard floor for a leg that
/// flat-out doesn't work), just a brief recoverable stumble for one that's merely weak.
/obj/item/organ/muscle/proc/check_buckle(delta_time)
	if(owner.body_position == LYING_DOWN || HAS_TRAIT(owner, TRAIT_FLOORED))
		return
	var/perf = get_performance()
	if(perf >= MS13_MUSCLE_BUCKLE_PERFORMANCE_THRESHOLD)
		return
	var/deficit = MS13_MUSCLE_BUCKLE_PERFORMANCE_THRESHOLD - perf
	var/chance = MS13_MUSCLE_BUCKLE_BASE_CHANCE * (deficit / MS13_MUSCLE_BUCKLE_PERFORMANCE_THRESHOLD) * delta_time
	if(!prob(chance))
		return
	owner.visible_message(
		span_danger("[owner]'s [ownerlimb.plaintext_zone] buckles under [owner.p_them()]!"),
		span_userdanger("Your [ownerlimb.plaintext_zone] buckles - you go down!"),
	)
	owner.Knockdown(1.5 SECONDS)
	ms13_medical_debug(owner, "Leg muscle buckle: performance=[perf] chance=[chance]%")

/// Destroying a muscle dumps a myoglobin burst on top of the ongoing trickle - a vessel rupture bleeds
/// instead (vessel.dm's set_organ_dead()).
/obj/item/organ/muscle/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!.)
		return
	if(failing && owner)
		add_myoglobin(MS13_MUSCLE_RUPTURE_WASTE_BURST)
		to_chat(owner, span_userdanger("Your [zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM ? "arm" : "leg"] floods with the poison of dead muscle tissue!"))
		ms13_medical_debug(owner, "Muscle [name] destroyed - myoglobin burst +[MS13_MUSCLE_RUPTURE_WASTE_BURST]")
	if(ownerlimb)
		ownerlimb.refresh_muscle_effects()

/// Adds myoglobin clamped to get_myoglobin_ceiling().
/obj/item/organ/muscle/proc/add_myoglobin(amount)
	if(!owner?.reagents || amount <= 0)
		return
	var/ceiling = get_myoglobin_ceiling()
	var/current = owner.reagents.get_reagent_amount(/datum/reagent/toxin/myoglobin)
	if(current >= ceiling)
		return
	var/added = min(amount, ceiling - current)
	owner.reagents.add_reagent(/datum/reagent/toxin/myoglobin, added)
	ms13_medical_debug(owner, "Myoglobin +[round(added, 0.1)] (now [round(current + added, 0.1)]/[ceiling])")

/// Ceiling scales with how many muscles are CURRENTLY damaged (not a running count) - one smashed limb stays
/// survivable, smashed up everywhere is genuine danger.
/obj/item/organ/muscle/proc/get_myoglobin_ceiling()
	var/contributing = 0
	for(var/obj/item/organ/muscle/M in owner.organs)
		if(M.damage > 0 || (M.organ_flags & ORGAN_DEAD))
			contributing++
	return max(1, contributing) * MS13_MUSCLE_WASTE_MAX_VOLUME_PER_MUSCLE

/// Real, separate reagent value with its own self-metabolizing toxin effect (base /datum/reagent/toxin/
/// affect_blood()) - same pattern as kidneys.dm's potassium, not a direct adjustToxLoss() call.
/datum/reagent/toxin/myoglobin
	name = "Myoglobin"
	description = "A muscle tissue breakdown byproduct. Toxic in large amounts."
	color = "#7a2d2d"
	taste_description = "copper"
	toxpwr = 0.8
	silent_toxin = TRUE

/obj/item/organ/muscle/Insert(mob/living/carbon/reciever, special = FALSE, drop_if_replaced = TRUE)
	. = ..()
	if(ownerlimb)
		ownerlimb.refresh_muscle_effects()

/// A missing muscle floors performance at MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR instead of 0 - refresh
/// immediately since no more on_life() ticks are coming from this (removed) organ.
/obj/item/organ/muscle/Remove(mob/living/carbon/organ_owner, special = FALSE)
	var/obj/item/bodypart/limb = ownerlimb
	. = ..()
	if(limb)
		limb.refresh_muscle_effects()

/// Registers muscle with the natural-armor-layer framework (natural_armor.dm) - some of a BRUTE hit is gone
/// entirely, some becomes real muscle damage, the rest passes through, all scaled by the muscle's own
/// remaining health. Separate from and applied after external armor/subarmor.
/datum/natural_armor_layer/muscle
	gone_fraction = MS13_MUSCLE_ARMOR_GONE_FRACTION
	absorb_fraction = MS13_MUSCLE_ARMOR_ABSORB_FRACTION

/datum/natural_armor_layer/muscle/get_organ(mob/living/carbon/human/H, obj/item/bodypart/hit_part, damagetype)
	if(damagetype != BRUTE)
		return null
	return locate(/obj/item/organ/muscle) in hit_part.contained_organs
