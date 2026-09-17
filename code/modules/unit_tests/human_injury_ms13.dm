/// A nearby blast injures the eyes and brain; only a close one reaches the lungs.
/datum/unit_test/ms13_blast_injury/Run()
	var/mob/living/carbon/human/consistent/far = ALLOCATE_BOTTOM_LEFT()
	var/mob/living/carbon/human/consistent/near = ALLOCATE_BOTTOM_LEFT()
	far.ex_act(EXPLODE_LIGHT)
	TEST_ASSERT_EQUAL(far.getorganslot(ORGAN_SLOT_LUNGS)?.damage, 0, "A distant blast hurt the lungs.")
	near.ex_act(EXPLODE_HEAVY)
	TEST_ASSERT(near.getorganslot(ORGAN_SLOT_LUNGS)?.damage > 0, "A close blast left the lungs untouched.")
	TEST_ASSERT(near.getorganslot(ORGAN_SLOT_BRAIN)?.damage > 0, "A close blast left the brain untouched.")
	TEST_ASSERT(near.getorganslot(ORGAN_SLOT_EYES)?.damage > 0, "A close blast left the eyes untouched.")

/// Limbs show MS13 wound sprites as they're hurt, and the body grows vermin once it's far gone.
/datum/unit_test/ms13_damage_overlays/Run()
	var/mob/living/carbon/human/consistent/victim = ALLOCATE_BOTTOM_LEFT()
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	victim.apply_damage(chest.max_damage * 0.5, BRUTE, chest)
	var/tier = chest.ms13_damage_tier()
	TEST_ASSERT(tier > 0, "A badly hurt chest counted as unhurt ([chest.get_damage()]/[chest.max_damage]).")
	TEST_ASSERT(has_damage_overlay(victim, "chest_damage[tier]"), "A hurt chest didn't show chest_damage[tier].")
	TEST_ASSERT(!has_damage_overlay(victim, "vermin"), "A fresh body showed vermin.")
	victim.rotting = 2
	victim.update_damage_overlays()
	TEST_ASSERT(has_damage_overlay(victim, "vermin"), "A far-gone body showed no vermin.")
	TEST_ASSERT(has_damage_overlay(victim, "head_rot2"), "A far-gone body's head didn't rot.")

/datum/unit_test/ms13_damage_overlays/proc/has_damage_overlay(mob/living/carbon/human/victim, state)
	for(var/image/overlay in victim.overlays_standing[DAMAGE_LAYER])
		if(overlay.icon_state == state)
			return TRUE
	return FALSE
