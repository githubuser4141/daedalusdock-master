/**
 * Covers the rules the tissue system (mojave/code/modules/surgery/organs/tissue_care.dm) is built on, and
 * the two dead-ends it exists to fix. Numeric thresholds are asserted as relative comparisons rather than
 * against the MS13_* defines: those live in mojave/, which daedalus.dme loads after all of code/, so they
 * aren't visible from a test file here.
 */
/datum/unit_test/ms13_tissue_care
	name = "TISSUE: Healing, Neglect And Strength"

/datum/unit_test/ms13_tissue_care/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = subject.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm, "Test subject has no left arm.")

	var/obj/item/organ/muscle/muscle = locate() in arm.contained_organs
	TEST_ASSERT(muscle, "Left arm has no muscle organ - the species organ list is not being applied.")
	TEST_ASSERT(muscle.ms13_tissue, "Muscle is not flagged as tissue, so none of the tissue rules apply to it.")

	subject.set_nutrition(NUTRITION_LEVEL_WELL_FED)
	arm.local_blood_volume = arm.local_blood_volume_max

	// A dressed, fed, well-perfused limb heals real damage. DD's stock rule only ever healed under 10% of
	// maxHealth, which left every injury that mattered permanent until a surgeon showed up.
	var/obj/item/stack/medical/gauze/ms13/gauze = allocate(/obj/item/stack/medical/gauze/ms13)
	arm.apply_bandage(gauze)
	TEST_ASSERT(arm.bandage, "Bandage failed to apply, so care quality can't be tested.")
	arm.ms13_mark_treated()

	muscle.setOrganDamage(muscle.maxHealth * 0.5)
	var/damage_before = muscle.damage
	muscle.ms13_tissue_regeneration()
	TEST_ASSERT(muscle.damage < damage_before, "Well-fed, bandaged, well-perfused tissue did not heal at all ([damage_before] -> [muscle.damage]).")

	// An infected limb stops healing until the infection is dealt with.
	arm.germ_level = INFECTION_LEVEL_TWO
	damage_before = muscle.damage
	muscle.ms13_tissue_regeneration()
	TEST_ASSERT_EQUAL(muscle.damage, damage_before, "Tissue healed while the limb was infected past INFECTION_LEVEL_TWO.")
	arm.germ_level = 0

	// Destroyed tissue in a limb that still has blood reaching it stays salvageable past
	// ORGAN_RECOVERY_THRESHOLD. Without this, any bone break older than ten minutes became permanently
	// unhealable - heal_bones() cleared BP_BROKEN_BONES but the organ stayed dead and the limb stayed
	// disabled forever, with nothing in game reporting why.
	muscle.setOrganDamage(muscle.maxHealth)
	TEST_ASSERT(muscle.organ_flags & ORGAN_DEAD, "Tissue at full damage did not register as destroyed.")
	muscle.time_of_death = world.time - (ORGAN_RECOVERY_THRESHOLD + 1 MINUTES)
	TEST_ASSERT(muscle.can_recover(), "Destroyed tissue in a perfused limb went permanently unrecoverable after the decay timeout.")

	// A limb with no blood left in it genuinely is necrotic, so there the timeout still applies.
	arm.local_blood_volume = 0
	TEST_ASSERT(!muscle.can_recover(), "Destroyed tissue in a limb with no blood supply should still time out.")
	arm.local_blood_volume = arm.local_blood_volume_max

	// Surgery has to actually finish the job: surgically_fix() repairs the damage, and for tissue it must
	// also lift ORGAN_DEAD, or a perfectly repaired bone reads as zero stability forever.
	muscle.surgically_fix(subject)
	TEST_ASSERT(!(muscle.organ_flags & ORGAN_DEAD), "Surgically repaired tissue is undamaged but still flagged as destroyed.")

	// Neglect: a serious injury nobody is treating starts to turn, feeding DD's own germ pipeline.
	var/obj/item/removed_bandage = arm.remove_bandage()
	if(removed_bandage)
		qdel(removed_bandage)
	TEST_ASSERT(!arm.bandage, "Bandage did not come off, so neglect can't be tested.")
	muscle.setOrganDamage(muscle.maxHealth * 0.8)
	arm.germ_level = 0
	arm.ms13_apply_tissue_neglect()
	TEST_ASSERT(arm.germ_level > 0, "A serious untreated tissue injury did not start to infect.")

	// A treated limb does not.
	arm.apply_bandage(allocate(/obj/item/stack/medical/gauze/ms13))
	arm.ms13_mark_treated()
	arm.germ_level = 0
	arm.ms13_apply_tissue_neglect()
	TEST_ASSERT_EQUAL(arm.germ_level, 0, "A freshly dressed injury still accrued infection.")

/**
 * Two rules that are easy to regress silently, because both fail by simply never happening.
 */
/datum/unit_test/ms13_tissue_pain_and_care
	name = "TISSUE: Destroyed Tissue Hurts, Herbal Care Stabilises"

/datum/unit_test/ms13_tissue_pain_and_care/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)

	// A completely destroyed bone has to keep hurting. DD's base is_causing_pain() excludes ORGAN_DEAD
	// outright, so before this a limb stopped hurting at the exact moment it finished being ruined.
	var/obj/item/bodypart/leg = subject.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(leg, "Test subject has no left leg.")
	var/obj/item/organ/bone/bone = leg.get_bone_organ()
	TEST_ASSERT(bone, "Left leg has no bone organ.")

	bone.setOrganDamage(bone.maxHealth)
	TEST_ASSERT(bone.organ_flags & ORGAN_DEAD, "Bone at full damage did not register as destroyed.")

	var/registered_pain = FALSE
	for(var/i in 1 to 200)
		if(bone.is_causing_pain())
			registered_pain = TRUE
			break
	TEST_ASSERT(registered_pain, "Destroyed tissue never registered as causing pain across 200 rolls.")

	// Herbal medicine stabilises a limb nobody has dressed - the drinkable and smokeable half of the tribal
	// tier, which could not count as care at all before. Literal chem key rather than CE_MS13_HERBAL_CARE:
	// that define lives in mojave/, which loads after code/ and isn't visible from a test file here.
	var/obj/item/bodypart/arm = subject.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm, "Test subject has no left arm.")
	TEST_ASSERT(!arm.bandage && !arm.splint, "Test subject's left arm is unexpectedly already dressed.")

	var/untreated = arm.get_tissue_care_quality()
	APPLY_CHEM_EFFECT(subject, "ms13_herbal_care", 1)
	var/herbal = arm.get_tissue_care_quality()
	TEST_ASSERT(herbal > untreated, "Herbal medicine did not improve care on an undressed limb ([untreated] -> [herbal]).")

/**
 * Strength (mojave/code/modules/stats/stat_condition.dm) has to actually fall when the body is wrecked,
 * and it has to reach weapons and not only fists - item melee previously ignored the attacker's condition
 * completely.
 */
/datum/unit_test/ms13_strength_condition
	name = "TISSUE: Strength Scales With Condition"

/datum/unit_test/ms13_strength_condition/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)

	// Must be a clean 1, not merely close: an uninjured human doesn't sit at exactly BLOOD_CIRC_FULL, so
	// scoring circulation against 100 quietly shaved every weapon in the game down to 99.35% of its listed
	// damage. Caught originally as novaflower_burn dealing 14.9 instead of 15.
	var/healthy = subject.get_melee_strength_mult()
	TEST_ASSERT(healthy >= 0.999, "An uninjured human swings at [healthy] of normal strength; should be exactly 1.")

	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		var/obj/item/bodypart/arm = subject.get_bodypart(zone)
		TEST_ASSERT(arm, "Test subject has no [zone].")
		var/obj/item/organ/muscle/muscle = locate() in arm.contained_organs
		TEST_ASSERT(muscle, "[zone] has no muscle organ.")
		muscle.setOrganDamage(muscle.maxHealth)

	var/mangled = subject.get_melee_strength_mult()
	TEST_ASSERT(mangled < healthy, "Destroying both arms' muscle did not reduce melee strength ([healthy] -> [mangled]).")
	TEST_ASSERT(mangled > 0, "Melee strength bottomed out at zero; a weapon should always land for something.")
