/** BURNS **/
// MOJAVE EDIT: burns used to never bleed at all (min_bleeding_stage = INFINITY + a bleeding() override
// hardcoded to FALSE). Gave the split-open "ripped X burn" stage a min_bleeding_stage like cuts.dm
// already does for its "ripped cut" stage, so a bad enough burn weeps/bleeds same as any other wound -
// this reuses the fully generic bleed_rate/get_modified_bleed_rate() system (_bodyparts.dm), so an
// applied bandage already slows/stops it exactly like it does for cuts, with no extra code needed.
// Carbonised burns have no "ripped" stage (charred flesh doesn't weep) so they keep the old never-bleeds
// behavior explicitly.
/datum/wound/burn
	pain_factor = 1.875
	wound_type = WOUND_BURN

/datum/wound/burn/moderate
	min_bleeding_stage = 3
	stages = list(
		"fresh skin" = 0,
		"healing moderate burn" = 2,
		"moderate burn" = 5,
		"ripped burn" = 10,
	)

/datum/wound/burn/large
	min_bleeding_stage = 3
	stages = list(
		"fresh skin" = 0,
		"healing large burn" = 5,
		"large burn" = 15,
		"ripped large burn" = 20,
	)

/datum/wound/burn/severe
	min_bleeding_stage = 3
	stages = list(
		"burn scar" = 0,
		"healing severe burn" = 10,
		"severe burn" = 30,
		"ripped severe burn" = 35,
	)

/datum/wound/burn/deep
	min_bleeding_stage = 3
	stages = list(
		"large burn scar" = 0,
		"healing deep burn" = 15,
		"deep burn" = 40,
		"ripped deep burn" = 45,
	)

/datum/wound/burn/carbonised
	min_bleeding_stage = INFINITY
	stages = list(
		"massive burn scar" = 0,
		"healing carbonised area" = 20,
		"carbonised area" = 50,
	)
