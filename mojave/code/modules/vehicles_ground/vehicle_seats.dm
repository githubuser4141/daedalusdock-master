/**
 * A seat mounted on one of a vehicle's frame tiles. Extends the normal chair type for its buckle
 * mechanics - the only thing added is that the driver seat relays its buckled occupant's movement
 * input into actually driving the vehicle (see _vehicle_base.dm) via the same buckled.relaymove()
 * hook every "can't walk while buckled" chair already uses; passenger seats are just normal chairs
 * along for the ride.
 *
 * Pressing the vehicle's current forward/backward direction drives it; pressing either perpendicular
 * direction turns it to face that way instead of sliding sideways - holding a direction key therefore
 * first turns the vehicle onto that heading, then drives it once already facing that way, matching
 * ordinary top-down vehicle controls.
 */
/obj/structure/chair/ms13_vehicle_seat
	name = "vehicle seat"
	desc = "A seat bolted to a vehicle frame."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "driver_car"
	var/obj/structure/ms13_vehicle_frame/parent_frame
	var/is_driver_seat = FALSE
	var/obj/structure/ms13_vehicle_part/turret/operated_turret
	var/obj/item/ms13_vehicle_turret_control/turret_control
	var/list/control_menu_users

/obj/structure/chair/ms13_vehicle_seat/attack_hand(mob/living/user, list/modifiers)
	if(!is_driver_seat || user.combat_mode)
		return ..()
	open_controls(user)
	return TRUE

/obj/structure/chair/ms13_vehicle_seat/proc/open_controls(mob/living/user)
	if(!user?.client || (user in control_menu_users) || !can_use_controls(user))
		return
	LAZYADD(control_menu_users, user)
	show_controls(user)
	LAZYREMOVE(control_menu_users, user)

/obj/structure/chair/ms13_vehicle_seat/proc/configure_driver_seat()
	is_driver_seat = TRUE
	name = "driver's seat and dashboard"
	desc = "The driver's seat has a full-size control monitor. Click the monitor or seat to open vehicle controls; buckling in opens them automatically."
	handle_layer()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/chair/ms13_vehicle_seat/handle_layer()
	if(is_driver_seat)
		layer = BELOW_MOB_LAYER
		return
	return ..()

/obj/structure/chair/ms13_vehicle_seat/setDir(new_dir)
	. = ..()
	if(is_driver_seat)
		update_appearance(UPDATE_OVERLAYS)

/obj/structure/chair/ms13_vehicle_seat/update_overlays()
	. = ..()
	if(!is_driver_seat)
		return
	// Attached appearances remain clickable as the seat, and travel/rotate with it.
	// Keep the monitor on the seat's interior tile, not beyond the front hull edge.
	for(var/state in list("computer", "generic", "generic_key"))
		var/mutable_appearance/monitor = mutable_appearance('icons/obj/computer.dmi', state, BELOW_MOB_LAYER)
		monitor.dir = dir
		monitor.pixel_x = (dir & EAST) ? -6 : (dir & WEST) ? 6 : 0
		monitor.pixel_y = (dir & NORTH) ? -6 : (dir & SOUTH) ? 6 : 0
		. += monitor

/obj/structure/chair/ms13_vehicle_seat/proc/can_use_controls(mob/living/user)
	return !QDELETED(src) && parent_frame?.vehicle && !QDELETED(parent_frame.vehicle.pivot) && !QDELETED(user) && !user.incapacitated() && user.Adjacent(src) && IsReachableBy(user) && get_ms13_ground_vehicle_at(user) == parent_frame.vehicle && !(user in parent_frame.vehicle.underneath)

/obj/structure/chair/ms13_vehicle_seat/proc/show_controls(mob/living/user)
	while(can_use_controls(user))
		var/datum/ms13_ground_vehicle/vehicle = parent_frame.vehicle
		var/list/options = list("Drive" = 1, "Engine toggle ([vehicle.engine_running ? "on" : "off"])" = 2, "Ignition toggle ([vehicle.ignition ? "on" : "off"])" = 3, "Exterior lights ([vehicle.exterior_lights_on ? "on" : "off"])" = 4, "Interior lights ([vehicle.interior_lights_on ? "on" : "off"])" = 5, "Vehicle cameras ([vehicle.cameras_on ? "on" : "off"])" = 6, "Camera view ([user.ms13_vehicle_camera ? user.ms13_vehicle_camera.feed_name() : "cabin"])" = 13, "Horn" = 7, "Exit" = 8, "Unbuckle" = 9, "Stop" = 10)
		var/battery_percent = vehicle.battery?.cell ? round(vehicle.battery.cell.percent()) : 0
		if(istype(vehicle, /datum/ms13_ground_vehicle/rail))
			// Rail cars only run routes to a stop.
			options -= "Drive"
			options["Rail destination"] = 12
		else
			options["Brakes mode ([vehicle.brakes_mode ? "on" : "off"])"] = 11
		var/choice = input(user, "Battery: [battery_percent]% | Speed band: [vehicle.speed]\nStop applies the brakes. Brakes mode moves slowly only while pressing a direction. Engine-off vehicles slow to a stop.", "Vehicle controls") as null|anything in options
		if(!choice || !can_use_controls(user) || parent_frame.vehicle != vehicle)
			return
		switch(options[choice])
			if(1)
				if(length(buckled_mobs) && !(user in buckled_mobs))
					to_chat(user, span_warning("The driver's seat is occupied."))
					continue
				vehicle.set_ignition(TRUE)
				if(vehicle.start_engine(user) && user.buckled != src)
					user_buckle_mob(user, user)
				return
			if(2)
				if(vehicle.engine_running)
					vehicle.stop_engine()
				else
					vehicle.start_engine(user)
			if(3)
				vehicle.set_ignition(!vehicle.ignition)
			if(4)
				vehicle.exterior_lights_on = !vehicle.exterior_lights_on
			if(5)
				vehicle.interior_lights_on = !vehicle.interior_lights_on
			if(6)
				vehicle.cameras_on = !vehicle.cameras_on
			if(7)
				if(world.time >= vehicle.next_horn_time && vehicle.use_battery(2))
					vehicle.next_horn_time = world.time + 1 SECONDS
					playsound(src, 'sound/items/carhorn.ogg', 80, TRUE)
			if(8)
				return
			if(9)
				if(user.buckled == src)
					user_unbuckle_mob(user, user)
			if(10)
				vehicle.stop_motion()
			if(11)
				vehicle.brakes_mode = !vehicle.brakes_mode
				vehicle.stop_motion()
			if(12)
				var/datum/ms13_ground_vehicle/rail/train = vehicle
				train.choose_destination(user, src)
			if(13)
				if(user.buckled == src)
					next_camera(user)
				else
					to_chat(user, span_warning("Sit in the driver's seat to watch the cameras."))
		vehicle.update_electrical()

/// Steps the driver's view to the next working camera, and back to the cabin after the last.
/obj/structure/chair/ms13_vehicle_seat/proc/next_camera(mob/living/user)
	var/list/feeds = list()
	for(var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera in parent_frame.vehicle.parts)
		if(camera.is_enabled())
			feeds += camera
	if(!length(feeds))
		to_chat(user, span_warning("No working cameras. Check the camera switch and the battery."))
	var/index = feeds.Find(user.ms13_vehicle_camera)
	user.set_ms13_vehicle_camera(index < length(feeds) ? feeds[index + 1] : null)

/obj/structure/chair/ms13_vehicle_seat/Destroy()
	if(operated_turret?.gunner_seat == src)
		operated_turret.gunner_seat = null
	operated_turret = null
	QDEL_NULL(turret_control)
	if(is_driver_seat && parent_frame?.vehicle?.driver)
		parent_frame.vehicle.driver = null
		parent_frame.vehicle.update_interior_masks()
	parent_frame = null
	return ..()

/obj/structure/chair/ms13_vehicle_seat/post_buckle_mob(mob/living/M)
	. = ..()
	// /mob/living/forceMove() auto-unbuckles its target unconditionally (living.dm) - without this,
	// the very first time do_move()/do_rotate() forceMoves a buckled occupant along with the rest of
	// the vehicle, they'd be silently dropped. Same trait, same BUCKLED_TRAIT source, industrial lifts
	// already rely on it for exactly this reason (industrial_lift.dm's AddItemOnLift()).
	ADD_TRAIT(M, TRAIT_CANNOT_BE_UNBUCKLED, BUCKLED_TRAIT)
	if(is_driver_seat && parent_frame?.vehicle)
		parent_frame.vehicle.driver = M
		M.update_ms13_vehicle_interior_mask()
		INVOKE_ASYNC(src, PROC_REF(open_controls), M)
	if(operated_turret)
		turret_control = new(operated_turret)
		if(!M.put_in_hands(turret_control, del_on_fail = TRUE))
			turret_control = null
			balloon_alert(M, "free a hand to use the turret!")

/obj/structure/chair/ms13_vehicle_seat/post_unbuckle_mob(mob/living/M)
	. = ..()
	REMOVE_TRAIT(M, TRAIT_CANNOT_BE_UNBUCKLED, BUCKLED_TRAIT)
	M.set_ms13_vehicle_camera(null)
	if(is_driver_seat && parent_frame?.vehicle?.driver == M)
		parent_frame.vehicle.driver = null
		M.update_ms13_vehicle_interior_mask()
	QDEL_NULL(turret_control)

/obj/structure/chair/ms13_vehicle_seat/attackby(obj/item/used_item, mob/user, params)
	if(operated_turret && istype(used_item, /obj/item/ammo_box))
		return operated_turret.attackby(used_item, user, params)
	return ..()

/obj/structure/chair/ms13_vehicle_seat/examine(mob/user)
	. = ..()
	if(operated_turret)
		. += operated_turret.ammo_report()

/obj/structure/chair/ms13_vehicle_seat/relaymove(mob/living/user, direction)
	if(!is_driver_seat || !parent_frame?.vehicle || !(user in buckled_mobs))
		return ..()
	// Diagonal input (both a vertical and horizontal key held) doesn't map onto this system at all -
	// every offset/facing here is purely cardinal.
	if(!(direction in list(NORTH, SOUTH, EAST, WEST)))
		return

	parent_frame.vehicle.handle_drive_input(direction)

/// An abstract held trigger, following the existing deployable-turret control pattern.
/obj/item/ms13_vehicle_turret_control
	name = "vehicle turret controls"
	desc = "Aim at a target and fire. Use the controls in hand to toggle the directional exterior gunsight; alt-click them to switch the kind of round in the breech."
	icon = 'icons/obj/items_and_weapons.dmi'
	icon_state = "offhand"
	w_class = WEIGHT_CLASS_HUGE
	item_flags = ABSTRACT | NOBLUDGEON | DROPDEL
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF
	var/obj/structure/ms13_vehicle_part/turret/turret
	var/sight_active = FALSE

/obj/item/ms13_vehicle_turret_control/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, ABSTRACT_ITEM_TRAIT)
	turret = loc
	if(!istype(turret))
		return INITIALIZE_HINT_QDEL
	name = "[turret.weapon_name] controls"

/obj/item/ms13_vehicle_turret_control/Destroy()
	var/mob/living/holder = loc
	if(sight_active && istype(holder))
		set_sight(holder, FALSE)
	if(turret?.gunner_seat?.turret_control == src)
		turret.gunner_seat.turret_control = null
	turret = null
	return ..()

/obj/item/ms13_vehicle_turret_control/CanItemAutoclick()
	return TRUE

/obj/item/ms13_vehicle_turret_control/examine(mob/user)
	. = ..()
	if(turret)
		. += turret.ammo_report()

/obj/item/ms13_vehicle_turret_control/AltClick(mob/user)
	. = ..()
	if(turret && user.buckled == turret.gunner_seat && user.is_holding(src))
		turret.cycle_round(user)

/obj/item/ms13_vehicle_turret_control/attack_self(mob/living/user)
	if(!turret || user.buckled != turret.gunner_seat || !user.is_holding(src))
		balloon_alert(user, "sit at the gunner station!")
		return
	set_sight(user, !sight_active)
	balloon_alert(user, sight_active ? "gunsight engaged" : "gunsight disengaged")
	return TRUE

/obj/item/ms13_vehicle_turret_control/proc/set_sight(mob/living/user, enabled)
	if(sight_active == enabled || !user)
		return FALSE
	if(enabled && !user.client)
		return FALSE
	var/datum/ms13_ground_vehicle/vehicle = turret?.vehicle
	sight_active = enabled
	if(enabled)
		user.ms13_active_gunner_sight?.set_sight(user, FALSE)
		user.ms13_active_gunner_sight = src
		vehicle?.set_roof_visible(user.client, TRUE)
		user.clear_ms13_vehicle_interior_mask()
		update_sight()
		return TRUE
	if(user.ms13_active_gunner_sight == src)
		user.ms13_active_gunner_sight = null
	user.client?.view_size.zoomIn()
	if(user.client && vehicle && get_ms13_ground_vehicle_at(user) == vehicle)
		vehicle.set_roof_visible(user.client, FALSE)
	user.update_ms13_vehicle_interior_mask()
	return TRUE

/obj/item/ms13_vehicle_turret_control/proc/update_sight()
	if(!sight_active || !turret)
		return
	var/mob/living/user = loc
	if(!istype(user) || !user.client)
		return
	user.client.view_size.zoomOut(2, 3, turret.dir)

/obj/item/ms13_vehicle_turret_control/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	turret?.fire_at(interacting_with, user, modifiers)
	return ITEM_INTERACT_SUCCESS
