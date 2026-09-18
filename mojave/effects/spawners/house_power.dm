// MOJAVE SUN HOUSE POWER MARKER //
// Buildings get a random power setup at round start (mojave/code/modules/power/house_power.dm). Place one of
// these anywhere inside a building to force its outcome instead: "working", "off", "broken", "box_only" for
// an unpowered utility box, or "none" for a house that stays dark. It works even in areas that normally skip
// house power.

/obj/effect/spawner/ms13_house_power
	name = "house power outcome (mapping helper)"
	desc = "Forces the round-start power setup of the building it's in. Deletes itself at round start."
	icon = 'mojave/icons/effects/mapping_helpers.dmi'
	icon_state = "random"
	anchored = TRUE
	var/forced_outcome = "working"

/obj/effect/spawner/ms13_house_power/Initialize(mapload)
	. = ..()
	GLOB.ms13_house_power_overrides[get_turf(src)] = forced_outcome
	return INITIALIZE_HINT_QDEL
