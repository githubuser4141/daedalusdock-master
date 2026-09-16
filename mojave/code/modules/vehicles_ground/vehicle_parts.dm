TYPEINFO_DEF(/obj/structure/ms13_vehicle_part)
	default_armor = list(BLUNT = 20, PUNCTURE = 20, SLASH = 10, LASER = 10, ENERGY = 10, BOMB = 10, BIO = 100, FIRE = 30, ACID = 20)

/datum/looping_sound/ms13/vehicle_engine
	start_sound = 'mojave/sound/ms13machines/engine_start.ogg'
	start_length = 1.2 SECONDS
	mid_sounds = list(
		'mojave/sound/ms13machines/engine_running1.ogg' = 1,
		'mojave/sound/ms13machines/engine_running2.ogg' = 1,
		'mojave/sound/ms13machines/engine_running3.ogg' = 1,
	)
	mid_length = 1 SECONDS
	volume = 35
	vary = TRUE
	extra_range = 3
	falloff_distance = 2

/datum/looping_sound/ms13/vehicle_wheels
	mid_sounds = list('sound/vehicles/skateboard_roll.ogg' = 1)
	mid_length = 1 SECONDS
	volume = 18
	vary = TRUE
	falloff_distance = 1

/datum/looping_sound/ms13/vehicle_tracks
	mid_sounds = list('sound/effects/tank_treads.ogg' = 1)
	mid_length = 1 SECONDS
	volume = 30
	vary = TRUE
	extra_range = 2
	falloff_distance = 1

/**
 * A damageable component mounted on a vehicle frame. Parts use the same local offsets as frames and
 * walls, so the shared controller moves and rotates them without knowing which concrete vehicle
 * installed them.
 */
/obj/structure/ms13_vehicle_part
	name = "vehicle part"
	desc = "A replaceable component mounted to a vehicle."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	density = FALSE
	anchored = TRUE
	layer = ABOVE_MOB_LAYER
	integrity_failure = 0.25
	var/datum/ms13_ground_vehicle/vehicle
	var/forward_offset = 0
	var/right_offset = 0
	var/relative_turn = 0
	/// Client image used by parts such as wheels which should be visible outside but hidden in-cabin.
	var/image/exterior_image

/obj/structure/ms13_vehicle_part/Destroy()
	if(exterior_image)
		GLOB.ms13_vehicle_exterior_part_images -= exterior_image
		for(var/client/viewer as anything in GLOB.clients)
			viewer.images -= exterior_image
		exterior_image = null
	if(vehicle?.engine == src)
		vehicle.engine = null
	vehicle?.parts -= src
	vehicle = null
	return ..()

/obj/structure/ms13_vehicle_part/setDir(new_dir)
	. = ..()
	if(exterior_image)
		exterior_image.dir = dir

/obj/structure/ms13_vehicle_part/proc/is_operational()
	return !QDELETED(src) && !broken && get_integrity() > 0

/obj/structure/ms13_vehicle_part/proc/set_moving(is_moving)
	return

/// Mounts a part on this frame using a direction relative to the vehicle's current facing.
/obj/structure/ms13_vehicle_frame/proc/spawn_part(part_type, relative_turn = 0)
	var/obj/structure/ms13_vehicle_part/part = new part_type(get_turf(src))
	part.vehicle = vehicle
	part.forward_offset = forward_offset
	part.right_offset = right_offset
	part.relative_turn = relative_turn
	part.setDir(turn(vehicle.dir, relative_turn))
	vehicle.parts += part
	part.configure_from_vehicle()
	vehicle.update_interior_lighting()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in vehicle.frames)
		for(var/mob/living/passenger in get_turf(frame))
			if(passenger.client)
				vehicle.set_roof_visible(passenger.client, FALSE)
	return part

/obj/structure/ms13_vehicle_part/proc/configure_from_vehicle()
	return

/** Running gear is a real, non-dense damage target; only its clickable image is exterior-only. */
/obj/structure/ms13_vehicle_part/running_gear
	name = "vehicle running gear"
	desc = "Exposed running gear. It looks vulnerable to a determined attacker."
	icon_state = "none"
	max_integrity = 80
	var/stationary_icon_state
	var/moving_icon_state
	var/broken_icon_state
	/// Pushes centered sprites such as wheels outside the frame edge; Civ13's tracks are pre-aligned.
	var/exterior_offset = 0

/obj/structure/ms13_vehicle_part/running_gear/Initialize(mapload)
	. = ..()
	exterior_image = image(icon = icon, loc = src, icon_state = stationary_icon_state, layer = ABOVE_ALL_MOB_LAYER + 0.02, dir = dir)
	exterior_image.mouse_opacity = MOUSE_OPACITY_ICON
	GLOB.ms13_vehicle_exterior_part_images |= exterior_image
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images |= exterior_image

/obj/structure/ms13_vehicle_part/running_gear/configure_from_vehicle()
	modify_max_integrity(vehicle.running_gear_integrity)

/obj/structure/ms13_vehicle_part/running_gear/setDir(new_dir)
	. = ..()
	if(exterior_image)
		exterior_image.pixel_x = dir == EAST ? exterior_offset : dir == WEST ? -exterior_offset : 0
		exterior_image.pixel_y = dir == NORTH ? exterior_offset : dir == SOUTH ? -exterior_offset : 0

/obj/structure/ms13_vehicle_part/running_gear/set_moving(is_moving)
	if(exterior_image && !broken)
		exterior_image.icon_state = is_moving ? moving_icon_state : stationary_icon_state

/obj/structure/ms13_vehicle_part/running_gear/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	exterior_image.icon_state = broken_icon_state

/obj/structure/ms13_vehicle_part/running_gear/atom_fix()
	. = ..()
	broken = FALSE
	set_moving(vehicle?.moving)

/obj/structure/ms13_vehicle_part/running_gear/wheel
	name = "vehicle wheel"
	desc = "An exposed rubber wheel. It looks vulnerable to a determined attacker."
	stationary_icon_state = "wheel_t_dark"
	moving_icon_state = "wheel_t_dark_m"
	broken_icon_state = "wheel_t_dark_broken"
	exterior_offset = 12

/obj/structure/ms13_vehicle_part/running_gear/track
	name = "M113 track assembly"
	desc = "An exposed armored track unit. Damaging enough of these will prevent acceleration."
	icon = 'mojave/icons/objects/vehicles_ground/apcparts.dmi'
	stationary_icon_state = "m113_tracks_end_left"
	moving_icon_state = "m113_tracks_end_left_m"
	broken_icon_state = "m113_tracks_end_left_broken"

/obj/structure/ms13_vehicle_part/running_gear/track/right
	stationary_icon_state = "m113_tracks_end_right"
	moving_icon_state = "m113_tracks_end_right_m"
	broken_icon_state = "m113_tracks_end_right_broken"

/** The engine burns fuel drawn from the vehicle's fuel tank part. */
/obj/structure/ms13_vehicle_part/engine
	name = "vehicle engine"
	desc = "A combustion engine."
	icon_state = "carengine_static"
	layer = OBJ_LAYER
	max_integrity = 200
	var/static_icon_state = "carengine_static"
	var/running_icon_state = "carengine_on"
	var/broken_icon_state = "carengine_broken"
	var/datum/looping_sound/ms13/vehicle_engine/soundloop

/obj/structure/ms13_vehicle_part/engine/Destroy()
	QDEL_NULL(soundloop)
	return ..()

/obj/structure/ms13_vehicle_part/engine/configure_from_vehicle()
	modify_max_integrity(vehicle.engine_integrity)
	vehicle.engine = src
	soundloop = new(src)

/obj/structure/ms13_vehicle_part/engine/proc/consume_fuel(amount)
	if(is_operational())
		vehicle.fuel_tank.draw_fuel(amount)
	if(!is_operational())
		set_moving(FALSE)

/obj/structure/ms13_vehicle_part/engine/is_operational()
	return ..() && vehicle?.fuel_tank?.has_fuel()

/obj/structure/ms13_vehicle_part/engine/set_moving(is_moving)
	if(!broken)
		icon_state = is_moving && is_operational() ? running_icon_state : static_icon_state
	if(is_moving && is_operational())
		soundloop?.start()
	else
		soundloop?.stop()

/obj/structure/ms13_vehicle_part/engine/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	icon_state = broken_icon_state
	soundloop?.stop()

/obj/structure/ms13_vehicle_part/engine/atom_fix()
	. = ..()
	broken = FALSE
	set_moving(vehicle?.moving)

/**
 * Holds the vehicle's gears: each entry is the move delay of one gear, lowest first. A worn gearbox
 * can no longer reach its top gear, and a broken one transmits no drive at all.
 * The sprite is Civ13's powered drive axis, which is where Civ13 keeps its own gear list.
 */
/obj/structure/ms13_vehicle_part/gearbox
	name = "gearbox"
	desc = "A manual gearbox and drive shaft."
	icon_state = "axis_powered"
	layer = OBJ_LAYER
	max_integrity = 150
	var/list/gear_delays = list(6, 4, 3, 2)
	/// Below this integrity fraction the top gear is stripped.
	var/worn_threshold = 0.6

/obj/structure/ms13_vehicle_part/gearbox/configure_from_vehicle()
	vehicle.gearbox = src

/obj/structure/ms13_vehicle_part/gearbox/Destroy()
	if(vehicle?.gearbox == src)
		vehicle.gearbox = null
	return ..()

/// How many gears can currently be selected.
/obj/structure/ms13_vehicle_part/gearbox/proc/available_gears()
	if(!is_operational())
		return 0
	if(get_integrity() < max_integrity * worn_threshold)
		return max(length(gear_delays) - 1, 1)
	return length(gear_delays)

/obj/structure/ms13_vehicle_part/gearbox/atom_break(damage_flag)
	. = ..()
	broken = TRUE

/obj/structure/ms13_vehicle_part/gearbox/atom_fix()
	. = ..()
	broken = FALSE

/obj/structure/ms13_vehicle_part/gearbox/examine(mob/user)
	. = ..()
	var/gears = available_gears()
	if(!gears)
		. += span_warning("It is wrecked and won't transmit any drive.")
	else if(gears < length(gear_delays))
		. += span_warning("Its teeth are chewed up; it grinds out of top gear.")
	else
		. += span_notice("It has [gears] working gears.")

/obj/structure/ms13_vehicle_part/gearbox/three_speed
	gear_delays = list(8, 6, 4)

/// Fuel lives here, not in the engine. Pour fuel in to refill it; once broken it leaks as the vehicle moves.
/obj/structure/ms13_vehicle_part/fuel_tank
	name = "fuel tank"
	desc = "A vehicle fuel tank."
	icon_state = "fueltank_small_tank"
	layer = OBJ_LAYER
	max_integrity = 120
	var/capacity = 70
	/// Extra fuel lost per tile travelled while broken.
	var/leak_per_tile = 0.5

/obj/structure/ms13_vehicle_part/fuel_tank/configure_from_vehicle()
	create_reagents(capacity, OPENCONTAINER)
	reagents.add_reagent(/datum/reagent/fuel, capacity)
	vehicle.fuel_tank = src

/obj/structure/ms13_vehicle_part/fuel_tank/Destroy()
	if(vehicle?.fuel_tank == src)
		vehicle.fuel_tank = null
	return ..()

/obj/structure/ms13_vehicle_part/fuel_tank/proc/has_fuel()
	return reagents?.has_reagent(/datum/reagent/fuel)

/obj/structure/ms13_vehicle_part/fuel_tank/proc/draw_fuel(amount)
	reagents?.remove_reagent(/datum/reagent/fuel, broken ? amount + leak_per_tile : amount)

/obj/structure/ms13_vehicle_part/fuel_tank/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	visible_message(span_warning("[src] is punctured and starts leaking fuel!"))

/obj/structure/ms13_vehicle_part/fuel_tank/atom_fix()
	. = ..()
	broken = FALSE

/obj/structure/ms13_vehicle_part/fuel_tank/examine(mob/user)
	. = ..()
	. += span_notice("It holds [round(reagents?.get_reagent_amount(/datum/reagent/fuel), 0.1)]/[reagents?.maximum_volume] units of fuel.")
	if(broken)
		. += span_warning("It is punctured and leaking.")

/obj/structure/ms13_vehicle_part/fuel_tank/large
	icon_state = "fueltank_large_tank"
	capacity = 140

/**
 * A cabin light. It lights nothing outside: the vehicle turns its fixtures into per-tile light for
 * the people inside (see update_interior_lighting()). Click to switch it on or off.
 */
/obj/structure/ms13_vehicle_part/interior_light
	name = "dome light"
	desc = "A caged cabin light. Click to switch it on or off."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "floor"
	layer = ABOVE_MOB_LAYER
	max_integrity = 30
	var/on = TRUE
	/// Brightness at the fixture itself, 0-1.
	var/power = 0.8
	/// Tiles of reach before the light fades out.
	var/range = 3
	var/color_on = "#ffe8c0"

/obj/structure/ms13_vehicle_part/interior_light/Initialize(mapload)
	. = ..()
	update_appearance()

/obj/structure/ms13_vehicle_part/interior_light/proc/is_lit()
	return on && !broken && !QDELETED(src)

/// Returns list(r, g, b), each 0-1, of what this fixture adds to frame.
/obj/structure/ms13_vehicle_part/interior_light/proc/light_at(obj/structure/ms13_vehicle_frame/frame)
	var/distance = sqrt((frame.forward_offset - forward_offset) ** 2 + (frame.right_offset - right_offset) ** 2)
	var/strength = power * max(0, 1 - distance / (range + 1)) / 255
	var/list/channels = rgb2num(color_on)
	return list(channels[1] * strength, channels[2] * strength, channels[3] * strength)

/obj/structure/ms13_vehicle_part/interior_light/update_icon_state()
	icon_state = broken ? "floor-broken" : on ? "floor" : "floor-burned"
	return ..()

/obj/structure/ms13_vehicle_part/interior_light/update_overlays()
	. = ..()
	if(is_lit())
		. += emissive_appearance(icon, "floor", alpha = 180)

/obj/structure/ms13_vehicle_part/interior_light/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	if(broken)
		to_chat(user, span_warning("[src] is smashed."))
		return TRUE
	on = !on
	update_appearance()
	vehicle?.update_interior_lighting()
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	user.visible_message(span_notice("[user] switches [src] [on ? "on" : "off"]."), span_notice("You switch [src] [on ? "on" : "off"]."))
	return TRUE

/obj/structure/ms13_vehicle_part/interior_light/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	update_appearance()
	vehicle?.update_interior_lighting()

/obj/structure/ms13_vehicle_part/interior_light/atom_fix()
	. = ..()
	broken = FALSE
	update_appearance()
	vehicle?.update_interior_lighting()

/obj/structure/ms13_vehicle_part/interior_light/Destroy()
	var/datum/ms13_ground_vehicle/old_vehicle = vehicle
	. = ..()
	old_vehicle?.update_interior_lighting()

/// Dim red lamp over the driver's gauges; shows the controls without ruining night vision.
/obj/structure/ms13_vehicle_part/interior_light/instrument
	name = "instrument panel lamp"
	desc = "A dim red lamp over the driver's gauges. Click to switch it on or off."
	power = 0.35
	range = 1
	color_on = "#ff4030"
