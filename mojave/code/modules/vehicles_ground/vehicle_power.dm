/// Shared electrical bus; one battery processor per vehicle, not one per lamp/camera.
/datum/ms13_ground_vehicle
	var/obj/structure/ms13_vehicle_part/battery/battery
	var/ignition = FALSE
	var/engine_running = FALSE
	var/interior_lights_on = TRUE
	var/exterior_lights_on = FALSE
	var/cameras_on = TRUE
	var/next_horn_time = 0
	var/starter_cost = 100
	var/alternator_rate = 20
	var/idle_fuel_rate = 0.01
	var/electrical_live = FALSE

/datum/ms13_ground_vehicle/proc/has_electrical_power()
	return ignition && battery?.is_operational() && battery.cell?.charge > 0

/datum/ms13_ground_vehicle/proc/use_battery(amount)
	if(!has_electrical_power() || !battery.cell.use(amount))
		return FALSE
	if(!battery.cell.charge)
		update_electrical()
	return TRUE

/datum/ms13_ground_vehicle/proc/start_engine(mob/user)
	if(QDELETED(pivot))
		return FALSE
	if(engine_running && engine?.is_operational())
		return TRUE
	if(!engine?.is_operational())
		if(user)
			to_chat(user, span_warning("The engine is damaged, missing, or out of fuel."))
		return FALSE
	if(!ignition || !use_battery(starter_cost))
		if(user)
			to_chat(user, span_warning("Switch on the ignition and check the battery: the starter needs [starter_cost] charge."))
		return FALSE
	engine_running = TRUE
	engine.set_moving(moving)
	return TRUE

/datum/ms13_ground_vehicle/proc/stop_engine()
	engine_running = FALSE
	engine?.set_moving(moving)

/datum/ms13_ground_vehicle/proc/set_ignition(enabled)
	ignition = enabled
	if(!ignition)
		stop_engine()
	update_electrical()

/datum/ms13_ground_vehicle/proc/process_power(seconds_per_tick)
	if(engine_running)
		if(!ignition || !engine?.is_operational())
			stop_engine()
		else
			engine.consume_fuel(idle_fuel_rate * seconds_per_tick)
			if(engine_running && battery?.is_operational())
				battery.cell?.give(alternator_rate * seconds_per_tick)
	if(has_electrical_power())
		var/load = 1 // Ignition/instruments.
		for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
			if(istype(part, /obj/structure/ms13_vehicle_part/interior_light))
				var/obj/structure/ms13_vehicle_part/interior_light/lamp = part
				if(lamp.is_lit())
					load += 1
			else if(istype(part, /obj/structure/ms13_vehicle_part/exterior_equipment))
				var/obj/structure/ms13_vehicle_part/exterior_equipment/equipment = part
				if(equipment.is_enabled())
					load += equipment.power_draw
		battery.cell.use(min(battery.cell.charge, load * seconds_per_tick))
	if(electrical_live != has_electrical_power())
		update_electrical()

/datum/ms13_ground_vehicle/proc/update_electrical()
	electrical_live = has_electrical_power()
	for(var/obj/structure/ms13_vehicle_part/part as anything in parts)
		if(istype(part, /obj/structure/ms13_vehicle_part/exterior_equipment) || istype(part, /obj/structure/ms13_vehicle_part/interior_light))
			part.update_appearance()
	update_interior_masks()

/// The driver alone can see through a powered camera's hull edge. This is not an opening for NPCs.
/datum/ms13_ground_vehicle/proc/camera_covers_edge(obj/structure/ms13_vehicle_frame/frame, exit_dir)
	if(!cameras_on || !has_electrical_power())
		return FALSE
	for(var/obj/structure/ms13_vehicle_part/exterior_equipment/camera/camera in parts)
		if(camera.forward_offset == frame.forward_offset && camera.right_offset == frame.right_offset && camera.dir == exit_dir && camera.is_operational())
			return TRUE
	return FALSE

/obj/structure/ms13_vehicle_part/battery
	name = "vehicle battery"
	desc = "A low, bolted-down starter battery. A screwdriver releases its cell; insert a charged cell to replace it."
	icon = 'icons/obj/power.dmi'
	icon_state = "cell"
	layer = OBJ_LAYER
	max_integrity = 100
	var/obj/item/stock_parts/cell/cell

/obj/structure/ms13_vehicle_part/battery/Initialize(mapload)
	. = ..()
	cell = new /obj/item/stock_parts/cell/high(src)

/obj/structure/ms13_vehicle_part/battery/configure_from_vehicle()
	vehicle.battery = src
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_vehicle_part/battery/process(seconds_per_tick)
	vehicle?.process_power(seconds_per_tick)

/obj/structure/ms13_vehicle_part/battery/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(vehicle?.battery == src)
		vehicle.battery = null
		vehicle.stop_engine()
		vehicle.update_electrical()
	QDEL_NULL(cell)
	return ..()

/obj/structure/ms13_vehicle_part/battery/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	vehicle?.stop_engine()
	vehicle?.update_electrical()

/obj/structure/ms13_vehicle_part/battery/atom_fix()
	. = ..()
	broken = FALSE
	vehicle?.update_electrical()

/obj/structure/ms13_vehicle_part/battery/examine(mob/user)
	. = ..()
	. += span_notice(cell ? "Charge: [round(cell.percent())]%." : "No cell installed.")

/obj/structure/ms13_vehicle_part/battery/screwdriver_act(mob/living/user, obj/item/tool)
	if(!cell)
		return TRUE
	if(!tool.use_tool(src, user, 0, volume = 30))
		return TRUE
	cell.forceMove(drop_location())
	cell = null
	vehicle?.stop_engine()
	vehicle?.update_electrical()
	return TRUE

/obj/structure/ms13_vehicle_part/battery/attackby(obj/item/item, mob/user, params)
	if(!istype(item, /obj/item/stock_parts/cell) || cell)
		return ..()
	if(user.transferItemToLoc(item, src))
		cell = item
		vehicle?.update_electrical()

/// Non-dense exterior accessories use the same per-client exterior images as wheels and turrets.
/obj/structure/ms13_vehicle_part/exterior_equipment
	icon_state = "none"
	max_integrity = 40
	var/equipment_icon
	var/on_state
	var/off_state
	var/power_draw = 1

/obj/structure/ms13_vehicle_part/exterior_equipment/Initialize(mapload)
	. = ..()
	exterior_image = image(equipment_icon, src, off_state, ABOVE_ALL_MOB_LAYER + 0.04, dir)
	exterior_image.mouse_opacity = MOUSE_OPACITY_ICON
	GLOB.ms13_vehicle_exterior_part_images |= exterior_image
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images |= exterior_image

/obj/structure/ms13_vehicle_part/exterior_equipment/configure_from_vehicle()
	update_appearance()

/obj/structure/ms13_vehicle_part/exterior_equipment/setDir(new_dir)
	. = ..()
	if(exterior_image)
		exterior_image.pixel_x = dir == EAST ? 16 : dir == WEST ? -16 : 0
		exterior_image.pixel_y = dir == NORTH ? 16 : dir == SOUTH ? -16 : 0

/obj/structure/ms13_vehicle_part/exterior_equipment/proc/is_enabled()
	return is_operational() && vehicle?.has_electrical_power()

/obj/structure/ms13_vehicle_part/exterior_equipment/update_icon_state()
	. = ..()
	if(exterior_image)
		exterior_image.icon_state = is_enabled() ? on_state : off_state
		exterior_image.color = broken ? "#706060" : null

/obj/structure/ms13_vehicle_part/exterior_equipment/atom_break(damage_flag)
	. = ..()
	broken = TRUE
	vehicle?.update_electrical()

/obj/structure/ms13_vehicle_part/exterior_equipment/atom_fix()
	. = ..()
	broken = FALSE
	vehicle?.update_electrical()

/obj/structure/ms13_vehicle_part/exterior_equipment/Destroy()
	var/datum/ms13_ground_vehicle/old_vehicle = vehicle
	. = ..()
	old_vehicle?.update_electrical()

/obj/structure/ms13_vehicle_part/exterior_equipment/camera
	name = "vehicle exterior camera"
	desc = "An armored hull camera wired to the driver's display."
	equipment_icon = 'icons/obj/machines/camera.dmi'
	on_state = "camera"
	off_state = "camera_off"

/obj/structure/ms13_vehicle_part/exterior_equipment/camera/is_enabled()
	return ..() && vehicle.cameras_on

/obj/structure/ms13_vehicle_part/exterior_equipment/light
	name = "vehicle exterior light"
	desc = "An exterior lamp. Its switch is at the driver's controls."
	equipment_icon = 'icons/obj/lighting.dmi'
	on_state = "floor"
	off_state = "floor-burned"
	power_draw = 2

/obj/structure/ms13_vehicle_part/exterior_equipment/light/is_enabled()
	return ..() && vehicle.exterior_lights_on

/obj/structure/ms13_vehicle_part/exterior_equipment/light/update_icon_state()
	. = ..()
	set_light(l_outer_range = is_enabled() ? 5 : 0, l_inner_range = 1, l_power = 1, l_color = "#ffe8c0")
