/**
 * Makes an object look wired in: a length of cable runs from it to any power cable on a neighbouring tile that
 * ends at its edge. Purely visual - nothing joins a powernet.
 */
/datum/element/ms13_wired_look
	element_flags = ELEMENT_DETACH

/datum/element/ms13_wired_look/Attach(datum/target)
	. = ..()
	if(!ismovable(target))
		return ELEMENT_INCOMPATIBLE
	ADD_TRAIT(target, TRAIT_MS13_WIRED_LOOK, ELEMENT_TRAIT(type))
	RegisterSignal(target, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(add_wires))
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	// Neighbouring cables may not exist yet during mapload.
	addtimer(CALLBACK(target, TYPE_PROC_REF(/atom, update_appearance), UPDATE_OVERLAYS), 0)

/datum/element/ms13_wired_look/Detach(atom/movable/source)
	UnregisterSignal(source, list(COMSIG_ATOM_UPDATE_OVERLAYS, COMSIG_MOVABLE_MOVED))
	REMOVE_TRAIT(source, TRAIT_MS13_WIRED_LOOK, ELEMENT_TRAIT(type))
	if(!QDELETED(source))
		source.update_appearance(UPDATE_OVERLAYS)
	return ..()

/datum/element/ms13_wired_look/proc/on_moved(atom/movable/source)
	SIGNAL_HANDLER
	source.update_appearance(UPDATE_OVERLAYS)

/datum/element/ms13_wired_look/proc/add_wires(atom/movable/source, list/overlays)
	SIGNAL_HANDLER
	var/turf/here = source.loc
	if(!isturf(here) || here.underfloor_accessibility < UNDERFLOOR_VISIBLE)
		return
	for(var/direction in GLOB.alldirs)
		var/turf/there = get_step(here, direction)
		if(!there || there.underfloor_accessibility < UNDERFLOOR_VISIBLE)
			continue
		var/toward_us = GLOB.real_dirs_to_cable_dirs["[REVERSE_DIR(direction)]"]
		for(var/obj/structure/cable/cable in there)
			if(!(cable.linked_dirs & toward_us))
				continue
			var/mutable_appearance/wire = mutable_appearance(cable.icon, "[GLOB.real_dirs_to_cable_dirs["[direction]"]]", WIRE_LAYER, appearance_flags = RESET_COLOR)
			wire.color = cable.color
			// Line up with the tile, not wherever the sprite is nudged to.
			wire.pixel_x = -source.pixel_x
			wire.pixel_y = -source.pixel_y
			overlays += wire
			break

/// Redraws wired-look objects around a cable that just changed.
/proc/ms13_refresh_wired_looks(turf/center)
	if(!center)
		return
	for(var/turf/nearby as anything in RANGE_TURFS(1, center))
		for(var/atom/movable/thing as anything in nearby)
			if(HAS_TRAIT(thing, TRAIT_MS13_WIRED_LOOK))
				thing.update_appearance(UPDATE_OVERLAYS)

/obj/structure/cable/Initialize(mapload)
	. = ..()
	if(!mapload)
		ms13_refresh_wired_looks(get_turf(src))

/obj/structure/cable/set_directions(new_directions, merge_connections = TRUE)
	. = ..()
	ms13_refresh_wired_looks(get_turf(src))

/obj/structure/cable/Destroy()
	var/turf/old_turf = get_turf(src)
	. = ..()
	ms13_refresh_wired_looks(old_turf)
