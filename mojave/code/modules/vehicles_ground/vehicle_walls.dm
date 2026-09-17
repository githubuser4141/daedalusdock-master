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
	/// Below this share of integrity the wall is holed (see atom_break()); it is only destroyed at 0.
	integrity_failure = 0.35
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
	/// Solid panels and closed shutters use this logical boundary instead of tile-wide opacity.
	var/blocks_vision = FALSE
	/// Keeps outside light out even while see-through, like a narrow periscope block.
	var/light_proof = FALSE
	/// A see-through wall only lets you see out from within this many tiles of it. Null: from anywhere aboard.
	var/vision_range
	/// Part of the outer hull. Interior bulkheads don't mark the roof as damaged.
	var/exterior = TRUE
	/// Holed by damage but still standing: most of its armor is gone and it no longer blocks sight or light.
	var/hull_broken = FALSE
	/// Share of its armor a holed wall keeps. Bullet stopping power follows armor, so rounds get through.
	var/broken_armor_mult = 0.15
	/// Damaged art, used when it has a match for this wall's icon_state.
	var/broken_icon = 'mojave/icons/objects/vehicles_ground/vehicleparts_damaged.dmi'
	/// Drawn over walls with no damaged art of their own.
	var/broken_fallback_state = "c_window"
	var/datum/armor/intact_armor

/obj/structure/window/ms13_vehicle_wall/proc/blocks_sight()
	return blocks_vision && !hull_broken

/obj/structure/window/ms13_vehicle_wall/proc/blocks_light()
	return (blocks_vision || light_proof) && !hull_broken

/obj/structure/window/ms13_vehicle_wall/atom_break(damage_flag)
	. = ..()
	if(hull_broken)
		return
	hull_broken = TRUE
	intact_armor = returnArmor()
	setArmor(getArmor(
		intact_armor.blunt * broken_armor_mult,
		intact_armor.puncture * broken_armor_mult,
		intact_armor.slash * broken_armor_mult,
		intact_armor.laser * broken_armor_mult,
		intact_armor.energy * broken_armor_mult,
		intact_armor.bomb * broken_armor_mult,
		intact_armor.bio,
		intact_armor.fire * broken_armor_mult,
		intact_armor.acid * broken_armor_mult,
	))
	visible_message(span_warning("[src] buckles and tears open!"))
	update_appearance()
	parent_frame?.vehicle?.update_interior_masks()

/obj/structure/window/ms13_vehicle_wall/atom_fix()
	. = ..()
	if(!hull_broken)
		return
	hull_broken = FALSE
	setArmor(intact_armor)
	intact_armor = null
	update_appearance()
	parent_frame?.vehicle?.update_interior_masks()

/// Window welding sets integrity directly, which never un-breaks anything.
/obj/structure/window/ms13_vehicle_wall/welder_act(mob/living/user, obj/item/tool)
	. = ..()
	if(hull_broken && !is_broken())
		atom_fix()

/obj/structure/window/ms13_vehicle_wall/update_icon_state()
	. = ..()
	icon = has_broken_art() ? broken_icon : initial(icon)

/obj/structure/window/ms13_vehicle_wall/update_overlays()
	. = ..()
	if(hull_broken && !has_broken_art())
		var/mutable_appearance/damage = mutable_appearance(broken_icon, broken_fallback_state, layer)
		damage.dir = dir
		. += damage

/obj/structure/window/ms13_vehicle_wall/setDir(new_dir)
	. = ..()
	if(hull_broken)
		update_appearance()

/obj/structure/window/ms13_vehicle_wall/proc/has_broken_art()
	if(!hull_broken || !broken_icon)
		return FALSE
	return ms13_icon_has_state(broken_icon, icon_state)

/// Cached icon_states() lookup.
/proc/ms13_icon_has_state(icon_file, state)
	var/static/list/states_by_icon = list()
	var/list/states = states_by_icon["[icon_file]"]
	if(!states)
		states = states_by_icon["[icon_file]"] = icon_states(icon_file)
	return state in states

/obj/structure/window/ms13_vehicle_wall/proc/finish_mount()
	return

/obj/structure/window/ms13_vehicle_wall/update_integrity(new_value, damage_flag = NONE, allow_break = TRUE)
	. = ..()
	if(exterior)
		parent_frame?.update_roof_damage()

/obj/structure/window/ms13_vehicle_wall/Destroy()
	var/datum/ms13_ground_vehicle/vehicle = parent_frame?.vehicle
	if(parent_frame && exterior)
		parent_frame.roof_hull_breached = TRUE
		parent_frame.update_roof_damage()
	vehicle?.walls -= src
	vehicle?.update_interior_masks()
	parent_frame = null
	return ..()

/**
 * A solid hull panel instead of a see-through pane. It keeps the border-object mechanic for movement
 * and gunfire. Interior clients mask sight rays which cross this boundary; native opacity cannot be
 * used because BYOND applies it to the whole frame tile. The frame roof covers outside viewers.
 */
/obj/structure/window/ms13_vehicle_wall/solid
	name = "vehicle hull plating"
	desc = "A solid section of vehicle armor plating."
	icon_state = "c_armoredwall"
	blocks_vision = TRUE
	bullet_damage_ratio = 0.3
	broken_fallback_state = "c_armoredwall"

/**
 * A bulkhead between two cabin tiles. Sits under the roof so outsiders never see it, and doesn't count
 * toward hull damage on the roof art.
 */
/obj/structure/window/ms13_vehicle_wall/solid/interior
	name = "bulkhead"
	desc = "A thin steel partition inside the vehicle."
	icon_state = "c_thin"
	layer = ABOVE_MOB_LAYER
	max_integrity = 200
	exterior = FALSE

/** A cabin access panel, e.g. into the engine bay. */
/obj/structure/window/ms13_vehicle_wall/solid/door/interior
	name = "access panel"
	desc = "A bolted panel between compartments. Click to open or close it."
	icon_state = "c_door"
	open_icon_state = "c_thin"
	layer = ABOVE_MOB_LAYER
	max_integrity = 200
	exterior = FALSE

/** A window with manually-operated armored shutters. It remains a normal window while open. */
/obj/structure/window/ms13_vehicle_wall/shuttered
	name = "shuttered vehicle window"
	desc = "A vehicle window fitted with sliding armored shutters. Click to open or close them."
	var/shutters_closed = FALSE
	var/open_icon_state
	var/closed_icon_state = "c_armoredwall"

/obj/structure/window/ms13_vehicle_wall/shuttered/finish_mount()
	open_icon_state = icon_state

/obj/structure/window/ms13_vehicle_wall/shuttered/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	shutters_closed = !shutters_closed
	blocks_vision = shutters_closed
	icon_state = shutters_closed ? closed_icon_state : open_icon_state
	update_appearance()
	parent_frame?.vehicle?.update_interior_masks()
	var/third_person_action = shutters_closed ? "closes" : "opens"
	var/second_person_action = shutters_closed ? "close" : "open"
	user.visible_message(span_notice("[user] [third_person_action] [src]'s shutters."), span_notice("You [second_person_action] [src]'s shutters."))
	playsound(src, 'sound/machines/door_open.ogg', 35, TRUE)
	return TRUE

/**
 * A manually-operated door mounted in place of a hull panel - same border mechanic as the rest of the
 * hull, just with toggleable density/vision blocking so it can actually be walked through. Left-click toggles
 * it open/closed (matching the base window's own attack_hand() combat_mode split - a combat-mode click
 * still bashes it like any other wall instead of opening it).
 */
/obj/structure/window/ms13_vehicle_wall/solid/door
	name = "vehicle door"
	desc = "A hinged section of the vehicle's hull. Click to open or close it."
	icon_state = "c_door"
	/// Icon state to show while open - c_thin is the closest thing this sheet has to an empty doorway.
	/// Null keeps the closed art.
	var/open_icon_state = "c_thin"
	var/closed_icon_state
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

/obj/structure/window/ms13_vehicle_wall/solid/door/finish_mount()
	closed_icon_state = icon_state

/obj/structure/window/ms13_vehicle_wall/solid/door/proc/open(mob/user)
	if(opened)
		return
	opened = TRUE
	set_density(FALSE)
	blocks_vision = FALSE
	icon_state = open_icon_state || closed_icon_state
	update_appearance()
	parent_frame?.vehicle?.update_interior_masks()
	if(user)
		user.visible_message(span_notice("[user] opens [src]."), span_notice("You open [src]."))
	playsound(src, 'sound/machines/door_open.ogg', 50, TRUE)

/obj/structure/window/ms13_vehicle_wall/solid/door/proc/close(mob/user)
	if(!opened)
		return
	opened = FALSE
	set_density(TRUE)
	blocks_vision = TRUE
	icon_state = closed_icon_state
	update_appearance()
	parent_frame?.vehicle?.update_interior_masks()
	if(user)
		user.visible_message(span_notice("[user] closes [src]."), span_notice("You close [src]."))
	playsound(src, 'sound/machines/door_close.ogg', 50, TRUE)

// Civ13 96x96 hull plating (soviet_vehicles.dm). The art is drawn centered on its tile and has damaged
// counterparts under the same names.

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/civ96) // mt lb armor
	default_armor = list(BLUNT = 50, PUNCTURE = 65, SLASH = 75, LASER = 50, ENERGY = 40, BOMB = 30, BIO = 100, FIRE = 60, ACID = 50)

/// A vision block or firing port: you only see out with your face to it, and it lets almost no light in.
/obj/structure/window/ms13_vehicle_wall/civ96
	name = "vision port"
	desc = "A thick armored vision block."
	icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96.dmi'
	broken_icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96_damaged.dmi'
	pixel_x = -32
	pixel_y = -32
	max_integrity = 500
	light_proof = TRUE
	vision_range = 1
	bullet_damage_ratio = 0.3

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/civ96) // mt lb armor
	default_armor = list(BLUNT = 50, PUNCTURE = 65, SLASH = 75, LASER = 70, ENERGY = 50, BOMB = 40, BIO = 100, FIRE = 60, ACID = 60)

/// Light armor: stops rifle rounds, not heavy machine guns.
/obj/structure/window/ms13_vehicle_wall/solid/civ96
	name = "armor plating"
	icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96.dmi'
	broken_icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96_damaged.dmi'
	pixel_x = -32
	pixel_y = -32
	max_integrity = 1000
	bullet_damage_ratio = 0.25

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/civ96/tank)
	default_armor = list(BLUNT = 95, PUNCTURE = 900, SLASH = 100, LASER = 90, ENERGY = 70, BOMB = 70, BIO = 100, FIRE = 80, ACID = 80)

/// Tank armor: PUNCTURE 900 stops every round in the game, up to a gauss slug, but hits still wear it down.
/obj/structure/window/ms13_vehicle_wall/solid/civ96/tank
	name = "tank armor"
	max_integrity = 3000
	bullet_damage_ratio = 0.05

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/door/civ96) // mt lb armor
	default_armor = list(BLUNT = 50, PUNCTURE = 65, SLASH = 75, LASER = 70, ENERGY = 50, BOMB = 40, BIO = 100, FIRE = 60, ACID = 60)

/// A hull hatch. Keeps its art while open, drawn faint so it's still there to click shut.
/obj/structure/window/ms13_vehicle_wall/solid/door/civ96
	name = "hatch"
	desc = "A heavy armored hatch. Click to open or close it."
	icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96.dmi'
	broken_icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96_damaged.dmi'
	pixel_x = -32
	pixel_y = -32
	open_icon_state = null
	max_integrity = 900
	bullet_damage_ratio = 0.25

/obj/structure/window/ms13_vehicle_wall/solid/door/civ96/open(mob/user)
	. = ..()
	alpha = opened ? 90 : 255

/obj/structure/window/ms13_vehicle_wall/solid/door/civ96/close(mob/user)
	. = ..()
	alpha = opened ? 90 : 255

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank)
	default_armor = list(BLUNT = 95, PUNCTURE = 900, SLASH = 100, LASER = 90, ENERGY = 70, BOMB = 70, BIO = 100, FIRE = 80, ACID = 80)

/obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank
	max_integrity = 2000
	bullet_damage_ratio = 0.05
