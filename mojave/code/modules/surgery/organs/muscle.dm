// One damageable /obj/item/organ/muscle per arm/leg, sitting alongside the vessel already installed in each
// limb (mojave/code/modules/surgery/organs/vessel.dm). Performance (0-100) drives real limb function -
// unarmed damage for arms, movement speed and a chance to buckle for legs - layered ON TOP of DD's existing
// bodypart_disabled/usable_legs/usable_hands cascade rather than replacing it (see refresh_muscle_effects()
// on /obj/item/bodypart and the update_disabled() override in code/modules/surgery/bodyparts/_bodyparts.dm).
//
// Performance has two independent inputs: how damaged the muscle itself is (permanent until healed), and
// how much local blood is reaching the limb (mojave/code/modules/surgery/organs/vessel_local_blood.dm) -
// partial blood loss only costs performance, not damage; local_blood_volume hitting 0 outright already
// triggers real ischemic damage to every organ in the limb (including this one) via the general
// starve_organs() mechanic, so full starvation eventually costs real health too, just through the system
// that already exists for that rather than a second parallel one here.

/obj/item/organ/muscle
	name = "muscle tissue"
	desc = "A bundle of muscle fibers. Best left where it is."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "fixovein" // placeholder - same reused sprite vessel.dm uses, no dedicated muscle art exists yet
	w_class = WEIGHT_CLASS_SMALL
	organ_flags = ORGAN_EDIBLE
	maxHealth = MS13_MUSCLE_MAX_HEALTH
	relative_size = MS13_MUSCLE_RELATIVE_SIZE
	low_threshold_passed = span_info("A dull ache settles into the muscle...")
	high_threshold_passed = span_warning("The muscle burns and spasms, weaker than it should be.")
	now_failing = span_userdanger("Something tears inside - the muscle gives out entirely!")
	now_fixed = span_info("The muscle finally stops aching.")
	high_threshold_cleared = span_info("The muscle stops burning.")
	/// Legs get movement/buckle effects, arms get melee scaling - see on_life() and
	/// /obj/item/bodypart/proc/refresh_muscle_effects().
	var/is_leg_muscle = FALSE

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

/// 0-100. Own damage (permanent until healed) times current local blood flow (reversible, no damage from
/// this factor alone - see header). A destroyed (ORGAN_DEAD) muscle is always 0 regardless of local blood.
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
	ownerlimb.refresh_muscle_effects()
	if(is_leg_muscle)
		check_buckle(delta_time)
	// AI EDIT: varying amounts of myoglobin (below), not direct toxin damage - same "real, separate value"
	// pattern kidneys.dm uses for potassium, scaled continuously to current damage rather than a flat number.
	// Capped (add_myoglobin() below) so this can never snowball into a kidney/liver damage spiral no matter
	// how much muscle damage exists or how long it persists.
	if(damage > 0)
		add_myoglobin(MS13_MUSCLE_WASTE_PER_DAMAGE * damage * delta_time)

/**
 * A weak leg doesn't just walk slower (see refresh_muscle_effects() -> update_muscle_movespeed()) - it can
 * give out mid-stride. This is deliberately NOT the same as DD's real TRAIT_FLOORED (usable_legs == 0,
 * living.dm) - that's a hard floor for a limb that flat-out doesn't work; this is a brief, recoverable
 * stumble for a limb that's merely weak, matching "should be able to stand up then fall over again."
 */
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

/// Destroying a muscle outright dumps a burst of myoglobin into the bloodstream on top of the ongoing
/// trickle above - distinct from a vessel rupture, which bleeds instead (vessel.dm's set_organ_dead()).
/// Also immediately refreshes melee/movement effects rather than waiting for the next life tick.
/obj/item/organ/muscle/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!.)
		return
	if(failing && owner)
		add_myoglobin(MS13_MUSCLE_RUPTURE_WASTE_BURST)
		to_chat(owner, span_userdanger("Your [zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM ? "arm" : "leg"] floods with the poison of dead muscle tissue!"))
	if(ownerlimb)
		ownerlimb.refresh_muscle_effects()

/// Adds myoglobin to the bloodstream, clamped to get_myoglobin_ceiling() - see MS13_MUSCLE_WASTE_MAX_VOLUME_
/// PER_MUSCLE for why this scales with how many muscles are hurt instead of being one flat number.
/obj/item/organ/muscle/proc/add_myoglobin(amount)
	if(!owner?.reagents || amount <= 0)
		return
	var/ceiling = get_myoglobin_ceiling()
	var/current = owner.reagents.get_reagent_amount(/datum/reagent/toxin/myoglobin)
	if(current >= ceiling)
		return
	owner.reagents.add_reagent(/datum/reagent/toxin/myoglobin, min(amount, ceiling - current))

/// One smashed limb should be bounded and survivable; smashed up everywhere should be real danger - the
/// ceiling is MS13_MUSCLE_WASTE_MAX_VOLUME_PER_MUSCLE times how many muscles are CURRENTLY damaged right
/// now (not a running historical count - a muscle that's since healed stops counting).
/obj/item/organ/muscle/proc/get_myoglobin_ceiling()
	var/contributing = 0
	for(var/obj/item/organ/muscle/M in owner.organs)
		if(M.damage > 0 || (M.organ_flags & ORGAN_DEAD))
			contributing++
	return max(1, contributing) * MS13_MUSCLE_WASTE_MAX_VOLUME_PER_MUSCLE

/**
 * Muscle breakdown byproduct - a real, separate reagent value with its own effect (self-metabolizing toxin
 * damage via the base /datum/reagent/toxin/affect_blood(), code/modules/reagents/chemistry/reagents/
 * toxin_reagents.dm), same pattern as kidneys.dm's potassium rather than calling adjustToxLoss() directly.
 */
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

/**
 * A missing muscle floors that limb's performance at MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR rather than 0 -
 * there's presumably more muscle tissue than just this one organ models. Refresh immediately rather than
 * waiting for the next life tick that will now never come from this (removed) organ.
 */
/obj/item/organ/muscle/Remove(mob/living/carbon/organ_owner, special = FALSE)
	var/obj/item/bodypart/limb = ownerlimb
	. = ..()
	if(limb)
		limb.refresh_muscle_effects()

/// See /obj/item/organ/muscle/proc/get_performance() - floors at MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR if
/// this limb doesn't have a muscle organ installed at all.
/obj/item/bodypart/proc/get_muscle_performance()
	var/obj/item/organ/muscle/M = locate() in contained_organs
	if(!M)
		return MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR
	return M.get_performance()

/**
 * The single point where muscle performance actually does something to this limb - called from the muscle
 * organ's on_life()/Insert()/Remove()/set_organ_dead(), never computed inline elsewhere, so every transition
 * (damage, healing, blood flow changing, the organ itself coming or going) stays in sync automatically:
 * - grabby limbs (arms/hands): scale unarmed_damage_low/high off the limb's OWN declared defaults (so this
 *   is idempotent, not cumulative - repeated calls at the same performance always land on the same value)
 * - movement limbs (legs): recompute the mob's whole-body muscle_weakness movespeed modifier (both legs
 *   feed one modifier - see /mob/living/carbon/human/proc/update_muscle_movespeed())
 * - always: re-run update_disabled() so a critically weak limb combines with DD's real disabled cascade
 *   (usable_legs/usable_hands/TRAIT_FLOORED/TRAIT_HANDS_BLOCKED/item drop - see _bodyparts.dm) instead of
 *   needing a second, parallel one.
 */
/obj/item/bodypart/proc/refresh_muscle_effects()
	if(bodypart_flags & BP_IS_GRABBY_LIMB)
		var/perf_ratio = get_muscle_performance() / 100
		unarmed_damage_low = round(initial(unarmed_damage_low) * perf_ratio, 1)
		unarmed_damage_high = round(initial(unarmed_damage_high) * perf_ratio, 1)
	if(bodypart_flags & BP_IS_MOVEMENT_LIMB)
		var/mob/living/carbon/human/human_owner = istype(owner, /mob/living/carbon/human) ? owner : null
		human_owner?.update_muscle_movespeed()
	update_disabled()

/// See update_disabled() override below.
/obj/item/bodypart/proc/muscle_critically_weak()
	if(!(bodypart_flags & (BP_IS_GRABBY_LIMB|BP_IS_MOVEMENT_LIMB)))
		return FALSE
	return get_muscle_performance() <= MS13_MUSCLE_CRITICAL_PERFORMANCE

/**
 * Both legs' muscle performance feed one whole-body movement penalty, stacking additively with DD's real
 * /datum/movespeed_modifier/limbless (living.dm's set_usable_legs()) rather than replacing it - a fully
 * disabled leg still gets that flat binary penalty same as ever, this just adds a graduated one for legs
 * that are present but weak.
 */
/mob/living/carbon/human/proc/update_muscle_movespeed()
	var/obj/item/bodypart/l_leg = get_bodypart(BODY_ZONE_L_LEG)
	var/obj/item/bodypart/r_leg = get_bodypart(BODY_ZONE_R_LEG)
	var/l_perf = l_leg ? l_leg.get_muscle_performance() : 100
	var/r_perf = r_leg ? r_leg.get_muscle_performance() : 100
	var/avg_deficit = 100 - ((l_perf + r_perf) * 0.5)
	if(avg_deficit <= 0)
		remove_movespeed_modifier(/datum/movespeed_modifier/muscle_weakness)
		return
	var/slowdown = (avg_deficit / 100) * MS13_MUSCLE_LEG_MAX_SLOWDOWN
	add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/muscle_weakness, slowdown = slowdown)

/datum/movespeed_modifier/muscle_weakness
	variable = TRUE
	movetypes = GROUND

/**
 * DD's real update_pull_movespeed() (code/modules/mob/living/living_movement.dm) already applies slowdown
 * per active grab (heavier/prone targets, structures with their own drag_slowdown) via
 * /datum/movespeed_modifier/grabbing - this doesn't touch that, it layers an independent penalty on top from
 * whichever grabbing arm is weakest among your active grabs, same "combine with existing gating" approach as
 * everywhere else in this system.
 */
/mob/living/carbon/human/update_pull_movespeed()
	. = ..()
	var/worst_deficit = 0
	for(var/obj/item/hand_item/grab/G as anything in active_grabs)
		var/held_index = get_held_index_of_item(G)
		var/obj/item/bodypart/grab_arm = held_index ? hand_bodyparts?[held_index] : null
		if(!grab_arm)
			continue
		worst_deficit = max(worst_deficit, 100 - grab_arm.get_muscle_performance())
	if(worst_deficit <= 0)
		remove_movespeed_modifier(/datum/movespeed_modifier/muscle_drag_weakness)
		return
	add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/muscle_drag_weakness, slowdown = (worst_deficit / 100) * MS13_MUSCLE_DRAG_MAX_SLOWDOWN)

/datum/movespeed_modifier/muscle_drag_weakness
	variable = TRUE
	movetypes = GROUND

