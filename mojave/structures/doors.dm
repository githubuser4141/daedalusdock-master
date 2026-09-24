TYPEINFO_DEF(/obj/machinery/door/unpowered/ms13)
	default_armor = list(BLUNT = 40, PUNCTURE = 20, SLASH = 40, LASER = 90, ENERGY = 40, BOMB = 30, BIO = 100, FIRE = 50, ACID = 100)

/obj/machinery/door/unpowered/ms13
	icon = 'mojave/icons/structure/doors.dmi'
	name = "base state ms13 door"
	pixel_x = -16
	pixel_y = -8
	layer = ABOVE_MOB_LAYER
	density = TRUE
	assemblytype = null
	can_crush = FALSE
	spark_system = null
	max_integrity = 1150
	damage_deflection = 15
	ms13_flags_1 = LOCKABLE_1
	// AI EDIT: sparks and safe were never declared anywhere - added here (sparks was previously just dropped on
	// the floor as an invalid assignment; safe gates a get_turf() crush-check in close() below)
	var/sparks = FALSE
	var/safe = TRUE
	var/door_type = null
	var/solidity = SOLID
	var/frametype = "metal"
	var/opensound = 'sound/machines/door_open.ogg'
	var/closesound = 'sound/machines/door_close.ogg'
	//used for attack checks
	var/open = FALSE
	//used for damage overlays
	var/has_damage_overlay = TRUE
	//used for mirrored overlays
	var/mirrored = FALSE
	/// Fitted with a door motor: it opens itself off the cable knotted under it, and has a wire panel.
	var/motorised = FALSE
	/// The motor's bolts are thrown: it won't move, by motor or by hand.
	var/bolted = FALSE

/obj/machinery/door/unpowered/ms13/Initialize(mapload)
	. = ..()
	align_to_dir()
	if(mapload)
		. = roll_for_roundstart_lock() || .

/obj/machinery/door/unpowered/ms13/setDir(newdir)
	. = ..()
	align_to_dir()

/// Sits the sprite on its tile for the way the door faces.
/obj/machinery/door/unpowered/ms13/proc/align_to_dir()
	switch(dir)
		if(NORTH)
			pixel_x = -16
			pixel_y = 8
		if(SOUTH)
			pixel_x = -16
			pixel_y = -8
		if(EAST)
			pixel_x = -3
			pixel_y = 16
		if(WEST)
			pixel_x = -28
			pixel_y = 16
	update_appearance()

/// Chance for a mapped-in door to start locked with a lockpickable difficulty, and a matching key
/// placed somewhere nearby as an alternative to picking it. Key placement itself happens in
/// LateInitialize (see place_roundstart_key_nearby() in keys.dm) since it can land on another mob
/// or inside another structure's storage, and those need to already exist.
#define DOOR_ROUNDSTART_LOCK_CHANCE 20
/obj/machinery/door/unpowered/ms13/proc/roll_for_roundstart_lock()
	if(!(ms13_flags_1 & LOCKABLE_1))
		return
	if(!prob(DOOR_ROUNDSTART_LOCK_CHANCE))
		return

	// Matches the manual flow (obj_defines.dm's attack_hand_secondary "Lock It") - a real padlock object
	// attached to the door, closed and clasped shut, rather than an invisible lock state.
	var/obj/item/ms13/lock/new_lock = new(src)
	new_lock.lock_difficulty = rand(10, 17)
	new_lock.item_lock_locked = TRUE
	lock = new_lock
	AddElement(/datum/element/lockpickable, difficulty = new_lock.lock_difficulty)
	update_appearance()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/door/unpowered/ms13/LateInitialize()
	. = ..()
	if(!lock)
		return
	var/obj/item/ms13/key/door/new_key = new
	new_key.matching_door = WEAKREF(src)
	place_roundstart_key_nearby(new_key, src)

/obj/machinery/door/unpowered/ms13/update_overlays()
	. = ..()

	cut_overlays()

	if(dir == EAST)
		add_overlay(image(icon,icon_state="[frametype]_frame_vertical_overlay", layer = ABOVE_ALL_MOB_LAYER))

	if(dir == WEST)
		add_overlay(image(icon,icon_state="[frametype]_frame_vertical_overlay", layer = ABOVE_ALL_MOB_LAYER))

	if(has_damage_overlay) //stunning code, code of the year
		switch(open)
			if(TRUE)
				switch(mirrored)
					if(TRUE)
						switch(dir)
							if(EAST)
								if(atom_integrity < (0.25 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_3", layer = FLOAT_LAYER, pixel_x = 17, pixel_y = -2))
								else if(atom_integrity < (0.50 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_2", layer = FLOAT_LAYER, pixel_x = 17, pixel_y = -2))
								else if(atom_integrity < (0.75 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_1", layer = FLOAT_LAYER, pixel_x = 17, pixel_y = -2))
							if(WEST)
								if(atom_integrity < (0.25 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_3", layer = FLOAT_LAYER, pixel_x = -17, pixel_y = -2))
								else if(atom_integrity < (0.50 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_2", layer = FLOAT_LAYER, pixel_x = -17, pixel_y = -2))
								else if(atom_integrity < (0.75 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_1", layer = FLOAT_LAYER, pixel_x = -17, pixel_y = -2))
					if(FALSE)
						switch(dir)
							if(EAST)
								if(atom_integrity < (0.25 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_3", layer = FLOAT_LAYER, pixel_x = -17, pixel_y = -2))
								else if(atom_integrity < (0.50 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_2", layer = FLOAT_LAYER, pixel_x = -17, pixel_y = -2))
								else if(atom_integrity < (0.75 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_1", layer = FLOAT_LAYER, pixel_x = -17, pixel_y = -2))
							if(WEST)
								if(atom_integrity < (0.25 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_3", layer = FLOAT_LAYER, pixel_x = 17, pixel_y = -2))
								else if(atom_integrity < (0.50 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_2", layer = FLOAT_LAYER, pixel_x = 17, pixel_y = -2))
								else if(atom_integrity < (0.75 * max_integrity))
									cut_overlays()
									add_overlay(image(icon, icon_state = "damage_closed_1", layer = FLOAT_LAYER, pixel_x = 17, pixel_y = -2))
			if(FALSE)
				switch(dir)
					if(NORTH)
						if(atom_integrity < (0.25 * max_integrity))
							cut_overlays()
							add_overlay(image(icon, icon_state = "damage_closed_3", layer = FLOAT_LAYER, pixel_y = -8))
						else if(atom_integrity < (0.50 * max_integrity))
							cut_overlays()
							add_overlay(image(icon, icon_state = "damage_closed_2", layer = FLOAT_LAYER, pixel_y = -8))
						else if(atom_integrity < (0.75 * max_integrity))
							cut_overlays()
							add_overlay(image(icon, icon_state = "damage_closed_1", layer = FLOAT_LAYER, pixel_y = -8))
					if(SOUTH)
						if(atom_integrity < (0.25 * max_integrity))
							cut_overlays()
							add_overlay(image(icon, icon_state = "damage_closed_3", layer = FLOAT_LAYER))
						else if(atom_integrity < (0.50 * max_integrity))
							cut_overlays()
							add_overlay(image(icon, icon_state = "damage_closed_2", layer = FLOAT_LAYER))
						else if(atom_integrity < (0.75 * max_integrity))
							cut_overlays()
							add_overlay(image(icon, icon_state = "damage_closed_1", layer = FLOAT_LAYER))


/obj/machinery/door/unpowered/ms13/open()
	if(!density)
		return TRUE
	if(operating)
		return
	operating = TRUE
	set_opacity(0)
	set_density(FALSE)
	flags_1 &= ~PREVENT_CLICK_UNDER_1
	open = TRUE
	update_appearance()
	set_opacity(0)
	operating = FALSE
	var/turf/T = get_turf(src)
	if(T)
		T.update_air_properties()
	update_freelook_sight()
	playsound(src, (opensound), 50, TRUE)
	return TRUE

/obj/machinery/door/unpowered/ms13/close()
	if(density)
		return TRUE
	if(operating)
		return
	if(safe)
		for(var/atom/movable/M in get_turf(src))
			if(M.density && M != src) //something is blocking the door
				return
	operating = TRUE
	set_density(TRUE)
	flags_1 |= PREVENT_CLICK_UNDER_1
	open = FALSE
	update_appearance()
	if(visible && !glass)
		set_opacity(1)
	operating = FALSE
	var/turf/T = get_turf(src)
	if(T)
		T.update_air_properties()
	update_freelook_sight()
	playsound(src, (closesound), 50, TRUE)
	return TRUE

/obj/machinery/door/unpowered/ms13/update_appearance(updates)
	. = ..()
	if(density)
		icon_state = "[door_type]_closed"
	else
		icon_state = "[door_type]_open"

/obj/machinery/door/unpowered/ms13/try_to_activate_door(mob/living/M)
	// Called both from attack_hand() below (already lock-checked there) and from the core
	// /obj/machinery/door/attackby() chain (code/game/machinery/doors/door.dm) when attacked with an
	// item in hand - that path had no lock check at all, so holding literally any item and clicking a
	// locked door bypassed both lock types entirely instead of falling through to the key/lock_group
	// handling in /obj/attackby() (mojave/code/modules/locks/obj_defines.dm).
	if(locked || (ms13_flags_1 & LOCKABLE_1 && lock_locked))
		to_chat(M, span_warning("The [name] is locked."))
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return FALSE
	if(bolted)
		to_chat(M, span_warning("[src]'s bolts are down. It won't budge."))
		return FALSE
	add_fingerprint(M)
	if(density)
		open()
	else
		close()
	return TRUE

// Punching a closed door in combat mode, locked or not, goes through the shared punch (punching.dm).
/obj/machinery/door/unpowered/ms13/attack_hand(mob/living/M)
	if(locked)
		to_chat(M, "<span class='warning'> The [name] is locked.</span>")
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return
	if(.)
		return
	if(ms13_flags_1 & LOCKABLE_1 && lock_locked)
		to_chat(M, span_warning("The [name] is locked."))
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return
	if(!bolted && run_motor())
		add_fingerprint(M)
		return
	// A dead motor's gearing drags: it takes a good haul to move by hand.
	if(do_after(M, time = motorised ? 3 SECONDS : 1 SECONDS, interaction_key = DOAFTER_SOURCE_DOORS))
		try_to_activate_door(M)

/obj/machinery/door/unpowered/ms13/attackby(obj/item/I, mob/living/M, params)
	. = ..()
	if(locked && !(M.combat_mode))
		to_chat(M, "<span class='warning'> The [name] is locked.</span>")
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return
	if(ms13_flags_1 & LOCKABLE_1 && lock_locked && !(M.combat_mode))
		to_chat(M, span_warning("The [name] is locked."))
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return
	if(!(I.item_flags & NOBLUDGEON || LOCKING_ITEM) && !(M.combat_mode) && do_after(M, time = 1.5 SECONDS, interaction_key = DOAFTER_SOURCE_DOORS))
		open = TRUE
		try_to_activate_door(M)
		return TRUE
	if(!open)
		update_appearance()
		// AI EDIT: attack_atom doesn't exist in DD - the atom-side equivalent is attacked_by(), called on the target
		return ((obj_flags & CAN_BE_HIT) && attacked_by(I, M))

/obj/machinery/door/unpowered/ms13/do_animate(animation)
	return

// AI EDIT: Bumped() doesn't exist in DD - renamed to BumpedBy() (code/game/atom/atoms.dm), same single-arg signature
/obj/machinery/door/unpowered/ms13/BumpedBy(atom/movable/AM)
	return

/// Watts a door motor needs spare on its line, and draws for each swing.
#define MS13_DOOR_MOTOR_DRAW 500

/obj/machinery/door/unpowered/ms13/examine(mob/user)
	. = ..()
	if(motorised)
		. += span_notice("It's motorised[motor_powered() ? ", and its motor hums" : ", but no power reaches its motor"]. Its wire panel is [panel_open ? "open" : "<b>screwed</b> shut"].")
	if(bolted)
		. += span_warning("Its bolts are down.")

// Keys, locks, motors and wires, before the attack chain can swing the door on them.
/obj/machinery/door/unpowered/ms13/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/ms13/key/door))
		return use_key(user, tool)
	if(istype(tool, /obj/item/ms13/lock))
		return fit_lock(user, tool)
	if(istype(tool, /obj/item/ms13/door_motor))
		return fit_motor(user, tool)
	if(panel_open && wires && is_wire_tool(tool))
		attempt_wire_interaction(user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/door/unpowered/ms13/proc/use_key(mob/living/user, obj/item/ms13/key/door/key)
	if(key.matching_door?.resolve() != src)
		to_chat(user, span_warning("[key] doesn't fit [src]."))
		return ITEM_INTERACT_BLOCKING
	if(lock_locked)
		// Matches the lockpicking success path (lockpicking.dm) so both unlock methods leave the door the same.
		locked = FALSE
		lock_locked = FALSE
		if(lock)
			lock.item_lock_locked = FALSE
			lock.lock_open = TRUE
		RemoveElement(/datum/element/lockpickable)
		to_chat(user, span_notice("You unlock [src] with [key]."))
	else if(!lock)
		to_chat(user, span_notice("[src] has no lock to turn."))
		return ITEM_INTERACT_BLOCKING
	else if(!density)
		to_chat(user, span_warning("Close [src] first."))
		return ITEM_INTERACT_BLOCKING
	else
		lock.lock_open = FALSE
		lock.item_lock_locked = TRUE
		AddElement(/datum/element/lockpickable, difficulty = lock.lock_difficulty)
		to_chat(user, span_notice("You lock [src] with [key]."))
	playsound(src, 'mojave/sound/ms13effects/lock_close.ogg', 50, TRUE)
	return ITEM_INTERACT_SUCCESS

/// Fits a padlock and cuts its key, so whoever fits it isn't locked out.
/obj/machinery/door/unpowered/ms13/proc/fit_lock(mob/living/user, obj/item/ms13/lock/new_lock)
	if(lock)
		to_chat(user, span_warning("[src] already has a lock."))
		return ITEM_INTERACT_BLOCKING
	if(!(ms13_flags_1 & LOCKABLE_1) || !can_be_picked)
		to_chat(user, span_warning("[new_lock] won't fit [src]."))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, src, 3 SECONDS, DO_PUBLIC, display = new_lock) || lock || !user.temporarilyRemoveItemFromInventory(new_lock))
		return ITEM_INTERACT_BLOCKING
	user.put_in_hands(take_lock(new_lock))
	to_chat(user, span_notice("You fit [new_lock] to [src] and cut a key for it."))
	return ITEM_INTERACT_SUCCESS

/// Takes new_lock, open, and returns the key cut for it.
/obj/machinery/door/unpowered/ms13/proc/take_lock(obj/item/ms13/lock/new_lock)
	new_lock.forceMove(src)
	lock = new_lock
	new_lock.lock_open = TRUE
	new_lock.item_lock_locked = FALSE
	var/obj/item/ms13/key/door/key = new(drop_location())
	key.matching_door = WEAKREF(src)
	update_appearance()
	return key

/obj/machinery/door/unpowered/ms13/proc/fit_motor(mob/living/user, obj/item/ms13/door_motor/motor)
	if(motorised)
		to_chat(user, span_warning("[src] already has a motor."))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, src, 8 SECONDS, DO_PUBLIC, display = motor) || motorised)
		return ITEM_INTERACT_BLOCKING
	qdel(motor)
	install_motor()
	to_chat(user, span_notice("You fit [motor] to [src]. It'll run off a live cable knotted under the door."))
	return ITEM_INTERACT_SUCCESS

/obj/machinery/door/unpowered/ms13/proc/install_motor()
	motorised = TRUE
	wires = new /datum/wires/ms13_door(src)

/obj/machinery/door/unpowered/ms13/screwdriver_act(mob/living/user, obj/item/tool)
	if(!motorised)
		return NONE
	panel_open = !panel_open
	tool.play_tool_sound(src)
	to_chat(user, span_notice("You [panel_open ? "open" : "close"] [src]'s wire panel."))
	return ITEM_INTERACT_SUCCESS

/// Out comes the motor, through the open wire panel.
/obj/machinery/door/unpowered/ms13/try_to_crowbar(obj/item/acting_object, mob/user)
	if(!motorised || !panel_open)
		return
	to_chat(user, span_notice("You start prying [src]'s motor out..."))
	if(!acting_object.use_tool(src, user, 8 SECONDS, volume = 50) || !motorised)
		return
	motorised = FALSE
	bolted = FALSE
	panel_open = FALSE
	QDEL_NULL(wires)
	user.put_in_hands(new /obj/item/ms13/door_motor(drop_location()))
	to_chat(user, span_notice("You pry the motor out of [src]."))

/// Whether the motor has what it needs to run: its power wire whole and a live cable knotted under the door.
/obj/machinery/door/unpowered/ms13/proc/motor_powered()
	if(!motorised || wires?.is_cut(WIRE_POWER))
		return FALSE
	var/datum/powernet/line = ms13_cable_net_at(loc)
	return line && line.avail - line.load >= MS13_DOOR_MOTOR_DRAW

/// Swings the door by motor, drawing from the line under it. FALSE if it has no power to.
/obj/machinery/door/unpowered/ms13/proc/run_motor()
	if(bolted || operating || !motor_powered())
		return FALSE
	if(density && (locked || lock_locked))
		return FALSE
	ms13_cable_net_at(loc).load += MS13_DOOR_MOTOR_DRAW
	playsound(src, density ? 'mojave/sound/ms13machines/doorgear_open.ogg' : 'mojave/sound/ms13machines/doorgear_close.ogg', 40, TRUE)
	return density ? open() : close()

TYPEINFO_DEF(/obj/machinery/door/unpowered/ms13/metal)
	default_armor = list(BLUNT = 75, PUNCTURE = 30, SLASH = 75, LASER = 75, ENERGY = 50, BOMB = 30, BIO = 100, FIRE = 60, ACID = 100)

/obj/machinery/door/unpowered/ms13/metal
	name = "metal door"
	icon_state = "metal_closed"
	door_type = "metal"
	assemblytype = /obj/item/stack/sheet/ms13/scrap
	max_integrity = 2000 //its metal
	damage_deflection = 25
	hitted_sound = 'mojave/sound/ms13effects/metal_door_hit.ogg'

/obj/machinery/door/unpowered/ms13/metal/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		playsound(src, 'mojave/sound/ms13effects/metal_door_break.ogg', 100, TRUE)
		new /obj/item/stack/sheet/ms13/scrap/two(loc)
		for(var/obj/item/I in src)
			I.forceMove(loc)
	qdel(src)

/obj/machinery/door/unpowered/ms13/metal/mirrored
	icon_state = "metal_mirrored_closed"
	door_type = "metal_mirrored"
	mirrored = TRUE

/obj/machinery/door/unpowered/ms13/metal/alt
	icon_state = "metal_alt_closed"
	door_type = "metal_alt"

/obj/machinery/door/unpowered/ms13/metal/mirrored/alt
	icon_state = "metal_alt_mirrored_closed"
	door_type = "metal_alt_mirrored"

/obj/machinery/door/unpowered/ms13/metal/red
	icon_state = "metal_red_closed"
	door_type = "metal_red"

/obj/machinery/door/unpowered/ms13/metal/mirrored/red
	icon_state = "metal_red_mirrored_closed"
	door_type = "metal_red_mirrored"

// Wood doors //
/obj/machinery/door/unpowered/ms13/wood
	name = "wood door"
	icon_state = "wood_closed"
	door_type = "wood"
	frametype = "wood"
	assemblytype = /obj/item/stack/sheet/ms13/wood/scrap_wood
	hitted_sound = 'mojave/sound/ms13effects/wood_door_hit.ogg'

/obj/machinery/door/unpowered/ms13/wood/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		playsound(src, 'mojave/sound/ms13effects/wood_door_break.ogg', 100, TRUE)
		new /obj/item/stack/sheet/ms13/wood/scrap_wood/two(loc)
		for(var/obj/item/I in src)
			I.forceMove(loc)
	qdel(src)

/obj/machinery/door/unpowered/ms13/wood/mirrored
	icon_state = "wood_mirrored_closed"
	door_type = "wood_mirrored"
	mirrored = TRUE

/obj/machinery/door/unpowered/ms13/wood/red
	icon_state = "wood_red_closed"
	door_type = "wood_red"

/obj/machinery/door/unpowered/ms13/wood/mirrored/red
	icon_state = "wood_red_mirrored_closed"
	door_type = "wood_red_mirrored"

/obj/machinery/door/unpowered/ms13/wood/blue
	icon_state = "wood_blue_closed"
	door_type = "wood_blue"

/obj/machinery/door/unpowered/ms13/wood/mirrored/blue
	icon_state = "wood_blue_mirrored_closed"
	door_type = "wood_blue_mirrored"

/obj/machinery/door/unpowered/ms13/wood/green
	icon_state = "wood_green_closed"
	door_type = "wood_green"

/obj/machinery/door/unpowered/ms13/wood/mirrored/green
	icon_state = "wood_green_mirrored_closed"
	door_type = "wood_green_mirrored"

/obj/machinery/door/unpowered/ms13/wood/white
	icon_state = "wood_white_closed"
	door_type = "wood_white"

/obj/machinery/door/unpowered/ms13/wood/mirrored/white
	icon_state = "wood_white_mirrored_closed"
	door_type = "wood_white_mirrored"

// Window/Open doors //

/obj/machinery/door/unpowered/ms13/seethrough
	name = "generic ms13 see-through door"
	glass = TRUE
	opacity = 0
	assemblytype = /obj/item/stack/sheet/ms13/scrap
	var/passthrough_chance = 80

/obj/machinery/door/unpowered/ms13/seethrough/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(locate(/obj/machinery/door/unpowered/ms13/seethrough) in get_turf(mover))
		return TRUE
	else if(istype(mover, /obj/projectile))
		if(!anchored)
			return TRUE
		var/obj/projectile/proj = mover
		if(proj.firer && Adjacent(proj.firer))
			return TRUE
		if(prob((passthrough_chance)))
			return TRUE
		return FALSE

TYPEINFO_DEF(/obj/machinery/door/unpowered/ms13/seethrough/metal)
	default_armor = list(BLUNT = 75, PUNCTURE = 30, SLASH = 75, LASER = 75, ENERGY = 50, BOMB = 30, BIO = 100, FIRE = 60, ACID = 100)

/obj/machinery/door/unpowered/ms13/seethrough/metal
	name = "metal door"
	icon_state = "metal_window_closed"
	door_type = "metal_window"
	passthrough_chance = 40 //Small window!
	max_integrity = 1800 //its metal
	damage_deflection = 25
	hitted_sound = 'mojave/sound/ms13effects/metal_door_hit.ogg'

/obj/machinery/door/unpowered/ms13/seethrough/metal/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		playsound(src, 'mojave/sound/ms13effects/metal_door_break.ogg', 100, TRUE)
		new /obj/item/stack/sheet/ms13/scrap/two(loc)
		for(var/obj/item/I in src)
			I.forceMove(loc)
	qdel(src)

/obj/machinery/door/unpowered/ms13/seethrough/mirrored/metal
	name = "metal door"
	icon_state = "metal_window_mirrored_closed"
	door_type = "metal_window_mirrored"
	mirrored = TRUE

/obj/machinery/door/unpowered/ms13/seethrough/bar
	name = "barred door"
	icon_state = "metal_bar_closed"
	door_type = "metal_bar"
	has_damage_overlay = FALSE

/obj/machinery/door/unpowered/ms13/seethrough/mirrored/bar
	name = "barred door"
	icon_state = "metal_bar_mirrored_closed"
	door_type = "metal_bar_mirrored"
	has_damage_overlay = FALSE

/obj/machinery/door/unpowered/ms13/seethrough/grate
	name = "grated door"
	icon_state = "metal_grate_closed"
	door_type = "metal_grate"
	has_damage_overlay = FALSE

/obj/machinery/door/unpowered/ms13/seethrough/mirrored/grate
	name = "grated door"
	icon_state = "metal_grate_mirrored_closed"
	door_type = "metal_grate_mirrored"
	has_damage_overlay = FALSE

// Door frames //

TYPEINFO_DEF(/obj/machinery/door/unpowered/ms13/seethrough/frame)
	default_armor = list(BLUNT = 20, PUNCTURE = 10, SLASH = 20, LASER = 30, ENERGY = 20, BOMB = 10, BIO = 100, FIRE = 10, ACID = 50)

/// A bare door on its hinges: it opens, shuts, locks and takes a motor like any door, but can be climbed over and shot
/// through. Panelled with planks, scrap or steel, it becomes a real door.
/obj/machinery/door/unpowered/ms13/seethrough/frame
	name = "door frame"
	desc = "A bare, braced door frame on its hinges. It opens and shuts, but anyone could climb over it."
	icon = 'mojave/icons/structure/door_frame.dmi'
	icon_state = "frame_closed"
	door_type = "frame"
	frametype = "wood"
	has_damage_overlay = FALSE
	passthrough_chance = 90
	max_integrity = 300
	damage_deflection = 5
	assemblytype = /obj/item/stack/sheet/ms13/wood/plank
	hitted_sound = 'mojave/sound/ms13effects/wood_door_hit.ogg'
	/// Sheet type -> list(door it becomes, sheets it takes).
	var/static/list/panels = list(
		/obj/item/stack/sheet/ms13/wood/plank = list(/obj/machinery/door/unpowered/ms13/wood, 4),
		/obj/item/stack/sheet/ms13/scrap = list(/obj/machinery/door/unpowered/ms13/metal, 4),
		/obj/item/stack/sheet/ms13/scrap_steel = list(/obj/machinery/door/unpowered/ms13/seethrough/bar, 3),
		/obj/item/stack/sheet/ms13/refined_steel = list(/obj/machinery/door/unpowered/ms13/seethrough/grate, 2),
	)

/obj/machinery/door/unpowered/ms13/seethrough/frame/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/climbable)

/obj/machinery/door/unpowered/ms13/seethrough/frame/examine(mob/user)
	. = ..()
	var/list/options = list()
	for(var/obj/item/stack/sheet/sheet as anything in panels)
		var/obj/machinery/door/door = panels[sheet][1]
		options += "[panels[sheet][2]] [initial(sheet.name)] for  [initial(door.name)]"
	. += span_notice("Panel it with [english_list(options, and_text = " or ")].")

/obj/machinery/door/unpowered/ms13/seethrough/frame/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/obj/item/stack/sheet/sheets = tool
	var/list/panel = istype(sheets) && panels[sheets.merge_type]
	if(!panel)
		return ..()
	if(lock)
		to_chat(user, span_warning("Take the lock off [src] first."))
		return ITEM_INTERACT_BLOCKING
	if(!density)
		to_chat(user, span_warning("Close [src] first."))
		return ITEM_INTERACT_BLOCKING
	var/needed = panel[2]
	if(sheets.get_amount() < needed)
		to_chat(user, span_warning("You need [needed] of [sheets] to panel [src]."))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, src, 10 SECONDS, DO_PUBLIC, display = sheets) || QDELETED(src) || lock || !density || sheets.get_amount() < needed)
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/door/unpowered/ms13/door = panel(sheets)
	user.visible_message(span_notice("[user] panels [src] into  [door]."), span_notice("You panel it into  [door]."))
	return ITEM_INTERACT_SUCCESS

/// Uses up the sheets and swaps the frame for the door they make, facing the same way and keeping its motor.
/obj/machinery/door/unpowered/ms13/seethrough/frame/proc/panel(obj/item/stack/sheet/sheets)
	var/list/panel = panels[sheets.merge_type]
	sheets.use(panel[2])
	var/door_type = panel[1]
	var/turf/spot = loc
	moveToNullspace() // one door to a tile
	var/obj/machinery/door/unpowered/ms13/door = new door_type(spot)
	door.setDir(dir)
	if(motorised)
		door.install_motor()
	transfer_fingerprints_to(door)
	qdel(src)
	return door

/obj/machinery/door/unpowered/ms13/seethrough/frame/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		playsound(src, 'mojave/sound/ms13effects/wood_door_break.ogg', 100, TRUE)
		new /obj/item/stack/sheet/ms13/wood/plank(loc, 2)
		for(var/obj/item/I in src)
			I.forceMove(loc)
	qdel(src)

/// A door frame, flat-packed. Stood up in the doorway you face.
/obj/item/ms13/door_frame
	name = "door frame kit"
	desc = "A braced wooden door frame, hinges and all. Face a doorway and use it in hand to stand it up there."
	icon = 'mojave/icons/objects/door_frame_kit.dmi'
	icon_state = "door_frame"
	w_class = WEIGHT_CLASS_BULKY

/obj/item/ms13/door_frame/attack_self(mob/user)
	var/turf/spot = get_step(user, user.dir)
	if(!door_room(spot))
		to_chat(user, span_warning("There's no room to stand [src] up there."))
		return
	to_chat(user, span_notice("You start standing [src] up..."))
	if(!do_after(user, spot, 5 SECONDS, DO_PUBLIC, display = src) || !door_room(spot))
		return
	var/obj/machinery/door/unpowered/ms13/seethrough/frame/frame = new(spot)
	frame.setDir(user.dir)
	transfer_fingerprints_to(frame)
	user.visible_message(span_notice("[user] stands up  [frame]."), span_notice("You stand up [frame]."))
	qdel(src)

/obj/item/ms13/door_frame/proc/door_room(turf/spot)
	if(!isopenturf(spot) || (locate(/obj/machinery/door) in spot) || (locate(/obj/structure/mineral_door) in spot))
		return FALSE
	for(var/atom/movable/thing in spot)
		if(thing.density)
			return FALSE
	return TRUE

/obj/item/ms13/door_motor
	name = "door motor"
	desc = "A geared electric motor with a bolt throw and a little wiring loom. Fitted to a door with a live cable knotted under it, it swings the door on its own."
	icon = 'icons/obj/module.dmi'
	icon_state = "servo"
	w_class = WEIGHT_CLASS_NORMAL

/// A door motor's loom: power, a wire that swings the door, a wire that throws its bolts.
/datum/wires/ms13_door
	holder_type = /obj/machinery/door/unpowered/ms13
	proper_name = "Door Motor"
	randomize = TRUE

/datum/wires/ms13_door/New(atom/holder)
	wires = list(WIRE_POWER, WIRE_OPEN, WIRE_BOLTS)
	add_duds(2)
	..()

/datum/wires/ms13_door/interactable(mob/user)
	. = ..()
	var/obj/machinery/door/unpowered/ms13/door = holder
	return . && door.panel_open

/datum/wires/ms13_door/on_pulse(wire, user)
	var/obj/machinery/door/unpowered/ms13/door = holder
	switch(wire)
		if(WIRE_OPEN)
			door.run_motor()
		if(WIRE_BOLTS)
			if(door.motor_powered())
				door.bolted = !door.bolted
				playsound(door, 'sound/machines/boltsup.ogg', 30, TRUE)

/datum/wires/ms13_door/on_cut(wire, mend)
	var/obj/machinery/door/unpowered/ms13/door = holder
	// Cut, the bolt wire drops them.
	if(wire == WIRE_BOLTS && !mend && !door.bolted)
		door.bolted = TRUE
		playsound(door, 'sound/machines/boltsdown.ogg', 30, TRUE)

#undef MS13_DOOR_MOTOR_DRAW

#ifdef UNIT_TESTS
/datum/unit_test/ms13_door_frames
	name = "DOORS: Frames Take Motors, Locks And Panels"

/datum/unit_test/ms13_door_frames/Run()
	var/x0 = run_loc_floor_bottom_left.x + 1
	var/y0 = run_loc_floor_bottom_left.y + 1
	var/z0 = run_loc_floor_bottom_left.z
	var/turf/spot = locate(x0, y0, z0)
	var/turf/beside = locate(x0 + 1, y0, z0)
	var/mob/living/carbon/human/builder = allocate(/mob/living/carbon/human/consistent, locate(x0, y0 + 1, z0))
	var/obj/machinery/door/unpowered/ms13/seethrough/frame/frame = allocate(/obj/machinery/door/unpowered/ms13/seethrough/frame, spot)
	frame.setDir(NORTH)
	if(!HAS_TRAIT(frame, TRAIT_CLIMBABLE) || frame.opacity)
		Fail("A door frame wasn't climbable, or blocked sight.")

	// A motor with no cable under it does nothing; wired to a running petrol generator, it swings the door.
	frame.install_motor()
	if(frame.run_motor())
		Fail("A door motor ran with no cable under it.")
	var/obj/structure/cable/door_knot = allocate(/obj/structure/cable, spot)
	door_knot.set_directions(GLOB.real_dirs_to_cable_dirs["[EAST]"])
	var/obj/structure/cable/generator_knot = allocate(/obj/structure/cable, beside)
	generator_knot.set_directions(GLOB.real_dirs_to_cable_dirs["[WEST]"])
	var/obj/machinery/ms13/fusion_generator/petrol/generator = allocate(/obj/machinery/ms13/fusion_generator/petrol, beside)
	var/obj/item/reagent_containers/ms13/lighterfluid/can = allocate(/obj/item/reagent_containers/ms13/lighterfluid)
	generator.item_interaction(builder, can)
	if(generator.fuel != generator.max_fuel || can.reagents.total_volume != 100 - generator.max_fuel / generator.seconds_per_unit)
		Fail("A petrol generator didn't fill its tank from a fuel can.")
	generator.set_generator_state("on")
	generator.process(2)
	ms13_cable_net_at(spot)?.reset()
	if(!frame.run_motor() || frame.density)
		Fail("A door motor on a live line didn't open the door.")
	frame.wires.cut(WIRE_POWER)
	if(frame.run_motor())
		Fail("A door motor ran with its power wire cut.")
	frame.wires.cut(WIRE_POWER)
	frame.run_motor()
	frame.wires.pulse(WIRE_BOLTS)
	if(!frame.density || !frame.bolted || frame.try_to_activate_door(builder))
		Fail("Pulsing the bolt wire didn't bolt the closed door.")
	frame.bolted = FALSE

	// A fitted padlock comes with its key, which locks and unlocks the door.
	var/obj/item/ms13/key/door/key = frame.take_lock(allocate(/obj/item/ms13/lock))
	allocated += key
	frame.use_key(builder, key)
	if(!frame.lock_locked || frame.try_to_activate_door(builder))
		Fail("The key cut for a fitted padlock didn't lock the door.")
	frame.use_key(builder, key)
	if(frame.lock_locked)
		Fail("The key cut for a fitted padlock didn't unlock the door.")

	// Panelled, the frame becomes a real door facing its way, motor and all.
	frame.lock.forceMove(spot)
	frame.lock = null
	var/obj/item/stack/sheet/ms13/wood/plank/planks = allocate(/obj/item/stack/sheet/ms13/wood/plank/four, spot)
	var/obj/machinery/door/unpowered/ms13/door = frame.panel(planks)
	allocated += door
	if(!istype(door, /obj/machinery/door/unpowered/ms13/wood) || door.dir != NORTH || !door.motorised || !QDELETED(frame) || !QDELETED(planks))
		Fail("Panelling a frame with planks didn't make a wooden door, facing its way and keeping its motor.")
#endif
