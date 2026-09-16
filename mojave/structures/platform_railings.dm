TYPEINFO_DEF(/obj/structure/ms13/platform_railings)
	default_armor = list(BLUNT = 60, PUNCTURE = 0, SLASH = 60, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, FIRE = 80, ACID = 50)

/obj/structure/ms13/platform_railings
	name = "steel platform"
	desc = "A durable industrial platform made of thick steel rods."
	icon = 'mojave/icons/structure/platform_railings.dmi'
	icon_state = "platrailings_full"
	density = FALSE
	anchored = TRUE
	max_integrity = 200
	layer = LATTICE_LAYER
	plane = FLOOR_PLANE
	obj_flags = CAN_BE_HIT | BLOCK_Z_OUT_DOWN | BLOCK_Z_IN_UP
	var/number_of_mats = 2
	var/build_material = /obj/item/stack/sheet/ms13/scrap_steel

/obj/structure/ms13/platform_railings/inner
	icon_state = "platrailings_innercorner"

/obj/structure/ms13/platform_railings/Initialize(mapload)
	. = ..()
	var/static/list/bad_initialize = list(INITIALIZE_HINT_QDEL, INITIALIZE_HINT_QDEL_FORCE)
	if(!(. in bad_initialize))
		AddElement(/datum/element/footstep_override, clawfootstep = FOOTSTEP_CATWALK, heavyfootstep = FOOTSTEP_CATWALK, footstep = FOOTSTEP_CATWALK) // AI EDIT: footstep_changer component doesn't exist - footstep_override is DD's real equivalent (see code/game/objects/structures/lattice.dm)

	var/turf/my_turf = get_turf(loc)
	if(my_turf)
		ADD_TRAIT(my_turf, TRAIT_REMOVE_SLOWDOWN, CATWALK_ON_TURF)

/obj/structure/ms13/platform_railings/Destroy()
	var/turf/my_turf = get_turf(loc)
	if(my_turf)
		REMOVE_TRAIT(my_turf, TRAIT_REMOVE_SLOWDOWN, CATWALK_ON_TURF)
	return ..()

/obj/structure/ms13/platform_railings/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new build_material(get_turf(src), number_of_mats)
	qdel(src)
