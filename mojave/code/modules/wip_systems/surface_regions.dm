/// Fixed, optional surface neighbours inspired by tgstation/tgstation#91920.
/// Keep planetary travel separate from randomized space linkage and vertical caves/roofs.
/// A neighbour is one surface map, or a list of maps stacked like map_file (its caves and roofs too), level beside level.
/datum/map_config
	var/surface_level = 2
	var/list/surface_neighbors = list()

/datum/map_config/LoadConfig(filename, log_missing)
	. = ..()
	if(!.)
		return
	var/list/settings = json_decode(file2text(filename))
	if(!("surface_neighbors" in settings))
		return
	var/list/neighbors = settings["surface_neighbors"]
	if(!islist(neighbors))
		log_mapping("surface_neighbors must be a direction-to-filename object.")
		return FALSE
	var/central = ("surface_level" in settings) ? settings["surface_level"] : 2
	if(!isnum(central) || central != round(central) || central < 1 || central > length(map_file) || !islist(map_file))
		log_mapping("surface_level must index the central single-z map in map_file.")
		return FALSE
	for(var/direction in neighbors)
		var/list/stack = neighbors[direction]
		if(islist(stack) && length(stack) != length(map_file))
			log_mapping("Surface neighbor [direction] must stack one map for each level in map_file.")
			return FALSE
		for(var/mapfile in (islist(stack) ? stack : list(stack)))
			if(!(direction in list("north", "east", "south", "west")) || !istext(mapfile) || findtext(mapfile, "..") || findtext(mapfile, "/") || findtext(mapfile, "\\") || !fexists("_maps/[map_path]/[mapfile]"))
				log_mapping("Invalid surface neighbor: [direction] = [mapfile]. Use an existing map filename in map_path.")
				return FALSE
	surface_level = central
	surface_neighbors = neighbors.Copy()

/datum/map_config/GetFullMapPaths()
	. = ..()
	for(var/direction in surface_neighbors)
		var/list/stack = surface_neighbors[direction]
		for(var/mapfile in (islist(stack) ? stack : list(stack)))
			. += "_maps/[map_path]/[mapfile]"

/datum/controller/subsystem/mapping
	/// z text -> (cardinal direction text -> destination z). No implicit wrapping.
	var/list/ms13_surface_links = list()
	/// Actual loaded map rectangle, not world bounds (Mammoth is narrower than world.maxx).
	var/list/ms13_surface_bounds
	/// The surface z of each region, the centre's included; not their caves or roofs.
	var/list/ms13_surface_levels = list()

/datum/controller/subsystem/mapping/loadWorld()
	. = ..()
	if(!length(config.surface_neighbors))
		return
	// Validate every file before loading any neighbours; do not resize or offset an existing map.
	var/datum/parsed_map/central_map = new(file("_maps/[config.map_path]/[config.map_file[config.surface_level]]"))
	var/list/bounds = central_map.bounds
	if(!bounds || bounds[MAP_MINX] != 1 || bounds[MAP_MINY] != 1 || bounds[MAP_MINZ] != 1 || bounds[MAP_MAXZ] != 1)
		CRASH("Surface regions require single-z maps starting at (1,1,1).")
	var/width = bounds[MAP_MAXX]
	var/height = bounds[MAP_MAXY]
	if(width <= 2 * (TRANSITIONEDGE + 2) || height <= 2 * (TRANSITIONEDGE + 2))
		CRASH("Surface region is too small for transition borders.")
	var/list/primary_files = config.map_file
	var/list/files = primary_files.Copy()
	for(var/direction in config.surface_neighbors)
		files += config.surface_neighbors[direction]
	for(var/mapfile in files)
		var/datum/parsed_map/region = new(file("_maps/[config.map_path]/[mapfile]"))
		var/list/region_bounds = region.bounds
		if(!region_bounds || region_bounds[MAP_MINX] != 1 || region_bounds[MAP_MINY] != 1 || region_bounds[MAP_MINZ] != 1 || region_bounds[MAP_MAXZ] != 1 || region_bounds[MAP_MAXX] != width || region_bounds[MAP_MAXY] != height)
			CRASH("Surface region [mapfile] must match the central map's [width]x[height] single-z dimensions.")
		qdel(region)
	qdel(central_map)
	var/min_x = max(1, round(world.maxx / 2 - width / 2) + 1)
	var/min_y = max(1, round(world.maxy / 2 - height / 2) + 1)
	ms13_surface_bounds = list(min_x, min_y, min_x + width - 1, min_y + height - 1)
	var/central_z = station_start + config.surface_level - 1
	var/datum/space_level/center = get_level(central_z)
	ms13_surface_links["[central_z]"] = list()
	ms13_surface_levels = list(central_z)
	var/list/directions = list("north" = NORTH, "east" = EAST, "south" = SOUTH, "west" = WEST)
	for(var/direction in config.surface_neighbors)
		var/list/stack = config.surface_neighbors[direction]
		// A lone surface map has nothing above or below it. A stack keeps its levels' own traits, links up and down included.
		var/list/level_traits = list()
		for(var/list/traits as anything in (islist(stack) ? config.traits : list(center.traits)))
			var/list/region_traits = traits.Copy()
			region_traits -= (islist(stack) ? list(ZTRAIT_LINKAGE) : list(ZTRAIT_UP, ZTRAIT_DOWN, ZTRAIT_LINKAGE))
			level_traits += list(region_traits)
		var/first_z = world.maxz + 1
		var/list/failed = list()
		LoadGroup(failed, "[config.map_name] [direction]", config.map_path, stack, level_traits, level_traits[1])
		if(length(failed))
			CRASH("Unable to load surface region: [english_list(failed)]")
		var/surface_offset = islist(stack) ? config.surface_level - 1 : 0
		ms13_surface_levels += first_z + surface_offset
		// Each level crosses to the one beside it: surface to surface, cave to cave, roof to roof.
		for(var/level in 1 to length(level_traits))
			var/center_z = central_z - surface_offset + level - 1
			var/datum/space_level/beside = get_level(center_z)
			beside.set_linkage(null)
			beside.neigbours.Cut()
			ms13_link_surface_region(center_z, first_z + level - 1, directions[direction])

/datum/controller/subsystem/mapping/proc/ms13_link_surface_region(center_z, neighbor_z, direction)
	LAZYINITLIST(ms13_surface_links["[center_z]"])
	LAZYINITLIST(ms13_surface_links["[neighbor_z]"])
	ms13_surface_links["[center_z]"]["[direction]"] = neighbor_z
	ms13_surface_links["[neighbor_z]"]["[turn(direction, 180)]"] = center_z

/// Return the mapped edge being crossed. Corner strips use N/S consistently, never diagonal links.
/datum/controller/subsystem/mapping/proc/ms13_surface_edge(turf/source)
	if(!ms13_surface_links["[source.z]"] || !ms13_surface_bounds)
		return NONE
	if(source.y >= ms13_surface_bounds[4] - TRANSITIONEDGE)
		return NORTH
	if(source.y <= ms13_surface_bounds[2] + TRANSITIONEDGE)
		return SOUTH
	if(source.x >= ms13_surface_bounds[3] - TRANSITIONEDGE)
		return EAST
	if(source.x <= ms13_surface_bounds[1] + TRANSITIONEDGE)
		return WEST
	return NONE

/datum/controller/subsystem/mapping/proc/ms13_surface_destination(turf/source, direction)
	var/destination_z = ms13_surface_links["[source.z]"]?["[direction]"]
	if(!destination_z)
		return null
	var/target_x = clamp(source.x, ms13_surface_bounds[1] + TRANSITIONEDGE + 1, ms13_surface_bounds[3] - TRANSITIONEDGE - 1)
	var/target_y = clamp(source.y, ms13_surface_bounds[2] + TRANSITIONEDGE + 1, ms13_surface_bounds[4] - TRANSITIONEDGE - 1)
	switch(direction)
		if(NORTH)
			target_y = ms13_surface_bounds[2] + TRANSITIONEDGE + 1
		if(SOUTH)
			target_y = ms13_surface_bounds[4] - TRANSITIONEDGE - 1
		if(EAST)
			target_x = ms13_surface_bounds[1] + TRANSITIONEDGE + 1
		if(WEST)
			target_x = ms13_surface_bounds[3] - TRANSITIONEDGE - 1
	return locate(target_x, target_y, destination_z)

/turf/open/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(!length(SSmapping.ms13_surface_links))
		return
	if(!isturf(old_loc) || !arrived || arrived.loc != src || arrived.anchored || arrived.currently_z_moving || LAZYLEN(arrived.grabbed_by) || istype(arrived, /atom/movable/mirage_holder))
		return
	var/direction = SSmapping.ms13_surface_edge(src)
	if(!direction)
		return
	// Whole-hull crossings are handled by the vehicle controller, not individual occupants.
	if(locate(/obj/structure/ms13_vehicle_frame) in src)
		return
	if(isliving(arrived))
		var/mob/living/rider = arrived
		if(rider.buckled)
			return
	var/turf/destination = SSmapping.ms13_surface_destination(src, direction)
	// Do not teleport through walls, doors or into space. Mappers must keep arrival lanes open.
	if(!isopenturf(destination) || isspaceturf(destination) || isopenspaceturf(destination) || destination.is_blocked_turf(TRUE) || istype(destination.loc, /area/shuttle))
		return
	if(SEND_SIGNAL(arrived, COMSIG_MOVABLE_LATERAL_Z_MOVE) & COMPONENT_BLOCK_MOVEMENT)
		return
	arrived.forceMoveWithGroup(destination, ZMOVING_LATERAL)
	if(isliving(arrived))
		var/mob/living/traveler = arrived
		for(var/obj/item/hand_item/grab/grab as anything in traveler.recursively_get_conga_line())
			grab.affecting.forceMoveWithGroup(destination, ZMOVING_LATERAL)

/datum/controller/subsystem/mapping/setup_map_transitions()
	. = ..()
	for(var/z_text in ms13_surface_links)
		var/list/links = ms13_surface_links[z_text]
		for(var/direction_text in links)
			var/direction = text2num(direction_text)
			var/min_x = ms13_surface_bounds[1] + TRANSITIONEDGE
			var/min_y = ms13_surface_bounds[2] + TRANSITIONEDGE
			var/max_x = ms13_surface_bounds[3] - TRANSITIONEDGE
			var/max_y = ms13_surface_bounds[4] - TRANSITIONEDGE
			switch(direction)
				if(NORTH)
					min_y = max_y
				if(SOUTH)
					max_y = min_y
				if(EAST)
					min_x = max_x
				if(WEST)
					max_x = min_x
			for(var/turf/open/border in block(locate(min_x, min_y, text2num(z_text)), locate(max_x, max_y, text2num(z_text))))
				border.AddElement(/datum/element/mirage_border, ms13_surface_destination(border, direction), direction, TRANSITIONEDGE)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_surface_regions
	name = "MAPPING: Fixed surface neighbors and ground crossings"

/datum/unit_test/ms13_surface_regions/Run()
	if(length(SSmapping.config.surface_neighbors))
		var/central_z = SSmapping.station_start + SSmapping.config.surface_level - 1
		var/list/loaded_neighbors = SSmapping.ms13_surface_links["[central_z]"]
		if(length(loaded_neighbors) != length(SSmapping.config.surface_neighbors))
			Fail("Configured neighboring maps were not loaded and linked.")
		for(var/direction in loaded_neighbors)
			var/neighbor_z = loaded_neighbors[direction]
			if(!(neighbor_z in SSmapping.ms13_surface_levels))
				Fail("A neighboring region's surface wasn't counted as one.")
			// A lone map has no levels above or below. A stack's line up with the centre's, and cross to them too.
			for(var/trait in list(ZTRAIT_UP, ZTRAIT_DOWN))
				var/offset = SSmapping.level_trait(neighbor_z, trait)
				if(offset && (!SSmapping.level_trait(central_z, trait) || SSmapping.ms13_surface_links["[neighbor_z + offset]"]?["[turn(text2num(direction), 180)]"] != central_z + offset))
					Fail("A neighboring region's level [trait] doesn't line up with the centre's.")
	var/list/saved_links = SSmapping.ms13_surface_links
	var/list/saved_bounds = SSmapping.ms13_surface_bounds
	SSmapping.ms13_surface_links = list()
	SSmapping.ms13_surface_bounds = list(10, 10, 50, 50)
	var/center_z = run_loc_floor_bottom_left.z
	var/datum/space_level/region = SSmapping.add_new_zlevel("Surface region regression", list())
	SSmapping.ms13_link_surface_region(center_z, region.z_value, NORTH)
	var/turf/north_edge = locate(30, 50 - TRANSITIONEDGE, center_z)
	var/turf/destination = SSmapping.ms13_surface_destination(north_edge, NORTH)
	if(!destination || destination.z != region.z_value || destination.x != 30 || destination.y != 11 + TRANSITIONEDGE)
		Fail("North crossing did not preserve the map-relative coordinate.")
	if(SSmapping.ms13_surface_destination(north_edge, WEST))
		Fail("An unmapped direction wrapped around.")
	if(SSmapping.ms13_surface_edge(destination))
		Fail("Arrival is still inside a transition strip and would bounce back.")
	for(var/direction in GLOB.cardinals)
		SSmapping.ms13_link_surface_region(center_z, region.z_value, direction)
		var/turf/entry
		switch(direction)
			if(NORTH)
				entry = locate(30, 50 - TRANSITIONEDGE, center_z)
			if(SOUTH)
				entry = locate(30, 10 + TRANSITIONEDGE, center_z)
			if(EAST)
				entry = locate(50 - TRANSITIONEDGE, 30, center_z)
			if(WEST)
				entry = locate(10 + TRANSITIONEDGE, 30, center_z)
		entry = entry.ChangeTurf(/turf/open/floor/plating)
		destination = SSmapping.ms13_surface_destination(entry, direction)
		destination = destination.ChangeTurf(/turf/open/floor/plating)
		var/obj/item/traveler = allocate(/obj/item, run_loc_floor_bottom_left)
		traveler.forceMove(entry)
		if(get_turf(traveler) != destination)
			Fail("Actual ground crossing failed for direction [direction].")
		var/turf/return_edge = get_step(destination, turn(direction, 180))
		return_edge = return_edge.ChangeTurf(/turf/open/floor/plating)
		var/turf/return_destination = SSmapping.ms13_surface_destination(return_edge, turn(direction, 180))
		return_destination = return_destination.ChangeTurf(/turf/open/floor/plating)
		traveler.forceMove(return_edge)
		if(get_turf(traveler) != return_destination || traveler.z != center_z)
			Fail("Return crossing failed for direction [direction].")
		var/obj/structure/blocker = allocate(/obj/structure, destination)
		blocker.density = TRUE
		traveler.forceMove(entry)
		if(get_turf(traveler) != entry)
			Fail("Crossing teleported through an obstructed arrival.")
		qdel(blocker)
		// Mirage holders must stay on the source side rather than recursively transitioning.
		entry.AddElement(/datum/element/mirage_border, destination, direction, TRANSITIONEDGE)
		if(!(locate(/atom/movable/mirage_holder) in entry))
			Fail("Ground mirage holder left its border turf.")
		entry.RemoveElement(/datum/element/mirage_border)
	check_surface_vehicles(center_z, region.z_value)
	SSmapping.ms13_surface_links = saved_links
	SSmapping.ms13_surface_bounds = saved_bounds
#endif
