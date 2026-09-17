/**
 * Round-start house power. Every enclosed building in an area that allows it (/area/ms13/var/house_power) gets
 * its own powered area and a random setup from the area's house_power_outcome(): a generator that's running,
 * switched off or broken, wired to a utility box; a utility box that works on its own; or nothing, leaving the
 * house dark.
 *
 * The generator and box are joined by real cable, which may be snipped or frayed along the way.
 *
 * A building is a patch of indoor floor bounded by walls, windows and doors, with almost no open gaps to the
 * ground outside. Buildings with airlocks (which need power to open), or with power gear already mapped in,
 * are left alone. A /obj/effect/spawner/ms13_house_power inside a building forces its outcome.
 */
#define HOUSE_POWER_MIN_SIZE 6
#define HOUSE_POWER_MAX_SIZE 300
/// Open gaps to the outside a building can have and still count as enclosed (a smashed window, say).
#define HOUSE_POWER_MAX_LEAKS 2
#define HOUSE_POWER_FAULT_SNIP "snip"
#define HOUSE_POWER_FAULT_FRAY "fray"

/// Turf -> outcome forced by a mapped /obj/effect/spawner/ms13_house_power.
GLOBAL_LIST_EMPTY(ms13_house_power_overrides)

SUBSYSTEM_DEF(ms13_house_power)
	name = "House Power"
	init_order = INIT_ORDER_MS13_HOUSE_POWER
	flags = SS_NO_FIRE
	/// House area -> outcome, for admins and tests.
	var/list/houses = list()

/datum/controller/subsystem/ms13_house_power/Initialize(timeofday)
	var/list/visited = list()
	for(var/area/ms13/place in GLOB.areas.Copy())
		var/list/seeds = list()
		for(var/turf/tile in place)
			if(is_building_floor(tile))
				seeds += tile
		for(var/turf/seed as anything in seeds)
			if(visited[seed])
				continue
			try_power(find_building(seed, visited))
			CHECK_TICK
	var/list/tally = list()
	for(var/area/house as anything in houses)
		tally[houses[house]]++
	var/list/summary = list()
	for(var/outcome in tally)
		summary += "[tally[outcome]] [outcome]"
	log_world("House power: [length(houses)] buildings ([english_list(summary, "none")]).")
	return ..()

/datum/controller/subsystem/ms13_house_power/proc/is_building_floor(turf/tile)
	if(!istype(tile, /turf/open/floor/ms13) && !istype(tile, /turf/open/floor/wood/ms13))
		return FALSE
	return !has_blocker(tile)

/// Something that walls a tile off: a window, a window frame, a low wall.
/datum/controller/subsystem/ms13_house_power/proc/has_blocker(turf/tile)
	var/static/list/blockers = typecacheof(list(/obj/structure/window, /obj/structure/ms13/frame, /obj/structure/low_wall))
	for(var/obj/thing as anything in tile)
		if(blockers[thing.type])
			return TRUE
	return FALSE

/datum/controller/subsystem/ms13_house_power/proc/has_door(turf/tile)
	return (locate(/obj/machinery/door) in tile) || (locate(/obj/structure/mineral_door) in tile) || (locate(/obj/structure/ms13/celldoor) in tile)

/// All building floor connected to seed, marking each tile in visited.
/datum/controller/subsystem/ms13_house_power/proc/find_building(turf/seed, list/visited)
	var/list/building = list(seed)
	visited[seed] = TRUE
	var/index = 1
	while(index <= length(building))
		var/turf/current = building[index++]
		for(var/dir in GLOB.cardinals)
			var/turf/next = get_step(current, dir)
			if(!next || visited[next] || !is_building_floor(next))
				continue
			visited[next] = TRUE
			building += next
	return building

/// Walls, windows and doors all the way round, give or take a gap or two.
/datum/controller/subsystem/ms13_house_power/proc/is_enclosed(list/inside)
	var/leaks = 0
	for(var/turf/tile as anything in inside)
		for(var/dir in GLOB.cardinals)
			var/turf/next = get_step(tile, dir)
			if(!next || inside[next] || next.density)
				continue
			if(has_blocker(next) || has_door(tile) || has_door(next))
				continue
			if(++leaks > HOUSE_POWER_MAX_LEAKS)
				return FALSE
	return TRUE

/datum/controller/subsystem/ms13_house_power/proc/try_power(list/building)
	if(length(building) < HOUSE_POWER_MIN_SIZE || length(building) > HOUSE_POWER_MAX_SIZE)
		return
	var/area/ms13/place = get_area(building[1])
	var/list/inside = list()
	var/forced
	for(var/turf/tile as anything in building)
		if(tile.loc != place)
			return
		inside[tile] = TRUE
		forced ||= GLOB.ms13_house_power_overrides[tile]
		for(var/obj/machinery/machine in tile)
			if(istype(machine, /obj/machinery/door/airlock) || istype(machine, /obj/machinery/power/apc) || istype(machine, /obj/machinery/ms13/fusion_generator))
				return
	if(!is_enclosed(inside))
		return
	var/outcome = forced || place.house_power_outcome(building)
	if(!outcome)
		return
	var/roll = rand(1, 100)
	power_building(building, outcome, roll <= 35 ? 0 : roll <= 75 ? 1 : 2)

/**
 * Gives building its own area and sets it up for outcome, with faults snips or frays along the cable.
 * Returns the new area.
 */
/datum/controller/subsystem/ms13_house_power/proc/power_building(list/building, outcome, faults = 0, list/fault_types)
	var/list/inside = list()
	for(var/turf/tile as anything in building)
		inside[tile] = TRUE
	var/area/house = make_house_area(building)
	houses[house] = outcome
	if(outcome == "none")
		return house

	var/turf/generator_spot
	if(outcome != "box_only")
		generator_spot = pick_generator_spot(building, inside)
		if(!generator_spot)
			outcome = "box_only"
			houses[house] = outcome
	var/list/box_spot = pick_box_spot(building, inside, generator_spot)
	if(!box_spot)
		return house

	var/list/created = list()
	SSatoms.map_loader_begin(REF(src))
	if(generator_spot)
		created += lay_cable(find_path(generator_spot, box_spot[1], inside), faults, fault_types)
		created += new /obj/structure/ms13/rug/rubber(generator_spot)
		var/obj/machinery/ms13/fusion_generator/generator = new(generator_spot)
		generator.generator_state = outcome == "working" ? "on" : outcome
		generator.fuel = round(generator.max_fuel * rand(15, 100) / 100)
		generator.condition = outcome == "broken" ? 0 : rand(35, 100)
		created += generator
	var/box_type = text2path("/obj/machinery/power/apc/ms13/directional/[dir2text(box_spot[2])]")
	var/obj/machinery/power/apc/ms13/box = new box_type(box_spot[1])
	box.always_powered = outcome == "box_only"
	created += box
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(created)
	// A terminal doesn't find its cable by itself; round start rebuilds powernets anyway, later calls don't.
	box.terminal?.connect_to_network()
	return house

/// A copy of the building's area, but needing power, holding just the building.
/datum/controller/subsystem/ms13_house_power/proc/make_house_area(list/building)
	var/area/old_area = get_area(building[1])
	SSatoms.map_loader_begin(REF(src))
	var/area/house = new old_area.type
	SSatoms.map_loader_stop(REF(src))
	// Unique areas register themselves by type; the map's instance keeps that slot.
	if(GLOB.areas_by_type[old_area.type] == house)
		GLOB.areas_by_type[old_area.type] = old_area
	house.area_flags &= ~UNIQUE_AREA
	house.name = old_area.name
	house.requires_power = TRUE
	house.always_unpowered = FALSE
	house.power_light = FALSE
	house.power_equip = FALSE
	house.power_environ = FALSE
	SSatoms.InitializeAtoms(list(house))
	for(var/turf/tile as anything in building)
		tile.change_area(old_area, house)
	house.reg_in_areas_in_z()
	return house

/// Nothing solid, fixed or in the way of a doorway.
/datum/controller/subsystem/ms13_house_power/proc/is_clear(turf/tile)
	if(tile.density || has_door(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(thing.density || istype(thing, /obj/structure) || istype(thing, /obj/machinery))
			return FALSE
	for(var/dir in GLOB.cardinals)
		var/turf/next = get_step(tile, dir)
		if(next && has_door(next))
			return FALSE
	return TRUE

/datum/controller/subsystem/ms13_house_power/proc/wall_dirs(turf/tile)
	. = list()
	for(var/dir in GLOB.cardinals)
		var/turf/next = get_step(tile, dir)
		if(next?.density)
			. += dir

/// Tucked against the walls, with room for the whole sprite if there is any.
/datum/controller/subsystem/ms13_house_power/proc/pick_generator_spot(list/building, list/inside)
	var/list/best = list()
	var/best_score = 0
	for(var/turf/tile as anything in building)
		if(!is_clear(tile))
			continue
		var/score = length(wall_dirs(tile))
		var/turf/east = get_step(tile, EAST)
		var/turf/north = get_step(tile, NORTH)
		var/turf/north_east = get_step(east, NORTH)
		if(inside[east] && inside[north] && inside[north_east] && is_clear(east) && is_clear(north) && is_clear(north_east))
			score += 10
		if(score > best_score)
			best = list(tile)
			best_score = score
		else if(score && score == best_score)
			best += tile
	return length(best) ? pick(best) : null

/// A clear bit of wall a few steps from the generator. Returns list(turf, wall direction).
/datum/controller/subsystem/ms13_house_power/proc/pick_box_spot(list/building, list/inside, turf/generator_spot)
	var/list/distances = generator_spot ? path_distances(generator_spot, inside) : null
	var/list/good = list()
	var/list/fallback = list()
	for(var/turf/tile as anything in building)
		if(tile == generator_spot || !is_clear(tile))
			continue
		var/list/walls = wall_dirs(tile)
		if(!length(walls))
			continue
		var/spot = list(tile, pick(walls))
		if(!distances)
			good += list(spot)
			continue
		var/distance = distances[tile]
		if(!distance)
			continue
		if(distance >= 3 && distance <= 12)
			good += list(spot)
		else
			fallback += list(spot)
	if(length(good))
		return pick(good)
	return length(fallback) ? pick(fallback) : null

/// Steps from start to every building tile it can reach.
/datum/controller/subsystem/ms13_house_power/proc/path_distances(turf/start, list/inside)
	var/list/distances = list()
	distances[start] = 0
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/dir in GLOB.cardinals)
			var/turf/next = get_step(current, dir)
			if(!next || !inside[next] || !isnull(distances[next]) || next.density)
				continue
			distances[next] = distances[current] + 1
			queue += next
	return distances

/// Shortest walk from start to finish through the building, both ends included.
/datum/controller/subsystem/ms13_house_power/proc/find_path(turf/start, turf/finish, list/inside)
	var/list/came_from = list()
	came_from[start] = start
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		if(current == finish)
			break
		for(var/dir in GLOB.cardinals)
			var/turf/next = get_step(current, dir)
			if(!next || !inside[next] || came_from[next] || next.density)
				continue
			came_from[next] = current
			queue += next
	if(!came_from[finish])
		return null
	var/list/path = list(finish)
	while(path[1] != start)
		path.Insert(1, came_from[path[1]])
	return path

/**
 * Lays one run of cable along path, knotted at both ends, with faults tiles along the middle snipped out or
 * frayed. fault_types forces the kinds, in order. Returns the new (uninitialized) atoms.
 */
/datum/controller/subsystem/ms13_house_power/proc/lay_cable(list/path, faults, list/fault_types)
	. = list()
	if(length(path) < 2)
		return
	var/list/faulty = list()
	var/list/middle = path.Copy(2, length(path))
	for(var/i in 1 to min(faults, length(middle)))
		var/turf/tile = pick_n_take(middle)
		faulty[tile] = LAZYACCESS(fault_types, i) || pick(HOUSE_POWER_FAULT_SNIP, HOUSE_POWER_FAULT_FRAY)
	var/cable_color = GLOB.cable_colors[pick(GLOB.cable_colors)]
	for(var/i in 1 to length(path))
		var/turf/tile = path[i]
		var/dirs = NONE
		if(i > 1)
			dirs |= GLOB.real_dirs_to_cable_dirs["[get_dir(tile, path[i - 1])]"]
		if(i < length(path))
			dirs |= GLOB.real_dirs_to_cable_dirs["[get_dir(tile, path[i + 1])]"]
		switch(faulty[tile])
			if(HOUSE_POWER_FAULT_SNIP)
				continue
			if(HOUSE_POWER_FAULT_FRAY)
				var/obj/structure/ms13_frayed_cable/frayed = new(tile)
				frayed.cable_dirs = dirs
				frayed.color = cable_color
				. += frayed
			else
				var/obj/structure/cable/wire = new(tile)
				wire.icon_state = "[dirs]"
				wire.color = cable_color
				. += wire

/**
 * A length of house wiring chewed down to bare copper. It carries no current, but it bites anyone who grabs it
 * while the cable it joins is live. Splice it with a cable coil, or cut it out.
 */
/obj/structure/ms13_frayed_cable
	name = "frayed cable"
	desc = "A length of power cable worn down to bare copper. It won't carry a current like this."
	icon = 'icons/obj/power_cond/cable.dmi'
	icon_state = "0"
	layer = WIRE_LAYER
	anchored = TRUE
	/// Cable directions (CABLE_NORTH etc.) the cable ran in.
	var/cable_dirs = NONE

/obj/structure/ms13_frayed_cable/Initialize(mapload)
	. = ..()
	icon_state = "[cable_dirs]"
	AddElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_frayed_cable/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/ms13_frayed_cable/examine(mob/user)
	. = ..()
	. += span_notice("It could be spliced with a <b>cable coil</b>, or cut out with <b>wirecutters</b>.")

/// The live network on either side of the break, if any.
/obj/structure/ms13_frayed_cable/proc/live_powernet()
	for(var/cable_dir in GLOB.cable_dirs)
		if(!(cable_dirs & cable_dir))
			continue
		var/turf/next = get_step(src, GLOB.cable_dirs_to_real_dirs["[cable_dir]"])
		for(var/obj/structure/cable/wire in next)
			if(wire.powernet?.avail > 0)
				return wire.powernet

/obj/structure/ms13_frayed_cable/process(seconds_per_tick)
	if(prob(5 * seconds_per_tick) && live_powernet())
		do_sparks(1, FALSE, src)

/obj/structure/ms13_frayed_cable/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	var/datum/powernet/live = live_powernet()
	if(live && electrocute_mob(user, live, src, 1, TRUE))
		return TRUE
	to_chat(user, span_notice("The copper is bare, but nothing bites."))

/obj/structure/ms13_frayed_cable/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/cable_coil))
		return NONE
	var/obj/item/stack/cable_coil/coil = tool
	if(!coil.use(1))
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/cable/wire = new(loc)
	wire.color = color
	wire.set_directions(cable_dirs)
	user.visible_message(span_notice("[user] splices [src]."), span_notice("You splice [src]."))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/structure/ms13_frayed_cable/wirecutter_act(mob/living/user, obj/item/tool)
	var/obj/item/stack/cable_coil/scrap = new(drop_location(), 1)
	scrap.color = color
	tool.play_tool_sound(src)
	user.visible_message(span_notice("[user] cuts out [src]."), span_notice("You cut out [src]."))
	qdel(src)
	return TRUE

#undef HOUSE_POWER_MIN_SIZE
#undef HOUSE_POWER_MAX_SIZE
#undef HOUSE_POWER_MAX_LEAKS
#undef HOUSE_POWER_FAULT_SNIP
#undef HOUSE_POWER_FAULT_FRAY
