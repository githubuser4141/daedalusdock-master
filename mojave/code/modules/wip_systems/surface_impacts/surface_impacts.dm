GLOBAL_LIST_EMPTY(ms13_surface_impact_reserved_turfs)

/obj/effect/temp_visual/ms13/target_indicator/surface_impact
	name = "impact warning"
	desc = "The ground here is about to become extremely unsafe."
	duration = 8 SECONDS

/**
 * First-map-level prototype for destructive, procedurally populated encounters.
 *
 * An admin chooses a theme at their current tile. The system reserves and marks a circular patch,
 * gives nearby players eight seconds to react, evacuates and wounds humans, gibs other living
 * occupants, then replaces the patch with the configured terrain and contents.
 */
/datum/ms13_surface_impact
	var/name = "surface impact"
	var/abstract = TRUE
	var/elite = FALSE
	var/radius = 4
	var/warning_time = 8 SECONDS
	var/human_damage_min = 20
	var/human_damage_max = 35
	var/wall_chance = 75
	var/interior_wall_chance = 18
	var/mob_count = 6
	var/feature_count = 7
	var/loot_count = 5
	var/floor_type = /turf/open/floor/plating/ms13/ground/mountain
	var/list/wall_types = list(/turf/closed/mineral/random/ms13)
	var/list/mob_types = list()
	var/list/feature_types = list()
	var/list/loot_types = list()
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

/datum/ms13_surface_impact/proc/is_impact_level(z_level)
	return z_level == SSmapping.station_start

/datum/ms13_surface_impact/proc/get_validation_error(turf/target, check_reservations = TRUE)
	if(!target || !is_impact_level(target.z))
		return "The impact must be placed on the first playable z-level."
	if(target.x <= radius + 3 || target.x > world.maxx - radius - 3 || target.y <= radius + 3 || target.y > world.maxy - radius - 3)
		return "The impact is too close to the map edge to evacuate its occupants safely."

	var/list/footprint = get_footprint(target)
	for(var/turf/affected as anything in footprint)
		if(check_reservations && (affected in GLOB.ms13_surface_impact_reserved_turfs))
			return "Another surface impact already reserves part of this footprint."
		if(affected.resistance_flags & INDESTRUCTIBLE)
			return "The footprint contains protected terrain."
		if(locate(/obj/effect/landmark) in affected || locate(/obj/docking_port) in affected)
			return "The footprint contains mapping infrastructure and cannot be replaced."

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
	addtimer(CALLBACK(src, PROC_REF(resolve)), warning_time)
	return null

/datum/ms13_surface_impact/proc/resolve()
	var/turf/center = locate(center_x, center_y, center_z)
	var/error = get_validation_error(center, FALSE)
	if(error)
		center?.visible_message(span_warning("The marked impact collapses harmlessly: [error]"))
		qdel(src)
		return

	var/list/footprint = get_footprint(center)
	var/list/evacuation_turfs = get_evacuation_turfs(center)
	var/list/humans = list()
	var/list/other_living = list()
	for(var/turf/affected as anything in footprint)
		for(var/mob/living/occupant in affected.get_all_contents())
			if(ishuman(occupant))
				humans |= occupant
			else
				other_living |= occupant

	for(var/mob/living/carbon/human/human as anything in humans)
		var/turf/destination = pick(evacuation_turfs)
		human.forceMove(destination)
		if(get_turf(human) != destination)
			center.visible_message(span_warning("The impact aborts when it cannot evacuate [human]."))
			qdel(src)
			return

	for(var/mob/living/carbon/human/human as anything in humans)
		human.apply_damage(rand(human_damage_min, human_damage_max), BRUTE, BODY_ZONE_CHEST)
		human.Knockdown(3 SECONDS)
		to_chat(human, span_userdanger("The impact hurls you clear and slams you into the ground!"))

	for(var/mob/living/other as anything in other_living)
		if(!QDELETED(other))
			other.gib(TRUE, TRUE, TRUE)

	playsound(center, 'sound/effects/meteorimpact.ogg', 100, TRUE)
	new /obj/effect/temp_visual/explosion(center)
	do_sparks(8, FALSE, center)
	for(var/mob/witness in range(radius + 7, center))
		shake_camera(witness, 8, 3)

	for(var/turf/affected as anything in footprint)
		affected.empty(floor_type, flags = CHANGETURF_DEFAULT_BASETURF | CHANGETURF_INHERIT_AIR)

	var/list/open_turfs = list()
	for(var/x_offset = -radius; x_offset <= radius; x_offset++)
		for(var/y_offset = -radius; y_offset <= radius; y_offset++)
			if(!contains_offset(x_offset, y_offset))
				continue
			var/turf/affected = locate(center_x + x_offset, center_y + y_offset, center_z)
			var/distance_squared = x_offset * x_offset + y_offset * y_offset
			var/on_edge = distance_squared >= (radius - 1) * (radius - 1)
			if((on_edge && prob(wall_chance)) || (!on_edge && (x_offset || y_offset) && prob(interior_wall_chance)))
				affected.ChangeTurf(pick(wall_types), flags = CHANGETURF_DEFAULT_BASETURF | CHANGETURF_INHERIT_AIR)
			else
				open_turfs += affected

	spawn_from_pool(feature_types, feature_count, open_turfs)
	spawn_from_pool(mob_types, mob_count, open_turfs)
	spawn_from_pool(loot_types, loot_count, open_turfs)
	center = locate(center_x, center_y, center_z)
	center.visible_message(span_boldwarning("A [lowertext(name)] tears into the wasteland!"))
	qdel(src)

/datum/ms13_surface_impact/proc/spawn_from_pool(list/spawn_types, amount, list/available_turfs)
	if(!length(spawn_types) || !amount || !length(available_turfs))
		return
	var/list/remaining_turfs = available_turfs.Copy()
	for(var/index in 1 to min(amount, length(remaining_turfs)))
		var/turf/spawn_turf = pick_n_take(remaining_turfs)
		var/spawn_type = pick(spawn_types)
		new spawn_type(spawn_turf)

// Cataclysm-style biological wreckage and anomalous technology.
/datum/ms13_surface_impact/cdda
	name = "CDDA asteroid"
	abstract = FALSE
	mob_types = list(
		/mob/living/simple_animal/hostile/netherworld/migo/ms13_impact,
		/mob/living/simple_animal/hostile/zombie/ms13_impact,
		/mob/living/simple_animal/hostile/zombie/ms13_impact,
		/mob/living/basic/ms13/ghoul,
	)
	feature_types = list(
		/obj/structure/flora/rock,
		/obj/structure/ms13/ore_deposit/uranium,
	)
	loot_types = list(
		/obj/item/ms13/component/cell,
		/obj/item/ms13/component/fusion,
		/obj/item/ms13/component/vacuum_tube,
		/obj/item/ms13/component/plasma_battery,
		/obj/item/stock_parts/cell/ms13/ec,
		/obj/item/gun/energy/ms13/laser/pistol/wattz,
	)

/datum/ms13_surface_impact/cdda/elite
	name = "CDDA asteroid (elite)"
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

// Mineable Mojave rock wrapped around MS ore deposits.
/datum/ms13_surface_impact/natural
	name = "natural asteroid"
	abstract = FALSE
	mob_count = 5
	feature_count = 10
	loot_count = 3
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
	)
	loot_types = list(/obj/item/stack/sheet/ms13/scrap)

/datum/ms13_surface_impact/natural/elite
	name = "natural asteroid (elite)"
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
	)

// A compact machine wreck built from MS metal terrain and salvage.
/datum/ms13_surface_impact/robot
	name = "robot asteroid"
	abstract = FALSE
	floor_type = /turf/open/floor/ms13/metal/plate
	wall_types = list(
		/turf/closed/wall/ms13/metal/rust,
		/turf/closed/wall/ms13/metal/reinforced/rust,
	)
	mob_types = list(
		/mob/living/basic/ms13/robot/handy,
		/mob/living/basic/ms13/robot/handy/saw,
		/mob/living/basic/ms13/robot/handy/gun,
	)
	feature_types = list(
		/obj/structure/girder,
		/obj/effect/decal/cleanable/robot_debris,
	)
	loot_types = list(
		/obj/item/stack/sheet/ms13/scrap_steel/two,
		/obj/item/stack/sheet/ms13/scrap_parts/two,
		/obj/item/stack/sheet/ms13/scrap_electronics/two,
		/obj/item/stack/sheet/ms13/circuits/two,
		/obj/item/ms13/component/vacuum_tube,
		/obj/item/ms13/component/plasma_battery,
	)

/datum/ms13_surface_impact/robot/elite
	name = "robot asteroid (elite)"
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

// A chunk of the original DD station ecosystem, deliberately visually foreign to Mojave.
/datum/ms13_surface_impact/ss13
	name = "SS13 asteroid"
	abstract = FALSE
	floor_type = /turf/open/floor/plating
	wall_types = list(/turf/closed/wall)
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

/datum/ms13_surface_impact/ss13/elite
	name = "SS13 asteroid (elite)"
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

// An extra MS-native variant: a scrap fort and the raiders who rode it down.
/datum/ms13_surface_impact/raider
	name = "raider wreck"
	abstract = FALSE
	floor_type = /turf/open/floor/plating/ms13/ground/desert
	wall_types = list(/turf/closed/wall/ms13/craftable/scrap)
	mob_types = list(
		/mob/living/basic/ms13/raider,
		/mob/living/basic/ms13/raider/metal,
		/mob/living/basic/ms13/raider/tribal,
		/mob/living/basic/ms13/raider/baseball,
	)
	feature_types = list(/obj/structure/closet/crate/ms13/woodcrate)
	loot_types = list(
		/obj/item/stack/sheet/ms13/scrap/two,
		/obj/item/stack/sheet/ms13/scrap_steel/two,
		/obj/item/gun/ballistic/automatic/pistol/ms13/m9mm,
		/obj/item/clothing/suit/ms13/raider,
	)

/datum/ms13_surface_impact/raider/elite
	name = "raider wreck (elite)"
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

/client/proc/ms13_spawn_surface_impact()
	set category = "Debug"
	set name = "MS13 - Spawn Surface Impact"

	if(!check_rights(R_DEBUG))
		return
	var/list/themes = list(
		"CDDA" = list(/datum/ms13_surface_impact/cdda, /datum/ms13_surface_impact/cdda/elite),
		"Natural" = list(/datum/ms13_surface_impact/natural, /datum/ms13_surface_impact/natural/elite),
		"Raider" = list(/datum/ms13_surface_impact/raider, /datum/ms13_surface_impact/raider/elite),
		"Robot" = list(/datum/ms13_surface_impact/robot, /datum/ms13_surface_impact/robot/elite),
		"SS13" = list(/datum/ms13_surface_impact/ss13, /datum/ms13_surface_impact/ss13/elite),
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

	var/list/locations = list("My current tile")
	if(holder?.marked_datum)
		locations += "Marked datum"
	var/location = tgui_input_list(src, "Choose the impact center. Mark a turf or object through View Variables to use it here.", "Surface Impact", locations, locations[1])
	if(!location)
		return
	var/turf/target = get_turf(location == "Marked datum" ? holder.marked_datum : mob)
	if(!target)
		to_chat(src, span_warning("The selected location is no longer valid."), confidential = TRUE)
		return

	var/list/impact_types = themes[theme]
	var/impact_type = impact_types[difficulty == "Elite" ? 2 : 1]
	var/datum/ms13_surface_impact/chosen = new impact_type
	chosen.radius += sizes[size]
	chosen.warning_time = warning_times[warning]

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
