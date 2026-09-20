/**
 * What's under a vehicle stays there. Anything a vehicle rolls on top of is underneath: hidden by the floor,
 * out of reach of the crew, and left behind as the vehicle drives on. Only things that are actually aboard move
 * with it.
 *
 * The floor and hull also stand between the crew and a blast that starts outside the cabin, taking the frame's
 * explosion_block off the blast's power (the same way DD's explosions lose power crossing any obstacle). Only a
 * blast with power left over reaches the people inside.
 */
/datum/ms13_ground_vehicle
	/// Things the vehicle is sitting on top of, to their own invisibility before they were covered.
	var/list/underneath = list()

/// Is thing riding in this vehicle, as opposed to being part of it or lying on the ground under it?
/datum/ms13_ground_vehicle/proc/is_aboard(atom/movable/thing)
	if(QDELETED(thing) || !thing.simulated || (thing in underneath) || (thing in frames) || (thing in walls) || (thing in parts))
		return FALSE
	return !thing.anchored || istype(thing, /obj/structure/chair/ms13_vehicle_seat)

/// Is thing inside the hull, where the floor shields it from blasts below? Running gear hangs outside.
/datum/ms13_ground_vehicle/proc/is_sheltered(atom/movable/thing)
	if(thing in parts)
		return !istype(thing, /obj/structure/ms13_vehicle_part/running_gear)
	return is_aboard(thing)

/// Blast power the hull strips before a blast from epicenter reaches the cabin at cabin_turf. From underneath
/// it meets the floor; from outside it meets the hull, if the tile is closed up.
/datum/ms13_ground_vehicle/proc/blast_shielding(turf/cabin_turf, turf/epicenter)
	var/obj/structure/ms13_vehicle_frame/frame = get_frame_at(cabin_turf)
	if(!frame)
		return 0
	if(get_frame_at(epicenter) || is_weather_sealed(frame))
		return frame.explosion_block
	return 0

/// Called after the vehicle moves or turns: covers whatever it rolled onto and uncovers what it left.
/datum/ms13_ground_vehicle/proc/can_run_over(mob/living/victim)
	return !victim.buckled && !victim.anchored && (victim.body_position == LYING_DOWN || victim.stat == DEAD)

/datum/ms13_ground_vehicle/proc/update_underneath(list/manifest)
	uncover_exposed()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/atom/movable/thing as anything in frame.loc)
			if(manifest[thing])
				continue
			if(isliving(thing))
				var/mob/living/victim = thing
				if(!can_run_over(victim))
					continue
				if(!(victim in underneath))
					cover(victim)
				// No corpse processing for either NPC framework; never explicitly gib a victim.
				if(victim.stat != DEAD || (!isanimal(victim) && !isbasicmob(victim)))
					victim.apply_damage((ram_damage_base * 3) + ram_damage_per_speed * max(speed, 1), BRUTE, BODY_ZONE_CHEST) // gonna stick a 3x here
				continue
			if(!thing.simulated || (thing in underneath))
				continue
			if((thing in frames) || (thing in walls) || (thing in parts))
				continue
			cover(thing)

/datum/ms13_ground_vehicle/proc/uncover_exposed()
	for(var/atom/movable/thing as anything in underneath)
		if(!get_frame_at(thing.loc))
			uncover(thing)

/datum/ms13_ground_vehicle/proc/cover(atom/movable/thing)
	underneath[thing] = thing.invisibility
	thing.invisibility = INVISIBILITY_ABSTRACT
	if(isliving(thing))
		ADD_TRAIT(thing, TRAIT_FLOORED, REF(src))
		var/mob/living/victim = thing
		if(victim.client)
			set_roof_visible(victim.client, TRUE)
			victim.clear_ms13_vehicle_interior_mask()
	RegisterSignal(thing, COMSIG_MOVABLE_MOVED, PROC_REF(on_underneath_moved))
	RegisterSignal(thing, COMSIG_PARENT_QDELETING, PROC_REF(on_underneath_deleted))

/datum/ms13_ground_vehicle/proc/uncover(atom/movable/thing)
	thing.invisibility = underneath[thing]
	underneath -= thing
	if(isliving(thing))
		REMOVE_TRAIT(thing, TRAIT_FLOORED, REF(src))
	UnregisterSignal(thing, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))

/// Blown or dragged out from under the vehicle.
/datum/ms13_ground_vehicle/proc/on_underneath_moved(atom/movable/thing)
	SIGNAL_HANDLER
	if(!get_frame_at(thing.loc))
		uncover(thing)

/datum/ms13_ground_vehicle/proc/on_underneath_deleted(atom/movable/thing)
	SIGNAL_HANDLER
	underneath -= thing

/// Sets off armed mines the vehicle has just rolled onto. Done once everything has moved, so the blast finds
/// the crew where they now are.
/datum/ms13_ground_vehicle/proc/crush_mines()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames.Copy())
		if(QDELETED(frame))
			continue
		for(var/obj/effect/mine/mine in frame.loc)
			if(mine.armed && !mine.triggered)
				mine.triggermine(frame)

/// Is thing inside some vehicle's hull? Explosions don't throw it about.
/proc/ms13_sheltered_in_vehicle(atom/movable/thing)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(thing)
	return vehicle?.is_sheltered(thing)

/// The vehicle whose cabin origin is exploding in, if any. A blast there skips the hull.
/proc/ms13_exploding_cabin(atom/origin)
	if(!ismovable(origin))
		return null
	var/atom/movable/exploding = get_atom_on_turf(origin)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(exploding)
	return vehicle?.is_sheltered(exploding) ? vehicle : null

/// A blast wears the hull down by how hard it hits, rather than deleting it outright.
/proc/ms13_vehicle_blast_damage(obj/piece, severity)
	if(QDELETED(piece))
		return
	switch(severity)
		if(EXPLODE_DEVASTATE)
			piece.take_damage(rand(250, 500), BRUTE, BOMB, FALSE)
		if(EXPLODE_HEAVY)
			piece.take_damage(rand(100, 250), BRUTE, BOMB, FALSE)
		if(EXPLODE_LIGHT)
			piece.take_damage(rand(10, 90), BRUTE, BOMB, FALSE)

/obj/structure/ms13_vehicle_frame/ex_act(severity, target)
	ms13_vehicle_blast_damage(src, severity)

/obj/structure/window/ms13_vehicle_wall/ex_act(severity, target)
	ms13_vehicle_blast_damage(src, severity)

/obj/structure/ms13_vehicle_part/ex_act(severity, target)
	ms13_vehicle_blast_damage(src, severity)

/// Whatever arrives on a mine under a vehicle is the vehicle or rides in it; crush_mines() handles the vehicle.
/obj/effect/mine/on_entered(datum/source, atom/movable/AM)
	if(get_ms13_ground_vehicle_at(src))
		return
	return ..()
