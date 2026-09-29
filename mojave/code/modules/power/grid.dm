/**
 * The regional grid, mapped by hand with ordinary cables.
 *
 * Power plant generators (/obj/machinery/ms13/fusion_generator/power_plant) put transmission voltage on the cable
 * under them. A substation takes that from the cable knotted under it and feeds house voltage into the cable knotted
 * on the tile it faces; utility boxes wired to that side run as normal. A box wired straight to plant voltage blows
 * its lights and burns out. A worn substation arcs and lets plant voltage through now and then, and a dead one passes
 * nothing.
 *
 * Plant output ripples, more as its generators wear. Capacitor units facing a substation's output tile join that
 * network, soaking up the ripple and covering dips. Without them the houses' lights flicker, and a bad enough ripple
 * pops bulbs.
 *
 * Cost: cables never process. Voltage, ripple and last tick's load are a few numbers on each powernet, rolled over in
 * its own reset(); only generators, substations, capacitors and utility boxes do anything each tick.
 */
/datum/powernet
	/// Whether it had power last cycle.
	var/ms13_was_live = FALSE
	/// Highest voltage fed in: what machines see this tick, and what is being fed for the next, like avail and newavail.
	var/ms13_voltage = MS13_VOLTAGE_NONE
	var/ms13_new_voltage = MS13_VOLTAGE_NONE
	/// How far the supply swings about its mean, 0-1, likewise.
	var/ms13_ripple = 0
	var/ms13_new_ripple = 0
	/// Load drawn over the whole of last tick: how much a substation's houses want.
	var/ms13_last_load = 0
	/// Capacitor units buffering this network.
	var/list/ms13_capacitors

/datum/powernet/reset()
	ms13_last_load = load
	ms13_voltage = ms13_new_voltage
	ms13_new_voltage = MS13_VOLTAGE_NONE
	ms13_ripple = ms13_new_ripple
	ms13_new_ripple = 0
	. = ..()
	// Rail feeders hear when their line goes live or dead, and only then, so a steady line costs nothing.
	var/live = avail > 0
	if(live != ms13_was_live)
		ms13_was_live = live
		ms13_rewire()
		for(var/obj/machinery/power/ms13_rail_feeder/feeder in nodes)
			SEND_SIGNAL(feeder, COMSIG_MS13_LINE_POWER_CHANGED, live)

/// The powernet of the cable knotted on target, if any.
/proc/ms13_cable_net_at(turf/target)
	var/obj/structure/cable/node = target?.get_cable_node()
	return node?.powernet

/*
 * Machines in the wasteland run off wiring, not their area: a live cable knotted on their tile, or a live wall they
 * touch. Walls carry the house wiring. A cable laid into a wall joins every other cable laid into the same stretch of
 * joined-up wall, so a run can go wall to wall; a utility box with its breaker closed does the same for the cable at its
 * terminal, which makes it the house's main switch. Door and window frames carry it across between the walls either
 * side, though nothing plugs into them. Rock carries nothing.
 */
/area
	/// Machines here run off wiring rather than area power.
	var/ms13_wired = FALSE

/area/ms13
	ms13_wired = TRUE

GLOBAL_LIST_INIT(ms13_conductors, typecacheof(list(/turf/closed/wall, /turf/closed/indestructible/ms13)))
GLOBAL_LIST_INIT(ms13_wall_frames, typecacheof(list(/obj/structure/window, /obj/structure/ms13/frame, /obj/structure/low_wall, /obj/machinery/door, /obj/structure/mineral_door, /obj/structure/ms13/celldoor)))
/// Machines that use power, to check when the wiring changes: machine -> TRUE.
GLOBAL_LIST_EMPTY(ms13_wired_machines)
/// Cables whose networks ran through walls that changed, rebuilt next tick.
GLOBAL_LIST_EMPTY(ms13_rewalled_cables)

/turf
	/// The stretch of joined-up wall this is part of, found when first needed.
	var/tmp/datum/ms13_wall_circuit/ms13_circuit

/datum/ms13_wall_circuit
	var/list/walls = list()
	/// Cables laid into it.
	var/list/plugs = list()

/proc/ms13_is_frame(turf/target)
	for(var/obj/thing in target)
		if(GLOB.ms13_wall_frames[thing.type])
			return TRUE
	return FALSE

/// target's stretch of wall, if it carries wiring.
/proc/ms13_wall_circuit(turf/target)
	if(target?.ms13_circuit)
		return target.ms13_circuit
	if(!target || (!GLOB.ms13_conductors[target.type] && !ms13_is_frame(target)))
		return null
	var/datum/ms13_wall_circuit/circuit = new
	var/list/walls = circuit.walls
	walls += target
	target.ms13_circuit = circuit
	var/index = 1
	while(index <= length(walls))
		var/turf/wall = walls[index++]
		var/solid = GLOB.ms13_conductors[wall.type]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(wall, direction)
			if(!next || next.ms13_circuit == circuit)
				continue
			if(GLOB.ms13_conductors[next.type] || ms13_is_frame(next))
				next.ms13_circuit = circuit
				walls += next
				continue
			if(!solid)
				continue
			for(var/obj/structure/cable/cable in next)
				if(cable.ms13_plugs_into(wall))
					circuit.plugs |= cable
	return circuit

/// Whether this cable runs into wall: laid into it, or knotted under a utility box on it with its breaker closed.
/obj/structure/cable/proc/ms13_plugs_into(turf/wall)
	var/direction = get_dir(loc, wall)
	if(linked_dirs & GLOB.real_dirs_to_cable_dirs["[direction]"])
		return TRUE
	if(!is_knotted() && !ms13_node)
		return FALSE
	for(var/obj/machinery/power/apc/ms13/box in loc)
		if(box.dir == direction && box.ms13_feeding)
			return TRUE
	return FALSE

/// Cables laid into the same stretch of wall are joined through it, and a node piece joins the knots on its tile.
/// Conduits (terminal_controls.dm) still cut them.
/obj/structure/cable/get_cable_connections(powernetless_only = FALSE)
	. = ..()
	if(ms13_node || is_knotted())
		for(var/obj/structure/cable/other in loc)
			if(other != src && (other.ms13_node || other.is_knotted()) && (!powernetless_only || !other.powernet))
				. |= other
	for(var/direction in GLOB.cardinals)
		var/turf/wall = get_step(src, direction)
		if(!wall || !GLOB.ms13_conductors[wall.type] || !ms13_plugs_into(wall))
			continue
		var/datum/ms13_wall_circuit/circuit = ms13_wall_circuit(wall)
		if(!(src in circuit.plugs))
			continue
		for(var/obj/structure/cable/other as anything in circuit.plugs)
			if(other != src && isturf(other.loc) && (!powernetless_only || !other.powernet))
				. |= other

/// Forgets the stretches of wall at and beside site, to be found again when needed. Returns the cables laid into them.
/proc/ms13_forget_walls(turf/site)
	. = list()
	if(!site)
		return
	var/list/near = list(site)
	for(var/direction in GLOB.cardinals)
		near += get_step(site, direction)
	for(var/turf/tile in near)
		var/datum/ms13_wall_circuit/circuit = tile.ms13_circuit
		if(!circuit)
			continue
		. |= circuit.plugs
		for(var/turf/wall as anything in circuit.walls)
			if(wall.ms13_circuit == circuit)
				wall.ms13_circuit = null

/// Walls changed at site: forget them, and next tick rebuild the networks that ran through them, or might now.
/proc/ms13_rewall(turf/site)
	var/list/cables = ms13_forget_walls(site)
	if(!site || !SSmachines.initialized)
		return
	for(var/obj/structure/cable/cable in range(1, site))
		cables |= cable
	GLOB.ms13_rewalled_cables |= cables
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(ms13_rebuild_rewalled)), 1, TIMER_UNIQUE)

/proc/ms13_rebuild_rewalled()
	var/list/cables = GLOB.ms13_rewalled_cables
	GLOB.ms13_rewalled_cables = list()
	var/list/rebuilt = list()
	for(var/obj/structure/cable/cable as anything in cables)
		if(QDELETED(cable) || !isturf(cable.loc) || (cable.powernet && rebuilt[cable.powernet]))
			continue
		var/datum/powernet/line = new
		propagate_network(cable, line)
		rebuilt[line] = TRUE

/// A wall going up or coming down joins or splits the wiring through it.
/turf/ChangeTurf(path, list/new_baseturfs, flags)
	if(!GLOB.ms13_conductors[type] && !(path && GLOB.ms13_conductors[path]))
		return ..()
	. = ..()
	ms13_rewall(.)

/obj/Initialize(mapload)
	. = ..()
	if(GLOB.ms13_wall_frames[type])
		ms13_rewall(loc)

/obj/Destroy(force)
	if(!GLOB.ms13_wall_frames[type])
		return ..()
	var/turf/site = get_turf(src)
	. = ..()
	ms13_rewall(site)

/obj/machinery/power/apc/ms13
	/// Breaker closed and in one piece: the cable at its terminal feeds the wall it's on.
	var/tmp/ms13_feeding = FALSE

/obj/machinery/power/apc/ms13/update()
	. = ..()
	var/feeding = ms13_wired() && operating && !shorted && !failure_timer && !(machine_stat & (BROKEN|MAINT))
	if(feeding != ms13_feeding)
		ms13_feeding = feeding
		ms13_rewall(loc)

/// The live network feeding spot: a cable knotted on it, or wiring in a wall on or beside it.
/proc/ms13_supply_at(turf/spot)
	var/datum/powernet/net = ms13_cable_net_at(spot)
	if(net?.avail > 0)
		return net
	var/list/sides = list(spot)
	for(var/direction in GLOB.cardinals)
		sides += get_step(spot, direction)
	for(var/turf/side in sides)
		var/datum/ms13_wall_circuit/circuit = ms13_wall_circuit(side)
		for(var/obj/structure/cable/plug as anything in circuit?.plugs)
			if(plug.powernet?.avail > 0 && isturf(plug.loc) && !ms13_conduit_blocks(plug.loc))
				return plug.powernet
	return null

/obj/machinery
	/// Whether it had power at the last wiring check, and the network it was drawing from.
	var/tmp/ms13_live = FALSE
	var/tmp/datum/powernet/ms13_net

/obj/machinery/proc/ms13_wired()
	var/area/place = get_area(src)
	return place?.ms13_wired

/obj/machinery/powered(chan = power_channel, ignore_use_power = FALSE)
	if(!ms13_wired())
		return ..()
	if(!use_power && !ignore_use_power)
		return TRUE
	return isturf(loc) && !!ms13_supply_at(loc)

/obj/machinery/use_power(amount, chan = power_channel)
	if(!ms13_wired())
		return ..()
	if(ms13_live && ms13_net)
		ms13_net.load += amount

/// Standing draw goes on the network each cycle (see SSmachines below), not on the area.
/obj/machinery/addStaticPower(value, powerchannel)
	if(!ms13_wired())
		return ..()

/obj/machinery/use_power_from_net(amount, take_any = FALSE)
	if(!ms13_wired())
		return ..()
	var/datum/powernet/net = isturf(loc) && ms13_supply_at(loc)
	if(!net || amount <= 0)
		return FALSE
	var/surplus = max(net.avail - net.load, 0)
	if(surplus < amount)
		if(!take_any || !surplus)
			return FALSE
		amount = surplus
	net.load += amount
	return amount

/obj/machinery/setup_area_power_relationship()
	. = ..()
	GLOB.ms13_wired_machines[src] = TRUE
	check_wiring()

/obj/machinery/remove_area_power_relationship()
	. = ..()
	GLOB.ms13_wired_machines -= src

/obj/machinery/Destroy()
	GLOB.ms13_wired_machines -= src
	ms13_net = null
	return ..()

/// Powers a machine up or down if its wiring changed.
/obj/machinery/proc/check_wiring()
	ms13_net = isturf(loc) && ms13_wired() ? ms13_supply_at(loc) : null
	var/live = !!powered(power_channel)
	if(live != ms13_live)
		ms13_live = live
		power_change()

/// A cable laid, cut, or gone live or dead: every machine checks its wiring next tick, all at once.
/// ponytail: sweeps every powered machine for any change anywhere; keep a list per powernet if that ever shows in profiles.
/proc/ms13_rewire()
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(ms13_check_wiring)), 1, TIMER_UNIQUE)

/proc/ms13_check_wiring()
	for(var/obj/machinery/machine as anything in GLOB.ms13_wired_machines)
		if(!QDELETED(machine))
			machine.check_wiring()
		CHECK_TICK
	for(var/obj/item/radio/intercom/intercom as anything in INSTANCES_OF(/obj/item/radio/intercom))
		intercom.AreaPowerCheck()
		CHECK_TICK

/// ponytail: machines draw whatever they like off a live network; nothing browns out an overloaded one yet.
/datum/controller/subsystem/machines/fire(resumed = FALSE)
	if(!resumed)
		for(var/obj/machinery/machine as anything in GLOB.ms13_wired_machines)
			if(machine.ms13_live && machine.ms13_net)
				machine.ms13_net.delayedload += machine.static_power_usage
	return ..()

/datum/powernet/New()
	. = ..()
	ms13_rewire()

/obj/structure/cable/Initialize(mapload)
	ms13_forget_walls(loc)
	. = ..()
	ms13_rewire()

/obj/structure/cable/set_directions(new_directions, merge_connections = TRUE)
	ms13_forget_walls(loc)
	. = ..()
	ms13_rewire()

/obj/structure/cable/Destroy()
	var/turf/site = loc
	ms13_forget_walls(site)
	ms13_rewire()
	. = ..()
	ms13_forget_walls(site)

/// The cable directions a cable drawn into a sprite runs, by its shape and dir, as cables.dmi and floors.dmi draw them.
/proc/ms13_drawn_cable_dirs(shape, dir)
	var/real_dirs
	switch(shape)
		if("curve")
			real_dirs = (dir & (NORTH|SOUTH) ? SOUTH : NORTH) | (dir & (SOUTH|EAST) ? EAST : WEST)
		if("tee")
			real_dirs = dir | turn(dir, 90) | turn(dir, -90)
		if("cross")
			real_dirs = NORTH|SOUTH|EAST|WEST
		if("junction")
			real_dirs = dir == SOUTH ? NORTH|SOUTH|EAST|WEST : dir | turn(dir, 90) | turn(dir, -90)
		if("end")
			real_dirs = dir
		if("tail")
			real_dirs = turn(dir, 180)
		else
			real_dirs = dir & (SOUTH|WEST) ? EAST|WEST : NORTH|SOUTH
	. = NONE
	for(var/direction in GLOB.cardinals)
		if(real_dirs & direction)
			. |= GLOB.real_dirs_to_cable_dirs["[direction]"]

/obj/structure/cable
	/// A drawn connector, splice, junction box or node: takes machines and joins knots on its tile like a knot, though a
	/// coil can't bend it.
	var/ms13_node = FALSE

/// Runs this cable the way shape and dir draw it.
/obj/structure/cable/proc/ms13_lay_drawn(shape, dir)
	var/static/list/node_shapes = list("connector", "tail", "box", "end")
	ms13_node = (shape in node_shapes)
	linked_dirs = ms13_drawn_cable_dirs(shape, dir)
	if(SSmachines.initialized)
		merge_new_connections()

/obj/structure/cable/get_machine_connections(powernetless_only = FALSE)
	. = ..()
	if(!ms13_node || is_knotted())
		return
	for(var/obj/machinery/power/machine in loc)
		if(machine.anchored && (!powernetless_only || !machine.powernet))
			. += machine

/turf/get_cable_node()
	. = ..()
	if(.)
		return
	for(var/obj/structure/cable/wire in src)
		if(wire.ms13_node)
			return wire

/// Heavy ground cable (structures/decorative.dm) lies on top of the ground, never under it, and keeps its own sprite.
/obj/structure/ms13/cable/Initialize(mapload)
	. = ..()
	RemoveElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)

/obj/structure/ms13/cable/mapping_init()
	if(ms13_smart)
		ms13_take_shape()
	ms13_lay_drawn(ms13_shape, dir)

/// Ground cable only joins ground cable of its own colour, so different colours can be piled and crossed freely.
/obj/structure/ms13/cable/get_cable_connections(powernetless_only = FALSE, ignore_conduits = FALSE)
	. = ..()
	var/list/joined = .
	for(var/obj/structure/ms13/cable/other in joined.Copy())
		if(other.ms13_colour != ms13_colour)
			joined -= other

/**
 * Smart ground cable takes the sprite that joins it to what's around it: the same smart cable, or any other cable of
 * its colour, or not ground cable at all, run into its tile. A lone end frays, unless it butts a wall, when it runs on into it; a straight run under a machine is a
 * connector, taking it like a knot. Tees the sprites don't draw become a full crossing.
 */
/obj/structure/ms13/cable/proc/ms13_take_shape()
	var/joins = NONE
	var/count = 0
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(src, direction)
		var/joined = ms13_cable_dirs_on(next, ms13_colour) & GLOB.real_dirs_to_cable_dirs["[turn(direction, 180)]"]
		for(var/obj/structure/ms13/cable/other in next)
			joined ||= other.type == type
		if(joined)
			joins |= direction
			count++
	var/sprite = "straight"
	ms13_shape = "straight"
	switch(count)
		if(0)
			dir = SOUTH
		if(1)
			var/turf/beyond = get_step(src, turn(joins, 180))
			if(beyond && GLOB.ms13_conductors[beyond.type])
				dir = joins & (NORTH|SOUTH) ? NORTH : SOUTH
			else
				sprite = "spliced"
				ms13_shape = "tail"
				dir = turn(joins, 180)
		if(2)
			if(joins == (NORTH|SOUTH) || joins == (EAST|WEST))
				dir = joins == (NORTH|SOUTH) ? NORTH : SOUTH
			else
				sprite = "curved"
				ms13_shape = "curve"
				dir = joins == (SOUTH|EAST) ? SOUTH : joins == (SOUTH|WEST) ? NORTH : joins == (NORTH|EAST) ? EAST : WEST
		else
			sprite = "intersect"
			ms13_shape = "junction"
			var/open = (NORTH|SOUTH|EAST|WEST) & ~joins
			dir = open == WEST ? EAST : open == EAST ? WEST : SOUTH
	if(ms13_shape == "straight" && (locate(/obj/machinery) in loc))
		sprite = "connector"
		ms13_shape = "connector"
	icon_state = "[ms13_smart]_[sprite]"

/// The cable directions the cabling on target runs, drawn or laid, whether or not it's set up yet. Smart ground cable
/// is left out, not having picked its shape, and so is ground cable of any colour but colour.
/proc/ms13_cable_dirs_on(turf/target, colour)
	. = NONE
	var/turf/open/floor/ms13/concrete/cable/floor = target
	if(istype(floor))
		. |= ms13_drawn_cable_dirs(floor.ms13_shape, floor.dir)
	for(var/obj/structure/cable/wire in target)
		var/obj/structure/ms13/cable/ground = wire
		if(istype(ground))
			if(!ground.ms13_smart && ground.ms13_colour == colour)
				. |= ms13_drawn_cable_dirs(ground.ms13_shape, ground.dir)
		else if(!istype(wire, /obj/structure/cable/ms13_cast))
			. |= wire.linked_dirs || text2num(wire.icon_state)

/obj/structure/ms13/cable/update_icon_state()
	var/drawn = icon_state
	. = ..()
	icon_state = drawn

/// The cabling cast into a concrete cable floor: unseen, and only ever goes with the floor.
/obj/structure/cable/ms13_cast
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/structure/cable/ms13_cast/Initialize(mapload)
	. = ..()
	RemoveElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)
	invisibility = INVISIBILITY_ABSTRACT

/obj/structure/cable/ms13_cast/mapping_init()
	var/turf/open/floor/ms13/concrete/cable/floor = loc
	if(istype(floor))
		ms13_lay_drawn(floor.ms13_shape, floor.dir)

/turf/open/floor/ms13/concrete/cable/Initialize(mapload)
	. = ..()
	new /obj/structure/cable/ms13_cast(src)

/turf/open/floor/ms13/concrete/cable/Destroy(force)
	for(var/obj/structure/cable/ms13_cast/wire in src)
		qdel(wire)
	return ..()

/// Doors that never needed power still don't; a door motor (structures/doors.dm) finds its own.
/obj/machinery/door/unpowered
	use_power = NO_POWER_USE

/obj/machinery/light/has_power()
	if(!ms13_wired())
		return ..()
	var/area/place = get_area(src)
	return place.lightswitch && powered()

/obj/machinery/light/turned_off()
	if(!ms13_wired())
		return ..()
	var/area/place = get_area(src)
	return !place.lightswitch && powered() || flickering || constant_flickering

/obj/machinery/light/power_change()
	if(!ms13_wired())
		return ..()
	set_on(has_power())

/obj/item/radio/intercom/AreaPowerCheck(datum/source)
	var/area/place = get_area(src)
	if(!place?.ms13_wired)
		return ..()
	set_on(isturf(loc) && !!ms13_supply_at(loc))
	update_appearance()

/// A stair cable joins its upper opening and landing, using the same offset as stair_ascend().
/// There is no implicit connection through ordinary floors or between unrelated region levels.
/proc/ms13_stair_cable_turfs(turf/site)
	. = list()
	if(!site)
		return
	var/list/candidates = list(site)
	var/turf/below = GetBelow(site)
	if(below)
		candidates += below
		for(var/direction in GLOB.cardinals)
			candidates += get_step(below, direction)
	for(var/turf/candidate as anything in candidates)
		for(var/obj/structure/stairs/stairs in candidate)
			if(QDELETED(stairs) || !stairs.isTerminator())
				continue
			var/turf/above = GetAbove(candidate)
			var/turf/landing = get_step(above, stairs.dir)
			if(!above || !landing)
				continue
			if(candidate == site)
				. |= above
				. |= landing
			else if(site == above || site == landing)
				. |= candidate

/// A changed stair can also change which adjacent stair is the end of its flight.
/proc/ms13_rebuild_stair_cables(turf/site)
	if(!site || !SSmachines.initialized)
		return
	ms13_rebuild_cables_at(site)
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(site, direction)
		if(locate(/obj/structure/stairs) in neighbor)
			ms13_rebuild_cables_at(neighbor)

/obj/structure/stairs/Initialize(mapload)
	. = ..()
	ms13_rebuild_stair_cables(get_turf(src))

/obj/structure/stairs/Destroy()
	var/turf/site = get_turf(src)
	. = ..()
	ms13_rebuild_stair_cables(site)

/obj/structure/stairs/Moved(atom/old_loc, movement_dir, forced, list/old_locs)
	. = ..()
	if(initialized && !QDELETED(src) && old_loc != loc)
		ms13_rebuild_stair_cables(get_turf(old_loc))
		ms13_rebuild_stair_cables(get_turf(src))

/obj/structure/stairs/setDir(newdir)
	var/old_dir = dir
	. = ..()
	if(initialized && dir != old_dir)
		ms13_rebuild_stair_cables(get_turf(src))

/// Smart cables (the mapping helper) leave a knot mid-line wherever a grid machine takes power: under any power machine,
/// generator or substation, and on the tile a substation or capacitor faces.
/obj/structure/cable/smart_cable/knot_desirable()
	if(..())
		return TRUE
	var/turf/my_turf = loc
	if((locate(/obj/machinery/power) in my_turf) || (locate(/obj/machinery/ms13/fusion_generator) in my_turf) || (locate(/obj/machinery/ms13/substation) in my_turf))
		return TRUE
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(my_turf, direction)
		// A rail feeder takes power from a knot beside it, too.
		if(locate(/obj/machinery/power/ms13_rail_feeder) in beside)
			return TRUE
		for(var/obj/machinery/ms13/substation/facing in beside)
			if(facing.dir == turn(direction, 180))
				return TRUE
	return FALSE

/// Whether a smart cable on here must stop short of the next tile along direction: that would join the plant side
/// under a substation to the house side it faces, making them one network.
/proc/ms13_grid_divides(turf/here, direction)
	for(var/obj/machinery/ms13/substation/substation in here)
		if(substation.dir == direction && !istype(substation, /obj/machinery/ms13/substation/discharge))
			return TRUE
	for(var/obj/machinery/ms13/substation/substation in get_step(here, direction))
		if(substation.dir == turn(direction, 180) && !istype(substation, /obj/machinery/ms13/substation/discharge))
			return TRUE
	return FALSE

/// Round start builds every powernet once, after all atoms exist (SSmachines.makepowernets()). Merging each mapped cable
/// into its neighbours' networks first is thrown away, and costs more the bigger the grid, so it waits for that.
/obj/structure/cable/mapping_init()
	if(SSmachines.initialized)
		return ..()
	linked_dirs = text2num(icon_state)

/// Mojave has no station blueprints to show the original wiring on, so mapped cables don't each keep a blueprint image.
/turf/add_blueprints_preround(atom/movable/AM)
	if(istype(AM, /obj/structure/cable))
		return
	return ..()

/// Welds a machine back into shape, using that many scrap parts from the other hand. TRUE if it did.
/obj/machinery/ms13/proc/weld_repair(mob/living/user, obj/item/tool, parts = 1, time = 5 SECONDS)
	var/obj/item/stack/sheet/ms13/scrap_parts/repair_parts = user.is_holding_item_of_type(/obj/item/stack/sheet/ms13/scrap_parts)
	if(repair_parts?.amount < parts)
		to_chat(user, span_warning("You need [parts] scrap part\s in your other hand to repair [src]."))
		return FALSE
	if(!tool.use_tool(src, user, time, volume = 50) || !repair_parts.use(parts))
		return FALSE
	user.visible_message(span_notice("[user] patches up [src]."), span_notice("You patch up [src]."))
	return TRUE

/obj/machinery/ms13/substation
	use_power = NO_POWER_USE
	/// Watts it can step down.
	var/rating = 60000
	/// 0-100. A worn transformer arcs, letting plant voltage through; at 0 it passes nothing.
	var/condition = 100
	/// Condition lost per second at full rated load. Running overloaded wears it four times as fast.
	var/wear_rate = 0.003
	var/repair_amount = 25
	var/breaker = TRUE
	/// The plant side (cable knotted under it) and house side (cable knotted on the tile it faces).
	var/datum/powernet/input
	var/datum/powernet/output
	/// Watts sent to the house side last tick, and how much of what it wanted it couldn't send.
	var/last_delivered = 0
	var/last_shortfall = 0

/obj/machinery/ms13/substation/rusty
	condition = 25

/// Live enough to bite whatever touches it.
/obj/machinery/ms13/substation/proc/is_live()
	return breaker && input?.avail > 0

/// Wrecked, it goes dead and can't be damaged further: it waits, a hulk, for someone with the parts to rebuild it.
/obj/machinery/ms13/substation/atom_break(damage_flag)
	. = ..()
	if(!.)
		return
	resistance_flags |= INDESTRUCTIBLE
	visible_message(span_warning("[src] shorts out in a shower of sparks and goes dead!"))
	do_sparks(5, TRUE, src)

/// Rebuilt from a wreck: whole again, and breakable again.
/obj/machinery/ms13/substation/proc/mend()
	resistance_flags &= ~INDESTRUCTIBLE
	repair_damage(max_integrity)
	set_machine_stat(machine_stat & ~BROKEN)
	update_appearance()

/obj/machinery/ms13/substation/process(seconds_per_tick)
	input = ms13_cable_net_at(loc)
	output = ms13_cable_net_at(get_step(src, dir))
	last_delivered = 0
	last_shortfall = 0
	if((machine_stat & BROKEN) || !breaker || !condition || !input || !output || input == output)
		return
	// What its houses drew last tick, with room for more to switch on.
	var/demand = min(output.ms13_last_load + rating / 4, rating)
	var/available = max(input.avail - input.load, 0)
	var/from_plant = min(available, demand)
	var/delivered = from_plant
	var/smoothed = FALSE
	for(var/obj/machinery/ms13/substation/discharge/capacitor as anything in output.ms13_capacitors)
		if(!capacitor.can_buffer())
			continue
		smoothed = TRUE
		if(delivered < demand)
			delivered += capacitor.release((demand - delivered) * seconds_per_tick, seconds_per_tick) / seconds_per_tick
		else if(available > from_plant)
			var/charged = capacitor.store((available - from_plant) * seconds_per_tick, seconds_per_tick) / seconds_per_tick
			from_plant += charged
			available -= charged
	input.load += from_plant
	output.newavail += delivered
	last_delivered = delivered
	last_shortfall = demand - delivered
	// A worn transformer arcs over, putting plant voltage straight onto the house side.
	var/arcing = condition < 50 && prob(((50 - condition) / 50) ** 2 * 100)
	output.ms13_new_voltage = max(output.ms13_new_voltage, arcing ? input.ms13_voltage : MS13_VOLTAGE_LOW)
	output.ms13_new_ripple = max(output.ms13_new_ripple, input.ms13_ripple * (smoothed ? 0.1 : 1))
	if(arcing)
		do_sparks(2, FALSE, src)
	var/strain = delivered / rating * (output.ms13_last_load >= rating ? 4 : 1)
	condition = max(condition - wear_rate * strain * seconds_per_tick, 0)
	if(!condition)
		visible_message(span_warning("[src] bangs and goes dead as its windings burn out!"))
		do_sparks(5, TRUE, src)

/obj/machinery/ms13/substation/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	breaker = !breaker
	playsound(src, 'sound/machines/lightswitch.ogg', 50, TRUE)
	to_chat(user, span_notice("You throw [src]'s breaker [breaker ? "on" : "off"]."))
	return TRUE

/obj/machinery/ms13/substation/welder_act(mob/living/user, obj/item/tool)
	if(machine_stat & BROKEN)
		if(weld_repair(user, tool, 5, 15 SECONDS))
			mend()
		return TRUE
	if(condition >= 100)
		to_chat(user, span_notice("[src] doesn't need repairs."))
		return TRUE
	if(weld_repair(user, tool))
		condition = min(condition + repair_amount, 100)
	return TRUE

/obj/machinery/ms13/substation/examine(mob/user)
	. = ..()
	if(machine_stat & BROKEN)
		. += span_warning("It's wrecked. A welder and five scrap parts could rebuild it.")
		return
	. += span_notice("Its breaker is [breaker ? "on" : "off"].")
	. += condition_text()
	if(breaker && condition)
		. += wiring_text()

/obj/machinery/ms13/substation/proc/wiring_text()
	. = list()
	if(!input || !output || input == output)
		. += span_warning("It isn't wired: plant cable knotted under it, house cable knotted on the tile it faces.")
		return
	. += span_notice("It's sending [display_power(last_delivered)] of its [display_power(rating)] rating to the houses.")
	if(last_shortfall > 1)
		. += span_warning("The plant side can't meet its load: [display_power(last_shortfall)] short.")

/obj/machinery/ms13/substation/proc/condition_text()
	switch(condition)
		if(75 to INFINITY)
			return span_notice("It hums steadily.")
		if(40 to 75)
			return span_notice("It buzzes unevenly.")
		if(1 to 40)
			return span_warning("It crackles and smells of burnt insulation. It needs repairs.")
	return span_warning("Its windings are burnt out. It needs repairs.")

/obj/machinery/ms13/substation/discharge
	/// Joules it holds, and at most when in perfect condition. A worn unit holds less before it discharges.
	var/charge = 0
	var/capacity = 2000000
	/// Watts it can take in or give out.
	var/rate = 30000
	/// The network knotted on the tile it faces, normally a substation's house side.
	var/datum/powernet/bus

/obj/machinery/ms13/substation/discharge/rusty
	condition = 25

/obj/machinery/ms13/substation/discharge/Destroy()
	LAZYREMOVE(bus?.ms13_capacitors, src)
	bus = null
	return ..()

/obj/machinery/ms13/substation/discharge/is_live()
	return charge > 0

/obj/machinery/ms13/substation/discharge/process(seconds_per_tick)
	var/datum/powernet/wanted = ms13_cable_net_at(get_step(src, dir))
	if(bus != wanted)
		LAZYREMOVE(bus?.ms13_capacitors, src)
		bus = wanted
	if(bus)
		LAZYOR(bus.ms13_capacitors, src)
	// Overcharged beyond what it can still hold, it lets go all at once.
	if(charge > held_charge())
		visible_message(span_danger("[src] discharges with a deafening crack!"))
		tesla_zap(src, 4, 300, zap_flags)
		charge = 0

/obj/machinery/ms13/substation/discharge/proc/held_charge()
	return capacity * condition / 100

/obj/machinery/ms13/substation/discharge/proc/can_buffer()
	return breaker && condition && !(machine_stat & BROKEN) && !QDELETED(src)

/// A wrecked capacitor dumps whatever it held.
/obj/machinery/ms13/substation/discharge/atom_break(damage_flag)
	. = ..()
	if(. && charge)
		tesla_zap(src, 4, 300, zap_flags)
		charge = 0

/// Takes in up to joules over seconds, as its charge rate allows. The substation charging it can't tell how much a worn
/// unit really holds, so a worn one gets overcharged and discharges. Returns joules taken.
/obj/machinery/ms13/substation/discharge/proc/store(joules, seconds)
	. = min(joules, rate * seconds, max(capacity - charge, 0))
	charge += .

/// Gives out up to joules over seconds. Returns joules given.
/obj/machinery/ms13/substation/discharge/proc/release(joules, seconds)
	. = min(joules, rate * seconds, charge)
	charge -= .

/obj/machinery/ms13/substation/discharge/wiring_text()
	. = list(span_notice("Its charge meter reads [round(100 * charge / capacity)]%."))
	if(!bus)
		. += span_warning("It isn't wired: cable knotted on the tile it faces, where a substation feeds its houses.")

/// A power plant's generator: far bigger than a house set, and it puts transmission voltage on its cable. Feed houses
/// from it only through a substation.
/obj/machinery/ms13/fusion_generator/power_plant
	name = "power plant generator"
	desc = "A plant-scale fusion generator. It puts out transmission voltage: houses can only take it through a substation."
	power_gen = 25000
	voltage = MS13_VOLTAGE_HIGH
	steady_ripple = 0.1

/// Street lamps light only off a live cable knotted under the pole: house voltage, with enough to spare for the bulb.
/obj/machinery/power/ms13/streetlamp
	use_power = NO_POWER_USE
	light_color = "#ffd9a0"
	/// Watts the lamp head draws while lit.
	var/lamp_draw = 150
	var/bulb_broken = FALSE
	var/lit = FALSE

/obj/machinery/power/ms13/streetlamp/double
	lamp_draw = 300

/obj/machinery/power/ms13/streetlamp/process(seconds_per_tick)
	if(!bulb_broken && powernet?.ms13_voltage >= MS13_VOLTAGE_HIGH)
		// Plant voltage straight on the pole: the bulb goes with a bang.
		bulb_broken = TRUE
		visible_message(span_warning("[src]'s lamp flashes blinding white and bursts!"))
		do_sparks(3, TRUE, src)
	var/shine = !bulb_broken && powernet && surplus() >= lamp_draw
	if(shine)
		add_load(lamp_draw)
		if(powernet.ms13_ripple && prob(powernet.ms13_ripple * 40))
			flicker()
	set_lit(shine)

/obj/machinery/power/ms13/streetlamp/proc/set_lit(on)
	if(lit == on)
		return
	lit = on
	set_light(l_outer_range = on ? 7 : 0, l_power = 1, l_on = on)

/// A brief stutter from a rippling supply.
/obj/machinery/power/ms13/streetlamp/proc/flicker()
	set waitfor = FALSE
	set_light(l_on = FALSE)
	sleep(rand(2, 6))
	if(lit && !QDELETED(src))
		set_light(l_on = TRUE)

/obj/machinery/power/ms13/streetlamp/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/light) || !bulb_broken)
		return NONE
	var/obj/item/light/bulb = tool
	if(bulb.status != LIGHT_OK)
		to_chat(user, span_warning("That [bulb.name] is dead too."))
		return ITEM_INTERACT_BLOCKING
	bulb_broken = FALSE
	user.visible_message(span_notice("[user] fits a new bulb into [src]."), span_notice("You fit a new bulb into [src]."))
	qdel(bulb)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/ms13/streetlamp/examine(mob/user)
	. = ..()
	if(bulb_broken)
		. += span_warning("Its bulb is blown. A light bulb would fix it.")
	else if(!lit)
		. += span_notice("It's dark: it needs a live cable knotted under the pole.")
