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
	if(contains_off_screen_hud && action_intent)
		action_intent.screen_loc = ui_combat_toggle
	reorganize_alert_texts(screenmob)
	if(screenmob?.client)
		INVOKE_ASYNC(screenmob.client, TYPE_PROC_REF(/client, setHudBarVisible), src)

/// MS13's hands: their own art, side by side at the bottom centre.
/datum/hud/build_hand_slots()
	. = ..()
	if(!contains_off_screen_hud)
		return
	for(var/index in hand_slots)
		var/atom/movable/screen/inventory/hand/hand_box = hand_slots[index]
		hand_box.cut_overlays() // Clear old icon-state overlays before changing their icon file.
		hand_box.managed_overlays = null
		hand_box.icon = 'mojave/icons/hud/ms_ui_slots_hands.dmi'
		var/hand_index = text2num(index)
		hand_box.icon_state = "[mymob.held_index_to_dir(hand_index)]hand"
		hand_box.screen_loc = "CENTER:[hand_index % 2 ? 2 : -44],BOTTOM+[round((hand_index - 1) / 2)]"
		hand_box.update_appearance()

/// Observers display their target's HUD. show_hud supplies it before observetarget is assigned.
/mob/proc/ms13_hud_width(datum/hud/displayed_hud)
	if(!displayed_hud)
		displayed_hud = hud_used
		if(isobserver(src))
			var/mob/dead/observer/observer = src
			displayed_hud = observer.observetarget?.hud_used || displayed_hud
	return displayed_hud?.contains_off_screen_hud && displayed_hud.hud_version != HUD_STYLE_NOHUD ? HUD_WIDTH : 0

/// Gives the displayed HUD its share of the window.
/client/proc/setHudBarVisible(datum/hud/displayed_hud)
	var/panel_width = mob?.ms13_hud_width(displayed_hud) || 0
	var/list/screen_size = splittext(winget(src, "mapwindow", "size"), "x")
	if(length(screen_size) != 2)
		return
	var/screen_width = text2num(screen_size[1])
	if(screen_width <= 0)
		return
	var/tile_width = screen_width / (getviewsize(view)[1] + panel_width)
	var/hud_width = round(panel_width * tile_width)
	if(panel_width)
		winset(src, "mapwindow.map", "pos=[hud_width],0;size=[screen_width - hud_width]x[screen_size[2]];anchor1=[100 * hud_width / screen_width],0")
	else
		winset(src, "mapwindow.map", "pos=0,0;size=[screen_width]x[screen_size[2]];anchor1=0,0")
	// Left shown even when unused, or it leaves a blank block.
	winset(src, "mapwindow.hud", "size=[hud_width]x[screen_size[2]];anchor2=[100 * hud_width / screen_width],100;zoom=0;letterbox=true")

/client/set_right_click_menu_mode(shift_only)
	. = ..()
	winset(src, "mapwindow.hud", "right-click=[shift_only ? "true" : "false"]")

// The 96x480 panel must fit its own control even when the player zooms into the world.
/datum/view_data/assertFormat()
	. = ..()
	winset(chief, "mapwindow.hud", "zoom=0;letterbox=true")

/datum/view_data/resetFormat()
	. = ..()
	winset(chief, "mapwindow.hud", "zoom=0;letterbox=true")

/datum/view_data/setZoomMode()
	. = ..()
	winset(chief, "mapwindow.hud", "zoom-mode=[chief?.prefs.read_preference(/datum/preference/choiced/scaling_method)]")

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
		new_overlays += image(healthdoll.icon, zone == BODY_ZONE_HEAD ? "head2" : "[zone]3")
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
		return body_part.body_zone == BODY_ZONE_HEAD ? "head2" : "[body_part.body_zone]3"
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
	head.bodypart_disabled = TRUE
	if(dummy.ms13_doll_state(head) != "head2")
		return Fail("A disabled head has no visible damage mark.")
	var/list/states = icon_states('mojave/icons/hud/ms_ui_health.dmi')
	for(var/obj/item/bodypart/body_part as anything in dummy.bodyparts)
		body_part.bodypart_disabled = TRUE
		if(!(dummy.ms13_doll_state(body_part) in states))
			return Fail("Disabled [body_part.body_zone] uses missing HUD art.")

// No client rendering is needed to check which HUD supplies the panel width.
/datum/hud/ms13_viewport_test/New(mob/owner)
	mymob = owner
	ui_style = ui_style2icon(null)

/datum/unit_test/ms13_hud_viewport
	name = "HUD: Side Panel Follows Displayed HUD"

/datum/unit_test/ms13_hud_viewport/Run()
	var/mob/living/carbon/human/dummy = ALLOCATE_BOTTOM_LEFT()
	var/mob/dead/observer/observer = ALLOCATE_BOTTOM_LEFT()
	dummy.hud_used = allocate(/datum/hud/ms13_viewport_test, dummy)
	observer.hud_used = allocate(/datum/hud/ms13_viewport_test, observer)
	dummy.hud_used.contains_off_screen_hud = TRUE
	if(dummy.ms13_hud_width() != HUD_WIDTH || observer.ms13_hud_width())
		return Fail("A normal player's or ghost's panel width is wrong.")
	if(observer.ms13_hud_width(dummy.hud_used) != HUD_WIDTH)
		return Fail("Entering observation does not reserve the target's panel.")
	observer.observetarget = dummy
	if(observer.ms13_hud_width() != HUD_WIDTH)
		return Fail("Resizing while observing loses the target's panel.")
	dummy.hud_used.hud_version = HUD_STYLE_NOHUD
	if(dummy.ms13_hud_width() || observer.ms13_hud_width())
		return Fail("A hidden HUD still reserves panel space.")
	dummy.hud_used.hud_version = HUD_STYLE_STANDARD
	observer.observetarget = null
	if(observer.ms13_hud_width())
		return Fail("Leaving observation keeps the target's panel.")

/datum/unit_test/ms13_hud_controls
	name = "HUD: MS13 Controls Match Their Sprites And Hit Regions"

/datum/unit_test/ms13_hud_controls/Run()
	var/atom/movable/screen/ms13/button_background/canvas = allocate(/atom/movable/screen/ms13/button_background)
	var/icon/canvas_icon = icon(canvas.icon, canvas.icon_state)
	if(canvas_icon.Width() != HUD_WIDTH * world.icon_size || canvas_icon.Height() != 480 || (canvas.appearance_flags & TILE_BOUND))
		return Fail("The side panel must contribute its full 96x480 canvas to auto-fit bounds.")
	var/mob/living/carbon/human/dummy = ALLOCATE_BOTTOM_LEFT()
	var/datum/hud/hud = allocate(/datum/hud/ms13_viewport_test, dummy)
	dummy.hud_used = hud
	hud.contains_off_screen_hud = TRUE
	var/atom/movable/screen/craft/craft = allocate(/atom/movable/screen/craft, null, hud)
	if(craft.screen_loc != "hud:EAST:2,SOUTH:444")
		return Fail("Crafting was not attached to the MS13 header.")
	var/atom/movable/screen/ms13/header_background/header = allocate(/atom/movable/screen/ms13/header_background, null, hud)
	if(!icon_exists(header.icon, header.icon_state) || header.mouse_opacity != MOUSE_OPACITY_TRANSPARENT)
		return Fail("The header background is missing or blocks its controls.")
	hud.build_hand_slots()
	for(var/index in hud.hand_slots)
		var/atom/movable/screen/inventory/hand/hand = hud.hand_slots[index]
		if(!icon_exists(hand.icon, hand.icon_state))
			return Fail("Hand [index] uses missing state [hand.icon_state].")
		dummy.active_hand_index = text2num(index)
		for(var/overlay in hand.update_overlays())
			if(istext(overlay) && !icon_exists(hand.icon, overlay))
				return Fail("Hand [index] uses missing overlay [overlay].")
		if(!findtext(hand.screen_loc, "BOTTOM"))
			return Fail("Hand [index] follows the cropped map edge instead of the control.")
	var/atom/movable/screen/combattoggle/ms13/combat = allocate(/atom/movable/screen/combattoggle/ms13, null, hud)
	for(var/enabled in list(FALSE, TRUE))
		dummy.set_combat_mode(enabled)
		combat.update_appearance()
		if(combat.icon_state != (enabled ? "combat" : "combat_off") || !icon_exists(combat.icon, combat.icon_state))
			return Fail("Combat mode [enabled] has no matching button art.")
	var/atom/movable/screen/zone_sel/ms13/selector = allocate(/atom/movable/screen/zone_sel/ms13, null, hud)
	var/list/samples = list(
		BODY_ZONE_HEAD = list(49, 77),
		BODY_ZONE_PRECISE_EYES = list(47, 75),
		BODY_ZONE_PRECISE_MOUTH = list(49, 72),
		BODY_ZONE_CHEST = list(49, 60),
		BODY_ZONE_PRECISE_GROIN = list(49, 45),
		BODY_ZONE_R_ARM = list(38, 55),
		BODY_ZONE_L_ARM = list(60, 55),
		BODY_ZONE_R_LEG = list(42, 25),
		BODY_ZONE_L_LEG = list(55, 25),
	)
	for(var/zone in samples)
		var/list/point = samples[zone]
		var/choice = selector.get_zone_at(point[1], point[2])
		selector.set_selected_zone(choice, dummy)
		if(choice != zone || dummy.zone_selected != zone)
			return Fail("Clicking the MS13 [zone] region selects [choice].")
	selector.MouseMove(null, null, "icon-x=49;icon-y=60")
	var/obj/effect/overlay/zone_sel/highlight = locate() in selector.vis_contents
	if(!highlight || highlight.icon != selector.icon || highlight.icon_state != BODY_ZONE_CHEST)
		return Fail("Hovering the MS13 doll uses the wrong highlight art.")
	var/atom/movable/screen/zone_sel/legacy = allocate(/atom/movable/screen/zone_sel, null, hud)
	legacy.MouseMove(null, null, "icon-x=16;icon-y=18")
	var/obj/effect/overlay/zone_sel/legacy_highlight = locate() in legacy.vis_contents
	if(!legacy_highlight || legacy_highlight == highlight || legacy_highlight.icon != legacy.overlay_icon)
		return Fail("MS13 hover art leaked into the original selector.")
	selector.MouseMove(null, null, "icon-x=1;icon-y=1")
	if(length(selector.vis_contents))
		return Fail("Moving off the doll leaves a hover highlight behind.")
#endif
