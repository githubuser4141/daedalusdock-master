#define MS13_MECH_LEFT_ARM "left arm"
#define MS13_MECH_RIGHT_ARM "right arm"

/**
 * A walking armored shell for one pilot, with ordinary guns bolted to its arms.
 *
 * Built on sealed vehicles rather than /mecha: there's no cabin air, malfunction, stock part or control panel to
 * switch off, and nothing processing while it stands idle. The pilot breathes the air outside, as on foot.
 * Everything else is done from outside, by hand: use a gun on it to mount it, a wrench to take one off, magazines
 * to reload, a crowbar for the battery and a welder for repairs.
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
	/// The gun on each arm. The pilot fires the left with a left click and the right with a right click.
	var/list/arms = list(MS13_MECH_LEFT_ARM = null, MS13_MECH_RIGHT_ARM = null)
	var/obj/item/ms13_mech_autoloader/autoloader
	/// Knocked out: it stands where it fell, climbable, until it's welded back up. Whoever's inside stays inside.
	var/wrecked = FALSE
	/// The pilot's client, whose mouse buttons fire the arms.
	var/client/pilot_client
	/// Arms held down on automatic: arm = list(target, click params, the target's turf when aimed). A new list each press.
	var/list/autofiring
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
		if(gun)
			var/rounds = gun.get_ammo(FALSE) + !!gun.chambered?.loaded_projectile
			. += "On its [arm]: [gun], with [rounds] round\s left."
	if(autoloader)
		. += "An autoloader on its back holds [length(autoloader.contents)] magazine\s."
	. += cell ? "Its battery reads [round(cell.percent())]%." : span_warning("It has no battery.")

/obj/vehicle/sealed/ms13_mech/update_icon_state()
	icon_state = wrecked ? "[base_icon_state]-broken" : (LAZYLEN(occupants) ? base_icon_state : "[base_icon_state]-open")
	return ..()

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
	RegisterSignal(M, COMSIG_MOB_CLICKON, PROC_REF(on_click))
	RegisterSignal(M, COMSIG_MOB_LOGIN, PROC_REF(grab_mouse))
	RegisterSignal(M, COMSIG_MOB_LOGOUT, PROC_REF(release_mouse))
	RegisterSignal(M, COMSIG_LIVING_DEATH, PROC_REF(mob_exit))
	grab_mouse(M)
	update_appearance()

/obj/vehicle/sealed/ms13_mech/remove_occupant(mob/M)
	if(ismob(M))
		UnregisterSignal(M, list(COMSIG_MOB_CLICKON, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH))
		release_mouse()
	. = ..()
	update_appearance()

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
			var/obj/item/gun/ballistic/gun = gone
			arms[arm] = null
			gun.wielded = FALSE
			UnregisterSignal(gun, list(COMSIG_PROJECTILE_BEFORE_FIRE, COMSIG_MOVABLE_PRE_THROW))
			LAZYREMOVE(autofiring, arm)
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
	if(istype(tool, /obj/item/gun/ballistic))
		var/arm = !arms[MS13_MECH_LEFT_ARM] ? MS13_MECH_LEFT_ARM : (!arms[MS13_MECH_RIGHT_ARM] ? MS13_MECH_RIGHT_ARM : null)
		if(!arm)
			balloon_alert(user, "both arms are armed!")
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

/// A wrench takes a gun or the autoloader off whole.
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

/obj/vehicle/sealed/ms13_mech/crowbar_act(mob/living/user, obj/item/tool)
	if(!cell)
		balloon_alert(user, "no battery!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "prying the battery out...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50) || !cell)
		return ITEM_INTERACT_BLOCKING
	user.put_in_hands(cell)
	return ITEM_INTERACT_SUCCESS

/// Bolts gun, already inside, onto arm.
/obj/vehicle/sealed/ms13_mech/proc/mount(obj/item/gun/ballistic/gun, arm)
	arms[arm] = gun
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
		if(!gun || (is_magazine ? (gun.internal_magazine || !istype(ammo, gun.mag_type)) : !(gun.internal_magazine || istype(gun.bolt, /datum/gun_bolt/no_bolt))))
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
	if(!autoloader || gun?.loc != src || gun.internal_magazine || gun.magazine?.ammo_count())
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

// Firing

/// Pulls the trigger of arm's gun at target. FALSE when it can't fire any more, such as when it's run dry.
/obj/vehicle/sealed/ms13_mech/proc/fire_arm(arm, atom/target, mob/living/pilot, params)
	var/obj/item/gun/ballistic/gun = arms[arm]
	if(!gun || wrecked || !cell?.charge || QDELETED(target) || !is_occupant(pilot) || pilot.incapacitated())
		return FALSE
	if(HAS_TRAIT(pilot, TRAIT_PACIFISM))
		to_chat(pilot, span_warning("You don't want to harm other living beings!"))
		return FALSE
	// The arms only swing so far.
	var/dir_to_target = get_dir(src, target)
	if(dir_to_target && !(dir_to_target & dir))
		return TRUE
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

/// A click fires the gun on that arm once. Automatics fire from on_mouse_down() instead, for as long as it's held.
/obj/vehicle/sealed/ms13_mech/proc/on_click(mob/living/user, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, MIDDLE_CLICK))
		return NONE
	if(target == src || (!isturf(target) && !isturf(target.loc)))
		return NONE
	var/arm = LAZYACCESS(modifiers, RIGHT_CLICK) ? MS13_MECH_RIGHT_ARM : MS13_MECH_LEFT_ARM
	var/obj/item/gun/gun = arms[arm]
	if(!gun || gun.GetComponent(/datum/component/automatic_fire))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(fire_arm), arm, target, user, list2params(modifiers))
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
	var/obj/item/gun/gun = arms[arm]
	if(!gun?.GetComponent(/datum/component/automatic_fire))
		return
	if(isnull(location) || istype(target, /atom/movable/screen))
		// Only the catcher behind the map: pressing on the HUD shouldn't open fire.
		if(target.plane != CLICKCATCHER_PLANE)
			return
		target = parse_caught_click_modifiers(modifiers, get_turf(source.eye), source)
		params = list2params(modifiers)
	if(!target || target == src)
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

/// Keeps firing arm while aim is still the press held on it, at the gun's own automatic rate.
/obj/vehicle/sealed/ms13_mech/proc/autofire(arm, list/aim)
	if(LAZYACCESS(autofiring, arm) != aim)
		return
	var/obj/item/gun/gun = arms[arm]
	var/datum/component/automatic_fire/automatic = gun?.GetComponent(/datum/component/automatic_fire)
	var/atom/target = aim[1]
	// Like a held automatic, it keeps on the tile it was aimed at rather than following whatever walks off it.
	if(QDELETED(target) || get_turf(target) != aim[3])
		target = aim[3]
	if(!automatic || !fire_arm(arm, target, pilot_client?.mob, aim[2]))
		LAZYREMOVE(autofiring, arm)
		return
	addtimer(CALLBACK(src, PROC_REF(autofire), arm, aim), automatic.autofire_shot_delay)

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

TYPEINFO_DEF(/obj/vehicle/sealed/ms13_mech/durand)
	default_armor = list(BLUNT = 40, PUNCTURE = 35, SLASH = 0, LASER = 15, ENERGY = 10, BOMB = 20, BIO = 0, FIRE = 100, ACID = 100)

/obj/vehicle/sealed/ms13_mech/durand
	name = "\improper Durand"
	desc = "A heavy security mech from before the war. A corporate logo still shows through the paint on its chest plate. Things like it once stood guard over company campuses and the gated homes of the very rich."
	icon_state = "durand"
	base_icon_state = "durand"
	max_integrity = 400
	movedelay = 4

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
	if(!mech.fire_arm(MS13_MECH_RIGHT_ARM, ahead, pilot) || !rifle.chambered || rifle.chambered.loaded_projectile)
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
