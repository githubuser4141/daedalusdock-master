/obj/structure/lattice/catwalk/ms13
	name = "catwalk"
	desc = "A durable catwalk used mainly in industrial areas"
	icon = 'mojave/icons/structure/catwalk.dmi'
	obj_flags = BLOCK_Z_OUT_DOWN | BLOCK_Z_IN_UP

/obj/structure/lattice/catwalk/ms13/Initialize(mapload)
	. = ..()
	// footstep_override is already added by the parent type (code/game/objects/structures/lattice.dm)
	// with identical args - adding it again here just duplicate-registers the same signal handler.

	var/turf/my_turf = get_turf(loc)
	if(my_turf)
		ADD_TRAIT(my_turf, TRAIT_REMOVE_SLOWDOWN, CATWALK_ON_TURF)

/obj/structure/lattice/catwalk/ms13/Destroy()
	var/turf/my_turf = get_turf(loc)
	if(my_turf)
		REMOVE_TRAIT(my_turf, TRAIT_REMOVE_SLOWDOWN, CATWALK_ON_TURF)
	return ..()
