/**
 * The blast wave hurts what's inside, not just the skin. Anywhere in the blast it rattles the ears, eyes and
 * brain; closer in, it tears the lungs. Bomb armor on the head or chest blunts it.
 *
 * Doesn't rely on the parent's return value: the base ex_act() chain returns nothing, which the core human
 * ex_act() reads as "blocked" and so skips all of its own damage.
 */
/mob/living/carbon/human/ex_act(severity, target, origin)
	. = ..()
	if(QDELETED(src) || severity < EXPLODE_LIGHT || (TRAIT_BOMBIMMUNE in dna.species.species_traits))
		return
	var/head_shielding = 1 - clamp(getarmor(get_bodypart(BODY_ZONE_HEAD), BOMB), 0, 100) / 100
	var/chest_shielding = 1 - clamp(getarmor(get_bodypart(BODY_ZONE_CHEST), BOMB), 0, 100) / 100
	var/obj/item/organ/ears/ears = getorganslot(ORGAN_SLOT_EARS)
	var/obj/item/organ/eyes = getorganslot(ORGAN_SLOT_EYES)
	var/obj/item/organ/brain = getorganslot(ORGAN_SLOT_BRAIN)
	var/obj/item/organ/lungs = getorganslot(ORGAN_SLOT_LUNGS)
	var/ear_protection = HAS_TRAIT_FROM(src, TRAIT_DEAF, CLOTHING_TRAIT) ? 0 : 1
	switch(severity)
		if(EXPLODE_LIGHT)
			ears?.adjustEarDamage(rand(10, 20) * head_shielding * ear_protection, 60 * ear_protection)
			eyes?.applyOrganDamage(rand(0, 5) * head_shielding)
			brain?.applyOrganDamage(rand(0, 4) * head_shielding)
		if(EXPLODE_HEAVY)
			ears?.adjustEarDamage(rand(15, 30) * head_shielding * ear_protection, 120 * ear_protection)
			eyes?.applyOrganDamage(rand(3, 10) * head_shielding)
			brain?.applyOrganDamage(rand(4, 10) * head_shielding)
			lungs?.applyOrganDamage(rand(5, 15) * chest_shielding)
		if(EXPLODE_DEVASTATE)
			ears?.adjustEarDamage(rand(30, 50) * head_shielding * ear_protection, 120 * ear_protection)
			eyes?.applyOrganDamage(rand(10, 20) * head_shielding)
			brain?.applyOrganDamage(rand(10, 20) * head_shielding)
			lungs?.applyOrganDamage(rand(15, 30) * chest_shielding)
