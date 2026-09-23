#define MS13_MECH_LEFT_ARM "left arm"
#define MS13_MECH_RIGHT_ARM "right arm"

/**
 * A walking armored shell for one pilot, with ordinary guns bolted to its arms.
 *
 * Built on sealed vehicles rather than /mecha: there's no cabin air, malfunction, stock part or control panel to
 * switch off, and nothing processing while it stands idle. The pilot breathes the air outside, as on foot.
 * Everything else is done from outside, by hand: use a gun or a piece of equipment on it to mount it, a wrench to take
 * one off, magazines to reload, a crowbar to pry out an occupant or the battery, and a welder for repairs.
 */
TYPEINFO_DEF(/obj/vehicle/sealed/ms13_mech)
	default_armor = list(BLUNT = 20, PUNCTURE = 10, SLASH = 0, LASER = 0, ENERGY = 0, BOMB = 10, BIO = 0, FIRE = 100, ACID = 100)

/obj/vehicle/sealed/ms13_mech
	name = "mech"
	desc = "A walking armored shell for one pilot."
	icon = 'icons/mecha/mecha.dmi'
	resistance_flags = FIRE_PROOF | ACID_PROOF
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_EXTREMELY_STRONG
	light_system = OVERLAY_LIGHT_DIRECTIONAL
	light_on = FALSE
	light_outer_range = 8
	mouse_pointer = 'icons/effects/mouse_pointers/mecha_mouse.dmi'
	movedelay = 1 SECONDS
	// Armor plate, like vehicle hull plating: it stops a lot of a round but takes little harm from it.
	bullet_damage_ratio = 0.3
	/// Runs everything. Any cell fits, and a crowbar pries it out.
	var/obj/item/stock_parts/cell/cell = /obj/item/stock_parts/cell/ms13_vehicle/truck
	/// Charge used by every step and turn.
	var/step_energy_drain = 10
	/// Damage multipliers for hits on the front, sides and back.
	var/list/facing_modifiers = list(MECHA_FRONT_ARMOUR = 0.5, MECHA_SIDE_ARMOUR = 1, MECHA_BACK_ARMOUR = 1.5)
	var/stepsound = 'sound/mecha/mechstep.ogg'
	var/turnsound = 'sound/mecha/mechturn.ogg'
	/// The gun or equipment on each arm. The driver uses the left with a left click and the right with a right click.
	var/list/arms = list(MS13_MECH_LEFT_ARM = null, MS13_MECH_RIGHT_ARM = null)
	var/obj/item/ms13_mech_autoloader/autoloader
	/// Knocked out: it stands where it fell, climbable, until it's welded back up. Whoever's inside stays inside.
	var/wrecked = FALSE
	/// The driver's client, whose mouse buttons work the arms.
	var/client/pilot_client
	/// Arms held down, going again and again: arm = list(target, click params, the target's turf when aimed). A new list each press.
	var/list/autofiring
	/// No sides to it: a round aimed at the head or chest finds whoever's inside, not the frame.
	var/open_cockpit = FALSE
	/// Weighed as a vehicle's mass_per_frame counts it: a vehicle ramming it with more momentum than this knocks it back.
	var/mass = 2000
	/// How long it takes to load someone in, or pry them out with a crowbar.
	var/load_time = 6 SECONDS
	/// Being loaded in by someone else: they ride along rather than taking the controls.
	var/mob/living/loading
	/// Guns still working their action after a shot.
	var/list/cycling

/obj/vehicle/sealed/ms13_mech/Initialize(mapload)
	. = ..()
	if(ispath(cell))
		cell = new cell(src)
	update_appearance()

/obj/vehicle/sealed/ms13_mech/Destroy()
	release_mouse()
	for(var/arm in arms)
		qdel(arms[arm])
	QDEL_NULL(autoloader)
	QDEL_NULL(cell)
	return ..()

/obj/vehicle/sealed/ms13_mech/examine(mob/user)
	. = ..()
	if(wrecked)
		. += span_warning("It's wrecked. Welded back up, it would walk again.")
	for(var/arm in arms)
		var/obj/item/gun/ballistic/gun = arms[arm]
		var/obj/item/ms13_mech_equipment/clamp/clamp = arms[arm]
		if(istype(gun))
			var/rounds = gun.get_ammo(FALSE) + !!gun.chambered?.loaded_projectile
			. += "On its [arm]: [gun], with [rounds] round\s left."
		else if(istype(clamp) && clamp.held)
			. += "On its [arm]: [clamp], holding [clamp.held]."
		else if(arms[arm])
			. += "On its [arm]: [arms[arm]]."
	if(LAZYLEN(occupants) > 1)
		. += "It carries [LAZYLEN(occupants)] people."
	if(autoloader)
		. += "An autoloader on its back holds [length(autoloader.contents)] magazine\s."
	. += cell ? "Its battery reads [round(cell.percent())]%." : span_warning("It has no battery.")

/obj/vehicle/sealed/ms13_mech/update_icon_state()
	icon_state = wrecked ? "[base_icon_state]-broken" : (LAZYLEN(occupants) ? base_icon_state : "[base_icon_state]-open")
	return ..()

/// A clamp shows a small copy of what it holds, out on its arm's side.
/obj/vehicle/sealed/ms13_mech/update_overlays()
	. = ..()
	for(var/arm in arms)
		var/obj/item/ms13_mech_equipment/clamp/clamp = arms[arm]
		if(!istype(clamp) || !clamp.held)
			continue
		var/mutable_appearance/held_look = new(clamp.held)
		held_look.transform = matrix(0.5, 0, 0, 0, 0.5, 0)
		held_look.plane = FLOAT_PLANE
		var/side = turn(dir, arm == MS13_MECH_LEFT_ARM ? 90 : -90)
		held_look.pixel_x = (side & EAST) ? 12 : (side & WEST) ? -12 : 0
		held_look.pixel_y = (side & NORTH) ? 6 : (side & SOUTH) ? -6 : 0
		// The far arm is behind the body.
		held_look.layer = side == NORTH ? layer - 0.01 : layer + 0.01
		. += held_look

/obj/vehicle/sealed/ms13_mech/setDir(newdir)
	var/turned = newdir != dir
	. = ..()
	if(turned)
		update_appearance()

/obj/vehicle/sealed/ms13_mech/generate_actions()
	. = ..()
	initialize_controller_action_type(/datum/action/vehicle/sealed/headlights, VEHICLE_CONTROL_DRIVE)

/obj/vehicle/sealed/ms13_mech/mob_try_enter(mob/M)
	if(!ishuman(M) || wrecked)
		return FALSE
	return ..()

/obj/vehicle/sealed/ms13_mech/add_occupant(mob/M, control_flags)
	. = ..()
	if(!.)
		return
	RegisterSignal(M, COMSIG_LIVING_DEATH, PROC_REF(mob_exit))
	update_appearance()

/obj/vehicle/sealed/ms13_mech/remove_occupant(mob/M)
	if(ismob(M))
		UnregisterSignal(M, COMSIG_LIVING_DEATH)
	. = ..()
	update_appearance()

/// Only someone climbing in takes the controls. Anyone loaded in rides along.
/obj/vehicle/sealed/ms13_mech/auto_assign_occupant_flags(mob/M)
	if(M != loading)
		return ..()

/// The driver walks it and works its arms.
/obj/vehicle/sealed/ms13_mech/add_control_flags(mob/controller, flags)
	var/was_driving = is_driver(controller)
	. = ..()
	if(!was_driving && is_driver(controller))
		RegisterSignal(controller, COMSIG_MOB_CLICKON, PROC_REF(on_click))
		RegisterSignal(controller, COMSIG_MOB_LOGIN, PROC_REF(grab_mouse))
		RegisterSignal(controller, COMSIG_MOB_LOGOUT, PROC_REF(release_mouse))
		grab_mouse(controller)

/obj/vehicle/sealed/ms13_mech/remove_control_flags(mob/controller, flags)
	var/was_driving = is_driver(controller)
	. = ..()
	if(was_driving && !is_driver(controller))
		UnregisterSignal(controller, list(COMSIG_MOB_CLICKON, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT))
		release_mouse()

/obj/vehicle/sealed/ms13_mech/relaymove(mob/living/user, direction)
	if(is_driver(user))
		return ..()
	return TRUE

/// Drag someone else onto it to load them in.
/obj/vehicle/sealed/ms13_mech/MouseDroppedOn(atom/dropping, mob/user)
	if(ishuman(dropping) && dropping != user && isliving(user))
		load_passenger(dropping, user)
		return
	return ..()

/obj/vehicle/sealed/ms13_mech/proc/load_passenger(mob/living/carbon/human/passenger, mob/living/user)
	if(wrecked || is_occupant(passenger) || !user.Adjacent(src) || !user.Adjacent(passenger))
		return FALSE
	if(occupant_amount() >= max_occupants)
		balloon_alert(user, "no room!")
		return FALSE
	user.visible_message(span_warning("[user] starts loading [passenger] into [src]."))
	if(!do_after(user, src, load_time, extra_checks = CALLBACK(src, PROC_REF(enter_checks), passenger)) || wrecked || !user.Adjacent(passenger))
		return FALSE
	loading = passenger
	mob_enter(passenger)
	loading = null
	return TRUE

/obj/vehicle/sealed/ms13_mech/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == cell)
		cell = null
	else if(gone == autoloader)
		autoloader = null
	else
		for(var/arm in arms)
			if(arms[arm] != gone)
				continue
			arms[arm] = null
			LAZYREMOVE(autofiring, arm)
			update_appearance()
			// Taken off, a clamp lets go.
			var/obj/item/ms13_mech_equipment/clamp/clamp = gone
			if(istype(clamp))
				clamp.held?.forceMove(drop_location())
			var/obj/item/gun/ballistic/gun = gone
			if(istype(gun))
				gun.wielded = FALSE
				UnregisterSignal(gun, list(COMSIG_PROJECTILE_BEFORE_FIRE, COMSIG_MOVABLE_PRE_THROW))
				LAZYREMOVE(cycling, gun)

// Movement

/obj/vehicle/sealed/ms13_mech/vehicle_move(direction)
	if(!direction || ISDIAGONALDIR(direction) || !COOLDOWN_FINISHED(src, cooldown_vehicle_move))
		return FALSE
	COOLDOWN_START(src, cooldown_vehicle_move, movedelay)
	if(wrecked || !cell?.use(step_energy_drain))
		if(!TIMER_COOLDOWN_CHECK(src, COOLDOWN_MECHA_MESSAGE))
			to_chat(occupants, span_warning("[src] [wrecked ? "is wrecked" : "has no power to move"]."))
			TIMER_COOLDOWN_START(src, COOLDOWN_MECHA_MESSAGE, 2 SECONDS)
		return FALSE
	// It turns on the spot before it walks.
	if(dir != direction)
		playsound(src, turnsound, 40, TRUE)
		setDir(direction)
		return TRUE
	set_glide_size(DELAY_TO_GLIDE_SIZE(movedelay))
	. = step(src, direction)
	if(.)
		playsound(src, stepsound, 40, TRUE)

// Damage and wrecking

/obj/vehicle/sealed/ms13_mech/run_atom_armor(damage_amount, damage_type, damage_flag = NONE, attack_dir, armor_penetration = 0)
	. = ..()
	if(. && attack_dir && !resolving_bullet_hit)
		. *= facing_modifier(attack_dir)

/// Damage multiplier for a hit coming from attack_dir: least on the front, most on the back.
/obj/vehicle/sealed/ms13_mech/proc/facing_modifier(attack_dir)
	var/angle = abs(dir2angle(dir) - dir2angle(attack_dir))
	angle = min(angle, 360 - angle)
	if(angle <= 45)
		return facing_modifiers[MECHA_FRONT_ARMOUR]
	if(angle >= 180)
		return facing_modifiers[MECHA_BACK_ARMOUR]
	return facing_modifiers[MECHA_SIDE_ARMOUR]

/// Thicker plate up front: a round finds a face as much harder to get through as that face takes less damage.
/obj/vehicle/sealed/ms13_mech/get_bullet_stopping_power(obj/projectile/P)
	return ..() / facing_modifier(REVERSE_DIR(P.dir))

/obj/vehicle/sealed/ms13_mech/get_bullet_transfer_fraction(obj/projectile/P, def_zone)
	if(open_cockpit && LAZYLEN(occupants) && (def_zone == BODY_ZONE_HEAD || def_zone == BODY_ZONE_CHEST))
		return 0
	return ..()

/obj/vehicle/sealed/ms13_mech/get_bullet_occupant()
	return LAZYLEN(occupants) ? pick(occupants) : null

/// It wrecks rather than going to pieces: it never quite runs out of integrity, and welded back to full, it walks again.
/obj/vehicle/sealed/ms13_mech/update_integrity(new_value, damage_flag = NONE, allow_break = TRUE)
	. = ..(max(new_value, 1), damage_flag, allow_break)
	if(wrecked ? atom_integrity >= max_integrity : atom_integrity <= 1)
		set_wrecked(!wrecked)

/obj/vehicle/sealed/ms13_mech/proc/set_wrecked(new_wrecked)
	wrecked = new_wrecked
	if(wrecked)
		autofiring = null
		AddElement(/datum/element/climbable)
		visible_message(span_danger("[src] crashes to a halt, wrecked!"))
		playsound(src, 'sound/mecha/critdestr.ogg', 50, TRUE)
	else
		RemoveElement(/datum/element/climbable)
		visible_message(span_notice("[src] shudders back to life."))
	update_appearance()

/// A vehicle ramming it with more momentum than it has mass knocks it back a tile, if there's room, and drives on.
/obj/vehicle/sealed/ms13_mech/rammed_by(datum/ms13_ground_vehicle/vehicle, direction)
	if(length(vehicle.frames) * vehicle.mass_per_frame * vehicle.speed >= mass)
		knocked_back(direction)

/obj/vehicle/sealed/ms13_mech/proc/knocked_back(direction)
	var/facing = dir
	if(!step(src, direction))
		return FALSE
	setDir(facing)
	playsound(src, 'sound/effects/meteorimpact.ogg', 60, TRUE)
	for(var/mob/living/occupant as anything in occupants)
		shake_camera(occupant, 3, 2)
	return TRUE

/obj/vehicle/sealed/ms13_mech/welder_act(mob/living/user, obj/item/tool)
	if(atom_integrity >= max_integrity)
		balloon_alert(user, "not damaged!")
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 1 SECONDS, amount = 1, volume = 50))
		return ITEM_INTERACT_BLOCKING
	repair_damage(10)
	balloon_alert(user, "[get_integrity_percentage()]%")
	return ITEM_INTERACT_SUCCESS

// Fitting it out

/obj/vehicle/sealed/ms13_mech/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode)
		return NONE
	if(istype(tool, /obj/item/gun/ballistic) || istype(tool, /obj/item/ms13_mech_equipment))
		var/arm = !arms[MS13_MECH_LEFT_ARM] ? MS13_MECH_LEFT_ARM : (!arms[MS13_MECH_RIGHT_ARM] ? MS13_MECH_RIGHT_ARM : null)
		if(!arm)
			balloon_alert(user, "both arms are full!")
			return ITEM_INTERACT_BLOCKING
		balloon_alert(user, "mounting it...")
		if(!do_after(user, src, 3 SECONDS) || arms[arm] || !user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		mount(tool, arm)
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/ms13_mech_autoloader))
		if(autoloader)
			balloon_alert(user, "it has one!")
			return ITEM_INTERACT_BLOCKING
		balloon_alert(user, "bolting it on...")
		if(!do_after(user, src, 3 SECONDS) || autoloader || !user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		autoloader = tool
		for(var/arm in arms)
			autoload(arms[arm])
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/stock_parts/cell))
		if(cell)
			balloon_alert(user, "it has a battery!")
			return ITEM_INTERACT_BLOCKING
		if(!user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		cell = tool
		return ITEM_INTERACT_SUCCESS
	if(isammocasing(tool) || istype(tool, /obj/item/ammo_box))
		// Fitted, the autoloader takes the magazines and feeds the guns itself.
		if(autoloader && autoloader.atom_storage.can_insert(tool, user, messages = FALSE) && autoloader.atom_storage.attempt_insert(tool, user))
			for(var/arm in arms)
				autoload(arms[arm])
			return ITEM_INTERACT_SUCCESS
		if(load_arms(tool, user))
			return ITEM_INTERACT_SUCCESS
		balloon_alert(user, "nothing takes that!")
		return ITEM_INTERACT_BLOCKING
	return NONE

/// A wrench takes a gun, equipment or the autoloader off whole.
/obj/vehicle/sealed/ms13_mech/wrench_act(mob/living/user, obj/item/tool)
	var/list/choices = list()
	for(var/arm in arms)
		if(arms[arm])
			choices[arm] = image(arms[arm])
	if(autoloader)
		choices["autoloader"] = image(autoloader)
	if(!length(choices))
		balloon_alert(user, "nothing to unbolt!")
		return ITEM_INTERACT_BLOCKING
	var/choice = length(choices) == 1 ? choices[1] : show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	var/obj/item/part = choice == "autoloader" ? autoloader : arms[choice]
	if(!part)
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "unbolting...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50) || part.loc != src)
		return ITEM_INTERACT_BLOCKING
	user.put_in_hands(part)
	return ITEM_INTERACT_SUCCESS

/// A crowbar pries out whoever's picked from inside, or the battery.
/obj/vehicle/sealed/ms13_mech/crowbar_act(mob/living/user, obj/item/tool)
	var/list/choices = list()
	var/list/picks = list()
	var/list/used_names = list()
	for(var/mob/occupant as anything in occupants)
		var/label = avoid_assoc_duplicate_keys(occupant.name, used_names)
		choices[label] = image(occupant)
		picks[label] = occupant
	if(cell)
		choices["battery"] = image(cell)
	if(!length(choices))
		balloon_alert(user, "nothing to pry out!")
		return ITEM_INTERACT_BLOCKING
	var/choice = length(choices) == 1 ? choices[1] : show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	if(choice == "battery")
		balloon_alert(user, "prying the battery out...")
		if(!tool.use_tool(src, user, 3 SECONDS, volume = 50) || !cell)
			return ITEM_INTERACT_BLOCKING
		user.put_in_hands(cell)
		return ITEM_INTERACT_SUCCESS
	var/mob/living/occupant = picks[choice]
	if(!is_occupant(occupant))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_warning("[user] starts prying [occupant] out of [src]!"))
	to_chat(occupant, span_userdanger("[user] is prying you out of [src]!"))
	if(!tool.use_tool(src, user, load_time, volume = 50, extra_checks = CALLBACK(src, PROC_REF(is_occupant), occupant)))
		return ITEM_INTERACT_BLOCKING
	mob_exit(occupant)
	return ITEM_INTERACT_SUCCESS

/// Bolts item, already inside, onto arm.
/obj/vehicle/sealed/ms13_mech/proc/mount(obj/item/item, arm)
	arms[arm] = item
	update_appearance()
	var/obj/item/gun/ballistic/gun = item
	if(!istype(gun))
		return
	// Braced on the arm, it shoots as steady as held in both hands.
	gun.wielded = TRUE
	RegisterSignal(gun, COMSIG_PROJECTILE_BEFORE_FIRE, PROC_REF(clear_own_hull))
	RegisterSignal(gun, COMSIG_MOVABLE_PRE_THROW, PROC_REF(stay_mounted))
	autoload(gun)

/// Its own shots fly out through the mech rather than hitting it.
/obj/vehicle/sealed/ms13_mech/proc/clear_own_hull(obj/item/gun/source, obj/projectile/bullet)
	SIGNAL_HANDLER
	bullet.impacted[src] = TRUE

/// A gun fired from inside something is treated as floating on its own, and would throw itself out of the mech.
/obj/vehicle/sealed/ms13_mech/proc/stay_mounted(obj/item/gun/source)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_THROW

// Ammunition

/// Someone outside feeds ammo to whichever mounted gun takes it and has the fewest rounds. FALSE if none does.
/obj/vehicle/sealed/ms13_mech/proc/load_arms(obj/item/ammo, mob/living/user)
	var/is_magazine = istype(ammo, /obj/item/ammo_box/magazine)
	var/obj/item/gun/ballistic/best
	for(var/arm in arms)
		var/obj/item/gun/ballistic/gun = arms[arm]
		if(!istype(gun) || (is_magazine ? (gun.internal_magazine || !istype(ammo, gun.mag_type)) : !(gun.internal_magazine || istype(gun.bolt, /datum/gun_bolt/no_bolt))))
			continue
		if(!best || gun.get_ammo() < best.get_ammo())
			best = gun
	if(!best)
		return FALSE
	// A bolt action takes ammo with its bolt open.
	if(istype(best, /obj/item/gun/ballistic/rifle) && !best.bolt.is_locked)
		best.rack()
	if(is_magazine && best.magazine)
		best.eject_magazine(user, FALSE)
	best.attackby(ammo, user)
	cycle(best)
	return TRUE

/// Once gun's magazine runs dry, the autoloader swaps in the first full one it has that fits.
/obj/vehicle/sealed/ms13_mech/proc/autoload(obj/item/gun/ballistic/gun)
	if(!autoloader || !istype(gun) || gun.loc != src || gun.internal_magazine || gun.magazine?.ammo_count())
		return
	var/obj/item/ammo_box/magazine/fresh
	for(var/obj/item/ammo_box/magazine/mag in autoloader)
		if(istype(mag, gun.mag_type) && mag.ammo_count())
			fresh = mag
			break
	if(!fresh)
		return
	var/obj/item/ammo_box/magazine/spent = gun.magazine
	if(spent)
		gun.bolt.magazine_ejected()
		gun.magazine = null
		spent.forceMove(drop_location())
		spent.update_appearance()
	fresh.forceMove(gun)
	gun.magazine = fresh
	gun.bolt.magazine_inserted()
	playsound(gun, gun.load_sound, gun.load_sound_volume, gun.load_sound_vary)
	cycle(gun)

/// Works gun's action as a gunner would, until a live round is chambered.
/obj/vehicle/sealed/ms13_mech/proc/cycle(obj/item/gun/ballistic/gun)
	if(gun.bolt.is_locked)
		gun.drop_bolt()
	else if(!gun.chambered?.loaded_projectile)
		gun.rack()
		// A bolt action opens on the first stroke and closes on the second.
		if(gun.bolt.is_locked && istype(gun, /obj/item/gun/ballistic/rifle))
			gun.drop_bolt()
	gun.update_appearance()

/obj/vehicle/sealed/ms13_mech/proc/finish_cycling(obj/item/gun/ballistic/gun)
	LAZYREMOVE(cycling, gun)
	if(gun.loc == src)
		cycle(gun)

// Using the arms

/// Fires arm's gun, or works its equipment, at target. FALSE when holding it down should stop, such as a gun run dry.
/obj/vehicle/sealed/ms13_mech/proc/use_arm(arm, atom/target, mob/living/pilot, params)
	var/obj/item/held = arms[arm]
	if(!held || wrecked || !cell?.charge || QDELETED(target) || !is_driver(pilot) || pilot.incapacitated())
		return FALSE
	// The arms only swing so far.
	var/dir_to_target = get_dir(src, target)
	if(dir_to_target && !(dir_to_target & dir))
		return TRUE
	var/obj/item/ms13_mech_equipment/equipment = held
	if(istype(equipment))
		return !Adjacent(target) || equipment.action(src, target, pilot)
	var/obj/item/gun/ballistic/gun = held
	if(HAS_TRAIT(pilot, TRAIT_PACIFISM))
		to_chat(pilot, span_warning("You don't want to harm other living beings!"))
		return FALSE
	if(gun.fire_lockout || LAZYACCESS(cycling, gun))
		return TRUE
	gun.on_trigger_pull(target, pilot)
	if(!gun.can_fire())
		gun.shoot_with_empty_chamber(pilot)
		return FALSE
	gun.do_fire_gun(target, pilot, FALSE, params)
	autoload(gun)
	if(!gun.semi_auto && gun.loc == src)
		LAZYSET(cycling, gun, TRUE)
		addtimer(CALLBACK(src, PROC_REF(finish_cycling), gun), gun.rack_delay)
	return TRUE

/// How soon holding the button down uses held again, or null if it goes once a click.
/obj/vehicle/sealed/ms13_mech/proc/repeat_delay(obj/item/held)
	var/obj/item/ms13_mech_equipment/equipment = held
	if(istype(equipment))
		return equipment.repeat_delay
	var/datum/component/automatic_fire/automatic = held?.GetComponent(/datum/component/automatic_fire)
	return automatic?.autofire_shot_delay

/// A click on a door beside it opens or shuts it, as a person would, unless it's the drill doing the clicking.
/obj/vehicle/sealed/ms13_mech/proc/is_door_click(arm, atom/target)
	return istype(target, /obj/machinery/door/unpowered) && Adjacent(target) && !istype(arms[arm], /obj/item/ms13_mech_equipment/drill)

/obj/vehicle/sealed/ms13_mech/proc/work_door(obj/machinery/door/unpowered/door, mob/living/pilot)
	if(!wrecked && do_after(pilot, door, 0.5 SECONDS, extra_checks = CALLBACK(src, PROC_REF(can_reach_door), door), interaction_key = DOAFTER_SOURCE_DOORS))
		door.try_to_activate_door(pilot)

/obj/vehicle/sealed/ms13_mech/proc/can_reach_door(obj/machinery/door/unpowered/door)
	return !wrecked && Adjacent(door)

/// A click uses that arm once. Anything that goes again while held uses on_mouse_down() instead.
/obj/vehicle/sealed/ms13_mech/proc/on_click(mob/living/user, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, MIDDLE_CLICK))
		return NONE
	if(target == src || (!isturf(target) && !isturf(target.loc)))
		return NONE
	var/arm = LAZYACCESS(modifiers, RIGHT_CLICK) ? MS13_MECH_RIGHT_ARM : MS13_MECH_LEFT_ARM
	if(is_door_click(arm, target))
		INVOKE_ASYNC(src, PROC_REF(work_door), target, user)
		return COMSIG_MOB_CANCEL_CLICKON
	var/obj/item/held = arms[arm]
	if(!held || repeat_delay(held))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(use_arm), arm, target, user, list2params(modifiers))
	return COMSIG_MOB_CANCEL_CLICKON

/obj/vehicle/sealed/ms13_mech/proc/grab_mouse(mob/pilot)
	SIGNAL_HANDLER
	release_mouse()
	pilot_client = pilot.client
	if(!pilot_client)
		return
	RegisterSignal(pilot_client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(on_mouse_down))
	RegisterSignal(pilot_client, COMSIG_CLIENT_MOUSEUP, PROC_REF(on_mouse_up))
	RegisterSignal(pilot_client, COMSIG_CLIENT_MOUSEDRAG, PROC_REF(on_mouse_drag))

/obj/vehicle/sealed/ms13_mech/proc/release_mouse()
	SIGNAL_HANDLER
	autofiring = null
	if(!pilot_client)
		return
	UnregisterSignal(pilot_client, list(COMSIG_CLIENT_MOUSEDOWN, COMSIG_CLIENT_MOUSEUP, COMSIG_CLIENT_MOUSEDRAG))
	pilot_client = null

/obj/vehicle/sealed/ms13_mech/proc/on_mouse_down(client/source, atom/target, turf/location, control, params)
	SIGNAL_HANDLER
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, MIDDLE_CLICK))
		return
	var/arm = LAZYACCESS(modifiers, RIGHT_CLICK) ? MS13_MECH_RIGHT_ARM : MS13_MECH_LEFT_ARM
	if(!repeat_delay(arms[arm]))
		return
	if(isnull(location) || istype(target, /atom/movable/screen))
		// Only the catcher behind the map: pressing on the HUD shouldn't open fire.
		if(target.plane != CLICKCATCHER_PLANE)
			return
		target = parse_caught_click_modifiers(modifiers, get_turf(source.eye), source)
		params = list2params(modifiers)
	if(!target || target == src || is_door_click(arm, target))
		return
	var/list/aim = list(target, params, get_turf(target))
	LAZYSET(autofiring, arm, aim)
	INVOKE_ASYNC(src, PROC_REF(autofire), arm, aim)

/obj/vehicle/sealed/ms13_mech/proc/on_mouse_up(client/source, atom/object, turf/location, control, params)
	SIGNAL_HANDLER
	var/arm = LAZYACCESS(params2list(params), RIGHT_CLICK) ? MS13_MECH_RIGHT_ARM : MS13_MECH_LEFT_ARM
	if(!LAZYACCESS(autofiring, arm))
		return NONE
	LAZYREMOVE(autofiring, arm)
	// The press already fired; the click it ends mustn't fire again.
	return COMPONENT_CLIENT_MOUSEUP_INTERCEPT

/obj/vehicle/sealed/ms13_mech/proc/on_mouse_drag(client/source, atom/src_object, atom/over_object, turf/src_location, turf/over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(!LAZYLEN(autofiring))
		return
	var/atom/target = over_object
	if(isnull(over_location))
		var/list/modifiers = params2list(params)
		target = parse_caught_click_modifiers(modifiers, get_turf(source.eye), source)
		params = list2params(modifiers)
	if(!target)
		return
	for(var/arm in autofiring)
		var/list/aim = autofiring[arm]
		aim[1] = target
		aim[2] = params
		aim[3] = get_turf(target)

/// Keeps using arm while aim is still the press held on it, as fast as what's on it goes again.
/obj/vehicle/sealed/ms13_mech/proc/autofire(arm, list/aim)
	if(LAZYACCESS(autofiring, arm) != aim)
		return
	var/delay = repeat_delay(arms[arm])
	var/atom/target = aim[1]
	// Like a held automatic, it keeps on the tile it was aimed at rather than following whatever walks off it.
	if(QDELETED(target) || get_turf(target) != aim[3])
		target = aim[3]
	if(!delay || !use_arm(arm, target, pilot_client?.mob, aim[2]))
		LAZYREMOVE(autofiring, arm)
		return
	addtimer(CALLBACK(src, PROC_REF(autofire), arm, aim), delay)

/// Bolts onto a mech's back. Stock it with magazines, by hand or through the mech: when a mounted gun runs dry, it swaps
/// in a full magazine that fits.
/obj/item/ms13_mech_autoloader
	name = "mech autoloader"
	desc = "A magazine feed that bolts onto a mech's back. When a mounted gun runs dry, it swaps in a full magazine that fits. Stock it by hand, or hand the mech the magazines once it's fitted."
	icon = 'icons/mecha/mecha_equipment.dmi'
	icon_state = "mecha_weapon_bay"
	w_class = WEIGHT_CLASS_BULKY

/obj/item/ms13_mech_autoloader/Initialize(mapload)
	. = ..()
	create_storage(canhold = list(/obj/item/ammo_box/magazine), type = /datum/storage/ms13/suit/med)

/// Equipment for a mech's arm. It mounts like a gun, by using it on the mech, and a wrench takes it off.
/obj/item/ms13_mech_equipment
	icon = 'icons/mecha/mecha_equipment.dmi'
	w_class = WEIGHT_CLASS_BULKY
	/// Held down, it goes again after this long. Null goes once a click.
	var/repeat_delay
	COOLDOWN_DECLARE(next_use)

/// Works on target, beside mech, for pilot. FALSE when holding it down should stop.
/obj/item/ms13_mech_equipment/proc/action(obj/vehicle/sealed/ms13_mech/mech, atom/target, mob/living/pilot)
	return FALSE

/obj/item/ms13_mech_equipment/clamp
	name = "mech clamp"
	desc = "A hydraulic clamp for a mech's arm. It picks up one thing at a time and holds it until it's set down."
	icon_state = "mecha_clamp"
	var/obj/item/held

/obj/item/ms13_mech_equipment/clamp/Destroy()
	held?.forceMove(drop_location())
	return ..()

/obj/item/ms13_mech_equipment/clamp/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != held)
		return
	held = null
	if(istype(loc, /obj/vehicle/sealed/ms13_mech))
		loc.update_appearance()

/// Picks up a loose item, or sets down the one it holds on target's tile.
/obj/item/ms13_mech_equipment/clamp/action(obj/vehicle/sealed/ms13_mech/mech, atom/target, mob/living/pilot)
	if(!COOLDOWN_FINISHED(src, next_use))
		return TRUE
	var/obj/item/thing = target
	if(held)
		var/turf/spot = get_turf(target)
		if(spot.density)
			mech.balloon_alert(pilot, "no room!")
			return FALSE
		held.forceMove(spot)
	else if(istype(thing) && !thing.anchored && isturf(thing.loc))
		thing.forceMove(src)
		held = thing
		mech.update_appearance()
	else
		mech.balloon_alert(pilot, "can't grab that!")
		return FALSE
	COOLDOWN_START(src, next_use, 1 SECONDS)
	playsound(mech, 'sound/mecha/hydraulic.ogg', 50, TRUE)
	return TRUE

/// Bites into whatever it's held against, again and again for as long as it's held down.
/obj/item/ms13_mech_equipment/drill
	name = "mech drill"
	desc = "A heavy drill for a mech's arm. Held against something, it grinds away at it a bite at a time."
	icon_state = "mecha_drill"
	repeat_delay = 0.7 SECONDS
	/// Damage a bite does to someone, through their armor, and to anything else.
	var/mob_damage = 10
	var/object_damage = 15

/obj/item/ms13_mech_equipment/drill/action(obj/vehicle/sealed/ms13_mech/mech, atom/target, mob/living/pilot)
	var/mob/living/victim = target
	if(istype(victim))
		if(HAS_TRAIT(pilot, TRAIT_PACIFISM))
			to_chat(pilot, span_warning("You don't want to harm other living beings!"))
			return FALSE
		var/zone = ran_zone(BODY_ZONE_CHEST)
		victim.apply_damage(mob_damage, BRUTE, zone, victim.run_armor_check(zone, BLUNT))
		log_combat(pilot, victim, "drilled", src)
	else if(target.uses_integrity && target.get_integrity() > 0 && !(target.resistance_flags & INDESTRUCTIBLE))
		target.take_damage(object_damage, BRUTE, NONE, FALSE, get_dir(target, mech))
	else
		return TRUE
	mech.do_attack_animation(target)
	playsound(mech, 'sound/weapons/drill.ogg', 40, TRUE)
	return TRUE

TYPEINFO_DEF(/obj/vehicle/sealed/ms13_mech/durand)
	default_armor = list(BLUNT = 40, PUNCTURE = 35, SLASH = 0, LASER = 15, ENERGY = 10, BOMB = 20, BIO = 0, FIRE = 100, ACID = 100)

/obj/vehicle/sealed/ms13_mech/durand
	name = "\improper Durand"
	desc = "A heavy security mech from before the war. A corporate logo still shows through the paint on its chest plate. Things like it once stood guard over company campuses and the gated homes of the very rich."
	icon_state = "durand"
	base_icon_state = "durand"
	max_integrity = 400
	movedelay = 4
	max_occupants = 2
	mass = 3000

TYPEINFO_DEF(/obj/vehicle/sealed/ms13_mech/gygax)
	default_armor = list(BLUNT = 25, PUNCTURE = 20, SLASH = 0, LASER = 30, ENERGY = 15, BOMB = 0, BIO = 0, FIRE = 100, ACID = 100)

/obj/vehicle/sealed/ms13_mech/gygax
	name = "\improper Gygax"
	desc = "A light security mech from before the war. Someone scraped the police decals off, but not well. Its plating was only ever meant to turn back a crowd."
	icon_state = "gygax"
	base_icon_state = "gygax"
	max_integrity = 250
	movedelay = 3
	step_energy_drain = 3
	mass = 1500

TYPEINFO_DEF(/obj/vehicle/sealed/ms13_mech/ripley)
	default_armor = list(BLUNT = 40, PUNCTURE = 20, SLASH = 0, LASER = 10, ENERGY = 20, BOMB = 40, BIO = 0, FIRE = 100, ACID = 100)

/obj/vehicle/sealed/ms13_mech/ripley
	name = "\improper Ripley MK-I"
	desc = "A pre-war power loader, open to the air. The load limits stenciled on its arms are still legible. It was built to move freight."
	icon_state = "ripley"
	base_icon_state = "ripley"
	max_integrity = 200
	movedelay = 2
	mass = 1500
	enter_delay = 1 SECONDS
	open_cockpit = TRUE
	stepsound = 'sound/mecha/powerloader_step.ogg'
	turnsound = 'sound/mecha/powerloader_turn2.ogg'

TYPEINFO_DEF(/obj/vehicle/sealed/ms13_mech/ripley/mk2)
	default_armor = list(BLUNT = 40, PUNCTURE = 30, SLASH = 0, LASER = 30, ENERGY = 30, BOMB = 60, BIO = 0, FIRE = 100, ACID = 100)

/obj/vehicle/sealed/ms13_mech/ripley/mk2
	name = "\improper Ripley MK-II"
	desc = "A pre-war power loader with a sealed cab welded over the seat. Somebody wanted more between them and whatever they were digging into."
	icon_state = "ripleymkii"
	base_icon_state = "ripleymkii"
	max_integrity = 250
	movedelay = 4
	mass = 2000
	enter_delay = 4 SECONDS
	open_cockpit = FALSE

#ifdef UNIT_TESTS
/// A Durand's arms fire the guns mounted on them and work their actions; the autoloader swaps magazines; rounds that
/// get through the plate hit the pilot; and knocked out, it wrecks with the pilot still inside, until it's welded up.
/datum/unit_test/ms13_mech
	name = "MECHS: A Durand Fires Its Arm Guns and Wrecks Rather Than Breaking"

/datum/unit_test/ms13_mech/Run()
	var/obj/vehicle/sealed/ms13_mech/durand/mech = allocate(/obj/vehicle/sealed/ms13_mech/durand, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z))
	mech.setDir(NORTH)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent)
	mech.mob_enter(pilot, TRUE)
	var/turf/ahead = get_step(get_step(mech, NORTH), NORTH)

	// A bolt action fires one round, then works its own bolt.
	var/obj/item/gun/ballistic/rifle/ms13/hunting/rifle = allocate(/obj/item/gun/ballistic/rifle/ms13/hunting)
	rifle.forceMove(mech)
	mech.mount(rifle, MS13_MECH_RIGHT_ARM)
	var/in_magazine = rifle.magazine.ammo_count()
	if(!mech.use_arm(MS13_MECH_RIGHT_ARM, ahead, pilot) || !rifle.chambered || rifle.chambered.loaded_projectile)
		Fail("A mounted bolt action didn't fire, leaving its spent case in.")
	mech.finish_cycling(rifle)
	if(!rifle.chambered?.loaded_projectile || rifle.magazine.ammo_count() != in_magazine - 1 || rifle.bolt.is_locked || rifle.loc != mech)
		Fail("A mounted bolt action didn't work its bolt onto the next round.")

	// Run dry, the autoloader swaps in a full magazine that fits.
	var/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle/automatic = allocate(/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle)
	automatic.forceMove(mech)
	mech.mount(automatic, MS13_MECH_LEFT_ARM)
	var/obj/item/ms13_mech_autoloader/loader = allocate(/obj/item/ms13_mech_autoloader)
	var/obj/item/ammo_box/magazine/ms13/r20/fresh = allocate(/obj/item/ammo_box/magazine/ms13/r20)
	loader.atom_storage.attempt_insert(fresh, override = TRUE)
	loader.forceMove(mech)
	mech.autoloader = loader
	var/obj/item/ammo_box/magazine/spent = automatic.magazine
	QDEL_LIST(spent.stored_ammo)
	QDEL_NULL(automatic.chambered)
	mech.autoload(automatic)
	if(automatic.magazine != fresh || !automatic.chambered?.loaded_projectile || spent.loc != mech.loc)
		Fail("The autoloader didn't swap a full magazine into a dry gun and drop the empty.")

	// Its own shots don't hit it, and the gun stays on the arm.
	var/obj/projectile/own = new /obj/projectile/bullet(mech.loc)
	own.impacted = list()
	SEND_SIGNAL(automatic, COMSIG_PROJECTILE_BEFORE_FIRE, own, ahead)
	if(!own.impacted[mech])
		Fail("A mounted gun's round could hit its own mech.")
	qdel(own)
	if(automatic.safe_throw_at(ahead, 1, 2) || automatic.loc != mech)
		Fail("A mounted gun could be thrown out of its mech.")

	// What gets through the plate hits the pilot; the front plate stops what the back lets through.
	if(!hit_through(mech, pilot, SOUTH) || hit_through(mech, pilot, NORTH))
		Fail("Rounds through a mech's back plate didn't hit its pilot, or ones on its front plate did.")

	// A civilian Gygax's front plate doesn't stop a rifle round.
	var/obj/vehicle/sealed/ms13_mech/gygax/gygax = allocate(/obj/vehicle/sealed/ms13_mech/gygax, locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z))
	gygax.setDir(NORTH)
	var/mob/living/carbon/human/guard = allocate(/mob/living/carbon/human/consistent)
	gygax.mob_enter(guard, TRUE)
	var/obj/projectile/bullet/ms13/a762/rifle_round = new(get_step(gygax, NORTH))
	rifle_round.setDir(SOUTH)
	rifle_round.penetrating_hit(gygax, BODY_ZONE_CHEST)
	qdel(rifle_round)
	if(!guard.getBruteLoss())
		Fail("A rifle round on a Gygax's front plate didn't reach its pilot.")

	// Knocked out, it wrecks: the pilot stays in, it won't walk, and it can be climbed. Welded up, it walks again.
	mech.take_damage(100000)
	mech.take_damage(100)
	if(QDELETED(mech) || !mech.wrecked || !mech.is_occupant(pilot) || mech.vehicle_move(EAST))
		Fail("A knocked out mech didn't stand wrecked, pilot inside and unable to walk.")
	mech.repair_damage(mech.max_integrity)
	if(mech.wrecked)
		Fail("A mech welded back to full integrity stayed wrecked.")

	// Taken off, a gun leaves the arm, unbraced.
	automatic.forceMove(mech.loc)
	if(mech.arms[MS13_MECH_LEFT_ARM] || automatic.wielded)
		Fail("A gun taken off a mech stayed on its arm, or braced.")

	// A clamp picks up a loose item beside it and shows it on its side; clicked on a tile, it sets it down there.
	rifle.forceMove(mech.loc)
	var/obj/item/ms13_mech_equipment/clamp/clamp = allocate(/obj/item/ms13_mech_equipment/clamp)
	clamp.forceMove(mech)
	mech.mount(clamp, MS13_MECH_LEFT_ARM)
	var/turf/front = get_step(mech, NORTH)
	var/obj/item/wrench/cargo = allocate(/obj/item/wrench, front)
	if(!mech.use_arm(MS13_MECH_LEFT_ARM, cargo, pilot) || clamp.held != cargo || cargo.loc != clamp || !length(mech.overlays))
		Fail("A mech's clamp didn't pick up a loose item and show it on the mech.")
	COOLDOWN_RESET(clamp, next_use)
	var/turf/beside = get_step(front, EAST)
	if(!mech.use_arm(MS13_MECH_LEFT_ARM, beside, pilot) || cargo.loc != beside || clamp.held)
		Fail("A mech's clamp didn't set what it held down where it was clicked.")

	// A drill bites into a wall beside it.
	var/obj/item/ms13_mech_equipment/drill/drill = allocate(/obj/item/ms13_mech_equipment/drill)
	drill.forceMove(mech)
	mech.mount(drill, MS13_MECH_RIGHT_ARM)
	var/turf/closed/wall/wall = front.ChangeTurf(/turf/closed/wall)
	var/wall_integrity = wall.get_integrity()
	if(!mech.use_arm(MS13_MECH_RIGHT_ARM, wall, pilot) || wall.get_integrity() >= wall_integrity)
		Fail("A mech's drill didn't bite into a wall.")
	wall.ChangeTurf(/turf/open/floor/iron)

	// It opens a door beside it, as a person would, after a moment.
	var/obj/machinery/door/unpowered/ms13/metal/door = allocate(/obj/machinery/door/unpowered/ms13/metal, front)
	mech.work_door(door, pilot)
	if(door.density)
		Fail("A mech couldn't open a door beside it.")
	qdel(door)

	// Someone loaded in rides along: the driver keeps the controls.
	var/mob/living/carbon/human/passenger = allocate(/mob/living/carbon/human/consistent)
	mech.loading = passenger
	mech.mob_enter(passenger, TRUE)
	mech.loading = null
	if(!mech.is_occupant(passenger) || mech.is_driver(passenger) || !mech.is_driver(pilot) || mech.use_arm(MS13_MECH_RIGHT_ARM, beside, passenger))
		Fail("Someone loaded into a mech took its controls, or its driver lost them.")
	mech.mob_exit(passenger, TRUE)

	// A light cart ramming it only dents it; a heavy truck knocks it back a tile, still facing the same way.
	var/obj/structure/ms13_vehicle_frame/bumper = allocate(/obj/structure/ms13_vehicle_frame, get_step(mech, SOUTH))
	// Tough enough not to break on the mech, so the heavy truck carries on.
	bumper.modify_max_integrity(100000)
	var/datum/ms13_ground_vehicle/truck = new
	bumper.vehicle = truck
	truck.pivot = bumper
	truck.frames += bumper
	truck.mass_per_frame = 100
	truck.speed = 1
	var/turf/rammed_at = get_turf(mech)
	var/before_ram = mech.get_integrity()
	truck.damage_collision(mech, bumper, NORTH)
	if(get_turf(mech) != rammed_at || mech.get_integrity() >= before_ram)
		Fail("A light cart knocked a mech back, or didn't dent it.")
	truck.mass_per_frame = 100000
	truck.speed = 1
	truck.impact_energy_reserve = null
	truck.damage_collision(mech, bumper, NORTH)
	if(get_turf(mech) != get_step(rammed_at, NORTH) || mech.dir != NORTH)
		Fail("A heavy truck ramming a mech didn't knock it back a tile, facing the way it was.")
	qdel(bumper)

	// An open cockpit: a round at the chest finds the pilot, not the frame.
	var/obj/vehicle/sealed/ms13_mech/ripley/open_loader = allocate(/obj/vehicle/sealed/ms13_mech/ripley, locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z))
	open_loader.setDir(NORTH)
	var/mob/living/carbon/human/driver = allocate(/mob/living/carbon/human/consistent)
	open_loader.mob_enter(driver, TRUE)
	var/obj/projectile/bullet/ms13/c9mm/pistol_round = new(get_step(open_loader, NORTH))
	pistol_round.setDir(SOUTH)
	pistol_round.penetrating_hit(open_loader, BODY_ZONE_CHEST)
	qdel(pistol_round)
	if(!driver.getBruteLoss() || open_loader.get_integrity() < open_loader.max_integrity)
		Fail("A round at an open cockpit's pilot hit the frame instead.")

/// Fires a rifle round into mech's back (SOUTH, travelling north) or front. TRUE if its pilot was hurt.
/datum/unit_test/ms13_mech/proc/hit_through(obj/vehicle/sealed/ms13_mech/mech, mob/living/carbon/human/pilot, from_dir)
	pilot.fully_heal()
	var/obj/projectile/bullet/round = new(get_step(mech, from_dir))
	round.damage = MED_RIFLE_DAMAGE
	round.speed = 0.5
	round.setDir(REVERSE_DIR(from_dir))
	round.penetrating_hit(mech, BODY_ZONE_CHEST)
	qdel(round)
	return pilot.getBruteLoss() > 0
#endif

#undef MS13_MECH_LEFT_ARM
#undef MS13_MECH_RIGHT_ARM
