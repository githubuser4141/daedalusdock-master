GLOBAL_LIST_EMPTY(ms13_terrain_hiveminds)

#define MS13_HIVE_ROLE_SCOUT "scout"
#define MS13_HIVE_ROLE_SOLDIER "footsoldier"
#define MS13_HIVE_ROLE_RANGED "ranged"
#define MS13_HIVE_ROLE_HEAVY "heavy"
#define MS13_HIVE_ROLE_INFECTOR "infector"

#define MS13_HIVE_CORPSE_EFFECT_BLOOD "blood"
#define MS13_HIVE_CORPSE_EFFECT_GOO "goo"
#define MS13_HIVE_CORPSE_EFFECT_SPARKS "sparks"

/**
 * Shared controller for terrain-based enemies. A network owns one core, a resource pool, frontier
 * tiles, defensive structures, and units. Concrete themes only supply tuning and icon states.
 */
/datum/ms13_terrain_hivemind
	var/name = "terrain hivemind"
	var/abstract = TRUE
	var/faction_id = "ms13_terrain_hivemind"
	var/active = FALSE
	var/resources = 40
	var/max_resources = 500
	var/resource_per_tile = 0.2
	var/expansion_cost = 4
	var/special_cost = 30
	var/unit_cost = 20
	var/territory_limit = 120
	var/territory_per_special = 12
	var/max_units = 12
	var/spread_delay = 3 SECONDS
	var/special_delay = 25 SECONDS
	var/unit_spawn_delay = 20 SECONDS
	var/mob_health = 50
	var/mob_damage_lower = 8
	var/mob_damage_upper = 12
	var/mob_regeneration = 2
	var/mob_off_terrain_damage = 3
	var/mob_orphan_damage = 3
	/// Fraction of maximum integrity restored per SSobj tick after a hive structure takes damage.
	var/structure_regeneration_rate = 0.003
	var/mobs_require_terrain = FALSE
	/// Seconds for an unattended corpse on owned terrain to be recycled into a unit.
	var/terrain_conversion_time = 120
	/// Seconds for a corpse delivered to the core or a converter structure.
	var/structure_conversion_time = 12
	/// Seconds for a normal unit which can convert a corpse in the field.
	var/field_conversion_time = 45
	/// Seconds for the expensive dedicated converter unit.
	var/converter_conversion_time = 24
	var/corpse_search_range = 7
	var/terrain_corpse_scan_budget = 4
	var/units_haul_corpses = FALSE
	var/base_units_convert_corpses = FALSE
	var/elite_units_convert_corpses = FALSE
	var/converter_unit_enabled = TRUE
	var/converter_unit_cost = 60
	var/converter_unit_threshold = 24
	var/max_converter_units = 1
	/// Dead bodies are the default feedstock; themes may instead reserve disabled living hosts.
	var/converts_dead_hosts = TRUE
	var/converts_living_hosts = FALSE
	var/living_hosts_must_be_incapacitated = TRUE
	/// Resources recovered when a completed corpse cannot become a unit because the population cap is full.
	var/corpse_recycling_value = 10
	var/corpse_conversion_effect = MS13_HIVE_CORPSE_EFFECT_BLOOD
	var/corpse_conversion_start_message = "begins to twitch unnaturally"
	var/corpse_conversion_message = "convulses, then bursts apart into fresh biomass"
	var/living_conversion_start_message = "goes rigid as something begins moving beneath the skin"
	var/living_conversion_message = "convulses as a new creature tears free"
	var/living_conversion_damage = 200
	var/converter_name = "corpse converter"
	var/converter_desc = "A specialized structure which rapidly remakes corpses dragged within reach."
	var/terrain_name = "hivemind growth"
	var/icon/terrain_icon
	var/terrain_icon_state
	/// Optional bitmask-state prefix, e.g. `corruption` produces `corruption-0` through `corruption-255`.
	var/terrain_smoothing_prefix
	var/terrain_smoothing_separator = "-"
	var/terrain_smoothing_diagonals = TRUE
	var/icon/core_icon
	var/core_icon_state
	var/icon/wall_icon
	var/wall_icon_state
	var/icon/trap_icon
	var/trap_icon_state
	var/icon/turret_icon
	var/turret_icon_state
	var/icon/spawner_icon
	var/spawner_icon_state
	var/icon/converter_icon
	var/converter_icon_state
	/// Role keyed lists keep combat behavior generic while themes supply names and art.
	var/list/unit_appearances = list(
		MS13_HIVE_ROLE_SCOUT = list("name" = "hivemind scout", "icon" = 'icons/mob/blob.dmi', "state" = "blob_spore_temp"),
		MS13_HIVE_ROLE_SOLDIER = list("name" = "hivemind footsoldier", "icon" = 'icons/mob/blob.dmi', "state" = "blobpod"),
		MS13_HIVE_ROLE_RANGED = list("name" = "hivemind ranged unit", "icon" = 'icons/mob/blob.dmi', "state" = "blob_head"),
		MS13_HIVE_ROLE_HEAVY = list("name" = "hivemind heavy", "icon" = 'icons/mob/blob.dmi', "state" = "blobbernaut"),
		MS13_HIVE_ROLE_INFECTOR = list("name" = "hivemind infector", "icon" = 'icons/mob/blob.dmi', "state" = "blobpod"),
	)
	var/ranged_projectile_type = /obj/projectile/ms13_hivemind
	var/sound/ranged_projectile_sound = 'sound/weapons/pierce.ogg'
	var/core_type = /obj/structure/ms13_hivemind/core
	var/terrain_type = /obj/structure/ms13_hivemind/terrain
	var/list/mob_types = list(
		/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout,
		/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier,
	)
	var/list/evolved_mob_types = list(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged)
	var/list/elite_mob_types = list(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy)
	var/converter_mob_type = /mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter
	var/evolved_unit_threshold = 24
	var/elite_unit_threshold = 55
	var/list/special_types = list(
		/obj/structure/ms13_hivemind/special/wall,
		/obj/structure/ms13_hivemind/special/trap,
		/obj/structure/ms13_hivemind/special/turret,
		/obj/structure/ms13_hivemind/special/spawner,
		/obj/structure/ms13_hivemind/special/converter,
	)
	var/obj/structure/ms13_hivemind/core/core
	var/list/territory = list()
	var/list/frontier = list()
	var/list/specials = list()
	var/list/units = list()
	/// Weak references let networks remember discoveries without keeping deleted corpses or workers alive.
	var/list/corpse_reports = list()
	var/list/corpse_claims = list()
	var/list/corpse_conversion_progress = list()
	var/terrain_corpse_scan_cursor = 1
	COOLDOWN_DECLARE(spread_cooldown)
	COOLDOWN_DECLARE(special_cooldown)

/datum/ms13_terrain_hivemind/New(turf/start, new_territory_limit)
	. = ..()
	if(!start || abstract)
		return
	if(!isnull(new_territory_limit))
		territory_limit = new_territory_limit
	active = TRUE
	GLOB.ms13_terrain_hiveminds += src
	core = new core_type(start, src)
	for(var/turf/nearby in RANGE_TURFS(1, start))
		claim_turf(nearby, FALSE)
	COOLDOWN_START(src, spread_cooldown, spread_delay)
	COOLDOWN_START(src, special_cooldown, special_delay)
	START_PROCESSING(SSobj, src)

/datum/ms13_terrain_hivemind/Destroy()
	STOP_PROCESSING(SSobj, src)
	GLOB.ms13_terrain_hiveminds -= src
	active = FALSE
	if(core && !QDELETED(core))
		core.network = null
		qdel(core)
	core = null
	for(var/obj/structure/ms13_hivemind/terrain/growth as anything in territory)
		growth.network = null
		QDEL_IN(growth, rand(10, 30) SECONDS)
	for(var/obj/structure/ms13_hivemind/special/structure as anything in specials)
		structure.network = null
		QDEL_IN(structure, rand(5, 15) SECONDS)
	for(var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit as anything in units)
		unit.network = null
	territory = null
	frontier = null
	specials = null
	units = null
	corpse_reports = null
	corpse_claims = null
	corpse_conversion_progress = null
	return ..()

/datum/ms13_terrain_hivemind/process(delta_time)
	if(!active || !core || QDELETED(core))
		return PROCESS_KILL
	resources = min(max_resources, resources + length(territory) * resource_per_tile * delta_time)
	process_terrain_corpses(delta_time)
	if(COOLDOWN_FINISHED(src, spread_cooldown))
		try_expand()
		COOLDOWN_START(src, spread_cooldown, spread_delay)
	if(COOLDOWN_FINISHED(src, special_cooldown))
		try_build_special()
		COOLDOWN_START(src, special_cooldown, special_delay)

/datum/ms13_terrain_hivemind/proc/can_claim(turf/target)
	if(!target || !isopenturf(target) || target.density || (target.resistance_flags & INDESTRUCTIBLE))
		return FALSE
	if(istype(target, /turf/open/space) || istype(target, /turf/open/chasm) || istype(target, /turf/open/lava) || istype(target, /turf/open/openspace))
		return FALSE
	if(locate(/obj/structure/ms13_hivemind/terrain) in target)
		return FALSE
	if(locate(/obj/effect/landmark) in target || locate(/obj/docking_port) in target)
		return FALSE
	return TRUE

/datum/ms13_terrain_hivemind/proc/claim_turf(turf/target, spend_resources = TRUE)
	if(!can_claim(target) || (territory_limit && length(territory) >= territory_limit))
		return FALSE
	if(spend_resources)
		if(resources < expansion_cost)
			return FALSE
		resources -= expansion_cost
	new terrain_type(target, src)
	return TRUE

/datum/ms13_terrain_hivemind/proc/register_terrain(obj/structure/ms13_hivemind/terrain/growth)
	territory |= growth
	update_frontier(growth)
	for(var/obj/structure/ms13_hivemind/terrain/neighbor in range(1, growth))
		if(neighbor.network == src)
			update_frontier(neighbor)
			neighbor.update_connected_icon()
	growth.update_connected_icon()

/datum/ms13_terrain_hivemind/proc/unregister_terrain(obj/structure/ms13_hivemind/terrain/growth)
	territory -= growth
	frontier -= growth
	for(var/obj/structure/ms13_hivemind/terrain/neighbor in range(1, growth))
		if(neighbor.network == src)
			update_frontier(neighbor)
			neighbor.update_connected_icon()

/datum/ms13_terrain_hivemind/proc/get_claimable_neighbors(obj/structure/ms13_hivemind/terrain/growth)
	. = list()
	if(!growth || QDELETED(growth))
		return
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(growth, direction)
		if(can_claim(candidate))
			. += candidate

/datum/ms13_terrain_hivemind/proc/update_frontier(obj/structure/ms13_hivemind/terrain/growth)
	if(!growth || QDELETED(growth) || growth.network != src)
		return
	if(length(get_claimable_neighbors(growth)))
		frontier |= growth
	else
		frontier -= growth

/datum/ms13_terrain_hivemind/proc/try_expand()
	if(resources < expansion_cost || (territory_limit && length(territory) >= territory_limit))
		return FALSE
	while(length(frontier))
		var/obj/structure/ms13_hivemind/terrain/origin = pick(frontier)
		var/list/candidates = get_claimable_neighbors(origin)
		if(!length(candidates))
			frontier -= origin
			continue
		return claim_turf(pick(candidates))
	return FALSE

/datum/ms13_terrain_hivemind/proc/try_build_special()
	if(resources < special_cost || !length(territory) || length(specials) >= max(1, round(length(territory) / territory_per_special)))
		return FALSE
	var/list/candidates = territory.Copy()
	shuffle_inplace(candidates)
	for(var/obj/structure/ms13_hivemind/terrain/growth as anything in candidates)
		var/turf/target = get_turf(growth)
		if(!target || target == get_turf(core) || locate(/obj/structure/ms13_hivemind/special) in target || locate(/mob/living) in target)
			continue
		var/blocked = FALSE
		for(var/atom/movable/content in target)
			if(content != growth && content.density)
				blocked = TRUE
				break
		if(blocked)
			continue
		var/special_type = pick(special_types)
		new special_type(target, src)
		resources -= special_cost
		return TRUE
	return FALSE

/datum/ms13_terrain_hivemind/proc/is_territory(turf/target)
	var/obj/structure/ms13_hivemind/terrain/growth = locate() in target
	return growth?.network == src

/datum/ms13_terrain_hivemind/proc/is_allied(mob/living/subject)
	return subject && (faction_id in subject.faction)

/datum/ms13_terrain_hivemind/proc/spend(amount)
	if(resources < amount)
		return FALSE
	resources -= amount
	return TRUE

/datum/ms13_terrain_hivemind/proc/get_available_unit_types()
	var/list/available_types = mob_types.Copy()
	if(length(territory) >= evolved_unit_threshold)
		available_types += evolved_mob_types
	if(length(territory) >= elite_unit_threshold)
		available_types += elite_mob_types
	return available_types

/datum/ms13_terrain_hivemind/proc/can_spawn_unit_at(turf/target)
	return isopenturf(target) && !target.density && !get_ms13_ground_vehicle_at(target)

/datum/ms13_terrain_hivemind/proc/get_unit_spawn_turf(turf/origin)
	if(can_spawn_unit_at(origin))
		return origin
	var/turf/closest
	var/closest_distance = INFINITY
	for(var/obj/structure/ms13_hivemind/terrain/growth as anything in territory)
		var/turf/candidate = get_turf(growth)
		var/distance = get_dist(origin, candidate)
		if(distance <= 4 && distance < closest_distance && can_spawn_unit_at(candidate))
			closest = candidate
			closest_distance = distance
	return closest

/datum/ms13_terrain_hivemind/proc/spawn_unit(unit_type, turf/origin)
	var/turf/spawn_turf = get_unit_spawn_turf(origin)
	if(!spawn_turf)
		return
	return new unit_type(spawn_turf, src)

/datum/ms13_terrain_hivemind/proc/is_convertible_corpse(mob/living/corpse)
	if(!corpse || QDELETED(corpse) || !isturf(corpse.loc) || is_allied(corpse))
		return FALSE
	if(corpse.stat == DEAD)
		return converts_dead_hosts
	if(!converts_living_hosts)
		return FALSE
	return !living_hosts_must_be_incapacitated || corpse.stat == UNCONSCIOUS || corpse.IsParalyzed()

/datum/ms13_terrain_hivemind/proc/report_corpse(mob/living/corpse)
	if(!is_convertible_corpse(corpse))
		return FALSE
	if(get_corpse_claim(corpse))
		return TRUE
	var/datum/weakref/corpse_ref = WEAKREF(corpse)
	if(corpse_ref in corpse_reports)
		return TRUE
	corpse_reports += corpse_ref
	for(var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit as anything in units)
		if(unit.AIStatus == AI_IDLE && unit.can_work_corpses())
			unit.toggle_ai(AI_ON)
	return TRUE

/datum/ms13_terrain_hivemind/proc/get_corpse_claim(mob/living/corpse)
	var/datum/weakref/corpse_ref = WEAKREF(corpse)
	var/datum/weakref/claim_ref = corpse_claims[corpse_ref]
	var/datum/claimant = claim_ref?.resolve()
	if(claim_ref && !claimant)
		corpse_claims -= corpse_ref
	return claimant

/datum/ms13_terrain_hivemind/proc/claim_corpse(mob/living/corpse, datum/claimant)
	if(!is_convertible_corpse(corpse) || QDELETED(claimant))
		return FALSE
	var/datum/current_claim = get_corpse_claim(corpse)
	if(current_claim && current_claim != claimant)
		return FALSE
	var/datum/weakref/corpse_ref = WEAKREF(corpse)
	corpse_claims[corpse_ref] = WEAKREF(claimant)
	corpse_reports -= corpse_ref
	return TRUE

/datum/ms13_terrain_hivemind/proc/release_corpse_claim(mob/living/corpse, datum/claimant, requeue = TRUE)
	if(!corpse)
		return
	var/datum/weakref/corpse_ref = WEAKREF(corpse)
	var/datum/weakref/claim_ref = corpse_claims[corpse_ref]
	if(!claimant || claim_ref?.resolve() == claimant)
		corpse_claims -= corpse_ref
		if(requeue)
			report_corpse(corpse)

/datum/ms13_terrain_hivemind/proc/find_reported_corpse(atom/seeker)
	var/mob/living/closest
	var/closest_distance = INFINITY
	for(var/datum/weakref/corpse_ref as anything in corpse_reports.Copy())
		var/mob/living/corpse = corpse_ref.resolve()
		if(!is_convertible_corpse(corpse))
			corpse_reports -= corpse_ref
			corpse_claims -= corpse_ref
			corpse_conversion_progress -= corpse_ref
			continue
		if(corpse.z != seeker.z)
			continue
		var/datum/current_claim = get_corpse_claim(corpse)
		if(current_claim && current_claim != seeker)
			continue
		var/distance = get_dist(seeker, corpse)
		if(distance < closest_distance)
			closest = corpse
			closest_distance = distance
	return closest

/datum/ms13_terrain_hivemind/proc/get_claimed_corpse(datum/claimant)
	for(var/datum/weakref/corpse_ref as anything in corpse_claims)
		var/datum/weakref/claim_ref = corpse_claims[corpse_ref]
		if(claim_ref?.resolve() != claimant)
			continue
		var/mob/living/corpse = corpse_ref.resolve()
		if(is_convertible_corpse(corpse))
			return corpse
		corpse_claims -= corpse_ref

/datum/ms13_terrain_hivemind/proc/advance_corpse_conversion(mob/living/corpse, datum/converter, delta_time, conversion_time, claim = TRUE)
	if(!is_convertible_corpse(corpse) || conversion_time <= 0)
		return FALSE
	if(claim && !claim_corpse(corpse, converter))
		return FALSE
	var/datum/weakref/corpse_ref = WEAKREF(corpse)
	var/old_progress = corpse_conversion_progress[corpse_ref] || 0
	corpse_conversion_progress[corpse_ref] = min(1, old_progress + delta_time / conversion_time)
	var/living_host = corpse.stat != DEAD
	if(living_host)
		corpse.Paralyze(3 SECONDS)
	if(!old_progress)
		var/start_message = living_host ? living_conversion_start_message : corpse_conversion_start_message
		corpse.visible_message(span_warning("[corpse] [start_message]."))
	corpse.shake_animation(2 + round(corpse_conversion_progress[corpse_ref] * 6))
	if(corpse_conversion_progress[corpse_ref] < 1)
		return FALSE
	var/turf/spawn_turf = get_turf(corpse)
	var/completion_message = living_host ? living_conversion_message : corpse_conversion_message
	corpse.visible_message(span_warning("[corpse] [completion_message]."))
	play_corpse_conversion_effect(corpse, spawn_turf)
	corpse_reports -= corpse_ref
	corpse_claims -= corpse_ref
	corpse_conversion_progress -= corpse_ref
	if(living_host)
		corpse.apply_damage(living_conversion_damage, BRUTE, BODY_ZONE_CHEST, forced = TRUE, sharpness = SHARP_POINTY)
		if(corpse.stat != DEAD)
			corpse.death()
	else
		qdel(corpse)
	if(length(units) < max_units)
		var/list/available_types = get_available_unit_types()
		if(length(available_types))
			var/unit_type = pick(available_types)
			if(spawn_unit(unit_type, spawn_turf))
				return TRUE
	resources = min(max_resources, resources + corpse_recycling_value)
	return TRUE

/datum/ms13_terrain_hivemind/proc/play_corpse_conversion_effect(mob/living/corpse, turf/where)
	switch(corpse_conversion_effect)
		if(MS13_HIVE_CORPSE_EFFECT_BLOOD)
			corpse.add_splatter_floor(where)
			new /obj/effect/decal/cleanable/blood/gibs(where, corpse.get_static_viruses())
		if(MS13_HIVE_CORPSE_EFFECT_GOO)
			new /obj/effect/decal/cleanable/greenglow(where)
			playsound(where, 'sound/effects/splat.ogg', 50, TRUE)
		if(MS13_HIVE_CORPSE_EFFECT_SPARKS)
			do_sparks(4, FALSE, where)

/datum/ms13_terrain_hivemind/proc/process_terrain_corpses(delta_time)
	var/territory_count = length(territory)
	if(!territory_count || terrain_conversion_time <= 0)
		return
	var/check_count = min(terrain_corpse_scan_budget, territory_count)
	for(var/i in 1 to check_count)
		if(terrain_corpse_scan_cursor > territory_count)
			terrain_corpse_scan_cursor = 1
		var/obj/structure/ms13_hivemind/terrain/growth = territory[terrain_corpse_scan_cursor++]
		if(!growth || QDELETED(growth))
			continue
		for(var/mob/living/corpse in get_turf(growth))
			if(!is_convertible_corpse(corpse) || LAZYLEN(corpse.grabbed_by))
				continue
			if(get_corpse_claim(corpse))
				continue
			report_corpse(corpse)
			advance_corpse_conversion(corpse, growth, delta_time * territory_count / check_count, terrain_conversion_time, FALSE)

/datum/ms13_terrain_hivemind/proc/process_structure_corpse(atom/converter, delta_time)
	var/mob/living/corpse = get_claimed_corpse(converter)
	if(corpse && (get_dist(converter, corpse) > 1 || LAZYLEN(corpse.grabbed_by)))
		release_corpse_claim(corpse, converter)
		corpse = null
	if(!corpse)
		for(var/mob/living/candidate in range(1, converter))
			if(!is_convertible_corpse(candidate) || LAZYLEN(candidate.grabbed_by))
				continue
			report_corpse(candidate)
			if(claim_corpse(candidate, converter))
				corpse = candidate
				break
	if(corpse)
		advance_corpse_conversion(corpse, converter, delta_time, structure_conversion_time)

/datum/ms13_terrain_hivemind/proc/get_corpse_delivery_target(atom/source)
	var/list/converters = list()
	if(core && !QDELETED(core))
		converters += core
	for(var/obj/structure/ms13_hivemind/special/converter/converter in specials)
		converters += converter
	return get_closest_atom(/obj/structure/ms13_hivemind, converters, source)

/datum/ms13_terrain_hivemind/proc/should_spawn_converter()
	if(!converter_unit_enabled || length(territory) < converter_unit_threshold || resources < converter_unit_cost || !find_reported_corpse(core))
		return FALSE
	var/converter_count = 0
	for(var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit as anything in units)
		if(unit.corpse_converter)
			converter_count++
	return converter_count < max_converter_units

/datum/ms13_terrain_hivemind/blob
	name = "SS13 blob"
	abstract = FALSE
	faction_id = ROLE_BLOB
	resource_per_tile = 0.3
	spread_delay = 2 SECONDS
	mobs_require_terrain = TRUE
	base_units_convert_corpses = TRUE
	terrain_conversion_time = 75
	field_conversion_time = 36
	structure_conversion_time = 8
	corpse_conversion_effect = MS13_HIVE_CORPSE_EFFECT_GOO
	corpse_conversion_message = "swells and ruptures into glowing protoplasm"
	mob_health = 130
	terrain_name = "pulsating blob"
	terrain_icon = 'icons/mob/blob.dmi'
	terrain_icon_state = "blob"
	core_icon = 'icons/mob/blob.dmi'
	core_icon_state = "blob_core_overlay"
	wall_icon = 'icons/mob/blob.dmi'
	wall_icon_state = "blob_shield"
	trap_icon = 'icons/mob/blob.dmi'
	trap_icon_state = "blob_glow"
	turret_icon = 'icons/mob/blob.dmi'
	turret_icon_state = "blobbernaut"
	spawner_icon = 'icons/mob/blob.dmi'
	spawner_icon_state = "blob_factory"
	converter_icon = 'icons/mob/blob.dmi'
	converter_icon_state = "blob_resource"
	unit_appearances = list(
		MS13_HIVE_ROLE_SCOUT = list("name" = "blob spore", "icon" = 'icons/mob/blob.dmi', "state" = "blob_spore_temp"),
		MS13_HIVE_ROLE_SOLDIER = list("name" = "blob pod", "icon" = 'icons/mob/blob.dmi', "state" = "blobpod"),
		MS13_HIVE_ROLE_RANGED = list("name" = "blob launcher", "icon" = 'icons/mob/blob.dmi', "state" = "blob_head"),
		MS13_HIVE_ROLE_HEAVY = list("name" = "blobbernaut", "icon" = 'icons/mob/blob.dmi', "state" = "blobbernaut"),
		MS13_HIVE_ROLE_INFECTOR = list("name" = "blob harvester", "icon" = 'icons/mob/blob.dmi', "state" = "blob_resource"),
	)
	ranged_projectile_type = /obj/projectile/ms13_hivemind/blob
	ranged_projectile_sound = 'sound/effects/attackblob.ogg'

/datum/ms13_terrain_hivemind/flock
	name = "Daedalus flock"
	abstract = FALSE
	faction_id = FACTION_FLOCK
	mob_regeneration = 3
	terrain_conversion_time = 150
	structure_conversion_time = 10
	corpse_conversion_effect = MS13_HIVE_CORPSE_EFFECT_SPARKS
	corpse_conversion_message = "flickers, fractures, and resolves into fresh gnesis"
	mob_health = 90
	mob_damage_lower = 12
	mob_damage_upper = 24
	terrain_name = "gnesis floor"
	terrain_icon = 'goon/icons/turf/flock.dmi'
	terrain_icon_state = "flock-0"
	terrain_smoothing_prefix = "flock"
	core_icon = 'goon/icons/mob/featherzone.dmi'
	core_icon_state = "rift"
	wall_icon = 'goon/icons/turf/flock.dmi'
	wall_icon_state = "flock-0"
	trap_icon = 'goon/icons/mob/featherzone.dmi'
	trap_icon_state = "sentinel"
	turret_icon = 'goon/icons/mob/featherzone.dmi'
	turret_icon_state = "teleblocker-on"
	spawner_icon = 'goon/icons/mob/featherzone.dmi'
	spawner_icon_state = "egg"
	converter_icon = 'goon/icons/mob/featherzone.dmi'
	converter_icon_state = "egg"
	unit_appearances = list(
		MS13_HIVE_ROLE_SCOUT = list("name" = "flockbit", "icon" = 'goon/icons/mob/featherzone.dmi', "state" = "flockbit"),
		MS13_HIVE_ROLE_SOLDIER = list("name" = "flockdrone", "icon" = 'goon/icons/mob/featherzone.dmi', "state" = "drone"),
		MS13_HIVE_ROLE_RANGED = list("name" = "flocktrace", "icon" = 'goon/icons/mob/featherzone.dmi', "state" = "flocktrace"),
		MS13_HIVE_ROLE_HEAVY = list("name" = "flockmind avatar", "icon" = 'goon/icons/mob/featherzone.dmi', "state" = "flockmind"),
		MS13_HIVE_ROLE_INFECTOR = list("name" = "flock reclaimer", "icon" = 'goon/icons/mob/featherzone.dmi', "state" = "reclaimer"),
	)
	ranged_projectile_type = /obj/projectile/ms13_hivemind/flock
	ranged_projectile_sound = 'sound/weapons/laser3.ogg'

/datum/ms13_terrain_hivemind/necromorph
	name = "DS13 necromorph corruption"
	abstract = FALSE
	faction_id = "ms13_necromorph"
	resource_per_tile = 0.15
	mobs_require_terrain = TRUE
	units_haul_corpses = TRUE
	elite_units_convert_corpses = TRUE
	terrain_conversion_time = 135
	field_conversion_time = 28
	structure_conversion_time = 7
	corpse_conversion_effect = MS13_HIVE_CORPSE_EFFECT_BLOOD
	corpse_conversion_message = "convulses violently before bursting into blood and reshaped flesh"
	mob_health = 100
	mob_damage_lower = 20
	mob_damage_upper = 40
	terrain_name = "necromorph corruption"
	terrain_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption.dmi'
	terrain_icon_state = "corruption-0"
	terrain_smoothing_prefix = "corruption"
	core_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption_structures.dmi'
	core_icon_state = "growth"
	wall_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption_structures.dmi'
	wall_icon_state = "wall"
	trap_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption_structures.dmi'
	trap_icon_state = "snare"
	turret_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption_structures.dmi'
	turret_icon_state = "cyst-full"
	spawner_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption_structures.dmi'
	spawner_icon_state = "nest"
	converter_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption_structures.dmi'
	converter_icon_state = "nest"
	unit_appearances = list(
		MS13_HIVE_ROLE_SCOUT = list("name" = "necromorph swarmer", "icon" = 'mojave/icons/wip/terrain_hivemind/ds13_swarmer.dmi', "state" = "swarmer1"),
		MS13_HIVE_ROLE_SOLDIER = list("name" = "necromorph slasher", "icon" = 'mojave/icons/wip/terrain_hivemind/ds13_slasher.dmi', "state" = "preview", "pixel_x" = -8, "pixel_y" = -8),
		MS13_HIVE_ROLE_RANGED = list("name" = "necromorph lurker", "icon" = 'mojave/icons/wip/terrain_hivemind/ds13_lurker.dmi', "state" = "preview", "pixel_x" = -16, "pixel_y" = -8),
		MS13_HIVE_ROLE_HEAVY = list("name" = "necromorph brute", "icon" = 'mojave/icons/wip/terrain_hivemind/ds13_necromorphs_64.dmi', "state" = "brute", "pixel_x" = -16, "pixel_y" = -16),
		MS13_HIVE_ROLE_INFECTOR = list("name" = "necromorph infector", "icon" = 'mojave/icons/wip/terrain_hivemind/ds13_infector.dmi', "state" = "preview", "pixel_x" = -8, "pixel_y" = -8),
	)
	ranged_projectile_type = /obj/projectile/ms13_hivemind/necromorph
	ranged_projectile_sound = 'sound/weapons/pierce.ogg'

/datum/ms13_terrain_hivemind/eris
	name = "CEV-Eris machine hive"
	abstract = FALSE
	faction_id = "ms13_eris_hive"
	resource_per_tile = 0.25
	mob_health = 120
	mob_damage_lower = 15
	mob_damage_upper = 30
	units_haul_corpses = TRUE
	terrain_conversion_time = 180
	structure_conversion_time = 9
	corpse_conversion_effect = MS13_HIVE_CORPSE_EFFECT_SPARKS
	corpse_conversion_message = "jerks upright, then collapses into sparking machine matter"
	terrain_name = "hivemind wireweed"
	terrain_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind.dmi'
	terrain_icon_state = "wires"
	core_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_machines.dmi'
	core_icon_state = "core"
	wall_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_machines.dmi'
	wall_icon_state = "infected_machine"
	trap_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_machines.dmi'
	trap_icon_state = "orb"
	turret_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_machines.dmi'
	turret_icon_state = "turret"
	spawner_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_machines.dmi'
	spawner_icon_state = "spawner"
	converter_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_machines.dmi'
	converter_icon_state = "spawner"
	unit_appearances = list(
		MS13_HIVE_ROLE_SCOUT = list("name" = "hivemind slicer", "icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi', "state" = "slicer"),
		MS13_HIVE_ROLE_SOLDIER = list("name" = "hivemind treader", "icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi', "state" = "treader"),
		MS13_HIVE_ROLE_RANGED = list("name" = "hivemind lobber", "icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi', "state" = "lobber"),
		MS13_HIVE_ROLE_HEAVY = list("name" = "hivemind borg", "icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi', "state" = "hiborg"),
		MS13_HIVE_ROLE_INFECTOR = list("name" = "hivemind recycler", "icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi', "state" = "mechiver-closed"),
	)
	ranged_projectile_type = /obj/projectile/ms13_hivemind/eris
	ranged_projectile_sound = 'sound/weapons/laser.ogg'

/datum/ms13_terrain_hivemind/xenomorph
	name = "TGMC xenomorph hive"
	abstract = FALSE
	faction_id = "ms13_xenomorph"
	resource_per_tile = 0.2
	mob_health = 105
	mob_damage_lower = 18
	mob_damage_upper = 30
	mob_regeneration = 3
	mob_off_terrain_damage = 0
	mob_orphan_damage = 0
	units_haul_corpses = TRUE
	converter_unit_enabled = FALSE
	converts_dead_hosts = FALSE
	converts_living_hosts = TRUE
	terrain_conversion_time = 0
	structure_conversion_time = 25
	living_conversion_start_message = "seizes as resin tightens and something begins growing inside"
	living_conversion_message = "erupts in a shower of blood as a newborn xenomorph emerges"
	converter_name = "incubation nest"
	converter_desc = "A resin hollow which keeps disabled living hosts immobile while the hive incubates them."
	terrain_name = "alien resin weeds"
	terrain_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/weeds.dmi'
	terrain_icon_state = "weed0"
	terrain_smoothing_prefix = "weed"
	terrain_smoothing_separator = ""
	terrain_smoothing_diagonals = FALSE
	core_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/weeds.dmi'
	core_icon_state = "weednode5"
	wall_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/structures.dmi'
	wall_icon_state = "thickresin15"
	trap_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/structures.dmi'
	trap_icon_state = "membrane15"
	turret_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/acid_turret.dmi'
	turret_icon_state = "acid_turret"
	spawner_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/structures.dmi'
	spawner_icon_state = "resin15"
	converter_icon = 'mojave/icons/by_nc/tgmc_xenomorphs/structures.dmi'
	converter_icon_state = "thickmembrane15"
	unit_appearances = list(
		MS13_HIVE_ROLE_SCOUT = list("name" = "xenomorph runner", "icon" = 'mojave/icons/by_nc/tgmc_xenomorphs/castes/runner.dmi', "state" = "Runner Walking", "pixel_x" = -16),
		MS13_HIVE_ROLE_SOLDIER = list("name" = "xenomorph warrior", "icon" = 'mojave/icons/by_nc/tgmc_xenomorphs/castes/warrior.dmi', "state" = "Warrior Walking", "pixel_x" = -16),
		MS13_HIVE_ROLE_RANGED = list("name" = "xenomorph spitter", "icon" = 'mojave/icons/by_nc/tgmc_xenomorphs/castes/spitter.dmi', "state" = "Spitter Walking", "pixel_x" = -16),
		MS13_HIVE_ROLE_HEAVY = list("name" = "xenomorph crusher", "icon" = 'mojave/icons/by_nc/tgmc_xenomorphs/castes/crusher.dmi', "state" = "Crusher Walking", "pixel_x" = -16),
		MS13_HIVE_ROLE_INFECTOR = list("name" = "xenomorph carrier", "icon" = 'mojave/icons/by_nc/tgmc_xenomorphs/castes/carrier.dmi', "state" = "Carrier Walking", "pixel_x" = -16),
	)
	mob_types = list(
		/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout,
		/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier,
	)
	evolved_mob_types = list(
		/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged,
		/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler,
	)
	elite_mob_types = list(/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy)
	ranged_projectile_type = /obj/projectile/ms13_hivemind/xenomorph
	ranged_projectile_sound = 'sound/effects/splat.ogg'

/obj/projectile/ms13_hivemind
	name = "hivemind bolt"
	icon = 'icons/obj/guns/projectiles.dmi'
	icon_state = "pulse0"
	damage = 20
	range = 8
	var/datum/ms13_terrain_hivemind/source_network

/obj/projectile/ms13_hivemind/blob
	name = "caustic glob"
	icon_state = "glob_projectile"
	damage = 22

/obj/projectile/ms13_hivemind/flock
	name = "gnesis bolt"
	icon = 'goon/icons/mob/featherzone.dmi'
	icon_state = "stunbolt"
	damage = 22

/obj/projectile/ms13_hivemind/necromorph
	name = "bone spine"
	icon = 'mojave/icons/wip/terrain_hivemind/ds13_lurker.dmi'
	icon_state = "spine_projectile"
	damage = 22

/obj/projectile/ms13_hivemind/eris
	name = "machine-hive glob"
	icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind.dmi'
	icon_state = "goo_proj"
	damage = 22

/obj/projectile/ms13_hivemind/xenomorph
	name = "acid spit"
	icon_state = "glob_projectile"
	damage = 20
	damage_type = BURN

/obj/structure/ms13_hivemind
	anchored = TRUE
	obj_flags = CAN_BE_HIT
	var/datum/ms13_terrain_hivemind/network

/obj/structure/ms13_hivemind/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(join_network)
		AddElement(/datum/element/obj_regen, join_network.structure_regeneration_rate)

/obj/structure/ms13_hivemind/core
	name = "hivemind core"
	desc = "The coordinating heart of an expanding hostile terrain network."
	density = TRUE
	max_integrity = 300

/obj/structure/ms13_hivemind/core/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		return INITIALIZE_HINT_QDEL
	network = join_network
	name = "[network.name] core"
	icon = network.core_icon
	icon_state = network.core_icon_state
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_hivemind/core/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(network)
		var/datum/ms13_terrain_hivemind/old_network = network
		network = null
		old_network.core = null
		qdel(old_network)
	return ..()

/obj/structure/ms13_hivemind/core/CanAllowThrough(atom/movable/mover, border_dir)
	var/obj/projectile/ms13_hivemind/shot = mover
	if(istype(shot) && shot.source_network == network)
		return TRUE
	return ..()

/obj/structure/ms13_hivemind/core/process(delta_time)
	if(!network || !network.active)
		return PROCESS_KILL
	network.process_structure_corpse(src, delta_time)

/obj/structure/ms13_hivemind/core/examine(mob/user)
	. = ..()
	if(network)
		. += span_notice("It controls [length(network.territory)][network.territory_limit ? "/[network.territory_limit]" : null] tiles and holds [round(network.resources, 0.1)]/[network.max_resources] resources.")

/obj/structure/ms13_hivemind/terrain
	name = "hivemind growth"
	desc = "Hostile terrain connected to a distant controlling intelligence."
	density = FALSE
	layer = ABOVE_OPEN_TURF_LAYER
	max_integrity = 35
	mouse_opacity = MOUSE_OPACITY_ICON

/obj/structure/ms13_hivemind/terrain/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		return INITIALIZE_HINT_QDEL
	network = join_network
	name = network.terrain_name
	icon = network.terrain_icon
	icon_state = network.terrain_icon_state
	network.register_terrain(src)

/obj/structure/ms13_hivemind/terrain/Destroy()
	var/datum/ms13_terrain_hivemind/old_network = network
	network = null
	if(old_network)
		old_network.unregister_terrain(src)
	for(var/obj/structure/ms13_hivemind/special/structure in loc)
		if(structure.network == old_network)
			qdel(structure)
	return ..()

/obj/structure/ms13_hivemind/terrain/proc/update_connected_icon()
	if(!network?.terrain_smoothing_prefix)
		return
	var/junction = NONE
	for(var/direction in GLOB.cardinals)
		if(has_network_neighbor(direction))
			junction |= direction
	if(network.terrain_smoothing_diagonals)
		if((junction & NORTH) && (junction & WEST) && has_network_neighbor(NORTHWEST))
			junction |= NORTHWEST_JUNCTION
		if((junction & NORTH) && (junction & EAST) && has_network_neighbor(NORTHEAST))
			junction |= NORTHEAST_JUNCTION
		if((junction & SOUTH) && (junction & WEST) && has_network_neighbor(SOUTHWEST))
			junction |= SOUTHWEST_JUNCTION
		if((junction & SOUTH) && (junction & EAST) && has_network_neighbor(SOUTHEAST))
			junction |= SOUTHEAST_JUNCTION
	icon_state = "[network.terrain_smoothing_prefix][network.terrain_smoothing_separator][junction]"

/obj/structure/ms13_hivemind/terrain/proc/has_network_neighbor(direction)
	var/turf/neighbor_turf = get_step(src, direction)
	if(!neighbor_turf)
		return FALSE
	for(var/obj/structure/ms13_hivemind/terrain/neighbor in neighbor_turf)
		if(neighbor.network == network)
			return TRUE
	return FALSE

/obj/structure/ms13_hivemind/special
	name = "hivemind structure"
	desc = "A specialized growth fed by the surrounding hostile terrain."
	max_integrity = 120

/obj/structure/ms13_hivemind/special/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		return INITIALIZE_HINT_QDEL
	network = join_network
	network.specials |= src

/obj/structure/ms13_hivemind/special/Destroy()
	if(network)
		network.specials -= src
	network = null
	return ..()

/obj/structure/ms13_hivemind/special/wall
	name = "hivemind wall"
	density = TRUE
	layer = BELOW_MOB_LAYER
	max_integrity = 180

/obj/structure/ms13_hivemind/special/wall/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(network)
		name = "[network.name] wall"
		icon = network.wall_icon
		icon_state = network.wall_icon_state

/obj/structure/ms13_hivemind/special/trap
	name = "hivemind trap"
	density = FALSE
	layer = ABOVE_OPEN_TURF_LAYER
	var/damage = 30
	COOLDOWN_DECLARE(trigger_cooldown)

/obj/structure/ms13_hivemind/special/trap/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!network)
		return
	name = "[network.name] trap"
	icon = network.trap_icon
	icon_state = network.trap_icon_state
	var/static/list/loc_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/ms13_hivemind/special/trap/proc/on_entered(datum/source, atom/movable/entered)
	SIGNAL_HANDLER
	if(!isliving(entered) || !network || network.is_allied(entered) || !COOLDOWN_FINISHED(src, trigger_cooldown))
		return
	var/mob/living/victim = entered
	victim.apply_damage(damage, BRUTE)
	victim.Knockdown(2 SECONDS)
	playsound(src, 'sound/effects/splat.ogg', 45, TRUE)
	COOLDOWN_START(src, trigger_cooldown, 3 SECONDS)

/obj/structure/ms13_hivemind/special/turret
	name = "hivemind turret"
	density = TRUE
	var/range = 7
	var/projectile_type = /obj/projectile/hivebotbullet
	COOLDOWN_DECLARE(fire_cooldown)

/obj/structure/ms13_hivemind/special/turret/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!network)
		return
	name = "[network.name] turret"
	icon = network.turret_icon
	icon_state = network.turret_icon_state
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_hivemind/special/turret/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/ms13_hivemind/special/turret/process(delta_time)
	if(!network || !network.active)
		return PROCESS_KILL
	if(!network.is_territory(get_turf(src)))
		take_damage(5 * delta_time, BRUTE)
		return
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		return
	var/mob/living/target
	var/target_distance = INFINITY
	for(var/mob/living/candidate in viewers(range, src))
		if(candidate.stat == DEAD || network.is_allied(candidate) || network.is_convertible_corpse(candidate))
			continue
		var/distance = get_dist(src, candidate)
		if(distance < target_distance)
			target = candidate
			target_distance = distance
	if(!target)
		return
	var/obj/projectile/shot = new projectile_type
	shot.preparePixelProjectile(target, get_turf(src))
	shot.firer = src
	shot.fired_from = src
	var/obj/projectile/ms13_hivemind/hive_shot = shot
	if(istype(hive_shot))
		hive_shot.source_network = network
	shot.ignored_factions = list(network.faction_id)
	shot.fire()
	COOLDOWN_START(src, fire_cooldown, 2 SECONDS)

/obj/structure/ms13_hivemind/special/spawner
	name = "hivemind unit generator"
	density = FALSE
	max_integrity = 120
	COOLDOWN_DECLARE(spawn_cooldown)

/obj/structure/ms13_hivemind/special/spawner/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!network)
		return
	name = "[network.name] unit generator"
	icon = network.spawner_icon
	icon_state = network.spawner_icon_state
	COOLDOWN_START(src, spawn_cooldown, network.unit_spawn_delay)
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_hivemind/special/spawner/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/ms13_hivemind/special/spawner/process(delta_time)
	if(!network || !network.active)
		return PROCESS_KILL
	if(!network.is_territory(get_turf(src)))
		take_damage(5 * delta_time, BRUTE)
		return
	if(length(network.units) >= network.max_units || !COOLDOWN_FINISHED(src, spawn_cooldown))
		return
	var/turf/spawn_turf = network.get_unit_spawn_turf(get_turf(src))
	if(!spawn_turf)
		return
	if(network.should_spawn_converter())
		if(network.spend(network.converter_unit_cost))
			var/converter_type = network.converter_mob_type
			new converter_type(spawn_turf, network)
			COOLDOWN_START(src, spawn_cooldown, network.unit_spawn_delay)
		return
	var/list/available_types = network.get_available_unit_types()
	if(!length(available_types) || !network.spend(network.unit_cost))
		return
	var/unit_type = pick(available_types)
	new unit_type(spawn_turf, network)
	COOLDOWN_START(src, spawn_cooldown, network.unit_spawn_delay)

/obj/structure/ms13_hivemind/special/converter
	name = "hivemind corpse converter"
	desc = "A specialized structure which rapidly remakes corpses dragged within reach."
	density = FALSE
	max_integrity = 130

/obj/structure/ms13_hivemind/special/converter/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!network)
		return
	name = "[network.name] [network.converter_name]"
	desc = network.converter_desc
	icon = network.converter_icon
	icon_state = network.converter_icon_state
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_hivemind/special/converter/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/ms13_hivemind/special/converter/process(delta_time)
	if(!network || !network.active)
		return PROCESS_KILL
	if(!network.is_territory(get_turf(src)))
		take_damage(5 * delta_time, BRUTE)
		return
	network.process_structure_corpse(src, delta_time)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	name = "hivemind drone"
	desc = "A creature sustained by a hostile terrain network."
	icon = 'icons/mob/blob.dmi'
	icon_state = "blobpod"
	icon_living = "blobpod"
	icon_dead = "blobpod"
	health = 100
	maxHealth = 100
	melee_damage_lower = 15
	melee_damage_upper = 30
	obj_damage = 25
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	attack_verb_continuous = "tears into"
	attack_verb_simple = "tear into"
	attack_sound = 'sound/weapons/genhit1.ogg'
	faction = list("ms13_terrain_hivemind")
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_plas" = 0, "max_plas" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	minbodytemp = 0
	maxbodytemp = INFINITY
	del_on_death = TRUE
	gold_core_spawnable = NO_SPAWN
	var/datum/ms13_terrain_hivemind/network
	var/terrain_dependent = FALSE
	var/unit_role = MS13_HIVE_ROLE_SOLDIER
	var/evolution_rank = 1
	var/health_multiplier = 1
	var/damage_multiplier = 1
	var/regeneration_multiplier = 1
	var/off_terrain_damage_multiplier = 1
	var/orphan_damage = 3
	/// Hurt, idle units only retreat when friendly terrain is close enough to be an obvious safe step.
	var/terrain_recovery_health = 0.45
	var/terrain_recovery_range = 6
	var/corpse_converter = FALSE
	var/corpse_hauler = TRUE
	var/roam_range = 14
	var/roam_min_distance = 7
	var/roam_retarget_delay = 15 SECONDS
	var/turf/roam_target
	var/datum/weakref/corpse_target_ref
	COOLDOWN_DECLARE(roam_retarget_cooldown)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		return INITIALIZE_HINT_QDEL
	network = join_network
	var/list/unit_appearance = network.unit_appearances[unit_role]
	if(!islist(unit_appearance))
		unit_appearance = network.unit_appearances[MS13_HIVE_ROLE_SOLDIER]
	name = unit_appearance["name"]
	icon = unit_appearance["icon"]
	icon_state = unit_appearance["state"]
	pixel_x = unit_appearance["pixel_x"]
	pixel_y = unit_appearance["pixel_y"]
	icon_living = icon_state
	icon_dead = icon_state
	health = round(network.mob_health * health_multiplier)
	maxHealth = health
	melee_damage_lower = round(network.mob_damage_lower * damage_multiplier)
	melee_damage_upper = round(network.mob_damage_upper * damage_multiplier)
	terrain_dependent = network.mobs_require_terrain
	orphan_damage = network.mob_orphan_damage
	faction = list(network.faction_id)
	network.units |= src
	START_PROCESSING(SSobj, src)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout
	unit_role = MS13_HIVE_ROLE_SCOUT
	health_multiplier = 0.7
	damage_multiplier = 0.7
	corpse_hauler = FALSE
	move_to_delay = 1
	vision_range = 12
	aggro_vision_range = 14
	dodging = TRUE
	dodge_prob = 45
	roam_range = 20
	roam_min_distance = 10
	roam_retarget_delay = 12 SECONDS

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/footsoldier
	unit_role = MS13_HIVE_ROLE_SOLDIER
	corpse_hauler = TRUE
	dodging = TRUE
	dodge_prob = 25

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged
	unit_role = MS13_HIVE_ROLE_RANGED
	evolution_rank = 2
	health_multiplier = 0.9
	damage_multiplier = 0.7
	corpse_hauler = FALSE
	ranged = TRUE
	rapid = 3
	rapid_fire_delay = 2
	ranged_cooldown_time = 45
	retreat_distance = 3
	minimum_distance = 4
	check_friendly_fire = TRUE
	vision_range = 11
	aggro_vision_range = 12
	roam_range = 16
	roam_min_distance = 8

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ranged/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(network)
		projectiletype = network.ranged_projectile_type
		projectilesound = network.ranged_projectile_sound

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy
	unit_role = MS13_HIVE_ROLE_HEAVY
	evolution_rank = 3
	health_multiplier = 2.5
	damage_multiplier = 2
	off_terrain_damage_multiplier = 0
	corpse_hauler = FALSE
	move_to_delay = 6
	vision_range = 8
	aggro_vision_range = 10
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES | ENVIRONMENT_SMASH_WALLS
	obj_damage = 90
	roam_range = 12
	roam_min_distance = 6
	roam_retarget_delay = 20 SECONDS

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter
	unit_role = MS13_HIVE_ROLE_INFECTOR
	corpse_converter = TRUE
	corpse_hauler = FALSE
	health_multiplier = 1.25
	damage_multiplier = 0.75
	off_terrain_damage_multiplier = 0.5
	roam_range = 10
	roam_min_distance = 5

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/hauler
	unit_role = MS13_HIVE_ROLE_INFECTOR
	evolution_rank = 2
	health_multiplier = 1.35
	damage_multiplier = 0.7
	off_terrain_damage_multiplier = 0.5
	corpse_hauler = TRUE
	move_to_delay = 3
	roam_range = 14
	roam_min_distance = 7

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/Destroy()
	STOP_PROCESSING(SSobj, src)
	clear_corpse_task()
	clear_roam_target()
	if(network)
		network.units -= src
	network = null
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/process(delta_time)
	if(stat == DEAD)
		return PROCESS_KILL
	if(network?.active && network.is_territory(get_turf(src)))
		adjustHealth(-network.mob_regeneration * regeneration_multiplier * delta_time)
	else if(!network)
		if(orphan_damage)
			adjustHealth(orphan_damage * delta_time)
	else if(terrain_dependent)
		var/decay_damage = network.mob_off_terrain_damage * off_terrain_damage_multiplier
		if(decay_damage)
			adjustHealth(decay_damage * delta_time)
	if(QDELETED(src) || stat == DEAD)
		return PROCESS_KILL
	if(network?.active && can_field_convert_corpses())
		var/mob/living/corpse = corpse_target_ref?.resolve()
		if(network.is_convertible_corpse(corpse) && get_dist(src, corpse) <= 1 && !LAZYLEN(corpse.grabbed_by))
			var/conversion_time = corpse_converter ? network.converter_conversion_time : network.field_conversion_time
			if(network.advance_corpse_conversion(corpse, src, delta_time, conversion_time))
				corpse_target_ref = null

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/handle_automated_action()
	set waitfor = FALSE
	if(AIStatus == AI_OFF || !network?.active)
		return FALSE
	if(target)
		clear_corpse_task()
		clear_roam_target()
		return ..()
	if(handle_terrain_recovery())
		return TRUE
	if(FindTarget(ListTargets(), TRUE))
		clear_corpse_task()
		clear_roam_target()
		return ..()
	if(handle_corpse_work())
		roam_target = null
		return TRUE
	if(handle_roaming())
		return TRUE
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/consider_wakeup()
	. = ..()
	if(AIStatus == AI_IDLE && network?.active && (network.find_reported_corpse(src) || roam_range))
		toggle_ai(AI_ON)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/ListTargets()
	. = ..()
	for(var/obj/structure/window/ms13_vehicle_wall/wall in oview(vision_range, src))
		if(is_vehicle_hull_target(wall))
			. |= wall

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/CanAttack(atom/the_target)
	if(istype(the_target, /obj/structure/window/ms13_vehicle_wall))
		return is_vehicle_hull_target(the_target)
	var/mob/living/living_target = the_target
	if(istype(living_target) && network?.is_convertible_corpse(living_target))
		network.report_corpse(living_target)
		return FALSE
	return ..()

/// Tank-grade hull is futile prey except at its hatches; lighter hull can be torn open anywhere.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/is_vehicle_hull_target(obj/structure/window/ms13_vehicle_wall/wall)
	var/datum/ms13_ground_vehicle/vehicle = wall?.parent_frame?.vehicle
	if(!vehicle || !wall.exterior || !wall.density)
		return FALSE
	var/heavy_armor = FALSE
	for(var/obj/structure/window/ms13_vehicle_wall/candidate as anything in vehicle.walls)
		if(istype(candidate, /obj/structure/window/ms13_vehicle_wall/solid/civ96/tank) || istype(candidate, /obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank))
			heavy_armor = TRUE
			break
	return !heavy_armor || istype(wall, /obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/can_field_convert_corpses()
	return corpse_converter || network?.base_units_convert_corpses || (unit_role == MS13_HIVE_ROLE_HEAVY && network?.elite_units_convert_corpses)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/can_work_corpses()
	return can_field_convert_corpses() || (corpse_hauler && network?.units_haul_corpses)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/handle_terrain_recovery()
	if(!terrain_dependent || network.is_territory(get_turf(src)) || health > maxHealth * terrain_recovery_health)
		return FALSE
	var/obj/structure/ms13_hivemind/terrain/growth = get_closest_atom(/obj/structure/ms13_hivemind/terrain, network.territory, src)
	if(!growth || get_dist(src, growth) > terrain_recovery_range)
		return FALSE
	clear_corpse_task()
	clear_roam_target()
	Goto(growth, move_to_delay, 0)
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/clear_corpse_task(release_body = TRUE)
	var/mob/living/corpse = corpse_target_ref?.resolve()
	if(corpse)
		if(release_body)
			release_grabs(corpse)
		network?.release_corpse_claim(corpse, src)
	corpse_target_ref = null
	SSmove_manager.stop_looping(src)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/find_local_corpses()
	for(var/mob/living/corpse in view(network.corpse_search_range, src))
		if(network.is_convertible_corpse(corpse))
			network.report_corpse(corpse)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/handle_corpse_work()
	find_local_corpses()
	if(!can_work_corpses())
		return FALSE
	var/mob/living/corpse = corpse_target_ref?.resolve()
	var/datum/current_claim = network.is_convertible_corpse(corpse) ? network.get_corpse_claim(corpse) : null
	if(!network.is_convertible_corpse(corpse) || (current_claim && current_claim != src))
		clear_corpse_task()
		corpse = network.find_reported_corpse(src)
		if(!corpse || !network.claim_corpse(corpse, src))
			return FALSE
		corpse_target_ref = WEAKREF(corpse)
	if(can_field_convert_corpses())
		if(get_dist(src, corpse) > 1)
			Goto(corpse, move_to_delay, 1)
		else
			SSmove_manager.stop_looping(src)
		return TRUE
	if(!corpse_hauler || !network.units_haul_corpses)
		return FALSE
	if(!is_grabbing(corpse))
		if(get_dist(src, corpse) > 1)
			Goto(corpse, move_to_delay, 1)
			return TRUE
		if(!try_make_grab(corpse))
			clear_corpse_task(FALSE)
			return FALSE
		// Let the grab exist for at least one AI tick so hauling remains readable to nearby players.
		return TRUE
	var/obj/structure/ms13_hivemind/destination = network.get_corpse_delivery_target(src)
	if(!destination)
		clear_corpse_task()
		return FALSE
	if(get_dist(src, destination) > 1)
		Goto(destination, move_to_delay, 1)
		return TRUE
	release_grabs(corpse)
	corpse.forceMove(get_turf(src))
	network.release_corpse_claim(corpse, src, FALSE)
	network.claim_corpse(corpse, destination)
	corpse_target_ref = null
	SSmove_manager.stop_looping(src)
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/clear_roam_target()
	roam_target = null
	SSmove_manager.stop_looping(src)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/pick_roam_target()
	if(!isturf(loc) || roam_range <= 0)
		return
	for(var/attempt in 1 to 16)
		var/x_offset = rand(-roam_range, roam_range)
		var/y_offset = rand(-roam_range, roam_range)
		if(max(abs(x_offset), abs(y_offset)) < roam_min_distance)
			continue
		var/turf/candidate = locate(x + x_offset, y + y_offset, z)
		if(!isopenturf(candidate) || candidate.density || istype(candidate, /turf/open/space) || istype(candidate, /turf/open/chasm) || istype(candidate, /turf/open/lava) || istype(candidate, /turf/open/openspace))
			continue
		// Prefer destinations beyond the growth so a crowd disperses out of its spawn room.
		if(attempt <= 12 && network.is_territory(candidate))
			continue
		return candidate

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/handle_roaming()
	if(roam_range <= 0 || !isturf(loc))
		return FALSE
	if(!roam_target || roam_target.z != z || get_dist(src, roam_target) <= 1 || COOLDOWN_FINISHED(src, roam_retarget_cooldown))
		roam_target = pick_roam_target()
		if(!roam_target)
			return FALSE
		COOLDOWN_START(src, roam_retarget_cooldown, roam_retarget_delay)
	if(environment_smash)
		var/roam_direction = get_dir(src, roam_target)
		var/list/smash_directions = ISDIAGONALDIR(roam_direction) ? list(roam_direction & (NORTH | SOUTH), roam_direction & (EAST | WEST)) : list(roam_direction)
		for(var/direction in smash_directions)
			var/turf/next_turf = get_step(src, direction)
			if(!next_turf)
				continue
			var/blocked_by_hive = FALSE
			for(var/obj/structure/ms13_hivemind/friendly_structure in next_turf)
				if(friendly_structure.network == network && friendly_structure.density)
					blocked_by_hive = TRUE
					break
			if(!blocked_by_hive)
				DestroyObjectsInDirection(direction)
	Goto(roam_target, move_to_delay, 0)
	return TRUE

/client/proc/ms13_spawn_terrain_hivemind()
	set category = "Debug"
	set name = "MS13 - Spawn Terrain Hivemind"

	if(!check_rights(R_DEBUG))
		return
	var/list/variants = list(
		"CEV-Eris machine hive" = /datum/ms13_terrain_hivemind/eris,
		"Daedalus flock" = /datum/ms13_terrain_hivemind/flock,
		"DS13 necromorph corruption" = /datum/ms13_terrain_hivemind/necromorph,
		"SS13 blob" = /datum/ms13_terrain_hivemind/blob,
		"TGMC xenomorph hive" = /datum/ms13_terrain_hivemind/xenomorph,
	)
	var/variant = tgui_input_list(src, "Choose the terrain-enemy theme.", "Terrain Hivemind", variants)
	if(!variant)
		return
	var/list/limits = list("Contained (60 tiles)" = 60, "Regional (150 tiles)" = 150, "Major (300 tiles)" = 300, "Unbounded" = 0)
	var/limit = tgui_input_list(src, "Choose its maximum territory. Unbounded networks keep growing while reachable open terrain remains.", "Terrain Hivemind", limits, "Contained (60 tiles)")
	if(!limit)
		return
	var/list/locations = list("My current tile")
	if(holder?.marked_datum)
		locations += "Marked datum"
	var/location = tgui_input_list(src, "Choose the core location.", "Terrain Hivemind", locations, locations[1])
	if(!location)
		return
	var/turf/target = get_turf(location == "Marked datum" ? holder.marked_datum : mob)
	if(!target || !isopenturf(target) || target.density || (target.resistance_flags & INDESTRUCTIBLE))
		to_chat(src, span_warning("The core requires a destructible open turf."), confidential = TRUE)
		return
	if(locate(/obj/structure/ms13_hivemind) in target)
		to_chat(src, span_warning("A terrain hivemind already occupies that tile."), confidential = TRUE)
		return
	var/limit_description = limit == "Unbounded" ? "no territory limit" : "a [limits[limit]]-tile limit"
	if(tgui_alert(src, "Spawn [variant] at [AREACOORD(target)] with [limit_description]?", "Confirm Terrain Hivemind", list("Cancel", "Spawn")) != "Spawn")
		return
	var/hive_type = variants[variant]
	var/datum/ms13_terrain_hivemind/network = new hive_type(target, limits[limit])
	message_admins(span_adminnotice("[key_name_admin(src)] spawned [network.name] at [ADMIN_COORDJMP(target)] ([limit])."))
	log_admin("[key_name(src)] spawned [network.name] at [AREACOORD(target)] ([limit]).")

#undef MS13_HIVE_ROLE_SCOUT
#undef MS13_HIVE_ROLE_SOLDIER
#undef MS13_HIVE_ROLE_RANGED
#undef MS13_HIVE_ROLE_HEAVY
#undef MS13_HIVE_ROLE_INFECTOR
#undef MS13_HIVE_CORPSE_EFFECT_BLOOD
#undef MS13_HIVE_CORPSE_EFFECT_GOO
#undef MS13_HIVE_CORPSE_EFFECT_SPARKS
