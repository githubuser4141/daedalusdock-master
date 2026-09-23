/**
 * Equipment a vehicle can carry beyond what drives it: a welding set, a smoke generator and a roof solar panel.
 * Each is fitted at assembly, or mapped/spawned onto a vehicle's floor to fit itself there.
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
