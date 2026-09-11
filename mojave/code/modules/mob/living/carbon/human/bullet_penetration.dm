// Bullet overpenetration: a shot doesn't dump its whole damage budget into the first person it hits - only
// part of it, depending on what internal structure is in its path and how fast it's going. The rest
// continues through as leftover damage on the same projectile, via DD's real BULLET_ACT_FORCE_PIERCE
// mechanic (process_hit(), projectile.dm) - reused as-is, see human_defense.dm's bullet_act() for the split.
//
// Strict conservation: nothing here ever adds damage, only redistributes a fixed budget - the transferred
// amount, the primary organ's share of it, and any splash carved out of that share, always sum back to
// exactly what was transferred. Denser structures (bone) transfer more of the budget at baseline, but speed
// and the bullet's own construction can push that either way - see get_bullet_transfer_fraction().
//
// Cross-section values below are placeholder-sensible, not simulated - see bullet_math.dm's TODO for
// eventually unifying this with the wall penetration math instead of a separate formula.

/// Cross-section coverage, centralized here for one-stop tuning (var-only reopens, not proc redeclarations -
/// safe to spread a type's vars across files, unlike a proc body). Limb bone/muscle/vessel default here;
/// chest/head-specific organs (including the head/chest bone and chest muscle subtypes) override below.
/obj/item/organ/bone
	bullet_cross_section = 0.15
/obj/item/organ/bone/head
	bullet_cross_section = 0.2
/obj/item/organ/muscle
	bullet_cross_section = 0.45
/obj/item/organ/muscle/chest
	bullet_cross_section = 0.2
/obj/item/organ/vessel
	bullet_cross_section = 0.03

/// Real cross-section coverage for DD's own chest/head organs.
/obj/item/organ/heart
	bullet_cross_section = 0.1
/obj/item/organ/lungs
	bullet_cross_section = 0.25
/obj/item/organ/liver
	bullet_cross_section = 0.08
/obj/item/organ/kidneys
	bullet_cross_section = 0.05
/obj/item/organ/stomach
	bullet_cross_section = 0.08
/obj/item/organ/brain
	bullet_cross_section = 0.55
/obj/item/organ/eyes
	bullet_cross_section = 0.02

/// How much of the transferred amount a hit on this organ type claims per unit of "rigidity" - reused for
/// both the primary struck organ and any splash targets, so "armor" consistently means MORE damage taken,
/// not less (deliberately not code/modules/surgery/organs/_organ.dm's external_damage_modifier, which means
/// the opposite for the organ's own general damage resistance).
/mob/living/carbon/human/proc/get_organ_bullet_rigidity(obj/item/organ/O)
	if(istype(O, /obj/item/organ/bone))
		return MS13_BULLET_TRANSFER_BONE
	if(istype(O, /obj/item/organ/vessel))
		return MS13_BULLET_TRANSFER_VESSEL
	if(istype(O, /obj/item/organ/muscle))
		return MS13_BULLET_TRANSFER_MUSCLE
	return MS13_BULLET_TRANSFER_ORGAN

/**
 * Picks what the shot's path crosses (weighted by bullet_cross_section, remainder is a clean pass through
 * generic tissue), applies organ-level consequences (primary hit + any splash, carved out of the same
 * transferred_amount - never on top of it), and returns the transfer fraction for the caller to split
 * P.damage with. See human_defense.dm's bullet_act() for how the split/pass-through actually happens.
 */
/mob/living/carbon/human/proc/get_bullet_transfer_fraction(obj/projectile/P, def_zone)
	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : get_bodypart(deprecise_zone(def_zone))
	if(!hit_part)
		return MS13_BULLET_TRANSFER_CLEAN

	var/list/candidates = list()
	var/total_cross_section = 0
	for(var/obj/item/organ/O in hit_part.contained_organs)
		if((O.organ_flags & ORGAN_DEAD) || O.cosmetic_only || !O.bullet_cross_section)
			continue
		candidates[O] = O.bullet_cross_section
		total_cross_section += O.bullet_cross_section
	candidates["clean pass"] = max(0.05, 1 - total_cross_section) // floor so a badly-tuned bodypart (cross-sections summing to >=1) can't zero this out

	var/picked = pick_weight(candidates)
	var/rigidity = istext(picked) ? MS13_BULLET_TRANSFER_CLEAN : get_organ_bullet_rigidity(picked)

	// Speed spreads structures apart from a common convergence point rather than scaling all of them
	// uniformly - see MS13_BULLET_TRANSFER_CONVERGENCE (bullet_math.dm). P.speed is a delay-per-tile (lower =
	// faster), so the ratio is initial/current, not current/initial.
	var/velocity_spread = clamp(initial(P.speed) / P.speed, MS13_BULLET_SPEED_SPREAD_MIN, MS13_BULLET_SPEED_SPREAD_MAX)
	var/transfer_fraction = MS13_BULLET_TRANSFER_CONVERGENCE + (rigidity - MS13_BULLET_TRANSFER_CONVERGENCE) * velocity_spread

	// The bullet's own construction divides the result - a tougher round holds its shape and punches through
	// more (transfer_fraction goes down); one that deforms/fragments more easily dumps its energy instead
	// (transfer_fraction goes up). Shared with wall overpenetration (bullet_math.dm's get_own_hardness_ratio()).
	var/hardness_ratio = P.get_own_hardness_ratio()
	transfer_fraction /= hardness_ratio

	transfer_fraction = clamp(transfer_fraction, 0, 1)
	var/transferred_amount = P.damage * transfer_fraction

	log_combat(P.firer, src, "shot [istext(picked) ? "with a clean pass" : "hitting [picked]"] in the [hit_part.plaintext_zone]", P, "transferred [round(transferred_amount, 0.1)]/[P.damage] (fraction [round(transfer_fraction, 0.01)], velocity_spread [round(velocity_spread, 0.01)], hardness [round(hardness_ratio, 0.01)], integrity [round(P.getBIntegrity(), 1)])")

	// Hitting a structure costs the bullet some of its own integrity too - more for a rigid one (bone) than a
	// clean pass, same idea as the existing ricochet/fragment integrity costs (bullet_math.dm). This also
	// shrinks its remaining range (adjustIntegrity()'s override there), so a sufficiently worn-down bullet
	// naturally runs out of both damage and distance instead of either being tracked forever.
	// AI EDIT: floored at 1, not 0 - adjustIntegrity() qdels the projectile outright at 0 integrity, and P is
	// still needed by the caller (human_defense.dm's bullet_act()) for the rest of this same hit. Letting an
	// organ hit alone fully finish the bullet off risks using it after it's deleted; a future ricochet or
	// fragment event can still finish it for real.
	var/integrity_cost = min(MS13_BULLET_ORGAN_INTEGRITY_LOSS_BASE * rigidity, P.getBIntegrity() - 1)
	if(integrity_cost > 0)
		P.adjustIntegrity(-integrity_cost)

	if(!istext(picked))
		apply_bullet_organ_damage(hit_part, picked, transferred_amount, P.firer)

	return transfer_fraction

/// Splits transferred_amount between the primary struck organ and any splash to nearby organs sharing the
/// bodypart - carved out of transferred_amount, never added to it.
/mob/living/carbon/human/proc/apply_bullet_organ_damage(obj/item/bodypart/hit_part, obj/item/organ/primary, transferred_amount, atom/firer)
	var/organ_pool = transferred_amount
	for(var/obj/item/organ/O in hit_part.contained_organs)
		if(O == primary || (O.organ_flags & ORGAN_DEAD) || O.cosmetic_only || !O.bullet_cross_section)
			continue
		if(!prob(O.bullet_cross_section * 100 * MS13_BULLET_SPLASH_CHANCE_MULT))
			continue
		var/splash = min(organ_pool, transferred_amount * MS13_BULLET_SPLASH_SHARE * get_organ_bullet_rigidity(O))
		if(splash <= 0)
			continue
		O.applyOrganDamage(splash)
		organ_pool -= splash
		if(firer)
			log_combat(firer, src, "bullet splash hit [O]", addition = "[round(splash, 0.1)] damage")

	primary.applyOrganDamage(organ_pool)
