/**
 * Field of vision: a mob can't see what's in the blind spot behind it. Mobs and loose items there are hidden from it,
 * and the blind spot is shaded; walls, floors and everything else stay in view.
 *
 * Mobs and loose items live on their own plane, which a viewer's field of vision masks and which is then drawn into
 * the game plane at mob layer, so whatever is drawn over mobs there (trees, roofs, door frames) still is. Sounds from
 * the blind spot show as cues instead (play_fov_effect()).
 *
 * People have a narrow blind spot of their own. Helmets and mechs can widen it, as fov traits; the widest applies.
 */

/mob
	plane = GAME_PLANE_FOV_HIDDEN

/obj/item
	plane = GAME_PLANE_FOV_HIDDEN

/atom/movable/screen/plane_master/game_world_fov_hidden
	name = "game world fov hidden plane master"
	plane = GAME_PLANE_FOV_HIDDEN
	blend_mode = BLEND_OVERLAY
	render_relay_plane = GAME_PLANE

// Only on the player's own view, not the map popups camera consoles open, which never call backdrop().
/atom/movable/screen/plane_master/game_world_fov_hidden/backdrop(mob/mymob)
	. = ..()
	relay.layer = MOB_LAYER
	add_filter("vision_cone", 1, alpha_mask_filter(render_source = FIELD_OF_VISION_BLOCKER_RENDER_TARGET, flags = MASK_INVERSE))

/atom/movable/screen/plane_master/field_of_vision_blocker
	name = "field of vision blocker plane master"
	plane = FIELD_OF_VISION_BLOCKER_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_relay_plane = null

/atom/movable/screen/plane_master/field_of_vision_blocker/backdrop(mob/mymob)
	. = ..()
	render_target = FIELD_OF_VISION_BLOCKER_RENDER_TARGET

/// What the blind spot hides.
/atom/movable/screen/fov_blocker
	icon = 'mojave/icons/effects/ms_fov.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = FIELD_OF_VISION_BLOCKER_PLANE
	screen_loc = "BOTTOM,LEFT"

/// The shade over the blind spot.
/atom/movable/screen/fov_shadow
	icon = 'mojave/icons/effects/ms_fov.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = ABOVE_LIGHTING_PLANE
	screen_loc = "BOTTOM,LEFT"

/// Masks and shades the blind spot behind a mob, on its client's screen.
/datum/component/fov_handler
	/// Currently applied size of the masks, in tiles.
	var/current_fov_x = BASE_FOV_MASK_X_DIMENSION
	var/current_fov_y = BASE_FOV_MASK_Y_DIMENSION
	var/applied_mask = FALSE
	/// How wide the blind spot is, in degrees.
	var/fov_angle
	var/atom/movable/screen/fov_blocker/blocker_mask
	var/atom/movable/screen/fov_shadow/visual_shadow
	/// How far, in pixels, something panning the view (a scope) has shifted it from the mob.
	var/view_shift_x = 0
	var/view_shift_y = 0

/datum/component/fov_handler/Initialize(fov_type = FOV_90_DEGREES)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/mob_parent = parent
	if(!mob_parent.client)
		qdel(src)
		return
	blocker_mask = new
	visual_shadow = new
	set_fov_angle(fov_type)
	on_dir_change(mob_parent, mob_parent.dir, mob_parent.dir)
	update_fov_size()
	update_mask()

/datum/component/fov_handler/Destroy()
	if(applied_mask)
		remove_mask()
	QDEL_NULL(blocker_mask)
	QDEL_NULL(visual_shadow)
	return ..()

/datum/component/fov_handler/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_dir_change))
	RegisterSignal(parent, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_MOB_RESET_PERSPECTIVE), PROC_REF(update_mask))
	RegisterSignal(parent, COMSIG_MOB_CLIENT_CHANGE_VIEW, PROC_REF(update_fov_size))
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, PROC_REF(mob_logout))

/datum/component/fov_handler/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent, list(COMSIG_ATOM_DIR_CHANGE, COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_MOB_RESET_PERSPECTIVE, COMSIG_MOB_CLIENT_CHANGE_VIEW, COMSIG_MOB_LOGOUT))

/datum/component/fov_handler/proc/set_fov_angle(new_angle)
	fov_angle = new_angle
	blocker_mask.icon_state = "[new_angle]"
	visual_shadow.icon_state = "[new_angle]_v"

/// Stretches the masks over the client's whole view.
/datum/component/fov_handler/proc/update_fov_size()
	SIGNAL_HANDLER
	var/mob/parent_mob = parent
	if(!parent_mob.client)
		return
	var/list/view_size = getviewsize(parent_mob.client.view)
	if(view_size[1] == current_fov_x && view_size[2] == current_fov_y)
		return
	current_fov_x = view_size[1]
	current_fov_y = view_size[2]
	blocker_mask.transform = mask_matrix()
	visual_shadow.transform = mask_matrix()

/// Stretches the masks over the view, kept centred on the mob wherever the view is panned.
/datum/component/fov_handler/proc/mask_matrix()
	var/matrix/new_matrix = matrix()
	new_matrix.Scale(current_fov_x / BASE_FOV_MASK_X_DIMENSION, current_fov_y / BASE_FOV_MASK_Y_DIMENSION)
	new_matrix.Translate((current_fov_x - BASE_FOV_MASK_X_DIMENSION) * 16 - view_shift_x, (current_fov_y - BASE_FOV_MASK_Y_DIMENSION) * 16 - view_shift_y)
	return new_matrix

/// The view has been panned x, y pixels from the mob, over time: the masks follow, so the blind spot stays behind it.
/datum/component/fov_handler/proc/follow_view(x, y, time)
	view_shift_x = x
	view_shift_y = y
	animate(blocker_mask, transform = mask_matrix(), time = time)
	animate(visual_shadow, transform = mask_matrix(), time = time)

// A scope pans the view toward where it's aimed.
/datum/component/scope/process(delta_time)
	. = ..()
	if(tracker)
		var/datum/component/fov_handler/fov = tracker.owner.GetComponent(/datum/component/fov_handler)
		fov?.follow_view(tracker.given_x, tracker.given_y, world.tick_lag)

/datum/component/scope/stop_zooming(mob/user)
	SIGNAL_HANDLER
	. = ..()
	var/datum/component/fov_handler/fov = user.GetComponent(/datum/component/fov_handler)
	fov?.follow_view(0, 0, 0.2 SECONDS)

/// Masks only while alive and seeing from where it is: not when dead, or looking through a camera.
/datum/component/fov_handler/proc/update_mask()
	SIGNAL_HANDLER
	var/mob/living/parent_mob = parent
	var/client/parent_client = parent_mob.client
	if(!parent_client)
		return
	var/should_apply = parent_mob.stat != DEAD && (parent_client.eye == parent_mob || parent_client.eye == get_atom_on_turf(parent_mob))
	if(should_apply == applied_mask)
		return
	if(should_apply)
		parent_client.screen += list(blocker_mask, visual_shadow)
	else
		remove_mask()
	applied_mask = should_apply

/datum/component/fov_handler/proc/remove_mask()
	var/mob/parent_mob = parent
	parent_mob.client?.screen -= list(blocker_mask, visual_shadow)
	applied_mask = FALSE

/datum/component/fov_handler/proc/on_dir_change(mob/source, old_dir, new_dir)
	SIGNAL_HANDLER
	blocker_mask.dir = new_dir
	visual_shadow.dir = new_dir

/datum/component/fov_handler/proc/mob_logout(mob/source)
	SIGNAL_HANDLER
	qdel(src)

/mob/living
	/// The blind spot straight behind it by nature, in degrees (see __DEFINES/fov.dm). Null for none.
	var/native_fov
	/// Wider blind spots from what it wears or rides in: source = degrees. The widest applies.
	var/list/fov_traits
	/// Visors it looks out through, which cost its own eyes steps along FOV_STEPS: source = steps. The most applies.
	var/list/fov_visors
	/// Sensors it sees through instead of its own eyes, like a mech's cab: the blind spot they leave, in degrees.
	var/fov_sensors
	/// The blind spot it has now.
	var/fov_view

/mob/living/carbon/human
	native_fov = FOV_90_DEGREES

/// Can this mob see observed_atom? Blindness, nearsightedness and its field of vision (fov_view) all count.
/mob/living/proc/in_fov(atom/observed_atom, ignore_self = FALSE)
	if(ignore_self && observed_atom == src)
		return TRUE
	if(is_blind())
		return FALSE
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(observed_atom)
	if(!here || !there)
		return TRUE
	var/distance = sqrt((there.x - here.x) ** 2 + (there.y - here.y) ** 2)
	if(HAS_TRAIT(src, TRAIT_NEARSIGHT) && distance > NEARSIGHTNESS_FOV_BLINDNESS)
		var/mob/living/carbon/carbon_me = src
		var/obj/item/clothing/glasses/glass = iscarbon(src) ? carbon_me.glasses : null
		if(!glass?.vision_correction)
			return FALSE
	// The tiles right around it are always in view; beyond them, the blind spot is fov_view degrees wide, straight behind.
	if(!fov_view || distance < 2)
		return TRUE
	return get_between_angles(get_angle(here, there), dir2angle(dir)) < 180 - fov_view / 2

/mob/living/proc/add_fov_trait(source, angle)
	LAZYSET(fov_traits, source, angle)
	update_fov()

/mob/living/proc/remove_fov_trait(source)
	LAZYREMOVE(fov_traits, source)
	update_fov()

/// The blind spot it has by nature, before anything it wears or rides in.
/mob/living/proc/get_native_fov()
	return native_fov

/mob/living/proc/add_fov_visor(source, steps)
	LAZYSET(fov_visors, source, steps)
	update_fov()

/mob/living/proc/remove_fov_visor(source)
	LAZYREMOVE(fov_visors, source)
	update_fov()

/// Its own view, a step narrower for each step of visor it looks out through.
/mob/living/proc/narrow_by_visors(angle)
	var/steps = 0
	for(var/source in fov_visors)
		steps = max(steps, fov_visors[source])
	if(!steps)
		return angle
	var/list/ladder = FOV_STEPS
	return ladder[clamp(ladder.Find(angle) + steps, 1, length(ladder))]

/mob/living/proc/update_fov()
	fov_view = isnull(fov_sensors) ? narrow_by_visors(get_native_fov()) : fov_sensors
	for(var/source in fov_traits)
		fov_view = max(fov_view, fov_traits[source])
	if(!client)
		return
	var/datum/component/fov_handler/handler = GetComponent(/datum/component/fov_handler)
	if(!fov_view)
		qdel(handler)
	else if(handler)
		handler.set_fov_angle(fov_view)
	else
		AddComponent(/datum/component/fov_handler, fov_view)

/mob/living/Login()
	. = ..()
	update_fov()

/obj/item/clothing
	/// Worn where it's meant to be, it narrows the wearer's view to a blind spot this wide (see __DEFINES/fov.dm).
	var/fov_angle
	/// Or a visor: it costs the wearer's own view this many steps (FOV_STEPS), so how sharp their eyes are still counts.
	var/fov_visor_steps

/obj/item/clothing/equipped(mob/living/user, slot)
	. = ..()
	if(!isliving(user) || !(slot & slot_flags))
		return
	if(fov_angle)
		user.add_fov_trait(src, fov_angle)
	if(fov_visor_steps)
		user.add_fov_visor(src, fov_visor_steps)

/obj/item/clothing/unequipped(mob/living/user)
	. = ..()
	if(!isliving(user))
		return
	if(fov_angle)
		user.remove_fov_trait(src)
	if(fov_visor_steps)
		user.remove_fov_visor(src)

#ifdef UNIT_TESTS
/// A person can't see what's straight behind them, and a helmet or visor widens the blind spot. A mech's sensors see
/// for its pilot, whoever they are. Mobs and loose items are what it hides.
/datum/unit_test/ms13_field_of_vision
	name = "FOV: People Can't See Behind Them, Less So In Helmets And Mechs"

/datum/unit_test/ms13_field_of_vision/Run()
	var/mob/living/carbon/human/viewer = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z))
	viewer.setDir(NORTH)
	var/obj/item/wrench/ahead = allocate(/obj/item/wrench, locate(viewer.x, viewer.y + 2, viewer.z))
	var/obj/item/wrench/beside = allocate(/obj/item/wrench, locate(viewer.x + 2, viewer.y, viewer.z))
	var/obj/item/wrench/behind = allocate(/obj/item/wrench, locate(viewer.x, viewer.y - 2, viewer.z))
	if(viewer.fov_view != FOV_90_DEGREES || !viewer.in_fov(ahead) || !viewer.in_fov(beside) || viewer.in_fov(behind))
		Fail("A person facing north didn't see ahead and to the side but not behind them.")
	if(viewer.plane != GAME_PLANE_FOV_HIDDEN || ahead.plane != GAME_PLANE_FOV_HIDDEN)
		Fail("Mobs and loose items aren't on the plane a field of vision hides.")

	var/obj/item/clothing/head/helmet/helmet = allocate(/obj/item/clothing/head/helmet)
	helmet.fov_angle = FOV_180_DEGREES
	viewer.equip_to_slot_or_del(helmet, ITEM_SLOT_HEAD)
	if(viewer.fov_view != FOV_180_DEGREES || viewer.in_fov(beside))
		Fail("A helmet didn't widen its wearer's blind spot.")
	viewer.dropItemToGround(helmet)
	if(viewer.fov_view != FOV_90_DEGREES)
		Fail("Taking a helmet off didn't narrow the blind spot again.")

	// A visor costs a step of the wearer's own view, so sharp eyes still see more through it.
	helmet.fov_angle = null
	helmet.fov_visor_steps = 1
	viewer.equip_to_slot_or_del(helmet, ITEM_SLOT_HEAD)
	var/average_through_visor = viewer.fov_view
	viewer.set_special_base(SPECIAL_PERCEPTION, 9)
	if(average_through_visor != FOV_120_DEGREES || viewer.fov_view != FOV_90_DEGREES)
		Fail("A visor didn't cost its wearer a step of their own view.")
	viewer.dropItemToGround(helmet)
	viewer.set_special_base(SPECIAL_PERCEPTION, 2)

	var/obj/vehicle/sealed/ms13_mech/durand/mech = allocate(/obj/vehicle/sealed/ms13_mech/durand, locate(viewer.x + 1, viewer.y, viewer.z))
	mech.setDir(EAST)
	mech.mob_enter(viewer, TRUE)
	mech.setDir(SOUTH)
	if(viewer.fov_view != mech.fov_angle || viewer.dir != SOUTH)
		Fail("A mech's sensors didn't see for its dull-eyed pilot, or it didn't face the way the mech faces.")
	mech.mob_exit(viewer, TRUE)
	if(viewer.fov_view != FOV_120_DEGREES)
		Fail("Climbing out of a mech didn't give its pilot their own eyes back.")
#endif
