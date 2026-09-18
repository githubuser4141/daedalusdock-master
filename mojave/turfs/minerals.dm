/turf/closed/indestructible/rock/ms13
	name = "dense rock"
	desc = "An extremely densely-packed rock, most mining tools or explosives would never get through this."
	icon = 'mojave/icons/turf/walls/rock.dmi'
	frill_icon = 'mojave/icons/turf/walls/rock_frill.dmi'
	icon_state = "wall-0"
	base_icon_state = "wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_MS13_MINERALS
	canSmoothWith = SMOOTH_GROUP_MS13_MINERALS

/turf/closed/indestructible/rock/ms13/drought
	icon = 'mojave/icons/turf/walls/rockdrought.dmi'
	frill_icon = 'mojave/icons/turf/walls/rockdrought_frill.dmi'

/turf/closed/indestructible/rock/ms13/mammoth
	icon = 'mojave/icons/turf/walls/rockmammoth.dmi'
	frill_icon = 'mojave/icons/turf/walls/rockmammoth_frill.dmi'

// Mineable counterparts for passages and shortcuts; the indestructible family remains for map boundaries.
/turf/closed/mineral/random/ms13
	name = "rock"
	desc = "Weathered rock that can be broken apart with mining tools."
	icon = 'mojave/icons/turf/walls/rock.dmi'
	frill_icon = 'mojave/icons/turf/walls/rock_frill.dmi'
	icon_state = "wall-0"
	base_icon_state = "wall"
	transform = matrix()
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_MS13_MINERALS
	canSmoothWith = SMOOTH_GROUP_MS13_MINERALS
	baseturfs = /turf/open/floor/plating/ms13/ground/mountain
	turf_type = /turf/open/floor/plating/ms13/ground/mountain
	initial_gas = OPENTURF_DEFAULT_ATMOS
	temperature = T20C

/turf/closed/mineral/random/ms13/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/frill, frill_icon)

/turf/closed/mineral/random/ms13/drought
	icon = 'mojave/icons/turf/walls/rockdrought.dmi'
	frill_icon = 'mojave/icons/turf/walls/rockdrought_frill.dmi'
	baseturfs = /turf/open/floor/plating/ms13/ground/mountain/drought
	turf_type = /turf/open/floor/plating/ms13/ground/mountain/drought

/turf/closed/mineral/random/ms13/mammoth
	icon = 'mojave/icons/turf/walls/rockmammoth.dmi'
	frill_icon = 'mojave/icons/turf/walls/rockmammoth_frill.dmi'
