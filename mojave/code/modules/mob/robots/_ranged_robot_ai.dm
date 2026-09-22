// Shared blind-fire memory for every ranged /mob/living/simple_animal/hostile/ms13/robot (sentrybot,
// assaultron, eyebot, protectron, handy/gun, robobrain, vendortron, etc) - losing line of sight doesn't mean
// instantly forgetting the target. They keep tracking/shooting at wherever the target was last actually seen
// for blind_fire_duration before giving up, instead of stock DD's "go idle the instant LoS breaks" behavior.
// A robot with its own extra firing flavor builds on top of this rather than duplicating it - see
// sentrybot.dm's OpenFire() override for the one example (gatling windup/spin-down).

/mob/living/simple_animal/hostile/ms13/robot
	/// Frozen aim point while blind-firing at a target's last-seen location - see get_blind_fire_target().
	var/turf/blind_fire_turf
	/// world.time deadline for the current blind-fire volley - 0 when not blind-firing.
	var/blind_fire_until = 0
	/// How long we'll keep shooting at a target's last-seen location after losing line of sight before giving up.
	var/blind_fire_duration = 20 SECONDS
	/// How far we can still make out whether we've kept or lost line of sight on the target.
	var/blind_fire_los_range = 12
	/// Was the target LYING_DOWN at the moment we lost line of sight on them? See low_aim_mode (sentrybot.dm).
	var/blind_fire_target_was_prone = FALSE

/// Keeps a lost-LoS target in scope for MoveToTarget()'s possible_targets check (code/modules/mob/living/
/// simple_animal/hostile/hostile.dm) as long as they're still within aggro_vision_range - without this,
/// losing direct sight would call LoseTarget() immediately, before blind fire ever got a chance to kick in.
/mob/living/simple_animal/hostile/ms13/robot/ListTargets()
	. = ..()
	if(target && get_dist(target, src) < aggro_vision_range)
		. += target

/**
 * Resolves what to actually aim at: the live target while it's visible, or its last-seen position for up to
 * blind_fire_duration after losing line of sight - instead of forgetting them the instant something blocks
 * the view. Returns null once it's time to give up (window elapsed, or nothing left to aim at) - callers
 * must bail out on null rather than firing at it.
 */
/mob/living/simple_animal/hostile/ms13/robot/proc/get_blind_fire_target(atom/A)
	if(ms13_can_see(src, target, blind_fire_los_range))
		blind_fire_until = 0
		blind_fire_turf = null
		blind_fire_target_was_prone = FALSE
		return A
	if(!blind_fire_until)
		blind_fire_turf = get_turf(target)
		// A pack follower fires where its leader called, roughly (mojave/code/modules/mob/ms13_packs/packs.dm).
		if(ms13_pack?.follows(src))
			blind_fire_turf = pick(RANGE_TURFS(1, blind_fire_turf))
		blind_fire_until = world.time + blind_fire_duration
		var/mob/living/living_target = isliving(target) ? target : null
		blind_fire_target_was_prone = living_target && living_target.body_position == LYING_DOWN
	if(!blind_fire_turf || world.time > blind_fire_until)
		blind_fire_until = 0
		blind_fire_turf = null
		blind_fire_target_was_prone = FALSE
		// Give up on it. Looking again would find it straight back (ListTargets() above keeps it in range) and
		// start a fresh window at wherever it is now, tracking it through walls for as long as it stays close.
		LoseTarget()
		return null
	return blind_fire_turf

/**
 * A genuine target switch starts blind-fire tracking fresh instead of inheriting a stale aim point (or a
 * stale prone-guess) that belonged to whoever was being shot at before - so acquiring a second target while
 * still blind-firing at the first one's last position can't leave the shooter aimed at the wrong spot, or
 * stuck thinking it's still tracking someone it's no longer actually after.
 */
/mob/living/simple_animal/hostile/ms13/robot/GiveTarget(new_target)
	if(new_target != target)
		blind_fire_until = 0
		blind_fire_turf = null
		blind_fire_target_was_prone = FALSE
	. = ..()

/// Robots with no extra firing flavor of their own (see sentrybot.dm for one that has some) just resolve the
/// aim point and fire normally through DD's stock OpenFire().
/mob/living/simple_animal/hostile/ms13/robot/OpenFire(atom/A)
	A = get_blind_fire_target(A)
	if(!A)
		return
	return ..(A)
