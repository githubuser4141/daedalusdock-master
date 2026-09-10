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
	var/local_blood_volume = MS13_LOCAL_BLOOD_MAX
	var/local_blood_volume_max = MS13_LOCAL_BLOOD_MAX

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

	if(damage > 0)
		var/local_loss = damage * MS13_VESSEL_BLEED_LOCAL_PER_DAMAGE * delta_time
		ownerlimb.local_blood_volume = max(0, ownerlimb.local_blood_volume - local_loss)

		var/global_loss = damage * MS13_VESSEL_BLEED_GLOBAL_PER_DAMAGE * delta_time
		owner.bleed(global_loss)
		return

	if(ownerlimb.local_blood_volume >= ownerlimb.local_blood_volume_max)
		return
	if(owner.blood_volume <= MS13_LOCAL_BLOOD_REGEN_FLOOR)
		return

	var/regen = min(MS13_LOCAL_BLOOD_REGEN * delta_time, ownerlimb.local_blood_volume_max - ownerlimb.local_blood_volume)
	ownerlimb.local_blood_volume += regen
	owner.adjustBloodVolume(-regen)

/**
 * DD's base /obj/item/organ/proc/handle_regeneration() (code/modules/surgery/organs/_organ.dm) already
 * self-heals any organ once its damage drops under 10% of max - vessels get that for free just by being a
 * normal /obj/item/organ subtype, no changes needed there. What DD's base version doesn't know about is
 * blood supply: gate it on this limb actually having enough local_blood_volume to knit itself back together
 * with - a vessel sitting in a locally blood-starved limb (drained faster than it's regenerating, see
 * on_life() above) shouldn't be healing on its own no matter how minor the damage is.
 */
/obj/item/organ/vessel/handle_regeneration()
	if(!ownerlimb || ownerlimb.local_blood_volume < MS13_VESSEL_REGEN_MIN_LOCAL_BLOOD)
		return
	return ..()
