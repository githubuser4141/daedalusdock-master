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
	/// Sheet broken_icon_state lives in, when it isn't this part's own.
	var/broken_icon
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
	exterior_image.icon = broken_icon || icon
	exterior_image.icon_state = broken_icon_state

/obj/structure/ms13_vehicle_part/running_gear/atom_fix()
	. = ..()
	broken = FALSE
	exterior_image.icon = icon
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
	vehicle?.stop_engine()
	QDEL_NULL(soundloop)
	return ..()

/obj/structure/ms13_vehicle_part/engine/configure_from_vehicle()
	modify_max_integrity(vehicle.engine_integrity)
	vehicle.engine = src
	soundloop = new(src)
	// All layouts use this shared mount path; keep the walk-over battery at the driver's end.
	if(!vehicle.battery)
		vehicle.pivot.spawn_part(/obj/structure/ms13_vehicle_part/battery)

/obj/structure/ms13_vehicle_part/engine/proc/consume_fuel(amount)
	if(vehicle?.engine_running && is_operational())
		vehicle.fuel_tank.draw_fuel(amount)
	if(!is_operational())
		vehicle?.stop_engine()

/obj/structure/ms13_vehicle_part/engine/is_operational()
	return ..() && vehicle?.fuel_tank?.has_fuel()

/obj/structure/ms13_vehicle_part/engine/set_moving(is_moving)
	if(!broken)
		icon_state = vehicle?.engine_running && is_operational() ? running_icon_state : static_icon_state
	if(vehicle?.engine_running && is_operational())
		soundloop?.start()
	else
		soundloop?.stop()

/obj/structure/ms13_vehicle_part/engine/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	vehicle?.stop_engine()
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

TYPEINFO_DEF(/obj/structure/ms13_vehicle_part/fuel_tank)
	default_armor = list(BLUNT = 25, PUNCTURE = 75, SLASH = 50, LASER = 80, ENERGY = 50, BOMB = 0, BIO = 100,  FIRE = 25, ACID = 25)

/obj/structure/ms13_vehicle_part/fuel_tank
	name = "fuel tank"
	desc = "A vehicle fuel tank."
	icon_state = "fueltank_small_tank"
	layer = OBJ_LAYER
	max_integrity = 200
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
	return on && is_operational() && vehicle?.interior_lights_on && vehicle.has_electrical_power()

/// Returns list(r, g, b), each 0-1, of what this fixture adds to frame.
/obj/structure/ms13_vehicle_part/interior_light/proc/light_at(obj/structure/ms13_vehicle_frame/frame)
	var/distance = sqrt((frame.forward_offset - forward_offset) ** 2 + (frame.right_offset - right_offset) ** 2)
	var/strength = power * max(0, 1 - distance / (range + 1)) / 255
	var/list/channels = rgb2num(color_on)
	return list(channels[1] * strength, channels[2] * strength, channels[3] * strength)

/obj/structure/ms13_vehicle_part/interior_light/update_icon_state()
	icon_state = broken ? "floor-broken" : is_lit() ? "floor" : "floor-burned"
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

/// Civ13 96x96 tracks and wheels, drawn centered on their tile. Art is set per vehicle by set_art().
/obj/structure/ms13_vehicle_part/running_gear/civ96
	name = "track assembly"
	desc = "An exposed track run. Damaging enough of these will prevent acceleration."
	icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96.dmi'
	broken_icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96_damaged.dmi'
	pixel_x = -32
	pixel_y = -32

/// art: normal state; moving art is "[art]_m". broken_art is looked up in broken_icon and falls back to a tint.
/obj/structure/ms13_vehicle_part/running_gear/civ96/proc/set_art(art, broken_art, paint)
	stationary_icon_state = art
	moving_icon_state = "[art]_m"
	if(ms13_icon_has_state(broken_icon, broken_art))
		broken_icon_state = broken_art
	else
		broken_icon = null
		broken_icon_state = art
	exterior_image.icon_state = art
	exterior_image.color = paint

/obj/structure/ms13_vehicle_part/running_gear/civ96/wheels
	name = "wheel set"
	desc = "A run of big armored-car wheels. Damaging enough of these will prevent acceleration."

/// Vehicle-scale rounds use existing projectile behavior and MS13's placeholder ammunition art.
TYPEINFO_DEF(/obj/projectile/bullet/ms13/vehicle_autocannon)
	default_armor = GIANT_CAL_RIFLE
/obj/projectile/bullet/ms13/vehicle_autocannon
	parent_type = /obj/projectile/bullet/ms13/a50MG/ap
	name = "30mm autocannon shell"
	damage = 180
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_INSANE
	bulletTipType = BULLET_SHARP

TYPEINFO_DEF(/obj/projectile/bullet/cannonball/ms13_vehicle/medium)
	default_armor = GIANT_CAL_RIFLE
/obj/projectile/bullet/cannonball/ms13_vehicle/medium
	name = "76mm tank shell"
	damage = 400
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_INSANE
	bulletTipType = BULLET_SHARP

TYPEINFO_DEF(/obj/projectile/bullet/cannonball/ms13_vehicle/heavy)
	default_armor = GIANT_CAL_RIFLE
/obj/projectile/bullet/cannonball/ms13_vehicle/heavy
	name = "122mm tank shell"
	damage = 800
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_INSANE
	bulletTipType = BULLET_SHARP

/obj/item/ammo_casing/ms13/vehicle_autocannon
	name = "30mm autocannon shell casing"
	desc = "A vehicle autocannon shell."
	caliber = "30mm"
	icon_state = "50bmg_casing"
	projectile_type = /obj/projectile/bullet/ms13/vehicle_autocannon

/obj/item/ammo_casing/ms13/vehicle_shell
	name = "76mm tank shell casing"
	desc = "A complete 76mm tank shell."
	caliber = "76mm"
	icon_state = "50bmg_casing"
	projectile_type = /obj/projectile/bullet/cannonball/ms13_vehicle/medium

/obj/item/ammo_casing/ms13/vehicle_shell/heavy
	name = "122mm tank shell casing"
	desc = "A complete 122mm tank shell."
	caliber = "122mm"
	projectile_type = /obj/projectile/bullet/cannonball/ms13_vehicle/heavy

/obj/item/ammo_box/ms13/vehicle_autocannon
	name = "30mm ammunition box"
	desc = "A heavy box of linked 30mm autocannon ammunition."
	icon_state = "box50"
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_autocannon
	caliber = "30mm"
	max_ammo = 20
	w_class = WEIGHT_CLASS_BULKY

/obj/item/ammo_box/ms13/vehicle_shell
	name = "76mm shell crate"
	desc = "A reinforced crate containing 76mm tank shells."
	icon_state = "box50"
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_shell
	caliber = "76mm"
	max_ammo = 4
	w_class = WEIGHT_CLASS_BULKY

/obj/item/ammo_box/ms13/vehicle_shell/heavy
	name = "122mm shell crate"
	desc = "A reinforced crate containing 122mm tank shells."
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_shell/heavy
	caliber = "122mm"
	max_ammo = 2

/**
 * A turret seen from above. Both ring and turret top are exterior-only, like the roof, so the art does not
 * cover its gunner inside the cabin. A linked gunner seat supplies the abstract controls used to aim and fire.
 */
/obj/structure/ms13_vehicle_part/turret
	name = "turret"
	desc = "The vehicle's turret."
	icon_state = "none"
	layer = ABOVE_ALL_MOB_LAYER + 0.02
	max_integrity = 1000
	var/turret_icon = 'mojave/icons/objects/vehicles_ground/civ_turrets.dmi'
	var/turret_art
	var/paint
	/// Where the turret art sits relative to this tile, in the vehicle's own right/forward pixels.
	var/shift_right = 0
	var/shift_forward = 0
	var/obj/structure/chair/ms13_vehicle_seat/gunner_seat
	var/projectile_type
	var/ammo_type
	var/weapon_name = "unarmed mount"
	var/fire_sound
	var/fire_sound_volume = 75
	var/fire_delay = 1 SECONDS
	var/max_ammo = 0
	var/ammo = 0
	var/next_fire_time = 0
	/// Hand-operated machine guns need no electricity; powered heavy mounts do.
	var/shot_power_cost = 0

/obj/structure/ms13_vehicle_part/turret/Destroy()
	if(gunner_seat)
		gunner_seat.operated_turret = null
		QDEL_NULL(gunner_seat.turret_control)
	gunner_seat = null
	return ..()

/obj/structure/ms13_vehicle_part/turret/examine(mob/user)
	. = ..()
	. += span_notice("Its [weapon_name] has [ammo]/[max_ammo] rounds loaded.")

/obj/structure/ms13_vehicle_part/turret/attackby(obj/item/used_item, mob/user, params)
	if(!istype(used_item, /obj/item/ammo_box))
		return ..()
	if(!ammo_type)
		balloon_alert(user, "no weapon fitted!")
		return
	if(ammo >= max_ammo)
		balloon_alert(user, "already full!")
		return

	var/obj/item/ammo_box/ammo_box = used_item
	var/loaded = 0
	while(ammo < max_ammo && ammo_box.ammo_count(FALSE))
		var/obj/item/ammo_casing/round = ammo_box.get_round(FALSE)
		if(!istype(round, ammo_type))
			ammo_box.give_round(round)
			break
		qdel(round)
		ammo++
		loaded++
	ammo_box.update_ammo_count()
	if(!loaded)
		balloon_alert(user, "wrong ammunition!")
		return
	playsound(src, 'mojave/sound/ms13vehicles/MGReloadGeneric.ogg', 50, TRUE)
	balloon_alert(user, "loaded [loaded] round[loaded == 1 ? "" : "s"]")

/// Point the turret without changing its relationship to the hull on the next vehicle turn.
/obj/structure/ms13_vehicle_part/turret/proc/aim_at(atom/target)
	var/aim_dir = get_cardinal_dir(src, target)
	if(!aim_dir)
		return FALSE
	setDir(aim_dir)
	if(vehicle)
		// dir2angle() increases clockwise, while turn() increases counter-clockwise.
		relative_turn = (dir2angle(vehicle.dir) - dir2angle(aim_dir) + 360) % 360
	return TRUE

/// The barrel is above the roof: begin outside the vehicle so rounds do not hit their own hull.
/obj/structure/ms13_vehicle_part/turret/proc/get_muzzle_turf(aim_dir)
	var/turf/muzzle = get_turf(src)
	while(muzzle && vehicle?.get_frame_at(muzzle))
		muzzle = get_step(muzzle, aim_dir)
	return muzzle

/obj/structure/ms13_vehicle_part/turret/proc/fire_at(atom/target, mob/living/user, list/modifiers)
	if(!projectile_type || !is_operational() || !gunner_seat || user.buckled != gunner_seat || !(user in gunner_seat.buckled_mobs) || user.incapacitated())
		return FALSE
	if(shot_power_cost && (!vehicle?.has_electrical_power() || vehicle.battery.cell.charge < shot_power_cost))
		balloon_alert(user, "mount has no power!")
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf || vehicle?.get_frame_at(target_turf) || !aim_at(target))
		return FALSE
	if(world.time < next_fire_time)
		return FALSE
	if(ammo <= 0)
		balloon_alert(user, "[weapon_name] is empty!")
		playsound(src, 'sound/weapons/gun/general/dry_fire.ogg', 30, TRUE)
		next_fire_time = world.time + 5
		return FALSE

	var/turf/muzzle = get_muzzle_turf(dir)
	if(!muzzle)
		return FALSE
	var/obj/projectile/shot = new projectile_type
	shot.firer = user
	shot.fired_from = src
	if(!shot.preparePixelProjectile(target, muzzle, modifiers))
		qdel(shot)
		return FALSE
	if(shot_power_cost && !vehicle.use_battery(shot_power_cost))
		qdel(shot)
		return FALSE
	ammo--
	next_fire_time = world.time + fire_delay
	playsound(src, fire_sound, fire_sound_volume, TRUE)
	shot.fire()
	return TRUE

/obj/structure/ms13_vehicle_part/turret/machine_gun
	weapon_name = "7.62mm machine gun"
	projectile_type = /obj/projectile/bullet/ms13/a762/fmj
	ammo_type = /obj/item/ammo_casing/ms13/a762
	fire_sound = 'mojave/sound/ms13vehicles/DP28.ogg'
	fire_delay = 2
	max_ammo = 100
	ammo = 100

/obj/structure/ms13_vehicle_part/turret/autocannon
	shot_power_cost = 25

/obj/structure/ms13_vehicle_part/turret/tank
	shot_power_cost = 50

/obj/structure/ms13_vehicle_part/turret/autocannon/btr80
	weapon_name = "Shipunov 2A72 30mm autocannon"
	projectile_type = /obj/projectile/bullet/ms13/vehicle_autocannon
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_autocannon
	fire_sound = 'mojave/sound/ms13vehicles/2a72.ogg'
	fire_delay = 4
	max_ammo = 40
	ammo = 40

/obj/structure/ms13_vehicle_part/turret/autocannon/bmd2
	weapon_name = "Shipunov 2A42 30mm autocannon"
	projectile_type = /obj/projectile/bullet/ms13/vehicle_autocannon
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_autocannon
	fire_sound = 'mojave/sound/ms13vehicles/30mm.ogg'
	fire_delay = 3
	max_ammo = 60
	ammo = 60

/obj/structure/ms13_vehicle_part/turret/tank/medium
	weapon_name = "76mm tank cannon"
	projectile_type = /obj/projectile/bullet/cannonball/ms13_vehicle/medium
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_shell
	fire_sound = 'mojave/sound/ms13vehicles/artillery_outgoing.ogg'
	fire_sound_volume = 100
	fire_delay = 5 SECONDS
	max_ammo = 12
	ammo = 12

/obj/structure/ms13_vehicle_part/turret/tank/heavy
	weapon_name = "122mm tank cannon"
	projectile_type = /obj/projectile/bullet/cannonball/ms13_vehicle/heavy
	ammo_type = /obj/item/ammo_casing/ms13/vehicle_shell/heavy
	fire_sound = 'mojave/sound/ms13vehicles/artillery_outgoing.ogg'
	fire_sound_volume = 100
	fire_delay = 8 SECONDS
	max_ammo = 8
	ammo = 8

/obj/structure/ms13_vehicle_part/turret/proc/set_art(art, right, forward, new_paint)
	turret_art = art
	shift_right = right
	shift_forward = forward
	paint = new_paint
	exterior_image = image(turret_icon, src, "[art]_turret0", ABOVE_ALL_MOB_LAYER + 0.02, dir)
	exterior_image.color = paint
	exterior_image.mouse_opacity = MOUSE_OPACITY_ICON
	GLOB.ms13_vehicle_exterior_part_images |= exterior_image
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images |= exterior_image
	setDir(dir)

/obj/structure/ms13_vehicle_part/turret/setDir(new_dir)
	. = ..()
	var/list/offset = get_art_offset()
	if(exterior_image)
		exterior_image.pixel_x = offset[1]
		exterior_image.pixel_y = offset[2]
		var/mutable_appearance/turret_top = mutable_appearance(turret_icon, "[turret_art]_turret_roof0", ABOVE_ALL_MOB_LAYER + 0.03)
		turret_top.dir = dir
		turret_top.color = paint
		turret_top.appearance_flags = RESET_COLOR
		turret_top.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		exterior_image.overlays = list(turret_top)
	update_appearance()
	gunner_seat?.turret_control?.update_sight()

/// Pixel offset of the 256x256 turret art for the current facing.
/obj/structure/ms13_vehicle_part/turret/proc/get_art_offset()
	var/right_dir = turn(dir, -90)
	var/px = -112 + shift_right * ((right_dir & EAST) ? 1 : (right_dir & WEST) ? -1 : 0) + shift_forward * ((dir & EAST) ? 1 : (dir & WEST) ? -1 : 0)
	var/py = -112 + shift_right * ((right_dir & NORTH) ? 1 : (right_dir & SOUTH) ? -1 : 0) + shift_forward * ((dir & NORTH) ? 1 : (dir & SOUTH) ? -1 : 0)
	return list(px, py)

/obj/structure/ms13_vehicle_part/turret/update_overlays()
	return ..()

/// Ammunition and kit stowage along the hull. Click to open.
/obj/structure/ms13_vehicle_part/stowage
	name = "ammunition rack"
	desc = "A bolted-down rack for ammunition and kit."
	icon = 'mojave/icons/structure/crates.dmi'
	icon_state = "army"
	layer = OBJ_LAYER
	max_integrity = 150
	var/slots = 8

/obj/structure/ms13_vehicle_part/stowage/Initialize(mapload)
	. = ..()
	create_storage(max_slots = slots, max_specific_storage = WEIGHT_CLASS_BULKY, max_total_storage = slots * WEIGHT_CLASS_BULKY)
