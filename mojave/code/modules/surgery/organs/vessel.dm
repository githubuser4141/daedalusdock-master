// The beginning of a basic blood vessel system: a physical, damageable object living in each limb
// instead of DD's plain BP_ARTERY_CUT boolean (code/modules/surgery/bodyparts/injuries.dm). Built as
// a regular /obj/item/organ subtype so it gets DD's real organ plumbing for free - it's automatically
// hit by damage_internal_organs() (code/modules/surgery/bodyparts/_bodyparts.dm) whenever its limb
// takes a hard enough hit, can be examined/scanned/operated on like any other organ, and shows up in
// pain.dm's internal-organ-pain loop.
//
// Deliberately scoped down from a full circulatory network: no cross-limb adjacency graph (nothing in
// DD encodes which bodypart "feeds" which, and building that plus a real localized-blood-supply
// consequence system is a much bigger project than "the beginning of a system"). Each vessel is
// self-contained to its own limb. When one ruptures (destroyed) it severs that limb's artery via DD's
// own set_sever_artery(), which is already wired into examine text, health analyzer scans, bleed rate,
// and the fix_vein surgery step - so this slots into machinery that already exists rather than adding
// a second, parallel bleed source. Rupturing scales with damage now instead of DD's binary "did a wound
// roll succeed" chance, and it's a real target players can look at, hit, and surgically repair.
//
// icon_state "fixovein" is a placeholder - it's the existing fix_vein surgery tool sprite, reused here
// because it's the closest thing to a vessel already in icons/obj/surgery.dmi. Swap for real art later.

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

/// Rupture (or repair) the parent limb's artery to match whether this vessel just died or was fixed.
/obj/item/organ/vessel/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!. || !ownerlimb)
		return
	ownerlimb.set_sever_artery(failing)

/obj/item/organ/vessel/head
	name = "carotid artery"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_VESSEL_HEAD

/obj/item/organ/vessel/chest
	name = "aorta"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_VESSEL_CHEST

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
 * Every human gets one vessel organ per limb, same as DD's own baseline organs
 * (/datum/species/var/organs, code/modules/mob/living/carbon/human/species.dm).
 * Not editing that list directly - this appends to it after the real one is built.
 */
/datum/species/New()
	. = ..()
	organs[ORGAN_SLOT_VESSEL_HEAD] = /obj/item/organ/vessel/head
	organs[ORGAN_SLOT_VESSEL_CHEST] = /obj/item/organ/vessel/chest
	organs[ORGAN_SLOT_VESSEL_L_ARM] = /obj/item/organ/vessel/l_arm
	organs[ORGAN_SLOT_VESSEL_R_ARM] = /obj/item/organ/vessel/r_arm
	organs[ORGAN_SLOT_VESSEL_L_LEG] = /obj/item/organ/vessel/l_leg
	organs[ORGAN_SLOT_VESSEL_R_LEG] = /obj/item/organ/vessel/r_leg
