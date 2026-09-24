// The live half of S.P.E.C.I.A.L. (stats.dm): the game asks get_stat(), which is the attribute scaled by how intact
// the body currently is.
//
// Only strength has condition inputs wired up so far. The others deliberately return a condition of 1 and read as
// their plain value, so they can be filled in the same way later (see get_stat_condition() below).

/// The attribute before any body-condition scaling.
/mob/living/proc/get_base_stat(stat)
	return get_special(stat)

/**
 * 0-1: how well the body can currently deliver this stat. 1 means "as capable as this character gets",
 * lower means injured, bleeding or in too much pain to use what they have.
 *
 * Base implementation returns 1 for everything - a mob with no bodyparts to be hurt in has no condition
 * to lose. /mob/living/carbon/human overrides this per stat below.
 */
/mob/living/proc/get_stat_condition(stat)
	return 1

/// Base stat scaled by current body condition, floored so a stat never reaches zero outright.
/mob/living/proc/get_stat(stat)
	return max(SPECIAL_MINIMUM, get_base_stat(stat) * get_stat_condition(stat))

/// get_stat() expressed as a multiplier around the neutral baseline: 1 at SPECIAL_BASELINE, above 1 for
/// a stronger-than-average character, below for a weaker or badly hurt one. This is what damage and
/// carry-weight maths want, rather than the raw number.
/mob/living/proc/get_stat_ratio(stat)
	return get_stat(stat) / SPECIAL_BASELINE

/mob/living/carbon/human/get_stat_condition(stat)
	switch(stat)
		if(SPECIAL_STRENGTH)
			return get_strength_condition()
	return ..()

/**
 * Strength's three inputs, multiplied:
 * - both arms' muscle performance, which already folds in bone stability and that arm's local blood supply
 *   (get_muscle_performance(), muscle_movement.dm) - so a shattered humerus costs strength without needing
 *   a separate bone term here
 * - whole-body circulation (get_blood_circulation(), which vessel.dm already multiplies its own factor
 *   into) - blood loss makes you weak everywhere, not just in the limb that's bleeding
 * - pain, which is what actually stops a person lifting something they physically still could
 *
 * Each input is floored (MS13_STAT_CONDITION_INPUT_FLOOR) before multiplying: three independent bad-but-
 * survivable values would otherwise compound into effectively zero.
 */
/mob/living/carbon/human/proc/get_strength_condition()
	var/obj/item/bodypart/l_arm = get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/r_arm = get_bodypart(BODY_ZONE_R_ARM)
	// A missing arm contributes nothing rather than counting as a healthy one - losing an arm should cost
	// strength. Both missing and we're down to the floor.
	var/arm_total = (l_arm ? l_arm.get_muscle_performance() : 0) + (r_arm ? r_arm.get_muscle_performance() : 0)
	var/muscle_factor = max(MS13_STAT_CONDITION_INPUT_FLOOR, arm_total / 200)

	// Measured against BLOOD_CIRC_SAFE, not BLOOD_CIRC_FULL: an uninjured human doesn't sit at exactly 100
	// circulation, and dividing by 100 made a perfectly healthy character swing at 99.35% of a weapon's
	// listed damage - which reads as the numbers being broken rather than as being hurt. Anywhere inside
	// the safe band is full strength; strength falls off once circulation is genuinely compromised.
	var/blood_factor = clamp(get_blood_circulation() / BLOOD_CIRC_SAFE, MS13_STAT_CONDITION_INPUT_FLOOR, 1)

	return muscle_factor * blood_factor * get_pain_strength_factor()

/// Pain scales in linearly from no penalty at all up to MS13_STAT_STRONG_PAIN_MULT at the floor stage.
/mob/living/carbon/human/proc/get_pain_strength_factor()
	if(shock_stage <= 0 || HAS_TRAIT(src, TRAIT_NO_PAINSHOCK))
		return 1
	var/severity = min(shock_stage / MS13_STAT_STRONG_PAIN_FLOOR_STAGE, 1)
	return 1 - (severity * (1 - MS13_STAT_STRONG_PAIN_MULT))

/**
 * Multiplier applied to a melee weapon's force, and to unarmed damage (muscle_movement.dm). Only
 * MS13_STAT_STRONG_MELEE_CONTRIBUTION of a swing is strength-dependent - the rest is the weapon itself,
 * so a pipe still hurts when a starving, half-bled-out raider swings it, just much less than it should.
 */
/mob/living/proc/get_melee_strength_mult()
	// In power armor the frame swings, at its own strength, whatever shape its wearer is in.
	var/ratio = HAS_TRAIT(src, TRAIT_IN_POWERARMOUR) ? 1 + get_body_special_offset(SPECIAL_STRENGTH) / SPECIAL_BASELINE : get_stat_ratio(SPECIAL_STRENGTH)
	return (1 - MS13_STAT_STRONG_MELEE_CONTRIBUTION) + (MS13_STAT_STRONG_MELEE_CONTRIBUTION * ratio)
