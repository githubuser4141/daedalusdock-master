#define MS13_HUMAN_DAMAGE_ICON 'mojave/icons/mob/human_damage.dmi'

/**
 * MS13 wound and decay sprites in place of DD's brute/burn overlays. Each limb shows "[zone]_damage1-4" by how
 * hurt it is and "[zone]_rot1-2" as the corpse rots; "pus" shows while a limb is badly infected and "vermin"
 * once the body is far gone. Missing states are skipped, so the sheet can be re-cut freely.
 */
/mob/living/carbon/human/update_damage_overlays()
	remove_overlay(DAMAGE_LAYER)
	var/list/overlays = list()
	var/infected = FALSE
	for(var/obj/item/bodypart/part as anything in bodyparts)
		if(part.is_stump || part.is_husked)
			continue
		var/damage_tier = part.ms13_damage_tier()
		if(damage_tier)
			ms13_add_damage_overlay(overlays, "[part.body_zone]_damage[damage_tier]")
		if(rotting)
			ms13_add_damage_overlay(overlays, "[part.body_zone]_rot[rotting]")
		if(part.germ_level >= INFECTION_LEVEL_TWO)
			infected = TRUE
	if(infected)
		ms13_add_damage_overlay(overlays, "pus")
	if(rotting >= 2)
		ms13_add_damage_overlay(overlays, "vermin")
	overlays_standing[DAMAGE_LAYER] = overlays
	if(length(overlays))
		apply_overlay(DAMAGE_LAYER)

/proc/ms13_add_damage_overlay(list/overlays, state)
	if(ms13_icon_has_state(MS13_HUMAN_DAMAGE_ICON, state))
		overlays += image(MS13_HUMAN_DAMAGE_ICON, state, -DAMAGE_LAYER)

/// 0 (unhurt) to 4 (about to fail), by total damage against the limb's max.
/obj/item/bodypart/proc/ms13_damage_tier()
	return clamp(round(4 * get_damage() / max_damage, 1), 0, 4)

/// DD only redraws when its own three-step brute/burn states change; the four MS13 tiers step elsewhere.
/obj/item/bodypart/update_damage()
	var/old_tier = ms13_damage_tier()
	. = ..()
	if(ms13_damage_tier() != old_tier)
		. |= BODYPART_LIFE_UPDATE_DAMAGE_OVERLAYS

#undef MS13_HUMAN_DAMAGE_ICON
