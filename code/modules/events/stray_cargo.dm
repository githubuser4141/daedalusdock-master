///Spawns a cargo pod containing a random cargo supply pack on a random area of the station
/datum/round_event_control/stray_cargo
	name = "Stray Cargo Pod"
	typepath = /datum/round_event/stray_cargo
	weight = 20
	max_occurrences = 4
	earliest_start = 10 MINUTES

/datum/round_event_control/stray_cargo/canSpawnEvent(players_amt)
	return length(GLOB.the_station_areas) && ..()

///Spawns a cargo pod containing a random cargo supply pack on a random area of the station
/datum/round_event/stray_cargo
	var/area/impact_area ///Randomly picked area
	announceChance = 75
	var/list/possible_pack_types = list() ///List of possible supply packs dropped in the pod, if empty picks from the cargo list
	var/static/list/stray_spawnable_supply_packs = list() ///List of default spawnable supply packs, filtered from the cargo list

/datum/round_event/stray_cargo/New(my_processing = TRUE)
	. = ..()
	if(!impact_area)
		processing = FALSE
		kill()

/datum/round_event/stray_cargo/announce(fake)
	if(!impact_area)
		return
	priority_announce("Stray cargo pod detected on long-range scanners. Expected location of impact: [impact_area.name].")

/**
* Tries to find a valid area; maps without one cannot receive this event.
* Also randomizes the start timer
*/
/datum/round_event/stray_cargo/setup()
	startWhen = rand(20, 40)
	impact_area = find_event_area()
	if(!impact_area)
		return

	if(!stray_spawnable_supply_packs.len)
		stray_spawnable_supply_packs = SSshuttle.supply_packs.Copy()
		for(var/pack in stray_spawnable_supply_packs)
			var/datum/supply_pack/pack_type = pack
			if(initial(pack_type.special))
				stray_spawnable_supply_packs -= pack

///Spawns a random supply pack, puts it in a pod, and spawns it on a random tile of the selected area
/datum/round_event/stray_cargo/start()
	if(!impact_area)
		return
	var/list/turf/valid_turfs = impact_area.get_contained_turfs()
	valid_turfs = valid_turfs.Copy()
	//Only target non-dense turfs to prevent wall-embedded pods
	for(var/i in valid_turfs)
		var/turf/T = i
		if(T.density)
			valid_turfs -= T
	if(!length(valid_turfs) || (!length(possible_pack_types) && !length(stray_spawnable_supply_packs)))
		return
	var/turf/LZ = pick(valid_turfs)
	var/pack_type
	if(possible_pack_types.len)
		pack_type = pick(possible_pack_types)
	else
		pack_type = pick(stray_spawnable_supply_packs)
	var/datum/supply_pack/SP = new pack_type
	var/obj/structure/closet/crate/crate = SP.generate(null)
	crate.locked = FALSE //Unlock secure crates
	crate.update_appearance()
	var/obj/structure/closet/supplypod/pod = make_pod()
	new /obj/effect/pod_landingzone(LZ, pod, crate)

///Handles the creation of the pod, in case it needs to be modified beforehand
/datum/round_event/stray_cargo/proc/make_pod()
	var/obj/structure/closet/supplypod/S = new
	return S

///Picks an area that wouldn't risk critical damage if hit by a pod explosion
/datum/round_event/stray_cargo/proc/find_event_area()
	///Places that shouldn't explode
	var/static/list/safe_area_types = typecacheof(list(
		/area/station/ai_monitored/turret_protected/ai,
		/area/station/ai_monitored/turret_protected/ai_upload,
		/area/station/engineering,
		/area/shuttle,
	))

	///Subtypes from the above that actually should explode.
	var/static/list/unsafe_area_subtypes = typecacheof(list(/area/station/engineering/break_room))
	var/list/allowed_areas = make_associative(GLOB.the_station_areas) - (safe_area_types - unsafe_area_subtypes)
	var/list/possible_areas = typecache_filter_list(GLOB.areas, allowed_areas)
	while(length(possible_areas))
		var/area/candidate = pick_n_take(possible_areas)
		if(get_first_open_turf_in_area(candidate))
			return candidate

///A rare variant that drops a crate containing syndicate uplink items
/datum/round_event_control/stray_cargo/syndicate
	name = "Stray Syndicate Cargo Pod"
	typepath = /datum/round_event/stray_cargo/syndicate
	weight = 6
	max_occurrences = 1
	earliest_start = 30 MINUTES

/datum/round_event/stray_cargo/syndicate
	possible_pack_types = list(/datum/supply_pack/misc/syndicate)

///Apply the syndicate pod skin
/datum/round_event/stray_cargo/syndicate/make_pod()
	var/obj/structure/closet/supplypod/S = new
	S.setStyle(STYLE_SYNDICATE)
	return S
