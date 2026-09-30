/datum/hud
	/// Whether we are wielding something or not right now, makes for faster icon updates
	var/wield_active = FALSE
	/// Part of this HUD lives in MS13's side panel, the "hud:" map (code/__DEFINES/hud.dm).
	var/contains_off_screen_hud = FALSE

/datum/hud/show_hud(version = 0, mob/viewmob)
	. = ..()
	if(!.)
		return
	var/mob/screenmob = viewmob || mymob
	reorganize_alert_texts(screenmob)
	if(screenmob?.client)
		INVOKE_ASYNC(screenmob.client, TYPE_PROC_REF(/client, setHudBarVisible))

/// MS13's hands: their own art, side by side at the bottom centre.
/datum/hud/build_hand_slots()
	. = ..()
	if(!contains_off_screen_hud)
		return
	for(var/index in hand_slots)
		var/atom/movable/screen/inventory/hand/hand_box = hand_slots[index]
		hand_box.icon = 'mojave/icons/hud/ms_ui_slots_hands.dmi'
		hand_box.screen_loc = text2num(index) == 1 ? "CENTER:2,SOUTH" : "CENTER:-44,SOUTH"
		hand_box.update_appearance()

/// Gives MS13's side panel its HUD_WIDTH share of the window when the HUD uses it, or the map the whole window when not.
/client/proc/setHudBarVisible()
	var/visible = mob?.hud_used ? mob.hud_used.contains_off_screen_hud && mob.hud_used.hud_version != HUD_STYLE_NOHUD : FALSE
	var/list/screen_size = splittext(winget(src, "mapwindow", "size"), "x")
	if(length(screen_size) != 2)
		return
	var/screen_width = text2num(screen_size[1])
	var/tile_width = screen_width / (getviewsize(view)[1] + HUD_WIDTH)
	var/hud_width = round(HUD_WIDTH * tile_width)
	if(visible)
		winset(src, "mapwindow.map", "pos=[hud_width],0;size=[screen_width - hud_width]x[screen_size[2]];anchor1=[100 * hud_width / screen_width],0")
	else
		winset(src, "mapwindow.map", "pos=0,0;size=[screen_width]x[screen_size[2]];anchor1=0,0")
	// Left shown even when unused, or it leaves a blank block.
	winset(src, "mapwindow.hud", "size=[hud_width]x[screen_size[2]]")

/client/set_right_click_menu_mode(shift_only)
	. = ..()
	winset(src, "mapwindow.hud", "right-click=[shift_only ? "true" : "false"]")

/// MS13 targeting art for the selected and hovered zones, matching the zone selector itself.
/atom/movable/screen/zone_sel
	overlay_icon = 'mojave/icons/hud/ms_ui_target.dmi'

/// MS13's doll only has light, heavy and gone per limb, redrawn over DD's. Fire has MS13's own light.
/mob/living/carbon/human/update_health_hud()
	. = ..()
	var/atom/movable/screen/healthdoll = hud_used?.healthdoll
	if(!healthdoll || !hud_used.contains_off_screen_hud || stat == DEAD)
		return
	var/list/new_overlays = list()
	var/in_pain = FALSE
	for(var/obj/item/bodypart/body_part as anything in bodyparts)
		var/state = ms13_doll_state(body_part)
		if(state)
			new_overlays += image(healthdoll.icon, state)
		in_pain ||= body_part.getPain() > 20
	for(var/zone in get_missing_limbs())
		new_overlays += image(healthdoll.icon, "[zone]3")
	// Stand-ins in DD's doll-head art until these get MS13 art, in the status lights' second row.
	if(in_pain)
		new_overlays += image('icons/hud/screen_gen.dmi', "headpain", pixel_x = 11, pixel_y = 34)
	if(undergoing_cardiac_arrest())
		new_overlays += image('icons/hud/screen_gen.dmi', "head", pixel_x = 67, pixel_y = 34)
	healthdoll.cut_overlays()
	healthdoll.add_overlay(new_overlays)

/// A limb's mark on MS13's doll: 1 light, 2 heavy, 3 out of action. There's no light head art.
/mob/living/carbon/human/proc/ms13_doll_state(obj/item/bodypart/body_part)
	if(body_part.bodypart_disabled)
		return "[body_part.body_zone]3"
	var/dam_state = (body_part.brute_dam + body_part.burn_dam) / max(1, body_part.max_damage)
	if(body_part.type in hal_screwydoll)
		dam_state = hal_screwydoll[body_part.type] * 0.2
	else if(hal_screwyhud == SCREWYHUD_HEALTHY)
		dam_state = 0
	if(dam_state > 0.5 || (dam_state && body_part.body_zone == BODY_ZONE_HEAD))
		return "[body_part.body_zone]2"
	if(dam_state)
		return "[body_part.body_zone]1"

/// MS13's mood faces, mood1 to mood9, sit on the doll's head, untinted.
/datum/mood/update_mood_icon()
	. = ..()
	if(!mood_screen_object || !mob_parent.hud_used?.contains_off_screen_hud)
		return
	mood_screen_object.icon = 'mojave/icons/hud/ms_ui_health.dmi'
	mood_screen_object.color = null
	mood_screen_object.cut_overlays()
	mood_screen_object.icon_state = "mood[mob_parent.stat == CONSCIOUS ? clamp(mood_level / 5 + 5, 1, 9) : 5]"

#ifdef UNIT_TESTS
/datum/unit_test/ms13_health_doll
	name = "HUD: MS13 Health Doll Marks Limbs By Damage"

/datum/unit_test/ms13_health_doll/Run()
	var/mob/living/carbon/human/dummy = ALLOCATE_BOTTOM_LEFT()
	var/obj/item/bodypart/chest = dummy.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/bodypart/head = dummy.get_bodypart(BODY_ZONE_HEAD)
	if(dummy.ms13_doll_state(chest))
		return Fail("An unhurt chest was marked.")
	chest.receive_damage(chest.max_damage * 0.2)
	head.receive_damage(1)
	if(dummy.ms13_doll_state(chest) != "chest1")
		return Fail("A lightly hurt chest was marked [dummy.ms13_doll_state(chest)], not chest1.")
	if(dummy.ms13_doll_state(head) != "head2")
		return Fail("A lightly hurt head was marked [dummy.ms13_doll_state(head)], not head2 (there's no head1 art).")
	chest.receive_damage(chest.max_damage * 0.5)
	if(dummy.ms13_doll_state(chest) != "chest2")
		return Fail("A badly hurt chest was marked [dummy.ms13_doll_state(chest)], not chest2.")
#endif
