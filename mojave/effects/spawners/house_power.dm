// MOJAVE SUN HOUSE POWER SPAWNER //
// Place one of these where a house's power equipment goes. At round start it rolls (or, if
// forced_outcome is set on the instance, always picks) one outcome and spawns the matching gear,
// then deletes itself. Mirrors the visual convention of an existing generator setup: a metal-plate
// floor with a rubber rug under the equipment.
//
// This does NOT lay any cable - real wiring between a spawned generator and its APC is still a
// manual map-editor job (see mojave/machinery/generators.dm and mojave/code/modules/power/
// apc_ms13.dm for why: the generator/APC connect through DD's real powernet, not a pushed link).
// "working" only means the generator starts switched on - it stays powerless until you wire it to
// the APC yourself. "apc_only" and "none" need no wiring at all, since always_on always has power
// and "none" has no equipment to power.

/obj/effect/spawner/ms13_house_power
	name = "house power setup (mapping helper)"
	desc = "Rolls a chance of this house having a generator, a bare fusebox, or nothing at all. Deletes itself at round start."
	icon = 'mojave/icons/effects/mapping_helpers.dmi'
	icon_state = "random"
	anchored = TRUE
	/// Outcome -> weight. "working"/"off"/"broken" all spawn a generator + a regular fusebox (still
	/// needs manual wiring for "working" to matter); "apc_only" spawns just an always-powered
	/// fusebox; "none" spawns nothing.
	var/list/outcome_weights = list(
		"working" = 30,
		"off" = 20,
		"broken" = 15,
		"apc_only" = 20,
		"none" = 15,
	)
	/// Set this on a specific instance (map editor variable edit) to skip the roll entirely - for
	/// plot-relevant houses that need guaranteed power, or guaranteed darkness.
	var/forced_outcome

/obj/effect/spawner/ms13_house_power/Initialize(mapload)
	. = ..()
	var/outcome = forced_outcome || pick_weight(outcome_weights)
	var/turf/target_turf = get_turf(src)

	if(outcome != "none")
		// ChangeTurf() deletes the old turf instance and builds a new one in its place. We're
		// anchored, so we can't assume src (or a cached reference to the old turf) survives that -
		// re-locate the replacement turf by coordinates instead of relying on src/loc afterward.
		var/list/turf_coords = list(target_turf.x, target_turf.y, target_turf.z)
		target_turf.ChangeTurf(/turf/open/floor/ms13/metal/plate)
		target_turf = locate(turf_coords[1], turf_coords[2], turf_coords[3])
		new /obj/structure/ms13/rug/rubber(target_turf)

	switch(outcome)
		// generator_state's real values ("on"/"off"/"broken") are #defined GENERATOR_ON/OFF/BROKEN
		// in generators.dm but #undef'd at the end of that file - using the literal strings here
		// rather than reaching across files for defines that are deliberately file-scoped.
		if("working")
			spawn_generator("on", target_turf)
			new /obj/machinery/power/apc/ms13(target_turf)
		if("off")
			spawn_generator("off", target_turf)
			new /obj/machinery/power/apc/ms13(target_turf)
		if("broken")
			spawn_generator("broken", target_turf)
			new /obj/machinery/power/apc/ms13(target_turf)
		if("apc_only")
			new /obj/machinery/power/apc/ms13/always_on(target_turf)
		// "none": no equipment, nothing left to do.

	return INITIALIZE_HINT_QDEL

/obj/effect/spawner/ms13_house_power/proc/spawn_generator(starting_state, turf/spawn_turf)
	var/obj/machinery/ms13/fusion_generator/new_generator = new(spawn_turf)
	new_generator.generator_state = starting_state
	new_generator.update_appearance()
