#define SMOOTH_GROUP_TARGET_INDICATOR S_OBJ(400)

/obj/effect/temp_visual/ms13/target_indicator
	name = "generic warning indicator"
	desc = "Do you even have the time to spare looking at this?"
	icon = 'mojave/icons/effects/target_indicator.dmi'
	icon_state = "target_indicator-0"
	base_icon_state = "target_indicator"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_TARGET_INDICATOR
	canSmoothWith = SMOOTH_GROUP_TARGET_INDICATOR
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	duration = 5 //0.5 SECONDS

/obj/effect/temp_visual/ms13/target_indicator/Initialize(mapload)
	. = ..()
	// /obj/effect does not run the smoothing setup used by turfs, structures, and machinery.
	SETUP_SMOOTHING()
	if(smoothing_flags & (SMOOTH_BITMASK))
		smooth_indicators_beside()
		QUEUE_SMOOTH(src)

/obj/effect/temp_visual/ms13/target_indicator/Destroy()
	if(smoothing_flags & (SMOOTH_BITMASK))
		smooth_indicators_beside()
	return ..()

/// It only joins up with other indicators: QUEUE_SMOOTH_NEIGHBORS() would redo every floor and wall around it too.
/obj/effect/temp_visual/ms13/target_indicator/proc/smooth_indicators_beside()
	for(var/obj/effect/temp_visual/ms13/target_indicator/other in orange(1, src))
		QUEUE_SMOOTH(other)
