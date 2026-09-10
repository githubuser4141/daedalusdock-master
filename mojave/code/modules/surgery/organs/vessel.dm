// One damageable /obj/item/organ/vessel per limb. Self-contained per limb, no cross-limb network.
// Rupture severs the limb's artery via DD's real set_sever_artery(). icon_state "fixovein" is a placeholder.

/obj/item/organ/vessel
	name = "blood vessel"
	desc = "A major blood vessel. Best left where it is."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "fixovein"
	w_class = WEIGHT_CLASS_TINY
	organ_flags = NONE // not edible - this isn't a heart or a liver
	maxHealth = MS13_VESSEL_MAX_HEALTH
	relative_size = MS13_VESSEL_RELATIVE_SIZE
	low_threshold_passed = span_info("You feel a twinge of pain, deep beneath the skin...")
	high_threshold_passed = span_warning("Something inside is bleeding badly, and it isn't stopping on its own.")
	now_failing = span_userdanger("Something ruptures inside, and blood starts pouring out!")
	now_fixed = span_info("The bleeding beneath your skin finally stops.")
	high_threshold_cleared = span_info("The bleeding beneath your skin slows.")
	/// Carotid/aorta vs a limb's artery - see set_organ_dead() below.
	var/major_vessel = FALSE

/// Sync the limb's artery to match, plus a one-time blood burst on major vessel rupture.
/obj/item/organ/vessel/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!. || !ownerlimb)
		return
	ownerlimb.set_sever_artery(failing)
	if(failing && major_vessel && owner)
		owner.blood_volume = max(0, owner.blood_volume - MS13_MAJOR_VESSEL_BLOOD_BURST)
		to_chat(owner, span_userdanger("A sudden gush of blood leaves you lightheaded!"))

/**
 * A missing vessel means no blood is getting to this limb at all - worse than even a ruptured one (which
 * can at least be repaired quickly). Snap local_blood_volume to 0 instead of leaving it frozen at whatever
 * it was the moment the vessel left, so the general regen gate and get_vessel_circulation_factor() (both in
 * vessel_local_blood.dm/vessel.dm) correctly treat the limb as fully blood-starved in the meantime. A new
 * vessel put back in doesn't need special handling here - it starts from this 0 and refills naturally
 * through its own on_life() regen, same as a healed one would.
 */
/obj/item/organ/vessel/Remove(mob/living/carbon/organ_owner, special = FALSE)
	var/obj/item/bodypart/limb = ownerlimb
	. = ..()
	if(limb)
		limb.local_blood_volume = 0

/obj/item/organ/vessel/head
	name = "carotid artery"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_VESSEL_HEAD
	major_vessel = TRUE

/obj/item/organ/vessel/chest
	name = "aorta"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_VESSEL_CHEST
	major_vessel = TRUE

/**
 * DD's own artery-fix tooling (the fix_vein surgery step, anti-coagulant chems, human.dm's full-heal) all
 * clear BP_ARTERY_CUT by calling set_sever_artery(FALSE) directly on the bodypart - none of them know the
 * vessel organ exists, so without this the bleeding would visibly stop while the vessel organ stayed
 * ruptured/dead forever (DD organs don't auto-recover from ORGAN_DEAD - see can_recover()/
 * check_failing_thresholds() in code/modules/surgery/organs/_organ.dm), permanently desynced from what the
 * player can see and treat. Hooking the shared proc here fixes every one of those call sites at once
 * instead of patching each individually. Safe against the set_organ_dead(FALSE) -> set_sever_artery(FALSE)
 * bounce below: the real set_sever_artery() no-ops (returns FALSE) once the artery's already fixed, so this
 * can't loop.
 */
/obj/item/bodypart/set_sever_artery(val = TRUE)
	. = ..()
	if(!. || val) // no change, or this was a *cut* - a spontaneous DD wound-roll cut doesn't imply the vessel itself is damaged
		return
	for(var/obj/item/organ/vessel/V in contained_organs)
		if(V.organ_flags & ORGAN_DEAD)
			V.applyOrganDamage(-V.damage, silent = TRUE)
			V.set_organ_dead(FALSE)
		return

/obj/item/organ/vessel/l_arm
	name = "brachial artery"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_VESSEL_L_ARM

/obj/item/organ/vessel/r_arm
	name = "brachial artery"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_VESSEL_R_ARM

/obj/item/organ/vessel/l_leg
	name = "femoral artery"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_VESSEL_L_LEG

/obj/item/organ/vessel/r_leg
	name = "femoral artery"
	zone = BODY_ZONE_R_LEG
	slot = ORGAN_SLOT_VESSEL_R_LEG

/**
 * DD already computes a real whole-body "circulation number" - /mob/living/carbon/proc/get_blood_circulation()
 * (code/modules/mob/living/blood.dm) - as blood_volume% scaled down by heart condition, and that number is
 * what get_blood_oxygenation() reads, which is what actually kills you (brain damage from low oxygenation,
 * see /obj/item/organ/brain/on_life()). Vessels currently have no input into it at all - a ruptured artery
 * only causes local bleeding via bleed_rate, it does nothing to the number that actually matters for organ
 * function. This gives them a real second job (the "prop up circulation" idea): a 0-1 multiplier applied on
 * top of the existing heart/blood_volume math, built from each vessel's own damage ratio - that IS the local
 * volume/global volume split described, just without a separate local blood currency: a vessel's own health
 * already stands in for how much blood is getting through that pathway, no extra state needed. A fully
 * healthy set of vessels multiplies by 1 (no change for anyone who hasn't been hit yet). major_vessel slots
 * (carotid/aorta) count double - losing the aorta should hurt whole-body circulation much more than losing a
 * wrist's worth of vessel.
 */
/mob/living/carbon/human/proc/get_vessel_circulation_factor()
	var/static/list/vessel_slot_weights = list(
		(ORGAN_SLOT_VESSEL_HEAD) = 2,
		(ORGAN_SLOT_VESSEL_CHEST) = 2,
		(ORGAN_SLOT_VESSEL_L_ARM) = 1,
		(ORGAN_SLOT_VESSEL_R_ARM) = 1,
		(ORGAN_SLOT_VESSEL_L_LEG) = 1,
		(ORGAN_SLOT_VESSEL_R_LEG) = 1,
	)
	var/total_weight = 0
	var/prop_sum = 0
	for(var/slot in vessel_slot_weights)
		var/weight = vessel_slot_weights[slot]
		total_weight += weight
		var/obj/item/organ/vessel/V = getorganslot(slot)
		if(!V || !V.ownerlimb || (V.organ_flags & ORGAN_DEAD))
			continue // missing or ruptured - contributes nothing to circulation
		var/damage_factor = 1 - (V.damage / V.maxHealth)
		// AI EDIT: also folds in local_blood_volume (mojave/code/modules/surgery/organs/vessel_local_blood.dm) -
		// a limb can be locally blood-starved (drained faster than it's regenerating) even before its vessel
		// takes enough damage to show up in damage_factor, so this keeps the two in sync instead of only one
		// of them mattering.
		var/local_blood_factor = V.ownerlimb.local_blood_volume / V.ownerlimb.local_blood_volume_max
		prop_sum += weight * damage_factor * local_blood_factor
	if(!total_weight)
		return 1
	return prop_sum / total_weight

/mob/living/carbon/human/get_blood_circulation()
	. = ..()
	. *= get_vessel_circulation_factor()

/**
 * Every human gets one vessel organ per limb (and one muscle organ per arm/leg - see muscle.dm), same as
 * DD's own baseline organs (/datum/species/var/organs, code/modules/mob/living/carbon/human/species.dm).
 * Not editing that list directly - this appends to it after the real one is built.
 *
 * AI EDIT: this is the ONLY /datum/species/New() override across the mojave organ files - DM silently lets
 * a later-compiled full redeclaration of the same proc+type replace an earlier one outright, no merge, no
 * warning (the exact bug that broke power armor's apply_damage() earlier - see human_armor.dm). Any future
 * organ system needs its slots added HERE, not in a second /datum/species/New() override elsewhere.
 */
/datum/species/New()
	. = ..()
	organs[ORGAN_SLOT_VESSEL_HEAD] = /obj/item/organ/vessel/head
	organs[ORGAN_SLOT_VESSEL_CHEST] = /obj/item/organ/vessel/chest
	organs[ORGAN_SLOT_VESSEL_L_ARM] = /obj/item/organ/vessel/l_arm
	organs[ORGAN_SLOT_VESSEL_R_ARM] = /obj/item/organ/vessel/r_arm
	organs[ORGAN_SLOT_MUSCLE_L_ARM] = /obj/item/organ/muscle/l_arm
	organs[ORGAN_SLOT_MUSCLE_R_ARM] = /obj/item/organ/muscle/r_arm
	organs[ORGAN_SLOT_MUSCLE_L_LEG] = /obj/item/organ/muscle/l_leg
	organs[ORGAN_SLOT_MUSCLE_R_LEG] = /obj/item/organ/muscle/r_leg
	organs[ORGAN_SLOT_VESSEL_L_LEG] = /obj/item/organ/vessel/l_leg
	organs[ORGAN_SLOT_VESSEL_R_LEG] = /obj/item/organ/vessel/r_leg
