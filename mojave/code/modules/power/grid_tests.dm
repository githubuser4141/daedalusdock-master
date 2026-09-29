#ifdef UNIT_TESTS
/// A plant generator feeds a substation, the substation feeds a house line, and a capacitor on that line steadies it.
/datum/unit_test/ms13_power_grid/Run()
	var/x0 = run_loc_floor_bottom_left.x + 1
	var/y0 = run_loc_floor_bottom_left.y + 1
	var/z0 = run_loc_floor_bottom_left.z
	// Plant knot -> substation knot is the plant side; the tile the substation faces and the box's tile are the house side.
	lay_knot(locate(x0, y0, z0), EAST)
	lay_knot(locate(x0 + 1, y0, z0), WEST)
	lay_knot(locate(x0 + 2, y0, z0), EAST)
	lay_knot(locate(x0 + 3, y0, z0), WEST)
	var/obj/machinery/ms13/fusion_generator/power_plant/plant = allocate(/obj/machinery/ms13/fusion_generator/power_plant, locate(x0, y0, z0))
	var/obj/machinery/ms13/substation/substation = allocate(/obj/machinery/ms13/substation, locate(x0 + 1, y0, z0))
	substation.setDir(EAST)
	var/obj/machinery/ms13/substation/discharge/capacitor = allocate(/obj/machinery/ms13/substation/discharge, locate(x0 + 2, y0 + 1, z0))
	capacitor.setDir(SOUTH)
	// Built the way round start builds them: a box made mid-round is an empty frame with no terminal.
	SSatoms.map_loader_begin(REF(src))
	var/obj/machinery/power/apc/ms13/box = new(locate(x0 + 3, y0, z0))
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(list(box))
	allocated += box
	box.terminal?.connect_to_network()
	for(var/tick in 1 to 3)
		run_grid(plant, substation, capacitor)
	var/datum/powernet/plant_side = substation.input
	var/datum/powernet/house_side = substation.output
	if(!(plant_side && house_side && plant_side != house_side))
		Fail("The substation did not sit between two networks.")
		return
	if(box.terminal?.powernet != house_side)
		Fail("The utility box was not on the substation's house side.")
	if(plant_side.ms13_voltage != MS13_VOLTAGE_HIGH)
		Fail("The plant did not put transmission voltage on its line.")
	if(house_side.ms13_voltage != MS13_VOLTAGE_LOW)
		Fail("The substation did not step plant voltage down for the houses.")
	if(!(house_side.avail > 0 && box.has_incoming_power()))
		Fail("The houses got no power through the substation.")
	if(!((capacitor in house_side.ms13_capacitors) && capacitor.charge > 0))
		Fail("The capacitor did not join the house line and charge.")
	if(!(plant_side.ms13_ripple > 0 && house_side.ms13_ripple < plant_side.ms13_ripple / 2))
		Fail("The capacitor did not steady the plant's ripple.")

	// A lamp on the house side lights and draws; one on the plant side blows its bulb.
	var/obj/machinery/power/ms13/streetlamp/house_lamp = allocate(/obj/machinery/power/ms13/streetlamp, locate(x0 + 3, y0, z0))
	var/obj/machinery/power/ms13/streetlamp/plant_lamp = allocate(/obj/machinery/power/ms13/streetlamp, locate(x0, y0, z0))
	house_lamp.connect_to_network()
	plant_lamp.connect_to_network()
	house_lamp.process(2)
	plant_lamp.process(2)
	if(!house_lamp.lit || house_side.load < house_lamp.lamp_draw)
		Fail("A street lamp on a live house line stayed dark or drew nothing.")
	if(!plant_lamp.bulb_broken || plant_lamp.lit)
		Fail("A street lamp on plant voltage kept its bulb.")
	house_lamp.disconnect_from_network()
	house_lamp.process(2)
	if(house_lamp.lit)
		Fail("A street lamp with no cable stayed lit.")
	house_side.load = 0

	// Without the capacitor the ripple goes straight through.
	capacitor.breaker = FALSE
	for(var/tick in 1 to 2)
		run_grid(plant, substation, capacitor)
	if(house_side.ms13_ripple != plant_side.ms13_ripple)
		Fail("The ripple was steadied with no capacitor working.")

	// A box short of power browns out and stays out a while.
	box.lastused_total = house_side.avail * 2
	if(!(!box.has_incoming_power() && box.brownout_until > world.time))
		Fail("A box drawing more than the line could spare stayed on.")
	box.lastused_total = 0
	if(!(!box.has_incoming_power()))
		Fail("A browned-out box came straight back.")
	box.brownout_until = 0

	// A worn substation arcs plant voltage through; a burnt-out one passes nothing.
	substation.condition = 1
	var/arced = FALSE
	for(var/tick in 1 to 10)
		run_grid(plant, substation, capacitor)
		if(house_side.ms13_voltage == MS13_VOLTAGE_HIGH)
			arced = TRUE
			break
	if(!(arced))
		Fail("A worn-out substation never let plant voltage through.")
	substation.condition = 0
	run_grid(plant, substation, capacitor)
	run_grid(plant, substation, capacitor)
	if(!(!house_side.avail))
		Fail("A burnt-out substation still fed the houses.")

	// Plant voltage on a box blows it out.
	var/burnt = FALSE
	for(var/tries in 1 to 40)
		if(box.suffer_grid(plant_side))
			burnt = TRUE
			break
	if(!(burnt && (box.machine_stat & BROKEN)))
		Fail("Plant voltage never burnt out a utility box.")

	// Knocked about badly enough, a substation breaks down but can't be destroyed; rebuilt, it works again.
	substation.condition = 100
	substation.take_damage(substation.max_integrity * 0.8, BRUTE, BLUNT, FALSE)
	if(!(substation.machine_stat & BROKEN) || !(substation.resistance_flags & INDESTRUCTIBLE))
		Fail("A wrecked substation did not break down and turn indestructible.")
	substation.take_damage(substation.max_integrity, BRUTE, BLUNT, FALSE)
	if(QDELETED(substation))
		Fail("A wrecked substation was destroyed outright.")
		return
	run_grid(plant, substation, capacitor)
	run_grid(plant, substation, capacitor)
	if(house_side.avail)
		Fail("A wrecked substation still fed the houses.")
	substation.mend()
	run_grid(plant, substation, capacitor)
	run_grid(plant, substation, capacitor)
	if(!house_side.avail || (substation.resistance_flags & INDESTRUCTIBLE))
		Fail("A rebuilt substation did not work again, or stayed indestructible.")

	// A worn capacitor can't hold a full charge: charged past it, it discharges.
	capacitor.breaker = TRUE
	capacitor.condition = 10
	capacitor.charge = capacitor.capacity / 2
	capacitor.process(2)
	if(!(!capacitor.charge))
		Fail("An overcharged worn capacitor held its charge.")

/// One grid tick, in SSmachines' order: every network rolls over, then the machines run.
/datum/unit_test/ms13_power_grid/proc/run_grid(obj/machinery/ms13/fusion_generator/plant, obj/machinery/ms13/substation/substation, obj/machinery/ms13/substation/discharge/capacitor)
	// Each network once, however many of these machines share it.
	var/list/nets = list()
	for(var/datum/powernet/net in list(plant.powernet, substation.input, substation.output))
		nets |= net
	for(var/datum/powernet/net as anything in nets)
		net.reset()
	plant.condition = 100
	plant.fuel = plant.max_fuel
	plant.process(2)
	substation.process(2)
	capacitor.process(2)

/datum/unit_test/ms13_power_grid/proc/lay_knot(turf/tile, toward)
	var/obj/structure/cable/knot = allocate(/obj/structure/cable, tile)
	knot.set_directions(GLOB.real_dirs_to_cable_dirs["[toward]"])

/// Named map rooms must not share the same APC-controlled area instance.
/datum/unit_test/ms13_named_map_areas
	name = "POWER: Separately Named MS13 Map Areas Stay Separate"

/datum/unit_test/ms13_named_map_areas/Run()
	var/datum/parsed_map/map = new
	allocated += map
	var/area/area_type = /area/ms13/underground/mountain_bunker
	var/area/default_area = GLOB.areas_by_type[area_type]
	var/list/names = list("Regression Tram", null, "Regression Mines", "Regression Tram", null)
	var/list/old_areas = list()
	var/list/rooms = list()
	for(var/index in 1 to length(names))
		var/turf/site = locate(run_loc_floor_bottom_left.x + index, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
		old_areas[site] = get_area(site)
		var/list/attributes = names[index] ? list("name" = names[index]) : GLOB.map_model_default
		map.build_coordinate(list(list(/turf/template_noop, area_type), list(GLOB.map_model_default, attributes)), site, FALSE, FALSE, FALSE)
		rooms += get_area(site)
	if(rooms[1] == rooms[2] || rooms[1] == rooms[3] || rooms[2] == rooms[3])
		Fail("Differently named rooms shared one area and would fight over APC power.")
	if(rooms[1] != rooms[4] || rooms[2] != rooms[5])
		Fail("Repeated tiles of the same mapped room created different areas.")
	if(GLOB.areas_by_type[area_type] != default_area || default_area.name != initial(area_type.name))
		Fail("Loading a named room replaced or renamed the default area.")
	for(var/turf/site as anything in old_areas)
		site.change_area(get_area(site), old_areas[site])
	get_sorted_areas()
	qdel(rooms[1])
	require_area_resort()
	qdel(rooms[3])
	var/area/deleted_room = rooms[3]
	if(deleted_room.alarm_manager || (rooms[1] in get_sorted_areas()) || (rooms[3] in get_sorted_areas()))
		Fail("Deleting a room with a cleared area cache interrupted cleanup or left stale area entries.")

/// Exercise a real generator, cable, terminal and fixture across powernet rollovers.
/datum/unit_test/ms13_utility_power
	name = "POWER: Utility Box Generator Startup Stays Steady"
	var/power_changes = 0

/datum/unit_test/ms13_utility_power/proc/power_changed()
	SIGNAL_HANDLER
	power_changes++

/datum/unit_test/ms13_utility_power/proc/power_tick(obj/machinery/ms13/fusion_generator/generator, obj/machinery/power/apc/ms13/box)
	generator.powernet.reset()
	generator.process(2)
	box.process(2)

/datum/unit_test/ms13_utility_power/Run()
	var/turf/site = run_loc_floor_bottom_left
	var/area/old_area = get_area(site)
	var/area/room = new
	allocated += room
	site.change_area(old_area, room)
	var/obj/structure/cable/wire = allocate(/obj/structure/cable, site)
	wire.set_directions(CABLE_NORTH)
	var/obj/machinery/ms13/fusion_generator/generator = allocate(/obj/machinery/ms13/fusion_generator, site)
	generator.set_generator_state("off")
	SSatoms.map_loader_begin(REF(src))
	var/obj/machinery/power/apc/ms13/box = new(site)
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(list(box))
	allocated += box
	box.terminal.connect_to_network()
	var/obj/machinery/light/ms13/fixture = allocate(/obj/machinery/light/ms13, site)
	fixture.status = LIGHT_OK
	fixture.switchcount = -1
	fixture.maploaded = TRUE
	// Advance this isolated network ourselves; timers still run for the real startup flicker.
	STOP_PROCESSING(SSmachines, generator)
	STOP_PROCESSING(SSmachines, box)
	SSmachines.powernets -= generator.powernet
	RegisterSignal(room, COMSIG_AREA_POWER_CHANGE, PROC_REF(power_changed))
	power_tick(generator, box)
	if(room.power_light || fixture.on)
		Fail("The switched-off generator powered its room.")
	generator.set_generator_state("on")
	power_tick(generator, box)
	power_tick(generator, box)
	if(!room.power_light || !fixture.on || !fixture.GetComponent(/datum/component/ms13_light_flicker))
		Fail("Generator startup did not power the fixture and start its finite flicker.")
	sleep(2 SECONDS)
	var/changes_after_startup = power_changes
	for(var/tick in 1 to 30)
		power_tick(generator, box)
		if(!room.power_light || !fixture.on)
			Fail("A steady generator lost room power on tick [tick].")
	if(power_changes != changes_after_startup || fixture.GetComponent(/datum/component/ms13_light_flicker) || fixture.switchcount != 0)
		Fail("Steady generator power repeated the APC transition or fixture startup.")
	generator.set_generator_state("off")
	power_tick(generator, box)
	power_tick(generator, box)
	if(room.power_light || fixture.on)
		Fail("Stopping the generator did not remove room power.")
	generator.set_generator_state("on")
	fixture.switchcount = -1
	fixture.maploaded = TRUE
	power_tick(generator, box)
	power_tick(generator, box)
	if(!room.power_light || !fixture.on)
		Fail("Restoring the generator did not restore room power.")
	UnregisterSignal(room, COMSIG_AREA_POWER_CHANGE)
	qdel(fixture)
	qdel(box)
	qdel(generator)
	qdel(wire)
	site.change_area(room, old_area)

/// Smart cables mapped straight through a plant: they stop at a substation, and leave a knot for a lamp mid-line.
/datum/unit_test/ms13_smart_cables
	name = "POWER: Smart Cables Wire The Grid"

/datum/unit_test/ms13_smart_cables/Run()
	var/x0 = run_loc_floor_bottom_left.x + 1
	var/y0 = run_loc_floor_bottom_left.y + 1
	var/z0 = run_loc_floor_bottom_left.z
	// Plant cable, substation facing east, the tile it faces, a lamp on the line, the line's end. Built as the map loads.
	SSatoms.map_loader_begin(REF(src))
	var/list/built = list()
	for(var/offset in 0 to 4)
		built += new /obj/structure/cable/smart_cable(locate(x0 + offset, y0, z0))
	var/obj/machinery/ms13/substation/substation = new(locate(x0 + 1, y0, z0))
	substation.setDir(EAST)
	var/obj/machinery/power/ms13/streetlamp/lamp = new(locate(x0 + 3, y0, z0))
	built += substation
	built += lamp
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(built)
	allocated += built
	var/datum/powernet/plant_side = ms13_cable_net_at(locate(x0 + 1, y0, z0))
	var/datum/powernet/house_side = ms13_cable_net_at(locate(x0 + 2, y0, z0))
	if(!plant_side || !house_side || plant_side == house_side)
		Fail("Smart cables ran straight across the substation, or left it no knot on either side.")
	if(ms13_cable_net_at(locate(x0, y0, z0)) != plant_side)
		Fail("Smart cables did not join the plant line.")
	if(ms13_cable_net_at(locate(x0 + 3, y0, z0)) != house_side)
		Fail("A smart cable running under a lamp left it no knot on the house line.")
	lamp.connect_to_network()
	if(lamp.powernet != house_side)
		Fail("A lamp mid-line didn't join the house line.")
	// A rail feeder beside the end of the line, its wires reaching over, joins it too.
	var/obj/machinery/power/ms13_rail_feeder/feeder = allocate(/obj/machinery/power/ms13_rail_feeder, locate(x0 + 5, y0, z0))
	feeder.setDir(WEST)
	feeder.connect_to_network()
	if(feeder.powernet != house_side)
		Fail("A rail feeder beside a cable's end didn't join its line.")

/// Machines run off wiring: a live knot on their tile, or a live wall they touch. Cables laid into one stretch of wall
/// join through it, rock carries nothing, and a utility box's breaker switches the cable at its terminal onto its wall.
/datum/unit_test/ms13_wired_power
	name = "POWER: Machines Run Off Wires And Walls"
	/// Turf -> the type it was, put back after.
	var/list/changed = list()

/datum/unit_test/ms13_wired_power/Run()
	var/area/place = get_area(run_loc_floor_bottom_left)
	place.ms13_wired = TRUE
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	// A wall three long, a heavy machine against its top, a cable laid into its bottom.
	for(var/offset in 0 to 2)
		build(locate(x0 + 2, y0 + offset, z0), /turf/closed/wall/ms13/wood)
	var/obj/machinery/ms13_heft_test/machine = allocate(/obj/machinery/ms13_heft_test, locate(x0 + 1, y0 + 2, z0))
	var/obj/structure/cable/plug = live_knot(locate(x0 + 1, y0, z0), EAST)
	machine.check_wiring()
	if(!machine.powered() || (machine.machine_stat & NOPOWER))
		return Fail("A machine against a live wall didn't run.")

	var/obj/structure/cable/other = live_knot(locate(x0 + 3, y0 + 1, z0), WEST)
	if(other.powernet != plug.powernet)
		return Fail("Two cables laid into one wall weren't joined through it.")

	machine.forceMove(locate(x0 + 1, y0 + 3, z0))
	if(!(machine.machine_stat & NOPOWER))
		return Fail("A machine dragged off the wall kept running.")
	machine.forceMove(locate(x0 + 1, y0 + 2, z0))

	build(locate(x0 + 2, y0 + 1, z0), /turf/closed/indestructible/rock/ms13)
	ms13_rebuild_rewalled()
	plug.powernet.avail = 1000
	machine.check_wiring()
	if(machine.powered())
		return Fail("Wiring ran through rock.")
	if(other.powernet == plug.powernet)
		return Fail("Cables stayed joined through rock.")

	var/turf/box_spot = locate(x0 + 3, y0 + 2, z0)
	var/obj/structure/cable/terminal = live_knot(box_spot)
	var/obj/machinery/power/apc/ms13/box = allocate(/obj/machinery/power/apc/ms13, box_spot, WEST, TRUE)
	box.set_machine_stat(box.machine_stat & ~MAINT)
	box.operating = TRUE
	box.update()
	ms13_rebuild_rewalled()
	terminal.powernet.avail = 1000
	machine.check_wiring()
	if(!machine.powered())
		return Fail("A utility box with its breaker closed didn't feed its wall.")
	box.operating = FALSE
	box.update()
	ms13_rebuild_rewalled()
	terminal.powernet.avail = 1000
	machine.check_wiring()
	if(machine.powered() || !(machine.machine_stat & NOPOWER))
		return Fail("A utility box with its breaker open still fed its wall.")

	var/obj/structure/cable/under = live_knot(get_turf(machine))
	machine.check_wiring()
	if(!machine.powered())
		return Fail("A machine on a live knot didn't run.")
	qdel(under)

	// A window where the rock was carries the wiring across again, but nothing plugs into it.
	build(locate(x0 + 2, y0 + 1, z0), /turf/open/floor/iron)
	allocate(/obj/structure/window/fulltile, locate(x0 + 2, y0 + 1, z0))
	ms13_rebuild_rewalled()
	plug.powernet.avail = 1000
	machine.check_wiring()
	if(!machine.powered())
		return Fail("A window didn't carry the wiring across between walls.")
	if(other.powernet == plug.powernet)
		return Fail("A cable laid into a window plugged into the wiring.")

/datum/unit_test/ms13_wired_power/proc/build(turf/tile, type)
	if(!changed[tile])
		changed[tile] = tile.type
	tile.ChangeTurf(type)

/// A knot on tile, laid toward direction if given, on a live network.
/datum/unit_test/ms13_wired_power/proc/live_knot(turf/tile, direction)
	var/obj/structure/cable/knot = allocate(/obj/structure/cable, tile)
	knot.set_directions(direction ? GLOB.real_dirs_to_cable_dirs["[direction]"] : NONE)
	if(!knot.powernet)
		new /datum/powernet().add_cable(knot)
	knot.powernet.avail = 1000
	return knot

/datum/unit_test/ms13_wired_power/Destroy()
	var/area/place = get_area(run_loc_floor_bottom_left)
	place.ms13_wired = initial(place.ms13_wired)
	for(var/turf/tile as anything in changed)
		tile.ChangeTurf(changed[tile])
	return ..()

/// Heavy ground cable and concrete cable floor wire up the way they're drawn; smart ground cable takes its shape from
/// what's around it, plain ground cable never joins plain ground cable, and connector and node pieces take machines and
/// knots like a cable knot.
/datum/unit_test/ms13_drawn_cables
	name = "POWER: Drawn Cables Run The Way They're Drawn"
	var/turf/floor_spot
	var/floor_was

/datum/unit_test/ms13_drawn_cables/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/bend_spot = get_step(start, EAST)
	floor_spot = get_step(bend_spot, NORTH)
	floor_was = floor_spot.type
	// Facing south, the node runs down into the bend; the connector runs east into it.
	floor_spot.ChangeTurf(/turf/open/floor/ms13/concrete/cable/node)
	var/obj/structure/ms13/cable/red/connector/connector = allocate(/obj/structure/ms13/cable/red/connector, start)
	var/obj/structure/ms13/cable/red/smart/bend = allocate(/obj/structure/ms13/cable/red/smart, bend_spot)
	if(connector.icon_state != "cable_red_connector")
		return Fail("Heavy ground cable lost its sprite.")
	if(bend.icon_state != "cable_red_curved" || bend.dir != WEST)
		return Fail("Smart ground cable between a cable to its west and a floor node to its north drew [bend.icon_state] facing [dir2text(bend.dir)], not a curve.")
	var/datum/powernet/line = connector.powernet
	if(!line || bend.powernet != line || ms13_cable_net_at(floor_spot) != line)
		return Fail("Ground cable and a concrete floor node didn't join up the way they're drawn.")
	if(ms13_cable_net_at(start) != line)
		return Fail("A connector didn't take machines like a cable knot.")
	var/obj/structure/cable/tap = allocate(/obj/structure/cable, start)
	tap.set_directions(CABLE_NORTH)
	if(tap.powernet != line)
		return Fail("A cable knotted on a connector's tile didn't join its line.")

	var/turf/pile = locate(start.x + 2, start.y + 3, start.z)
	var/obj/structure/ms13/cable/red/one = allocate(/obj/structure/ms13/cable/red, pile)
	var/obj/structure/ms13/cable/blue/two = allocate(/obj/structure/ms13/cable/blue, get_step(pile, EAST))
	var/obj/structure/ms13/cable/red/over = allocate(/obj/structure/ms13/cable/red, pile)
	if((two in one.get_cable_connections()) || (one in two.get_cable_connections()) || (over in one.get_cable_connections()))
		return Fail("Plain ground cable joined plain ground cable.")
	if(ms13_drawn_cable_dirs("curve", EAST) != (CABLE_NORTH|CABLE_EAST) || ms13_drawn_cable_dirs("tail", WEST) != CABLE_EAST)
		return Fail("Drawn cable shapes don't run the way their sprites do.")

/datum/unit_test/ms13_drawn_cables/Destroy()
	floor_spot?.ChangeTurf(floor_was)
	return ..()
#endif
