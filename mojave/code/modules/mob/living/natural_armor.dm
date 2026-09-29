// A brute hit works its way into a limb outside in: the limb's own skin and flesh, then its muscle, then its bone,
// which stops whatever gets down to it. Each layer stops a share of what reaches it - its armor against that kind of
// hit (BLUNT for a blow, SLASH for a blade, PUNCTURE for a stab), less the more it's already hurt, set against what's
// left of the hit - and lets the rest go deeper. A weak hit is mostly spent on the skin; a strong one gets down to the
// bone. Of what muscle or bone stops, MS13_BULLET_ORGAN_SHARE is that tissue's own damage, the same as a bullet
// (bullet_penetration.dm); the rest, with everything the skin stops, is the limb's wound. Nothing is added or lost:
// the limb and its tissue share the hit. Called after external armor, from apply_damage() (damage_procs.dm).

/// Base stub - safe no-op for any mob without tissue layers.
/mob/living/proc/apply_natural_armor_layers(damage_amount, damagetype, def_zone, sharpness)
	return damage_amount

/// Returns the share of the hit left for the limb's own wound.
/mob/living/carbon/human/apply_natural_armor_layers(damage_amount, damagetype, def_zone, sharpness)
	// Bullets already split their damage between tissue and limb (bullet_penetration.dm).
	if(resolving_bullet_hit || damagetype != BRUTE || damage_amount <= 0)
		return damage_amount
	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : get_bodypart(deprecise_zone(def_zone))
	if(!hit_part)
		return damage_amount
	var/armor_type = (sharpness & (SHARP_POINTY|SHARP_IMPALING)) ? PUNCTURE : (sharpness & SHARP_EDGED) ? SLASH : BLUNT
	var/reaching = damage_amount * (1 - ms13_depth_share(hit_part.soft_tissue_armor, damage_amount))
	var/to_tissue = 0
	for(var/obj/item/organ/layer as anything in list(locate(/obj/item/organ/muscle) in hit_part.contained_organs, hit_part.get_bone_organ()))
		if(!layer || (layer.organ_flags & ORGAN_DEAD) || reaching <= 0)
			continue
		// Bone is the backstop: it stops whatever gets down to it.
		var/stopped = istype(layer, /obj/item/organ/bone) ? reaching : reaching * ms13_depth_share(layer.get_depth_stopping(armor_type), reaching)
		reaching -= stopped
		var/tissue_damage = stopped * MS13_BULLET_ORGAN_SHARE
		layer.applyOrganDamage(tissue_damage, updating_health = FALSE)
		to_tissue += tissue_damage
		ms13_medical_debug(src, "[layer.name] stopped [round(stopped, 0.1)] of the hit, taking [round(tissue_damage, 0.1)]")
	return damage_amount - to_tissue

/// Of what reaches a layer, the share it stops: its stopping power against what's left of the hit.
/proc/ms13_depth_share(stopping, remaining)
	return stopping > 0 ? stopping / (stopping + remaining) : 0

/// How much of a hit this tissue stops: its armor against that kind of hit, denser with Strength (muscle.dm), and
/// less the more it's already been hurt.
/obj/item/organ/proc/get_depth_stopping(armor_type)
	var/datum/armor/armor = returnArmor()
	return (armor ? armor.getRating(armor_type) : 0) * get_strength_density() * (1 - damage / maxHealth)

#ifdef UNIT_TESTS
/// A hit is spent from the skin inward: a scratch stays in the skin, a heavy blow reaches the bone, and the limb and
/// its tissue together take exactly the hit.
/datum/unit_test/ms13_tissue_depth
	name = "TISSUE: Hits Work In From The Skin To The Bone"

/datum/unit_test/ms13_tissue_depth/Run()
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = subject.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/organ/muscle/muscle = locate() in arm.contained_organs
	var/obj/item/organ/bone/bone = arm.get_bone_organ()

	var/to_limb = subject.apply_natural_armor_layers(2, BRUTE, arm, SHARP_EDGED)
	if(to_limb < 1.5 || bone.damage > 0.05)
		Fail("A scratch went past the skin: [to_limb] of 2 to the limb, [bone.damage] to the bone.")
	if(abs(to_limb + muscle.damage + bone.damage - 2) > 0.15)
		Fail("A scratch's damage didn't add up: [to_limb] limb, [muscle.damage] muscle, [bone.damage] bone, of 2.")

	muscle.setOrganDamage(0)
	bone.setOrganDamage(0)
	to_limb = subject.apply_natural_armor_layers(40, BRUTE, arm, NONE)
	if(bone.damage < 5 || to_limb < 20)
		Fail("A heavy blow didn't reach the bone and leave most of itself on the limb: [to_limb] limb, [bone.damage] bone.")
	if(abs(to_limb + muscle.damage + bone.damage - 40) > 0.15)
		Fail("A heavy blow's damage didn't add up: [to_limb] limb, [muscle.damage] muscle, [bone.damage] bone, of 40.")
#endif
