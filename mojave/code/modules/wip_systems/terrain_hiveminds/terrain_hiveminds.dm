GLOBAL_LIST_EMPTY(ms13_terrain_hiveminds)

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
	var/mobs_require_terrain = FALSE
	var/terrain_name = "hivemind growth"
	var/mob_name = "hivemind drone"
	var/icon/terrain_icon
	var/terrain_icon_state
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
	var/icon/mob_icon
	var/mob_icon_state
	var/core_type = /obj/structure/ms13_hivemind/core
	var/terrain_type = /obj/structure/ms13_hivemind/terrain
	var/mob_type = /mob/living/simple_animal/hostile/ms13/terrain_hivemind
	var/list/special_types = list(
		/obj/structure/ms13_hivemind/special/wall,
		/obj/structure/ms13_hivemind/special/trap,
		/obj/structure/ms13_hivemind/special/turret,
		/obj/structure/ms13_hivemind/special/spawner,
	)
	var/obj/structure/ms13_hivemind/core/core
	var/list/territory = list()
	var/list/frontier = list()
	var/list/specials = list()
	var/list/units = list()
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
	return ..()

/datum/ms13_terrain_hivemind/process(delta_time)
	if(!active || !core || QDELETED(core))
		return PROCESS_KILL
	resources = min(max_resources, resources + length(territory) * resource_per_tile * delta_time)
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

/datum/ms13_terrain_hivemind/proc/unregister_terrain(obj/structure/ms13_hivemind/terrain/growth)
	territory -= growth
	frontier -= growth
	for(var/obj/structure/ms13_hivemind/terrain/neighbor in range(1, growth))
		if(neighbor.network == src)
			update_frontier(neighbor)

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

/datum/ms13_terrain_hivemind/blob
	name = "SS13 blob"
	abstract = FALSE
	faction_id = ROLE_BLOB
	resource_per_tile = 0.3
	spread_delay = 2 SECONDS
	mobs_require_terrain = TRUE
	terrain_name = "pulsating blob"
	mob_name = "blob spore"
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
	mob_icon = 'icons/mob/blob.dmi'
	mob_icon_state = "blobpod"

/datum/ms13_terrain_hivemind/flock
	name = "Daedalus flock"
	abstract = FALSE
	faction_id = FACTION_FLOCK
	mob_regeneration = 3
	terrain_name = "gnesis floor"
	mob_name = "flockbit"
	terrain_icon = 'goon/icons/mob/featherzone.dmi'
	terrain_icon_state = "floor"
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
	mob_icon = 'goon/icons/mob/featherzone.dmi'
	mob_icon_state = "flockbit"

/datum/ms13_terrain_hivemind/necromorph
	name = "DS13 necromorph corruption"
	abstract = FALSE
	faction_id = "ms13_necromorph"
	resource_per_tile = 0.15
	mobs_require_terrain = TRUE
	mob_health = 65
	mob_damage_lower = 10
	mob_damage_upper = 16
	terrain_name = "necromorph corruption"
	mob_name = "necromorph swarmer"
	terrain_icon = 'mojave/icons/wip/terrain_hivemind/ds13_corruption.dmi'
	terrain_icon_state = "corruption-1"
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
	mob_icon = 'mojave/icons/wip/terrain_hivemind/ds13_swarmer.dmi'
	mob_icon_state = "swarmer1"

/datum/ms13_terrain_hivemind/eris
	name = "CEV-Eris machine hive"
	abstract = FALSE
	faction_id = "ms13_eris_hive"
	resource_per_tile = 0.25
	mob_health = 60
	mob_damage_lower = 9
	mob_damage_upper = 14
	terrain_name = "hivemind wireweed"
	mob_name = "hivemind slicer"
	terrain_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind.dmi'
	terrain_icon_state = "wires1"
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
	mob_icon = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi'
	mob_icon_state = "slicer"

/obj/structure/ms13_hivemind
	anchored = TRUE
	obj_flags = CAN_BE_HIT

/obj/structure/ms13_hivemind/core
	name = "hivemind core"
	desc = "The coordinating heart of an expanding hostile terrain network."
	density = TRUE
	max_integrity = 300
	var/datum/ms13_terrain_hivemind/network

/obj/structure/ms13_hivemind/core/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		return INITIALIZE_HINT_QDEL
	network = join_network
	name = "[network.name] core"
	icon = network.core_icon
	icon_state = network.core_icon_state

/obj/structure/ms13_hivemind/core/Destroy()
	if(network)
		var/datum/ms13_terrain_hivemind/old_network = network
		network = null
		old_network.core = null
		qdel(old_network)
	return ..()

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
	var/datum/ms13_terrain_hivemind/network

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
	if(old_network)
		old_network.unregister_terrain(src)
	for(var/obj/structure/ms13_hivemind/special/structure in loc)
		if(structure.network == old_network)
			qdel(structure)
	network = null
	return ..()

/obj/structure/ms13_hivemind/special
	name = "hivemind structure"
	desc = "A specialized growth fed by the surrounding hostile terrain."
	max_integrity = 90
	var/datum/ms13_terrain_hivemind/network

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
	max_integrity = 140

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
	var/damage = 15
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
		if(candidate.stat == DEAD || network.is_allied(candidate))
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
	if(length(network.units) >= network.max_units || !COOLDOWN_FINISHED(src, spawn_cooldown) || !network.spend(network.unit_cost))
		return
	new network.mob_type(get_turf(src), network)
	COOLDOWN_START(src, spawn_cooldown, network.unit_spawn_delay)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	name = "hivemind drone"
	desc = "A creature sustained by a hostile terrain network."
	icon = 'icons/mob/blob.dmi'
	icon_state = "blobpod"
	icon_living = "blobpod"
	icon_dead = "blobpod"
	health = 50
	maxHealth = 50
	melee_damage_lower = 8
	melee_damage_upper = 12
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

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(!join_network)
		return INITIALIZE_HINT_QDEL
	network = join_network
	name = network.mob_name
	icon = network.mob_icon
	icon_state = network.mob_icon_state
	icon_living = network.mob_icon_state
	icon_dead = network.mob_icon_state
	health = network.mob_health
	maxHealth = network.mob_health
	melee_damage_lower = network.mob_damage_lower
	melee_damage_upper = network.mob_damage_upper
	terrain_dependent = network.mobs_require_terrain
	faction = list(network.faction_id)
	network.units |= src
	START_PROCESSING(SSobj, src)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(network)
		network.units -= src
	network = null
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/process(delta_time)
	if(stat == DEAD)
		return PROCESS_KILL
	if(network?.active && network.is_territory(get_turf(src)))
		adjustHealth(-network.mob_regeneration * delta_time)
	else if(!network || terrain_dependent)
		var/decay_damage = network ? network.mob_off_terrain_damage : 3
		adjustHealth(decay_damage * delta_time)

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
