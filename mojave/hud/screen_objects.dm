/atom/movable/screen/ms13/button_background
	name = "background"
	icon = 'mojave/icons/hud/ms_ui_base.dmi'
	icon_state = ""
	layer = HUD_BACKGROUND_LAYER
	// The full 96x480 canvas must count towards the secondary map's auto-fit bounds.
	appearance_flags = APPEARANCE_UI & ~TILE_BOUND
	screen_loc = "hud:EAST,SOUTH"
	mouse_opacity = 0

// Cover the decorative lettering beneath the utility controls; retain the case rim.
/atom/movable/screen/ms13/header_background
	icon = 'mojave/icons/hud/storage.dmi'
	icon_state = "white"
	color = "#272c32"
	layer = HUD_BACKGROUND_LAYER + 0.01
	screen_loc = "hud:EAST:4,SOUTH:394"
	transform = matrix(2.75, 0, 28, 0, 2.5625, 25)
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/craft/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	if(hud?.contains_off_screen_hud)
		screen_loc = "hud:EAST:2,SOUTH:444"

/atom/movable/screen/ms13/slot_background
	name = "base"
	icon = 'mojave/icons/hud/ms_ui_inventory.dmi'
	icon_state = "base"
	layer = HUD_BACKGROUND_LAYER
	screen_loc = "LEFT,BOTTOM"
	mouse_opacity = 0

/atom/movable/screen/ms13/hand_background
	name = "base"
	icon = 'mojave/icons/hud/ms_ui_hands.dmi'
	icon_state = "base"
	layer = HUD_BACKGROUND_LAYER
	screen_loc = "CENTER:-80,BOTTOM"
	mouse_opacity = 0

/atom/movable/screen/combattoggle/ms13
	icon = 'mojave/icons/hud/ms_ui_combat.dmi'
	icon_state = "combat_off"

/atom/movable/screen/combattoggle/ms13/update_icon_state()
	. = ..()
	var/mob/living/owner = hud?.mymob
	icon_state = owner?.combat_mode ? "combat" : "combat_off"

/atom/movable/screen/zone_sel/ms13
	icon = 'mojave/icons/hud/ms_ui_target.dmi'
	overlay_icon = 'mojave/icons/hud/ms_ui_target.dmi'

// Mojave Sun's 96x96 doll uses different hit regions from DD's 32x32 selector.
/atom/movable/screen/zone_sel/ms13/get_zone_at(icon_x, icon_y)
	switch(icon_y)
		if(15 to 42)
			switch(icon_x)
				if(37 to 48)
					return BODY_ZONE_R_LEG
				if(50 to 60)
					return BODY_ZONE_L_LEG
		if(43 to 47)
			switch(icon_x)
				if(36 to 39)
					return BODY_ZONE_R_ARM
				if(42 to 55)
					return BODY_ZONE_PRECISE_GROIN
				if(59 to 62)
					return BODY_ZONE_L_ARM
		if(48 to 68)
			switch(icon_x)
				if(36 to 41)
					return BODY_ZONE_R_ARM
				if(42 to 55)
					return BODY_ZONE_CHEST
				if(56 to 62)
					return BODY_ZONE_L_ARM
		if(69 to 78)
			if(icon_x in 46 to 52)
				if(icon_y >= 72 && icon_y <= 73 && icon_x >= 47 && icon_x <= 51)
					return BODY_ZONE_PRECISE_MOUTH
				if(icon_y >= 74 && icon_y <= 75 && (icon_x in list(47, 48, 50, 51)))
					return BODY_ZONE_PRECISE_EYES
				return BODY_ZONE_HEAD

/atom/movable/screen/human/toggle/ms13
	icon = 'mojave/icons/hud/ms_ui_buttons.dmi'
	icon_state = "inventory"

/atom/movable/screen/human/toggle/ms13/Click()
	. = ..()
	icon_state = usr?.hud_used?.inventory_shown ? "inventory_on" : "inventory"

/atom/movable/screen/rest/ms13
	icon = 'mojave/icons/hud/ms_ui_buttons.dmi'
	icon_state = "rest"
	base_icon_state = "rest"
	screen_loc = "hud:EAST,SOUTH"

/atom/movable/screen/pull/ms13
	icon = 'mojave/icons/hud/ms_ui_buttons.dmi'
	icon_state = "pull"
	base_icon_state = "pull"
	screen_loc = "hud:EAST,SOUTH"

//atom/movable/screen/resist/ms13

//atom/movable/screen/drop/ms13

/atom/movable/screen/throw_catch/ms13
	icon = 'mojave/icons/hud/ms_ui_buttons.dmi'
	icon_state = "act_throw_off"
	screen_loc = "hud:EAST,SOUTH"

/atom/movable/screen/mov_intent/ms13
	icon = 'mojave/icons/hud/ms_ui_buttons.dmi'
	icon_state = "running"
	screen_loc = "hud:EAST,SOUTH"


