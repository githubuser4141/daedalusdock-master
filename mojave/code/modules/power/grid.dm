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
	return ..()

/// The powernet of the cable knotted on target, if any.
/proc/ms13_cable_net_at(turf/target)
	var/obj/structure/cable/node = target?.get_cable_node()
	return node?.powernet

/// Smart cables (the mapping helper) leave a knot mid-line wherever a grid machine takes power: under any power machine,
/// generator or substation, and on the tile a substation or capacitor faces.
/obj/structure/cable/smart_cable/knot_desirable()
	if(..())
		return TRUE
	var/turf/my_turf = loc
	if((locate(/obj/machinery/power) in my_turf) || (locate(/obj/machinery/ms13/fusion_generator) in my_turf) || (locate(/obj/machinery/ms13/substation) in my_turf))
		return TRUE
	for(var/direction in GLOB.cardinals)
		for(var/obj/machinery/ms13/substation/facing in get_step(my_turf, direction))
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
