#ifndef MS13_SQUAD_DEMOLITION_INCLUDED
#define MS13_SQUAD_DEMOLITION_INCLUDED

// Charges own the hazard, so deleting their planter cannot make squadmates ignore it.
GLOBAL_LIST_EMPTY(ms13_squad_charges)

/obj/item/grenade/c4
	var/turf/ms13_breach_origin
	var/ms13_breach_radius = 0
	var/datum/weakref/ms13_breach_user

/obj/item/grenade/c4/Destroy()
	GLOB.ms13_squad_charges -= src
	ms13_breach_origin = null
	ms13_breach_user = null
	return ..()

/mob/living/carbon/human/ms13_squad
	var/datum/weakref/breach_charge
	var/turf/blast_escape
	var/next_blast_escape = 0

/mob/living/carbon/human/ms13_squad/Destroy()
	clear_breach()
	blast_escape = null
	return ..()

/proc/ms13_demolition_target(atom/target, explosive = FALSE)
	if(QDELETED(target) || (target.resistance_flags & INDESTRUCTIBLE))
		return FALSE
	if(explosive && isclosedturf(target))
		return TRUE
	if(!istype(target, /obj/structure) && !istype(target, /obj/machinery))
		return FALSE
	var/obj/object = target
	return isturf(object.loc) && object.uses_integrity && object.get_integrity() > 0 && (!explosive || object.anchored)

/mob/living/carbon/human/ms13_squad/proc/destroy_object(obj/target)
	if(!ms13_demolition_target(target))
		set_order("Guard", get_turf(src))
		order_status = "Object destroyed or no longer a valid target"
		return
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	if(!brain.approach(target, target.IsReachableBy(src) ? 1 : 0) || !target.IsReachableBy(src))
		order_status = "Approaching object"
		return
	var/obj/item/tool
	var/best_damage = 0
	for(var/obj/item/candidate as anything in get_all_contents_type(/obj/item))
		if((candidate.loc != src && (candidate.loc?.loc != src || !candidate.loc.atom_storage)) || candidate.item_flags & (NOBLUDGEON|ABSTRACT) || istype(candidate, /obj/item/gun))
			continue
		var/damage = target.run_atom_armor(candidate.force, candidate.damtype, BLUNT)
		if(damage > best_damage)
			tool = candidate
			best_damage = damage
	if(!tool)
		brain.stop_travel()
		order_status = "Needs a stronger melee tool; Breach uses explosives"
		return
	if(!ready_item(tool))
		order_status = "Needs a free hand for [tool.name]"
		return
	var/old_integrity = target.get_integrity()
	// Explicit destruction must hit, not open a welder menu or fire a point-blank gun.
	tool.attack_obj(target, src)
	if(QDELETED(target) || target.is_destroyed())
		set_order("Guard", get_turf(src))
		order_status = "Object destroyed"
	else if(target.get_integrity() < old_integrity)
		order_deadline = world.time + 45 SECONDS
		order_status = "Destroying [target.name] ([round(target.get_integrity_percentage())]% remaining)"
	else
		order_status = "Tool did no damage; check target protection"

/// Only known, finite explosive payloads; no improvised grenade guessing.
/mob/living/carbon/human/ms13_squad/proc/carried_breach_charge()
	for(var/obj/item/grenade/c4/charge as anything in get_all_contents_type(/obj/item/grenade/c4))
		if(!(charge.type in list(/obj/item/grenade/c4, /obj/item/grenade/c4/x4, /obj/item/grenade/c4/ms13/shaped)))
			continue
		if(charge.active || charge.target || charge.dud_flags || charge.shrapnel_type || HAS_TRAIT(charge, TRAIT_NODROP))
			continue
		if(charge.loc == src || (charge.loc?.loc == src && charge.loc.atom_storage))
			return charge

/mob/living/carbon/human/ms13_squad/proc/clear_breach()
	var/obj/item/grenade/c4/charge = breach_charge?.resolve()
	if(charge && !charge.active)
		GLOB.ms13_squad_charges -= charge
		charge.ms13_breach_origin = null
		charge.ms13_breach_user = null
	breach_charge = null

/// A short, real A* route to the nearest reachable tile beyond the entire blast.
/mob/living/carbon/human/ms13_squad/proc/find_blast_escape(turf/origin, radius)
	var/list/candidates = list()
	for(var/turf/open/tile in RANGE_TURFS(radius + 1, origin))
		if(get_dist(tile, origin) == radius + 1 && !tile.is_blocked_turf(source_atom = src))
			candidates += tile
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	// ponytail: bounded ring searches suit small squads; batch path searches for mass deployments.
	while(length(candidates))
		var/turf/nearest = get_closest_atom(/turf, candidates, src)
		candidates -= nearest
		if(length(SSpathfinder.astar_pathfind_now(src, nearest, max_steps = 40, mintargetdist = 0, access = brain.get_access(), use_diagonals = FALSE)))
			return nearest

/// Existing orders resume after the hazard clears; even Hold cannot strand a planter at a live charge.
/mob/living/carbon/human/ms13_squad/proc/avoid_breaches()
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	var/obj/item/grenade/c4/own_charge = breach_charge?.resolve()
	if(breach_charge && (!own_charge || (!own_charge.active && own_charge.target)))
		clear_breach()
		if(squad_order == "Breach")
			set_order("Guard", get_turf(src))
			order_status = own_charge ? "Charge failed to detonate; do not approach" : "Breach detonated; guarding here"
	for(var/obj/item/grenade/c4/charge as anything in GLOB.ms13_squad_charges)
		var/turf/origin = charge.ms13_breach_origin
		if(!origin || origin.z != z || (!charge.active && charge.ms13_breach_user?.resolve() == src))
			continue
		var/atom/destination = order_target?.resolve()
		if(get_dist(src, origin) > charge.ms13_breach_radius)
			if(charge == own_charge || (destination?.z == z && get_dist(destination, origin) <= charge.ms13_breach_radius))
				brain.stop_travel()
				order_status = "Holding clear of breaching charge"
				return TRUE
			continue
		if(istype(buckled, /obj/structure/chair/ms13_vehicle_seat))
			buckled.user_unbuckle_mob(src, src)
		if(world.time >= next_blast_escape)
			next_blast_escape = world.time + 2 SECONDS
			blast_escape = find_blast_escape(origin, charge.ms13_breach_radius)
		if(blast_escape && get_dist(blast_escape, origin) > charge.ms13_breach_radius)
			brain.approach(blast_escape, 0)
			order_status = "Clearing breaching charge"
		else
			brain.stop_travel()
			order_status = "No escape route from charge"
		return TRUE
	return FALSE

/mob/living/carbon/human/ms13_squad/proc/breach_ready(serial, obj/item/grenade/c4/charge, atom/target)
	if(client || stat != CONSCIOUS || order_serial != serial || squad_order != "Breach" || order_target?.resolve() != target || !ms13_demolition_target(target, TRUE) || get_turf(target) != charge.ms13_breach_origin)
		return FALSE
	for(var/mob/living/occupant in range(charge.ms13_breach_radius, charge.ms13_breach_origin))
		if(occupant != src && occupant.stat != DEAD && (squad_friendly(occupant) || faction_check_atom(occupant)))
			return FALSE
	return TRUE

/mob/living/carbon/human/ms13_squad/proc/breach_target(atom/target)
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	if(!ms13_demolition_target(target, TRUE))
		set_order("Guard", get_turf(src))
		order_status = "Breach target gone or no longer anchored"
		return
	var/obj/item/grenade/c4/charge = carried_breach_charge()
	if(!charge)
		brain.stop_travel()
		clear_breach()
		order_status = "Needs a usable C4, X4 or shaped charge"
		return
	if(!brain.approach(target, 1) || !target.IsReachableBy(src))
		order_status = "Approaching breach"
		return
	if(!ready_item(charge))
		order_status = "Needs a free hand for the charge"
		return
	var/radius = max(charge.boom_sizes[1], charge.boom_sizes[2], charge.boom_sizes[3], charge.ex_dev, charge.ex_heavy, charge.ex_light, charge.ex_flame) + (charge.directional ? 2 : 0)
	if(istype(charge, /obj/item/grenade/c4/ms13/shaped))
		var/obj/item/grenade/c4/ms13/shaped/shaped = charge
		radius = max(radius, shaped.jet_range + 8) // Include the jet's breakup fragments.
	if(radius > 16)
		order_status = "Payload exceeds supported breach clearance"
		return
	var/turf/origin = get_turf(target)
	blast_escape = find_blast_escape(origin, radius)
	if(!blast_escape)
		clear_breach()
		order_status = "No safe retreat route; charge not armed"
		return
	if(breach_charge?.resolve() != charge)
		clear_breach()
		breach_charge = WEAKREF(charge)
		charge.ms13_breach_user = WEAKREF(src)
		charge.ms13_breach_origin = origin
		charge.ms13_breach_radius = radius
		GLOB.ms13_squad_charges |= charge
		say("Breaching [target.name]. Clear at least [radius + 1] tiles!", forced = "squad order")
	if(!breach_ready(order_serial, charge, target))
		order_status = "Waiting for friendlies to clear [radius + 1] tiles"
		return
	var/list/escape_path = SSpathfinder.astar_pathfind_now(src, blast_escape, max_steps = 40, mintargetdist = 0, access = brain.get_access(), use_diagonals = FALSE)
	if(!length(escape_path))
		order_status = "Retreat route blocked; charge not armed"
		return
	// Respect slow/injured movement and retain longer player-configured fuses.
	charge.det_time = clamp(max(charge.det_time, 20, CEILING(length(escape_path) * brain.get_movement_delay() / 10, 1) + 15), charge.minimum_timer, charge.maximum_timer)
	charge.aim_dir = get_dir(src, target)
	order_status = "Planting charge"
	var/serial = order_serial
	if(charge.plant_c4(target, src, CALLBACK(src, PROC_REF(breach_ready), serial, charge, target)))
		say("Charge live! [charge.det_time] seconds!", forced = "squad order")
		avoid_breaches()
	else if(order_serial == serial)
		order_status = "Planting interrupted; waiting to retry safely"

#endif
