/obj/structure/lattice/catwalk/ms13
	name = "catwalk"
	desc = "A durable catwalk used mainly in industrial areas"
	icon = 'mojave/icons/structure/catwalk.dmi'
	obj_flags = BLOCK_Z_OUT_DOWN | BLOCK_Z_IN_UP

/obj/structure/lattice/catwalk/ms13/Initialize(mapload)
	. = ..()
	var/static/list/bad_initialize = list(INITIALIZE_HINT_QDEL, INITIALIZE_HINT_QDEL_FORCE)
	if(!(. in bad_initialize))
		AddElement(/datum/element/footstep_override, clawfootstep = FOOTSTEP_CATWALK, heavyfootstep = FOOTSTEP_CATWALK, footstep = FOOTSTEP_CATWALK) // AI EDIT: footstep_changer component doesn't exist - footstep_override is DD's real equivalent (already used by the parent type, code/game/objects/structures/lattice.dm)

	var/turf/my_turf = get_turf(loc)
	if(my_turf)
		ADD_TRAIT(my_turf, TRAIT_REMOVE_SLOWDOWN, CATWALK_ON_TURF)

/obj/structure/lattice/catwalk/ms13/Destroy()
	var/turf/my_turf = get_turf(loc)
	if(my_turf)
		REMOVE_TRAIT(my_turf, TRAIT_REMOVE_SLOWDOWN, CATWALK_ON_TURF)
	return ..()
