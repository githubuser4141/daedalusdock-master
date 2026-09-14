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

/// How far these mobs bother resolving line of sight.
#define MS13_AI_SIGHT_RANGE 9
/// Incoming shot quality above which we consider ourselves worth shooting at, and go looking for cover.
#define MS13_AI_EXPOSED_THRESHOLD 0.5
/// A candidate spot has to be at least this much better than where we already are to be worth crossing to.
#define MS13_AI_COVER_IMPROVEMENT 0.25

/**
 * Picks somewhere near seeker that threat has a worse shot into.
 *
 * Candidates are not "every turf in range" - that would be over a hundred line-walks per decision. They're
 * the tile on the far side of each nearby dense object, which is both far cheaper and a direct expression of
 * what cover-seeking actually means: get that thing between us.
 */
/proc/ms13_find_cover_turf(mob/living/seeker, atom/threat, radius = 5)
	var/turf/seeker_turf = get_turf(seeker)
	var/turf/threat_turf = get_turf(threat)
	if(!seeker_turf || !threat_turf)
		return null

	var/current_quality = ms13_shot_quality(threat_turf, seeker_turf)
	var/best_quality = current_quality - MS13_AI_COVER_IMPROVEMENT
	var/turf/best_turf

	for(var/obj/obstacle in range(radius, seeker))
		if(!obstacle.density)
			continue
		var/turf/obstacle_turf = get_turf(obstacle)
		if(!obstacle_turf)
			continue
		var/turf/candidate = get_step(obstacle_turf, get_dir(threat_turf, obstacle_turf))
		if(!candidate || candidate.density || candidate == seeker_turf)
			continue
		if(get_dist(seeker_turf, candidate) > radius)
			continue

		var/blocked = FALSE
		for(var/atom/movable/thing in candidate)
			if(thing.density && thing != seeker)
				blocked = TRUE
				break
		if(blocked)
			continue

		var/candidate_quality = ms13_shot_quality(threat_turf, candidate)
		if(candidate_quality < best_quality)
			best_quality = candidate_quality
			best_turf = candidate

	return best_turf

/// Records where a target was last actually seen. Queues nothing itself - it only feeds the two below.
/datum/ai_planning_subtree/ms13_combat_awareness
	/// How long a remembered position stays worth shooting at after sight breaks.
	var/memory_duration = 12 SECONDS

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

/datum/ai_planning_subtree/ms13_take_cover/SelectBehaviors(datum/ai_controller/controller, delta_time)
	. = ..()
	var/mob/living/pawn = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target) || !isliving(pawn))
		return
	// Already behind something that works - stay put and let the firing subtrees run instead.
	if(ms13_shot_quality(target, pawn) < MS13_AI_EXPOSED_THRESHOLD)
		return

	var/turf/cover_turf = ms13_find_cover_turf(pawn, target)
	if(!cover_turf)
		return

	controller.set_blackboard_key(BB_MS13_COVER_TURF, cover_turf)
	controller.queue_behavior(/datum/ai_behavior/ms13_move_to_cover, BB_MS13_COVER_TURF)
	// Crossing open ground is the whole action this tick; shooting resumes once we're behind something.
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/ms13_move_to_cover
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	action_cooldown = 2 SECONDS
	required_distance = 0

/datum/ai_behavior/ms13_move_to_cover/setup(datum/ai_controller/controller, cover_key)
	. = ..()
	var/turf/cover_turf = controller.blackboard[cover_key]
	if(!cover_turf)
		return FALSE
	controller.set_move_target(cover_turf)

/datum/ai_behavior/ms13_move_to_cover/perform(delta_time, datum/ai_controller/controller, cover_key)
	. = ..()
	return BEHAVIOR_PERFORM_SUCCESS

/datum/ai_behavior/ms13_move_to_cover/finish_action(datum/ai_controller/controller, succeeded, cover_key)
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

	var/turf/last_known = controller.blackboard[BB_MS13_LAST_KNOWN_TURF]
	if(!last_known)
		return
	if(world.time > controller.blackboard[BB_MS13_SUPPRESS_UNTIL])
		controller.clear_blackboard_key(BB_MS13_LAST_KNOWN_TURF)
		controller.clear_blackboard_key(BB_MS13_SUPPRESS_UNTIL)
		return

	controller.queue_behavior(/datum/ai_behavior/ms13_suppressing_fire, BB_MS13_LAST_KNOWN_TURF)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/ms13_suppressing_fire
	/// Deliberately slower than aimed fire - this is shooting at a memory, not at a target.
	action_cooldown = 1.2 SECONDS

/datum/ai_behavior/ms13_suppressing_fire/perform(delta_time, datum/ai_controller/controller, turf_key)
	. = ..()
	var/mob/living/basic/pawn = controller.pawn
	var/turf/aim_point = controller.blackboard[turf_key]
	if(!istype(pawn) || !aim_point)
		return BEHAVIOR_PERFORM_FAILURE
	pawn.RangedAttack(aim_point)
	return BEHAVIOR_PERFORM_COOLDOWN
