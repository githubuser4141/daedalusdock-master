/**
 * Cover.
 *
 * Stock DD treats cover as binary and symmetric: can_hit_target() stops a projectile on ANY dense atom,
 * every time, and never on a non-dense one. That leaves no room for the middle tier every shooter wants -
 * the crate you can crouch behind but still shoot over.
 *
 * projectile_passchance fills that gap. It's the same var original Mojave Sun 13 used, and roughly forty
 * mojave structures still carry commented-out values for it (crates 45-90, safes 80-100, ruins 35-45) from
 * that port - uncomment those to tune individual objects; the defaults set at the bottom of this file cover
 * the common cases in the meantime.
 *
 * The three tiers fall out of properties objects already have, so there are no new object classes:
 *
 *   hard cover   dense, passchance 0,      usually opaque - stops everything, breaks sight (walls)
 *   semi-hard    dense, passchance 35-90,  not opaque     - usually stops incoming, shootable over (crates)
 *   concealment  not dense,                opaque         - stops nothing, breaks sight (curtains, smoke)
 */

/obj
	/// Percent chance a projectile passes over/through this object instead of striking it. 0 (the default)
	/// keeps stock behaviour - a dense object stops every shot. Only meaningful on dense objects.
	var/projectile_passchance = 0

/obj/projectile
	/// Cover this projectile has already rolled against, so one object can't be rolled twice on its way past.
	var/list/cover_passed
	var/list/cover_blocked

/**
 * Lets a shot clear semi-hard cover instead of always burying itself in it.
 *
 * The asymmetry the player actually wants - "blocks incoming, allows outgoing" - is deliberately NOT a
 * property of the object here. If it were, the same crate would be a one-way wall for whoever happened to be
 * standing on the far side of it. It's a property of the shooter's position instead: firing while braced
 * against a piece of cover shoots over it. Everyone gets that rule, player and NPC alike.
 *
 * ponytail: "braced" is just adjacency, so it ignores which way you're actually facing - standing next to a
 * crate clears it in every direction, not only across it. Compare firing angle against the cover's bearing
 * if that ever reads wrong.
 */
/obj/projectile/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	. = ..()
	if(!. || direct_target || !isobj(target))
		return

	var/obj/cover = target
	if(!cover.density || cover.projectile_passchance <= 0)
		return

	if(firer && get_dist(firer, cover) <= 1)
		return FALSE

	if(cover in cover_passed)
		return FALSE
	if(cover in cover_blocked)
		return TRUE

	if(prob(cover.projectile_passchance))
		LAZYADD(cover_passed, cover)
		return FALSE

	LAZYADD(cover_blocked, cover)
	return TRUE

/**
 * How good a shot from source to target is, as 0 (no shot at all) to 1 (completely clear).
 *
 * This is the predicate AI combat should be asking, because with cover in play "can I see you" and "can I
 * hit you" stop being the same question - a raider behind a crate is plainly visible and largely unshootable,
 * one behind a curtain is the reverse. can_see() (code/__HELPERS/atoms.dm) only ever tested IS_OPAQUE_TURF,
 * so it answers the first question and is blind to every piece of cover in the game.
 *
 * Returning a value rather than a bool is what allows graded decisions - take the shot, take it but look for
 * a better angle, or stop wasting ammunition - instead of a switch.
 *
 * ponytail: dense border objects (windows, railings) count wherever they sit on the line, ignoring which edge
 * of the tile they actually occupy, so a window can shave quality off a shot that wouldn't really cross it.
 */
/proc/ms13_shot_quality(atom/source, atom/target, max_range = 14, ignore_braced = FALSE)
	var/turf/source_turf = get_turf(source)
	var/turf/target_turf = get_turf(target)
	if(!source_turf || !target_turf)
		return 0
	if(source_turf == target_turf)
		return 1
	if(get_dist(source_turf, target_turf) > max_range)
		return 0

	. = 1
	var/list/line = get_line(source_turf, target_turf)
	// Skip both endpoints: the shooter's own tile and whatever the target is standing behind on theirs.
	for(var/index in 2 to length(line) - 1)
		var/turf/step_turf = line[index]
		if(step_turf.density)
			return 0
		// Cover the shooter is braced against doesn't obstruct their own outgoing shot - same rule
		// can_hit_target() applies above. Walls still block regardless; bracing is an object-only rule.
		for(var/obj/obstacle in step_turf)
			if(!obstacle.density)
				continue
			// Only semi-hard cover can be fired over. The live projectile rule deliberately leaves
			// passchance-zero objects to the stock collision result, so walls and other hard cover must
			// remain blocking here too.
			if(ignore_braced && obstacle.projectile_passchance > 0 && get_dist(source_turf, step_turf) <= 1)
				continue
			if(obstacle.projectile_passchance <= 0)
				return 0
			. *= obstacle.projectile_passchance / 100
			if(. <= 0.05)
				return 0

/**
 * Overpenetration for structures and machinery.
 *
 * The passchance roll above only answers whether the round physically met the object. Once it has, the hit
 * should behave like every other hit in the game - and it didn't. Walls (wall_integrity.dm) and mobs
 * (bullet_penetration.dm) both transfer part of a round's damage into what they're made of and let the rest
 * carry on through, but /obj/bullet_act() just applied the full damage and let process_hit() qdel the
 * projectile. A crate stopped a .50 BMG as dead as a .22, and cover was harder to shoot through than a
 * concrete wall.
 *
 * These route structures and machinery through the same shared transfer-fraction model, so armor rating and
 * the round's own construction decide what gets through, exactly as they already do everywhere else.
 */
/obj/structure/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	var/original_damage = hitting_projectile.damage
	hitting_projectile.damage *= ms13_bullet_transfer_fraction(returnArmor(), hitting_projectile)
	. = ..()
	if(QDELETED(src))
		hitting_projectile.damage = original_damage
		return
	return ms13_finish_overpenetration(hitting_projectile, original_damage, .)

/obj/machinery/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	var/original_damage = hitting_projectile.damage
	hitting_projectile.damage *= ms13_bullet_transfer_fraction(returnArmor(), hitting_projectile)
	. = ..()
	if(QDELETED(src))
		hitting_projectile.damage = original_damage
		return
	return ms13_finish_overpenetration(hitting_projectile, original_damage, .)

/**
 * Shared tail of the two overrides above: hand whatever the target didn't absorb back to the projectile and
 * tell process_hit() to let it through, or restore the round untouched if too little is left to matter.
 */
/proc/ms13_finish_overpenetration(obj/projectile/hitting_projectile, original_damage, bullet_act_result)
	if(bullet_act_result != BULLET_ACT_HIT)
		hitting_projectile.damage = original_damage
		return bullet_act_result

	var/remaining_damage = original_damage - hitting_projectile.damage
	if(remaining_damage >= MS13_BULLET_OVERPEN_MIN_REMAINING)
		hitting_projectile.damage = remaining_damage
		return BULLET_ACT_FORCE_PIERCE

	hitting_projectile.damage = original_damage
	return bullet_act_result

/// Baseline values for the common cases. Individual structures can override this the same way the
/// commented-out per-object values in mojave/structures/ were always meant to.
/obj/structure/girder
	projectile_passchance = 70

/obj/structure/table
	projectile_passchance = 60

/obj/structure/rack
	projectile_passchance = 80
