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

/** The engine is an ordinary interior structure backed by the existing reagent fuel system. */
/obj/structure/ms13_vehicle_part/engine
	name = "vehicle engine"
	desc = "A combustion engine and its integral fuel tank."
	icon_state = "carengine_static"
	layer = OBJ_LAYER
	max_integrity = 200
	var/datum/looping_sound/ms13/vehicle_engine/soundloop

/obj/structure/ms13_vehicle_part/engine/Destroy()
	QDEL_NULL(soundloop)
	return ..()

/obj/structure/ms13_vehicle_part/engine/configure_from_vehicle()
	modify_max_integrity(vehicle.engine_integrity)
	create_reagents(vehicle.fuel_capacity, OPENCONTAINER)
	reagents.add_reagent(/datum/reagent/fuel, vehicle.fuel_capacity)
	vehicle.engine = src
	soundloop = new(src)

/obj/structure/ms13_vehicle_part/engine/proc/consume_fuel(amount)
	if(is_operational() && reagents?.has_reagent(/datum/reagent/fuel))
		reagents.remove_reagent(/datum/reagent/fuel, amount)
	if(!reagents?.has_reagent(/datum/reagent/fuel))
		set_moving(FALSE)

/obj/structure/ms13_vehicle_part/engine/is_operational()
	return ..() && reagents?.has_reagent(/datum/reagent/fuel)

/obj/structure/ms13_vehicle_part/engine/set_moving(is_moving)
	if(!broken)
		icon_state = is_moving && reagents?.has_reagent(/datum/reagent/fuel) ? "carengine_on" : "carengine_static"
	if(is_moving && is_operational())
		soundloop?.start()
	else
		soundloop?.stop()

/obj/structure/ms13_vehicle_part/engine/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	icon_state = "carengine_broken"
	soundloop?.stop()

/obj/structure/ms13_vehicle_part/engine/atom_fix()
	. = ..()
	broken = FALSE
	set_moving(vehicle?.moving)

/obj/structure/ms13_vehicle_part/engine/examine(mob/user)
	. = ..()
	. += span_notice("Its tank contains [round(reagents?.get_reagent_amount(/datum/reagent/fuel), 0.1)]/[reagents?.maximum_volume] units of fuel.")
