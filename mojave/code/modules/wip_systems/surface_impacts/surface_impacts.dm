GLOBAL_LIST_EMPTY(ms13_surface_impact_reserved_turfs)

/obj/effect/temp_visual/ms13/target_indicator/surface_impact
	name = "impact warning"
	desc = "The ground here is about to become extremely unsafe."
	duration = 8 SECONDS

/// What's coming down, seen falling out of the sky just before it hits.
/obj/effect/temp_visual/ms13/falling_impact
	name = "falling rock"
	icon = 'icons/obj/meteor.dmi'
	icon_state = "flaming"
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	duration = 1 SECONDS

/obj/effect/temp_visual/ms13/falling_impact/Initialize(mapload)
	. = ..()
	transform = matrix() * 3
	pixel_x = -320
	pixel_y = 640
	animate(src, pixel_x = 0, pixel_y = 0, transform = matrix() * 1.5, time = duration)

/**
 * Something comes down out of the sky into the wasteland: a meteorite, an alien seedpod, a wreck. It marks its landing
 * site, warns everyone on the surface with a streak across the sky, gives anyone at the site a few seconds to clear
 * out, throws clear and wounds whoever's left, then digs a crater with what came down standing in it.
 *
 * What came down is built from one of the theme's layouts, turned and mirrored at random. Layout symbols:
 * # wall, . floor, + door, X its centrepiece, M a mob, L loot, F a feature; a space is left as crater.
 *
 * Admins can drop one anywhere (the MS13 - Spawn Surface Impact verb); the Surface Impact random event drops them out in
 * the open near players on its own.
 */
/datum/ms13_surface_impact
	var/name = "surface impact"
	var/abstract = TRUE
	var/elite = FALSE
	var/radius = 4
	var/warning_time = 8 SECONDS
	var/human_damage_min = 20
	var/human_damage_max = 35
	/// Chance each tile of the crater's rim is rock.
	var/wall_chance = 75
	var/mob_count = 6
	var/feature_count = 7
	var/loot_count = 5
	/// The crater's floor, and the floor inside what came down (the crater's, if null).
	var/floor_type = /turf/open/floor/plating/ms13/ground/mountain
	var/interior_floor_type
	/// The crater's rim.
	var/list/wall_types = list(/turf/closed/mineral/random/ms13)
	/// What came down's walls (the rim's, if null), doors, and the heart of it.
	var/list/structure_wall_types
	var/door_type
	var/list/centerpiece_types = list()
	/// The colour its centrepiece glows, if it does.
	var/centerpiece_glow
	var/list/layouts = list()
	var/list/mob_types = list()
	var/list/feature_types = list()
	var/list/loot_types = list()
	/// Wreckage flung over the crater and out past its rim. It lands on open ground only, so keep it walkable.
	var/list/debris_types = list()
	var/center_x
	var/center_y
	var/center_z
	var/list/reserved_turfs

/datum/ms13_surface_impact/New()
	. = ..()
	if(elite)
		radius++
		mob_count += 5
		feature_count += 4
		loot_count += 3
		human_damage_min += 10
		human_damage_max += 15

/datum/ms13_surface_impact/Destroy()
	if(reserved_turfs)
		GLOB.ms13_surface_impact_reserved_turfs -= reserved_turfs
		reserved_turfs = null
	return ..()

/datum/ms13_surface_impact/proc/contains_offset(x_offset, y_offset)
	return x_offset * x_offset + y_offset * y_offset <= radius * radius

/datum/ms13_surface_impact/proc/get_footprint(turf/center)
	. = list()
	if(!center)
		return
	for(var/x_offset = -radius; x_offset <= radius; x_offset++)
		for(var/y_offset = -radius; y_offset <= radius; y_offset++)
			if(!contains_offset(x_offset, y_offset))
				continue
			var/turf/affected = locate(center.x + x_offset, center.y + y_offset, center.z)
			if(affected)
				. += affected

/// The open ground: the surface level and the regions around it, never a basement or an upper storey.
/datum/ms13_surface_impact/proc/is_impact_level(z_level)
	return z_level == ms13_surface_z() || !isnull(SSmapping.ms13_surface_links["[z_level]"])

/// The map's central ground level (its config's surface_level).
/proc/ms13_surface_z()
	var/list/levels = islist(SSmapping.config.map_file) ? SSmapping.config.map_file : list(SSmapping.config.map_file)
	return SSmapping.station_start + min(SSmapping.config.surface_level, length(levels)) - 1

/// outdoors_only: keep off anywhere roofed, towns and bases, as the random event does.
/datum/ms13_surface_impact/proc/get_validation_error(turf/target, check_reservations = TRUE, outdoors_only = FALSE)
	if(!target || !is_impact_level(target.z))
		return "The impact must be placed on the surface, not a basement or an upper floor."
	// Clear of the map's edge, and of the strips that cross into the regions beside it.
	var/list/bounds = SSmapping.ms13_surface_bounds || list(1, 1, world.maxx, world.maxy)
	var/margin = radius + 3 + (SSmapping.ms13_surface_bounds ? TRANSITIONEDGE : 0)
	if(target.x - margin < bounds[1] || target.x + margin > bounds[3] || target.y - margin < bounds[2] || target.y + margin > bounds[4])
		return "The impact is too close to the map edge to evacuate its occupants safely."

	var/list/footprint = get_footprint(target)
	for(var/turf/affected as anything in footprint)
		if(check_reservations && (affected in GLOB.ms13_surface_impact_reserved_turfs))
			return "Another surface impact already reserves part of this footprint."
		if(affected.resistance_flags & INDESTRUCTIBLE)
			return "The footprint contains protected terrain."
		if((locate(/obj/effect/landmark) in affected) || (locate(/obj/docking_port) in affected))
			return "The footprint contains mapping infrastructure and cannot be replaced."
		// Half a vehicle can't be left behind.
		if((locate(/obj/structure/ms13_vehicle_frame) in affected) || (locate(/obj/vehicle/sealed) in affected))
			return "A vehicle or mech is in the way."
		if(outdoors_only)
			var/area/place = affected.loc
			if(!place.outdoors)
				return "The footprint reaches under a roof."

	if(!length(get_evacuation_turfs(target)))
		return "No safe open tile exists near the impact for evacuating players."

/datum/ms13_surface_impact/proc/get_evacuation_turfs(turf/target)
	. = list()
	if(!target)
		return
	var/outer_radius = radius + 3
	for(var/x_offset = -outer_radius; x_offset <= outer_radius; x_offset++)
		for(var/y_offset = -outer_radius; y_offset <= outer_radius; y_offset++)
			var/distance_squared = x_offset * x_offset + y_offset * y_offset
			if(distance_squared <= radius * radius || distance_squared > outer_radius * outer_radius)
				continue
			var/turf/candidate = locate(target.x + x_offset, target.y + y_offset, target.z)
			if(!candidate || !isopenturf(candidate))
				continue
			if(is_safe_turf(candidate, extended_safety_checks = TRUE))
				. += candidate

/// Somewhere out in the open, a walk from someone so there's an audience, but not on top of anyone.
/datum/ms13_surface_impact/proc/find_landing_site()
	var/list/witnesses = list()
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		if(is_impact_level(player.z))
			witnesses += player
	for(var/attempt in 1 to 60)
		var/turf/candidate
		if(length(witnesses))
			var/mob/living/witness = pick(witnesses)
			var/angle = rand(0, 359)
			var/distance = rand(20, 45)
			candidate = locate(witness.x + round(distance * cos(angle)), witness.y + round(distance * sin(angle)), witness.z)
		else
			candidate = locate(rand(1, world.maxx), rand(1, world.maxy), ms13_surface_z())
		if(!candidate || get_validation_error(candidate, outdoors_only = TRUE))
			continue
		var/crowded = FALSE
		for(var/mob/living/player as anything in witnesses)
			if(player.z == candidate.z && get_dist(player, candidate) <= radius + 3)
				crowded = TRUE
				break
		if(!crowded)
			return candidate

/datum/ms13_surface_impact/proc/begin(turf/target)
	var/error = get_validation_error(target)
	if(error)
		return error

	center_x = target.x
	center_y = target.y
	center_z = target.z
	reserved_turfs = get_footprint(target)
	GLOB.ms13_surface_impact_reserved_turfs += reserved_turfs

	for(var/turf/affected as anything in reserved_turfs)
		new /obj/effect/temp_visual/ms13/target_indicator/surface_impact(affected)

	target.visible_message(span_boldwarning("The ground shudders as an impact zone lights up! Clear the marked area!"))
	playsound(target, 'mojave/sound/ms13effects/alarm.ogg', 70, TRUE)
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		if(player.z == target.z && get_dist(player, target) > radius + 7)
			to_chat(player, span_warning("Something streaks across the sky, falling away to the [dir2text(get_dir(player, target))]."))
	addtimer(CALLBACK(src, PROC_REF(fall)), max(warning_time - 1 SECONDS, 0))
	addtimer(CALLBACK(src, PROC_REF(resolve)), warning_time)
	return null

/datum/ms13_surface_impact/proc/fall()
	var/turf/center = locate(center_x, center_y, center_z)
	if(center)
		new /obj/effect/temp_visual/ms13/falling_impact(center)

/datum/ms13_surface_impact/proc/resolve()
	var/turf/center = locate(center_x, center_y, center_z)
	var/error = get_validation_error(center, FALSE)
	if(error)
		center?.visible_message(span_warning("The marked impact collapses harmlessly: [error]"))
		qdel(src)
		return

	var/list/footprint = get_footprint(center)
	if(!evacuate(center, footprint))
		qdel(src)
		return

	// The blast is heard across the map (distant_sound.dm).
	playsound(center, 'sound/effects/meteorimpact.ogg', 100, TRUE)
	playsound(center, SFX_EXPLOSION, 100, TRUE)
	new /obj/effect/temp_visual/explosion(center)
	do_sparks(8, FALSE, center)
	for(var/mob/witness in range(radius + 7, center))
		shake_camera(witness, 8, 3)

	for(var/turf/affected as anything in footprint)
		affected.empty(floor_type, flags = CHANGETURF_DEFAULT_BASETURF | CHANGETURF_INHERIT_AIR)

	var/list/open_turfs = dig_crater()
	var/list/spots = build_structure(open_turfs)
	spawn_at(feature_types, feature_count, spots["F"], open_turfs)
	spawn_at(mob_types, mob_count, spots["M"], open_turfs)
	spawn_at(loot_types, loot_count, spots["L"], open_turfs)
	scatter_debris(open_turfs)
	center = locate(center_x, center_y, center_z)
	center.visible_message(span_boldwarning("A [lowertext(name)] tears into the wasteland!"))
	qdel(src)

/// Throws clear whoever could stand it, people and anyone played; the rest are caught in it. FALSE if someone couldn't be.
/datum/ms13_surface_impact/proc/evacuate(turf/center, list/footprint)
	var/list/evacuation_turfs = get_evacuation_turfs(center)
	var/list/evacuees = list()
	var/list/caught = list()
	for(var/turf/affected as anything in footprint)
		for(var/mob/living/occupant in affected.get_all_contents())
			if(ishuman(occupant) || occupant.mind)
				evacuees |= occupant
			else
				caught |= occupant

	for(var/mob/living/evacuee as anything in evacuees)
		var/turf/destination = pick(evacuation_turfs)
		evacuee.forceMove(destination)
		if(get_turf(evacuee) != destination)
			center.visible_message(span_warning("The impact aborts when it cannot evacuate [evacuee]."))
			return FALSE

	for(var/mob/living/evacuee as anything in evacuees)
		evacuee.apply_damage(rand(human_damage_min, human_damage_max), BRUTE, BODY_ZONE_CHEST)
		evacuee.Knockdown(3 SECONDS)
		to_chat(evacuee, span_userdanger("The impact hurls you clear and slams you into the ground!"))

	for(var/mob/living/other as anything in caught)
		if(!QDELETED(other))
			other.gib(TRUE, TRUE, TRUE)
	return TRUE

/// Hollows the crater, ringed with rock at its rim. Returns its open ground.
/datum/ms13_surface_impact/proc/dig_crater()
	. = list()
	for(var/x_offset = -radius; x_offset <= radius; x_offset++)
		for(var/y_offset = -radius; y_offset <= radius; y_offset++)
			if(!contains_offset(x_offset, y_offset))
				continue
			var/turf/affected = locate(center_x + x_offset, center_y + y_offset, center_z)
			if(x_offset * x_offset + y_offset * y_offset >= (radius - 1) * (radius - 1) && prob(wall_chance))
				affected.ChangeTurf(pick(wall_types), flags = CHANGETURF_DEFAULT_BASETURF | CHANGETURF_INHERIT_AIR)
			else
				. += affected

/// A layout's cells as list(x offset, y offset, symbol), turned a quarter turn turns times and mirrored if asked.
/datum/ms13_surface_impact/proc/layout_cells(list/layout, turns = 0, mirror = FALSE)
	. = list()
	var/height = length(layout)
	for(var/row in 1 to height)
		var/line = layout[row]
		var/width = length(line)
		for(var/column in 1 to width)
			var/symbol = copytext(line, column, column + 1)
			if(symbol == " ")
				continue
			var/x_offset = column - 1 - round((width - 1) / 2)
			var/y_offset = round((height - 1) / 2) - (row - 1)
			if(mirror)
				x_offset = -x_offset
			for(var/turn in 1 to turns)
				var/old_x = x_offset
				x_offset = y_offset
				y_offset = -old_x
			. += list(list(x_offset, y_offset, symbol))

/datum/ms13_surface_impact/proc/layout_fits(list/layout)
	for(var/list/cell as anything in layout_cells(layout))
		if(!contains_offset(cell[1], cell[2]))
			return FALSE
	return TRUE

/**
 * Builds what came down at the crater's heart, from a layout that fits it. Returns where it wants its mobs, loot and
 * features: list("M" = turfs, "L" = turfs, "F" = turfs).
 */
/datum/ms13_surface_impact/proc/build_structure(list/open_turfs)
	. = list("M" = list(), "L" = list(), "F" = list())
	var/list/fitting = list()
	for(var/list/layout as anything in layouts)
		if(layout_fits(layout))
			fitting += list(layout)
	if(!length(fitting))
		return
	var/list/doors = list()
	for(var/list/cell as anything in layout_cells(pick(fitting), rand(0, 3), prob(50)))
		var/turf/spot = locate(center_x + cell[1], center_y + cell[2], center_z)
		if(!spot)
			continue
		var/symbol = cell[3]
		if(symbol == "#")
			spot.ChangeTurf(pick(structure_wall_types || wall_types), flags = CHANGETURF_DEFAULT_BASETURF | CHANGETURF_INHERIT_AIR)
			open_turfs -= spot
			continue
		// Its floor, even where the rim had rock.
		if(interior_floor_type || spot.density)
			spot.ChangeTurf(interior_floor_type || floor_type, flags = CHANGETURF_DEFAULT_BASETURF | CHANGETURF_INHERIT_AIR)
		open_turfs |= spot
		switch(symbol)
			if("X")
				open_turfs -= spot
				if(length(centerpiece_types))
					var/centerpiece_type = pick(centerpiece_types)
					var/atom/centerpiece = new centerpiece_type(spot)
					if(centerpiece_glow)
						centerpiece.set_light(4, 1, centerpiece_glow)
			if("+")
				open_turfs -= spot
				doors += spot
			if("M", "L", "F")
				.[symbol] += spot
	// Doors go in once the walls stand, to face along them.
	for(var/turf/spot as anything in doors)
		if(!door_type)
			continue
		var/obj/door = new door_type(spot)
		var/turf/north = get_step(spot, NORTH)
		door.setDir(north?.density ? EAST : SOUTH)

/// Fills the spots asked for first, then anywhere open in the crater.
/datum/ms13_surface_impact/proc/spawn_at(list/spawn_types, amount, list/spots, list/open_turfs)
	if(!length(spawn_types))
		return
	spots = spots.Copy()
	for(var/index in 1 to amount)
		var/turf/spot
		while(length(spots) && !(spot in open_turfs))
			spot = pick_n_take(spots)
		if(!(spot in open_turfs))
			if(!length(open_turfs))
				return
			spot = pick(open_turfs)
		open_turfs -= spot
		var/spawn_type = pick(spawn_types)
		new spawn_type(spot)

/// Wreckage over the crater and flung out past its rim, only onto open ground with nothing standing on it.
/datum/ms13_surface_impact/proc/scatter_debris(list/open_turfs)
	if(!length(debris_types))
		return
	var/list/landing = open_turfs.Copy()
	var/outer_radius = radius + 3
	for(var/x_offset = -outer_radius; x_offset <= outer_radius; x_offset++)
		for(var/y_offset = -outer_radius; y_offset <= outer_radius; y_offset++)
			var/distance_squared = x_offset * x_offset + y_offset * y_offset
			if(distance_squared <= radius * radius || distance_squared > outer_radius * outer_radius)
				continue
			var/turf/spot = locate(center_x + x_offset, center_y + y_offset, center_z)
			if(isopenturf(spot) && !spot.is_blocked_turf(TRUE))
				landing += spot
	for(var/index in 1 to radius * 3)
		if(!length(landing))
			return
		var/debris_type = pick(debris_types)
		new debris_type(pick_n_take(landing))

// An alien seedpod: resin chambers around a glowing crystal, alien growths, and what hatched.
/datum/ms13_surface_impact/cdda
	name = "alien seedpod"
	abstract = FALSE
	interior_floor_type = /turf/open/floor/ms13/cdda/t_floor_resin
	structure_wall_types = list(/turf/closed/wall/ms13/concrete/cdda/t_wall_resin)
	centerpiece_types = list(/obj/structure/ms13/cdda/f_huge_mana_crystal)
	centerpiece_glow = "#ffe28a"
	layouts = list(
		list(
			" #.# ",
			"#M.F#",
			"..X..",
			"#L.M#",
			" #.# ",
		),
		list(
			"  #.#  ",
			" #F.M# ",
			"#M...L#",
			"...X...",
			"#L...F#",
			" #M.F# ",
			"  #.#  ",
		),
		list(
			"   ###   ",
			"  #F.M#  ",
			" #M...F# ",
			"#L..#..L#",
			"....X....",
			"#F..#..M#",
			" #M...F# ",
			"  #L.M#  ",
			"   #.#   ",
		),
	)
	mob_types = list(
		/mob/living/simple_animal/hostile/netherworld/migo/ms13_impact,
		/mob/living/simple_animal/hostile/zombie/ms13_impact,
		/mob/living/simple_animal/hostile/zombie/ms13_impact,
		/mob/living/basic/ms13/ghoul,
	)
	feature_types = list(
		/obj/structure/ms13/cdda/f_alien_pod,
		/obj/structure/ms13/cdda/f_alien_tendril,
		/obj/structure/ms13/cdda/f_alien_anemone,
		/obj/structure/ms13/cdda/f_alien_gasper,
		/obj/structure/ms13/cdda/f_alien_zapper,
		/obj/structure/ms13/cdda/t_resin_hole,
		/obj/structure/ms13/cdda/f_egg_sacke,
	)
	loot_types = list(
		/obj/item/ms13/component/cell,
		/obj/item/ms13/component/fusion,
		/obj/item/ms13/component/vacuum_tube,
		/obj/item/ms13/component/plasma_battery,
		/obj/item/stock_parts/cell/ms13/ec,
		/obj/item/gun/energy/ms13/laser/pistol/wattz,
	)
	debris_types = list(
		/obj/structure/ms13/cdda/f_ash,
		/obj/structure/ms13/cdda/f_rubble_rock,
		/obj/structure/flora/ms13/cdda/t_grass_alien,
		/obj/structure/ms13/cdda/f_fungal_clump,
	)

/datum/ms13_surface_impact/cdda/elite
	name = "alien seedpod (elite)"
	elite = TRUE
	mob_types = list(
		/mob/living/simple_animal/hostile/netherworld/migo/ms13_impact,
		/mob/living/simple_animal/hostile/netherworld/migo/ms13_impact,
		/mob/living/simple_animal/hostile/zombie/ms13_impact,
		/mob/living/basic/ms13/ghoul/radioactive,
	)
	loot_types = list(
		/obj/item/ms13/component/fusion,
		/obj/item/ms13/component/plasma_battery,
		/obj/item/stock_parts/cell/ms13/mfc,
		/obj/item/gun/energy/ms13/laser/rifle/wattz,
		/obj/item/gun/energy/ms13/plasma/pistol,
	)

// A meteorite: a geode of rock split open round its glowing core, veined with ore.
/datum/ms13_surface_impact/natural
	name = "meteorite"
	abstract = FALSE
	mob_count = 5
	feature_count = 10
	loot_count = 3
	centerpiece_types = list(/obj/structure/ms13/cdda/f_glow_boulder)
	centerpiece_glow = "#8dff9a"
	layouts = list(
		list(
			" #.# ",
			"#F.F#",
			"..X..",
			"#F.M#",
			" #.# ",
		),
		list(
			"  #.#  ",
			" #F.F# ",
			"#M...M#",
			"...X...",
			"#F...F#",
			" #L.F# ",
			"  #.#  ",
		),
		list(
			"   #.#   ",
			"  #F.F#  ",
			" #M...M# ",
			"#F.#.#.F#",
			"....X....",
			"#F.#.#.F#",
			" #M...L# ",
			"  #F.F#  ",
			"   #.#   ",
		),
	)
	mob_types = list(
		/mob/living/basic/ms13/hostile_animal/radroach,
		/mob/living/basic/ms13/hostile_animal/molerat/young,
	)
	feature_types = list(
		/obj/structure/ms13/ore_deposit/copper,
		/obj/structure/ms13/ore_deposit/lead,
		/obj/structure/ms13/ore_deposit/alu,
		/obj/structure/ms13/ore_deposit/iron,
		/obj/structure/ms13/ore_deposit/coal,
		/obj/structure/ms13/cdda/f_boulder_medium,
	)
	loot_types = list(/obj/item/stack/sheet/ms13/scrap)
	debris_types = list(
		/obj/structure/ms13/cdda/f_rubble_rock,
		/obj/structure/ms13/cdda/f_rubble,
		/obj/structure/ms13/cdda/f_ash,
	)

/datum/ms13_surface_impact/natural/elite
	name = "meteorite (elite)"
	elite = TRUE
	mob_types = list(
		/mob/living/basic/ms13/hostile_animal/gecko/golden,
		/mob/living/basic/ms13/hostile_animal/yaoguai,
		/mob/living/basic/ms13/hostile_animal/molerat,
	)
	feature_types = list(
		/obj/structure/ms13/ore_deposit/gold,
		/obj/structure/ms13/ore_deposit/silver,
		/obj/structure/ms13/ore_deposit/uranium,
		/obj/structure/ms13/ore_deposit/iron,
		/obj/structure/ms13/cdda/f_boulder_large,
	)

// An Exodii wreck: a machine hull of scrap and bulkheads round its portal tower, still guarded.
/datum/ms13_surface_impact/robot
	name = "Exodii wreck"
	abstract = FALSE
	interior_floor_type = /turf/open/floor/ms13/cdda/t_scrap_floor
	structure_wall_types = list(/turf/closed/wall/ms13/metal/cdda/t_scrap_wall)
	wall_types = list(
		/turf/closed/wall/ms13/metal/rust,
		/turf/closed/wall/ms13/metal/reinforced/rust,
	)
	door_type = /obj/machinery/door/unpowered/ms13/metal
	centerpiece_types = list(/obj/structure/ms13/cdda/f_exodii_portal_tower)
	centerpiece_glow = "#8fd6ff"
	layouts = list(
		list(
			"#####",
			"#F.L#",
			"#MX.#",
			"#..M#",
			"##+##",
		),
		list(
			" ##### ",
			"#F.X.F#",
			"#M...L#",
			"##+#+##",
			"#L.#.M#",
			"#F.#.F#",
			" #.#.# ",
		),
		list(
			"  #####  ",
			" #F.X.F# ",
			"#M.....L#",
			"#F..M..F#",
			"##+###+##",
			"#L.#.#.M#",
			"#F.+.+.F#",
			" ##.#.## ",
			"  #...#  ",
		),
	)
	mob_types = list(
		/mob/living/basic/ms13/robot/handy,
		/mob/living/basic/ms13/robot/handy/saw,
		/mob/living/basic/ms13/robot/handy/gun,
	)
	feature_types = list(
		/obj/structure/ms13/cdda/f_exodii_charger,
		/obj/structure/ms13/cdda/f_exodii_scanner,
		/obj/structure/ms13/cdda/f_exodii_pump,
		/obj/structure/ms13/cdda/f_exodii_printer_large,
		/obj/structure/ms13/cdda/f_exodii_generator_1,
		/obj/structure/ms13/cdda/f_console_broken,
		/obj/structure/ms13/cdda/f_exodii_lamp,
	)
	loot_types = list(
		/obj/item/stack/sheet/ms13/scrap_steel/two,
		/obj/item/stack/sheet/ms13/scrap_parts/two,
		/obj/item/stack/sheet/ms13/scrap_electronics/two,
		/obj/item/stack/sheet/ms13/circuits/two,
		/obj/item/ms13/component/vacuum_tube,
		/obj/item/ms13/component/plasma_battery,
	)
	debris_types = list(
		/obj/effect/decal/cleanable/robot_debris,
		/obj/structure/ms13/cdda/f_rubble,
		/obj/structure/ms13/cdda/f_ash,
	)

/datum/ms13_surface_impact/robot/elite
	name = "Exodii wreck (elite)"
	elite = TRUE
	mob_types = list(
		/mob/living/simple_animal/hostile/ms13/robot/assaultron,
		/mob/living/simple_animal/hostile/ms13/robot/sentrybot,
		/mob/living/basic/ms13/robot/handy/gun,
	)
	loot_types = list(
		/obj/item/stack/sheet/ms13/scrap_steel/ten,
		/obj/item/stack/sheet/ms13/scrap_electronics/ten,
		/obj/item/stack/sheet/ms13/circuits/eight,
		/obj/item/ms13/component/fusion,
		/obj/item/ms13/component/plasma_battery,
	)

// A chunk of the original DD station, torn off whole, deliberately foreign to the Mojave.
/datum/ms13_surface_impact/ss13
	name = "station wreckage"
	abstract = FALSE
	floor_type = /turf/open/floor/plating
	wall_types = list(/turf/closed/wall)
	interior_floor_type = /turf/open/floor/iron
	door_type = /obj/machinery/door/airlock/public/glass
	centerpiece_types = list(/obj/structure/closet/crate/secure/loot)
	layouts = list(
		list(
			"#####",
			"#LXF#",
			"#M..#",
			"#..M#",
			"##+##",
		),
		list(
			" ##### ",
			"#L.#.F#",
			"#M.+.X#",
			"#.##+##",
			"#.+..M#",
			"#F#.L.#",
			" ##+## ",
		),
		list(
			"  #####  ",
			" #L...F# ",
			"#M.....X#",
			"#F..M..L#",
			"##+###+##",
			"#L.#.#.F#",
			"#M.+.+.M#",
			" ###.### ",
			"   #.#   ",
		),
	)
	mob_types = list(
		/mob/living/simple_animal/hostile/hivebot,
		/mob/living/simple_animal/hostile/hivebot/range,
		/mob/living/simple_animal/hostile/syndicate/melee,
	)
	feature_types = list(
		/obj/structure/girder,
		/obj/structure/closet/crate,
	)
	loot_types = list(
		/obj/item/gun/ballistic/automatic/pistol/m1911,
		/obj/item/gun/ballistic/shotgun/riot,
		/obj/item/clothing/suit/armor/vest,
		/obj/item/clothing/head/helmet/sec,
		/obj/item/gun/energy/laser,
	)
	debris_types = list(
		/obj/effect/decal/cleanable/robot_debris,
		/obj/structure/ms13/cdda/f_rubble,
	)

/datum/ms13_surface_impact/ss13/elite
	name = "station wreckage (elite)"
	elite = TRUE
	mob_types = list(
		/mob/living/simple_animal/hostile/hivebot/strong,
		/mob/living/simple_animal/hostile/syndicate/ranged,
		/mob/living/simple_animal/hostile/syndicate/melee/sword,
	)
	loot_types = list(
		/obj/item/gun/ballistic/automatic/c20r,
		/obj/item/gun/energy/e_gun,
		/obj/item/clothing/suit/armor/riot,
		/obj/item/clothing/head/helmet/riot,
	)

// A raider fort: the scrap stockade and the raiders who rode it down.
/datum/ms13_surface_impact/raider
	name = "raider fort"
	abstract = FALSE
	floor_type = /turf/open/floor/plating/ms13/ground/desert
	wall_types = list(/turf/closed/wall/ms13/craftable/scrap)
	door_type = /obj/machinery/door/unpowered/ms13/wood
	centerpiece_types = list(/obj/structure/ms13/cdda/f_scrap_antenna, /obj/structure/bonfire/ms13/fire_barrel)
	layouts = list(
		list(
			"#.###",
			"#M.L#",
			"+.X.#",
			"#F.M#",
			"###.#",
		),
		list(
			"  ###  ",
			" #M.L# ",
			"#F...F#",
			"+..X..+",
			"#L...M#",
			" #F.M# ",
			"  ###  ",
		),
		list(
			"  #####  ",
			" #L.M.L# ",
			"#F.....F#",
			"#M.#+#.M#",
			"+..#X#..+",
			"#M.#.#.M#",
			"#F.....F#",
			" #L.M.L# ",
			"  #####  ",
		),
	)
	mob_types = list(
		/mob/living/basic/ms13/raider,
		/mob/living/basic/ms13/raider/metal,
		/mob/living/basic/ms13/raider/tribal,
		/mob/living/basic/ms13/raider/baseball,
	)
	feature_types = list(
		/obj/structure/closet/crate/ms13/woodcrate,
		/obj/structure/ms13/cdda/f_metal_crate_c,
		/obj/structure/ms13/barricade,
	)
	loot_types = list(
		/obj/item/stack/sheet/ms13/scrap/two,
		/obj/item/stack/sheet/ms13/scrap_steel/two,
		/obj/item/gun/ballistic/automatic/pistol/ms13/m9mm,
		/obj/item/clothing/suit/ms13/raider,
	)
	debris_types = list(
		/obj/structure/ms13/cdda/f_rubble,
		/obj/structure/ms13/cdda/f_ash,
	)

/datum/ms13_surface_impact/raider/elite
	name = "raider fort (elite)"
	elite = TRUE
	mob_types = list(
		/mob/living/basic/ms13/raider/badlands,
		/mob/living/basic/ms13/raider/sulphite,
		/mob/living/basic/ms13/raider/boss,
	)
	loot_types = list(
		/obj/item/stack/sheet/ms13/scrap_steel/five,
		/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle,
		/obj/item/clothing/suit/armor/ms13/combat,
	)

/// Now and then, something comes down out of the sky near someone on the surface.
/datum/round_event_control/ms13_surface_impact
	name = "Surface Impact"
	typepath = /datum/round_event/ms13_surface_impact
	weight = 8
	earliest_start = 20 MINUTES
	min_players = 1
	max_occurrences = 4

/datum/round_event/ms13_surface_impact/start()
	// Elites come down a quarter of the time.
	var/list/choices = list()
	for(var/datum/ms13_surface_impact/impact_type as anything in subtypesof(/datum/ms13_surface_impact))
		if(!initial(impact_type.abstract))
			choices[impact_type] = initial(impact_type.elite) ? 1 : 3
	var/impact_type = pick_weight(choices)
	var/datum/ms13_surface_impact/impact = new impact_type
	var/turf/target = impact.find_landing_site()
	if(!target || impact.begin(target))
		qdel(impact)
		return
	announce_to_ghosts(target)
	log_game("A [impact.name] came down at [AREACOORD(target)].")

/client/proc/ms13_spawn_surface_impact()
	set category = "Debug"
	set name = "MS13 - Spawn Surface Impact"

	if(!check_rights(R_DEBUG))
		return
	var/list/themes = list(
		"Alien seedpod" = list(/datum/ms13_surface_impact/cdda, /datum/ms13_surface_impact/cdda/elite),
		"Meteorite" = list(/datum/ms13_surface_impact/natural, /datum/ms13_surface_impact/natural/elite),
		"Raider fort" = list(/datum/ms13_surface_impact/raider, /datum/ms13_surface_impact/raider/elite),
		"Exodii wreck" = list(/datum/ms13_surface_impact/robot, /datum/ms13_surface_impact/robot/elite),
		"Station wreckage" = list(/datum/ms13_surface_impact/ss13, /datum/ms13_surface_impact/ss13/elite),
	)
	var/theme = tgui_input_list(src, "Choose an impact theme.", "Surface Impact", list("Random") + themes)
	if(!theme)
		return
	if(theme == "Random")
		theme = pick(themes)

	var/difficulty = tgui_input_list(src, "Choose the encounter strength.", "Surface Impact", list("Standard", "Elite", "Random"), "Standard")
	if(!difficulty)
		return
	if(difficulty == "Random")
		difficulty = pick("Standard", "Elite")

	var/list/sizes = list("Small (-1 radius)" = -1, "Standard" = 0, "Large (+2 radius)" = 2)
	var/size = tgui_input_list(src, "Choose the impact size.", "Surface Impact", sizes, "Standard")
	if(!size)
		return

	var/list/warning_times = list("8 seconds" = 8 SECONDS, "15 seconds" = 15 SECONDS, "30 seconds" = 30 SECONDS)
	var/warning = tgui_input_list(src, "Choose how much warning players receive.", "Surface Impact", warning_times, "8 seconds")
	if(!warning)
		return

	var/list/locations = list("My current tile", "Somewhere near players, out in the open")
	if(holder?.marked_datum)
		locations += "Marked datum"
	var/location = tgui_input_list(src, "Choose the impact center. Mark a turf or object through View Variables to use it here.", "Surface Impact", locations, locations[1])
	if(!location)
		return

	var/list/impact_types = themes[theme]
	var/impact_type = impact_types[difficulty == "Elite" ? 2 : 1]
	var/datum/ms13_surface_impact/chosen = new impact_type
	chosen.radius += sizes[size]
	chosen.warning_time = warning_times[warning]

	var/turf/target
	switch(location)
		if("Marked datum")
			target = get_turf(holder.marked_datum)
		if("Somewhere near players, out in the open")
			target = chosen.find_landing_site()
		else
			target = get_turf(mob)
	if(!target)
		to_chat(src, span_warning("No valid place to bring it down."), confidential = TRUE)
		qdel(chosen)
		return

	var/error = chosen.get_validation_error(target)
	if(error)
		to_chat(src, span_warning(error), confidential = TRUE)
		qdel(chosen)
		return
	if(tgui_alert(src, "Spawn [chosen.name] at [AREACOORD(target)]? This permanently replaces a radius-[chosen.radius] patch after [chosen.warning_time / 10] seconds.", "Confirm Surface Impact", list("Cancel", "Impact")) != "Impact")
		qdel(chosen)
		return

	error = chosen.begin(target)
	if(error)
		to_chat(src, span_warning(error), confidential = TRUE)
		qdel(chosen)
		return
	message_admins(span_adminnotice("[key_name_admin(src)] triggered [chosen.name] at [ADMIN_COORDJMP(target)]."))
	log_admin("[key_name(src)] triggered [chosen.name] at [AREACOORD(target)].")
