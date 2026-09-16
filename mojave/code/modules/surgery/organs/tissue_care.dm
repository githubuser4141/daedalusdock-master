// Treatment, natural healing and neglect for the per-limb tissue organs (bone.dm, muscle.dm, vessel.dm).
//
// Tissue damage used to be permanent short of surgery - DD's handle_regeneration() only self-heals below
// 10% of maxHealth. Here it heals on its own, at a rate set by blood supply, nutrition, rest and how
// recently the limb was treated; untreated serious injuries instead get infected, feeding DD's own
// germ_level pipeline (germs_bodypart.dm) so its fever -> spread -> necrosis chain does the deteriorating.
// Destroyed tissue can still come back without a surgeon, but only under good conditions and only
// sometimes. All of it is gated on ms13_tissue, so DD's own organs keep their stock behaviour.

/obj/item/organ
	/// Set on mojave's per-limb tissue organs. Tissue is living structure inside a living limb rather than
	/// a discrete organ sitting in a cavity, which is why it gets its own healing rules (and why the
	/// decay timeout below doesn't apply to it the way it does to a heart).
	var/ms13_tissue = FALSE

/obj/item/bodypart
	/// world.time of the last medical treatment applied to this limb. Drives get_tissue_care_quality() -
	/// treatment goes stale, so care has to be kept up rather than applied once and forgotten.
	var/ms13_treated_at = 0

/// Neglect is scored per LIMB, not per organ - a limb with a smashed bone, a torn muscle and a nicked
/// vessel would otherwise infect three times as fast as one with a single bad injury, purely because more
/// organs were running the check. Hooked on the bodypart's own tick, right where DD runs update_germs().
/obj/item/bodypart/on_life(delta_time, times_fired, stam_heal)
	. = ..()
	if(owner.stat != DEAD)
		ms13_apply_tissue_neglect()

/**
 * ORGAN_RECOVERY_THRESHOLD (10 minutes) models an organ decaying once it's no longer being perfused, which
 * is the right rule for a heart in a cooler and the wrong one for a femur. Without this override a bone
 * broken more than ten minutes ago could never be healed by anything: apply_bone_heal()'s setOrganDamage(0)
 * hits applyOrganDamage()'s `if(damage_amount < 0 && !can_recover()) return`, the damage stays pinned at
 * max, and check_failing_thresholds() then re-asserts the dead flag instead of clearing it. The limb ends
 * up permanently disabled with BP_BROKEN_BONES already cleared, so nothing in-game even reports why.
 *
 * Tissue in a limb that still has blood reaching it hasn't stopped being perfused, so the timeout doesn't
 * apply. Tissue in a limb with no local blood left genuinely is necrotic, and there it still does.
 */
/obj/item/organ/can_recover()
	. = ..()
	if(. || !ms13_tissue)
		return
	if(maxHealth < 0 || !owner || !ownerlimb)
		return
	return ownerlimb.local_blood_volume > 0

/**
 * Surgery is the reliable answer for destroyed tissue, so it has to actually finish the job. DD's
 * surgically_fix() repairs the damage but leaves ORGAN_DEAD set (check_failing_thresholds() only clears
 * that flag when explicitly told to), which for tissue would mean a perfectly repaired bone still reading
 * as zero stability forever. Scoped to tissue so a dead heart still needs peridaxon like it always has.
 */
/obj/item/organ/surgically_fix(mob/user)
	. = ..()
	if(ms13_tissue && !damage)
		check_failing_thresholds(TRUE)

/**
 * DD's base is_causing_pain() (_organ.dm) is `prob(1) && damage >= 5 && !(organ_flags & ORGAN_DEAD)`, so an
 * organ stops hurting the moment it is completely destroyed. That reads correctly for a necrotic liver you
 * genuinely cannot feel, and badly wrong for the structural tissue of a limb you are still standing on - a
 * shattered femur stopped hurting the instant it finished shattering.
 *
 * Destroyed tissue therefore hurts reliably instead. Each organ that passes contributes 65 pain to its limb
 * through handle_pain(), which adjustPain() clamps to that limb's own max_damage - so a wrecked arm tops out
 * around 50 pain and a wrecked leg around 80, rather than stacking without limit.
 */
/obj/item/organ/is_causing_pain()
	if(ms13_tissue && ownerlimb && (organ_flags & ORGAN_DEAD))
		return prob(MS13_TISSUE_DESTROYED_PAIN_CHANCE)
	return ..()

/// Stamp a limb as freshly treated. Called for every medical stack application below; surgery and chems
/// that dress a wound can call it too.
/obj/item/bodypart/proc/ms13_mark_treated()
	ms13_treated_at = world.time

/// Hooked on heal_carbon() rather than each item, so sutures, gauze, ointment, splints, healing powder and
/// poultices all count as care without needing to know this system exists.
/obj/item/stack/medical
	/// Whether applying this counts as cleaning the wound as well as dressing it.
	var/ms13_disinfects = FALSE

/obj/item/stack/medical/heal_carbon(mob/living/carbon/C, mob/user, brute, burn)
	. = ..()
	if(!.)
		return
	var/obj/item/bodypart/affecting = C.get_bodypart(deprecise_zone(user.zone_selected), TRUE)
	if(!affecting)
		return
	affecting.ms13_mark_treated()
	if(ms13_disinfects)
		affecting.disinfect()

/**
 * 0-1ish: how well this limb is currently being looked after. Untreated limbs sit at a floor rather than
 * zero - the body still tries - but that floor is below MS13_TISSUE_CRITICAL_MIN_CARE, so an untended
 * critical injury never recovers on its own no matter how lucky or well-fed the patient is.
 */
/obj/item/bodypart/proc/get_tissue_care_quality()
	. = MS13_TISSUE_CARE_UNTREATED
	if(bandage || splint)
		. = (world.time <= ms13_treated_at + MS13_TISSUE_TREATMENT_DURATION) ? MS13_TISSUE_CARE_FRESH : MS13_TISSUE_CARE_STALE
	// Herbal medicine works from the inside, so it stabilises a limb nobody has dressed - better than
	// nothing, and enough to keep a critical injury's slow recovery alive. Scored as the better of the two
	// rather than either/or: returning early on the dressing meant a STALE dressing (0.65) scored worse
	// than no dressing at all with herbal in the blood (0.7), so pulling a bandage off improved your care.
	if(owner && CHEM_EFFECT_MAGNITUDE(owner, CE_MS13_HERBAL_CARE))
		. = max(., MS13_TISSUE_CARE_HERBAL)

/datum/reagent
	/// Herbal remedies stabilise a wound systemically rather than by being applied to it. Reagents that set
	/// this feed CE_MS13_HERBAL_CARE, which get_tissue_care_quality() above reads.
	var/ms13_herbal_care = FALSE

/// One hook for the whole herbal tier rather than an affect_blood() override on each remedy.
/datum/reagent/affect_blood(mob/living/carbon/C, removed)
	. = ..()
	if(ms13_herbal_care)
		APPLY_CHEM_EFFECT(C, CE_MS13_HERBAL_CARE, 1)

/// Per-organ hook so bone can add its splint bonus. Defaults to whatever the limb scores.
/obj/item/organ/proc/get_tissue_care_quality()
	return ownerlimb ? ownerlimb.get_tissue_care_quality() : MS13_TISSUE_CARE_UNTREATED

/// Bone additionally benefits from being immobilised, which is the whole point of a splint.
/obj/item/organ/bone/get_tissue_care_quality()
	. = ..()
	if(ownerlimb?.splint)
		. += MS13_TISSUE_CARE_SPLINT_BONUS

/// Healing costs food, so how much food there is decides how fast it goes.
/obj/item/organ/proc/get_tissue_nutrition_factor()
	switch(owner.nutrition)
		if(-INFINITY to NUTRITION_LEVEL_STARVING)
			return MS13_TISSUE_HEAL_NUTRITION_STARVING
		if(NUTRITION_LEVEL_STARVING to NUTRITION_LEVEL_HUNGRY)
			return MS13_TISSUE_HEAL_NUTRITION_HUNGRY
		if(NUTRITION_LEVEL_HUNGRY to NUTRITION_LEVEL_WELL_FED)
			return MS13_TISSUE_HEAL_NUTRITION_FED
	return MS13_TISSUE_HEAL_NUTRITION_WELL_FED

/// Bed rest, the oldest treatment there is.
/obj/item/organ/proc/get_tissue_rest_factor()
	if(owner.IsSleeping())
		return MS13_TISSUE_HEAL_REST_SLEEPING
	if(owner.body_position == LYING_DOWN)
		return MS13_TISSUE_HEAL_REST_LYING
	return MS13_TISSUE_HEAL_REST_STANDING

/**
 * The healing curve. Returns TRUE if any progress was made.
 *
 * Destroyed tissue takes the same path but must first clear three gates - blood reaching the limb, real
 * care, food in the tank - and then pass a per-tick roll, so two identically treated patients don't
 * recover on the same schedule and one of them may not recover at all.
 */
/obj/item/organ/proc/ms13_tissue_regeneration()
	if(!owner || !ownerlimb || !damage)
		return
	// Same two blockers DD's own handle_regeneration() applies, which the tissue path would otherwise skip
	// by returning before it: nothing knits while the heart has stopped or while the body is full of toxin.
	// local_blood_volume doesn't fall during asystole, so the blood term below wouldn't catch that on its own.
	if(CHEM_EFFECT_MAGNITUDE(owner, CE_TOXIN) || owner.undergoing_cardiac_arrest())
		return
	// The body is busy fighting the infection. Clear it before anything will knit.
	if(ownerlimb.germ_level >= MS13_TISSUE_HEAL_BLOCKING_GERMS)
		return

	var/blood_ratio = ownerlimb.local_blood_volume / ownerlimb.local_blood_volume_max
	var/care = get_tissue_care_quality()
	var/critical = (organ_flags & ORGAN_DEAD)

	if(critical)
		if(blood_ratio < MS13_TISSUE_CRITICAL_MIN_BLOOD || care < MS13_TISSUE_CRITICAL_MIN_CARE)
			return
		if(owner.nutrition < NUTRITION_LEVEL_FED || !prob(MS13_TISSUE_CRITICAL_HEAL_CHANCE))
			return

	var/rate = MS13_TISSUE_HEAL_BASE * blood_ratio * care * get_tissue_nutrition_factor() * get_tissue_rest_factor()
	if(critical)
		rate *= MS13_TISSUE_CRITICAL_HEAL_MULT
	rate = min(rate, damage)
	if(rate <= 0)
		return

	applyOrganDamage(-rate, updating_health = FALSE)
	owner.adjust_nutrition(-rate * MS13_TISSUE_HEAL_NUTRITION_COST)

	// Lifting the flag is what actually un-breaks the bone / un-severs the artery, via each type's own
	// set_organ_dead(FALSE) override - so it waits until the tissue is genuinely back in usable shape.
	if(critical && damage <= maxHealth * high_threshold)
		check_failing_thresholds(TRUE)
	return TRUE

/**
 * Medicine's entry point into tissue (drugs.dm). Spreads its budget over everything hurt rather than
 * dumping it into one organ. max_ratio is how badly damaged tissue can be and still respond - a normal
 * stimpak only closes light injuries, which is what leaves super stimpaks and surgery a job.
 */
/mob/living/carbon/proc/ms13_heal_tissue(amount, max_ratio = 1, include_critical = FALSE)
	if(amount <= 0)
		return 0
	var/list/obj/item/organ/candidates = list()
	for(var/obj/item/organ/O as anything in organs)
		if(!O.ms13_tissue || !O.damage)
			continue
		if(O.organ_flags & ORGAN_DEAD)
			if(!include_critical || !O.can_recover())
				continue
		else if(O.damage > O.maxHealth * max_ratio)
			continue
		candidates += O
	if(!length(candidates))
		return 0

	var/share = amount / length(candidates)
	. = 0
	for(var/obj/item/organ/O as anything in candidates)
		var/healed = min(share, O.damage)
		O.applyOrganDamage(-healed, updating_health = FALSE)
		if((O.organ_flags & ORGAN_DEAD) && O.damage <= O.maxHealth * O.high_threshold)
			O.check_failing_thresholds(TRUE)
		. += healed

/// A serious injury nobody is treating gets infected. Feeds DD's existing germ_level rather than adding a
/// second deterioration track - that already escalates to fever, spread, and finally BP_NECROTIC plus
/// steady toxin damage, which is the life-or-limb end state. Dressing the limb stops it; disinfecting it
/// (healing powder, poultices) separately removes the open-wound multiplier.
/obj/item/bodypart/proc/ms13_apply_tissue_neglect()
	if(!owner || !IS_ORGANIC_LIMB(src))
		return
	// Dressing or splinting the limb is what stops this, so there's a reason to carry gauze for an injury
	// that isn't actively bleeding.
	if(get_tissue_care_quality() > MS13_TISSUE_CARE_UNTREATED)
		return

	var/worst = 0
	for(var/obj/item/organ/O as anything in contained_organs)
		if(!O.ms13_tissue)
			continue
		worst = max(worst, O.damage / O.maxHealth)
	if(worst < MS13_TISSUE_NEGLECT_DAMAGE_RATIO)
		return

	var/rate = MS13_TISSUE_NEGLECT_GERM_RATE
	if(cached_bleed_rate > 0 && !is_disinfected())
		rate *= MS13_TISSUE_NEGLECT_OPEN_WOUND_MULT
	germ_level += rate
