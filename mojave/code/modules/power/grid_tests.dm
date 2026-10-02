#ifdef UNIT_TESTS
/// Dead lines cannot surge; the same hardware must work again when power returns.
/datum/unit_test/ms13_dead_grid/Run()
	var/turf/site = run_loc_floor_bottom_left
	var/obj/machinery/light/ms13/fixture = allocate(/obj/machinery/light/ms13, site)
	var/obj/machinery/light/ms13/broken/mapped_broken = allocate(/obj/machinery/light/ms13/broken, site)
	if(fixture.status != LIGHT_OK || mapped_broken.status != LIGHT_BROKEN)
		return Fail("Light initialization changed the mapped bulb condition.")
	var/obj/structure/cable/cable = allocate(/obj/structure/cable, site)
	cable.set_directions(CABLE_EAST)
	var/datum/powernet/line = cable.powernet
	var/obj/machinery/power/ms13/streetlamp/lamp = allocate(/obj/machinery/power/ms13/streetlamp, site)
	lamp.connect_to_network()
	var/obj/machinery/power/apc/ms13/box = allocate(/obj/machinery/power/apc/ms13, get_step(site, NORTH))
	STOP_PROCESSING(SSmachines, lamp)
	STOP_PROCESSING(SSmachines, box)
	line.avail = 0
	line.ms13_voltage = MS13_VOLTAGE_HIGH
	line.ms13_ripple = 100
	for(var/attempt in 1 to 40)
		box.suffer_grid(line)
		lamp.process(2)
	if(!(!box.surged && !(box.machine_stat & BROKEN) && !lamp.bulb_broken))
		return Fail("An unpowered line damaged its equipment.")
	line.ms13_new_voltage = MS13_VOLTAGE_HIGH
	line.ms13_new_ripple = 100
	line.newavail = 0
	line.reset()
	if(!(line.ms13_voltage == MS13_VOLTAGE_NONE && line.ms13_ripple == 0))
		return Fail("A dead network retained voltage/ripple.")
	line.newavail = 2000
	line.ms13_new_voltage = MS13_VOLTAGE_LOW
	line.reset()
	lamp.process(2)
	if(!(lamp.lit && !lamp.bulb_broken))
		return Fail("A lamp failed to recover after power returned.")
	line.ms13_voltage = MS13_VOLTAGE_HIGH
	lamp.process(2)
	if(!(lamp.bulb_broken))
		return Fail("Real live high voltage no longer damages a lamp.")

/// Electrical faults follow cables, not the shared map area.
/datum/unit_test/ms13_grid_surge/Run()
	var/turf/site = run_loc_floor_bottom_left
	var/area/place = get_area(site)
	var/was_wired = place.ms13_wired
	place.ms13_wired = TRUE
	var/obj/structure/cable/cable = allocate(/obj/structure/cable, site)
	cable.set_directions(CABLE_NORTH)
	var/datum/powernet/line = cable.powernet
	var/obj/machinery/power/apc/ms13/box = allocate(/obj/machinery/power/apc/ms13, site)
	box.terminal = allocate(/obj/machinery/power/terminal, site)
	box.terminal.connect_to_network()
	var/obj/machinery/light/ms13/connected = allocate(/obj/machinery/light/ms13, site)
	var/obj/machinery/light/ms13/isolated = allocate(/obj/machinery/light/ms13, get_step(site, EAST))
	// The surge sweep yields on large maps; keep the test supply steady across those yields.
	STOP_PROCESSING(SSmachines, box)
	SSmachines.powernets -= line
	line.avail = 1000
	box.break_lights()
	if(connected.status != LIGHT_BROKEN || isolated.status != LIGHT_OK)
		Fail("Surge: connected=[connected.status], isolated=[isolated.status], supply=[ms13_supply_at(site) == line], terminal=[box.terminal.powernet == line].")
	connected.status = LIGHT_OK
	line.ms13_voltage = MS13_VOLTAGE_LOW
	line.ms13_ripple = 100
	box.suffer_grid(line)
	if(connected.status != LIGHT_BROKEN || isolated.status != LIGHT_OK)
		Fail("Ripple damaged an electrically isolated light in the same area.")
	SSmachines.powernets |= line
	place.ms13_wired = was_wired

/// The cursor needs a client view; substitute only that UI dependency in server tests.
/atom/movable/screen/fullscreen/cursor_catcher/kinesis/ms13_test/assign_to_mob(mob/owner)
	src.owner = owner
	view_list = getviewsize(world.view)

/mob/living/carbon/human/ms13_kinesis_test/overlay_fullscreen(category, type, severity)
	if(category == "kinesis")
		type = /atom/movable/screen/fullscreen/cursor_catcher/kinesis/ms13_test
	return ..()

/mob/living/carbon/human/ms13_kinesis_test
	parent_type = /mob/living/carbon/human/consistent

/datum/unit_test/ms13_manual_power/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/obj/structure/cable/cable = allocate(/obj/structure/cable, site)
	cable.set_directions(CABLE_EAST)
	var/obj/machinery/power/ms13/manual_generator/generator = allocate(/obj/machinery/power/ms13/manual_generator, site)
	for(var/state in list("idle", "manual", "tk"))
		if(!(state in icon_states(generator.icon)))
			return Fail("Missing manual generator sprite state: [state].")
		var/icon/sprite = icon(generator.icon, state)
		if(sprite.Width() != 32 || sprite.Height() != 32)
			return Fail("Generator state [state] is not a native 32x32 sprite.")
	STOP_PROCESSING(SSmachines, generator)
	var/mob/living/carbon/human/ms13_kinesis_test/user = allocate(/mob/living/carbon/human/ms13_kinesis_test, get_step(site, WEST))
	user.set_special_base(SPECIAL_STRENGTH, 5)
	generator.operator = user
	var/old_stamina = user.stamina.current
	generator.process(2)
	if(!(generator.last_output == 200 && user.stamina.current < old_stamina))
		return Fail("Hand cranking: output [generator.last_output], STR [user.get_special(SPECIAL_STRENGTH)], stamina [old_stamina] -> [user.stamina.current], can crank [generator.can_crank(user)], hand [user.has_active_hand()], incapacitated [user.incapacitated()].")
	if(generator.icon_state != "manual")
		return Fail("Hand cranking did not select the manual sprite.")
	user.set_special_base(SPECIAL_STRENGTH, 10)
	generator.process(2)
	if(!(generator.last_output == 400 && generator.powernet?.ms13_new_voltage == MS13_VOLTAGE_LOW))
		return Fail("More STR did not produce more low-voltage power.")
	user.forceMove(get_step(get_step(site, EAST), EAST))
	generator.process(2)
	if(!(generator.last_output == 0))
		return Fail("Walking away left manual generation running.")
	generator.operator = null
	user.forceMove(get_step(site, WEST))
	INVOKE_ASYNC(generator, TYPE_PROC_REF(/atom, attack_hand), user)
	sleep(1)
	if(generator.operator != user || !DOING_INTERACTION(user, "MS13_CRANK"))
		return Fail("Clicking the generator did not start continuous cranking.")
	user.forceMove(get_step(site, SOUTHWEST))
	sleep(3 SECONDS)
	if(generator.operator || DOING_INTERACTION(user, "MS13_CRANK"))
		return Fail("Moving failed to stop the crank action.")
	user.forceMove(get_step(site, WEST))

	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor, user)
	var/obj/item/ms13/power_armor/arm/right/arm = allocate(/obj/item/ms13/power_armor/arm/right, null)
	frame.module_armor[BODY_ZONE_R_ARM] = arm
	arm.frame = frame
	var/obj/item/ms13/pa_module/kinesis/module = allocate(/obj/item/ms13/pa_module/kinesis, arm)
	arm.modules[MAIN_MODULE_PA] = module
	arm.actions_modules = module.actions_modules.Copy()
	module.part_pa = arm
	user.equip_to_slot_if_possible(frame, ITEM_SLOT_OCLOTHING, disable_warning = TRUE)
	module.added_to_pa()
	var/datum/action/action = module.actions_modules[1]
	if(!(action.owner == user && (action in frame.actions)))
		return Fail("Installing a PA module did not grant its action.")
	module.ui_action_click(user)
	var/obj/item/mod/module/anomaly_locked/kinesis/power_armor/controller = module.controller
	if(!(controller.kinesis_user == user && controller.check_power(1)))
		return Fail("Installed powered kinesis did not activate.")
	if(!(!controller.can_grab(user) && controller.can_grab(generator)))
		return Fail("Kinesis accepted self-grab or rejected the generator rotor.")
	var/old_charge = frame.cell.charge
	if(!(controller.drain_power(1) && frame.cell.charge == old_charge - 1))
		return Fail("Kinesis did not draw from the PA cell.")
	controller.grab_atom(generator)
	if(!(generator.kinetic_driver == controller && !controller.can_grab(generator)))
		return Fail("The rotor was not claimed exclusively.")
	var/list/old_sparks = list()
	for(var/obj/effect/particle_effect/sparks/spark in site)
		old_sparks += spark
	generator.process(2)
	if(!(generator.last_output == 2000))
		return Fail("Kinesis did not generate its higher output.")
	var/real_sparks = FALSE
	for(var/obj/effect/particle_effect/sparks/spark in site)
		if(!(spark in old_sparks))
			real_sparks = TRUE
	if(!real_sparks || generator.icon_state != "tk")
		return Fail("Kinesis did not emit real sparks and select its TK sprite.")
	if(COOLDOWN_FINISHED(generator, tk_spark_cooldown))
		return Fail("Kinesis sparks have no cooldown.")
	controller.move_grabbed()
	if(!(generator.loc == site))
		return Fail("Kinesis moved the anchored generator.")
	controller.clear_grab(FALSE)
	if(generator.icon_state != "idle")
		return Fail("Releasing kinesis did not restore the idle sprite.")
	controller.launch(generator)
	if(!(!generator.kinetic_driver && !generator.throwing && !user.screens["kinesis"]))
		return Fail("Releasing the rotor left a claim/cursor or threw the generator.")
	controller.grab_atom(generator)
	frame.cell.charge = 0
	generator.process(2)
	if(!(generator.last_output == 0 && !controller.drain_power(1)))
		return Fail("An empty PA cell kept producing power.")
	frame.cell.charge = old_charge
	module.removed_from_pa()
	if(!(!controller.grabbed_atom && !controller.kinesis_user && !generator.kinetic_driver && !action.owner))
		return Fail("Removing the module left its action, beam or rotor claim active.")
	module.added_to_pa()
	module.ui_action_click(user)
	controller.grab_atom(generator)
	qdel(generator)
	if(!(!controller.grabbed_atom && !controller.kinesis_catcher && !controller.kinesis_beam))
		return Fail("Deleting the target leaked the kinesis grab.")
	var/obj/item/target = allocate(/obj/item, site)
	controller.grab_atom(target)
	user.dropItemToGround(frame, force = TRUE)
	if(!(!controller.kinesis_user && !controller.grabbed_atom && !HAS_TRAIT(target, TRAIT_NO_FLOATING_ANIM)))
		return Fail("Unequipping the armor left kinesis active.")
	user.equip_to_slot_if_possible(frame, ITEM_SLOT_OCLOTHING, disable_warning = TRUE)
	module.ui_action_click(user)
	controller.grab_atom(target)
	qdel(module)
	if(arm.modules[MAIN_MODULE_PA] || (action in frame.actions_modules) || (action in frame.actions) || HAS_TRAIT(target, TRAIT_NO_FLOATING_ANIM))
		return Fail("Deleting an installed module left armor references or a kinesis grab behind.")

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

	// A dead plant cannot arc or pass ripple through a transformer running on stored energy.
	plant_side.avail = 0
	plant_side.ms13_ripple = 1
	substation.condition = 1
	house_side.newavail = 0
	house_side.ms13_new_voltage = MS13_VOLTAGE_NONE
	house_side.ms13_new_ripple = 0
	substation.process(2)
	if(substation.last_delivered <= 0 || house_side.ms13_new_voltage != MS13_VOLTAGE_LOW || house_side.ms13_new_ripple)
		Fail("Capacitor-only backup inherited the dead plant's hazards or supplied no power.")
	capacitor.charge = 0
	house_side.newavail = 0
	house_side.ms13_new_voltage = MS13_VOLTAGE_NONE
	substation.process(2)
	if(house_side.newavail || house_side.ms13_new_voltage != MS13_VOLTAGE_NONE)
		Fail("An empty transformer announced power/voltage with no source.")
	substation.condition = 100
	for(var/tick in 1 to 3)
		run_grid(plant, substation, capacitor)

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
/// what's around it, ground cable only joins ground cable of its own colour, and connector and node pieces take machines
/// and knots like a cable knot.
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
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer, start)
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human, start)
	var/obj/structure/cable/ms13_cast/cast_wire = locate() in floor_spot
	for(var/supply in list(0, 5000))
		line.avail = supply
		line.load = 1000
		var/readout = cast_wire.get_power_info()
		if(!(readout in floor_spot.examine(ghost)))
			return Fail("A ghost cannot read the embedded cable's power at [supply] watts.")
		if(readout in floor_spot.examine(player))
			return Fail("The observer power readout is exposed to living players.")
	var/obj/structure/cable/tap = allocate(/obj/structure/cable, start)
	tap.set_directions(CABLE_NORTH)
	if(tap.powernet != line)
		return Fail("A cable knotted on a connector's tile didn't join its line.")

	var/turf/pile = locate(start.x + 2, start.y + 3, start.z)
	var/obj/structure/ms13/cable/red/one = allocate(/obj/structure/ms13/cable/red, pile)
	var/obj/structure/ms13/cable/red/next = allocate(/obj/structure/ms13/cable/red, get_step(pile, WEST))
	var/obj/structure/ms13/cable/blue/other = allocate(/obj/structure/ms13/cable/blue, get_step(pile, EAST))
	if(!(next in one.get_cable_connections()) || !(one in next.get_cable_connections()))
		return Fail("A run of plain ground cable of one colour didn't join up.")
	if((other in one.get_cable_connections()) || (one in other.get_cable_connections()))
		return Fail("Ground cable of different colours joined.")
	if(ms13_drawn_cable_dirs("curve", EAST) != (CABLE_NORTH|CABLE_EAST) || ms13_drawn_cable_dirs("tail", WEST) != CABLE_EAST)
		return Fail("Drawn cable shapes don't run the way their sprites do.")

/datum/unit_test/ms13_drawn_cables/Destroy()
	floor_spot?.ChangeTurf(floor_was)
	return ..()
#endif
