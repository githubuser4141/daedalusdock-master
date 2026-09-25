/**
 * Creatures can't see through a closed hull: a rider is hidden from anyone outside unless the line between
 * them leaves the vehicle through an opening (see blocks_sight_from()). A moving or turning vehicle is loud
 * and hard to miss, though, so hostiles nearby re-aim at whoever they were after inside. Once it stops, they
 * fall back on their normal blind fire at the last spot they had.
 *
 * Melee creatures, as in CDDA, don't give up on someone shut in a vehicle: they come at it, batter the panel
 * they're up against until it gives, and climb in through the hole or any open door. The noise of one driving
 * past draws them.
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

/// Is pawn a melee creature after quarry, who's in a vehicle pawn is outside of? It'll break its way in.
/proc/ms13_besieging(mob/living/pawn, atom/quarry)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(quarry)
	if(!vehicle || get_ms13_ground_vehicle_at(pawn) == vehicle || pawn.z != quarry.z || get_dist(pawn, quarry) > MS13_AI_SIGHT_RANGE)
		return FALSE
	return pawn.besieges(quarry)

/mob/living/proc/besieges(atom/quarry)
	return FALSE

/mob/living/simple_animal/hostile/besieges(atom/quarry)
	return quarry == target && !ranged

/mob/living/basic/besieges(atom/quarry)
	return ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == quarry && length(ai_controller.current_behaviors) && (locate(/datum/ai_behavior/basic_melee_attack) in ai_controller.current_behaviors)

/// The shut panel of quarry's vehicle that attacker is up against, nearest quarry: what it breaks in through.
/proc/ms13_breach_panel(mob/living/attacker, atom/quarry)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(quarry)
	var/turf/here = get_turf(attacker)
	if(!vehicle || !here)
		return
	var/closest = INFINITY
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(here, direction)
		if(!vehicle.get_frame_at(beside) || get_dist(beside, quarry) >= closest)
			continue
		for(var/obj/structure/window/ms13_vehicle_wall/wall in beside)
			if(wall.density && wall.dir == turn(direction, 180))
				closest = get_dist(beside, quarry)
				. = wall

/datum/targeting_strategy/generic/can_attack(mob/living/pawn, atom/the_target, vision_range)
	// Out of sight and reach, but it knows where they went.
	if(isliving(the_target) && ms13_besieging(pawn, the_target))
		return should_attack_mob(pawn, pawn.ai_controller, the_target)
	if(!ignore_sight && ms13_hidden_in_vehicle(the_target, pawn))
		return FALSE
	return ..()

/// The panel in the way is where they're hiding, as a locker would be.
/datum/targeting_strategy/find_hidden_mobs(mob/living/living_mob, atom/target)
	return (ms13_besieging(living_mob, target) && ms13_breach_panel(living_mob, target)) || ..()

/// Every plan, it goes for the panel it's up against, and once that's down, for its target.
/datum/ai_behavior/basic_melee_attack/setup(datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/obj/structure/window/ms13_vehicle_wall/panel = ms13_besieging(controller.pawn, controller.blackboard[target_key]) && ms13_breach_panel(controller.pawn, controller.blackboard[target_key])
	if(panel)
		controller.set_blackboard_key(hiding_location_key, panel)
	else if(istype(controller.blackboard[hiding_location_key], /obj/structure/window/ms13_vehicle_wall))
		controller.clear_blackboard_key(hiding_location_key)
	return ..()

/// A hidden rider is treated as out of sight rather than unattackable, so blind fire still gets its chance.
/mob/living/simple_animal/hostile/ListTargets()
	. = ..()
	for(var/mob/living/rider in .)
		if(ms13_hidden_in_vehicle(rider, src) && !ms13_besieging(src, rider))
			. -= rider

/mob/living/simple_animal/hostile/DestroyPathToTarget()
	var/obj/structure/window/ms13_vehicle_wall/panel = ms13_besieging(src, target) && ms13_breach_panel(src, target)
	if(!panel)
		return ..()
	face_atom(panel)
	panel.attack_animal(src)

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

/// A melee creature with nobody to fight comes after whoever's making the racket.
/mob/living/simple_animal/hostile/notice_vehicle(datum/ms13_ground_vehicle/vehicle, list/aboard)
	if(target || ranged || client || AIStatus == AI_OFF)
		return
	for(var/mob/living/rider as anything in aboard)
		if(CanAttack(rider))
			GiveTarget(rider)
			if(AIStatus == AI_IDLE)
				toggle_ai(AI_ON)
			return

/// Remembers a hostile rider's position, which the cover AI's suppressing fire (ms13_cover_ai.dm) shoots at. With nobody
/// to fight, it goes after them.
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
	if(!ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
		ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, quarry)
	ai_controller.set_blackboard_key(BB_MS13_LAST_KNOWN_TURF, get_turf(quarry))
	ai_controller.set_blackboard_key(BB_MS13_SUPPRESS_UNTIL, world.time + MS13_AI_VEHICLE_MEMORY)

/// Keeps a robot's blind fire (_ranged_robot_ai.dm) aimed at its target as the vehicle carries it off.
/mob/living/simple_animal/hostile/ms13/robot/notice_vehicle(datum/ms13_ground_vehicle/vehicle, list/aboard)
	if(!(target in aboard))
		return
	blind_fire_turf = get_turf(target)
	blind_fire_until = world.time + blind_fire_duration

#undef MS13_AI_VEHICLE_MEMORY

#ifdef UNIT_TESTS
/datum/unit_test/ms13_vehicle_besieged
	name = "VEHICLES: Melee Creatures Batter Their Way Into A Vehicle"

/datum/unit_test/ms13_vehicle_besieged/Run()
	// Out past the test room, clear of the sedan test's car.
	var/turf/front_left = locate(run_loc_floor_top_right.x + 12, run_loc_floor_top_right.y + 12, run_loc_floor_top_right.z)
	var/obj/structure/ms13_vehicle_frame/udp_car/sedan/car = ms13_build_vehicle(/obj/structure/ms13_vehicle_frame/udp_car/sedan, front_left, NORTH)
	var/datum/ms13_ground_vehicle/vehicle = car.vehicle
	var/obj/structure/ms13_vehicle_frame/rear_left = car.tiles["4,1"]
	var/obj/structure/ms13_vehicle_frame/rear_right = car.tiles["4,3"]
	var/obj/structure/window/ms13_vehicle_wall/solid/door/left_door
	var/obj/structure/window/ms13_vehicle_wall/solid/door/right_door
	for(var/obj/structure/window/ms13_vehicle_wall/solid/door/door in vehicle.walls)
		door.close()
		if(door.loc == rear_left.loc && door.dir == WEST)
			left_door = door
		if(door.loc == rear_right.loc && door.dir == EAST)
			right_door = door
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent, get_turf(rear_left))
	var/rider_health = rider.health

	// The old AI: it keeps after its rider and batters the door it's up against.
	var/mob/living/simple_animal/hostile/ms13/mongrel/dog = allocate(/mob/living/simple_animal/hostile/ms13/mongrel, get_step(rear_left, WEST))
	dog.faction = list("test_hostile")
	dog.GiveTarget(rider)
	dog.toggle_ai(AI_ON)
	var/left_before = left_door.get_integrity()
	dog.handle_automated_action()
	if(dog.target != rider || left_door.get_integrity() >= left_before || rider.health < rider_health)
		Fail("A creature shut out of a car didn't keep after its rider and batter the door in its way: target [dog.target], door [left_before] to [left_door.get_integrity()], rider [rider_health] to [rider.health].")

	// The new AI: the door's where its rider is hiding, until it's down.
	var/mob/living/basic/ms13/ghoul/ghoul = allocate(/mob/living/basic/ms13/ghoul, get_step(rear_right, EAST))
	var/datum/ai_controller/controller = ghoul.ai_controller
	var/melee_type = /datum/ai_behavior/basic_melee_attack/ms13/ghoul
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, rider)
	for(var/plan in 1 to 2)
		controller.queue_behavior(melee_type, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	if(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION] != right_door)
		Fail("A ghoul shut out of a car didn't go for the door in its way.")
	var/datum/ai_behavior/melee = GET_AI_BEHAVIOR(melee_type)
	var/right_before = right_door.get_integrity()
	melee.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	if(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] != rider || right_door.get_integrity() >= right_before || rider.health < rider_health)
		Fail("A ghoul shut out of a car gave up on its rider, or didn't batter the door: target [controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]], door [right_before] to [right_door.get_integrity()], rider [rider_health] to [rider.health].")
	qdel(right_door)
	controller.queue_behavior(melee_type, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	if(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION] || controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] != rider)
		Fail("With the door down, a ghoul didn't go on in for its rider.")
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames.Copy())
		qdel(frame)
#endif
