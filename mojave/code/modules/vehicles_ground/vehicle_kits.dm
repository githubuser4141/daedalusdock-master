/**
 * Vehicles built in-game, from the ground up. A floor frame laid on open ground starts a new vehicle, facing the way you
 * face; laid beside a vehicle's floor, it adds another tile to that vehicle. Hull panels, seats and parts are then fitted
 * to its floor. Panels and outside parts go on the edge you're working from, or, from aboard, the side you face.
 *
 * A wrench takes a part, panel or seat off whole, the thing itself inside what you carry: fuel, battery, contents and
 * damage go with it. A welder patches damaged parts and floor, and takes up a bare floor tile that nothing else hangs off.
 * Everything is made at workbenches, and parts come empty: no fuel in a tank, no battery in its box.
 *
 * Wrecks are mapped with a wreck spawner: the vehicle, left for dead. A parked vehicle's battery doesn't process, so a
 * map can carry plenty of them (see update_power_processing()).
 */

/// A vehicle built up in-game from one floor frame.
/datum/ms13_ground_vehicle/modular
	required_running_gear = 2

/// Builds frame_type on spot, facing facing: the vehicle is assembled facing that way from the start.
/proc/ms13_build_vehicle(obj/structure/ms13_vehicle_frame/frame_type, turf/spot, facing)
	var/static/builds = 0
	var/source = "ms13_build_vehicle_[++builds]"
	SSatoms.map_loader_begin(source)
	var/obj/structure/ms13_vehicle_frame/front = new frame_type(spot)
	front.dir = facing
	SSatoms.map_loader_stop(source)
	SSatoms.InitializeAtoms(list(front))
	return front

/// Room on spot for a floor frame: open, and nothing on it in the way.
/proc/ms13_frame_room(turf/spot)
	if(!spot || spot.density || (locate(/obj/structure/ms13_vehicle_frame) in spot))
		return FALSE
	for(var/atom/movable/thing in spot)
		if(thing.density && !isliving(thing))
			return FALSE
	return TRUE

/// Lays another floor frame on spot, beside the rest of the vehicle.
/datum/ms13_ground_vehicle/proc/extend_to(turf/spot)
	var/dx = spot.x - pivot.x
	var/dy = spot.y - pivot.y
	var/step_x = (dir & EAST) ? 1 : (dir & WEST) ? -1 : 0
	var/step_y = (dir & NORTH) ? 1 : (dir & SOUTH) ? -1 : 0
	// Forward is along the facing; right of (x, y) is (y, -x).
	var/obj/structure/ms13_vehicle_frame/segment = pivot.add_segment(dx * step_x + dy * step_y, dx * step_y - dy * step_x, pivot.icon_state, "roof_steel")
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/mob/living/passenger in get_turf(frame))
			if(passenger.client)
				set_roof_visible(passenger.client, FALSE)
	update_interior_masks()
	return segment

/// Would taking frame away leave the rest of the floor in one piece, around the pivot? The pivot goes only last.
/datum/ms13_ground_vehicle/proc/holds_together_without(obj/structure/ms13_vehicle_frame/frame)
	if(frame == pivot)
		return length(frames) == 1
	var/list/reached = list()
	reached[pivot] = TRUE
	var/list/queue = list(pivot)
	while(length(queue))
		var/obj/structure/ms13_vehicle_frame/current = queue[length(queue)]
		queue.len--
		for(var/direction in GLOB.cardinals)
			var/obj/structure/ms13_vehicle_frame/beside = get_frame_at(get_step(current, direction))
			if(beside && beside != frame && !reached[beside])
				reached[beside] = TRUE
				queue += beside
	return length(reached) == length(frames) - 1

/// Anything fitted to frame: a panel on its edges, a seat or a part on it.
/datum/ms13_ground_vehicle/proc/fitted_to(obj/structure/ms13_vehicle_frame/frame)
	if(LAZYLEN(frame.mounted_walls))
		return frame.mounted_walls[1]
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		if(part.forward_offset == frame.forward_offset && part.right_offset == frame.right_offset)
			return part
	for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
		if(seat.parent_frame == frame)
			return seat

/// A welder patches a damaged floor tile, or takes up a bare one, unless the rest of the floor hangs off it.
/obj/structure/ms13_vehicle_frame/welder_act(mob/living/user, obj/item/tool)
	if(!vehicle)
		return
	if(!tool.tool_start_check(user, amount = 1))
		return ITEM_INTERACT_BLOCKING
	if(get_integrity() < max_integrity)
		balloon_alert(user, "repairing...")
		if(tool.use_tool(src, user, 3 SECONDS, amount = 1, volume = 50))
			repair_damage(max_integrity)
		return ITEM_INTERACT_SUCCESS
	var/atom/fitted = vehicle.fitted_to(src)
	if(fitted)
		balloon_alert(user, "take off [fitted] first!")
		return ITEM_INTERACT_BLOCKING
	if(vehicle.moving || !vehicle.holds_together_without(src))
		balloon_alert(user, "the rest of the floor hangs off it!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "cutting it free...")
	if(!tool.use_tool(src, user, 5 SECONDS, amount = 1, volume = 50) || !vehicle || vehicle.fitted_to(src))
		return ITEM_INTERACT_BLOCKING
	take_up()
	user.put_in_hands(new /obj/item/ms13_vehicle_frame_kit(drop_location()))
	return ITEM_INTERACT_SUCCESS

/// Takes this floor tile out of its vehicle. The last one takes the vehicle with it.
/obj/structure/ms13_vehicle_frame/proc/take_up()
	var/datum/ms13_ground_vehicle/old_vehicle = vehicle
	qdel(src)
	if(!length(old_vehicle.frames))
		qdel(old_vehicle)

/// One tile of a vehicle's floor.
/obj/item/ms13_vehicle_frame_kit
	name = "vehicle floor frame"
	desc = "One tile of a vehicle's floor. Lay it on open ground to start a vehicle, facing the way you face, or beside a vehicle's floor to add to it."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "frame_steel"
	w_class = WEIGHT_CLASS_HUGE

/obj/item/ms13_vehicle_frame_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/turf/spot = get_turf(interacting_with)
	if(!ms13_frame_room(spot))
		return NONE
	var/datum/ms13_ground_vehicle/beside = frame_beside(spot)
	if(beside?.moving)
		balloon_alert(user, "it's moving!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "laying the frame...")
	if(!do_after(user, spot, 5 SECONDS) || !ms13_frame_room(spot) || QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	lay(spot, user.dir)
	return ITEM_INTERACT_SUCCESS

/// The vehicle with a floor beside spot, if any.
/obj/item/ms13_vehicle_frame_kit/proc/frame_beside(turf/spot)
	for(var/direction in GLOB.cardinals)
		var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(get_step(spot, direction))
		if(vehicle && !QDELETED(vehicle.pivot) && vehicle.pivot.z == spot.z)
			return vehicle

/// Lays the frame on spot: added to the vehicle beside it, or the start of a new one facing facing.
/obj/item/ms13_vehicle_frame_kit/proc/lay(turf/spot, facing)
	var/datum/ms13_ground_vehicle/beside = frame_beside(spot)
	. = beside ? beside.extend_to(spot) : ms13_start_vehicle(spot, facing)
	qdel(src)

/// A new vehicle: one floor frame on spot, facing facing.
/proc/ms13_start_vehicle(turf/spot, facing)
	var/obj/structure/ms13_vehicle_frame/frame = new(spot)
	var/datum/ms13_ground_vehicle/modular/vehicle = new
	frame.vehicle = vehicle
	vehicle.pivot = frame
	vehicle.dir = facing
	vehicle.frames += frame
	frame.setDir(facing)
	return frame

/// A hull panel, or the panel itself taken off a vehicle.
/obj/item/ms13_vehicle_wall_kit
	name = "vehicle hull panel"
	desc = "A panel of vehicle hull."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "c_wall"
	w_class = WEIGHT_CLASS_BULKY
	var/obj/structure/window/ms13_vehicle_wall/wall_type = /obj/structure/window/ms13_vehicle_wall/solid
	/// Its art, when not its type's own.
	var/wall_art
	/// A panel taken off a vehicle, whole.
	var/obj/structure/window/ms13_vehicle_wall/wall

/obj/item/ms13_vehicle_wall_kit/Initialize(mapload, obj/structure/window/ms13_vehicle_wall/loose_wall)
	. = ..()
	if(loose_wall)
		wall = loose_wall
		wall.forceMove(src)
		name = wall.name
		icon_state = wall.icon_state
		return
	name = initial(wall_type.name)
	icon_state = wall_art || initial(wall_type.icon_state)
	desc = "[initial(wall_type.desc)] Use it on a vehicle's floor to fit it on the edge you're working from."

/obj/item/ms13_vehicle_wall_kit/Destroy()
	QDEL_NULL(wall)
	return ..()

/obj/item/ms13_vehicle_wall_kit/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == wall)
		wall = null

/obj/item/ms13_vehicle_wall_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(interacting_with)
	var/obj/structure/ms13_vehicle_frame/frame = vehicle?.get_frame_at(get_turf(interacting_with))
	if(!frame)
		return NONE
	var/edge = get_turf(user) == get_turf(frame) ? user.dir : get_cardinal_dir(frame, user)
	if(vehicle.moving || frame.wall_on(edge))
		balloon_alert(user, vehicle.moving ? "it's moving!" : "there's a panel there!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "fitting the panel...")
	if(!do_after(user, frame, 4 SECONDS) || QDELETED(frame) || frame.wall_on(edge) || QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	fit(frame, edge)
	return ITEM_INTERACT_SUCCESS

/// Fits the panel on frame's edge facing edge.
/obj/item/ms13_vehicle_wall_kit/proc/fit(obj/structure/ms13_vehicle_frame/frame, edge)
	if(wall)
		. = frame.mount_wall(wall, edge)
		wall = null
	else
		. = frame.spawn_wall(edge, wall_art, wall_type)
	qdel(src)

/obj/item/ms13_vehicle_wall_kit/window
	wall_type = /obj/structure/window/ms13_vehicle_wall/shuttered
	wall_art = "c_window"

/obj/item/ms13_vehicle_wall_kit/windshield
	wall_type = /obj/structure/window/ms13_vehicle_wall/shuttered
	wall_art = "c_windshield"

/obj/item/ms13_vehicle_wall_kit/door
	wall_type = /obj/structure/window/ms13_vehicle_wall/solid/door

/obj/item/ms13_vehicle_wall_kit/power_door
	wall_type = /obj/structure/window/ms13_vehicle_wall/solid/door/power

/obj/item/ms13_vehicle_wall_kit/bulkhead
	wall_type = /obj/structure/window/ms13_vehicle_wall/solid/interior

/obj/item/ms13_vehicle_wall_kit/cabin_door
	wall_type = /obj/structure/window/ms13_vehicle_wall/solid/door/interior

/// The panel on this frame's edge facing edge, if any.
/obj/structure/ms13_vehicle_frame/proc/wall_on(edge)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in mounted_walls)
		if(wall.dir == edge)
			return wall

/// A wrench takes a panel off whole. Closed first, and only with nothing mounted on it.
/obj/structure/window/ms13_vehicle_wall/wrench_act(mob/living/user, obj/item/tool)
	var/datum/ms13_ground_vehicle/vehicle = parent_frame?.vehicle
	if(!vehicle)
		return ..()
	for(var/obj/structure/ms13_vehicle_part/exterior_equipment/part in vehicle.parts)
		if(part.forward_offset == forward_offset && part.right_offset == right_offset && part.dir == dir)
			balloon_alert(user, "take off [part] first!")
			return ITEM_INTERACT_BLOCKING
	if(vehicle.moving)
		balloon_alert(user, "it's moving!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "unbolting...")
	if(!tool.use_tool(src, user, 4 SECONDS, volume = 50) || parent_frame?.vehicle != vehicle)
		return ITEM_INTERACT_BLOCKING
	detach()
	user.put_in_hands(new /obj/item/ms13_vehicle_wall_kit(drop_location(), src))
	return ITEM_INTERACT_SUCCESS

/// Takes the panel off its frame whole.
/obj/structure/window/ms13_vehicle_wall/proc/detach()
	var/datum/ms13_ground_vehicle/vehicle = parent_frame?.vehicle
	var/obj/structure/window/ms13_vehicle_wall/solid/door/door = src
	if(istype(door) && door.opened)
		door.close()
	vehicle?.walls -= src
	LAZYREMOVE(parent_frame?.mounted_walls, src)
	parent_frame = null
	vehicle?.update_interior_masks()

/// A seat, or the seat itself taken off a vehicle.
/obj/item/ms13_vehicle_seat_kit
	name = "vehicle seat"
	desc = "A seat to bolt to a vehicle's floor, facing the way you face."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "commanders_seat"
	w_class = WEIGHT_CLASS_BULKY
	/// The driver's seat and dashboard, which faces the way the vehicle does.
	var/driver = FALSE

/obj/item/ms13_vehicle_seat_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(interacting_with)
	var/obj/structure/ms13_vehicle_frame/frame = vehicle?.get_frame_at(get_turf(interacting_with))
	if(!frame)
		return NONE
	if(vehicle.moving || (locate(/obj/structure/chair/ms13_vehicle_seat) in get_turf(frame)) || (driver && vehicle.driver_seat()))
		balloon_alert(user, vehicle.moving ? "it's moving!" : "there's a seat already!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "bolting it down...")
	if(!do_after(user, frame, 3 SECONDS) || QDELETED(frame) || (locate(/obj/structure/chair/ms13_vehicle_seat) in get_turf(frame)) || QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	fit(frame, user.dir)
	return ITEM_INTERACT_SUCCESS

/// Bolts the seat to frame facing facing, or for the driver's, the way the vehicle faces.
/obj/item/ms13_vehicle_seat_kit/proc/fit(obj/structure/ms13_vehicle_frame/frame, facing)
	var/datum/ms13_ground_vehicle/vehicle = frame.vehicle
	// dir2angle() increases clockwise, while turn() increases counter-clockwise.
	var/obj/structure/chair/ms13_vehicle_seat/seat = frame.add_seat(driver ? 0 : dir2angle(vehicle.dir) - dir2angle(facing), driver ? "driver's seat" : "vehicle seat", driver ? "driver_car" : "commanders_seat")
	if(driver)
		seat.configure_driver_seat()
	qdel(src)
	return seat

/obj/item/ms13_vehicle_seat_kit/driver
	name = "driver's seat and dashboard"
	desc = "The driver's seat and its control monitor. It's bolted to a vehicle's floor facing the way the vehicle faces."
	icon_state = "driver_car"
	driver = TRUE

/// The vehicle's driver's seat, if it has one.
/datum/ms13_ground_vehicle/proc/driver_seat()
	for(var/obj/structure/ms13_vehicle_frame/frame as anything in frames)
		for(var/obj/structure/chair/ms13_vehicle_seat/seat in get_turf(frame))
			if(seat.is_driver_seat)
				return seat

/// A wrench takes an empty seat off whole: a gunner's seat with the gun it works, once it's fired empty.
/obj/structure/chair/ms13_vehicle_seat/wrench_act(mob/living/user, obj/item/tool)
	if(!parent_frame?.vehicle)
		return ..()
	var/obj/structure/ms13_vehicle_part/turret/machine_gun/mounted_gun = operated_turret
	if(has_buckled_mobs() || (operated_turret && (!istype(mounted_gun) || mounted_gun.ammo)))
		balloon_alert(user, has_buckled_mobs() ? "someone's in it!" : operated_turret.ammo ? "fire it empty first!" : "it works the turret!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "unbolting...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50) || has_buckled_mobs())
		return ITEM_INTERACT_BLOCKING
	var/obj/item/kit
	if(mounted_gun)
		kit = new /obj/item/ms13_vehicle_gun_mount_kit(drop_location())
		qdel(mounted_gun)
	else
		kit = is_driver_seat ? new /obj/item/ms13_vehicle_seat_kit/driver(drop_location()) : new /obj/item/ms13_vehicle_seat_kit(drop_location())
	qdel(src)
	user.put_in_hands(kit)
	return ITEM_INTERACT_SUCCESS

/// A 7.62mm machine gun on a ring mount, and the gunner's seat that works it.
/obj/item/ms13_vehicle_gun_mount_kit
	name = "machine gun mount"
	desc = "A 7.62mm machine gun on a ring mount, with the gunner's seat that works it. Use it on a vehicle's floor where there's no seat yet. It comes unloaded: load it from the gunner's seat."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "commanders_seat"
	w_class = WEIGHT_CLASS_HUGE

/obj/item/ms13_vehicle_gun_mount_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(interacting_with)
	var/obj/structure/ms13_vehicle_frame/frame = vehicle?.get_frame_at(get_turf(interacting_with))
	if(!frame)
		return NONE
	if(vehicle.moving || (locate(/obj/structure/chair/ms13_vehicle_seat) in get_turf(frame)))
		balloon_alert(user, vehicle.moving ? "it's moving!" : "there's a seat already!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "mounting the gun...")
	if(!do_after(user, frame, 8 SECONDS) || QDELETED(frame) || (locate(/obj/structure/chair/ms13_vehicle_seat) in get_turf(frame)) || QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	fit(frame, user.dir)
	return ITEM_INTERACT_SUCCESS

/// Mounts the gun on frame, and the gunner's seat under it facing facing. Returns the gun.
/obj/item/ms13_vehicle_gun_mount_kit/proc/fit(obj/structure/ms13_vehicle_frame/frame, facing)
	var/datum/ms13_ground_vehicle/vehicle = frame.vehicle
	var/obj/structure/ms13_vehicle_part/turret/machine_gun/gun = frame.spawn_part(/obj/structure/ms13_vehicle_part/turret/machine_gun)
	gun.name = "machine gun turret"
	gun.set_art("mtlb", 0, 0, frame.hull_color)
	gun.ammo = 0
	gun.loaded_rounds = list()
	gun.selected_round = null
	// dir2angle() increases clockwise, while turn() increases counter-clockwise.
	var/obj/structure/chair/ms13_vehicle_seat/seat = frame.add_seat(dir2angle(vehicle.dir) - dir2angle(facing), "gunner's seat")
	seat.operated_turret = gun
	gun.gunner_seat = seat
	qdel(src)
	return gun

/// A vehicle part off its vehicle, the part inside.
/obj/item/ms13_vehicle_part_kit
	name = "vehicle part"
	desc = "A vehicle part."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "carengine_static"
	w_class = WEIGHT_CLASS_BULKY
	var/obj/structure/ms13_vehicle_part/part
	/// For a new one, made by hand: the part to make.
	var/part_type

/obj/item/ms13_vehicle_part_kit/Initialize(mapload, obj/structure/ms13_vehicle_part/loose_part)
	. = ..()
	if(!loose_part)
		loose_part = new part_type(src)
		loose_part.stock_on_fit = FALSE
	part = loose_part
	part.forceMove(src)
	name = part.name
	desc = "[part.desc] Use it on a vehicle's floor to bolt it on there."
	var/list/art = part.loose_art()
	icon = art[1]
	icon_state = art[2]

/obj/item/ms13_vehicle_part_kit/Destroy()
	QDEL_NULL(part)
	return ..()

/obj/item/ms13_vehicle_part_kit/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == part)
		part = null

/obj/item/ms13_vehicle_part_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/ms13_ground_vehicle/vehicle = get_ms13_ground_vehicle_at(interacting_with)
	var/obj/structure/ms13_vehicle_frame/frame = vehicle?.get_frame_at(get_turf(interacting_with))
	if(!frame || !part)
		return NONE
	if(vehicle.moving)
		balloon_alert(user, "it's moving!")
		return ITEM_INTERACT_BLOCKING
	var/facing = get_turf(user) == get_turf(frame) ? user.dir : get_cardinal_dir(frame, user)
	balloon_alert(user, "bolting on...")
	if(!do_after(user, frame, part.fitting_time) || QDELETED(frame) || !frame.vehicle || part?.loc != src)
		return ITEM_INTERACT_BLOCKING
	part.fit_to(frame, facing)
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/item/ms13_vehicle_part_kit/engine
	part_type = /obj/structure/ms13_vehicle_part/engine

/obj/item/ms13_vehicle_part_kit/gearbox
	part_type = /obj/structure/ms13_vehicle_part/gearbox

/obj/item/ms13_vehicle_part_kit/gearbox/three_speed
	part_type = /obj/structure/ms13_vehicle_part/gearbox/three_speed

/obj/item/ms13_vehicle_part_kit/gearbox/five_speed
	part_type = /obj/structure/ms13_vehicle_part/gearbox/five_speed

/obj/item/ms13_vehicle_part_kit/traction_motor
	part_type = /obj/structure/ms13_vehicle_part/gearbox/traction

/obj/item/ms13_vehicle_part_kit/fuel_tank
	part_type = /obj/structure/ms13_vehicle_part/fuel_tank

/obj/item/ms13_vehicle_part_kit/fuel_tank/large
	part_type = /obj/structure/ms13_vehicle_part/fuel_tank/large

/obj/item/ms13_vehicle_part_kit/external_fuel_tank
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/fuel_tank

/obj/item/ms13_vehicle_part_kit/wheel
	part_type = /obj/structure/ms13_vehicle_part/running_gear/wheel

/obj/item/ms13_vehicle_part_kit/track
	part_type = /obj/structure/ms13_vehicle_part/running_gear/track

/obj/item/ms13_vehicle_part_kit/battery_box
	part_type = /obj/structure/ms13_vehicle_part/battery

/obj/item/ms13_vehicle_part_kit/battery_cutout
	part_type = /obj/structure/ms13_vehicle_part/battery_cutout

/obj/item/ms13_vehicle_part_kit/alternator
	part_type = /obj/structure/ms13_vehicle_part/alternator

/obj/item/ms13_vehicle_part_kit/alternator/bike
	part_type = /obj/structure/ms13_vehicle_part/alternator/bike

/obj/item/ms13_vehicle_part_kit/alternator/truck
	part_type = /obj/structure/ms13_vehicle_part/alternator/truck

/obj/item/ms13_vehicle_part_kit/headlight
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/light

/obj/item/ms13_vehicle_part_kit/dome_light
	part_type = /obj/structure/ms13_vehicle_part/interior_light

/obj/item/ms13_vehicle_part_kit/instrument_lamp
	part_type = /obj/structure/ms13_vehicle_part/interior_light/instrument

/obj/item/ms13_vehicle_part_kit/camera
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/camera

/obj/item/ms13_vehicle_part_kit/camera/thermal
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/thermal

/obj/item/ms13_vehicle_part_kit/camera/night_vision
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/night_vision

/obj/item/ms13_vehicle_part_kit/camera/wide
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/wide

/obj/item/ms13_vehicle_part_kit/camera/zoom
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/camera/zoom

/obj/item/ms13_vehicle_part_kit/solar_panel
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/solar_panel

/obj/item/ms13_vehicle_part_kit/scoop
	part_type = /obj/structure/ms13_vehicle_part/exterior_equipment/scoop

/obj/item/ms13_vehicle_part_kit/welding_rig
	part_type = /obj/structure/ms13_vehicle_part/welding_rig

/obj/item/ms13_vehicle_part_kit/smoke_generator
	part_type = /obj/structure/ms13_vehicle_part/smoke_generator

/obj/item/ms13_vehicle_part_kit/stowage
	part_type = /obj/structure/ms13_vehicle_part/stowage

/obj/item/ms13_vehicle_part_kit/freezer
	part_type = /obj/structure/ms13_vehicle_part/stowage/freezer

/obj/item/ms13_vehicle_part_kit/freezer/mini
	part_type = /obj/structure/ms13_vehicle_part/stowage/freezer/mini

/obj/item/ms13_vehicle_part_kit/recharge_station
	part_type = /obj/structure/ms13_vehicle_part/stowage/recharge_station

/obj/item/ms13_vehicle_part_kit/route_terminal
	part_type = /obj/structure/ms13_vehicle_part/rail_terminal

/obj/item/ms13_vehicle_part_kit/camera_console
	part_type = /obj/structure/ms13_vehicle_part/camera_console

/**
 * Leaves the vehicle for dead: each part gone or broken at random, the tanks drained, the battery flat, the racks
 * emptied and the hull holed. Everything can be repaired or replaced to drive it again.
 */
/datum/ms13_ground_vehicle/proc/wreck(missing_chance, broken_chance, holed_chance)
	set_ignition(FALSE)
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts.Copy())
		if(part.removable && prob(missing_chance))
			qdel(part)
			continue
		if(prob(broken_chance))
			part.update_integrity(part.max_integrity * part.integrity_failure * rand(10, 90) / 100)
		part.reagents?.remove_all(max(0, part.reagents.total_volume - rand(0, 5)))
		if(istype(part, /obj/structure/ms13_vehicle_part/battery))
			var/obj/structure/ms13_vehicle_part/battery/battery = part
			battery.cell?.charge = 0
		else if(istype(part, /obj/structure/ms13_vehicle_part/turret))
			var/obj/structure/ms13_vehicle_part/turret/turret = part
			turret.ammo = 0
			turret.loaded_rounds = list()
			turret.selected_round = null
		else if(istype(part, /obj/structure/ms13_vehicle_part/stowage))
			for(var/obj/item/stowed in part)
				qdel(stowed)
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in walls.Copy())
		if(wall.exterior && prob(holed_chance))
			wall.update_integrity(wall.max_integrity * rand(5, 30) / 100)

/// A vehicle left for dead, mapped in. Rotate it to set the way the vehicle faces.
/obj/effect/ms13_vehicle_wreck
	name = "vehicle wreck spawner"
	icon = 'mojave/icons/structure/crates.dmi'
	icon_state = "army"
	invisibility = INVISIBILITY_ABSTRACT
	var/obj/structure/ms13_vehicle_frame/frame_type = /obj/structure/ms13_vehicle_frame/jeep_front
	/// Chance each part is gone, and that each one left is broken.
	var/missing_chance = 40
	var/broken_chance = 50
	/// Chance each outer hull panel is holed.
	var/holed_chance = 30

/obj/effect/ms13_vehicle_wreck/Initialize(mapload)
	. = ..()
	var/obj/structure/ms13_vehicle_frame/front = ms13_build_vehicle(frame_type, get_turf(src), dir)
	front.vehicle?.wreck(missing_chance, broken_chance, holed_chance)
	return INITIALIZE_HINT_QDEL

/obj/effect/ms13_vehicle_wreck/armored_truck
	frame_type = /obj/structure/ms13_vehicle_frame/armored_truck_front_left

/obj/effect/ms13_vehicle_wreck/m113
	frame_type = /obj/structure/ms13_vehicle_frame/m113/front_left

/obj/effect/ms13_vehicle_wreck/btr80
	frame_type = /obj/structure/ms13_vehicle_frame/civ96/btr80

/obj/effect/ms13_vehicle_wreck/mtlb
	frame_type = /obj/structure/ms13_vehicle_frame/civ96/mtlb

/obj/effect/ms13_vehicle_wreck/bmd2
	frame_type = /obj/structure/ms13_vehicle_frame/civ96/bmd2

/obj/effect/ms13_vehicle_wreck/t34
	frame_type = /obj/structure/ms13_vehicle_frame/civ96/t34

/obj/effect/ms13_vehicle_wreck/is3
	frame_type = /obj/structure/ms13_vehicle_frame/civ96/is3

/obj/effect/ms13_vehicle_wreck/tram
	frame_type = /obj/structure/ms13_vehicle_frame/tram

/obj/effect/ms13_vehicle_wreck/train
	frame_type = /obj/structure/ms13_vehicle_frame/tram/train

// Recipes. Every crafting_recipe subtype is a recipe, so each carries its own bench and category.

/datum/crafting_recipe/ms13_vehicle_frame
	name = "vehicle floor frame"
	result = /obj/item/ms13_vehicle_frame_kit
	time = 20 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 6, /obj/item/stack/sheet/ms13/scrap_parts = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_plating
	name = "vehicle hull plating"
	result = /obj/item/ms13_vehicle_wall_kit
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 4)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_window
	name = "vehicle window"
	result = /obj/item/ms13_vehicle_wall_kit/window
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WELDER, TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/glass = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_windshield
	name = "vehicle windshield"
	result = /obj/item/ms13_vehicle_wall_kit/windshield
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WELDER, TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/glass = 3)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_door
	name = "vehicle door"
	result = /obj/item/ms13_vehicle_wall_kit/door
	time = 20 SECONDS
	tool_behaviors = list(TOOL_WELDER, TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 4, /obj/item/stack/sheet/ms13/scrap_parts = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_power_door
	name = "vehicle power door"
	result = /obj/item/ms13_vehicle_wall_kit/power_door
	time = 30 SECONDS
	tool_behaviors = list(TOOL_WELDER, TOOL_WRENCH, TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 4, /obj/item/stack/sheet/ms13/scrap_parts = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 2, /obj/item/stack/sheet/ms13/scrap_copper = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_bulkhead
	name = "vehicle bulkhead"
	result = /obj/item/ms13_vehicle_wall_kit/bulkhead
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 3)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wall_cabin_door
	name = "vehicle cabin door"
	result = /obj/item/ms13_vehicle_wall_kit/cabin_door
	time = 20 SECONDS
	tool_behaviors = list(TOOL_WELDER, TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/scrap_parts = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_seat
	name = "vehicle seat"
	result = /obj/item/ms13_vehicle_seat_kit
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 1, /obj/item/stack/sheet/ms13/leather = 2, /obj/item/stack/sheet/ms13/cloth = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_driver_seat
	name = "driver's seat and dashboard"
	result = /obj/item/ms13_vehicle_seat_kit/driver
	time = 30 SECONDS
	tool_behaviors = list(TOOL_WRENCH, TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/leather = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/circuits = 1, /obj/item/stack/sheet/ms13/glass = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_gun_mount
	name = "machine gun mount"
	result = /obj/item/ms13_vehicle_gun_mount_kit
	time = 60 SECONDS
	tool_behaviors = list(TOOL_WRENCH, TOOL_WELDER, TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 8, /obj/item/stack/sheet/ms13/scrap_parts = 10, /obj/item/stack/sheet/ms13/leather = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_WEAPONS

/datum/crafting_recipe/ms13_vehicle_engine
	name = "vehicle engine"
	result = /obj/item/ms13_vehicle_part_kit/engine
	time = 40 SECONDS
	tool_behaviors = list(TOOL_WRENCH, TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 8, /obj/item/stack/sheet/ms13/scrap_parts = 12, /obj/item/stack/sheet/ms13/scrap_copper = 4, /obj/item/stack/sheet/ms13/rubber = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_gearbox
	name = "four-speed gearbox"
	result = /obj/item/ms13_vehicle_part_kit/gearbox
	time = 30 SECONDS
	tool_behaviors = list(TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 4, /obj/item/stack/sheet/ms13/scrap_parts = 8)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_gearbox_three
	name = "three-speed gearbox"
	result = /obj/item/ms13_vehicle_part_kit/gearbox/three_speed
	time = 25 SECONDS
	tool_behaviors = list(TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/scrap_parts = 6)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_gearbox_five
	name = "five-speed gearbox"
	result = /obj/item/ms13_vehicle_part_kit/gearbox/five_speed
	time = 40 SECONDS
	tool_behaviors = list(TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 6, /obj/item/stack/sheet/ms13/scrap_parts = 12)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_traction_motor
	name = "traction motor"
	result = /obj/item/ms13_vehicle_part_kit/traction_motor
	time = 40 SECONDS
	tool_behaviors = list(TOOL_WRENCH, TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 4, /obj/item/stack/sheet/ms13/refined_copper = 8, /obj/item/stack/sheet/ms13/scrap_parts = 6)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_fuel_tank
	name = "fuel tank"
	result = /obj/item/ms13_vehicle_part_kit/fuel_tank
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 3)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_fuel_tank_large
	name = "large fuel tank"
	result = /obj/item/ms13_vehicle_part_kit/fuel_tank/large
	time = 20 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 5)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_external_fuel_tank
	name = "external fuel tank"
	result = /obj/item/ms13_vehicle_part_kit/external_fuel_tank
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/leather = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_wheel
	name = "vehicle wheel"
	result = /obj/item/ms13_vehicle_part_kit/wheel
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/rubber = 4, /obj/item/stack/sheet/ms13/refined_steel = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_track
	name = "track assembly"
	result = /obj/item/ms13_vehicle_part_kit/track
	time = 40 SECONDS
	tool_behaviors = list(TOOL_WRENCH, TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 10, /obj/item/stack/sheet/ms13/scrap_parts = 8, /obj/item/stack/sheet/ms13/rubber = 4)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_battery_box
	name = "vehicle battery box"
	result = /obj/item/ms13_vehicle_part_kit/battery_box
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 1, /obj/item/stack/sheet/ms13/scrap_copper = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_battery_cutout
	name = "low-voltage cut-out"
	result = /obj/item/ms13_vehicle_part_kit/battery_cutout
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 1, /obj/item/stack/sheet/ms13/scrap_electronics = 2, /obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_battery_bike
	name = "motorcycle battery"
	result = /obj/item/stock_parts/cell/ms13_vehicle/bike
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_lead = 3, /obj/item/stack/sheet/ms13/scrap_copper = 1, /obj/item/stack/sheet/ms13/plastic = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_battery_car
	name = "car battery"
	result = /obj/item/stock_parts/cell/ms13_vehicle
	time = 20 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_lead = 6, /obj/item/stack/sheet/ms13/scrap_copper = 2, /obj/item/stack/sheet/ms13/plastic = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_battery_truck
	name = "truck battery"
	result = /obj/item/stock_parts/cell/ms13_vehicle/truck
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_lead = 10, /obj/item/stack/sheet/ms13/scrap_copper = 4, /obj/item/stack/sheet/ms13/plastic = 4)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_battery_storage
	name = "storage battery bank"
	result = /obj/item/stock_parts/cell/ms13_vehicle/storage
	time = 60 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_lead = 30, /obj/item/stack/sheet/ms13/scrap_copper = 10, /obj/item/stack/sheet/ms13/plastic = 10, /obj/item/stack/sheet/ms13/scrap_electronics = 6)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_alternator_bike
	name = "motorcycle alternator"
	result = /obj/item/ms13_vehicle_part_kit/alternator/bike
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_copper = 3, /obj/item/stack/sheet/ms13/refined_steel = 1, /obj/item/stack/sheet/ms13/scrap_parts = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_alternator
	name = "car alternator"
	result = /obj/item/ms13_vehicle_part_kit/alternator
	time = 20 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_copper = 6, /obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/scrap_parts = 4)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_alternator_truck
	name = "truck alternator"
	result = /obj/item/ms13_vehicle_part_kit/alternator/truck
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_copper = 10, /obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/scrap_parts = 6)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_headlight
	name = "vehicle headlight"
	result = /obj/item/ms13_vehicle_part_kit/headlight
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/glass = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 1, /obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_dome_light
	name = "vehicle dome light"
	result = /obj/item/ms13_vehicle_part_kit/dome_light
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/glass = 1, /obj/item/stack/sheet/ms13/scrap_electronics = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_instrument_lamp
	name = "instrument panel lamp"
	result = /obj/item/ms13_vehicle_part_kit/instrument_lamp
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/glass = 1, /obj/item/stack/sheet/ms13/scrap_electronics = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_camera
	name = "vehicle exterior camera"
	result = /obj/item/ms13_vehicle_part_kit/camera
	time = 20 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 3, /obj/item/stack/sheet/ms13/glass = 1, /obj/item/stack/sheet/ms13/refined_steel = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_camera_thermal
	name = "vehicle thermal camera"
	result = /obj/item/ms13_vehicle_part_kit/camera/thermal
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 4, /obj/item/stack/sheet/ms13/scrap_electronics = 5, /obj/item/stack/sheet/ms13/glass = 1, /obj/item/stack/sheet/ms13/refined_steel = 1, /obj/item/stack/sheet/ms13/refined_gold = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_camera_night_vision
	name = "vehicle night vision camera"
	result = /obj/item/ms13_vehicle_part_kit/camera/night_vision
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 3, /obj/item/stack/sheet/ms13/scrap_electronics = 5, /obj/item/stack/sheet/ms13/glass = 2, /obj/item/stack/sheet/ms13/refined_steel = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_camera_wide
	name = "vehicle wide-angle camera"
	result = /obj/item/ms13_vehicle_part_kit/camera/wide
	time = 25 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/glass = 3, /obj/item/stack/sheet/ms13/refined_steel = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_camera_zoom
	name = "vehicle zoom camera"
	result = /obj/item/ms13_vehicle_part_kit/camera/zoom
	time = 25 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/glass = 4, /obj/item/stack/sheet/ms13/refined_steel = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_solar_panel
	name = "vehicle solar panel"
	result = /obj/item/ms13_vehicle_part_kit/solar_panel
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/glass = 4, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/circuits = 2, /obj/item/stack/sheet/ms13/refined_alu = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_scoop
	name = "vehicle scoop"
	result = /obj/item/ms13_vehicle_part_kit/scoop
	time = 20 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/scrap_parts = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_welding_rig
	name = "vehicle welding set"
	result = /obj/item/ms13_vehicle_part_kit/welding_rig
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/scrap_copper = 6, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/rubber = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_smoke_generator
	name = "smoke generator"
	result = /obj/item/ms13_vehicle_part_kit/smoke_generator
	time = 25 SECONDS
	tool_behaviors = list(TOOL_WRENCH, TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/scrap_parts = 4, /obj/item/stack/sheet/ms13/rubber = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_stowage
	name = "vehicle stowage rack"
	result = /obj/item/ms13_vehicle_part_kit/stowage
	time = 15 SECONDS
	tool_behaviors = list(TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/wood = 4)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_freezer
	name = "vehicle chest freezer"
	result = /obj/item/ms13_vehicle_part_kit/freezer
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 4, /obj/item/stack/sheet/ms13/scrap_copper = 4, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/circuits = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_minifreezer
	name = "vehicle minifreezer"
	result = /obj/item/ms13_vehicle_part_kit/freezer/mini
	time = 20 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 2, /obj/item/stack/sheet/ms13/scrap_copper = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_recharge_station
	name = "vehicle recharge station"
	result = /obj/item/ms13_vehicle_part_kit/recharge_station
	time = 25 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_copper = 4, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/circuits = 2, /obj/item/stack/sheet/ms13/refined_steel = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_route_terminal
	name = "rail route terminal"
	result = /obj/item/ms13_vehicle_part_kit/route_terminal
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 3, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/glass = 2, /obj/item/stack/sheet/ms13/plastic = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_vehicle_armor_steel
	name = "steel appliqué plate"
	result = /obj/item/ms13_vehicle_armor
	time = 30 SECONDS
	tool_behaviors = list(TOOL_WELDER)
	reqs = list(/obj/item/stack/sheet/ms13/refined_steel = 8)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_vehicle_armor_ceramic
	name = "ceramic add-on armor module"
	result = /obj/item/ms13_vehicle_armor/ceramic
	time = 45 SECONDS
	tool_behaviors = list(TOOL_WELDER, TOOL_WRENCH)
	reqs = list(/obj/item/stack/sheet/ms13/ceramic = 6, /obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/kevlar = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ARMTAILOR

/datum/crafting_recipe/ms13_vehicle_camera_console
	name = "vehicle camera console"
	result = /obj/item/ms13_vehicle_part_kit/camera_console
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 2, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/glass = 2, /obj/item/stack/sheet/ms13/refined_steel = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_remote_viewing_module
	name = "remote viewing module"
	result = /obj/item/ms13_remote_viewing_module
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 4, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/refined_gold = 1)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

#ifdef UNIT_TESTS
/// A vehicle built up from one floor frame: floor, hull, seats and parts, then driven. A wrench takes a part or a panel
/// off whole and it goes back on as it was; a part made by hand comes empty; a welder takes up a bare floor tile.
/datum/unit_test/ms13_vehicle_kits
	name = "VEHICLES: A Vehicle Built From One Floor Frame Drives"

/datum/unit_test/ms13_vehicle_kits/Run()
	var/turf/front_spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/back_spot = get_step(front_spot, WEST)
	var/obj/item/ms13_vehicle_frame_kit/first = allocate(/obj/item/ms13_vehicle_frame_kit)
	var/obj/structure/ms13_vehicle_frame/front = first.lay(front_spot, EAST)
	var/datum/ms13_ground_vehicle/vehicle = front.vehicle
	if(!istype(vehicle, /datum/ms13_ground_vehicle/modular) || vehicle.dir != EAST || vehicle.pivot != front)
		Fail("A floor frame on open ground didn't start a vehicle facing the way it was laid.")
		return
	var/obj/item/ms13_vehicle_frame_kit/second = allocate(/obj/item/ms13_vehicle_frame_kit)
	var/obj/structure/ms13_vehicle_frame/back = second.lay(back_spot, NORTH)
	if(back?.vehicle != vehicle || back.forward_offset != -1 || back.right_offset || get_turf(back) != back_spot)
		Fail("A floor frame beside a vehicle didn't join it, a tile behind its front.")
		return
	var/obj/item/ms13_vehicle_wall_kit/window/left_window = allocate(/obj/item/ms13_vehicle_wall_kit/window)
	var/obj/structure/window/ms13_vehicle_wall/window = left_window.fit(front, NORTH)
	if(!(window in vehicle.walls) || window.dir != NORTH || front.wall_on(NORTH) != window)
		Fail("A hull panel didn't fit on the edge it was fitted to.")
	var/obj/item/ms13_vehicle_seat_kit/driver/driver_kit = allocate(/obj/item/ms13_vehicle_seat_kit/driver)
	var/obj/structure/chair/ms13_vehicle_seat/driver_seat = driver_kit.fit(front, SOUTH)
	if(!driver_seat.is_driver_seat || driver_seat.dir != EAST || vehicle.driver_seat() != driver_seat)
		Fail("A driver's seat didn't face the way the vehicle does.")
	for(var/part_kit_type in list(/obj/item/ms13_vehicle_part_kit/engine, /obj/item/ms13_vehicle_part_kit/gearbox, /obj/item/ms13_vehicle_part_kit/battery_box))
		var/obj/item/ms13_vehicle_part_kit/part_kit = allocate(part_kit_type)
		part_kit.part.fit_to(front, EAST)
		qdel(part_kit)
	var/obj/item/ms13_vehicle_part_kit/fuel_tank/tank_kit = allocate(/obj/item/ms13_vehicle_part_kit/fuel_tank)
	var/obj/structure/ms13_vehicle_part/fuel_tank/tank = tank_kit.part
	tank.fit_to(back, EAST)
	qdel(tank_kit)
	for(var/list/wheel_spot in list(list(front, NORTH), list(front, SOUTH), list(back, NORTH), list(back, SOUTH)))
		var/obj/item/ms13_vehicle_part_kit/wheel/wheel_kit = allocate(/obj/item/ms13_vehicle_part_kit/wheel)
		wheel_kit.part.fit_to(wheel_spot[1], wheel_spot[2])
		qdel(wheel_kit)
	if(tank.reagents.total_volume || vehicle.battery?.cell || (locate(/obj/structure/ms13_vehicle_part/alternator) in vehicle.parts))
		Fail("Parts made by hand came with fuel, a battery or an alternator.")
	tank.reagents.add_reagent(/datum/reagent/fuel, 50)
	vehicle.battery.cell = new /obj/item/stock_parts/cell/ms13_vehicle(vehicle.battery)
	vehicle.set_ignition(TRUE)
	if(!vehicle.start_engine() || !vehicle.has_motive_power())
		Fail("A vehicle built up from its floor, with an engine, gearbox, fuel, a battery and wheels, wouldn't drive.")
	vehicle.stop_engine()
	vehicle.set_ignition(FALSE)

	// Parts and panels come off whole and go back on as they were.
	var/mob/living/carbon/human/consistent/mechanic = allocate(/mob/living/carbon/human/consistent, front_spot)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	mechanic.put_in_active_hand(wrench)
	tank.wrench_act(mechanic, wrench)
	var/obj/item/ms13_vehicle_part_kit/off = locate() in mechanic.held_items
	if(off?.part != tank || vehicle.fuel_tank || tank.reagents.total_volume != 50)
		Fail("A wrench didn't take the fuel tank off whole.")
		return
	tank.fit_to(back, EAST)
	qdel(off)
	if(vehicle.fuel_tank != tank || tank.reagents.total_volume != 50)
		Fail("A fuel tank bolted back on didn't come back as it was.")
	window.wrench_act(mechanic, wrench)
	var/obj/item/ms13_vehicle_wall_kit/panel = locate() in mechanic.held_items
	if(panel?.wall != window || (window in vehicle.walls))
		Fail("A wrench didn't take a hull panel off whole.")
		return
	panel.fit(back, SOUTH)
	if(window.parent_frame != back || window.dir != SOUTH || !(window in vehicle.walls))
		Fail("A hull panel taken off didn't fit again elsewhere.")

	// A bare floor tile takes up; one with a panel on it, or the pivot of a longer floor, won't.
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	mechanic.dropItemToGround(wrench)
	mechanic.put_in_active_hand(welder)
	welder.welding = TRUE
	if(back.welder_act(mechanic, welder) == ITEM_INTERACT_SUCCESS)
		Fail("A floor tile with things fitted to it was taken up.")
	var/obj/item/ms13_vehicle_frame_kit/third = allocate(/obj/item/ms13_vehicle_frame_kit)
	var/obj/structure/ms13_vehicle_frame/tail = third.lay(get_step(back_spot, WEST), NORTH)
	if(vehicle.holds_together_without(back) || vehicle.holds_together_without(front) || !vehicle.holds_together_without(tail))
		Fail("The floor's pieces weren't told apart from what holds it together.")

	// A gun mount comes unloaded, and its gunner's seat works it.
	var/obj/item/ms13_vehicle_gun_mount_kit/mount = allocate(/obj/item/ms13_vehicle_gun_mount_kit)
	var/obj/structure/ms13_vehicle_part/turret/machine_gun/gun = mount.fit(tail, NORTH)
	if(gun.ammo || !gun.gunner_seat || gun.gunner_seat.operated_turret != gun || get_turf(gun.gunner_seat) != get_turf(tail))
		Fail("A gun mount didn't come unloaded, worked from its own gunner's seat.")

/// A parked vehicle's battery doesn't process; a wreck is drained, flat and broken; a welder mends a broken part.
/datum/unit_test/ms13_vehicle_wrecks
	name = "VEHICLES: Parked Vehicles Sleep, Wrecks Are Left For Dead And Mend"

/datum/unit_test/ms13_vehicle_wrecks/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = new(spot)
	var/datum/ms13_ground_vehicle/vehicle = front.vehicle
	if(vehicle.battery.datum_flags & DF_ISPROCESSING)
		Fail("A parked vehicle's battery was processing.")
	vehicle.set_ignition(TRUE)
	if(!(vehicle.battery.datum_flags & DF_ISPROCESSING))
		Fail("Switching the ignition on didn't wake the battery.")
	vehicle.wreck(0, 100, 100)
	if(vehicle.battery.datum_flags & DF_ISPROCESSING)
		Fail("A wreck's battery kept processing.")
	if(vehicle.fuel_tank.reagents.total_volume > 5 || vehicle.battery.cell.charge)
		Fail("A wreck kept its fuel or its battery charge.")
	var/obj/structure/ms13_vehicle_part/engine/engine = vehicle.engine
	if(!engine.broken)
		Fail("A wreck's parts weren't broken.")
	for(var/obj/structure/window/ms13_vehicle_wall/wall as anything in vehicle.walls)
		if(wall.exterior && !wall.hull_broken)
			Fail("A wreck's hull wasn't holed.")
			break
	var/mob/living/carbon/human/consistent/mechanic = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	mechanic.put_in_active_hand(welder)
	welder.welding = TRUE
	engine.welder_act(mechanic, welder)
	if(engine.broken || engine.get_integrity() < engine.max_integrity)
		Fail("A welder didn't mend a broken engine.")
	vehicle.wreck(100, 0, 0)
	for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts)
		if(part.removable)
			Fail("A wreck kept a [part] it should have lost.")
			break
#endif
