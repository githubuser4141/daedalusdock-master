/**
 * Creatures can't see through a closed hull: a rider is hidden from anyone outside unless the line between
 * them leaves the vehicle through an opening (see blocks_sight_from()). A moving or turning vehicle is loud
 * and hard to miss, though, so hostiles nearby re-aim at whoever they were after inside. Once it stops, they
 * fall back on their normal blind fire at the last spot they had.
 */

/// How long a moving vehicle keeps hostiles shooting at a rider they can't see.
#define MS13_AI_VEHICLE_MEMORY 6 SECONDS

/// Is target tucked inside a vehicle, out of viewer's sight through its hull?
/proc/ms13_hidden_in_vehicle(atom/target, atom/viewer)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(target)
	if(!vehicle || get_ms13_ground_vehicle_at(viewer) == vehicle)
		return FALSE
	return vehicle.blocks_sight_from(get_turf(target), get_turf(viewer))

/// can_see() that also respects vehicle hulls. Use it for AI line-of-sight decisions about a mob.
/proc/ms13_can_see(atom/viewer, atom/target, length = 5)
	return can_see(viewer, target, length) && !ms13_hidden_in_vehicle(target, viewer)

/datum/targeting_strategy/generic/can_attack(mob/living/pawn, atom/the_target, vision_range)
	if(!ignore_sight && ms13_hidden_in_vehicle(the_target, pawn))
		return FALSE
	return ..()

/// A hidden rider is treated as out of sight rather than unattackable, so blind fire still gets its chance.
/mob/living/simple_animal/hostile/ListTargets()
	. = ..()
	for(var/mob/living/rider in .)
		if(ms13_hidden_in_vehicle(rider, src))
			. -= rider

/// Tells hostiles within earshot where the riders they're after are now.
/datum/ms13_ground_vehicle/proc/alert_watchers()
	var/list/aboard = list()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/mob/living/rider in frame.loc)
			aboard += rider
	if(!length(aboard))
		return
	for(var/mob/living/watcher in hearers(MS13_AI_SIGHT_RANGE, pivot))
		if(watcher.stat == CONSCIOUS && !(watcher in aboard))
			watcher.notice_vehicle(src, aboard)

/mob/living/proc/notice_vehicle(datum/ms13_ground_vehicle/vehicle, list/aboard)
	return

/// Remembers a hostile rider's position, which the cover AI's suppressing fire (ms13_cover_ai.dm) shoots at.
/mob/living/basic/notice_vehicle(datum/ms13_ground_vehicle/vehicle, list/aboard)
	if(!ai_controller)
		return
	var/mob/living/quarry = ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!(quarry in aboard))
		quarry = null
		for(var/mob/living/rider as anything in aboard)
			if(rider.stat != DEAD && !faction_check(faction, rider.faction))
				quarry = rider
				break
	if(!quarry)
		return
	ai_controller.set_blackboard_key(BB_MS13_LAST_KNOWN_TURF, get_turf(quarry))
	ai_controller.set_blackboard_key(BB_MS13_SUPPRESS_UNTIL, world.time + MS13_AI_VEHICLE_MEMORY)

/// Keeps a robot's blind fire (_ranged_robot_ai.dm) aimed at its target as the vehicle carries it off.
/mob/living/simple_animal/hostile/ms13/robot/notice_vehicle(datum/ms13_ground_vehicle/vehicle, list/aboard)
	if(!(target in aboard))
		return
	blind_fire_turf = get_turf(target)
	blind_fire_until = world.time + blind_fire_duration

#undef MS13_AI_VEHICLE_MEMORY
