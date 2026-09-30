/atom/movable/screen/resist
	name = "resist"
	icon = 'mojave/icons/hud/ms_ui_combat.dmi'
	icon_state = "resist"
	base_icon_state = "resist"
	plane = HUD_PLANE

/atom/movable/screen/resist/Click()
	if(isliving(usr))
		var/mob/living/L = usr
		L.resist()

/atom/movable/screen/wield
	name = "wield"
	icon = 'mojave/icons/hud/ms_ui_combat.dmi'
	icon_state = "wield"
	base_icon_state = "wield"
	plane = HUD_PLANE

/atom/movable/screen/wield/Click()
	if(isliving(usr))
		var/mob/living/L = usr
		L.wield_active_hand()

/atom/movable/screen/wield/update_icon_state()
	. = ..()
	var/obj/item/held = hud?.mymob?.get_active_held_item()
	if(held?.wielded)
		icon_state = "[base_icon_state]_active"
	else
		icon_state = base_icon_state

/// Grain strength: what's always there, and what someone as badly off as it gets sees.
#define MS13_GRAIN_BASE 0.5
#define MS13_GRAIN_MAX 2

/**
 * Film grain over the world, for the grimdark look: always a little, heavier the worse off you are. It's the camera
 * static tile, colour-matrixed so only its dark specks show, as black grain; the matrix strength is the intensity.
 */
/atom/movable/screen/fullscreen/ms13_grain
	icon = 'icons/hud/screen_gen.dmi'
	icon_state = "noise"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/strength = MS13_GRAIN_BASE

/atom/movable/screen/fullscreen/ms13_grain/Initialize(mapload)
	. = ..()
	color = ms13_grain_matrix(strength)

/// Black everywhere, as opaque as the noise is dark, times strength.
/proc/ms13_grain_matrix(strength)
	var/tint = -strength / 3
	return list(0,0,0,tint, 0,0,0,tint, 0,0,0,tint, 0,0,0,0, 0,0,0,strength)

/// How heavy the grain is for them: low mood, pain, injury and hunger each ease it in and compound; a good mood thins it.
/mob/living/carbon/human/proc/ms13_grain_strength()
	var/sad = clamp(mob_mood?.mood / MOOD_LEVEL_SAD4, -1, 1)
	var/pain = clamp(getPain() / PAIN_AMT_AGONIZING, 0, 1)
	var/injury = clamp((getBruteLoss() + getFireLoss()) / maxHealth, 0, 1)
	var/hunger = clamp((NUTRITION_LEVEL_HUNGRY - nutrition) / NUTRITION_LEVEL_HUNGRY, 0, 1)
	var/grim = 1 - (1 - 0.5 * max(sad, 0)) * (1 - 0.6 * pain) * (1 - 0.5 * injury) * (1 - 0.4 * hunger)
	return MS13_GRAIN_BASE * (1 + 0.5 * min(sad, 0)) + (MS13_GRAIN_MAX - MS13_GRAIN_BASE) * grim

/// Keeps their grain in step with how they're doing. Off for anyone who asked for darkened flashes (photosensitivity).
/mob/living/carbon/human/proc/ms13_update_grain()
	if(!client)
		return
	if(client.prefs?.read_preference(/datum/preference/toggle/darkened_flash))
		clear_fullscreen("grain", 0)
		return
	var/atom/movable/screen/fullscreen/ms13_grain/grain = overlay_fullscreen("grain", /atom/movable/screen/fullscreen/ms13_grain)
	var/strength = ms13_grain_strength()
	if(abs(strength - grain.strength) < 0.05)
		return
	grain.strength = strength
	animate(grain, color = ms13_grain_matrix(strength), time = 2 SECONDS)

/mob/living/carbon/human/Life(delta_time = SSMOBS_DT, times_fired)
	. = ..()
	ms13_update_grain()

#ifdef UNIT_TESTS
/datum/unit_test/ms13_film_grain
	name = "HUD: Film Grain Thickens As Things Get Grim"

/datum/unit_test/ms13_film_grain/Run()
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	subject.set_nutrition(NUTRITION_LEVEL_FED)
	var/rested = subject.ms13_grain_strength()
	if(abs(rested - MS13_GRAIN_BASE) > 0.1)
		return Fail("A fed, unhurt, level-headed person saw grain at [rested], not about [MS13_GRAIN_BASE].")
	subject.apply_damage(40, BRUTE, BODY_ZONE_CHEST)
	subject.set_nutrition(NUTRITION_LEVEL_STARVING / 2)
	var/grim = subject.ms13_grain_strength()
	if(grim <= rested || grim > MS13_GRAIN_MAX)
		return Fail("Injury and hunger moved the grain from [rested] to [grim], not up within [MS13_GRAIN_MAX].")
#endif

#undef MS13_GRAIN_BASE
#undef MS13_GRAIN_MAX
