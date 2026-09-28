/// Shared placement check. Live mobs, machines and structures keep their tile clear.
/proc/ms13_ecology_clear_tile(turf/tile)
	if(!isfloorturf(tile) || tile.density)
		return FALSE
	for(var/atom/movable/occupant in tile)
		if(occupant.density || istype(occupant, /obj/machinery) || istype(occupant, /obj/structure) || isliving(occupant))
			return FALSE
	return TRUE

/// Explicitly excludes asphalt, sidewalks, ice, water and constructed floors.
/proc/ms13_flora_soil(turf/tile)
	return istype(tile, /turf/open/floor/plating/ms13/ground/desert) || istype(tile, /turf/open/floor/plating/ms13/ground/desertalt) || istype(tile, /turf/open/floor/plating/ms13/ground/snow) || istype(tile, /turf/open/floor/plating/ms13/ground/mountain) || istype(tile, /turf/open/floor/plating/dirt/ms13)

/obj/effect/spawner/ms13/flora
	parent_type = /obj/effect
	name = "regrowing flora - desert patch"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x"
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	/// Zero is an exact single planting point. Area mode uses the whole containing area.
	var/radius = 10
	var/area_mode = FALSE
	var/max_plants = 20
	var/min_spacing = 2
	var/regrow_delay_min = 16 MINUTES
	var/regrow_delay_max = 24 MINUTES
	/// Plain list; repeat entries to weight a species. A one-entry list picks an exact object type.
	var/list/plant_types = list(/obj/structure/flora/ms13/leafy, /obj/structure/flora/ms13/cactus, /obj/structure/flora/ms13/forage/yucca, /obj/structure/flora/ms13/forage/brocflower/drought, /obj/structure/flora/ms13/forage/xander/drought)
	/// Only this opt-in permits precise plantings on constructed floors.
	var/require_soil = TRUE
	var/list/candidates = list()
	/// Turf -> weak plant reference (null while waiting for regrowth).
	var/list/plant_slots = list()
	var/list/regrow_at = list()
	var/list/slot_types = list()
	var/next_check = 0
	var/datum/weakref/owner_area

/obj/effect/spawner/ms13/flora/Initialize(mapload, whole_area = FALSE, population_override)
	. = ..()
	if(whole_area)
		area_mode = TRUE
	if(!isnull(population_override))
		max_plants = population_override
	radius = clamp(round(radius), 0, 40)
	max_plants = clamp(round(max_plants), 0, 300)
	min_spacing = clamp(round(min_spacing), 0, 8)
	regrow_delay_min = max(regrow_delay_min, 30 SECONDS)
	regrow_delay_max = max(regrow_delay_min, regrow_delay_max)
	var/list/valid_types = list()
	for(var/plant_type in plant_types)
		if(ispath(plant_type, /obj/structure/flora))
			valid_types += plant_type
	plant_types = valid_types
	if(!length(plant_types))
		stack_trace("Flora spawner at [AREACOORD(src)] has no valid plant_types.")
		return INITIALIZE_HINT_QDEL
	return INITIALIZE_HINT_LATELOAD

/obj/effect/spawner/ms13/flora/LateInitialize()
	var/area/region = get_area(src)
	if(!region)
		return
	owner_area = WEAKREF(region)
	if(area_mode)
		// Stored once; processing visits the capped planting slots, not every turf in the area.
		candidates = region.get_contained_turfs().Copy()
	else
		candidates = RANGE_TURFS(radius, src)
	START_PROCESSING(SSobj, src)
	process()

/obj/effect/spawner/ms13/flora/Destroy()
	STOP_PROCESSING(SSobj, src)
	for(var/turf/tile as anything in plant_slots)
		var/datum/weakref/reference = plant_slots[tile]
		var/obj/structure/flora/plant = reference?.resolve()
		if(plant?.ms13_flora_owner?.resolve() == src)
			plant.ms13_flora_owner = null
	candidates.Cut()
	plant_slots.Cut()
	regrow_at.Cut()
	slot_types.Cut()
	owner_area = null
	return ..()

/obj/effect/spawner/ms13/flora/proc/valid_tile(turf/tile, check_spacing = TRUE)
	if(!tile || (area_mode && get_area(tile) != owner_area?.resolve()) || (require_soil && !ms13_flora_soil(tile)) || !ms13_ecology_clear_tile(tile))
		return FALSE
	if(check_spacing && min_spacing)
		for(var/obj/structure/flora/nearby in range(min_spacing, tile))
			return FALSE
		for(var/turf/reserved as anything in plant_slots)
			if(reserved != tile && reserved.z == tile.z && get_dist(reserved, tile) <= min_spacing)
				return FALSE
	return TRUE

/obj/effect/spawner/ms13/flora/proc/plant_at(turf/tile, plant_type)
	if(!valid_tile(tile) || !ispath(plant_type, /obj/structure/flora))
		return
	var/obj/structure/flora/plant = new plant_type(tile)
	plant.ms13_flora_owner = WEAKREF(src)
	plant_slots[tile] = WEAKREF(plant)
	slot_types[tile] = plant_type
	regrow_at -= tile
	return plant

/obj/effect/spawner/ms13/flora/process(delta_time)
	if(world.time < next_check)
		return
	next_check = world.time + 30 SECONDS
	for(var/turf/tile as anything in plant_slots)
		var/datum/weakref/reference = plant_slots[tile]
		if(reference?.resolve())
			continue
		if(isnull(regrow_at[tile]))
			regrow_at[tile] = world.time + rand(regrow_delay_min, regrow_delay_max)
		if(world.time >= regrow_at[tile])
			plant_at(tile, slot_types[tile])
	if(length(plant_slots) >= max_plants || !length(candidates))
		return
	// Twenty attempts per pass bounds sparse or mostly built-up area work.
	for(var/i in 1 to 20)
		if(length(plant_slots) >= max_plants)
			break
		var/turf/tile = pick(candidates)
		if(tile in plant_slots)
			continue
		var/obj/structure/flora/existing = locate() in tile
		if(existing)
			// Count mapped flora toward the cap and let it regrow too. Overlapping spawners share no plants.
			if(!existing.ms13_flora_owner?.resolve())
				existing.ms13_flora_owner = WEAKREF(src)
				plant_slots[tile] = WEAKREF(existing)
				slot_types[tile] = existing.type
			continue
		plant_at(tile, pick(plant_types))

/obj/effect/spawner/ms13/flora/single
	name = "regrowing flora - precise object"
	radius = 0
	max_plants = 1
	min_spacing = 0
	plant_types = list(/obj/structure/flora/ms13/forage/brocflower/drought)

/obj/effect/spawner/ms13/flora/woodland
	name = "regrowing flora - woodland patch"
	plant_types = list(/obj/structure/flora/ms13/tree/tallpine, /obj/structure/flora/ms13/leafy, /obj/structure/flora/ms13/forage/blackberry, /obj/structure/flora/ms13/forage/mutfruit)
	min_spacing = 3

/obj/effect/spawner/ms13/flora/cave
	name = "regrowing flora - cave fungi"
	plant_types = list(/obj/structure/flora/ms13/forage/mushroom, /obj/structure/flora/ms13/forage/mushroom/glowing)

/obj/effect/spawner/ms13/flora/area
	name = "regrowing flora - entire area"
	area_mode = TRUE
	max_plants = 100

/area/ms13
	/// Optional spawner subtype, e.g. /obj/effect/spawner/ms13/flora/woodland. Null leaves the area alone.
	var/flora_spawner_type
	var/flora_population = 100
	var/obj/effect/spawner/ms13/flora/ecology_spawner

/area/ms13/LateInitialize()
	. = ..()
	if(ispath(flora_spawner_type, /obj/effect/spawner/ms13/flora) && !ecology_spawner)
		var/list/tiles = get_contained_turfs()
		if(length(tiles))
			ecology_spawner = new flora_spawner_type(tiles[1], TRUE, flora_population)

/area/ms13/Destroy()
	QDEL_NULL(ecology_spawner)
	return ..()

/obj/structure/flora
	var/tmp/datum/weakref/ms13_flora_owner
	var/tmp/ms13_grazed_until = 0

/obj/structure/flora/proc/ms13_can_graze()
	if(world.time < ms13_grazed_until || QDELETED(src))
		return FALSE
	if(istype(src, /obj/structure/flora/ms13/forage))
		var/obj/structure/flora/ms13/forage/plant = src
		return !plant.harvested
	if(istype(src, /obj/structure/flora/ms13/tree/drought/dead) || istype(src, /obj/structure/flora/ms13/tree/tallpine/dead))
		return FALSE
	return herbage || istype(src, /obj/structure/flora/ms13/tree) || istype(src, /obj/structure/flora/ms13/leafy) || istype(src, /obj/structure/flora/ms13/cactus)

/obj/structure/flora/proc/ms13_graze()
	if(!ms13_can_graze())
		return FALSE
	ms13_grazed_until = world.time + 20 MINUTES
	if(istype(src, /obj/structure/flora/ms13/forage))
		var/obj/structure/flora/ms13/forage/plant = src
		return plant.harvest(null, FALSE)
	// Browse leaves from trees; small vegetation is eaten away and its spawner can replace it.
	if(!istype(src, /obj/structure/flora/ms13/tree) && !wood)
		qdel(src)
	return TRUE
