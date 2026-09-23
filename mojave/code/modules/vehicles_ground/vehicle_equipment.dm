/**
 * Equipment a vehicle can carry beyond what drives it: a welding set, a smoke generator, a roof solar panel, freezers, a
 * recharge station, external fuel tanks and a scoop. Each is fitted at assembly, or mapped/spawned onto a vehicle's floor
 * to fit itself there. The freezers and recharge station run off the battery with the ignition off, until it's flat
 * unless a low-voltage cut-out is fitted.
 */

/// A welding set bolted into the vehicle, its torch on a hose. The arc runs off the vehicle's battery.
/obj/structure/ms13_vehicle_part/welding_rig
	name = "vehicle welding set"
	desc = "An arc welder bolted into the vehicle and run off its battery. Take the torch to use it: the hose only reaches so far, and it winds back in when you let go."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/vehicle_equipment.dmi'
	icon_state = "vp_welding_rig_#0"
	max_integrity = 100
	fits_itself = TRUE
	var/obj/item/weldingtool/ms13/vehicle/torch
	/// Tiles the hose reaches from the set.
	var/hose_length = 5

/obj/structure/ms13_vehicle_part/welding_rig/Initialize(mapload)
	. = ..()
	torch = new(src)
	torch.rig = src

/obj/structure/ms13_vehicle_part/welding_rig/Destroy()
	QDEL_NULL(torch)
	return ..()

/obj/structure/ms13_vehicle_part/welding_rig/detach()
	torch?.wind_in()
	return ..()

/obj/structure/ms13_vehicle_part/welding_rig/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(torch?.loc != src)
		balloon_alert(user, "the torch is out!")
		return TRUE
	if(!user.put_in_hands(torch))
		balloon_alert(user, "free a hand!")
	return TRUE

/obj/structure/ms13_vehicle_part/welding_rig/attackby(obj/item/used_item, mob/user, params)
	if(used_item != torch)
		return ..()
	torch.wind_in()
	return TRUE

/// The vehicle may drive off from someone standing outside with the torch.
/obj/structure/ms13_vehicle_part/welding_rig/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(torch && torch.loc != src)
		// After the rest of the vehicle and its riders have moved too.
		addtimer(CALLBACK(torch, TYPE_PROC_REF(/obj/item/weldingtool/ms13/vehicle, check_range)), 1, TIMER_UNIQUE)

/obj/structure/ms13_vehicle_part/welding_rig/examine(mob/user)
	. = ..()
	. += span_notice("It runs off the battery, [vehicle?.battery?.cell ? "at [round(vehicle.battery.cell.percent())]%" : "which is missing"]. The ignition has to be on.")

/// The welding set's torch. It burns battery charge rather than fuel, and snaps back to the set past the hose's reach.
/obj/item/weldingtool/ms13/vehicle
	name = "vehicle welding torch"
	desc = "A welding torch on a hose back to its vehicle's welding set. It runs off the vehicle's battery."
	w_class = WEIGHT_CLASS_HUGE
	var/obj/structure/ms13_vehicle_part/welding_rig/rig
	/// Battery charge the arc burns for each unit of welding fuel it stands in for.
	var/charge_per_fuel = 25

/obj/item/weldingtool/ms13/vehicle/Destroy()
	if(rig?.torch == src)
		rig.torch = null
	rig = null
	return ..()

/obj/item/weldingtool/ms13/vehicle/get_fuel()
	var/datum/ms13_ground_vehicle/vehicle = rig?.vehicle
	var/obj/item/stock_parts/cell/cell = vehicle?.has_electrical_power() && vehicle.battery.cell
	max_fuel = cell ? round(cell.maxcharge / charge_per_fuel) : 0
	return cell ? round(cell.charge / charge_per_fuel) : 0

/obj/item/weldingtool/ms13/vehicle/use(used = 0)
	if(!isOn() || !check_fuel())
		return FALSE
	if(used > 0)
		burned_fuel_for = 0
	return !used || rig?.vehicle?.use_battery(used * charge_per_fuel)

/obj/item/weldingtool/ms13/vehicle/equipped(mob/user, slot)
	. = ..()
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(check_range), override = TRUE)

/obj/item/weldingtool/ms13/vehicle/unequipped(mob/user)
	. = ..()
	if(user)
		UnregisterSignal(user, COMSIG_MOVABLE_MOVED)
	wind_in()

/obj/item/weldingtool/ms13/vehicle/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	check_range()

/obj/item/weldingtool/ms13/vehicle/proc/check_range()
	SIGNAL_HANDLER
	if(!rig || loc == rig)
		return
	var/turf/here = get_turf(src)
	if(here?.z == rig.z && get_dist(here, rig) <= rig.hose_length)
		return
	if(isliving(loc))
		to_chat(loc, span_warning("[src]'s hose pulls taut and yanks it out of your hands!"))
	wind_in()

/// Back into the welding set, switched off.
/obj/item/weldingtool/ms13/vehicle/proc/wind_in()
	if(QDELETED(rig) || loc == rig)
		return
	if(welding)
		switched_off()
	forceMove(rig)

/obj/effect/particle_effect/fluid/smoke/ms13_vehicle
	lifetime = 25 SECONDS

/// Sprays fuel into the hot exhaust to lay a smoke screen, out through the hull edge it faces.
/obj/structure/ms13_vehicle_part/smoke_generator
	name = "smoke generator"
	desc = "Sprays fuel into the hot exhaust to lay a thick smoke screen. The driver sets it off from the controls, with the engine running."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "smoke0"
	max_integrity = 80
	fits_itself = TRUE
	/// Fuel burnt for each screen.
	var/fuel_cost = 4
	/// Tiles the screen spreads from the exhaust.
	var/spread = 5
	var/cooldown = 40 SECONDS
	COOLDOWN_DECLARE(next_screen)

/obj/structure/ms13_vehicle_part/smoke_generator/proc/discharge(mob/user)
	if(!is_operational())
		to_chat(user, span_warning("The smoke generator is wrecked."))
		return FALSE
	if(!COOLDOWN_FINISHED(src, next_screen))
		to_chat(user, span_warning("The smoke generator is still building pressure."))
		return FALSE
	if(!vehicle?.engine_running)
		to_chat(user, span_warning("Start the engine: the smoke generator works off the hot exhaust."))
		return FALSE
	var/obj/structure/ms13_vehicle_part/fuel_tank/tank = vehicle.fuel_tank
	if(!tank?.reagents || tank.reagents.get_reagent_amount(/datum/reagent/fuel) < fuel_cost)
		to_chat(user, span_warning("There isn't enough fuel for a smoke screen."))
		return FALSE
	tank.draw_fuel(fuel_cost)
	COOLDOWN_START(src, next_screen, cooldown)
	do_smoke(spread, holder = src, location = get_step(src, dir), smoke_type = /obj/effect/particle_effect/fluid/smoke/ms13_vehicle)
	playsound(src, 'sound/effects/smoke.ogg', 50, TRUE)
	vehicle.pivot.visible_message(span_warning("Thick smoke billows out of [vehicle.pivot]!"))
	return TRUE

/// A roof panel that trickle-charges the battery from the sun, ignition on or off.
/obj/structure/ms13_vehicle_part/exterior_equipment/solar_panel
	name = "vehicle solar panel"
	desc = "A solar panel bolted flat to the roof. It trickle-charges the battery in daylight."
	equipment_icon = 'mojave/icons/cdda_ultimate_cataclysm/vehicle_equipment_32x48.dmi'
	on_state = "vp_solar_panel_#0"
	off_state = "vp_solar_panel_#0"
	power_draw = 0
	max_integrity = 60
	fits_itself = TRUE
	/// Charge a second in full noon sun.
	var/output = 4

/obj/structure/ms13_vehicle_part/exterior_equipment/solar_panel/setDir(new_dir)
	. = ..()
	if(exterior_image)
		exterior_image.pixel_x = 0
		exterior_image.pixel_y = 0

/// It lies on the roof, so no hull panel carries it.
/obj/structure/ms13_vehicle_part/exterior_equipment/solar_panel/lose_support()
	return

/**
 * The share of full sun on it, 0 to 1: the brightness of the sky's light at this time of day, from white at noon
 * through the colours of sunrise and sunset to near black at midnight. Sunlight is its own light, apart from lamps
 * and headlights, so those never charge it.
 */
/obj/structure/ms13_vehicle_part/exterior_equipment/solar_panel/proc/sunlight()
	var/turf/ground = get_turf(src)
	var/datum/time_of_day/sky = SSoutdoor_effects.current_step_datum
	if(!is_operational() || !sky || !ground?.outdoor_effect || ground.outdoor_effect.state == SKY_BLOCKED)
		return 0
	var/list/rgb = rgb2num(sky.color)
	return (0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]) / 255

/obj/structure/ms13_vehicle_part/exterior_equipment/solar_panel/examine(mob/user)
	. = ..()
	. += span_notice("It's catching [round(sunlight() * 100)]% of full sun.")

/// A chest freezer on the battery. While it has power, organs kept in it don't decay.
/obj/structure/ms13_vehicle_part/stowage/freezer
	name = "vehicle chest freezer"
	desc = "A chest freezer wired to the vehicle's battery. Organs kept in it don't decay while it runs, ignition on or off, until the battery's flat."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/vehicle_equipment.dmi'
	icon_state = "vp_ap_chest_freezer"
	max_integrity = 120
	fits_itself = TRUE
	slots = 12
	/// Charge a second it draws while running.
	var/power_draw = 3
	var/cold = FALSE

/// Runs off the battery for a while, if the battery can spare it.
/obj/structure/ms13_vehicle_part/stowage/freezer/proc/chill(seconds_per_tick)
	var/now_cold = is_operational() && vehicle?.use_spare_charge(power_draw * seconds_per_tick)
	if(cold == now_cold)
		return
	cold = now_cold
	for(var/obj/item/organ/organ in src)
		set_frozen(organ, cold)

/obj/structure/ms13_vehicle_part/stowage/freezer/proc/set_frozen(obj/item/organ/organ, frozen)
	if(frozen)
		organ.organ_flags |= ORGAN_FROZEN
	else
		organ.organ_flags &= ~ORGAN_FROZEN

/obj/structure/ms13_vehicle_part/stowage/freezer/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(isorgan(arrived))
		set_frozen(arrived, cold)

/obj/structure/ms13_vehicle_part/stowage/freezer/Exited(atom/movable/gone, direction)
	. = ..()
	if(isorgan(gone))
		set_frozen(gone, FALSE)

/obj/structure/ms13_vehicle_part/stowage/freezer/examine(mob/user)
	. = ..()
	. += span_notice(cold ? "It's running cold." : "It isn't running.")

/obj/structure/ms13_vehicle_part/stowage/freezer/mini
	name = "vehicle minifreezer"
	desc = "A small freezer box wired to the vehicle's battery. Organs kept in it don't decay while it runs, ignition on or off, until the battery's flat."
	icon_state = "vp_minifreezer_#0"
	max_integrity = 80
	slots = 4
	max_item_size = WEIGHT_CLASS_NORMAL
	power_draw = 1

/// Charges anything put in it that runs on a cell, off the battery.
/obj/structure/ms13_vehicle_part/stowage/recharge_station
	name = "vehicle recharge station"
	desc = "A charging rack wired to the vehicle's battery. Cells, and anything put in it that runs on one, charge off the battery, ignition on or off, until the battery's flat."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/vehicle_equipment.dmi'
	icon_state = "vp_recharge_station_#0"
	max_integrity = 80
	fits_itself = TRUE
	slots = 4
	max_item_size = WEIGHT_CLASS_NORMAL
	/// Charge a second it gives each thing in it.
	var/charge_rate = 50

/obj/structure/ms13_vehicle_part/stowage/recharge_station/proc/recharge(seconds_per_tick)
	if(!is_operational())
		return
	for(var/obj/item/thing in src)
		var/obj/item/stock_parts/cell/cell = thing.get_cell()
		var/amount = cell ? min(charge_rate * seconds_per_tick, cell.maxcharge - cell.charge) : 0
		if(amount <= 0)
			continue
		if(!vehicle?.use_spare_charge(amount))
			return
		cell.give(amount)
		thing.update_appearance()

/// A spare tank strapped to the outside of the hull. It feeds the vehicle's own tank as that's drawn down.
/obj/structure/ms13_vehicle_part/exterior_equipment/fuel_tank
	name = "external fuel tank"
	desc = "A spare fuel tank strapped to the outside of the hull. It feeds the vehicle's own tank as that's drawn down. Pour fuel in to fill it."
	equipment_icon = 'mojave/icons/cdda_ultimate_cataclysm/vehicle_equipment.dmi'
	rotated_art = "vp_external_tank"
	on_state = "vp_external_tank_#0"
	off_state = "vp_external_tank_#0"
	power_draw = 0
	max_integrity = 80
	fits_itself = TRUE
	var/capacity = 60

/obj/structure/ms13_vehicle_part/exterior_equipment/fuel_tank/Initialize(mapload)
	. = ..()
	create_reagents(capacity, OPENCONTAINER)

/obj/structure/ms13_vehicle_part/exterior_equipment/fuel_tank/configure_from_vehicle()
	. = ..()
	if(stock_on_fit)
		reagents.add_reagent(/datum/reagent/fuel, capacity)

/obj/structure/ms13_vehicle_part/exterior_equipment/fuel_tank/atom_break(damage_flag)
	. = ..()
	if(reagents.total_volume)
		visible_message(span_warning("[src] is punctured and its fuel pours out!"))
		reagents.clear_reagents()

/obj/structure/ms13_vehicle_part/exterior_equipment/fuel_tank/examine(mob/user)
	. = ..()
	. += span_notice("It holds [round(reagents.get_reagent_amount(/datum/reagent/fuel), 0.1)]/[reagents.maximum_volume] units of fuel.")
	if(broken)
		. += span_warning("It is punctured.")

/// Slung low off the edge of the hull, it sweeps small loose things up off the ground it faces as the vehicle drives.
/obj/structure/ms13_vehicle_part/exterior_equipment/scoop
	name = "vehicle scoop"
	desc = "A scoop slung low off the edge of the hull. As the vehicle drives, it sweeps small loose things off the ground it faces into its hopper. Click it to empty it."
	equipment_icon = 'mojave/icons/cdda_ultimate_cataclysm/vehicle_equipment.dmi'
	rotated_art = "vp_vehicle_scoop"
	on_state = "vp_vehicle_scoop_#0"
	off_state = "vp_vehicle_scoop_#0"
	power_draw = 0
	max_integrity = 80
	fits_itself = TRUE
	var/slots = 10

/obj/structure/ms13_vehicle_part/exterior_equipment/scoop/Initialize(mapload)
	. = ..()
	create_storage(max_slots = slots, max_specific_storage = WEIGHT_CLASS_NORMAL, max_total_storage = slots * WEIGHT_CLASS_NORMAL)

/obj/structure/ms13_vehicle_part/exterior_equipment/scoop/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(!vehicle?.moving || !is_operational())
		return
	for(var/obj/item/loose in get_step(src, dir))
		if(!loose.anchored && loose.w_class <= WEIGHT_CLASS_NORMAL)
			atom_storage.attempt_insert(loose, override = TRUE)

/**
 * A screen in the cabin showing the vehicle's cameras one at a time, in a window of its own: whoever watches it keeps
 * their own view as well. With a remote viewing module fitted, right-click it to look out through the camera instead, and
 * look about everything the vehicle's cameras take in, as with an advanced camera console.
 */
/obj/structure/ms13_vehicle_part/camera_console
	name = "vehicle camera console"
	desc = "A screen showing the vehicle's cameras, one at a time. It runs off the vehicle's power."
	icon = 'mojave/icons/structure/terminals.dmi'
	icon_state = "terminal"
	pixel_y = 8
	layer = BELOW_OBJ_LAYER
	max_integrity = 100
	fits_itself = TRUE
	var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/active_camera
	var/atom/movable/screen/map_view/byondui/camera/cam_screen
	/// Watching it, in its window.
	var/list/watchers
	/// A remote viewing module is fitted: right-click to look out through the cameras.
	var/remote_viewing = FALSE
	/// Looking out through the cameras: each one, and their eye.
	var/list/lookers

/obj/structure/ms13_vehicle_part/camera_console/Initialize(mapload)
	. = ..()
	cam_screen = new
	// A map name has to start and end with a letter.
	cam_screen.generate_view("ms13_vehicle_cameras_[REF(src)]_map")

/obj/structure/ms13_vehicle_part/camera_console/Destroy()
	QDEL_NULL(cam_screen)
	return ..()

/obj/structure/ms13_vehicle_part/camera_console/detach()
	for(var/mob/living/looker as anything in lookers)
		stop_looking(looker)
	set_camera(null)
	return ..()

/obj/structure/ms13_vehicle_part/camera_console/proc/is_powered()
	return is_operational() && vehicle?.has_electrical_power()

/obj/structure/ms13_vehicle_part/camera_console/update_overlays()
	. = ..()
	if(is_powered())
		. += mutable_appearance(icon, "terminal_screen")
		. += emissive_appearance(icon, "terminal_screen", alpha = 180)

/// Power came or went: dark, it shows nothing and nobody looks out through it.
/obj/structure/ms13_vehicle_part/camera_console/proc/power_changed()
	update_appearance()
	if(!is_powered())
		for(var/mob/living/looker as anything in lookers)
			stop_looking(looker)
	show_feed()

/obj/structure/ms13_vehicle_part/camera_console/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	ui_interact(user)
	return TRUE

/obj/structure/ms13_vehicle_part/camera_console/attack_hand_secondary(mob/living/user, list/modifiers)
	if(!remote_viewing)
		balloon_alert(user, "no remote viewing module!")
	else if(LAZYACCESS(lookers, user))
		stop_looking(user)
	else
		start_looking(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/structure/ms13_vehicle_part/camera_console/attackby(obj/item/used_item, mob/user, params)
	if(!istype(used_item, /obj/item/ms13_remote_viewing_module))
		return ..()
	if(remote_viewing)
		balloon_alert(user, "already fitted!")
		return TRUE
	qdel(used_item)
	remote_viewing = TRUE
	balloon_alert(user, "remote viewing fitted")
	playsound(src, 'sound/items/screwdriver.ogg', 40, TRUE)
	return TRUE

/obj/structure/ms13_vehicle_part/camera_console/examine(mob/user)
	. = ..()
	. += span_notice(remote_viewing ? "A remote viewing module is fitted: right-click it to look out through the cameras." : "A remote viewing module would let you look out through the cameras.")

/// Worked from inside the vehicle only.
/obj/structure/ms13_vehicle_part/camera_console/ui_status(mob/user, datum/ui_state/state)
	if(!isobserver(user) && (get_ms13_ground_vehicle_at(user) != vehicle || (user in vehicle?.underneath)))
		return UI_CLOSE
	return ..()

/obj/structure/ms13_vehicle_part/camera_console/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "CameraConsole", name)
	ui.open()
	cam_screen.render_to_tgui(user.client, ui.window)
	LAZYOR(watchers, user)
	show_feed()

/obj/structure/ms13_vehicle_part/camera_console/ui_close(mob/user)
	. = ..()
	cam_screen?.hide_from_client(user.client)
	LAZYREMOVE(watchers, user)
	if(!LAZYLEN(watchers) && !LAZYLEN(lookers))
		set_camera(null)

/obj/structure/ms13_vehicle_part/camera_console/ui_static_data(mob/user)
	var/list/data = list()
	data["mapRef"] = cam_screen.assigned_map
	data["cameras"] = list()
	for(var/feed in cameras())
		data["cameras"] += list(list("name" = feed))
	return data

/obj/structure/ms13_vehicle_part/camera_console/ui_data(mob/user)
	var/list/data = list()
	data["activeCamera"] = active_camera ? list("name" = feed_name_of(active_camera)) : null
	return data

/obj/structure/ms13_vehicle_part/camera_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || action != "switch_camera")
		return
	var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera = cameras()[params["name"]]
	if(!camera)
		return
	set_camera(camera)
	playsound(src, get_sfx(SFX_TERMINAL_TYPE), 25, FALSE)
	return TRUE

/// The vehicle's cameras by name: which side each watches, told apart where two watch the same side.
/obj/structure/ms13_vehicle_part/camera_console/proc/cameras()
	. = list()
	for(var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera in vehicle?.parts)
		var/feed = camera.feed_name()
		var/count = 1
		while(.[feed])
			feed = "[camera.feed_name()] ([++count])"
		.[feed] = camera

/obj/structure/ms13_vehicle_part/camera_console/proc/feed_name_of(obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera)
	var/list/named = cameras()
	for(var/feed in named)
		if(named[feed] == camera)
			return feed

/obj/structure/ms13_vehicle_part/camera_console/proc/set_camera(obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera)
	if(active_camera)
		UnregisterSignal(active_camera, list(COMSIG_MOVABLE_MOVED, COMSIG_ATOM_DIR_CHANGE, COMSIG_PARENT_QDELETING))
	active_camera = camera
	if(camera)
		RegisterSignal(camera, COMSIG_MOVABLE_MOVED, PROC_REF(on_camera_moved))
		RegisterSignal(camera, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_camera_turned))
		RegisterSignal(camera, COMSIG_PARENT_QDELETING, PROC_REF(on_camera_deleted))
	for(var/mob/living/looker as anything in lookers)
		var/obj/effect/abstract/ms13_vehicle_camera_eye/eye = lookers[looker]
		eye.forceMove(get_step(camera || src, camera?.dir || dir))
	show_feed()

/// The vehicle drove on: the feed moves with it, and so does each eye looking out through it.
/obj/structure/ms13_vehicle_part/camera_console/proc/on_camera_moved(atom/movable/camera, atom/old_loc)
	SIGNAL_HANDLER
	var/turf/was = get_turf(old_loc)
	var/turf/now = get_turf(camera)
	for(var/mob/living/looker as anything in lookers)
		var/atom/movable/eye = lookers[looker]
		var/turf/eye_turf = get_turf(eye)
		var/turf/carried = was && now && eye_turf ? locate(eye_turf.x + now.x - was.x, eye_turf.y + now.y - was.y, now.z) : null
		eye.forceMove(carried || get_step(camera, camera.dir))
	show_feed()

/// The vehicle turned: each eye goes back to the view straight out of the camera.
/obj/structure/ms13_vehicle_part/camera_console/proc/on_camera_turned(atom/movable/camera, old_dir, new_dir)
	SIGNAL_HANDLER
	for(var/mob/living/looker as anything in lookers)
		var/atom/movable/eye = lookers[looker]
		eye.forceMove(get_step(camera, new_dir))
	show_feed()

/obj/structure/ms13_vehicle_part/camera_console/proc/on_camera_deleted()
	SIGNAL_HANDLER
	set_camera(null)

/obj/structure/ms13_vehicle_part/camera_console/proc/show_feed()
	var/list/seen = feed_turfs()
	if(!length(seen))
		cam_screen?.show_camera_static()
		return
	var/list/bbox = get_bbox_of_atoms(seen)
	cam_screen.show_camera(seen, bbox[3] - bbox[1] + 1, bbox[4] - bbox[2] + 1)

/// What the active camera takes in, or nothing without power.
/obj/structure/ms13_vehicle_part/camera_console/proc/feed_turfs()
	. = list()
	if(!is_powered() || !active_camera?.is_enabled())
		return
	var/turf/outside = get_step(active_camera, active_camera.dir)
	for(var/turf/seen in view(7 + active_camera.view_reach, outside))
		if(active_camera.covers(seen))
			. += seen

/// Looks out through the active camera, in place of the user's own eyes. Their movement keys look about.
/obj/structure/ms13_vehicle_part/camera_console/proc/start_looking(mob/living/user)
	if(!remote_viewing || LAZYACCESS(lookers, user))
		return FALSE
	if(!length(feed_turfs()))
		balloon_alert(user, "no feed!")
		return FALSE
	var/obj/effect/abstract/ms13_vehicle_camera_eye/eye = new(get_step(active_camera, active_camera.dir))
	eye.console = src
	eye.stop_action = new(src)
	eye.stop_action.Grant(user)
	LAZYSET(lookers, user, eye)
	user.remote_control = eye
	user.ms13_camera_eye = eye
	user.reset_perspective(eye)
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_looker_moved))
	return TRUE

/obj/structure/ms13_vehicle_part/camera_console/proc/stop_looking(mob/living/user)
	var/obj/effect/abstract/ms13_vehicle_camera_eye/eye = LAZYACCESS(lookers, user)
	if(!eye)
		return
	LAZYREMOVE(lookers, user)
	UnregisterSignal(user, COMSIG_MOVABLE_MOVED)
	if(user.remote_control == eye)
		user.remote_control = null
	user.ms13_camera_eye = null
	user.reset_perspective()
	qdel(eye)
	if(!LAZYLEN(watchers) && !LAZYLEN(lookers))
		set_camera(null)

/// Out of the vehicle, they're no longer looking.
/obj/structure/ms13_vehicle_part/camera_console/proc/on_looker_moved(mob/living/looker)
	SIGNAL_HANDLER
	if(get_ms13_ground_vehicle_at(looker) != vehicle)
		stop_looking(looker)

/// Where someone at a vehicle camera console looks from. It goes only where the vehicle's working cameras see.
/obj/effect/abstract/ms13_vehicle_camera_eye
	name = "camera view"
	var/obj/structure/ms13_vehicle_part/camera_console/console
	var/datum/action/innate/ms13_stop_looking/stop_action

/obj/effect/abstract/ms13_vehicle_camera_eye/Destroy()
	QDEL_NULL(stop_action)
	console = null
	return ..()

/obj/effect/abstract/ms13_vehicle_camera_eye/relaymove(mob/living/user, direction)
	var/turf/next = get_step(src, direction)
	if(next && console?.vehicle?.camera_covering(next))
		forceMove(next)

/// Thermal and night vision cameras show as they do on the driver's display.
/obj/effect/abstract/ms13_vehicle_camera_eye/update_remote_sight(mob/living/user)
	return console?.active_camera?.update_remote_sight(user)

/datum/action/innate/ms13_stop_looking
	name = "Stop Looking"
	button_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "camera_off"

/datum/action/innate/ms13_stop_looking/Activate()
	var/obj/structure/ms13_vehicle_part/camera_console/console = target
	console?.stop_looking(owner)

/// Fitted to a vehicle camera console, it lets the console's user look out through the vehicle's cameras.
/obj/item/ms13_remote_viewing_module
	name = "remote viewing module"
	desc = "A circuit board for a vehicle camera console. Fitted, it lets whoever works the console look out through the vehicle's cameras, and about everything they take in."
	icon = 'icons/obj/module.dmi'
	icon_state = "cpuboard_adv"
	w_class = WEIGHT_CLASS_SMALL
