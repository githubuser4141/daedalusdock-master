// One damageable /obj/item/organ/vessel per limb. Self-contained per limb, no cross-limb network.
// Rupture severs the limb's artery via DD's real set_sever_artery().
// Organ sprites are ported from CEV-Eris (icons/obj/surgery.dmi, AGPL-3.0) into
// mojave/icons/objects/organs/tissue_organs.dmi.

/// Debug-only to_chat for the vessel/muscle systems - see MS13_MEDICAL_DEBUG_ENABLED (vessels.dm). Global so
/// every file in both systems (including code/modules/grab/grab_datum.dm) can call it without a namespace.
/proc/ms13_medical_debug(mob/recipient, message)
	if(!MS13_MEDICAL_DEBUG_ENABLED)
		return
	to_chat(recipient, span_notice("[DEBUG] [message]"))

TYPEINFO_DEF(/obj/item/organ/vessel)
	default_armor = list(BLUNT = 25, PUNCTURE = 10, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 25, ACID = 25) // famously low slash armor

/obj/item/organ/vessel
	name = "blood vessel"
	desc = "A major blood vessel. Best left where it is."
	icon = 'mojave/icons/objects/organs/tissue_organs.dmi'
	icon_state = "blood_vessel"
	w_class = WEIGHT_CLASS_TINY
	organ_flags = NONE // not edible - this isn't a heart or a liver
	ms13_tissue = TRUE
	maxHealth = MS13_VESSEL_MAX_HEALTH
	relative_size = MS13_VESSEL_RELATIVE_SIZE
	low_threshold_passed = span_info("You feel a twinge of pain, deep beneath the skin...")
	high_threshold_passed = span_warning("Something inside is bleeding badly, and it isn't stopping on its own.")
	now_failing = span_userdanger("Something ruptures inside, and blood starts pouring out!")
	now_fixed = span_info("The bleeding beneath your skin finally stops.")
	high_threshold_cleared = span_info("The bleeding beneath your skin slows.")
	/// How big this vessel is, relative to a limb artery (1) - aorta/carotid are bigger, see the subtypes
	/// below. Scales the one-time rupture burst (set_organ_dead()), the ongoing bleed rate (on_life(),
	/// vessel_local_blood.dm), and this vessel's weight in get_vessel_circulation_factor() below.
	var/vessel_size = 1

/**
 * What a damaged-but-not-ruptured vessel contributes to its limb's bleed rate, called from
 * refresh_bleed_rate() (code/modules/surgery/bodyparts/_bodyparts.dm). Going through the limb's rate
 * instead of calling owner.bleed() directly is what makes bandaging, clamping, lying down and
 * anticoagulants work on vessel bleeding at all.
 *
 * A fully ruptured vessel contributes nothing here on purpose - that case is already represented by the
 * flat +4 the severed-artery term adds just above the call site, and counting both meant a burst aorta
 * bled at several times the intended rate with no treatment able to touch the larger half of it.
 */
/obj/item/bodypart/proc/get_vessel_bleed_rate()
	. = 0
	for(var/obj/item/organ/vessel/V in contained_organs)
		if(!V.damage || (V.organ_flags & ORGAN_DEAD))
			continue
		// Blood only leaves the body where there's a path out. An intact surface over a damaged vessel
		// pools internally instead (that half is handled in vessel_local_blood.dm's on_life()).
		var/external_mult = (bodypart_flags & BP_BLEEDING) ? MS13_BLEED_RATIO_SHARP_EXTERNAL_MULT : MS13_BLEED_RATIO_BLUNT_EXTERNAL_MULT
		. += V.damage * MS13_VESSEL_BLEED_GLOBAL_PER_DAMAGE * external_mult * V.vessel_size

/// The limb's bleed rate is cached, so it has to be recomputed whenever this vessel's damage changes.
/obj/item/organ/vessel/applyOrganDamage(damage_amount, maximum = maxHealth, silent, updating_health = TRUE, cause_of_death = "Organ failure")
	. = ..()
	if(.)
		ownerlimb?.refresh_bleed_rate()

/// Sync the limb's artery to match, plus a one-time blood burst on rupture scaled by vessel_size.
/obj/item/organ/vessel/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!. || !ownerlimb)
		return
	ownerlimb.set_sever_artery(failing)
	if(failing && owner)
		owner.blood_volume = max(0, owner.blood_volume - MS13_VESSEL_BLOOD_BURST_PER_SIZE * vessel_size)
		to_chat(owner, vessel_size >= 2 ? span_userdanger("A sudden gush of blood leaves you lightheaded!") : span_warning("Blood spurts from the wound!"))
	ms13_medical_debug(owner, "Vessel [name] ([zone]) [failing ? "ruptured" : "repaired"] (size=[vessel_size])")

/**
 * A missing vessel means no blood is getting to this limb at all - worse than even a ruptured one (which
 * can at least be repaired quickly). Snap local_blood_volume to 0 instead of leaving it frozen at whatever
 * it was the moment the vessel left, so the general regen gate and get_vessel_circulation_factor() (both in
 * vessel_local_blood.dm/vessel.dm) correctly treat the limb as fully blood-starved in the meantime. A new
 * vessel put back in doesn't need special handling here - it starts from this 0 and refills naturally
 * through its own on_life() regen, same as a healed one would.
 *
 * AI EDIT (bugfix): gated on !special. species.dm's regenerate_organs() silently swaps organs via
 * oldorgan.Remove(C, TRUE) -> Insert() (fires whenever a character's species/appearance is (re)applied,
 * which can happen more than once during spawn) - without this guard that routine swap zeroed
 * local_blood_volume on every limb, tanking circulation/muscle performance to 0 and causing near-instant
 * cardiac arrest + every limb force-disabling right after spawn. Real removal (surgery, dismemberment)
 * still passes special=FALSE and correctly zeroes it.
 */
/obj/item/organ/vessel/Remove(mob/living/carbon/organ_owner, special = FALSE)
	var/obj/item/bodypart/limb = ownerlimb
	. = ..()
	if(limb && !special)
		limb.local_blood_volume = 0

/obj/item/organ/vessel/head
	name = "carotid artery"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_VESSEL_HEAD
	vessel_size = 2

/obj/item/organ/vessel/chest
	name = "aorta"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_VESSEL_CHEST
	vessel_size = 3

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
	vessel_size = 1.5

/obj/item/organ/vessel/r_leg
	name = "femoral artery"
	zone = BODY_ZONE_R_LEG
	slot = ORGAN_SLOT_VESSEL_R_LEG
	vessel_size = 1.5

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
 * healthy set of vessels multiplies by 1 (no change for anyone who hasn't been hit yet). Each slot is
 * weighted by that vessel type's own vessel_size (see the subtypes above) - losing the aorta (size 3) should
 * hurt whole-body circulation much more than losing a wrist's worth of vessel (size 1).
 *
 * The weights mirror each subtype's vessel_size above: a vessel missing from a limb that's still attached counts
 * against total_weight at its normal size. A limb that's gone altogether doesn't count at all - an amputee's
 * stump doesn't starve the rest of the body.
 */
/mob/living/carbon/human/proc/get_vessel_circulation_factor()
	var/static/list/vessel_zone_weights = list(
		(BODY_ZONE_HEAD) = 2,
		(BODY_ZONE_CHEST) = 3,
		(BODY_ZONE_L_ARM) = 1,
		(BODY_ZONE_R_ARM) = 1,
		(BODY_ZONE_L_LEG) = 1.5,
		(BODY_ZONE_R_LEG) = 1.5,
	)
	var/total_weight = 0
	var/prop_sum = 0
	for(var/zone in vessel_zone_weights)
		var/obj/item/bodypart/limb = get_bodypart(zone)
		if(!limb)
			continue
		var/weight = vessel_zone_weights[zone]
		total_weight += weight
		var/obj/item/organ/vessel/V = locate() in limb.contained_organs
		if(!V || (V.organ_flags & ORGAN_DEAD))
			continue // missing or ruptured - contributes nothing to circulation
		var/damage_factor = 1 - (V.damage / V.maxHealth)
		// AI EDIT: also folds in local_blood_volume (mojave/code/modules/surgery/organs/vessel_local_blood.dm) -
		// a limb can be locally blood-starved (drained faster than it's regenerating) even before its vessel
		// takes enough damage to show up in damage_factor, so this keeps the two in sync instead of only one
		// of them mattering.
		var/local_blood_factor = limb.local_blood_volume / limb.local_blood_volume_max
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
	organs[ORGAN_SLOT_BONE_L_ARM] = /obj/item/organ/bone/l_arm
	organs[ORGAN_SLOT_BONE_R_ARM] = /obj/item/organ/bone/r_arm
	organs[ORGAN_SLOT_BONE_L_LEG] = /obj/item/organ/bone/l_leg
	organs[ORGAN_SLOT_BONE_R_LEG] = /obj/item/organ/bone/r_leg
	organs[ORGAN_SLOT_BONE_CHEST] = /obj/item/organ/bone/chest
	organs[ORGAN_SLOT_BONE_HEAD] = /obj/item/organ/bone/head
	organs[ORGAN_SLOT_MUSCLE_CHEST] = /obj/item/organ/muscle/chest
	organs[ORGAN_SLOT_VESSEL_L_LEG] = /obj/item/organ/vessel/l_leg
	organs[ORGAN_SLOT_VESSEL_R_LEG] = /obj/item/organ/vessel/r_leg
