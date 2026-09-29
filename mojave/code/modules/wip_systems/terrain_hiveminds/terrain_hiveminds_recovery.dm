// Strain tuning, persistent bodies, and shared progress tracking for every hive task.
/datum/ms13_terrain_hivemind/proc/get_strain_stats(mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit_type)
	return strain_stats?[initial(unit_type.strain_key) || initial(unit_type.unit_role)]

/datum/ms13_terrain_hivemind/proc/get_unit_cost(unit_type)
	var/list/stats = get_strain_stats(unit_type)
	if(!isnull(stats?["cost"]))
		return stats["cost"]
	return unit_type == converter_mob_type ? converter_unit_cost : unit_cost

/// Repairing an existing body costs a quarter of making that strain from a new host.
/datum/ms13_terrain_hivemind/proc/get_unit_revival_cost(unit_type)
	var/list/stats = get_strain_stats(unit_type)
	return max(0, isnull(stats?["revive_cost"]) ? CEILING(get_unit_cost(unit_type) / 4, 1) : stats["revive_cost"])

/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	var/revivable_hive_corpse = FALSE
	var/hive_reanimate_after = 0
	var/hive_corpse_damage = 0
	/// Extra damage after death required to destroy the body permanently.
	var/hive_corpse_damage_limit = 75
	var/datum/weakref/hive_route_goal
	var/list/hive_route_tiles = list()
	var/hive_route_progress_at = 0
	var/list/hive_failed_goals = list()
	var/turf/hive_last_seen_turf
	var/hive_last_seen_at = 0
	/// Do not spend a whole hunt chipping a barrier down or fighting its repairs.
	var/hive_max_breach_hits = 50
	var/datum/weakref/hive_breach_target
	var/hive_breach_hits = 0

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_network_lost()
	SIGNAL_HANDLER
	clear_corpse_task()
	clear_roam_target()
	prying_door_ref = null
	LoseTarget()
	network = null

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/on_stamina_update()
	. = ..()
	if(!isnull(hive_move_delay))
		move_to_delay = hive_move_delay + stamina.loss * 0.06

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/adjustHealth(amount, updating_health = TRUE, forced = FALSE)
	if(stat == DEAD && revivable_hive_corpse && amount > 0)
		if(!forced && (status_flags & GODMODE))
			return FALSE
		hive_corpse_damage += amount
		if(hive_corpse_damage >= hive_corpse_damage_limit)
			visible_message(span_danger("[src]'s remains are smashed apart!"))
			gib()
		return amount
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/revive(full_heal = FALSE, admin_revive = FALSE)
	. = ..()
	if(!. || !revivable_hive_corpse)
		return
	hive_corpse_damage = 0
	set_lying_angle(0)
	if(network?.active)
		network.units |= src
	START_PROCESSING(SSobj, src)
	consider_wakeup()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/examine(mob/user)
	. = ..()
	if(stat == DEAD && revivable_hive_corpse)
		. += span_warning("Its body is still intact enough for the hive to reanimate. Destroy the remains to stop it rising again.")

/// Remember failed work briefly, so acquisition doesn't immediately choose the same inaccessible target.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_goal_blocked(atom/goal)
	for(var/datum/weakref/failed as anything in hive_failed_goals)
		if(!failed.resolve() || hive_failed_goals[failed] <= world.time)
			hive_failed_goals -= failed
	return goal && hive_failed_goals[WEAKREF(goal)] > world.time

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_avoid_goal(atom/goal)
	if(!goal)
		return
	hive_goal_blocked(goal) // Prune expired entries before adding another.
	hive_failed_goals[WEAKREF(goal)] = world.time + 30 SECONDS
	// ponytail: remember eight recent failures per unit; a shared route cache is unnecessary at this population cap.
	if(length(hive_failed_goals) > 8)
		hive_failed_goals.Cut(1, 2)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_abandon_route(atom/goal)
	hive_avoid_goal(goal)
	SSmove_manager.stop_looping(src)
	hive_route_goal = null
	hive_route_tiles.Cut()
	hive_z_waypoint = null
	hive_z_connector = null
	prying_door_ref = null
	if(target == goal)
		LoseTarget()
	var/mob/living/corpse = corpse_target_ref?.resolve()
	if(corpse == goal)
		clear_corpse_task()
	// A failed delivery destination is skipped next tick while the hauler tries another converter.
	else if(corpse && istype(goal, /obj/structure/ms13_hivemind) && ++corpse_route_failures >= 3)
		// Bound the entire haul too: old destination cooldowns may expire while trying several alternatives.
		hive_avoid_goal(corpse)
		clear_corpse_task()
	if(roam_target == goal)
		clear_roam_target()
		COOLDOWN_START(src, roam_retry_cooldown, 2 SECONDS)

/// New tiles and effective breaches are progress. Repeated shuffling around a blockage is not.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_route_ready(atom/goal)
	if(!goal || hive_goal_blocked(goal))
		return FALSE
	if(hive_route_goal?.resolve() != goal)
		hive_route_goal = WEAKREF(goal)
		hive_route_tiles.Cut()
		hive_route_progress_at = world.time
	var/turf/here = get_turf(src)
	if(!(here in hive_route_tiles))
		hive_route_tiles += here
		hive_route_progress_at = world.time
		// Bound memory without abandoning a legitimate long journey.
		if(length(hive_route_tiles) > 128)
			hive_route_tiles.Cut(1, 65)
	if(world.time - hive_route_progress_at >= 10 SECONDS)
		hive_abandon_route(goal)
		return FALSE
	return TRUE

/// Test the same armor/deflection as attack_animal, including native wall-smash exceptions.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/can_hive_damage_obstacle(atom/obstacle, damage, ramming = FALSE, last_resort = FALSE)
	if(!obstacle || QDELETED(obstacle) || (!last_resort && !obstacle.density) || istype(obstacle, /turf/closed/indestructible) || (obstacle.resistance_flags & INDESTRUCTIBLE) || hive_goal_blocked(obstacle))
		return FALSE
	var/obj/item/item = obstacle
	if(istype(item) && !(item.obj_flags & CAN_BE_HIT))
		return FALSE
	var/obj/structure/ms13_hivemind/friendly = obstacle
	if(istype(friendly) && friendly.network == network)
		return FALSE
	if(isnull(damage))
		damage = obj_damage || melee_damage_upper
	if(ismineralturf(obstacle))
		if(!ramming && (environment_smash & (ENVIRONMENT_SMASH_WALLS | ENVIRONMENT_SMASH_RWALLS)))
			return TRUE
		var/turf/closed/mineral/random/ms13/rock = obstacle
		return istype(rock) && (melee_damage_type in list(BRUTE, BURN)) && damage >= max(rock.damage_deflection, DAMAGE_PRECISION) && (last_resort || rock.mining_health <= damage * hive_max_breach_hits)
	if(!ramming)
		var/turf/closed/wall/wall = obstacle
		if(istype(wall))
			if(environment_smash & ENVIRONMENT_SMASH_RWALLS)
				return TRUE
			if(wall.hard_decon && environment_smash)
				return FALSE
			if(!wall.hard_decon && (environment_smash & ENVIRONMENT_SMASH_WALLS))
				return TRUE
	if(!obstacle.uses_integrity)
		return FALSE
	var/effective_damage = obstacle.run_atom_armor(damage, melee_damage_type, BLUNT, get_dir(obstacle, src), armor_penetration)
	return effective_damage >= DAMAGE_PRECISION && (last_resort || obstacle.get_integrity() <= effective_damage * hive_max_breach_hits)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/CanSmashTurfs(turf/obstacle)
	if(istype(obstacle, /turf/closed/mineral/random/ms13))
		return environment_smash && can_hive_damage_obstacle(obstacle)
	return ..() && can_hive_damage_obstacle(obstacle)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/hive_attack_obstacle(atom/obstacle, ram_damage, last_resort = FALSE)
	if(!can_hive_damage_obstacle(obstacle, ram_damage, !isnull(ram_damage), last_resort))
		return FALSE
	if(hive_breach_target?.resolve() != obstacle)
		hive_breach_target = WEAKREF(obstacle)
		hive_breach_hits = 0
	hive_breach_hits++
	var/old_integrity = obstacle.get_integrity()
	var/was_dense = obstacle.density
	if(!isnull(ram_damage))
		obstacle.attack_generic(src, ram_damage, melee_damage_type, BLUNT, TRUE, armor_penetration)
	else
		obstacle.attack_animal(src)
	if(QDELETED(obstacle) || (was_dense && !obstacle.density) || obstacle.get_integrity() < old_integrity)
		hive_route_progress_at = world.time
		if(!QDELETED(obstacle) && hive_breach_hits >= hive_max_breach_hits)
			hive_avoid_goal(obstacle)
			hive_breach_target = null
		return TRUE
	// Special defenses can still veto a hit after the armor check.
	hive_avoid_goal(obstacle)
	return FALSE

/// No persistent combat target: hunting, hauling, healing and a viable patrol always get the next turn.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/handle_hive_idle_destruction()
	if(!istype(network, /datum/ms13_terrain_hivemind/necromorph) || (!istype(src, /mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier) && !istype(src, /mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy)))
		return FALSE
	if(!isturf(loc) || target || roam_target || corpse_target_ref || incapacitated() || !COOLDOWN_FINISHED(src, hive_breach_cooldown))
		return FALSE
	// Open an exit before spending idle turns on loose furniture inside the enclosure.
	for(var/turf/closed/wall in orange(1, src))
		if(Adjacent(wall) && hive_attack_obstacle(wall, last_resort = TRUE))
			COOLDOWN_START(src, hive_breach_cooldown, 2 SECONDS)
			return TRUE
	for(var/obj/obstacle in range(1, src))
		if(!isturf(obstacle.loc) || !Adjacent(obstacle) || obstacle.IsObscured())
			continue
		if(hive_attack_obstacle(obstacle, last_resort = TRUE))
			COOLDOWN_START(src, hive_breach_cooldown, 2 SECONDS)
			return TRUE
	return FALSE
