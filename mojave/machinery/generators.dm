#define GENERATOR_ON "on"
#define GENERATOR_OFF "off"
#define GENERATOR_BROKEN "broken"

/**
 * A house-scale power source that feeds real cables. Wire it to an /obj/machinery/power/apc/ms13's terminal
 * (mojave/code/modules/power/apc_ms13.dm) and that box draws power from it like any grid. Houses get one at
 * round start (mojave/code/modules/power/house_power.dm); mappers can also place it and set generator_state.
 * The sprite has one "running" frame, so off/broken are tinted instead.
 *
 * It burns fusion fuel while running and wears as it goes: output drops with its condition, and a worn-out
 * generator can break down. Fusion cores refuel it and a welder patches it up.
 *
 * fusion_generator is /obj/machinery/ms13, not /obj/machinery/power (renaming it would orphan every existing
 * map placement), so the few powernet procs it needs are copied from code/modules/power/power.dm.
 */
/obj/machinery/ms13/fusion_generator
	name = "fusion generator"
	desc = "A generator that runs on fusion cores. Can power a whole house by itself, if it's kept fed."
	icon = 'mojave/icons/structure/64x64_machinery.dmi'
	icon_state = "generator_on"
	anchored = TRUE
	density = TRUE
	max_integrity = 5000
	flags_1 = INDESTRUCTIBLE
	use_power = NO_POWER_USE
	/// Mapper-set starting state: GENERATOR_ON, GENERATOR_OFF or GENERATOR_BROKEN.
	var/generator_state = GENERATOR_ON
	/// Watts added to the powernet each tick while running in perfect condition.
	var/power_gen = 5000
	/// Seconds of running time left.
	var/fuel = 2 HOURS / 10
	var/max_fuel = 2 HOURS / 10
	/// Seconds of running time one fusion core adds.
	var/fuel_per_core = 1 HOURS / 10
	/// 0-100. Output scales with it, and a badly worn generator can break down.
	var/condition = 100
	/// Condition lost per second of running.
	var/wear_rate = 0.002
	/// Condition a single weld restores.
	var/repair_amount = 25
	var/datum/powernet/powernet
	var/datum/looping_sound/generator/soundloop

/obj/machinery/ms13/fusion_generator/Initialize(mapload)
	. = ..()
	soundloop = new(src, FALSE)
	ensure_connection()
	update_running()

/obj/machinery/ms13/fusion_generator/Destroy()
	disconnect_from_network()
	QDEL_NULL(soundloop)
	return ..()

/obj/machinery/ms13/fusion_generator/examine(mob/user)
	. = ..()
	switch(generator_state)
		if(GENERATOR_ON)
			. += span_notice("It's running[powernet ? ", feeding the cable under it" : ", but nothing is wired to it"].")
		if(GENERATOR_OFF)
			. += span_notice("It's switched off.")
		if(GENERATOR_BROKEN)
			. += span_warning("It's broken down. A welder might get it going again.")
	. += span_notice("The fuel gauge reads [round(100 * fuel / max_fuel)]%.")
	switch(condition)
		if(75 to INFINITY)
			. += span_notice("It's in good shape.")
		if(40 to 75)
			. += span_notice("It rattles a little.")
		if(1 to 40)
			. += span_warning("It's badly worn and knocking hard.")

/obj/machinery/ms13/fusion_generator/process(seconds_per_tick)
	ensure_connection()
	if(generator_state != GENERATOR_ON)
		return
	if(fuel <= 0)
		visible_message(span_warning("[src] sputters and dies as its fuel runs out."))
		set_generator_state(GENERATOR_OFF)
		return
	fuel = max(fuel - seconds_per_tick, 0)
	condition = max(condition - wear_rate * seconds_per_tick, 0)
	// The more worn it is, the likelier it is to give out.
	if(!condition || prob((1 - condition / 100) ** 4 * seconds_per_tick))
		visible_message(span_warning("[src] shudders and grinds to a halt!"))
		set_generator_state(GENERATOR_BROKEN)
		return
	add_avail(power_gen * (0.5 + condition / 200))

/// Keeps the generator on the powernet of the cable knot under it, however that network was rebuilt or rewired.
/obj/machinery/ms13/fusion_generator/proc/ensure_connection()
	var/turf/generator_turf = loc
	var/datum/powernet/wanted
	if(istype(generator_turf))
		var/obj/structure/cable/node = generator_turf.get_cable_node()
		wanted = node?.powernet
		if(!wanted)
			var/obj/machinery/power/terminal/term = locate() in generator_turf
			wanted = term?.powernet
	if(powernet == wanted && !QDELETED(powernet))
		return
	disconnect_from_network()
	wanted?.add_machine(src)

/obj/machinery/ms13/fusion_generator/proc/disconnect_from_network()
	if(!powernet)
		return FALSE
	if(QDELETED(powernet))
		powernet = null
	else
		powernet.remove_machine(src)
	return TRUE

/obj/machinery/ms13/fusion_generator/proc/add_avail(amount)
	if(!powernet)
		return FALSE
	powernet.newavail += amount
	return TRUE

/obj/machinery/ms13/fusion_generator/update_icon_state()
	. = ..()
	switch(generator_state)
		if(GENERATOR_ON)
			color = null
		if(GENERATOR_OFF)
			color = "#606060"
		if(GENERATOR_BROKEN)
			color = "#4a3030"

/obj/machinery/ms13/fusion_generator/proc/set_generator_state(new_state)
	if(generator_state == new_state)
		return
	generator_state = new_state
	update_running()
	if(generator_state == GENERATOR_BROKEN)
		do_sparks(2, FALSE, src)

/// Sound, glow and tint to match generator_state.
/obj/machinery/ms13/fusion_generator/proc/update_running()
	update_appearance()
	if(generator_state == GENERATOR_ON)
		soundloop?.start()
		set_light(2, 1, 0.6, l_color = "#9fd0ff", l_on = TRUE)
	else
		soundloop?.stop()
		set_light(l_on = FALSE)

/obj/machinery/ms13/fusion_generator/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(generator_state == GENERATOR_BROKEN)
		to_chat(user, span_warning("[src] is broken down and needs repairs before it'll run."))
		return
	if(generator_state == GENERATOR_OFF && fuel <= 0)
		to_chat(user, span_warning("[src] turns over but won't catch. It's out of fuel."))
		return
	set_generator_state(generator_state == GENERATOR_ON ? GENERATOR_OFF : GENERATOR_ON)
	to_chat(user, span_notice("You switch [src] [generator_state == GENERATOR_ON ? "on" : "off"]."))
	playsound(src, 'sound/machines/lightswitch.ogg', 50, TRUE)

/obj/machinery/ms13/fusion_generator/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/ms13/component/fusion))
		return NONE
	if(fuel >= max_fuel - fuel_per_core / 2)
		to_chat(user, span_warning("[src]'s fuel gauge is already near full."))
		return ITEM_INTERACT_BLOCKING
	fuel = min(fuel + fuel_per_core, max_fuel)
	user.visible_message(span_notice("[user] loads [tool] into [src]."), span_notice("You load [tool] into [src]."))
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)
	qdel(tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/ms13/fusion_generator/welder_act(mob/living/user, obj/item/tool)
	if(condition >= 100 && generator_state != GENERATOR_BROKEN)
		to_chat(user, span_notice("[src] doesn't need repairs."))
		return TRUE
	if(!tool.use_tool(src, user, 5 SECONDS, volume = 50))
		return TRUE
	condition = min(condition + repair_amount, 100)
	user.visible_message(span_notice("[user] patches up [src]."), span_notice("You patch up [src]."))
	if(generator_state == GENERATOR_BROKEN)
		set_generator_state(GENERATOR_OFF) // repaired, but still needs to be switched on
	return TRUE

#undef GENERATOR_ON
#undef GENERATOR_OFF
#undef GENERATOR_BROKEN

/obj/machinery/ms13/substation
	name = "power substation"
	desc = "A power distribution node. It helps store and redirect power through the networks... You think."
	icon = 'mojave/icons/structure/32x48_machinery.dmi'
	icon_state = "substation"
	anchored = TRUE
	density = TRUE
	max_integrity = 5000
	flags_1 = INDESTRUCTIBLE
	var/zap_flags = ZAP_MOB_DAMAGE | ZAP_MOB_STUN

/obj/machinery/ms13/substation/Bump(atom/movable/bumped_atom)
	. = ..()
	tesla_zap(src, 3, 100, zap_flags)

/obj/machinery/ms13/substation/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	do_sparks(1, FALSE, src)
	tesla_zap(src, 5, 200, zap_flags)

/obj/machinery/ms13/substation/rusty
	icon_state = "substation_rust"
	anchored = TRUE

/obj/machinery/ms13/substation/discharge
	name = "substation capacitor unit"
	desc = "A large capacitor, it stores energy for rapid use. Has a tendency to discharge when overclocked, be wary."
	icon_state = "generator"

/obj/machinery/ms13/substation/discharge/rusty
	icon_state = "generator_rust"
