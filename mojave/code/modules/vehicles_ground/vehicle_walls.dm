TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall)
	default_armor = list(BLUNT = 40, PUNCTURE = 50, SLASH = 30, LASER = 30, ENERGY = 20, BOMB = 20, BIO = 100, FIRE = 60, ACID = 40)

/**
 * One side's worth of vehicle hull - a directional/border object. Extends the game's existing window
 * type (code/game/objects/structures/window.dm) specifically for its ON_BORDER_1 + CanAllowThrough()
 * behavior: it only blocks movement and gunfire crossing the one edge of the tile it's mounted on.
 * The other 3 sides of that same tile stay completely open - this is the specific behavior that
 * made Civ13's own vehicle walls interesting rather than just a solid box, and it comes for free from
 * the same border-object pipeline every window/railing in the game already uses, armor and all.
 *
 * Icons ported from Civ13 (github.com/Civ13/Civ13, icons/obj/vehicles/vehicleparts.dmi, AGPLv3).
 */
/obj/structure/window/ms13_vehicle_wall
	name = "vehicle plating"
	desc = "A section of vehicle armor plating."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "c_wall"
	// Keep the exterior hull visible over the opaque roof shown to bystanders.
	layer = ABOVE_ALL_MOB_LAYER + 0.01
	max_integrity = 150
	fulltile = FALSE
	wtype = "metal"
	var/obj/structure/ms13_vehicle_frame/parent_frame
	/// Same vehicle-local coordinates as the frame it's mounted on - see _vehicle_base.dm's
	/// get_relative_turf().
	var/forward_offset = 0
	var/right_offset = 0
	/// This wall's own facing, as a fixed angle offset from the vehicle's forward dir (e.g. 0 for the
	/// front wall, 90/270 for the sides) - set once at spawn_wall() and never changes, so turning just
	/// re-applies turn(new_dir, relative_turn) to get this wall's new absolute facing.
	var/relative_turn = 0

/obj/structure/window/ms13_vehicle_wall/Destroy()
	parent_frame?.vehicle?.walls -= src
	parent_frame = null
	return ..()

/**
 * A solid hull panel instead of a see-through pane. It keeps the border-object mechanic for movement
 * and gunfire; its exterior sight blocker handles BYOND's non-directional opacity without placing
 * blackness inside the vehicle. The frame roof supplies top-down cover for outside viewers.
 */
/obj/structure/window/ms13_vehicle_wall/solid
	name = "vehicle hull plating"
	desc = "A solid section of vehicle armor plating."
	icon_state = "c_armoredwall"
	opacity = TRUE
	var/obj/effect/ms13_vehicle_sight_blocker/sight_blocker

/obj/structure/window/ms13_vehicle_wall/solid/Initialize(mapload, direct)
	. = ..()
	sight_blocker = new(get_step(src, dir))

/obj/structure/window/ms13_vehicle_wall/solid/Destroy()
	QDEL_NULL(sight_blocker)
	return ..()

/obj/structure/window/ms13_vehicle_wall/solid/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	update_sight_blocker()

/obj/structure/window/ms13_vehicle_wall/solid/setDir(new_dir)
	. = ..()
	update_sight_blocker()

/obj/structure/window/ms13_vehicle_wall/solid/set_opacity(new_opacity)
	. = ..()
	if(sight_blocker)
		sight_blocker.set_opacity(opacity)

/// BYOND ignores opacity on the viewer's own tile. Keep the sight boundary immediately outside
/// the hull instead, where it can occlude the exterior without blacking out a vehicle frame.
/obj/structure/window/ms13_vehicle_wall/solid/proc/update_sight_blocker()
	if(sight_blocker)
		sight_blocker.forceMove(get_step(src, dir))

/obj/effect/ms13_vehicle_sight_blocker
	name = ""
	anchored = TRUE
	opacity = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/**
 * A manually-operated door mounted in place of a hull panel - same border mechanic as the rest of the
 * hull, just with a toggleable density/opacity so it can actually be walked through. Left-click toggles
 * it open/closed (matching the base window's own attack_hand() combat_mode split - a combat-mode click
 * still bashes it like any other wall instead of opening it).
 */
/obj/structure/window/ms13_vehicle_wall/solid/door
	name = "vehicle door"
	desc = "A hinged section of the vehicle's hull. Click to open or close it."
	icon_state = "c_door"
	/// Icon state to show while open - c_thin is the closest thing this sheet has to an empty doorway.
	var/open_icon_state = "c_thin"
	var/opened = FALSE

/obj/structure/window/ms13_vehicle_wall/solid/door/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	toggle(user)
	return TRUE

/obj/structure/window/ms13_vehicle_wall/solid/door/proc/toggle(mob/user)
	if(opened)
		close(user)
	else
		open(user)

/obj/structure/window/ms13_vehicle_wall/solid/door/proc/open(mob/user)
	if(opened)
		return
	opened = TRUE
	set_density(FALSE)
	set_opacity(FALSE)
	icon_state = open_icon_state
	if(user)
		user.visible_message(span_notice("[user] opens [src]."), span_notice("You open [src]."))
	playsound(src, 'sound/machines/door_open.ogg', 50, TRUE)

/obj/structure/window/ms13_vehicle_wall/solid/door/proc/close(mob/user)
	if(!opened)
		return
	opened = FALSE
	set_density(TRUE)
	set_opacity(TRUE)
	icon_state = initial(icon_state)
	if(user)
		user.visible_message(span_notice("[user] closes [src]."), span_notice("You close [src]."))
	playsound(src, 'sound/machines/door_close.ogg', 50, TRUE)
