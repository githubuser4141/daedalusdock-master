// One damageable /obj/item/organ/bone per arm/leg, alongside vessel and muscle. Stability (get_stability(),
// 0-100) multiplies muscle performance (get_muscle_performance(), muscle_movement.dm) rather than adding to
// it - a limb needs a structural baseline before muscle strength matters at all.
// Organ sprites are ported from CEV-Eris (icons/obj/surgery.dmi, AGPL-3.0) into
// mojave/icons/objects/organs/tissue_organs.dmi.

TYPEINFO_DEF(/obj/item/organ/bone)
	default_armor = list(BLUNT = 15, PUNCTURE = 50, SLASH = 50, LASER = 50, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 25, ACID = 25)

/obj/item/organ/bone
	name = "bone"
	desc = "Load-bearing skeletal structure. Best left where it is."
	icon = 'mojave/icons/objects/organs/tissue_organs.dmi'
	icon_state = "ribcage"
	w_class = WEIGHT_CLASS_SMALL
	organ_flags = NONE
	ms13_tissue = TRUE
	maxHealth = MS13_BONE_MAX_HEALTH
	relative_size = MS13_BONE_RELATIVE_SIZE
	external_damage_modifier = MS13_BONE_EXTERNAL_DAMAGE_MODIFIER
	low_threshold_passed = span_info("A dull, deep ache settles into the bone...")
	high_threshold_passed = span_warning("The bone throbs, close to giving out.")
	now_failing = span_userdanger("Something snaps!")
	now_fixed = span_info("The bone finally stops aching.")
	high_threshold_cleared = span_info("The bone stops throbbing.")
	/// Set while DD's break_bones()/heal_bones() bridge is syncing this organ to the limb's own bone state,
	/// so that synthetic damage jump isn't mistaken for a real hit. See applyOrganDamage() below.
	var/bridging_break = FALSE
	bullet_damage_ratio = 1.5

/obj/item/organ/bone/l_arm
	name = "left arm bone"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_BONE_L_ARM
	icon_state = "left_arm"
	relative_size = 40

/obj/item/organ/bone/r_arm
	name = "right arm bone"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_BONE_R_ARM
	icon_state = "right_arm"
	relative_size = 40

/obj/item/organ/bone/l_leg
	name = "left leg bone"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_BONE_L_LEG
	icon_state = "left_leg"
	relative_size = 40

/obj/item/organ/bone/r_leg
	name = "right leg bone"
	zone = BODY_ZONE_R_LEG
	slot = ORGAN_SLOT_BONE_R_LEG
	icon_state = "right_leg"
	relative_size = 40

/obj/item/organ/bone/chest
	name = "ribcage"
	desc = "Ribs and spine. Protects the organs behind them. Best left where it is."
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_BONE_CHEST
	icon_state = "ribcage"
	relative_size = 35

TYPEINFO_DEF(/obj/item/organ/bone/head)
	default_armor = list(BLUNT = 15, PUNCTURE = 75, SLASH = 50, LASER = 50, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 25, ACID = 25)

/obj/item/organ/bone/head
	name = "skull"
	desc = "Protects the brain. Best left where it is."
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_BONE_HEAD
	icon_state = "skull"
	external_damage_modifier = MS13_BONE_SKULL_EXTERNAL_DAMAGE_MODIFIER
	relative_size = 100
	bullet_damage_ratio = 2

/// 0-100, own damage ratio. Always 0 once destroyed (broken).
/obj/item/organ/bone/proc/get_stability()
	if(organ_flags & ORGAN_DEAD)
		return 0
	return round(100 * (1 - damage / maxHealth), 0.1)

/obj/item/bodypart/proc/get_bone_organ()
	return locate(/obj/item/organ/bone) in contained_organs

/// Bodypart-level lookup, same pattern as get_muscle_performance() (muscle_movement.dm) - 100 (no-op) if this
/// limb has no bone organ installed.
/obj/item/bodypart/proc/get_bone_stability()
	var/obj/item/organ/bone/B = get_bone_organ()
	if(!B)
		return 100
	return B.get_stability()

/// Multiplies the liver's real blood regen (owner.adjustBloodVolumeUpTo() in liver.dm's on_life()) - 1 by
/// default for anyone without bones.
/mob/living/carbon/proc/get_blood_regen_multiplier()
	return 1

/// Averaged across bone-bearing limbs - broken bones are systemic (marrow), not one limb tanking the whole
/// body's regen.
/mob/living/carbon/human/get_blood_regen_multiplier()
	var/total = 0
	var/count = 0
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		var/obj/item/organ/bone/B = BP.get_bone_organ()
		if(!B)
			continue
		total += B.get_stability()
		count++
	if(!count)
		return 1
	return (total / count) / 100

/// Fragmenting is a per-hit event, not a tick effect - hooked on the damage-application proc itself.
/// bridging_break is set while DD's own break_bones() is driving this organ to full damage (see
/// apply_bone_break() in code/modules/surgery/bodyparts/injuries.dm): that single synthetic 0 -> maxHealth
/// jump isn't a real hit, and letting it fragment meant every engine-side break also dumped the maximum
/// four fragments into the muscle and vessel sharing the limb, on top of the break's own effects.
/obj/item/organ/bone/applyOrganDamage(damage_amount, maximum = maxHealth, silent, updating_health = TRUE, cause_of_death = "Organ failure")
	. = ..()
	if(. > 0 && !bridging_break)
		try_fragment(.)
	if(ownerlimb)
		ownerlimb.refresh_muscle_effects()

/// Sends a few chunks of bone into whatever else shares this limb. Scales with how hard THIS hit was, not
/// cumulative damage - a single solid hit chips fragments loose, a string of small ones doesn't.
/obj/item/organ/bone/proc/try_fragment(hit_damage)
	if(hit_damage < MS13_BONE_FRAGMENT_MIN_DAMAGE || !ownerlimb)
		return
	var/fragment_count = min(MS13_BONE_FRAGMENT_MAX_COUNT, round((hit_damage - MS13_BONE_FRAGMENT_MIN_DAMAGE) * MS13_BONE_FRAGMENT_PER_DAMAGE) + 1)
	var/list/neighbors = ownerlimb.contained_organs - src
	if(!length(neighbors))
		return
	for(var/i in 1 to fragment_count)
		if(!prob(MS13_BONE_FRAGMENT_CHANCE))
			continue
		var/obj/item/organ/victim = pick(neighbors)
		victim.applyOrganDamage(MS13_BONE_FRAGMENT_DAMAGE)
		ms13_medical_debug(owner, "Bone fragment hit [victim.name] for [MS13_BONE_FRAGMENT_DAMAGE]")

/**
 * A break is self-contained - local blood loss only (see apply_organ_bleed(), vessel_local_blood.dm), not a
 * life-threatening open bleed. Also stops propping up local blood regen and muscle performance (see
 * get_bone_stability()/get_muscle_performance() callers) until it's healed.
 *
 * Also bridges to DD's own real break_bones()/heal_bones() (bodypart_flags & BP_BROKEN_BONES,
 * code/modules/surgery/bodyparts/injuries.dm) - the reverse bridge is apply_bone_break()/apply_bone_heal()
 * below. Without this, this organ's stability and DD's own limp/splint/interaction-speed break state could
 * silently disagree. NOTE: two independently-tuned break systems now trigger each other - worth revisiting
 * if breaks end up feeling too frequent/rare or double up oddly.
 */
/obj/item/organ/bone/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!.)
		return
	if(failing && ownerlimb)
		ownerlimb.apply_organ_bleed(MS13_BONE_BREAK_LOCAL_BLEED)
		if(owner)
			to_chat(owner, span_userdanger("Something snaps in your [ownerlimb.plaintext_zone]!"))
		ownerlimb.break_bones(painful = FALSE) // painful=FALSE: applyOrganDamage() already applied pain for this hit
	else if(ownerlimb)
		ownerlimb.heal_bones()
	if(ownerlimb)
		ownerlimb.refresh_muscle_effects()

// apply_bone_break()/apply_bone_heal() bridge lives directly in code/modules/surgery/bodyparts/injuries.dm
// (the real proc bodies) - NOT redeclared here. Those are declared straight on /obj/item/bodypart with
// SHOULD_CALL_PARENT, so a second /obj/item/bodypart/apply_bone_break() in this file would silently replace
// the original body outright instead of layering (same DM redeclaration trap noted elsewhere this session).

/obj/item/organ/bone/Insert(mob/living/carbon/reciever, special = FALSE, drop_if_replaced = TRUE)
	. = ..()
	update_strength_density()
	if(ownerlimb)
		ownerlimb.refresh_muscle_effects()

/obj/item/organ/bone/Remove(mob/living/carbon/organ_owner, special = FALSE)
	var/obj/item/bodypart/limb = ownerlimb
	. = ..()
	if(limb)
		limb.refresh_muscle_effects()

/// Bone is the harder, deeper layer - registered after muscle in GLOB.natural_armor_layers (natural_armor.dm)
/// so muscle absorbs first and bone gets whatever's left, matching real anatomy (skin/muscle over bone).
/datum/natural_armor_layer/bone
	gone_fraction = MS13_BONE_ARMOR_GONE_FRACTION
	absorb_fraction = MS13_BONE_ARMOR_ABSORB_FRACTION

/// Below MS13_BONE_ARMOR_MIN_DAMAGE, the hit is too weak to so much as scratch the bone - so the bone stops
/// it cold instead of the normal gone/absorbed/passthrough split, and it doesn't even register as organ damage.
/datum/natural_armor_layer/bone/absorb(mob/living/carbon/human/H, damage_amount, damagetype, def_zone)
	if(damage_amount < MS13_BONE_ARMOR_MIN_DAMAGE)
		return 0
	return ..()

/datum/natural_armor_layer/bone/get_organ(mob/living/carbon/human/H, obj/item/bodypart/hit_part, damagetype)
	if(damagetype != BRUTE)
		return null
	return hit_part.get_bone_organ()

/// Dragging someone over the ground (drag_damage() only runs for a grabbed, unbuckled body lying on a turf) can
/// tear off an arm or leg that is already broken and mangled almost to nothing.
/mob/living/carbon/human/drag_damage(turf/new_loc, turf/old_loc, direction)
	. = ..()
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		if(!(limb.body_zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
			continue
		if(!(limb.bodypart_flags & BP_BROKEN_BONES) || limb.get_damage() < limb.max_damage * MS13_DRAG_DISMEMBER_DAMAGE)
			continue
		if(!prob(MS13_DRAG_DISMEMBER_CHANCE))
			continue
		var/limb_name = limb.plaintext_zone
		if(limb.dismember(DROPLIMB_BLUNT, silent = TRUE))
			visible_message(
				span_danger("[src]'s mangled [limb_name] tears away as [p_theyre()] dragged across the ground!"),
				span_userdanger("Your mangled [limb_name] tears away as you're dragged across the ground!"),
			)
			return
