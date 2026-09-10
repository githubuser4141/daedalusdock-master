// Local (per-bodypart) blood volume, layered on top of mojave/code/modules/surgery/organs/vessel.dm's
// vessels and DD's own real global blood_volume/bleed_rate system - none of that is being replaced.
//
// The split: local_blood_volume is how much blood is currently available to a SPECIFIC limb (organs live
// in a specific bodypart, per vessel.dm's header comment). A damaged vessel drains its own limb's local
// supply directly, AND simultaneously bleeds some of that out of the body entirely via DD's real bleed()
// proc (code/modules/mob/living/blood.dm) - the same proc DD's own bleed_rate system already uses, reused
// here rather than inventing a second global blood-loss pathway. A ruptured vessel already causes the
// existing flat +4 bleed_rate through BP_ARTERY_CUT (see vessel.dm's set_organ_dead() override) - this adds
// a smaller, damage-scaled drain on TOP of that for the merely-damaged-but-not-yet-ruptured case, which
// previously did nothing at all between "healthy" and "ruptured."
//
// A healthy limb slowly refills its own local supply by pulling a little global blood_volume back in - so
// local and global aren't independent currencies, local is drawn down by damage and topped back up from
// global, same as real circulation. get_vessel_circulation_factor() (vessel.dm) reads local_blood_volume
// per limb, so a locally blood-starved limb drags down whole-body circulation the same way a damaged
// vessel does, even before it's damaged enough on its own to matter.

/obj/item/bodypart
	/// How much blood is currently available to this specific limb - drained by its own vessel's damage,
	/// refilled from the mob's global blood_volume while the vessel is healthy. See vessel_local_blood.dm.
	/// Defaults to the generic fallback size - chest/head/arm/leg override both vars below to their own size.
	var/local_blood_volume = MS13_LOCAL_BLOOD_MAX
	var/local_blood_volume_max = MS13_LOCAL_BLOOD_MAX
	/// Sharpness of the most recent hit to reach this limb - DD's own damage_internal_organs() (code/modules/
	/// surgery/bodyparts/_bodyparts.dm) receives sharpness but never passes it to the organ it damages, so
	/// there's no way for a vessel to know what actually hit it without capturing it here first.
	var/last_damage_sharpness = NONE

/// See last_damage_sharpness above.
/obj/item/bodypart/receive_damage(brute = 0, burn = 0, blocked = 0, updating_health = TRUE, required_status = null, sharpness = NONE, modifiers = DEFAULT_DAMAGE_FLAGS, obj/item/weapon_used = null)
	if(brute || burn)
		last_damage_sharpness = sharpness
	return ..()

/// Per-zone local blood pool sizes - the chest (torso, holding most of the body's actual blood supply)
/// dwarfs a single limb, matching real distribution far better than one flat number for every zone.
/obj/item/bodypart/chest
	local_blood_volume = MS13_LOCAL_BLOOD_CHEST
	local_blood_volume_max = MS13_LOCAL_BLOOD_CHEST

/obj/item/bodypart/head
	local_blood_volume = MS13_LOCAL_BLOOD_HEAD
	local_blood_volume_max = MS13_LOCAL_BLOOD_HEAD

/obj/item/bodypart/arm
	local_blood_volume = MS13_LOCAL_BLOOD_ARM
	local_blood_volume_max = MS13_LOCAL_BLOOD_ARM

/obj/item/bodypart/leg
	local_blood_volume = MS13_LOCAL_BLOOD_LEG
	local_blood_volume_max = MS13_LOCAL_BLOOD_LEG

/**
 * Every tick: a damaged (but not yet ruptured - that's handled separately by set_organ_dead()) vessel bleeds
 * into two places at once, same amount of damage driving both:
 * - locally, straight out of this limb's own local_blood_volume
 * - globally, via the real bleed() proc, same as DD's own bleed_rate system already does for a fully severed
 *   artery, just scaled down and continuous instead of a flat rate that only kicks in at full rupture
 * A healthy vessel instead slowly pulls a little blood back in from the global pool, capped so it won't
 * drain a body that's already blood-starved just to top off one limb.
 */
/obj/item/organ/vessel/on_life(delta_time, times_fired)
	. = ..()
	if(!ownerlimb || !owner)
		return

	if(ownerlimb.local_blood_volume <= 0)
		starve_organs(delta_time)

	if(damage > 0)
		// AI EDIT: internal (pools in the limb, local_blood_volume) vs external (leaves the body via
		// bleed(), which already handles floor splatter - see code/modules/mob/living/blood.dm) - the split
		// isn't fixed, it shifts with what actually caused the damage: an open/sharp wound bleeds out
		// visibly, blunt trauma mostly pools internally with no path out.
		var/sharp_wound = ownerlimb.last_damage_sharpness & (SHARP_EDGED|SHARP_POINTY|SHARP_IMPALING)
		var/internal_mult = sharp_wound ? MS13_BLEED_RATIO_SHARP_INTERNAL_MULT : MS13_BLEED_RATIO_BLUNT_INTERNAL_MULT
		var/external_mult = sharp_wound ? MS13_BLEED_RATIO_SHARP_EXTERNAL_MULT : MS13_BLEED_RATIO_BLUNT_EXTERNAL_MULT

		var/local_loss = damage * MS13_VESSEL_BLEED_LOCAL_PER_DAMAGE * internal_mult * delta_time
		ownerlimb.local_blood_volume = max(0, ownerlimb.local_blood_volume - local_loss)

		var/global_loss = damage * MS13_VESSEL_BLEED_GLOBAL_PER_DAMAGE * external_mult * delta_time
		owner.bleed(global_loss)
		ms13_medical_debug(owner, "Vessel [name] bleeding: local -[round(local_loss, 0.1)] (now [round(ownerlimb.local_blood_volume, 0.1)]/[ownerlimb.local_blood_volume_max]), global -[round(global_loss, 0.1)]")
		return

	if(ownerlimb.local_blood_volume >= ownerlimb.local_blood_volume_max)
		return
	if(owner.blood_volume <= MS13_LOCAL_BLOOD_REGEN_FLOOR)
		return

	var/regen = min(MS13_LOCAL_BLOOD_REGEN * delta_time, ownerlimb.local_blood_volume_max - ownerlimb.local_blood_volume)
	ownerlimb.local_blood_volume += regen
	owner.adjustBloodVolume(-regen)
	ms13_medical_debug(owner, "Vessel [name] local blood regen: +[round(regen, 0.1)] (now [round(ownerlimb.local_blood_volume, 0.1)]/[ownerlimb.local_blood_volume_max])")

/**
 * "organs need blood values" - a limb with zero local blood isn't just failing to heal its own vessel
 * (handle_regeneration() below already covers that generally), the other organs living in it are being
 * starved outright. Everything else in ownerlimb.contained_organs takes slow ischemic damage while this
 * lasts - the heart/lungs/liver/stomach for a starved chest, the brain/eyes for a starved head.
 *
 * Gated on two things at once: how damaged THIS vessel currently is (worse vessel damage -> organs are
 * allowed to be brought further down), and a hard MS13_ISCHEMIA_DAMAGE_CAP ceiling regardless of vessel
 * severity or how long the starvation lasts - ischemia alone should never be a death sentence on its own,
 * just a real cost, with actual failure reserved for direct injury (a fully ruptured/destroyed organ).
 */
/obj/item/organ/vessel/proc/starve_organs(delta_time)
	var/vessel_severity = damage / maxHealth
	for(var/obj/item/organ/O in ownerlimb.contained_organs)
		if(O == src || (O.organ_flags & ORGAN_SYNTHETIC))
			continue
		var/ceiling = O.maxHealth * MS13_ISCHEMIA_DAMAGE_CAP * vessel_severity
		if(O.damage >= ceiling)
			continue
		var/ischemia_damage = min(MS13_ISCHEMIA_DAMAGE_PER_TICK * delta_time, ceiling - O.damage)
		O.applyOrganDamage(ischemia_damage)
		ms13_medical_debug(owner, "Ischemia: [O.name] +[round(ischemia_damage, 0.1)] damage (ceiling [round(ceiling, 0.1)])")

/**
 * DD's base /obj/item/organ/proc/handle_regeneration() (code/modules/surgery/organs/_organ.dm) already
 * self-heals any organ once its damage drops under 10% of max - vessels get that for free just by being a
 * normal /obj/item/organ subtype, no changes needed there. What DD's base version doesn't know about is
 * blood supply: gate it on this limb actually having enough local_blood_volume to knit itself back together
 * with - a vessel sitting in a locally blood-starved limb (drained faster than it's regenerating, see
 * on_life() above) shouldn't be healing on its own no matter how minor the damage is.
 */
/obj/item/organ/vessel/handle_regeneration()
	if(!ownerlimb || ownerlimb.local_blood_volume < ownerlimb.local_blood_volume_max * MS13_VESSEL_REGEN_MIN_LOCAL_BLOOD_PCT)
		if(ownerlimb)
			ms13_medical_debug(owner, "Vessel [name] regen blocked: local blood too low ([round(ownerlimb.local_blood_volume, 0.1)]/[ownerlimb.local_blood_volume_max])")
		return
	return ..()

/**
 * Same idea as the vessel-specific override above, generalized to every other organ - a heart or lung
 * sitting in a blood-starved chest shouldn't be knitting itself back together either. Safe to apply
 * universally: local_blood_volume defaults to full and only ever drops via a vessel actually being
 * damaged (vessel_local_blood.dm's on_life()), so this is a no-op for any species/mob that never got the
 * vessel system installed on it.
 */
/obj/item/organ/handle_regeneration()
	if(ownerlimb && ownerlimb.local_blood_volume < ownerlimb.local_blood_volume_max * MS13_ORGAN_REGEN_MIN_LOCAL_BLOOD_PCT)
		ms13_medical_debug(owner, "[name] regen blocked: local blood too low ([round(ownerlimb.local_blood_volume, 0.1)]/[ownerlimb.local_blood_volume_max])")
		return
	return ..()
