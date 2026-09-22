/**
 * Mob packs: mobs nobody is near fall asleep together, and wake together.
 *
 * Every few seconds SSms13_packs gathers awake, idle mobs into packs of their faction, and puts a pack to sleep
 * once nobody has been near its leader and none of it has fought for two passes. A sleeping mob's AI is off and its
 * Life() runs one tick in ten, so it costs next to nothing. The leader has a wake area, its members' sight range plus a
 * margin. A player in it, an active hostile mob that comes into it, or any member being hurt wakes the pack: the leader
 * at once, the others over the next couple of seconds, so a big pack doesn't all start thinking in the same tick. Mobs
 * already about when it fell asleep, sleeping or not, never wake it, so neighbouring packs can't keep each other up.
 *
 * The wake area listens to the few spatial grid cells (17x17 tiles) around the leader, not its turfs: a pack signs up
 * to four to nine cells as it falls asleep, rather than hundreds of turfs, and hears only when a mob crosses into one.
 * While a player, or a hostile mob that crossed in, is inside its cells but not yet in range, it looks again once a
 * second.
 *
 * Awake, only the leader looks for targets. Followers take the leader's target and trail it while idle, and only look
 * around for themselves for a few seconds after being hurt, so a pack can't be picked apart from its edges. When the
 * leader dies or leaves, a random member takes over, and the followers lose the target they were given.
 *
 * Every mob with an AI can join a pack. /mob/living/var/ms13_can_sleep = FALSE keeps one always awake; the types that
 * set it are listed just below.
 */

/// Members stay within this many tiles of their leader to fall asleep with it.
#define MS13_PACK_RANGE 5
/// Awake members wandering further than this from the leader leave the pack.
#define MS13_PACK_STRAY_RANGE 15
#define MS13_PACK_MAX_SIZE 12
/// The wake area reaches this many tiles past what the members could see.
#define MS13_PACK_WAKE_MARGIN 3
/// Quiet passes in a row before a pack falls asleep.
#define MS13_PACK_QUIET_PASSES 2
/// How long a hurt follower looks for its own target instead of the leader's.
#define MS13_PACK_HURT_MEMORY 5 SECONDS
/// How long after being hurt a mob still counts as fighting, and won't fall asleep.
#define MS13_PACK_FIGHT_MEMORY 30 SECONDS
/// A sleeping mob's Life() runs once in this many ticks.
#define MS13_PACK_STASIS 10
/// Followers wake this long apart, after the leader.
#define MS13_PACK_WAKE_STAGGER 2
/// How often a sleeping pack looks again while someone is inside its cells but not yet in range.
#define MS13_PACK_WATCH_INTERVAL 1 SECONDS

/mob/living
	/// Falls asleep with a pack when nobody is near. FALSE keeps this mob always awake.
	var/ms13_can_sleep = TRUE
	var/tmp/datum/ms13_pack/ms13_pack
	var/tmp/ms13_asleep = FALSE
	/// world.time this mob was last hurt.
	var/tmp/ms13_hurt_at = -INFINITY

// Never sleep. Hive units take their orders from their network, and a sleeping unit would ignore them.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	ms13_can_sleep = FALSE

/// Its AI runs by itself, and sleeping would pause it.
/mob/living/proc/ms13_runs_ai()
	return ai_controller?.ai_status == AI_STATUS_ON

/mob/living/simple_animal/ms13_runs_ai()
	return ..() || (!ai_controller && can_have_ai && (AIStatus == AI_ON || AIStatus == AI_IDLE))

/// What this mob is after, if anything.
/mob/living/proc/ms13_current_target()
	return ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]

/mob/living/simple_animal/hostile/ms13_current_target()
	return target || ..()

/mob/living/proc/ms13_drop_target()
	ai_controller?.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/mob/living/simple_animal/hostile/ms13_drop_target()
	. = ..()
	if(target)
		LoseTarget()

/// Busy with a living target, or hurt lately. Standing over a corpse doesn't count.
/mob/living/proc/ms13_in_fight()
	if(world.time < ms13_hurt_at + MS13_PACK_FIGHT_MEMORY)
		return TRUE
	var/atom/target = ms13_current_target()
	if(QDELETED(target))
		return FALSE
	var/mob/living/living_target = target
	return !istype(living_target) || living_target.stat != DEAD

/// How far this mob looks for targets.
/mob/living/proc/ms13_sight_range()
	return 9

/mob/living/simple_animal/hostile/ms13_sight_range()
	return max(vision_range, aggro_vision_range)

/// Could fall asleep in a pack right now: nobody playing it, its AI running, and nothing to fight.
/mob/living/proc/ms13_can_join_pack()
	return ms13_can_sleep && !key && stat != DEAD && isturf(loc) && ms13_runs_ai() && !ms13_in_fight()

/mob/living/proc/ms13_set_asleep(asleep)
	if(ms13_asleep == asleep)
		return
	ms13_asleep = asleep
	if(asleep)
		SET_STASIS_LEVEL(src, "ms13_pack", MS13_PACK_STASIS)
	else
		UNSET_STASIS_LEVEL(src, "ms13_pack")
	ms13_pause_ai(asleep)

/mob/living/proc/ms13_pause_ai(paused)
	if(!ai_controller || (!paused && (client || stat == DEAD)))
		return
	ai_controller.set_ai_status(paused ? AI_STATUS_OFF : AI_STATUS_ON)

/mob/living/simple_animal/ms13_pause_ai(paused)
	. = ..()
	if(ai_controller || !can_have_ai)
		return
	if(paused)
		toggle_ai(AI_OFF)
		SSmove_manager.stop_looping(src)
	else if(AIStatus == AI_OFF && !client && stat != DEAD)
		toggle_ai(AI_ON)

/// A delayed wake for a follower, which the pack may have put back to sleep or let go of since.
/mob/living/proc/ms13_wake_with_pack()
	if(ms13_pack && !ms13_pack.asleep)
		ms13_set_asleep(FALSE)

/mob/living/updatehealth(cause_of_death)
	var/old_health = health
	. = ..()
	if(health >= old_health)
		return
	ms13_hurt_at = world.time
	if(ms13_asleep)
		ms13_pack?.wake()

/datum/ms13_pack
	var/list/members = list()
	var/mob/living/leader
	var/asleep = FALSE
	/// Passes in a row with nobody near and nobody fighting.
	var/quiet_passes = 0
	/// The spatial grid cells a sleeping pack listens to.
	var/list/watched_cells
	/// Looking again soon, because someone is inside its cells.
	var/watching_closely = FALSE
	/// Active hostile mobs that crossed into its cells while it slept.
	var/list/visitors

/datum/ms13_pack/New(mob/living/founder)
	SSms13_packs.packs += src
	add(founder)

/datum/ms13_pack/Destroy()
	SSms13_packs.packs -= src
	unwatch()
	for(var/mob/living/member as anything in members)
		release(member)
	members.Cut()
	leader = null
	return ..()

/datum/ms13_pack/proc/add(mob/living/member)
	members += member
	member.ms13_pack = src
	leader ||= member
	RegisterSignal(member, COMSIG_PARENT_QDELETING, PROC_REF(on_member_gone))
	RegisterSignal(member, COMSIG_LIVING_DEATH, PROC_REF(on_member_gone))
	if(asleep)
		member.ms13_set_asleep(TRUE)

/datum/ms13_pack/proc/remove(mob/living/member)
	if(!(member in members))
		return
	members -= member
	release(member)
	if(!length(members))
		qdel(src)
	else if(member == leader)
		replace_leader()

/// Lets member go, awake.
/datum/ms13_pack/proc/release(mob/living/member)
	UnregisterSignal(member, list(COMSIG_PARENT_QDELETING, COMSIG_LIVING_DEATH))
	member.ms13_pack = null
	if(!QDELETED(member))
		member.ms13_set_asleep(FALSE)

/datum/ms13_pack/proc/on_member_gone(mob/living/member)
	SIGNAL_HANDLER
	remove(member)

/// A random member takes over. Followers lose the target the old leader gave them, unless they're fighting for themselves.
/datum/ms13_pack/proc/replace_leader()
	leader = pick(members)
	if(asleep)
		unwatch()
		watch()
		return
	for(var/mob/living/member as anything in members)
		if(member != leader && follows(member))
			member.ms13_drop_target()

/datum/ms13_pack/proc/wake_range()
	var/sight = 0
	for(var/mob/living/member as anything in members)
		sight = max(sight, member.ms13_sight_range())
	return sight + MS13_PACK_WAKE_MARGIN

/// Once a pass: lets go of members that died, got a player, or strayed, then falls asleep if it has been quiet long enough.
/datum/ms13_pack/proc/check()
	for(var/mob/living/member as anything in members.Copy())
		if(member.key || member.stat == DEAD || !isturf(member.loc) || member.z != leader.z || get_dist(member, leader) > MS13_PACK_STRAY_RANGE)
			remove(member)
	if(QDELETED(src) || asleep)
		return
	if(anyone_near() || fighting())
		quiet_passes = 0
		return
	if(++quiet_passes >= MS13_PACK_QUIET_PASSES)
		fall_asleep()

/datum/ms13_pack/proc/anyone_near()
	var/range = wake_range()
	for(var/mob/living/player in SSspatial_grid.orthogonal_range_search(leader, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, range))
		if(player.stat != DEAD && get_dist(player, leader) <= range)
			return TRUE
	return FALSE

/datum/ms13_pack/proc/fighting()
	for(var/mob/living/member as anything in members)
		if(member.ms13_in_fight())
			return TRUE
	return FALSE

/datum/ms13_pack/proc/fall_asleep()
	// Stragglers form packs of their own, so every sleeper lies inside the leader's wake area.
	for(var/mob/living/member as anything in members.Copy())
		if(member != leader && get_dist(member, leader) > MS13_PACK_RANGE)
			remove(member)
	asleep = TRUE
	for(var/mob/living/member as anything in members)
		member.ms13_set_asleep(TRUE)
	watch()

/datum/ms13_pack/proc/watch()
	watched_cells = SSspatial_grid.get_cells_in_range(leader, wake_range())
	for(var/datum/spatial_grid_cell/cell as anything in watched_cells)
		RegisterSignal(cell, SPATIAL_GRID_CELL_ENTERED(SPATIAL_GRID_CONTENTS_TYPE_HEARING), PROC_REF(on_cell_entered))
	// Someone may be inside its cells already, and will never cross into one.
	look_around()

/datum/ms13_pack/proc/unwatch()
	for(var/datum/spatial_grid_cell/cell as anything in watched_cells)
		UnregisterSignal(cell, SPATIAL_GRID_CELL_ENTERED(SPATIAL_GRID_CONTENTS_TYPE_HEARING))
	watched_cells = null
	visitors = null

/datum/ms13_pack/proc/on_cell_entered(datum/spatial_grid_cell/source, list/arrivals)
	SIGNAL_HANDLER
	if(!asleep)
		return
	var/noticed = FALSE
	for(var/mob/living/visitor in arrivals)
		if(visitor.client ? visitor.stat != DEAD : disturbed_by(visitor))
			if(!visitor.client)
				LAZYOR(visitors, visitor)
			noticed = TRUE
	if(noticed && !watching_closely)
		look_around()

/// Wakes if a player, or a hostile mob that came in, is in range. If one is only inside its cells, looks again shortly.
/datum/ms13_pack/proc/look_around()
	watching_closely = FALSE
	if(!asleep)
		return
	var/range = wake_range()
	var/someone_close = FALSE
	for(var/mob/living/player in SSspatial_grid.orthogonal_range_search(leader, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, range))
		if(player.stat == DEAD || player.z != leader.z)
			continue
		if(get_dist(player, leader) <= range)
			wake()
			return
		someone_close = TRUE
	for(var/mob/living/visitor as anything in visitors)
		// Gone, or wandered back out of its cells.
		if(QDELETED(visitor) || !disturbed_by(visitor) || get_dist(visitor, leader) > range + SPATIAL_GRID_CELLSIZE)
			LAZYREMOVE(visitors, visitor)
			continue
		if(get_dist(visitor, leader) <= range)
			wake()
			return
		someone_close = TRUE
	if(someone_close)
		watching_closely = TRUE
		addtimer(CALLBACK(src, PROC_REF(look_around)), MS13_PACK_WATCH_INTERVAL)
	else
		visitors = null

/datum/ms13_pack/proc/wake()
	if(!asleep)
		return
	asleep = FALSE
	quiet_passes = 0
	unwatch()
	leader.ms13_set_asleep(FALSE)
	var/delay = 0
	for(var/mob/living/member as anything in members)
		if(member == leader)
			continue
		delay += MS13_PACK_WAKE_STAGGER
		addtimer(CALLBACK(member, TYPE_PROC_REF(/mob/living, ms13_wake_with_pack)), delay)

/// A mob that wakes a sleeping pack by coming close: one of another faction, with its AI running.
/datum/ms13_pack/proc/disturbed_by(mob/living/visitor)
	if(visitor.stat == DEAD || visitor.ms13_pack == src || visitor.z != leader.z || !visitor.ms13_runs_ai())
		return FALSE
	return !faction_check(leader.faction, visitor.faction)

/// An awake follower that hasn't been hurt lately goes by the leader rather than looking around itself.
/datum/ms13_pack/proc/follows(mob/living/member)
	return !asleep && member != leader && leader.stat != DEAD && world.time > member.ms13_hurt_at + MS13_PACK_HURT_MEMORY

/// The leader's target, if it's a living one member is close enough to go for.
/datum/ms13_pack/proc/called_target(mob/living/member)
	var/atom/target = leader.ms13_current_target()
	if(QDELETED(target) || target.z != member.z || get_dist(member, target) > member.ms13_sight_range() + MS13_PACK_RANGE)
		return null
	var/mob/living/living_target = target
	if(istype(living_target) && living_target.stat == DEAD)
		return null
	return target

// Followers take the leader's target instead of scanning.
/datum/ai_behavior/find_potential_targets/perform(delta_time, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/pawn = controller.pawn
	if(!istype(pawn) || !pawn.ms13_pack?.follows(pawn))
		return ..()
	var/atom/target = pawn.ms13_pack.called_target(pawn)
	if(target)
		controller.set_blackboard_key(target_key, target)
	finish_action(controller, !!target)

// Idle followers trail the leader.
/datum/ai_behavior/idle_random_walk/perform(delta_time, datum/ai_controller/controller, ...)
	var/mob/living/pawn = controller.pawn
	var/datum/ms13_pack/pack = istype(pawn) ? pawn.ms13_pack : null
	if(!pack?.follows(pawn) || get_dist(pawn, pack.leader) <= MS13_PACK_RANGE - 2)
		return ..()
	var/move_dir = get_dir(pawn, pack.leader)
	controller.MovePawn(get_step(pawn, move_dir), move_dir)
	return BEHAVIOR_PERFORM_COOLDOWN | BEHAVIOR_PERFORM_SUCCESS

// The legacy hostile AI's per-tick look around, for followers.
/mob/living/simple_animal/hostile/ListTargets()
	if(!ms13_pack?.follows(src))
		return ..()
	var/atom/called = ms13_pack.called_target(src)
	return called ? list(called) : list()

SUBSYSTEM_DEF(ms13_packs)
	name = "Mob Packs"
	wait = 10 SECONDS
	// Unit tests run passes by hand, so mobs spawned for other tests aren't put to sleep under them.
#ifdef UNIT_TESTS
	flags = SS_BACKGROUND | SS_NO_INIT | SS_NO_FIRE
#else
	flags = SS_BACKGROUND | SS_NO_INIT
#endif
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/packs = list()

/datum/controller/subsystem/ms13_packs/stat_entry(msg)
	var/sleeping = 0
	for(var/datum/ms13_pack/pack as anything in packs)
		if(pack.asleep)
			sleeping++
	msg = "Packs:[length(packs)]|Asleep:[sleeping]"
	return ..()

/datum/controller/subsystem/ms13_packs/fire(resumed)
	for(var/mob/living/loner as anything in GLOB.mob_living_list)
		if(!loner.ms13_pack && loner.ms13_can_join_pack())
			join_or_found(loner)
	for(var/datum/ms13_pack/pack as anything in packs.Copy())
		if(!QDELETED(pack))
			pack.check()

/datum/controller/subsystem/ms13_packs/proc/join_or_found(mob/living/loner)
	for(var/datum/ms13_pack/pack as anything in packs)
		if(length(pack.members) < MS13_PACK_MAX_SIZE && pack.leader.z == loner.z && get_dist(pack.leader, loner) <= MS13_PACK_RANGE && faction_check(pack.leader.faction, loner.faction))
			pack.add(loner)
			return
	new /datum/ms13_pack(loner)

#undef MS13_PACK_RANGE
#undef MS13_PACK_STRAY_RANGE
#undef MS13_PACK_MAX_SIZE
#undef MS13_PACK_WAKE_MARGIN
#undef MS13_PACK_QUIET_PASSES
#undef MS13_PACK_HURT_MEMORY
#undef MS13_PACK_FIGHT_MEMORY
#undef MS13_PACK_STASIS
#undef MS13_PACK_WAKE_STAGGER
#undef MS13_PACK_WATCH_INTERVAL
