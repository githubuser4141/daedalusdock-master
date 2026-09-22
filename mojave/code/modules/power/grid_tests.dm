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
#endif
