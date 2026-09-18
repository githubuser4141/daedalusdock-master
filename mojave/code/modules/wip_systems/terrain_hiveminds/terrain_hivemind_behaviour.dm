// Focused extensions kept separate from the framework so variant balance can be tuned independently.

/datum/ms13_terrain_hivemind
	/// A corpse delivered to a core or converter permanently expands the network's storage.
	var/corpse_capacity_value = 5

/datum/ms13_terrain_hivemind/advance_corpse_conversion(mob/living/corpse, datum/converter, delta_time, conversion_time, claim = TRUE)
	var/atom/delivery_structure = istype(converter, /obj/structure/ms13_hivemind) ? converter : null
	var/old_unit_count = length(units)
	. = ..()
	if(!. || !delivery_structure)
		return
	max_resources += corpse_capacity_value
	if(length(units) > old_unit_count)
		delivery_structure.visible_message(span_notice("[delivery_structure] consumes the remains, expands the hive's biomass reserve, and births a new unit."))
	else
		delivery_structure.visible_message(span_notice("[delivery_structure] consumes the remains, increasing the hive's biomass capacity and stored resources."))

/datum/ms13_terrain_hivemind/find_reported_corpse(atom/seeker)
	. = ..()
	if(istype(seeker, /mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter) && . && get_dist(seeker, .) > 14)
		return null

/datum/ms13_terrain_hivemind/eris/New(turf/start, new_territory_limit)
	. = ..()
	unit_appearances["suicide"] = list(
		"name" = "hivemind bomber",
		"icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi',
		"state" = "bomber",
	)
	evolved_mob_types |= /mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide

/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	var/force_opens_doors = TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout
	force_opens_doors = FALSE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter
	terrain_recovery_health = 0.4
	terrain_recovery_range = 12
	force_opens_doors = FALSE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/handle_automated_action()
	set waitfor = FALSE
	if(AIStatus == AI_OFF || !network?.active)
		return FALSE
	// Once committed, keep still long enough to make progress unless survival is genuinely urgent.
	if(health > maxHealth * 0.25 && has_adjacent_conversion_target())
		clear_roam_target()
		return TRUE
	if(handle_converter_recovery())
		return TRUE
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/handle_corpse_work()
	var/mob/living/corpse = corpse_target_ref?.resolve()
	if(corpse && get_dist(src, corpse) <= 1 && LAZYLEN(corpse.grabbed_by))
		clear_corpse_task()
		return FALSE
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/pick_roam_target()
	if(!isturf(loc) || roam_range <= 0)
		return
	var/list/candidates = list()
	for(var/obj/structure/ms13_hivemind/terrain/growth as anything in network.territory)
		var/turf/candidate = get_turf(growth)
		var/distance = get_dist(src, candidate)
		if(distance >= roam_min_distance && distance <= roam_range)
			candidates += candidate
	if(length(candidates))
		return pick(candidates)
	var/obj/structure/ms13_hivemind/terrain/closest = get_closest_atom(/obj/structure/ms13_hivemind/terrain, network.territory, src)
	return get_turf(closest)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/proc/has_adjacent_conversion_target()
	var/mob/living/corpse = corpse_target_ref?.resolve()
	if(!network?.is_convertible_corpse(corpse) || get_dist(src, corpse) > 1 || LAZYLEN(corpse.grabbed_by))
		return FALSE
	var/datum/current_claim = network.get_corpse_claim(corpse)
	return !current_claim || current_claim == src

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/proc/handle_converter_recovery()
	if(network.is_territory(get_turf(src)) || health > maxHealth * terrain_recovery_health)
		return FALSE
	var/obj/structure/ms13_hivemind/terrain/growth = get_closest_atom(/obj/structure/ms13_hivemind/terrain, network.territory, src)
	if(!growth || get_dist(src, growth) > terrain_recovery_range)
		return FALSE
	LoseTarget()
	clear_corpse_task()
	clear_roam_target()
	Goto(growth, move_to_delay, 0)
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide
	unit_role = "suicide"
	evolution_rank = 2
	health_multiplier = 0.8
	damage_multiplier = 0.5
	corpse_hauler = FALSE
	move_to_delay = 2
	roam_range = 18
	roam_min_distance = 8

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide/AttackingTarget(atom/attacked_target)
	var/atom/victim = attacked_target
	if(!victim)
		victim = target
	if(!victim || get_dist(src, victim) > 1)
		return ..()
	var/turf/origin = get_turf(src)
	var/attack_direction = get_dir(src, victim)
	if(!attack_direction)
		attack_direction = dir
	var/jet_angle = dir2angle(attack_direction)
	visible_message(span_danger("[src] ruptures in a focused blast!"))
	explosion(origin, devastation_range = -1, heavy_impact_range = -1, light_impact_range = 1, adminlog = FALSE, explosion_cause = src)
	ms13_fire_shaped_charge_jet(origin, jet_angle, 48, 150, 5, 4, src)
	qdel(src)
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/DestroyObjectsInDirection(direction)
	if(force_opens_doors)
		var/atom/target_from = GET_TARGETS_FROM(src)
		var/turf/next_turf = get_step(target_from, direction)
		if(next_turf?.Adjacent(target_from))
			for(var/obj/machinery/door/door in next_turf)
				if(door.density && door.Adjacent(target_from) && try_force_open_door(door))
					return
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/try_force_open_door(obj/machinery/door/door)
	if(!force_opens_doors || !door?.density || istype(door, /obj/machinery/door/airlock/ms13))
		return FALSE
	var/opened
	if(istype(door, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = door
		opened = airlock.open(2)
	else
		opened = door.open()
	if(opened)
		visible_message(span_warning("[src] forces [door] open!"))
	return opened
