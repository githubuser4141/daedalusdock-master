/**
 * Cover-seeking and suppressing fire for ranged NPCs.
 *
 * Three subtrees, deliberately kept separate so they can be mixed per mob rather than arriving as one
 * monolithic "combat AI" - a mob can take memory without cover, or cover without suppression:
 *
 *   ms13_combat_awareness   remembers where a target was last actually seen
 *   ms13_take_cover         moves somewhere the target has a worse shot at us
 *   ms13_suppressing_fire   keeps shooting at that remembered spot once line of sight breaks
 *
 * Together they replace the stock behaviour where losing sight of a target means instantly forgetting it and
 * standing around in the open. The memory half generalises what mojave's legacy ranged robots already do
 * privately in _ranged_robot_ai.dm (blind_fire_turf), but onto the modern controller framework and in a form
 * other mobs can reuse.
 *
 * Everything here reads cover through ms13_shot_quality() (mojave/code/modules/projectiles/cover.dm) rather
 * than can_see(), because can_see() only tests turf opacity and is blind to every crate and table in the game.
 *
 * ponytail: each mob reasons alone. There is no shared threat picture between members of a faction yet, so
 * two NPCs can pick the same piece of cover and neither knows what the other can see. The awareness subtree
 * is where a squad-level contact list would plug in.
 */

/// Where the target was standing when we last genuinely had eyes on it.
#define BB_MS13_LAST_KNOWN_TURF "ms13_last_known_turf"
/// world.time deadline for how long that memory stays worth shooting at.
#define BB_MS13_SUPPRESS_UNTIL "ms13_suppress_until"
/// Cover turf currently being moved to.
#define BB_MS13_COVER_TURF "ms13_cover_turf"
/// Earliest world.time we'll go looking for cover again, so a bad pick can't be retried every tick.
#define BB_MS13_NEXT_COVER_ATTEMPT "ms13_next_cover_attempt"

/// How far these mobs bother resolving line of sight.
#define MS13_AI_SIGHT_RANGE 9
/// Incoming shot quality above which we consider ourselves worth shooting at, and go looking for cover.
#define MS13_AI_EXPOSED_THRESHOLD 0.75
/// A candidate spot has to be at least this much better than where we already are to be worth crossing to.
#define MS13_AI_COVER_IMPROVEMENT 0.25
/// How far a gun-armed mob will engage from. Stock basic_ranged_attack uses 3, which is knife range for
/// something holding a rifle, and made cover-seeking actively harmful - it would fall back to cover and
/// then be unable to shoot from it at all.
#define MS13_AI_ENGAGE_RANGE 7
/// Cover we can't meaningfully shoot back from is just a corner to die in, so candidates have to keep at
/// least this much outgoing shot quality (measured braced, since firing over your own cover is allowed).
#define MS13_AI_MIN_RETURN_FIRE 0.6

/**
 * Picks somewhere near seeker that threat has a worse shot into.
 *
 * Candidates are not "every turf in range" - that would be over a hundred line-walks per decision. They're
 * the open tiles immediately around nearby dense objects. Shot quality then proves whether the object is
 * actually between the candidate and the threat. Considering all sides is what allows lateral movement;
 * selecting only the geometrical far side made every cover decision a backwards step.
 */
/proc/ms13_find_cover_turf(mob/living/seeker, atom/threat, radius = 5)
	var/turf/seeker_turf = get_turf(seeker)
	var/turf/threat_turf = get_turf(threat)
	if(!seeker_turf || !threat_turf)
		return null

	var/current_quality = ms13_shot_quality(threat_turf, seeker_turf)
	var/current_threat_distance = get_dist_manhattan(seeker_turf, threat_turf)
	var/threat_x = SIGN(threat_turf.x - seeker_turf.x)
	var/threat_y = SIGN(threat_turf.y - seeker_turf.y)
	var/best_score = INFINITY
	var/turf/best_turf
	var/list/checked_turfs = list()

	for(var/obj/obstacle in range(radius, seeker))
		if(!obstacle.density)
			continue
		for(var/turf/candidate in orange(1, obstacle))
			if(candidate in checked_turfs)
				continue
			checked_turfs += candidate
			if(candidate.density || candidate == seeker_turf || get_dist(seeker_turf, candidate) > radius)
				continue

			var/threat_distance = get_dist_manhattan(candidate, threat_turf)
			var/forward_progress = ((candidate.x - seeker_turf.x) * threat_x) + ((candidate.y - seeker_turf.y) * threat_y)
			// A Chebyshev-distance check still admitted diagonal retreat: moving one axis toward the target
			// and the other several tiles away can leave get_dist() unchanged. Require the destination to
			// be genuinely lateral/forward as well as no farther away in Manhattan distance.
			if(forward_progress < 0 || threat_distance > current_threat_distance || get_dist(candidate, threat_turf) > MS13_AI_ENGAGE_RANGE)
				continue
			if(ms13_shot_quality(candidate, threat_turf, ignore_braced = TRUE) < MS13_AI_MIN_RETURN_FIRE)
				continue

			var/blocked = FALSE
			for(var/atom/movable/thing in candidate)
				if(thing.density && thing != seeker)
					blocked = TRUE
					break
			if(blocked)
				continue

			var/candidate_quality = ms13_shot_quality(threat_turf, candidate)
			if(candidate_quality > current_quality - MS13_AI_COVER_IMPROVEMENT)
				continue

			// Prove the route now. Handing an unreachable destination to the movement behavior made it
			// spend twenty failed attempts pressed against the first obstruction before it could think again.
			// ponytail: this synchronously checks the small set of useful candidates; replace it with one
			// multi-target search only if profiling shows large NPC groups spending materially on cover plans.
			var/list/path = SSpathfinder.jps_pathfind_now(
				seeker,
				candidate,
				radius * 2,
				0,
				seeker.ai_controller?.get_access(),
				!HAS_TRAIT(seeker, TRAIT_FREE_FLOAT_MOVEMENT),
			)
			if(!length(path))
				continue

			// Once a tile is meaningfully protected, prefer the shortest complete route.
			var/candidate_score = length(path) + candidate_quality
			if(candidate_score < best_score)
				best_score = candidate_score
				best_turf = candidate

	return best_turf

/// Records where a target was last actually seen. Queues nothing itself - it only feeds the two below.
/datum/ai_planning_subtree/ms13_combat_awareness
	/// How long a remembered position stays worth shooting at after sight breaks. Short on purpose - a long
	/// window reads as a mob frozen in cover firing at nothing rather than as suppressing fire.
	var/memory_duration = 6 SECONDS

/datum/ai_planning_subtree/ms13_combat_awareness/SelectBehaviors(datum/ai_controller/controller, delta_time)
	. = ..()
	var/mob/living/pawn = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target) || !isliving(pawn))
		return
	if(!can_see(pawn, target, MS13_AI_SIGHT_RANGE))
		return

	controller.set_blackboard_key(BB_MS13_LAST_KNOWN_TURF, get_turf(target))
	controller.set_blackboard_key(BB_MS13_SUPPRESS_UNTIL, world.time + memory_duration)

/// Relocates when the current target has too clean a shot at us and somewhere better is in reach.
/datum/ai_planning_subtree/ms13_take_cover
	/// Minimum gap between cover decisions - keeps a failed or unreachable pick from being retried forever.
	var/cover_attempt_interval = 4 SECONDS

/datum/ai_planning_subtree/ms13_take_cover/SelectBehaviors(datum/ai_controller/controller, delta_time)
	. = ..()
	var/mob/living/pawn = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target) || !isliving(pawn))
		return
	// Already behind something that works - stay put and let the firing subtrees run instead.
	if(ms13_shot_quality(target, pawn) < MS13_AI_EXPOSED_THRESHOLD)
		return

	// Don't re-run the synchronous candidate/path search after every shot. Previously this cooldown was
	// only started after a cover tile was found, so open ground made every planning pass search every
	// nearby obstacle again; that was the source of the gunner's glacial stop-start behavior.
	if(world.time < controller.blackboard[BB_MS13_NEXT_COVER_ATTEMPT])
		return
	controller.set_blackboard_key(BB_MS13_NEXT_COVER_ATTEMPT, world.time + cover_attempt_interval)

	var/turf/cover_turf = ms13_find_cover_turf(pawn, target)
	if(!cover_turf)
		return

	controller.set_blackboard_key(BB_MS13_COVER_TURF, cover_turf)
	controller.queue_behavior(/datum/ai_behavior/ms13_move_to_turf, BB_MS13_COVER_TURF, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/ms13_move_to_turf
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM
	action_cooldown = 0.5 SECONDS
	required_distance = 0

/datum/ai_behavior/ms13_move_to_turf/setup(datum/ai_controller/controller, cover_key)
	. = ..()
	var/turf/cover_turf = controller.blackboard[cover_key]
	if(!cover_turf)
		return FALSE
	controller.set_move_target(cover_turf)

/datum/ai_behavior/ms13_move_to_turf/perform(delta_time, datum/ai_controller/controller, cover_key, target_key)
	. = ..()
	var/mob/living/basic/pawn = controller.pawn
	var/atom/target = target_key && controller.blackboard[target_key]
	if(target && can_see(pawn, target, MS13_AI_SIGHT_RANGE))
		pawn.RangedAttack(target)
	if(get_dist(pawn, controller.current_movement_target) <= required_distance)
		return BEHAVIOR_PERFORM_COOLDOWN | BEHAVIOR_PERFORM_SUCCESS
	return BEHAVIOR_PERFORM_COOLDOWN

/datum/ai_behavior/ms13_move_to_turf/finish_action(datum/ai_controller/controller, succeeded, cover_key, target_key)
	. = ..()
	controller.clear_blackboard_key(cover_key)

/**
 * Keeps shooting at a target's last known position after it breaks line of sight, instead of going quiet the
 * instant it steps behind something. Only runs when we genuinely can't see them - while they're visible the
 * ordinary ranged attack subtree is the one doing the work.
 */
/datum/ai_planning_subtree/ms13_suppressing_fire

/datum/ai_planning_subtree/ms13_suppressing_fire/SelectBehaviors(datum/ai_controller/controller, delta_time)
	. = ..()
	var/mob/living/pawn = controller.pawn
	if(!isliving(pawn))
		return
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(target) && can_see(pawn, target, MS13_AI_SIGHT_RANGE))
		return

	// The blackboard target is usually already empty by the time we get here - the ranged attack subtree
	// finishes planning whenever it has one - so checking only that would let us blaze away at a memory
	// while the target stands in plain view. Ask the mob's own targeting rules whether anything is actually
	// shootable right now instead, and leave it to the normal attack path if so.
	var/datum/targeting_strategy/targeting = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	if(targeting)
		for(var/mob/living/candidate in view(MS13_AI_SIGHT_RANGE, pawn))
			if(candidate == pawn)
				continue
			if(targeting.can_attack(pawn, candidate, MS13_AI_SIGHT_RANGE))
				return

	var/turf/last_known = controller.blackboard[BB_MS13_LAST_KNOWN_TURF]
	if(!last_known)
		return

	// Standing on or right next to the remembered spot isn't suppressing it, and firing at your own tile
	// leaves the projectile with no direction to travel in - it just squirts out southward. Arriving here
	// is also how "go and look" ends: we looked, nobody's home, forget it.
	if(get_dist(pawn, last_known) <= 1)
		controller.clear_blackboard_key(BB_MS13_LAST_KNOWN_TURF)
		controller.clear_blackboard_key(BB_MS13_SUPPRESS_UNTIL)
		return

	// If we can see the spot itself and nobody's on it, the memory is disproven - drop it rather than keep
	// shooting ground the target plainly already left. Our own pawn standing there doesn't count as proof.
	if(can_see(pawn, last_known, MS13_AI_SIGHT_RANGE))
		var/still_occupied = FALSE
		for(var/mob/living/occupant in last_known)
			if(occupant == pawn || occupant.stat == DEAD)
				continue
			still_occupied = TRUE
			break
		if(!still_occupied)
			controller.clear_blackboard_key(BB_MS13_LAST_KNOWN_TURF)
			controller.clear_blackboard_key(BB_MS13_SUPPRESS_UNTIL)
			return
	// Suppression spent. Go and look at the spot rather than sitting in cover firing at it forever - the
	// move behaviour clears the remembered turf when it finishes, which ends this whole state.
	if(world.time > controller.blackboard[BB_MS13_SUPPRESS_UNTIL])
		controller.clear_blackboard_key(BB_MS13_SUPPRESS_UNTIL)
		controller.queue_behavior(/datum/ai_behavior/ms13_move_to_turf, BB_MS13_LAST_KNOWN_TURF)
		return SUBTREE_RETURN_FINISH_PLANNING

	controller.queue_behavior(/datum/ai_behavior/ms13_suppressing_fire, BB_MS13_LAST_KNOWN_TURF)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Ordinary aimed fire, at a range a gun actually makes sense at. Stock basic_ranged_attack fires only
 * within 3 tiles and walks the mob into your face to do it; paired with cover-seeking that was actively
 * worse than no cover AI at all, since it would retreat to cover and then be too far away to shoot.
 */
/datum/ai_planning_subtree/basic_ranged_attack_subtree/ms13_gunner
	ranged_attack_behavior = /datum/ai_behavior/basic_ranged_attack/ms13_gunner

/datum/ai_planning_subtree/basic_ranged_attack_subtree/ms13_gunner/SelectBehaviors(datum/ai_controller/controller, delta_time)
	var/mob/living/pawn = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	// Do not let the stock attack subtree consume planning while the target is out of sight. That leaves
	// the remembered-position subtree below it free to suppress, investigate, and eventually forget them.
	if(!isliving(pawn) || QDELETED(target) || !can_see(pawn, target, MS13_AI_SIGHT_RANGE))
		return
	return ..()

/datum/ai_behavior/basic_ranged_attack/ms13_gunner
	// Acquired visible targets are already within this range. Ordinary aimed fire must not also own a
	// movement loop: all combat movement is chosen and path-validated by ms13_take_cover above.
	required_distance = MS13_AI_SIGHT_RANGE
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/basic_ranged_attack/ms13_gunner/perform(delta_time, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	. = ..()
	// Stock ranged attacks never finish after firing, permanently locking out replanning. Finish this one
	// successful shot so the next planning pass can decide between another shot, cover, or suppression.
	if(. & BEHAVIOR_PERFORM_COOLDOWN)
		return . | BEHAVIOR_PERFORM_SUCCESS

/datum/ai_behavior/ms13_suppressing_fire
	/// Deliberately slower than aimed fire - this is shooting at a memory, not at a target.
	action_cooldown = 1.2 SECONDS

/datum/ai_behavior/ms13_suppressing_fire/perform(delta_time, datum/ai_controller/controller, turf_key)
	. = ..()
	var/mob/living/basic/pawn = controller.pawn
	var/turf/aim_point = controller.blackboard[turf_key]
	if(!istype(pawn) || !aim_point)
		return BEHAVIOR_PERFORM_FAILURE
	// Firing at the tile you're standing on has no direction to resolve and the shot just goes south.
	if(get_dist(pawn, aim_point) <= 1)
		return BEHAVIOR_PERFORM_FAILURE
	pawn.RangedAttack(aim_point)
	// Suppression also has to yield to the planner or its deadline can never be observed.
	return BEHAVIOR_PERFORM_COOLDOWN | BEHAVIOR_PERFORM_SUCCESS
