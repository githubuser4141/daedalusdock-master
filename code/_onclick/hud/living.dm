/datum/hud/living
	// AI EDIT: was 'icons/hud/screen_gen.dmi', which is missing "hand_l"/"hand_r"/"swap_1_m"/"swap_2"
	// (confirmed identical to upstream DD - not a mojave asset issue, just an unnoticed base bug).
	// null lets /datum/hud/New()'s existing preference-based fallback (ui_style2icon(), defaults to
	// Midnight) resolve a complete skin instead, for every living mob, with no per-player action needed.
	ui_style = null

/datum/hud/living/New(mob/living/owner)
	..()

	pull_icon = new /atom/movable/screen/pull(null, src)
	pull_icon.icon = ui_style
	pull_icon.update_appearance()
	pull_icon.screen_loc = ui_living_pull
	static_inventory += pull_icon

	combo_display = new /atom/movable/screen/combo(null, src)
	infodisplay += combo_display

	//mob health doll! assumes whatever sprite the mob is
	healthdoll = new /atom/movable/screen/healthdoll/living(null, src)
	infodisplay += healthdoll
